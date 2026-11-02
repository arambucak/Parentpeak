// Checks Prisma mock writes against the real Prisma schema.
// Unit tests mock Prisma; without this guard a write with a field the schema
// does not know (e.g. `phoneVerified`) passes in tests and fails in production
// with PrismaClientValidationError.
//
// Source of truth: Prisma.dmmf from the generated client. CI restores backend
// dependencies with --ignore-scripts (no `prisma generate`); then the guard
// reads backend/prisma/schema.prisma directly with the same checks.
const fs = require('node:fs');
const path = require('node:path');

const SOURCE_SCHEMA = path.join(__dirname, '../../../prisma/schema.prisma');

const WRITE_METHODS = new Set([
  'create', 'createMany', 'createManyAndReturn', 'upsert', 'update', 'updateMany', 'updateManyAndReturn',
]);

// Returns Map<modelName, Map<fieldName, { type, isRequired }>>. A field is
// required when its type has neither `?` nor `[]`.
function parseSchemaModels(schemaPath) {
  const models = new Map();
  let current = null;
  for (const rawLine of fs.readFileSync(schemaPath, 'utf8').split(/\r?\n/)) {
    const line = rawLine.replace(/\/\/.*$/, '').trim();
    const modelStart = /^model\s+(\w+)\s*\{/.exec(line);
    if (modelStart) {
      current = new Map();
      models.set(modelStart[1], current);
    } else if (line === '}') {
      current = null;
    } else if (current && line && !line.startsWith('@@')) {
      const field = /^(\w+)\s+(\w+)(\[\])?(\?)?/.exec(line);
      if (field) current.set(field[1], { type: field[2], isRequired: !field[3] && !field[4] });
    }
  }
  return models;
}

const fieldNames = fields => [...fields.keys()].sort().join(',');

function loadGeneratedDmmf() {
  let Prisma;
  try {
    ({ Prisma } = require('@prisma/client'));
  } catch {
    return null;
  }
  return Prisma?.dmmf?.datamodel ? Prisma.dmmf.datamodel : null;
}

function buildModels() {
  const sourceModels = parseSchemaModels(SOURCE_SCHEMA);
  const dmmf = loadGeneratedDmmf();
  if (!dmmf) {
    return { origin: 'backend/prisma/schema.prisma (Prisma client not generated)', models: sourceModels };
  }
  // Prisma 7 trims nullability from the runtime DMMF; the generated schema copy keeps it.
  const generatedSchema = path.join(path.dirname(require.resolve('.prisma/client/default')), 'schema.prisma');
  const generatedModels = parseSchemaModels(generatedSchema);
  const models = new Map();
  for (const model of dmmf.models) {
    const dmmfFields = new Map(model.fields.map(field => [field.name, field]));
    const generated = generatedModels.get(model.name);
    const source = sourceModels.get(model.name);
    if (!generated || fieldNames(generated) !== fieldNames(dmmfFields)) {
      throw new Error(`Generated schema copy and Prisma.dmmf disagree for ${model.name}`);
    }
    if (!source || fieldNames(source) !== fieldNames(dmmfFields)) {
      throw new Error(
        `Generated Prisma client is stale for ${model.name}; run \`cd backend && npx prisma generate\``,
      );
    }
    models.set(model.name, new Map(model.fields.map(field => [
      field.name, { type: field.type, isRequired: generated.get(field.name).isRequired },
    ])));
  }
  if (models.size !== sourceModels.size) {
    throw new Error('Generated Prisma client is stale; run `cd backend && npx prisma generate`');
  }
  return { origin: 'Prisma.dmmf (generated client)', models };
}

const { origin: schemaOrigin, models: schemaModels } = buildModels();

const modelsByDelegate = new Map([...schemaModels].map(([name, fields]) => [
  name.charAt(0).toLowerCase() + name.slice(1),
  {
    name,
    fields: new Map([...fields].map(([fieldName, field]) => [fieldName, {
      ...field, kind: schemaModels.has(field.type) ? 'object' : 'scalar',
    }])),
  },
]));

class SchemaGuardError extends Error {
  constructor(message) {
    super(message);
    this.name = 'SchemaGuardError';
  }
}

function checkData(model, method, part, data) {
  if (data === undefined) return;
  if (Array.isArray(data)) {
    data.forEach((item, index) => checkData(model, method, `${part}[${index}]`, item));
    return;
  }
  if (data === null || typeof data !== 'object') {
    throw new SchemaGuardError(`${model.name}.${method} ${part}: data must be an object`);
  }
  for (const [key, value] of Object.entries(data)) {
    const field = model.fields.get(key);
    if (!field) {
      throw new SchemaGuardError(`${model.name}.${method} ${part}: Unknown argument \`${key}\``);
    }
    if (value === null && field.isRequired && field.kind !== 'object') {
      throw new SchemaGuardError(
        `${model.name}.${method} ${part}: Argument \`${key}\` must not be null (${field.type})`,
      );
    }
  }
}

function assertWriteMatchesSchema(delegate, method, args = {}) {
  const model = modelsByDelegate.get(delegate);
  if (!model) throw new SchemaGuardError(`Unknown Prisma model delegate \`${delegate}\``);
  if (method === 'upsert') {
    checkData(model, method, 'create', args.create);
    checkData(model, method, 'update', args.update);
  } else {
    checkData(model, method, 'data', args.data);
  }
}

// Wraps a Prisma mock; every write method is validated before the mock runs.
function withSchemaGuard(prismaMock) {
  return new Proxy(prismaMock, {
    get(target, delegate, receiver) {
      const value = Reflect.get(target, delegate, receiver);
      if (typeof delegate !== 'string' || !modelsByDelegate.has(delegate) || !value) return value;
      return new Proxy(value, {
        get(delegateTarget, method, delegateReceiver) {
          const fn = Reflect.get(delegateTarget, method, delegateReceiver);
          if (typeof fn !== 'function' || !WRITE_METHODS.has(method)) return fn;
          return (args, ...rest) => {
            assertWriteMatchesSchema(delegate, method, args);
            return fn.call(delegateTarget, args, ...rest);
          };
        },
      });
    },
  });
}

module.exports = {
  assertWriteMatchesSchema, withSchemaGuard, SchemaGuardError, schemaOrigin, parseSchemaModels,
};
