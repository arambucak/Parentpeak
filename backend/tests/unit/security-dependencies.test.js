const assert = require('node:assert/strict');
const fs = require('node:fs');
const { createRequire } = require('node:module');
const net = require('node:net');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');
const nodemailer = require('nodemailer');
const { XMLParser } = require('fast-xml-parser');

const lock = require('../../package-lock.json');
const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');
const sender = { from: 'ParentPeak <sender@example.test>' };

function mailFixture(env = {}, mailer = nodemailer, Resend = class {}) {
  const start = source.indexOf('const ACTION_HANDLER_BASE =');
  const end = source.indexOf('/** Build a custom action URL', start);
  assert.ok(start >= 0 && end > start);
  const warnings = [];
  const context = vm.createContext({
    process: { env }, nodemailer: mailer, Resend,
    console: { warn: (message) => warnings.push(message) },
  });
  vm.runInContext(source.slice(start, end), context);
  return {
    createTransport: context.createMailTransporter,
    sendEmail: context.sendEmail,
    warnings,
  };
}

function smtpEnv(port, overrides = {}) {
  return {
    SMTP_HOST: '127.0.0.1', SMTP_PORT: String(port),
    SMTP_USER: 'synthetic-user', SMTP_PASS: 'synthetic-test-password',
    SMTP_FROM_EMAIL: 'sender@example.test', ...overrides,
  };
}

async function smtpServer(t, { rejectRecipient = false } = {}) {
  const commands = [];
  const messages = [];
  const sockets = new Set();
  const server = net.createServer((socket) => {
    sockets.add(socket);
    socket.on('close', () => sockets.delete(socket));
    socket.on('error', (error) => {
      if (error.code !== 'ECONNRESET') assert.fail(error);
    });
    socket.setEncoding('utf8');
    socket.write('220 localhost synthetic SMTP\r\n');
    let pending = '';
    let data = null;
    socket.on('data', (chunk) => {
      pending += chunk;
      let end;
      while ((end = pending.indexOf('\r\n')) >= 0) {
        const line = pending.slice(0, end);
        pending = pending.slice(end + 2);
        if (data !== null) {
          if (line === '.') {
            messages.push(data.join('\r\n'));
            data = null;
            socket.write('250 accepted\r\n');
          } else {
            data.push(line);
          }
          continue;
        }
        commands.push(line);
        if (/^EHLO /.test(line)) {
          socket.write('250-localhost\r\n250 AUTH PLAIN\r\n');
        } else if (/^AUTH PLAIN /.test(line)) {
          socket.write('235 authenticated\r\n');
        } else if (/^MAIL FROM:/.test(line)) {
          socket.write('250 sender accepted\r\n');
        } else if (/^RCPT TO:/.test(line)) {
          socket.write(rejectRecipient ? '550 recipient rejected\r\n' : '250 recipient accepted\r\n');
        } else if (line === 'DATA') {
          data = [];
          socket.write('354 send message\r\n');
        } else if (line === 'QUIT') {
          socket.end('221 goodbye\r\n');
        } else {
          socket.write('500 unexpected command\r\n');
        }
      }
    });
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(async () => {
    for (const socket of sockets) socket.destroy();
    await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
  });
  return { port: server.address().port, commands, messages };
}

test('approved patches are locked and six accepted packages plus Prisma remain version-identical', () => {
  const versions = {
    'proxy-addr': '2.0.8', 'fast-uri': '3.1.8',
    'fast-xml-parser': '5.10.1', nodemailer: '10.0.16',
    '@fastify/busboy': '3.2.0', '@grpc/grpc-js': '1.14.4',
    '@prisma/config': '7.8.0', 'glob/node_modules/brace-expansion': '2.1.2',
    'brace-expansion': '5.0.7', 'deepmerge-ts': '7.1.5', mysql2: '3.15.3',
    prisma: '7.8.0', '@prisma/client': '7.8.0', '@prisma/adapter-pg': '7.8.0',
  };
  for (const [name, version] of Object.entries(versions)) {
    assert.equal(lock.packages[`node_modules/${name}`].version, version, name);
  }
  assert.equal(require('nodemailer/package.json').version, versions.nodemailer);
  assert.equal(require('proxy-addr/package.json').version, versions['proxy-addr']);
  const semver = require('semver');
  const engine = require('../../package.json').engines.node;
  assert.equal(semver.satisfies('24.14.1', engine), true);
  assert.equal(semver.satisfies('20.18.0', engine), false);
});

test('real Nodemailer compiles ordinary and IDN recipients using createTransport/sendMail', async () => {
  const transport = nodemailer.createTransport({ streamTransport: true, buffer: true, newline: 'windows' });
  for (const [to, address] of [
    ['Parent <parent@example.test>', 'parent@example.test'],
    ['Family <family@b\u00fccher.example>', 'family@xn--bcher-kva.example'],
  ]) {
    const result = await transport.sendMail({
      ...sender, to, subject: 'Synthetic verification', html: '<p>Test only</p>',
    });
    assert.deepEqual(result.envelope.to, [address]);
    assert.match(result.message.toString(), /Subject: Synthetic verification/);
    assert.match(result.message.toString(), /<p>Test only<\/p>/);
  }
});

test('production SMTP factory preserves auth, default port and certificate validation', () => {
  const fixture = mailFixture(smtpEnv(587));
  const transport = fixture.createTransport();
  assert.equal(transport.options.host, '127.0.0.1');
  assert.equal(transport.options.port, 587);
  assert.equal(transport.options.secure, false);
  assert.equal(transport.options.auth.user, 'synthetic-user');
  assert.equal(transport.options.auth.pass, 'synthetic-test-password');
  assert.equal(transport.options.tls.rejectUnauthorized, true);
  const env = smtpEnv(587);
  delete env.SMTP_PORT;
  assert.equal(mailFixture(env).createTransport().options.port, 587);
  const tlsTransport = mailFixture(smtpEnv(465, { SMTP_SECURE: 'true' })).createTransport();
  assert.equal(tlsTransport.options.port, 465);
  assert.equal(tlsTransport.options.secure, true);
  assert.equal(tlsTransport.options.tls.rejectUnauthorized, true);
});

test('missing SMTP credentials do not create transport or claim successful delivery', async () => {
  for (const missing of ['SMTP_HOST', 'SMTP_USER', 'SMTP_PASS']) {
    const env = smtpEnv(587);
    delete env[missing];
    const fixture = mailFixture(env);
    assert.equal(fixture.createTransport(), null);
    assert.equal(await fixture.sendEmail({ to: 'parent@example.test', subject: 'Test', html: '<p>Test</p>' }), false);
    assert.match(fixture.warnings[0], /Email provider not configured/);
  }
});

test('production sendEmail authenticates and delivers through real local SMTP', { timeout: 10000 }, async (t) => {
  const smtp = await smtpServer(t);
  const fixture = mailFixture(smtpEnv(smtp.port));
  assert.equal(await fixture.sendEmail({
    to: 'Family <family@b\u00fccher.example>', subject: 'Synthetic reset',
    html: '<a href="https://example.test/reset">Reset</a>',
  }), true);
  assert.ok(smtp.commands.some((line) => line.startsWith('AUTH PLAIN ')));
  assert.ok(smtp.commands.includes('RCPT TO:<family@xn--bcher-kva.example>'));
  assert.equal(smtp.messages.length, 1);
  assert.match(smtp.messages[0], /Subject: Synthetic reset/);
  assert.equal(fixture.warnings.length, 0);
});

test('SMTP rejection propagates instead of reporting delivery success', { timeout: 10000 }, async (t) => {
  const smtp = await smtpServer(t, { rejectRecipient: true });
  const fixture = mailFixture(smtpEnv(smtp.port));
  await assert.rejects(fixture.sendEmail({
    to: 'parent@example.test', subject: 'Test', html: '<p>Test</p>',
  }), (error) => error.code === 'EENVELOPE' && error.responseCode === 550);
  assert.equal(smtp.messages.length, 0);
});

test('Resend priority and errors remain independent of SMTP fallback', async () => {
  const messages = [];
  class FakeResend {
    constructor(key) {
      assert.equal(key, 'synthetic-key');
      this.emails = { send: async (message) => { messages.push(message); return { error: null }; } };
    }
  }
  const mailer = { createTransport() { assert.fail('Resend must not create SMTP transport'); } };
  const fixture = mailFixture({ RESEND_API_KEY: 'synthetic-key' }, mailer, FakeResend);
  assert.equal(await fixture.sendEmail({ to: 'parent@example.test', subject: 'Test', html: '<p>Test</p>' }), true);
  assert.equal(messages[0].to, 'parent@example.test');
  class FailedResend {
    constructor() {
      this.emails = { send: async () => ({ error: { message: 'synthetic rejection' } }) };
    }
  }
  await assert.rejects(mailFixture({ RESEND_API_KEY: 'synthetic-key' }, mailer, FailedResend)
    .sendEmail({ to: 'parent@example.test', subject: 'Test', html: '<p>Test</p>' }), /Resend error: synthetic rejection/);
});

function cloudXmlFixture(responseXml) {
  const storageEntry = require.resolve('@google-cloud/storage');
  const helperFile = path.join(path.dirname(storageEntry), 'transfer-manager.js');
  const module = { exports: {} };
  // Expose the SDK's private helper only in the test, executing its real code.
  const load = vm.compileFunction(
    `${fs.readFileSync(helperFile, 'utf8')}\nreturn XMLMultiPartUploadHelper;`,
    ['require', 'module', 'exports', '__dirname', '__filename'],
    { filename: helperFile },
  );
  const Helper = load(createRequire(helperFile), module, module.exports, path.dirname(helperFile), helperFile);
  const requests = [];
  const bucket = {
    name: 'synthetic-bucket',
    storage: {
      apiEndpoint: 'https://storage.googleapis.com',
      authClient: { request: async (request) => { requests.push(request); return { data: responseXml }; } },
      retryOptions: {
        autoRetry: false, maxRetries: 0, retryDelayMultiplier: 1,
        maxRetryDelay: 1, totalTimeout: 1,
      },
    },
  };
  return { helper: new Helper(bucket, 'synthetic.png'), requests };
}

test('Cloud Storage real multipart XML helper parses upload ID and builds escaped completion XML', async () => {
  const fixture = cloudXmlFixture(
    '<?xml version="1.0"?><InitiateMultipartUploadResult><Bucket>synthetic-bucket</Bucket><UploadId>upload&amp;id</UploadId></InitiateMultipartUploadResult>',
  );
  await fixture.helper.initiateUpload();
  assert.equal(fixture.helper.uploadId, 'upload&id');
  assert.equal(fixture.requests[0].method, 'POST');
  assert.match(fixture.requests[0].url, /^https:\/\/synthetic-bucket\.storage\.googleapis\.com\/synthetic\.png\?uploads$/);
  fixture.helper.partsMap.set(2, '"second"');
  fixture.helper.partsMap.set(1, '"first&part"');
  await fixture.helper.completeUpload();
  const body = fixture.requests[1].body;
  const parts = new XMLParser().parse(body).CompleteMultipartUpload.Part;
  assert.deepEqual(parts.map((part) => part.PartNumber), [1, 2]);
  assert.equal(parts[0].ETag, '"first&part"');
  assert.match(body, /&amp;/);
});

test('Cloud Storage parser rejects repeated DOCTYPE instead of resetting entity limits', async () => {
  const fixture = cloudXmlFixture(
    '<!DOCTYPE a [<!ENTITY first "one">]><!DOCTYPE b [<!ENTITY second "two">]><InitiateMultipartUploadResult><UploadId>&first;&second;</UploadId></InitiateMultipartUploadResult>',
  );
  await assert.rejects(fixture.helper.initiateUpload(), /Multiple DOCTYPE declarations found/);
  assert.equal(fixture.helper.uploadId, '');
  assert.equal(fixture.requests.length, 1);
});

test('AJV consumer retains valid URI/schema behavior with patched fast-uri', () => {
  const Ajv = require('ajv');
  const uri = require('fast-uri');
  assert.equal(uri.parse('https://example.test/path?q=value').host, 'example.test');
  const ajv = new Ajv();
  ajv.addSchema({ $id: 'https://example.test/value', type: 'string' });
  const validate = ajv.compile({ $ref: 'https://example.test/value' });
  assert.equal(validate('synthetic'), true);
  assert.equal(validate(42), false);
});

test('proxy-addr handles IPv4-mapped IPv6 without trusting unrelated addresses', () => {
  const proxyaddr = require('proxy-addr');
  const trust = proxyaddr.compile(['127.0.0.0/8']);
  assert.equal(trust('::ffff:127.0.0.1'), true);
  assert.equal(trust('::ffff:203.0.113.1'), false);
  assert.equal(trust('203.0.113.1'), false);
});
