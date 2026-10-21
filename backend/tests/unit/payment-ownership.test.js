const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');
function block(startMarker, endMarker) {
  const start = source.indexOf(startMarker);
  const end = source.indexOf(endMarker, start);
  assert.ok(start >= 0 && end > start, `Missing block: ${startMarker}`);
  return source.slice(start, end);
}

function fixture(options = {}) {
  const routes = new Map(), globals = [], records = new Map(), intents = new Map(), calls = [];
  let sequence = 0;
  const event = { id: 'event1', hosterId: 'host', costPerPerson: 12.5,
    currency: 'EUR', status: 'upcoming', ...options.event };
  const context = vm.createContext({
    crypto, Buffer, console: { error() {} },
    stripeWebhookSecret: 'unit-test-signing-key', stripeWebhookToleranceSec: 300,
    firebaseRequireAuth: true, backendApiToken: 'unit-test-shared-token',
    WRITE_METHODS: new Set(['POST', 'PUT', 'PATCH', 'DELETE']),
    isNoTokenWritePath: () => false,
    isUserSuspended: async () => false,
    express: { raw: () => (_req, _res, next) => next() },
    firebaseAdmin: { auth: () => ({ verifyIdToken: async token => {
      if (!['payer', 'host', 'stranger'].includes(token)) throw new Error('Invalid token');
      return { uid: token };
    } }) },
    stripe: options.noStripe ? null : {
      paymentIntents: {
        create: async (data, requestOptions) => {
          calls.push(['stripe.create', data, requestOptions]);
          if (options.createFailure) throw new Error('Provider unavailable');
          const intent = { id: `pi_${sequence}`, client_secret: 'secret_not_for_reads',
            ...data, status: 'requires_payment_method', amount_received: 0 };
          intents.set(intent.id, intent); return intent;
        },
        retrieve: async id => {
          calls.push(['stripe.retrieve', id]);
          if (options.providerFailure) throw new Error('Provider unavailable');
          assert.ok(intents.has(id)); return intents.get(id);
        },
      },
      refunds: { create: async (data, requestOptions) => {
        calls.push(['stripe.refund', data, requestOptions]);
        if (options.refundFailure) throw new Error('Refund unavailable');
        return { id: 're_1', payment_intent: data.payment_intent, amount: data.amount,
          currency: 'eur', status: options.refundStatus || 'succeeded', ...options.refund };
      } },
    },
    prisma: {
      event: { findUnique: async () => options.missingEvent ? null : event },
      user: { findUnique: async ({ where }) => ({ id: where.id }) },
      paymentTransaction: {
        create: async ({ data }) => {
          calls.push('db.create');
          if (options.createDbFailure) throw new Error('DB unavailable');
          const item = { id: `order${++sequence}`, createdAt: new Date(), ...data };
          records.set(item.id, item); return item;
        },
        update: async ({ where, data }) => {
          calls.push('db.update');
          const item = { ...records.get(where.id), ...data }; records.set(item.id, item); return item;
        },
        updateMany: async ({ where, data }) => {
          calls.push('db.updateMany');
          if (options.writeFailure) throw new Error('DB unavailable');
          const item = records.get(where.id);
          if (item.status !== where.status) return { count: 0 };
          records.set(item.id, { ...item, ...data }); return { count: 1 };
        },
        findUnique: async ({ where }) => {
          calls.push('db.findUnique');
          if (options.readFailure) throw new Error('DB unavailable');
          return where.id ? records.get(where.id) || null : [...records.values()]
            .find(item => item.stripePaymentIntentId === where.stripePaymentIntentId) || null;
        },
        findMany: async ({ where }) => {
          calls.push(['db.findMany', where]);
          if (options.readFailure) throw new Error('DB unavailable');
          return [...records.values()];
        },
      },
    },
    updateEventPaymentDateIfCompleted: async () => {},
    app: {
      use: handler => globals.push(handler),
      ...Object.fromEntries(['get', 'post'].map(method => [method, (route, ...handlers) => {
        routes.set(`${method.toUpperCase()} ${route}`, [...globals, ...handlers]);
      }])),
    },
  });
  vm.runInContext([
    block('function parseStripeSignatureHeader(', '\n// Missing Admin configuration'),
    block('async function verifyFirebaseIdToken(', '\nfunction resolveVerifiedUserId('),
    block('async function firebaseAuthMiddleware(', '\napp.use(async (req, res, next) => {'),
    block('function paymentError(', '\nfunction mapDbEventStatusToApi('),
    block('function normalizePaymentStatus(', '\nasync function updateEventPaymentDateIfCompleted('),
    block('async function applyProviderTransactionStatusUpdate(', '\nfunction ensureEntitlement('),
    block("app.post('/payments/stripe/webhook',", "\napp.use('/ai/generate'"),
    block('// 18. Payments', '\n// Health Check'),
  ].join('\n'), context);
  assert.ok(source.indexOf('app.use(firebaseAuthMiddleware);') <
    source.indexOf("app.post('/payments/stripe/webhook',"));
  async function request(route, { token = 'payer', body = {}, params = {}, query = {}, headers = {} } = {}) {
    let status = 200, payload, index = 0;
    const [method, requestPath] = route.split(' ');
    const req = { method, path: requestPath, body, params, query,
      headers: { authorization: token ? `Bearer ${token}` : '', ...headers } };
    const res = { status(code) { status = code; return res; }, json(data) { payload = data; return res; } };
    const handlers = routes.get(route);
    assert.ok(handlers, route);
    const next = () => handlers[index++]?.(req, res, next);
    await next(); return { status, body: payload };
  }
  const initiate = () => request('POST /payments/stripe/initiate',
    { body: { eventId: 'event1', hosterId: 'host', amount: 12.5 } });
  async function paidOrder() {
    const response = await initiate(); assert.equal(response.status, 201);
    const record = records.get(response.body.item.id), intent = intents.get(record.stripePaymentIntentId);
    Object.assign(intent, { status: 'succeeded', amount_received: 1250 });
    return { record, intent };
  }
  return { request, initiate, paidOrder, records, intents, calls, context, routes };
}

test('all ten client payment endpoints require verified tokens and reject foreign actor claims', async () => {
  const f = fixture();
  assert.equal(f.routes.size, 11);
  for (const route of f.routes.keys()) {
    if (route === 'POST /payments/stripe/webhook') continue;
    for (const token of [null, 'invalid']) assert.equal((await f.request(route, { token })).status, 401, route);
    for (const body of [{ userId: 'stranger' }, { payerUid: 'stranger' }, { payerId: 'stranger' }]) {
      assert.equal((await f.request(route, { body })).status, 403, route);
    }
    assert.equal((await f.request(route, { query: { userId: 'stranger' } })).status, 403);
  }
  assert.equal(f.calls.length, 0);
});

test('initiate stores payer distinct from host before exposing a bound server-priced intent', async () => {
  const f = fixture(), result = await f.initiate();
  assert.equal(result.status, 201);
  assert.equal(result.body.item.payerUid, 'payer');
  assert.equal(result.body.item.hosterId, 'host');
  assert.equal(result.body.item.amount, 12.5);
  assert.equal(f.calls[0], 'db.create');
  const call = f.calls.find(item => item[0] === 'stripe.create');
  assert.equal(call[1].amount, 1250);
  assert.equal(call[1].currency, 'eur');
  assert.deepEqual({ ...call[1].metadata }, {
    orderId: result.body.item.id, payerUid: 'payer', eventId: 'event1', hosterId: 'host',
  });
});

test('initiate rejects tampered price, currency, host and non-payable saved events', async () => {
  for (const [change, expected] of [[{ amount: 0.01 }, 409], [{ currency: 'usd' }, 409], [{ hosterId: 'stranger' }, 403]]) {
    const f = fixture();
    assert.equal((await f.request('POST /payments/stripe/initiate', {
      body: { eventId: 'event1', amount: 12.5, hosterId: 'host', ...change },
    })).status, expected);
    assert.equal(f.records.size, 0);
  }
  for (const options of [{ missingEvent: true }, { event: { costPerPerson: 0 } },
    { event: { costPerPerson: null } }, { event: { currency: 'USD' } },
    { event: { costPerPerson: 1.005 } }, { event: { status: 'cancelled' } }]) {
    assert.ok([404, 409].includes((await fixture(options).initiate()).status));
  }
});

test('foreign actor and recipient cannot confirm payer intent or read its secret', async () => {
  const f = fixture(), { record } = await f.paidOrder();
  for (const token of ['host', 'stranger']) {
    assert.equal((await f.request('GET /payments/stripe/confirm/:intentId', {
      token, params: { intentId: record.stripePaymentIntentId },
    })).status, 403);
    assert.equal((await f.request('POST /payments/confirm', {
      token, body: { providerTransactionRef: record.stripePaymentIntentId },
    })).status, 403);
  }
  const own = await f.request('GET /payments/stripe/confirm/:intentId', { params: { intentId: 'pi_1' } });
  assert.equal(own.body.item.status, 'completed');
  assert.equal(own.body.item.clientSecret, undefined);
});

test('body proof never completes pending payment; real provider proof completes the same order', async () => {
  const f = fixture(); await f.initiate();
  const body = { providerTransactionRef: 'pi_1', status: 'completed', providerVerified: true };
  assert.equal((await f.request('POST /payments/confirm', { body })).body.item.status, 'pending');
  Object.assign(f.intents.get('pi_1'), { status: 'succeeded', amount_received: 1250 });
  for (let i = 0; i < 2; i++) assert.equal((await f.request('POST /payments/confirm', { body })).body.item.status, 'completed');
  assert.equal(f.records.size, 1);
});

test('confirmation rejects client secrets, unknown intent and conflicting client context', async () => {
  const f = fixture(); await f.paidOrder();
  for (const [body, expected] of [
    [{ providerTransactionRef: 'pi_1_secret_value' }, 400],
    [{ providerTransactionRef: 'pi_unknown' }, 404],
    [{ providerTransactionRef: 'pi_1', eventId: 'foreign' }, 403],
    [{ providerTransactionRef: 'pi_1', hosterId: 'foreign' }, 403],
    [{ providerTransactionRef: 'pi_1', amount: 0.01 }, 409],
    [{ providerTransactionRef: 'pi_1', stripePaymentIntentId: 'pi_other' }, 409],
  ]) assert.equal((await f.request('POST /payments/confirm', { body })).status, expected);
});

test('provider proof must match every order binding and exact received money', async () => {
  for (const mutate of [
    intent => { intent.id = 'pi_other'; },
    ...['payerUid', 'orderId', 'eventId', 'hosterId'].map(key => intent => { intent.metadata[key] = 'foreign'; }),
    intent => { intent.amount = 1; }, intent => { intent.currency = 'usd'; },
    intent => { intent.amount_received = 1; },
  ]) {
    const f = fixture(), { record, intent } = await f.paidOrder(); mutate(intent);
    assert.equal((await f.request('POST /payments/confirm', {
      body: { providerTransactionRef: record.stripePaymentIntentId, providerVerified: true },
    })).status, 409);
    assert.equal(f.records.get(record.id).status, 'pending');
  }
});

test('transaction reads, host lists and status changes enforce stored ownership', async () => {
  const f = fixture(), { record } = await f.paidOrder(), params = { id: record.id };
  for (const route of ['GET /payments/transactions/:id', 'POST /payments/transactions/:id/status',
    'POST /payments/transactions/:id/refund']) {
    assert.equal((await f.request(route, { token: 'stranger', params })).status, 403);
  }
  assert.equal((await f.request('GET /payments/host/:hosterId', { params: { hosterId: 'host' } })).status, 403);
  assert.equal((await f.request('GET /payments/transactions', { query: { hosterId: 'host' } })).status, 403);
  assert.equal((await f.request('GET /payments/transactions', { token: 'stranger' })).body.items.length, 0);
  assert.equal((await f.request('GET /payments/host/:hosterId', { token: 'host', params: { hosterId: 'host' } })).body.items.length, 1);
  assert.equal((await f.request('GET /payments/transactions/:id', { token: 'host', params })).status, 200);
  assert.equal((await f.request('POST /payments/transactions/:id/status', {
    params, body: { status: 'refunded' },
  })).body.item.status, 'completed');
});

test('refund is host-only and requires real successful full provider refund', async () => {
  const f = fixture(), { record } = await f.paidOrder();
  await f.request('POST /payments/confirm', { body: { providerTransactionRef: 'pi_1' } });
  const params = { id: record.id };
  assert.equal((await f.request('POST /payments/transactions/:id/refund', { params })).status, 403);
  const result = await f.request('POST /payments/transactions/:id/refund', { params, token: 'host' });
  assert.equal(result.body.item.status, 'refunded');
  const call = f.calls.find(item => item[0] === 'stripe.refund');
  assert.equal(call[1].payment_intent, 'pi_1'); assert.equal(call[1].amount, 1250);
  assert.equal(call[2].idempotencyKey, `payment-refund:${record.id}`);
});

test('failed, pending or mismatched refunds never simulate success', async () => {
  for (const options of [{ refundFailure: true }, { refundStatus: 'pending' },
    { refund: { payment_intent: 'pi_other' } }, { refund: { amount: 1 } }]) {
    const f = fixture(options), { record } = await f.paidOrder();
    await f.request('POST /payments/confirm', { body: { providerTransactionRef: 'pi_1' } });
    const result = await f.request('POST /payments/transactions/:id/refund', { token: 'host', params: { id: record.id } });
    assert.ok([409, 503].includes(result.status));
    assert.equal(f.records.get(record.id).status, 'completed');
  }
});

test('database and provider failures are explicit, never cached success', async () => {
  for (const options of [{ writeFailure: true }, { providerFailure: true }]) {
    const f = fixture(options); await f.paidOrder();
    assert.equal((await f.request('POST /payments/confirm', { body: { providerTransactionRef: 'pi_1' } })).status, 503);
    assert.equal([...f.records.values()][0].status, 'pending');
  }
  for (const options of [{ createDbFailure: true }, { createFailure: true }, { noStripe: true }]) {
    assert.equal((await fixture(options).initiate()).status, 503);
  }
  assert.equal((await fixture({ readFailure: true }).request('GET /payments/transactions')).status, 503);
});

test('unsupported provider flows and client-submitted provider events fail closed', async () => {
  const f = fixture();
  for (const paymentMethod of ['paypal', 'apple_iap', 'google_play']) {
    assert.equal((await f.request('POST /payments/confirm', { body: { paymentMethod, providerVerified: true } })).status, 503);
  }
  assert.equal((await f.request('POST /payments/paypal/initiate')).status, 503);
  assert.equal((await f.request('POST /payments/provider-events', { body: { verified: true } })).status, 403);
  assert.equal(f.records.size, 0);
});

test('provider event updater retrieves current Stripe state rather than trusting event claims', async () => {
  const f = fixture(), { intent } = await f.paidOrder();
  const update = () => f.context.applyProviderTransactionStatusUpdate({
    provider: 'stripe', providerTransactionRef: intent.id, targetStatus: 'failed', verified: true,
  });
  assert.equal((await update()).item.status, 'completed');
  intent.metadata.orderId = 'foreign';
  assert.equal((await update()).ok, false);
});

test('signed public webhook remains reachable through actual global strict Firebase middleware', async () => {
  const f = fixture(), { record } = await f.paidOrder();
  const body = Buffer.from(JSON.stringify({ type: 'payment_intent.succeeded', data: { object: { id: 'pi_1' } } }));
  const route = 'POST /payments/stripe/webhook', before = f.calls.length;
  assert.equal((await f.request(route, { token: null, body })).status, 400);
  assert.equal((await f.request(route, { token: null, body, headers: { 'stripe-signature': 't=1,v1=invalid' } })).status, 400);
  assert.equal(f.calls.length, before);
  const timestamp = Math.floor(Date.now() / 1000);
  const signature = crypto.createHmac('sha256', 'unit-test-signing-key').update(`${timestamp}.${body.toString('utf8')}`).digest('hex');
  const result = await f.request(route, { token: null, body, headers: { 'stripe-signature': `t=${timestamp},v1=${signature}` } });
  assert.equal(result.status, 200); assert.equal(result.body.status, 'completed');
  assert.equal(f.records.get(record.id).verifiedByType, 'webhook');
});

test('global Firebase public write exemption is limited to the exact Stripe webhook', async () => {
  const f = fixture();
  for (const [method, requestPath] of [['POST', '/payments/stripe/webhook/extra'],
    ['POST', '/payments/stripe/webhook/'],
    ['POST', '/payments/provider-events'], ['POST', '/payments/stripe/initiate']]) {
    let status, continued = false;
    const res = { status(code) { status = code; return this; }, json() { return this; } };
    await f.context.firebaseAuthMiddleware({ method, path: requestPath, headers: {} }, res, () => { continued = true; });
    assert.equal(status, 401); assert.equal(continued, false);
  }
});

test('retryable declines stay pending and can complete after provider-side retry', async () => {
  const f = fixture(); await f.initiate();
  const intent = f.intents.get('pi_1'), body = { providerTransactionRef: 'pi_1' };
  intent.last_payment_error = { code: 'card_declined' };
  assert.equal((await f.request('POST /payments/confirm', { body })).body.item.status, 'pending');
  Object.assign(intent, { status: 'succeeded', amount_received: 1250 });
  assert.equal((await f.request('POST /payments/confirm', { body })).body.item.status, 'completed');
});

test('only full matching provider charge refund marks order refunded', async () => {
  const f = fixture(), { record, intent } = await f.paidOrder(), params = { id: record.id };
  intent.latest_charge = { refunded: false, amount_refunded: 500, payment_intent: intent.id, currency: 'eur' };
  assert.equal((await f.request('POST /payments/transactions/:id/status', { params })).body.item.status, 'completed');
  Object.assign(intent.latest_charge, { refunded: true, amount_refunded: 1250 });
  assert.equal((await f.request('POST /payments/transactions/:id/status', { params })).body.item.status, 'refunded');
});

test('legacy unbound payment rows cannot establish payer or authorize movement of money', async () => {
  const f = fixture(), { record } = await f.paidOrder();
  f.records.set(record.id, { ...record, userId: 'host', auditDetails: { hosterId: 'host', paymentMethod: 'stripe' } });
  assert.equal((await f.request('POST /payments/confirm', { token: 'host', body: { providerTransactionRef: 'pi_1' } })).status, 403);
  assert.equal((await f.request('POST /payments/transactions/:id/refund', { token: 'host', params: { id: record.id } })).status, 409);
});
