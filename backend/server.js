const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const nodemailer = require('nodemailer');
const { Resend } = require('resend');
const Stripe = require('stripe');
require('dotenv').config(); // Load environment variables
const { Pool } = require('pg');
const { PrismaPg } = require('@prisma/adapter-pg');
const { PrismaClient } = require('@prisma/client');
const multer = require('multer');
const { changeParticipation, updateOwnedEvent, validateEventMode, CONFIRMED } = require('./event_participation_policy');
const { publicTreasure } = require('./treasure_public_view');
const treasureGeometry = require('./treasure_geometry');
const { MEMORY_CONSENT_VERSION, hasMemoryConsent, buildMemoryContext, minimizeMemoryText } = require('./ai_memory_policy');
const { readEntitlementSnapshot } = require('./entitlement_store');
const { readAdsConsent, setAdsConsent } = require('./ads_consent_store');

// Firebase Admin — initialised lazily so the server starts without credentials
// in local dev. Set GOOGLE_APPLICATION_CREDENTIALS or FIREBASE_SERVICE_ACCOUNT_JSON.
let firebaseAdmin = null;
let firebaseStorageBucket = (process.env.FIREBASE_STORAGE_BUCKET || '').trim();
try {
  const {
    applicationDefault,
    cert,
    getApps,
    initializeApp,
  } = require('firebase-admin/app');
  const { getAuth } = require('firebase-admin/auth');
  const { getMessaging } = require('firebase-admin/messaging');
  const { getStorage } = require('firebase-admin/storage');
  const serviceAccountJson = (process.env.FIREBASE_SERVICE_ACCOUNT_JSON || '').trim();
  if (serviceAccountJson) {
    const serviceAccount = JSON.parse(serviceAccountJson);
    firebaseStorageBucket =
      firebaseStorageBucket ||
      (serviceAccount.project_id
        ? `${serviceAccount.project_id}.firebasestorage.app`
        : '');
    if (getApps().length === 0) {
      initializeApp({
        credential: cert(serviceAccount),
        ...(firebaseStorageBucket ? { storageBucket: firebaseStorageBucket } : {}),
      });
    }
    firebaseAdmin = { auth: getAuth, messaging: getMessaging, storage: getStorage };
    console.log('🔑 Firebase Admin SDK initialisiert');
  } else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    if (getApps().length === 0) {
      initializeApp({
        credential: applicationDefault(),
        ...(firebaseStorageBucket ? { storageBucket: firebaseStorageBucket } : {}),
      });
    }
    firebaseAdmin = { auth: getAuth, messaging: getMessaging, storage: getStorage };
    console.log('🔑 Firebase Admin SDK initialisiert (Application Default Credentials)');
  }
} catch (err) {
  console.warn('⚠️  Firebase Admin SDK nicht verfügbar:', err.message);
}

// Multer for image uploads — stored under uploads/ (create if missing)
const uploadsDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}
const multerStorage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, uploadsDir),
  filename: (_req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    cb(null, `${Date.now()}-${crypto.randomBytes(6).toString('hex')}${ext}`);
  },
});
const upload = multer({
  storage: multerStorage,
  // This image endpoint does not consume array-valued multipart metadata.
  limits: { fileSize: 10 * 1024 * 1024, fieldArrayIndexLimit: 0 }, // 10 MB
  fileFilter: (_req, file, cb) => {
    const allowed = new Set(['image/jpeg', 'image/png', 'image/webp', 'image/gif']);
    if (allowed.has(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Nur JPEG, PNG, WebP und GIF sind erlaubt'));
    }
  },
});

const databaseUrl = (process.env.DATABASE_URL || '').trim();
const useDatabaseSsl = /render\.com/i.test(databaseUrl);
// Standard: rejectUnauthorized=false, weil Renders DB-Zertifikat die
// Standard-CA-Pruefung nicht besteht und die Verbindung sonst in Produktion
// bricht. Sobald Renders CA-Zertifikat vorliegt, kann strikte Pruefung per
// DATABASE_SSL_STRICT=1 aktiviert werden (optional PG-CA ueber DATABASE_SSL_CA).
const databaseSslStrict = `${process.env.DATABASE_SSL_STRICT || ''}`.toLowerCase() === '1'
  || `${process.env.DATABASE_SSL_STRICT || ''}`.toLowerCase() === 'true';
const databaseSslCa = (process.env.DATABASE_SSL_CA || '').trim();
const databaseSslConfig = useDatabaseSsl
  ? {
      rejectUnauthorized: databaseSslStrict,
      ...(databaseSslCa ? { ca: databaseSslCa } : {}),
    }
  : undefined;
const prismaPool = new Pool({
  connectionString: databaseUrl,
  ssl: databaseSslConfig,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
  query_timeout: 15000,
  statement_timeout: 15000,
});

// Retry logic for Prisma connection
let prismaRetries = 0;
const MAX_RETRIES = 3;
let prisma = null;

async function initializePrisma() {
  try {
    const prismaAdapter = new PrismaPg(prismaPool);
    prisma = new PrismaClient({
      adapter: prismaAdapter,
      log: ['error'],
      errorFormat: 'pretty',
    });
    // Test connection
    await prisma.$queryRaw`SELECT 1`;
    console.log('✅ Prisma Client initialisiert & Datenbankverbindung geprüft');
    prismaRetries = 0;
    return prisma;
  } catch (err) {
    if (prismaRetries < MAX_RETRIES) {
      prismaRetries++;
      console.warn(`⚠️  Prisma-Verbindung fehlgeschlagen (Versuch ${prismaRetries}/${MAX_RETRIES}): ${err.message}`);
      await new Promise(resolve => setTimeout(resolve, 2000 * prismaRetries));
      return initializePrisma();
    } else {
      console.error(`❌ Prisma-Verbindung nach ${MAX_RETRIES} Versuchen fehlgeschlagen. In-Memory-Fallback wird verwendet.`);
      return null;
    }
  }
}

const app = express();
const PORT = Number.parseInt(process.env.PORT || '3000', 10);
const backendApiToken = (process.env.BACKEND_API_TOKEN || '').trim();
const geminiApiKey = (process.env.GEMINI_API_KEY || '').trim();
// Moderations-Admins: kommagetrennte Firebase-UIDs aus der Render-Env.
// Niemals hardcodiert — nur ueber ADMIN_USER_IDS konfiguriert.
const adminUserIds = new Set(
  (process.env.ADMIN_USER_IDS || '')
    .split(',')
    .map(id => id.trim())
    .filter(Boolean)
);
const requireAuthForWrites =
  (process.env.REQUIRE_AUTH_FOR_WRITES ||
    (process.env.NODE_ENV === 'production' ? '1' : '0')) === '1';
const disableInMemoryFallbacks =
  (process.env.DISABLE_IN_MEMORY_FALLBACKS || '1') === '1';
const allowedOrigins = (process.env.CORS_ALLOWED_ORIGINS || '')
  .split(',')
  .map(origin => origin.trim())
  .filter(Boolean);
const stripeWebhookSecret = (process.env.STRIPE_WEBHOOK_SECRET || '').trim();
const otpHashSecret = (process.env.OTP_HASH_SECRET || '').trim();
const stripeWebhookToleranceSec = Number.parseInt(
  process.env.STRIPE_WEBHOOK_TOLERANCE_SEC || '300',
  10,
);
const stripeSecretKey = (process.env.STRIPE_SECRET_KEY || '').trim();
const isProduction = process.env.NODE_ENV === 'production';

if (!otpHashSecret) {
  console.warn('⚠️ OTP_HASH_SECRET fehlt — OTP Hashing nutzt temporären Prozess-Secret.');
}

const runtimeOtpHashSecret = otpHashSecret || crypto.randomBytes(32).toString('hex');

// Stripe client — initialized if secret key is available.
let stripe = null;
if (stripeSecretKey) {
  stripe = new Stripe(stripeSecretKey, { apiVersion: '2024-04-10' });
  console.log('✅ Stripe SDK mit echtem API-Schlüssel initialisiert');
} else {
  console.error('❌ STRIPE_SECRET_KEY nicht gesetzt — Stripe-Zahlungen sind deaktiviert');
}
const allowClientProviderEvents =
  (process.env.ALLOW_CLIENT_PROVIDER_EVENTS ||
    (process.env.NODE_ENV === 'production' ? '0' : '1')) === '1';
const internalModeratorEmails = (process.env.INTERNAL_MODERATOR_EMAILS || '')
  .split(',')
  .map(item => item.trim().toLowerCase())
  .filter(Boolean);
const internalModeratorDomains = (process.env.INTERNAL_MODERATOR_DOMAINS || 'parentpeak.de,parentpeak.com')
  .split(',')
  .map(item => item.trim().toLowerCase())
  .filter(Boolean);
const allowDemoBootstrap =
  process.env.NODE_ENV !== 'production' &&
  (process.env.ALLOW_DEMO_BOOTSTRAP || '1') === '1';

const writeRateWindowMs = Number.parseInt(
  process.env.WRITE_RATE_LIMIT_WINDOW_MS || `${15 * 60 * 1000}`,
  10,
);
const writeRateMax = Number.parseInt(
  process.env.WRITE_RATE_LIMIT_MAX || '120',
  10,
);
const writeRateBuckets = new Map();

// Dediziertes, strengeres Limit für den teuren KI-Endpunkt (/ai/generate).
// Schützt die Gemini-Kosten gegen Missbrauch durch ein einzelnes (eingeloggtes)
// Konto. Pro Firebase-UID (Fallback: IP). Default: 30 Anfragen / 15 Min —
// großzügig für normale Nutzung, aber eine harte Obergrenze gegen Abuse.
const aiRateWindowMs = Number.parseInt(
  process.env.AI_RATE_LIMIT_WINDOW_MS || `${15 * 60 * 1000}`,
  10,
);
const aiRateMax = Number.parseInt(
  process.env.AI_RATE_LIMIT_MAX || '30',
  10,
);
const aiRateBuckets = new Map();

// Globales Tagesbudget für ALLE KI-Aufrufe zusammen (Hard-Cap gegen
// Kosten-Explosion, selbst bei vielen Konten oder einer koordinierten
// Attacke). Default 2000 Calls/Tag; 0 deaktiviert das Cap. Zählt pro
// UTC-Kalendertag und setzt sich automatisch um Mitternacht zurück.
const aiDailyBudgetMax = Number.parseInt(
  process.env.AI_DAILY_BUDGET_MAX || '2000',
  10,
);
const aiDailyBudget = { day: '', count: 0 };

// Reine, testbare Rate-Limit-Prüfung (Sliding-Window pro Schlüssel).
// Gibt true zurück, wenn die Anfrage erlaubt ist, false bei Überschreitung.
function checkRateLimit(buckets, key, { windowMs, max, now = Date.now() }) {
  const bucket = buckets.get(key);
  if (!bucket || now - bucket.start > windowMs) {
    buckets.set(key, { start: now, count: 1 });
    return true;
  }
  bucket.count += 1;
  return bucket.count <= max;
}

// Reine, testbare Tagesbudget-Prüfung. [state] = {day, count} wird mutiert.
// max <= 0 bedeutet "kein Cap". Gibt true zurück, wenn erlaubt.
function checkDailyBudget(state, max, now = new Date()) {
  if (!Number.isFinite(max) || max <= 0) return true;
  const day = now.toISOString().slice(0, 10); // UTC-Kalendertag
  if (state.day !== day) {
    state.day = day;
    state.count = 0;
  }
  state.count += 1;
  return state.count <= max;
}
const DEMO_USER_ID = 'host_demo_001';
const DEMO_FAMILY_ID = 'demo-family-001';
const weeklyImpulseCommunityState = new Map();
const weeklyImpulseVerificationRequests = [];
const weeklyImpulseVerifiedExperts = new Map();

const WRITE_METHODS = new Set(['POST', 'PUT', 'PATCH', 'DELETE']);

function isWriteRequest(req) {
  return WRITE_METHODS.has(req.method);
}

function getClientIp(req) {
  const xff = req.headers['x-forwarded-for'];
  if (typeof xff === 'string' && xff.trim()) {
    return xff.split(',')[0].trim();
  }
  return req.ip || req.socket?.remoteAddress || 'unknown';
}

function respondWithStrictPersistenceError(res, routeLabel, error) {
  console.error(`${routeLabel} fallback (in-memory):`, error?.message || error);
  if (!disableInMemoryFallbacks) {
    return false;
  }

  res.status(503).json({
    error: 'Persistenzfehler: In-Memory-Fallback ist deaktiviert.',
    route: routeLabel,
  });
  return true;
}

function getWeeklyImpulseCommunityEntry(impulseId) {
  if (!weeklyImpulseCommunityState.has(impulseId)) {
    weeklyImpulseCommunityState.set(impulseId, {
      customPosts: [],
      likedByPostId: {},
      commentsByPostId: {},
      reportsByPostId: {},
      hiddenPostIds: {},
    });
  }

  return weeklyImpulseCommunityState.get(impulseId);
}

function getVerifiedExpertRecord({ userId, email }) {
  const normalizedUserId = typeof userId === 'string' ? userId.trim() : '';
  const normalizedEmail = typeof email === 'string' ? email.trim().toLowerCase() : '';

  if (normalizedUserId && weeklyImpulseVerifiedExperts.has(`user:${normalizedUserId}`)) {
    return weeklyImpulseVerifiedExperts.get(`user:${normalizedUserId}`);
  }
  if (normalizedEmail && weeklyImpulseVerifiedExperts.has(`email:${normalizedEmail}`)) {
    return weeklyImpulseVerifiedExperts.get(`email:${normalizedEmail}`);
  }
  return null;
}

function isInternalModeratorEmail(email) {
  if (!email || typeof email !== 'string') return false;
  const normalized = email.trim().toLowerCase();
  if (!normalized) return false;
  if (internalModeratorEmails.includes(normalized)) return true;
  return internalModeratorDomains.some(domain => normalized.endsWith(`@${domain}`));
}

function requireInternalModerator(req, res, next) {
  const identity = req.firebaseIdentity;
  if (!identity?.emailVerified || !isInternalModeratorEmail(identity.email)) {
    return res.status(403).json({ error: 'Moderationszugriff nicht erlaubt' });
  }
  return next();
}

function storeVerifiedExpertRecord(record) {
  if (record.userId) {
    weeklyImpulseVerifiedExperts.set(`user:${record.userId}`, record);
  }
  if (record.email) {
    weeklyImpulseVerifiedExperts.set(`email:${record.email.toLowerCase()}`, record);
  }
}

// Pool of 28 daily impulse topics, cycled by day-of-year.
const DAILY_IMPULSE_POOL = [
  {
    key: 'gfk_warum',
    title: 'Warum-Fragen gelassen begleiten',
    category: 'gfk',
    parent_lens: "Dein Kind stellt dir 100-mal am Tag die Frage 'Warum?'. Das tut es nicht, um dich zu nerven, sondern weil sein Gehirn Verbindungen knüpft. Es will die Welt begreifen.",
    parent_tips: [
      "Nutze die Giraffensprache (GfK): Benenne deine eigenen Gefühle und Bedürfnisse klar, statt zu schimpfen.",
      "Beantworte die 'Warum'-Fragen kurz und simpel – dein Kind sucht Logik, keine wissenschaftlichen Vorträge.",
      "Setze Grenzen liebevoll durch persönliche Präsenz ('Ich möchte nicht, dass du haust'), statt durch Strafen.",
    ],
    practical_tip: "Bei der nächsten Warum-Frage: erst das Gefühl spiegeln ('Du bist neugierig!'), dann in einem Satz antworten.",
    discussion_body: "Welche kurze, ruhige Formulierung hilft euch, wenn euer Kind zum zehnten Mal nach dem Warum fragt?",
    companion_quick: "Wähle heute nur eine ruhige Antwort auf eine Warum-Frage und bleib danach bewusst kurz.",
    companion_reflect: "Wann hat dein Kind heute besonders viele Verbindungen gesucht – und wie konntest du ruhig Orientierung geben?",
  },
  {
    key: 'gfk_grenzen',
    title: 'Grenzen liebevoll und klar setzen',
    category: 'gfk',
    parent_lens: "Liebevolle Grenzen sind kein Widerspruch. Kinder brauchen beides: das Gefühl, geliebt zu sein, UND klare Orientierung, was nicht geht. Grenzen ohne Verbindung wirken wie Mauern – Grenzen mit Verbindung wirken wie Leitplanken.",
    parent_tips: [
      "Benenne zuerst das Gefühl deines Kindes, dann die Grenze: 'Ich sehe, du bist wütend. Und trotzdem: Hauen geht nicht.'",
      "Bleib körperlich ruhig – dein Ton ist lauter als deine Worte. Ein tiefer Atemzug vor der Reaktion hilft.",
      "Konsequenzen ansagen und einhalten. Nicht drohen, sondern ankündigen: 'Wenn du ... dann ...'",
    ],
    practical_tip: "Übe heute einen Satz mit Gefühl + Grenze: 'Ich verstehe, dass du das willst. Und: Nein.' – und dabei ruhig bleiben.",
    discussion_body: "Wie reagiert ihr, wenn ihr selbst an eure Grenzen geratet? Welcher Satz hilft euch, ruhig zu bleiben?",
    companion_quick: "Einmal tief einatmen vor der nächsten Grenzreaktion – das ist schon halbe Miete.",
    companion_reflect: "Gab es heute eine Situation, in der eine ruhige Grenze besser funktioniert hat als ein lautes Nein?",
  },
  {
    key: 'gfk_ichbotschaft',
    title: 'Ich-Botschaften statt Du-Vorwürfe',
    category: 'gfk',
    parent_lens: "Du-Botschaften ('Du bist so laut!') lösen Abwehr aus. Ich-Botschaften ('Ich werde müde und brauche Ruhe') öffnen Türen. Kinder hören mehr zu, wenn sie sich nicht angegriffen fühlen.",
    parent_tips: [
      "Forme Vorwürfe zu Ich-Botschaften um: statt 'Du hörst nie zu' → 'Ich fühle mich nicht gehört und das macht mich traurig.'",
      "Teile dein Bedürfnis mit: 'Ich brauche jetzt kurz Stille, um nachzudenken.' Kinder verstehen Bedürfnisse erstaunlich gut.",
      "Übe im Alltag: Formuliere drei klassische Sätze als Ich-Botschaft um – morgens beim Zähneputzen, mittags beim Essen, abends beim Einschlafen.",
    ],
    practical_tip: "Wähle heute eine Situation, in der du sonst 'Du immer...' sagst – und ersetze sie durch 'Ich fühle ... weil ich ... brauche.'",
    discussion_body: "Welche Du-Botschaft fällt euch am schwersten umzuformulieren? Und was hilft dabei?",
    companion_quick: "Gefühl + Bedürfnis benennen – das ist die Formel für eine echte Ich-Botschaft.",
    companion_reflect: "Hat eine Ich-Botschaft heute eine Reaktion ausgelöst, die dich überrascht hat?",
  },
  {
    key: 'gfk_trotz',
    title: 'Trotzphasen gelassen begleiten',
    category: 'gfk',
    parent_lens: "Trotz ist keine Rebellion – er ist Entwicklung. Wenn ein Kind auf dem Boden liegt und schreit, ist sein präfrontaler Kortex schlicht noch nicht ausgereift genug, um die Emotion zu regulieren. Es braucht dich als Co-Regulierer.",
    parent_tips: [
      "Bleib körperlich nah, ohne zu zwingen: Auf Kniehöhe gehen, ruhig sprechen, nicht anfassen wenn das Kind es ablehnt.",
      "Vermeide Diskussionen mitten im Sturm. Erst wenn es sich beruhigt hat, kommt das Gespräch.",
      "Verwende 'Gefühl-Brücken': 'Du wolltest das Eis. Das war dir so wichtig. Ich verstehe das.'",
    ],
    practical_tip: "Wenn dein Kind außer sich ist: Setz dich daneben. Nicht weg, nicht eingreifen – einfach da sein. Das reguliert schon.",
    discussion_body: "Was hilft euch selbst ruhig zu bleiben, wenn euer Kind mitten in einem emotionalen Ausbruch ist?",
    companion_quick: "Drei Worte für Trotzphasen: Nah bleiben. Ruhig atmen. Abwarten.",
    companion_reflect: "Was hat dich heute am meisten Kraft gekostet – und was hat dir geholfen, dabei gelassen zu bleiben?",
  },
  {
    key: 'gfk_geschwister',
    title: 'Geschwisterstreit als Lernfeld nutzen',
    category: 'gfk',
    parent_lens: "Geschwister streiten – das ist normal und sogar wichtig. Im Streit lernen Kinder Kompromisse, Perspektivwechsel und Selbstbehauptung. Deine Rolle ist die des Moderators, nicht des Richters.",
    parent_tips: [
      "Kein Partei ergreifen: 'Ich sehe, dass ihr beide gerade wütend seid. Ich höre zuerst dich, dann dich.'",
      "Lass Kinder Lösungen selbst finden, wenn die Situation nicht eskaliert. Eingreifen erst bei Gefahr.",
      "Stärke jedes Kind einzeln: regelmäßige 1:1-Momente ohne Geschwister reduzieren Eifersucht langfristig.",
    ],
    practical_tip: "Beim nächsten Streit: Beide Kinder fragen 'Was brauchst du gerade?' – bevor du entscheidest wer Recht hat.",
    discussion_body: "Wie hanhabt ihr es, wenn Geschwister streiten? Was funktioniert bei euch am besten?",
    companion_quick: "Moderator statt Richter – das ist deine Rolle bei Geschwisterkonflikten.",
    companion_reflect: "Gab es heute einen Moment, in dem deine Kinder einen Streit selbst gelöst haben? Was habt ihr dabei gelernt?",
  },
  {
    key: 'gfk_gefühle',
    title: 'Gefühle benennen und anerkennen',
    category: 'gfk',
    parent_lens: "Kinder, die ihre Gefühle benennen können, haben einen massiven Vorteil: Sie können kommunizieren, was sie brauchen. Dieser Schritt – vom Fühlen zum Sprechen – braucht Übung und deine Unterstützung.",
    parent_tips: [
      "Nutze das 'Gefühlsbarometer': Frage abends 'Wie war dein Tag auf einer Skala von 1-5?' – und erzähle selbst zuerst.",
      "Benenne eigene Gefühle laut: 'Ich bin gerade ein bisschen gestresst, weil ich viel nachdenken muss.' Modelllernen wirkt.",
      "Lese Kinderbücher über Gefühle – und halte danach inne: 'Was hat die Figur wohl gefühlt? Und du?'",
    ],
    practical_tip: "Stell heute Abend die Frage: 'Was hat dich heute froh gemacht? Was hat dich traurig oder wütend gemacht?' – und hör einfach zu.",
    discussion_body: "Welches Gefühl fällt eurem Kind besonders schwer zu benennen? Wie begegnet ihr dem?",
    companion_quick: "Erst fühlen, dann benennen – das Gefühls-ABC beginnt mit dir als Vorbild.",
    companion_reflect: "Welchen Gefühlsmoment eures Kindes wolltet ihr heute festhalten?",
  },
  {
    key: 'gfk_nein',
    title: 'Nein sagen – ohne schlechtes Gewissen',
    category: 'gfk',
    parent_lens: "Eltern, die nie Nein sagen, erziehen Kinder, die Grenzen nicht kennen. Ein liebevolles Nein zeigt deinem Kind: Ich nehme meine Bedürfnisse ernst – und das darfst du auch.",
    parent_tips: [
      "Ein Nein braucht keine lange Erklärung. Ein klares 'Nein, das geht jetzt nicht' ist vollständig.",
      "Schuld nach einem Nein ist ein Signal, kein Fehler. Frage dich: Ist das Nein wirklich falsch – oder nur unbequem?",
      "Übe das Nein auch gegenüber anderen Erwachsenen (Spielverabredungen, Zusagen) – dein Kind lernt durch dein Vorbild.",
    ],
    practical_tip: "Sag heute einmal bewusst Nein – ohne dich zu entschuldigen. Spüre nach, wie es sich anfühlt.",
    discussion_body: "Wann fällt es euch am schwersten, Nein zu sagen – zu euren Kindern, oder zu anderen?",
    companion_quick: "Ein Nein zu einer Sache ist ein Ja zu etwas Wichtigerem – meistens zu dir selbst.",
    companion_reflect: "Gab es heute ein Nein, das sich rückblickend richtig angefühlt hat?",
  },
  {
    key: 'inclusion_stärken',
    title: 'Stärken sehen statt Schwächen bewerten',
    category: 'inclusion',
    parent_lens: "Jedes Kind hat eine einzigartige Stärken-Konstellation. Oft sehen wir als Eltern zuerst die Baustellen – dabei wären wir die ersten, die den Rohdiamanten polieren könnten.",
    parent_tips: [
      "Schreib heute Abend 3 Stärken deines Kindes auf – nicht Leistungen, sondern Charaktereigenschaften ('neugierig', 'fürsorglich', 'hartnäckig').",
      "Benenne Stärken konkret und zeitnah: 'Das warst du so geduldig gerade – das ist echt toll.'",
      "Vermeide Vergleiche mit Geschwistern oder anderen Kindern. Jede Entwicklungskurve ist einzigartig.",
    ],
    practical_tip: "Sprich heute mit deinem Kind über eine seiner Stärken – nicht als Lob, sondern als Beobachtung: 'Ich habe heute gesehen, wie du ...'",
    discussion_body: "Welche verborgene Stärke eures Kindes möchtet ihr heute teilen?",
    companion_quick: "Stärken sehen heißt nicht, Schwächen ignorieren – es heißt, Wachstum ermöglichen.",
    companion_reflect: "Welche Stärke deines Kindes hat dich heute überrascht oder beeindruckt?",
  },
  {
    key: 'inclusion_selbstwert',
    title: 'Selbstwert täglich aufbauen',
    category: 'inclusion',
    parent_lens: "Selbstwert entsteht nicht durch Lob allein – er entsteht durch das Erleben: 'Ich kann etwas. Ich bin wichtig. Ich gehöre dazu.' Du kannst alle drei Erfahrungen täglich einbauen.",
    parent_tips: [
      "Lass dein Kind kleine Entscheidungen treffen: 'Willst du erst die Aufgaben machen oder erst spielen?' Autonomie = Selbstwert.",
      "Zeig echtes Interesse: Leg das Handy weg, schau ins Gesicht, frage nach. 10 Minuten volle Aufmerksamkeit wirken Wunder.",
      "Feiere den Prozess, nicht nur das Ergebnis: 'Du hast das so lange probiert – das ist der wichtige Teil.'",
    ],
    practical_tip: "Heute: 10 Minuten ungeteilte Aufmerksamkeit für dein Kind – kein Handy, keine Ablenkung, nur Interesse.",
    discussion_body: "Was macht euer Kind besonders stolz auf sich – und wie unterstützt ihr dieses Gefühl?",
    companion_quick: "Selbstwert kommt nicht vom Spiegel, sondern aus den Augen der Menschen, die uns lieben.",
    companion_reflect: "In welchem Moment hat dein Kind heute 'Ich kann das!' gezeigt?",
  },
  {
    key: 'inclusion_scheitern',
    title: 'Scheitern als Lernchance sehen',
    category: 'inclusion',
    parent_lens: "Das Gehirn lernt am stärksten durch Fehler – nicht durch Erfolge. Wenn dein Kind scheitert und du dabei ruhig bleibst, gibst du ihm das stärkste Signal: 'Scheitern ist sicher. Ich halte das aus.'",
    parent_tips: [
      "Beim Scheitern zuerst Mitgefühl, dann Lösung: 'Das war frustrierend. Was könnten wir beim nächsten Mal anders machen?'",
      "Erzähle von eigenen Misserfolgen: 'Ich habe auch mal ... und dann habe ich ... gelernt.' Modelllernen enttabuisiert.",
      "Vermeide 'Ich hab's dir doch gesagt'. Das schließt Türen. Stattdessen: 'Was hast du daraus mitgenommen?'",
    ],
    practical_tip: "Erzähle deinem Kind heute von einem eigenen Misserfolg – und was du daraus gelernt hast.",
    discussion_body: "Wie geht ihr als Familie mit Niederlagen um? Was hilft euch, Scheitern als Teil des Lernens zu sehen?",
    companion_quick: "Kinder, die Fehler machen dürfen, werden mutigere Erwachsene.",
    companion_reflect: "Gab es heute einen Misserfolg, den dein Kind gut weggesteckt hat? Was hat dabei geholfen?",
  },
  {
    key: 'inclusion_hochsensibel',
    title: 'Hochsensible Kinder verstehen und begleiten',
    category: 'inclusion',
    parent_lens: "Etwa 20% der Kinder sind hochsensibel – sie nehmen mehr wahr, fühlen intensiver und brauchen mehr Erholungszeit. Das ist keine Schwäche, sondern ein Persönlichkeitsmerkmal mit eigenen Stärken.",
    parent_tips: [
      "Reduce Reizüberflutung: Ruhige Übergangszeiten einplanen, bevor Hochdruck-Situationen kommen (Einkauf, Schule, Party).",
      "Vorhersehbarkeit schützt: Ankündigen was kommt ('In 10 Minuten gehen wir'). Überraschungen sind für hochsensible Kinder belastend.",
      "Ihre Empfindsamkeit ist eine Stärke: Sie bemerken, wenn jemand traurig ist, und denken tief nach. Benenne das positiv.",
    ],
    practical_tip: "Plane heute 15 Minuten stille 'Auftankzeit' für dein Kind nach einer Hochdruck-Situation – ohne Bildschirm, ohne Erwartung.",
    discussion_body: "Erkennt ihr hochsensible Züge in eurem Kind? Was hilft euch im Alltag damit umzugehen?",
    companion_quick: "Hochsensible Kinder brauchen keine Abhärtung – sie brauchen Schutzräume und Verständnis.",
    companion_reflect: "Wann hat dein Kind heute besonders viel Eindrücke verarbeitet – und wie hat es sich danach erholt?",
  },
  {
    key: 'inclusion_freundschaft',
    title: 'Freundschaften begleiten – nicht steuern',
    category: 'inclusion',
    parent_lens: "Freundschaften sind der wichtigste Lernort für soziale Kompetenz. Kinder lernen Geben und Nehmen, Verhandeln und Verzichten – aber nur wenn wir als Eltern loslassen und begleiten statt steuern.",
    parent_tips: [
      "Frage nach, aber urteile nicht: 'Wie war das heute mit ...?' ist besser als 'Mag ich nicht, der/die hat neulich ...'",
      "Lass Konflikte zwischen Kindern zunächst selbst lösen – greife erst ein, wenn echte Not entsteht.",
      "Ermögliche Freundschaften aktiv: Spielverabredungen, Einladungen. Soziale Chancen entstehen nicht von selbst.",
    ],
    practical_tip: "Frage dein Kind heute: 'Wer aus deiner Klasse / Gruppe mag das Gleiche wie du?' – und überlege gemeinsam, wie ihr Zeit schafft.",
    discussion_body: "Wie gebt ihr euren Kindern Raum für eigene Freundschaften – auch wenn ihr die Wahl nicht immer versteht?",
    companion_quick: "Echte Freundschaft lässt sich nicht erzwingen – aber fruchtbaren Boden könnt ihr gemeinsam schaffen.",
    companion_reflect: "Hat dein Kind heute über jemanden gesprochen, der ihm wichtig ist? Was hast du dabei gelernt?",
  },
  {
    key: 'inclusion_resilienz',
    title: 'Resilienz – wie Kinder an Herausforderungen wachsen',
    category: 'inclusion',
    parent_lens: "Resilienz ist nicht angeboren – sie wird geübt. Kinder werden widerstandsfähig, wenn sie Herausforderungen erleben UND dabei unterstützt werden. Nicht Schutz, sondern Begleitung ist der Schlüssel.",
    parent_tips: [
      "Lass dein Kind Herausforderungen vollenden: Nicht zu früh helfen. Erst wenn es wirklich nicht mehr weiterkommt – dann anbieten.",
      "Stärke den inneren Dialog: 'Was denkst du, was du tun könntest?' statt direkt die Lösung zu geben.",
      "Spreche über Krisen in der Familie altersgerecht: Kinder die ausgeschlossen werden, entwickeln Fantasien die schlimmer sind als die Wahrheit.",
    ],
    practical_tip: "Wenn dein Kind heute scheitert: Warte 30 Sekunden bevor du eingreifst. Oft kommt die Lösung von selbst.",
    discussion_body: "Welche Herausforderung hat euer Kind gemeistert und euch dabei überrascht?",
    companion_quick: "Resilienz wächst in dem Raum zwischen Herausforderung und Unterstützung – nicht davor und nicht danach.",
    companion_reflect: "Woran erkennt ihr, dass euer Kind heute innerlich gewachsen ist?",
  },
  {
    key: 'inclusion_vielfalt',
    title: 'Vielfalt erleben – Unterschiedlichkeit als Stärke',
    category: 'inclusion',
    parent_lens: "Kinder, die früh lernen, dass Menschen verschieden sind – in Herkunft, Fähigkeiten, Denkweise – entwickeln mehr Empathie und weniger Berührungsangst. Du kannst Vielfalt im Alltag lebendig machen.",
    parent_tips: [
      "Sprich offen über Unterschiede – Kinder bemerken sie sowieso. 'Ja, Lara hat eine andere Hautfarbe als du – und ihre Familie kommt aus ...'",
      "Wähle Bücher, Filme und Spiele mit diversen Charakteren – Repräsentation beeinflusst Weltbild.",
      "Feiere familiäre Eigenheiten: 'Bei uns ist das so, und bei anderen Familien ist es anders – das ist das Schöne.'",
    ],
    practical_tip: "Lies heute ein Kinderbuch mit einer Hauptfigur, die anders ist als dein Kind – und sprecht danach darüber.",
    discussion_body: "Wie erklärt ihr Kindern Unterschiede zwischen Menschen auf eine Weise, die neugierig statt ängstlich macht?",
    companion_quick: "Kinder sind von Natur aus neugierig auf Unterschiede – Vorurteile lernen sie erst.",
    companion_reflect: "Hat dein Kind heute eine Frage über Unterschiede gestellt, die dich zum Nachdenken gebracht hat?",
  },
  {
    key: 'leadership_struktur',
    title: 'Tagesstruktur als Sicherheitsanker',
    category: 'parentLeadership',
    parent_lens: "Das Gehirn eines Kindes liebt Vorhersehbarkeit. Rituale und Strukturen sind keine Einschränkung – sie sind das Gerüst, das Kindern Freiheit gibt, sich sicher zu entfalten.",
    parent_tips: [
      "Fixe Anker im Tag: Aufsteh-Ritual, Mahlzeiten, Schlafenszeit. Diese drei reichen für echte Stabilität.",
      "Übergangsrituale einplanen: Zwischen Aktivitäten kurze Übergänge ankündigen. 'In 5 Minuten räumen wir auf.'",
      "Struktur ist kein Stress – verändere sie schrittweise wenn nötig, nicht abrupt.",
    ],
    practical_tip: "Schau heute gemeinsam mit deinem Kind auf den Tagesplan – besprecht, was kommt. Das reduziert Widerstand und Unsicherheit.",
    discussion_body: "Welches Tagesritual ist euch als Familie besonders wichtig – und warum?",
    companion_quick: "Vorhersehbarkeit schafft Sicherheit. Sicherheit schafft Lernbereitschaft.",
    companion_reflect: "Welcher Moment heute hat gezeigt, dass dein Kind Struktur braucht – oder genossen hat?",
  },
  {
    key: 'leadership_schlaf',
    title: 'Schlafrituale – Ruhe schaffen für Körper und Geist',
    category: 'parentLeadership',
    parent_lens: "Schlaf ist Entwicklungszeit, keine Pause. Im Schlaf verarbeitet das Gehirn den Tag, festigt Erinnerungen und regeneriert. Ein gutes Einschlafritual ist eine der wirksamsten Investitionen in dein Kind.",
    parent_tips: [
      "30 Minuten vor dem Schlafen: keine Bildschirme, keine aufregenden Spiele. Runterkommen braucht Zeit.",
      "Immer gleiche Reihenfolge: Zähne, Pyjama, Geschichte, Licht aus. Rituale signalisieren dem Gehirn: 'Jetzt kommt Schlaf.'",
      "Wenn dein Kind nicht einschlafen kann: atmet zusammen. 4 Sekunden ein, 6 Sekunden aus – das aktiviert das parasympathische Nervensystem.",
    ],
    practical_tip: "Führe heute Abend ein 3-minütiges Atemsritual vor dem Schlafen ein – einatmen, ausatmen, zusammen.",
    discussion_body: "Was ist euer liebstes Einschlafritual – und wie habt ihr es entwickelt?",
    companion_quick: "Ein ruhiges Abschlussritual ist der beste Einstieg in einen guten Schlaf.",
    companion_reflect: "Wie war das Einschlafen heute – was hat geholfen, was hat gestört?",
  },
  {
    key: 'leadership_bildschirm',
    title: 'Bildschirmzeit bewusst gestalten',
    category: 'parentLeadership',
    parent_lens: "Nicht die Bildschirmzeit an sich ist das Problem – es ist der unkontrollierte, passive Konsum ohne Gespräch danach. Mit einfachen Rahmenbedingungen wird Bildschirm zur gesunden Freizeitaktivität.",
    parent_tips: [
      "Feste Zeiten statt spontaner Verbote: 'Nach den Hausaufgaben bis 17 Uhr' ist klarer als 'nicht so viel'.",
      "Gemeinsam schauen und danach reden: 'Was hat dir gefallen? Was war komisch oder merkwürdig?' stärkt Medienkompetenz.",
      "Bildschirmfreie Räume einrichten: Schlafzimmer und Esstisch sind gute Start-Grenzen.",
    ],
    practical_tip: "Schaut heute 15 Minuten gemeinsam etwas an – und stell danach 2 Fragen dazu. Das verändert, wie dein Kind Medien wahrnimmt.",
    discussion_body: "Wie handhabt ihr die Bildschirmzeit bei euch – was hat sich bewährt, was weniger?",
    companion_quick: "Bewusstes Mediennutzen lernt man nicht durch Verbot, sondern durch Gespräch.",
    companion_reflect: "Wie hat dein Kind heute Medien genutzt – aktiv oder passiv? Was fiel auf?",
  },
  {
    key: 'leadership_autoritaet',
    title: 'Autorität durch Verbindung – nicht durch Angst',
    category: 'parentLeadership',
    parent_lens: "Autoritär bedeutet nicht laut und streng. Wahre elterliche Autorität entsteht, wenn ein Kind weiß: 'Du liebst mich UND du bist klar.' Verbindung und Führung schließen sich nicht aus – sie bedingen einander.",
    parent_tips: [
      "Klare Ansagen ohne Diskussion: 'Das machen wir jetzt so.' Danach folgt kein Verhandeln – nur Verständnis anbieten.",
      "Entschuldigungen machen Erwachsene stärker, nicht schwächer. 'Das war vorhin nicht fair von mir' – Kinder respektieren das.",
      "Einige Regeln gemeinsam erarbeiten – das steigert die Bereitschaft, sie einzuhalten.",
    ],
    practical_tip: "Formuliere heute eine Regel als positiven Auftrag statt als Verbot: 'Wir räumen nach dem Spielen auf' statt 'Nicht liegen lassen'.",
    discussion_body: "Wie findet ihr die Balance zwischen Führung und Mitsprache eurer Kinder?",
    companion_quick: "Autorität ohne Verbindung ist Kontrolle. Verbindung ohne Autorität ist Chaos. Beides zusammen ist Führung.",
    companion_reflect: "Gab es heute einen Moment, in dem deine ruhige Klarheit mehr bewirkt hat als ein Machtwort?",
  },
  {
    key: 'leadership_hausaufgaben',
    title: 'Hausaufgaben ohne Stress – ein Rahmen, der funktioniert',
    category: 'parentLeadership',
    parent_lens: "Hausaufgaben-Stress ist oft kein Lernproblem – er ist ein Ritual-Problem. Mit der richtigen Struktur und dem richtigen Zeitpunkt entspannt sich das Thema von selbst.",
    parent_tips: [
      "Den richtigen Zeitpunkt finden: Direkt nach der Schule oder nach einer kurzen Erholungsphase – aber vor dem Abend.",
      "Ich bin da, aber ich helfe nicht sofort: Erst selbst versuchen. Nach 10 Minuten ohne Fortschritt: nachfragen 'Wo stockt's?'",
      "Arbeitsplatz vorbereiten: fester Platz, aufgeräumter Tisch, kein Handy in Sichtweite – das reduziert Ablenkung.",
    ],
    practical_tip: "Definiere heute gemeinsam mit deinem Kind DEN einen Hausaufgaben-Zeitpunkt für die Woche – und schreib ihn auf.",
    discussion_body: "Was hat bei euch Hausaufgaben stressfreier gemacht? Welche Routinen funktionieren?",
    companion_quick: "Struktur beim Lernen ist keine Einschränkung – sie ist der Motor für Konzentration.",
    companion_reflect: "Wie lief das Lernen heute? Was könnte ihr morgen anders ausprobieren?",
  },
  {
    key: 'leadership_selbstaendigkeit',
    title: 'Selbständigkeit – loslassen ist auch Liebe',
    category: 'parentLeadership',
    parent_lens: "Kinder werden selbständig, wenn wir ihnen trauen. Aber loslassen fühlt sich riskant an – und das ist normal. Die Kunst ist: Schritt für Schritt mehr Verantwortung übergeben.",
    parent_tips: [
      "Altersgerechte Aufgaben vergeben: 3-jährige räumen Spielzeug weg, 6-jährige decken den Tisch, 10-jährige kochen mit.",
      "Nicht einspringen, wenn's langsam geht. Langsam und selbst ist wertvoller als schnell und mit Hilfe.",
      "Fehler bei selbständigen Aufgaben akzeptieren: Das Glas Milch kippt um – das ist kein Versagen, das ist Üben.",
    ],
    practical_tip: "Übergib deinem Kind heute eine neue Aufgabe, die du bisher selbst gemacht hast – und lass es komplett selbst.",
    discussion_body: "Was ist die größte Selbständigkeits-Leistung eures Kindes, auf die ihr beide stolz seid?",
    companion_quick: "Jede Aufgabe, die das Kind selbst erledigt, ist eine Investition in sein späteres Selbstbewusstsein.",
    companion_reflect: "Wann habt ihr heute losgelassen – und wie hat sich das für euch angefühlt?",
  },
  {
    key: 'leadership_natur',
    title: 'Natur und Bewegung als Familienritual',
    category: 'parentLeadership',
    parent_lens: "Kinder, die regelmäßig draußen sind, schlafen besser, sind konzentrierter und emotional stabiler. Natur ist keine Freizeitbeschäftigung – sie ist ein Grundbedürfnis.",
    parent_tips: [
      "15 Minuten täglich draußen sind bereits messbar wirksam – kein Ausflug nötig, auch der Schulweg zählt.",
      "Bewege dich gemeinsam: Fahrrad, Spaziergang, Bolzplatz. Bewegung zusammen stärkt Bindung.",
      "Lass dein Kind Natur entdecken: Steine, Käfer, Pfützen. Kein Programm – nur Offenheit.",
    ],
    practical_tip: "Plane heute eine 15-minütige Runde draußen – ohne Ziel, ohne Programm, einfach gemeinsam.",
    discussion_body: "Welches Naturerlebnis aus eurer Kindheit möchtet ihr euren Kindern weitergeben?",
    companion_quick: "Draußen sein ist Gehirnnahrung – für Kinder und Erwachsene.",
    companion_reflect: "Wie hat eure Zeit draußen heute die Stimmung verändert?",
  },
  {
    key: 'milestone_sprache',
    title: 'Sprachentwicklung – so förderst du spielend',
    category: 'milestones',
    parent_lens: "Sprachentwicklung passiert nicht im Vokabeltraining – sie entsteht im Dialog. Kinder lernen sprechen, wenn Erwachsene mit ihnen sprechen, ihnen zuhören und auf ihre Äußerungen eingehen.",
    parent_tips: [
      "Beschreibe deinen Alltag laut: 'Ich schneide jetzt die Karotten' – das bereichert den passiven Wortschatz.",
      "Greife Aussagen deines Kindes auf und erweitere sie: 'Ball!' – 'Ja, der rote Ball rollt.'",
      "Vorlesen täglich, auch wenn das Kind schon lesen kann. Texte aus Büchern haben andere Strukturen als Alltagssprache.",
    ],
    practical_tip: "Lies heute 10 Minuten laut vor – und frage beim Lesen: 'Was glaubst du, was als nächstes passiert?'",
    discussion_body: "Welche Wörter oder Sätze eures Kindes haben euch zuletzt besonders überrascht oder berührt?",
    companion_quick: "Sprache wächst im Gespräch – nicht in der Stille.",
    companion_reflect: "Welcher sprachliche Fortschritt eures Kindes ist euch heute aufgefallen?",
  },
  {
    key: 'milestone_schule',
    title: 'Schulstart und Übergänge gelassen begleiten',
    category: 'milestones',
    parent_lens: "Übergänge – Schulstart, Klassenwechsel, neue Kita – sind für Kinder die intensivsten Lernphasen. Deine Ruhe und Zuversicht übertragen sich auf dein Kind. Du bist die Regulationsbasis.",
    parent_tips: [
      "Neue Orte vorher kennenlernen: Wenn möglich, den neuen Klassenraum oder die Schule vor dem ersten Tag besuchen.",
      "Über Gefühle reden: 'Es ist okay, aufgeregt zu sein. Ich war beim ersten Schultag auch nervös.'",
      "Kleine Übergangsobjekte helfen: Ein Foto in der Tasche, ein kleines Erinnerungsstück – Gegenstände schaffen Sicherheit.",
    ],
    practical_tip: "Frage dein Kind heute: 'Was freut dich auf ... ? Was macht dir noch Sorgen?' – und höre ohne Bewertung zu.",
    discussion_body: "Wie habt ihr einen wichtigen Übergang eures Kindes begleitet? Was hat geholfen?",
    companion_quick: "Übergänge sind Ende und Anfang zugleich – und beides darf gefühlt werden.",
    companion_reflect: "Welche Emotion hat dein Kind rund um einen Übergang heute gezeigt?",
  },
  {
    key: 'milestone_sozial',
    title: 'Soziale Intelligenz – die wichtigste Kompetenz des 21. Jahrhunderts',
    category: 'milestones',
    parent_lens: "IQ öffnet Türen. EQ (emotionale Intelligenz) lässt Menschen rein. Kinder mit hoher sozialer Kompetenz können besser kooperieren, kommunizieren und sich in andere hineinversetzen – das lernen sie bei dir.",
    parent_tips: [
      "Modelliere Empathie täglich: 'Die Katze sieht traurig aus. Was glaubst du, warum?'",
      "Übe Perspektivwechsel: 'Wie hat sich wohl ... dabei gefühlt, als du das gesagt hast?'",
      "Lobbe soziales Verhalten explizit: 'Du hast gewartet, bis er fertig gesprochen hat. Das war sehr respektvoll.'",
    ],
    practical_tip: "Sprich heute nach dem Kindergarten oder der Schule über eine soziale Situation: 'Hat jemand heute etwas Nettes getan?'",
    discussion_body: "Welchen Aspekt sozialer Kompetenz findet ihr heute am wichtigsten – für Kinder und Erwachsene?",
    companion_quick: "Sozialkompetenz ist kein Talent – sie ist eine Fähigkeit, die geübt wird.",
    companion_reflect: "Wann hat dein Kind heute Empathie gezeigt – auch wenn es vielleicht unbemerkt war?",
  },
  {
    key: 'milestone_emotion',
    title: 'Emotionale Reife – wenn Gefühle verarbeitet werden',
    category: 'milestones',
    parent_lens: "Emotionale Reife zeigt sich nicht darin, keine Gefühle zu haben – sondern darin, sie zu verarbeiten. Kinder, die Gefühle ausdrücken dürfen, lernen langfristig besser damit umzugehen.",
    parent_tips: [
      "Alle Gefühle sind erlaubt – nicht alle Handlungen. 'Du darfst wütend sein. Du darfst nicht schlagen.'",
      "Gefühle nicht wegredden: statt 'Das ist doch nicht so schlimm' → 'Ich sehe, dass dich das wirklich trifft.'",
      "Emotionen im Körper spüren lassen: 'Wo fühlst du das gerade? Im Bauch? In der Brust?'",
    ],
    practical_tip: "Frage heute: 'Wie fühlt sich das in deinem Körper an?' – und akzeptiere jede Antwort.",
    discussion_body: "Welches Gefühl fällt euch in eurer Familie am schwersten offen zu zeigen?",
    companion_quick: "Gefühle zulassen ist nicht Schwäche – es ist emotionale Stärke.",
    companion_reflect: "Welche Emotion hat dein Kind heute offen gezeigt – und wie habt ihr sie gemeinsam begleitet?",
  },
  {
    key: 'milestone_kreativitaet',
    title: 'Kreativität fördern – ohne Ergebnisorientierung',
    category: 'milestones',
    parent_lens: "Kreativität ist Problemlösefähigkeit in Verkleidung. Wenn Kinder malen, bauen, basteln oder spielen, trainieren sie Flexibilität und Originalität – die Kompetenzen der Zukunft.",
    parent_tips: [
      "Kein Endprodukt-Fokus: 'Erzähl mir, was du gemacht hast' statt 'Was soll das sein?'",
      "Materialien ohne Anleitung anbieten: Stoff, Pappe, Naturmaterialien – und dann loslassen.",
      "Selbst kreativ sein: Wenn Eltern malen, bauen, singen – ohne Perfektion – erlauben sie ihren Kindern dasselbe.",
    ],
    practical_tip: "Biete heute 20 Minuten freies Basteln an – ohne Vorlage, ohne Anleitung, nur Materialien.",
    discussion_body: "Was ist das kreativste Projekt, das euer Kind je selbst entwickelt hat?",
    companion_quick: "Kreativität braucht Raum, Zeit und einen Erwachsenen, der nicht bewertet.",
    companion_reflect: "Was hat dein Kind heute erfunden, gebaut oder ausgedacht – das dich überrascht hat?",
  },
  {
    key: 'milestone_koerper',
    title: 'Körperwahrnehmung stärken – Bewegung als Entwicklungsmotor',
    category: 'milestones',
    parent_lens: "Motorische Entwicklung und kognitive Entwicklung sind untrennbar verbunden. Kinder, die klettern, balancieren und tanzen, entwickeln auch ihr räumliches Denken und ihre Konzentration.",
    parent_tips: [
      "Bewegung täglich einbauen: Nicht als Sport-Programm, sondern als Alltag – Treppen statt Aufzug, Laufen statt Tragen.",
      "Grobmotorik und Feinmotorik wechseln: Bauen (Fein) und Klettern (Grob) ergänzen sich wunderbar.",
      "Körperbilder positiv stärken: 'Dein Körper kann so viel' – unabhängig von Aussehen oder Leistung.",
    ],
    practical_tip: "Plane heute 10 Minuten Bewegungsspiel – Balancieren, Hüpfen, Rollen. Kein Programm, nur Körper und Spaß.",
    discussion_body: "Welche Bewegungsaktivität macht eurem Kind am meisten Freude – und warum?",
    companion_quick: "Bewegung ist nicht Freizeitbeschäftigung – sie ist Lernmotor.",
    companion_reflect: "Was hat dein Kind heute körperlich ausprobiert oder gewagt, das neu war?",
  },
  {
    key: 'milestone_uebergaenge',
    title: 'Pubertät vorbereiten – frühzeitig und entspannt',
    category: 'milestones',
    parent_lens: "Die Pubertät beginnt früher als die meisten Eltern denken – und die Weichen werden in der Kindheit gestellt. Offene Kommunikation und ein sicheres Eltern-Kind-Verhältnis sind die beste Vorbereitung.",
    parent_tips: [
      "Frühzeitig über Körperveränderungen sprechen – sachlich, ohne Drama. Kinder die informiert sind, haben weniger Angst.",
      "Eigene Pubertätserinnerungen teilen (angemessen): 'Ich war damals auch unsicher mit ...' – das normalisiert.",
      "Räume für Privatheit schaffen: Anklopfen, Tagebücher respektieren. Vertrauen entsteht durch Respekt.",
    ],
    practical_tip: "Schau dir heute gemeinsam mit deinem Kind (altersgerecht) ein Video oder Buch über Körperprozesse an – ohne Scheu.",
    discussion_body: "Was war euch rückblickend in der Pubertät wichtig – und was wünscht ihr euch, eure Eltern hätten gemacht?",
    companion_quick: "Die beste Pubertätsvorbereitung ist eine starke Beziehung heute.",
    companion_reflect: "Hat dein Kind heute eine Frage gestellt, die zeigt, dass es anfängt, über sich selbst nachzudenken?",
  },
  {
    key: 'gfk_wiedergutmachung',
    title: 'Wenn Eltern ausrasten – Wiedergutmachung als Stärke',
    category: 'gfk',
    parent_lens: "Kein Elternteil ist immer geduldig. Wenn du ausrastest, ist das kein Versagen als Elternteil – es ist ein menschlicher Moment. Was danach kommt, formt aber die Beziehung stärker als der Ausraster selbst.",
    parent_tips: [
      "Wiedergutmachung braucht drei Schritte: Verantwortung übernehmen ('Ich habe mich geirrt'), Mitgefühl zeigen, und ggf. anders machen.",
      "Entschuldigungen ohne 'Aber': 'Es tut mir leid, dass ich so laut war. Das war nicht in Ordnung.' – fertig.",
      "Dein Kind sieht dich als Mensch – das ist gut. Kinder lernen durch Reparatur, dass Beziehungen Stürme überstehen.",
    ],
    practical_tip: "Wenn du dich heute in einer Situation nicht schön verhalten hast: Geh nochmal zum Kind und sage es. Drei Sätze reichen.",
    discussion_body: "Wie habt ihr als Eltern gelernt, mit eigenen Ausrastern umzugehen – ohne euch selbst zu hart zu beurteilen?",
    companion_quick: "Wiedergutmachung lehrt Kindern etwas, was kein Ratgeber kann: dass Beziehungen reparierbar sind.",
    companion_reflect: "Gab es heute einen Moment, den du im Nachhinein anders gemacht hättest – und was hast du daraus gemacht?",
  },
];

// Per-language overlay for DAILY_IMPULSE_POOL entries, keyed by topic `key`.
// Only translatable text fields are overridden; `category`/`key` stay as-is.
const DAILY_IMPULSE_TRANSLATIONS = {
  en: {
    gfk_warum: {
      title: 'Calmly handling "why" questions',
      parent_lens: "Your child asks 'why?' a hundred times a day. It's not to annoy you — it's because their brain is building connections. They want to understand the world.",
      parent_tips: [
        "Use nonviolent communication (NVC): name your own feelings and needs clearly instead of scolding.",
        "Answer 'why' questions briefly and simply — your child is looking for logic, not a scientific lecture.",
        "Set boundaries lovingly through personal presence ('I don't want you to hit'), not through punishment.",
      ],
      practical_tip: "At the next 'why' question: first mirror the feeling ('You're curious!'), then answer in one sentence.",
      discussion_body: "What short, calm phrase helps you when your child asks 'why' for the tenth time?",
      companion_quick: "Today, choose just one calm answer to a why-question and stay deliberately brief afterward.",
      companion_reflect: "When did your child seek the most connections today — and how could you calmly provide guidance?",
    },
    gfk_grenzen: {
      title: 'Setting boundaries lovingly and clearly',
      parent_lens: "Loving boundaries are not a contradiction. Children need both: the feeling of being loved AND clear guidance on what isn't okay. Boundaries without connection feel like walls — boundaries with connection feel like guardrails.",
      parent_tips: [
        "Name your child's feeling first, then the boundary: 'I see you're angry. And still: hitting isn't okay.'",
        "Stay physically calm — your tone is louder than your words. A deep breath before reacting helps.",
        "Announce consequences and follow through. Don't threaten, state them: 'If you ... then ...'",
      ],
      practical_tip: "Practice a sentence with feeling + boundary today: 'I understand you want that. And: no.' — and stay calm while saying it.",
      discussion_body: "How do you react when you reach your own limits? Which phrase helps you stay calm?",
      companion_quick: "One deep breath before the next boundary reaction — that's already half the battle.",
      companion_reflect: "Was there a situation today where a calm boundary worked better than a loud no?",
    },
    gfk_ichbotschaft: {
      title: '"I" messages instead of "you" accusations',
      parent_lens: "\"You\" messages (\"You're so loud!\") trigger defensiveness. \"I\" messages (\"I'm getting tired and need quiet\") open doors. Children listen more when they don't feel attacked.",
      parent_tips: [
        "Turn accusations into \"I\" messages: instead of \"You never listen\" → \"I don't feel heard and that makes me sad.\"",
        "Share your need: \"I need a moment of quiet to think.\" Children understand needs remarkably well.",
        "Practice in everyday life: rephrase three classic sentences as \"I\" messages — in the morning brushing teeth, at lunch, at bedtime.",
      ],
      practical_tip: "Today, pick a situation where you'd usually say \"You always...\" — and replace it with \"I feel ... because I need ...\"",
      discussion_body: "Which \"you\" message is hardest for you to rephrase? What helps with that?",
      companion_quick: "Name the feeling + the need — that's the formula for a real \"I\" message.",
      companion_reflect: "Did an \"I\" message today trigger a reaction that surprised you?",
    },
    gfk_trotz: {
      title: 'Calmly accompanying defiant phases',
      parent_lens: "Defiance isn't rebellion — it's development. When a child lies on the floor screaming, their prefrontal cortex simply isn't mature enough yet to regulate the emotion. They need you as a co-regulator.",
      parent_tips: [
        "Stay physically close without forcing it: get down to their level, speak calmly, don't touch if the child refuses.",
        "Avoid discussions in the middle of the storm. The conversation comes once they've calmed down.",
        "Use 'feeling bridges': 'You wanted the ice cream. That was really important to you. I understand.'",
      ],
      practical_tip: "When your child is beside themselves: sit next to them. Don't leave, don't intervene — just be there. That alone helps regulate.",
      discussion_body: "What helps you stay calm yourselves when your child is in the middle of an emotional outburst?",
      companion_quick: "Three words for defiant phases: stay close. Breathe calmly. Wait it out.",
      companion_reflect: "What cost you the most energy today — and what helped you stay calm through it?",
    },
    gfk_geschwister: {
      title: 'Using sibling conflict as a learning field',
      parent_lens: "Siblings argue — that's normal and even important. In conflict, children learn compromise, perspective-taking and self-assertion. Your role is moderator, not judge.",
      parent_tips: [
        "Don't take sides: 'I see you're both angry right now. I'll listen to you first, then you.'",
        "Let children find their own solutions when the situation isn't escalating. Step in only when there's real danger.",
        "Strengthen each child individually: regular 1:1 moments without siblings reduce jealousy long-term.",
      ],
      practical_tip: "At the next argument: ask both children 'What do you need right now?' — before deciding who's right.",
      discussion_body: "How do you handle it when siblings argue? What works best for you?",
      companion_quick: "Moderator instead of judge — that's your role in sibling conflicts.",
      companion_reflect: "Was there a moment today when your children resolved a conflict themselves? What did you learn from it?",
    },
    gfk_gefühle: {
      title: 'Naming and acknowledging feelings',
      parent_lens: "Children who can name their feelings have a huge advantage: they can communicate what they need. This step — from feeling to speaking — needs practice and your support.",
      parent_tips: [
        "Use the 'feelings barometer': ask in the evening 'How was your day on a scale of 1-5?' — and share your own first.",
        "Name your own feelings out loud: 'I'm a bit stressed right now because I have a lot to think about.' Modeling works.",
        "Read children's books about feelings — and pause afterward: 'What do you think the character felt? And you?'",
      ],
      practical_tip: "Tonight, ask: 'What made you happy today? What made you sad or angry?' — and just listen.",
      discussion_body: "Which feeling is especially hard for your child to name? How do you approach that?",
      companion_quick: "Feel first, then name — the feelings ABC starts with you as a role model.",
      companion_reflect: "Which feeling moment of your child did you want to hold onto today?",
    },
    gfk_nein: {
      title: 'Saying no — without guilt',
      parent_lens: "Parents who never say no raise children who don't know boundaries. A loving no shows your child: I take my own needs seriously — and so may you.",
      parent_tips: [
        "A no doesn't need a long explanation. A clear 'No, that's not possible right now' is complete.",
        "Guilt after a no is a signal, not a mistake. Ask yourself: is the no really wrong — or just uncomfortable?",
        "Practice saying no to other adults too (playdates, commitments) — your child learns from your example.",
      ],
      practical_tip: "Today, say no once, deliberately — without apologizing. Notice how it feels.",
      discussion_body: "When is it hardest for you to say no — to your children, or to others?",
      companion_quick: "A no to one thing is a yes to something more important — usually to yourself.",
      companion_reflect: "Was there a no today that felt right in hindsight?",
    },
    inclusion_stärken: {
      title: 'Seeing strengths instead of judging weaknesses',
      parent_lens: "Every child has a unique constellation of strengths. As parents, we often see the trouble spots first — even though we could be the first to polish the rough diamond.",
      parent_tips: [
        "Tonight, write down 3 strengths of your child — not achievements, but character traits ('curious', 'caring', 'persistent').",
        "Name strengths concretely and promptly: 'You were so patient just now — that's really great.'",
        "Avoid comparisons with siblings or other children. Every developmental curve is unique.",
      ],
      practical_tip: "Talk to your child today about one of their strengths — not as praise, but as an observation: 'I saw today how you...'",
      discussion_body: "Which hidden strength of your child would you like to share today?",
      companion_quick: "Seeing strengths doesn't mean ignoring weaknesses — it means enabling growth.",
      companion_reflect: "Which strength of your child surprised or impressed you today?",
    },
    inclusion_selbstwert: {
      title: 'Building self-worth every day',
      parent_lens: "Self-worth doesn't come from praise alone — it comes from the experience: 'I can do something. I matter. I belong.' You can build in all three experiences daily.",
      parent_tips: [
        "Let your child make small decisions: 'Do you want to do the tasks first or play first?' Autonomy = self-worth.",
        "Show genuine interest: put the phone away, look at their face, ask questions. 10 minutes of full attention work wonders.",
        "Celebrate the process, not just the result: 'You tried that for so long — that's the important part.'",
      ],
      practical_tip: "Today: 10 minutes of undivided attention for your child — no phone, no distraction, just interest.",
      discussion_body: "What makes your child especially proud of themselves — and how do you support that feeling?",
      companion_quick: "Self-worth doesn't come from the mirror, but from the eyes of the people who love us.",
      companion_reflect: "In which moment today did your child show 'I can do this!'?",
    },
    inclusion_scheitern: {
      title: 'Seeing failure as a learning opportunity',
      parent_lens: "The brain learns most strongly from mistakes — not from successes. When your child fails and you stay calm, you send the strongest signal: 'Failing is safe. I can handle it.'",
      parent_tips: [
        "When failing, show compassion first, then a solution: 'That was frustrating. What could we do differently next time?'",
        "Share your own failures: 'I also once ... and then I learned ...' Modeling removes the taboo.",
        "Avoid 'I told you so.' That closes doors. Instead: 'What did you take away from that?'",
      ],
      practical_tip: "Tell your child today about one of your own failures — and what you learned from it.",
      discussion_body: "How does your family handle setbacks? What helps you see failure as part of learning?",
      companion_quick: "Children who are allowed to make mistakes become braver adults.",
      companion_reflect: "Was there a failure today that your child handled well? What helped with that?",
    },
    inclusion_hochsensibel: {
      title: 'Understanding and supporting highly sensitive children',
      parent_lens: "About 20% of children are highly sensitive — they perceive more, feel more intensely and need more recovery time. That's not a weakness, but a personality trait with its own strengths.",
      parent_tips: [
        "Reduce sensory overload: plan calm transition times before high-pressure situations (shopping, school, parties).",
        "Predictability protects: announce what's coming ('We're leaving in 10 minutes'). Surprises are stressful for highly sensitive children.",
        "Their sensitivity is a strength: they notice when someone is sad and think deeply. Name that positively.",
      ],
      practical_tip: "Today, plan 15 minutes of quiet 'recharge time' for your child after a high-pressure situation — no screen, no expectations.",
      discussion_body: "Do you recognize highly sensitive traits in your child? What helps you handle it day to day?",
      companion_quick: "Highly sensitive children don't need toughening up — they need protected spaces and understanding.",
      companion_reflect: "When did your child process especially many impressions today — and how did they recover afterward?",
    },
    inclusion_freundschaft: {
      title: 'Accompanying friendships — not steering them',
      parent_lens: "Friendships are the most important place to learn social skills. Children learn giving and taking, negotiating and letting go — but only if we as parents let go and accompany instead of steering.",
      parent_tips: [
        "Ask, but don't judge: 'How did it go with ... today?' is better than 'I don't like them, they did ... recently.'",
        "Let children resolve conflicts among themselves at first — step in only when real distress arises.",
        "Actively enable friendships: playdates, invitations. Social opportunities don't just happen on their own.",
      ],
      practical_tip: "Ask your child today: 'Who in your class / group likes the same things as you?' — and think together about how to make time for it.",
      discussion_body: "How do you give your children room for their own friendships — even when you don't always understand their choices?",
      companion_quick: "Real friendship can't be forced — but you can create fertile ground for it together.",
      companion_reflect: "Did your child talk about someone important to them today? What did you learn from it?",
    },
    inclusion_resilienz: {
      title: 'Resilience — how children grow through challenges',
      parent_lens: "Resilience isn't innate — it's practiced. Children become resilient when they experience challenges AND are supported through them. Not protection, but accompaniment is the key.",
      parent_tips: [
        "Let your child complete challenges: don't help too early. Only offer help once they truly can't go further.",
        "Strengthen inner dialogue: 'What do you think you could do?' instead of giving the solution directly.",
        "Talk about family crises age-appropriately: children who are left out develop fantasies worse than the truth.",
      ],
      practical_tip: "If your child fails today: wait 30 seconds before stepping in. Often the solution comes on its own.",
      discussion_body: "Which challenge did your child master that surprised you?",
      companion_quick: "Resilience grows in the space between challenge and support — not before it and not after it.",
      companion_reflect: "How can you tell that your child grew inwardly today?",
    },
    inclusion_vielfalt: {
      title: 'Experiencing diversity — difference as a strength',
      parent_lens: "Children who learn early that people differ — in origin, abilities, ways of thinking — develop more empathy and less fear of contact. You can bring diversity to life in everyday moments.",
      parent_tips: [
        "Talk openly about differences — children notice them anyway. 'Yes, Lara has a different skin color than you — and her family comes from...'",
        "Choose books, films and games with diverse characters — representation shapes worldview.",
        "Celebrate family quirks: 'For us it's like this, and other families do it differently — that's the beauty of it.'",
      ],
      practical_tip: "Read a children's book today with a main character different from your child — and talk about it afterward.",
      discussion_body: "How do you explain differences between people to children in a way that sparks curiosity instead of fear?",
      companion_quick: "Children are naturally curious about differences — prejudice is learned later.",
      companion_reflect: "Did your child ask a question about differences today that made you think?",
    },
    leadership_struktur: {
      title: 'Daily structure as an anchor of security',
      parent_lens: "A child's brain loves predictability. Rituals and structures aren't limitations — they're the scaffolding that gives children the freedom to develop safely.",
      parent_tips: [
        "Fixed anchors in the day: waking-up ritual, meals, bedtime. These three are enough for real stability.",
        "Plan transition rituals: announce short transitions between activities. 'In 5 minutes we'll tidy up.'",
        "Structure isn't stress — change it gradually if needed, not abruptly.",
      ],
      practical_tip: "Today, look at the daily schedule together with your child — discuss what's coming. That reduces resistance and uncertainty.",
      discussion_body: "Which daily ritual is especially important to your family — and why?",
      companion_quick: "Predictability creates security. Security creates readiness to learn.",
      companion_reflect: "Which moment today showed that your child needs structure — or enjoyed it?",
    },
    leadership_schlaf: {
      title: 'Sleep rituals — creating calm for body and mind',
      parent_lens: "Sleep is developmental time, not a pause. During sleep, the brain processes the day, consolidates memories and regenerates. A good bedtime ritual is one of the most effective investments in your child.",
      parent_tips: [
        "30 minutes before sleep: no screens, no exciting games. Winding down takes time.",
        "Always the same order: teeth, pajamas, story, lights out. Rituals signal to the brain: 'Now it's time for sleep.'",
        "If your child can't fall asleep: breathe together. 4 seconds in, 6 seconds out — that activates the parasympathetic nervous system.",
      ],
      practical_tip: "Introduce a 3-minute breathing ritual before sleep tonight — breathe in, breathe out, together.",
      discussion_body: "What's your favorite bedtime ritual — and how did you develop it?",
      companion_quick: "A calm closing ritual is the best start to good sleep.",
      companion_reflect: "How was falling asleep today — what helped, what disturbed it?",
    },
    leadership_bildschirm: {
      title: 'Shaping screen time consciously',
      parent_lens: "Screen time itself isn't the problem — it's uncontrolled, passive consumption without conversation afterward. With simple guidelines, screens become a healthy leisure activity.",
      parent_tips: [
        "Fixed times instead of spontaneous bans: 'After homework until 5pm' is clearer than 'not too much'.",
        "Watch together and talk afterward: 'What did you like? What was strange or odd?' strengthens media literacy.",
        "Set up screen-free spaces: bedroom and dinner table are good starting boundaries.",
      ],
      practical_tip: "Watch something together for 15 minutes today — and ask 2 questions about it afterward. That changes how your child perceives media.",
      discussion_body: "How do you handle screen time in your family — what has worked, what less so?",
      companion_quick: "Conscious media use isn't learned through bans, but through conversation.",
      companion_reflect: "How did your child use media today — actively or passively? What did you notice?",
    },
    leadership_autoritaet: {
      title: 'Authority through connection — not fear',
      parent_lens: "Authoritative doesn't mean loud and strict. True parental authority arises when a child knows: 'You love me AND you're clear.' Connection and leadership don't exclude each other — they depend on each other.",
      parent_tips: [
        "Clear statements without discussion: 'This is how we're doing it now.' No negotiating afterward — just offer understanding.",
        "Apologies make adults stronger, not weaker. 'That wasn't fair of me earlier' — children respect that.",
        "Work out some rules together — that increases willingness to follow them.",
      ],
      practical_tip: "Today, phrase a rule as a positive instruction instead of a ban: 'We tidy up after playing' instead of 'Don't leave things lying around'.",
      discussion_body: "How do you find the balance between leadership and your children's say?",
      companion_quick: "Authority without connection is control. Connection without authority is chaos. Both together is leadership.",
      companion_reflect: "Was there a moment today when your calm clarity achieved more than a power word?",
    },
    leadership_hausaufgaben: {
      title: 'Homework without stress — a framework that works',
      parent_lens: "Homework stress is often not a learning problem — it's a ritual problem. With the right structure and the right timing, the issue relaxes on its own.",
      parent_tips: [
        "Find the right time: right after school or after a short recovery break — but before evening.",
        "I'm here, but I won't help right away: try it yourself first. After 10 minutes without progress: ask 'Where are you stuck?'",
        "Prepare the workspace: a fixed spot, a tidy desk, no phone in sight — that reduces distraction.",
      ],
      practical_tip: "Today, define THE one homework time for the week together with your child — and write it down.",
      discussion_body: "What made homework less stressful for you? Which routines work?",
      companion_quick: "Structure while learning isn't a limitation — it's the engine for concentration.",
      companion_reflect: "How did learning go today? What could you try differently tomorrow?",
    },
    leadership_selbstaendigkeit: {
      title: 'Independence — letting go is also love',
      parent_lens: "Children become independent when we trust them. But letting go feels risky — and that's normal. The art is: hand over more responsibility step by step.",
      parent_tips: [
        "Assign age-appropriate tasks: 3-year-olds put away toys, 6-year-olds set the table, 10-year-olds help cook.",
        "Don't jump in when it's going slowly. Slow and by themselves is more valuable than fast and with help.",
        "Accept mistakes in independent tasks: the glass of milk tips over — that's not failure, that's practice.",
      ],
      practical_tip: "Today, hand your child a new task you've always done yourself — and let them do it completely on their own.",
      discussion_body: "What is your child's greatest achievement of independence that you're both proud of?",
      companion_quick: "Every task a child completes themselves is an investment in their future self-confidence.",
      companion_reflect: "When did you let go today — and how did that feel for you?",
    },
    leadership_natur: {
      title: 'Nature and movement as a family ritual',
      parent_lens: "Children who are regularly outside sleep better, concentrate better and are more emotionally stable. Nature isn't a leisure activity — it's a basic need.",
      parent_tips: [
        "15 minutes outside daily already has a measurable effect — no trip needed, even the walk to school counts.",
        "Move together: bicycle, walk, playing field. Moving together strengthens bonding.",
        "Let your child discover nature: stones, beetles, puddles. No program — just openness.",
      ],
      practical_tip: "Plan a 15-minute walk outside today — no destination, no program, just together.",
      discussion_body: "Which nature experience from your own childhood would you like to pass on to your children?",
      companion_quick: "Being outside is brain food — for children and adults.",
      companion_reflect: "How did your time outside today change the mood?",
    },
    milestone_sprache: {
      title: 'Language development — how to support it through play',
      parent_lens: "Language development doesn't happen through vocabulary drills — it happens in dialogue. Children learn to speak when adults talk with them, listen to them and respond to what they say.",
      parent_tips: [
        "Describe your everyday life out loud: 'Now I'm cutting the carrots' — that enriches passive vocabulary.",
        "Pick up on your child's statements and expand them: 'Ball!' — 'Yes, the red ball is rolling.'",
        "Read aloud daily, even if the child can already read. Texts from books have different structures than everyday speech.",
      ],
      practical_tip: "Read aloud for 10 minutes today — and ask while reading: 'What do you think happens next?'",
      discussion_body: "Which words or sentences of your child have recently surprised or touched you?",
      companion_quick: "Language grows in conversation — not in silence.",
      companion_reflect: "Which language progress of your child did you notice today?",
    },
    milestone_schule: {
      title: 'Calmly accompanying school starts and transitions',
      parent_lens: "Transitions — starting school, changing classes, new daycare — are the most intense learning phases for children. Your calm and confidence transfer to your child. You are the base of regulation.",
      parent_tips: [
        "Get to know new places beforehand: if possible, visit the new classroom or school before the first day.",
        "Talk about feelings: 'It's okay to be nervous. I was nervous on my first day of school too.'",
        "Small transition objects help: a photo in the bag, a small keepsake — objects create security.",
      ],
      practical_tip: "Ask your child today: 'What are you looking forward to about ...? What still worries you?' — and listen without judgment.",
      discussion_body: "How have you accompanied an important transition for your child? What helped?",
      companion_quick: "Transitions are an ending and a beginning at once — and both may be felt.",
      companion_reflect: "Which emotion did your child show around a transition today?",
    },
    milestone_sozial: {
      title: 'Social intelligence — the most important skill of the 21st century',
      parent_lens: "IQ opens doors. EQ (emotional intelligence) lets people in. Children with high social competence can cooperate, communicate and empathize better — and they learn this from you.",
      parent_tips: [
        "Model empathy daily: 'The cat looks sad. Why do you think that is?'",
        "Practice perspective-taking: 'How do you think ... felt when you said that?'",
        "Praise social behavior explicitly: 'You waited until he finished speaking. That was very respectful.'",
      ],
      practical_tip: "Talk about a social situation after daycare or school today: 'Did anyone do something nice today?'",
      discussion_body: "Which aspect of social competence do you find most important today — for children and adults?",
      companion_quick: "Social competence isn't a talent — it's a skill that is practiced.",
      companion_reflect: "When did your child show empathy today — even if it went unnoticed?",
    },
    milestone_emotion: {
      title: 'Emotional maturity — when feelings are processed',
      parent_lens: "Emotional maturity doesn't show in having no feelings — but in processing them. Children who are allowed to express feelings learn to handle them better in the long run.",
      parent_tips: [
        "All feelings are allowed — not all actions. 'You may be angry. You may not hit.'",
        "Don't talk feelings away: instead of 'That's not so bad' → 'I can see this really affects you.'",
        "Let emotions be felt in the body: 'Where do you feel that right now? In your stomach? In your chest?'",
      ],
      practical_tip: "Ask today: 'How does that feel in your body?' — and accept whatever answer comes.",
      discussion_body: "Which feeling is hardest for your family to show openly?",
      companion_quick: "Allowing feelings isn't weakness — it's emotional strength.",
      companion_reflect: "Which emotion did your child show openly today — and how did you accompany it together?",
    },
    milestone_kreativitaet: {
      title: 'Fostering creativity — without focusing on outcomes',
      parent_lens: "Creativity is problem-solving in disguise. When children paint, build, craft or play, they train flexibility and originality — the skills of the future.",
      parent_tips: [
        "No focus on the end product: 'Tell me what you made' instead of 'What is that supposed to be?'",
        "Offer materials without instructions: fabric, cardboard, natural materials — and then let go.",
        "Be creative yourself: when parents paint, build, sing — without perfection — they allow their children the same.",
      ],
      practical_tip: "Offer 20 minutes of free crafting today — no template, no instructions, just materials.",
      discussion_body: "What's the most creative project your child has ever come up with themselves?",
      companion_quick: "Creativity needs space, time, and an adult who doesn't judge.",
      companion_reflect: "What did your child invent, build or imagine today that surprised you?",
    },
    milestone_koerper: {
      title: 'Strengthening body awareness — movement as a driver of development',
      parent_lens: "Motor development and cognitive development are inseparably linked. Children who climb, balance and dance also develop their spatial thinking and concentration.",
      parent_tips: [
        "Build in movement daily: not as a sports program, but as everyday life — stairs instead of elevator, walking instead of carrying.",
        "Alternate gross and fine motor skills: building (fine) and climbing (gross) complement each other wonderfully.",
        "Reinforce body image positively: 'Your body can do so much' — regardless of appearance or performance.",
      ],
      practical_tip: "Plan 10 minutes of movement play today — balancing, hopping, rolling. No program, just body and fun.",
      discussion_body: "Which movement activity brings your child the most joy — and why?",
      companion_quick: "Movement isn't a leisure activity — it's an engine for learning.",
      companion_reflect: "What did your child try or dare physically today that was new?",
    },
    milestone_uebergaenge: {
      title: 'Preparing for puberty — early and relaxed',
      parent_lens: "Puberty starts earlier than most parents think — and the course is set in childhood. Open communication and a secure parent-child relationship are the best preparation.",
      parent_tips: [
        "Talk about body changes early — matter-of-factly, without drama. Children who are informed have less fear.",
        "Share your own puberty memories (appropriately): 'I was unsure about ... back then too' — that normalizes it.",
        "Create space for privacy: knock, respect diaries. Trust arises through respect.",
      ],
      practical_tip: "Watch an age-appropriate video or book about body processes together with your child today — without shyness.",
      discussion_body: "Looking back, what mattered to you during puberty — and what do you wish your parents had done?",
      companion_quick: "The best puberty preparation is a strong relationship today.",
      companion_reflect: "Did your child ask a question today that shows they're starting to reflect on themselves?",
    },
    gfk_wiedergutmachung: {
      title: 'When parents lose it — making amends as a strength',
      parent_lens: "No parent is patient all the time. When you lose it, that's not a failure as a parent — it's a human moment. But what comes after shapes the relationship more strongly than the outburst itself.",
      parent_tips: [
        "Making amends needs three steps: take responsibility ('I was wrong'), show compassion, and if needed, do it differently.",
        "Apologize without 'but': 'I'm sorry I was so loud. That wasn't okay.' — done.",
        "Your child sees you as human — that's good. Children learn through repair that relationships survive storms.",
      ],
      practical_tip: "If you didn't behave well in a situation today: go back to your child and say so. Three sentences are enough.",
      discussion_body: "How have you as parents learned to handle your own outbursts — without judging yourselves too harshly?",
      companion_quick: "Making amends teaches children something no guidebook can: that relationships can be repaired.",
      companion_reflect: "Was there a moment today you would have handled differently in hindsight — and what did you take from it?",
    },
  },
  tr: {
    gfk_warum: {
      title: '"Neden" sorularını sakin şekilde karşılamak',
      parent_lens: "Çocuğunuz günde yüz kez 'Neden?' diye soruyor. Bunu sizi sinirlendirmek için değil, beyni bağlantılar kurduğu için yapıyor. Dünyayı anlamak istiyor.",
      parent_tips: [
        "Şiddetsiz iletişimi (NVC) kullanın: azarlamak yerine kendi duygu ve ihtiyaçlarınızı açıkça ifade edin.",
        "'Neden' sorularını kısa ve basit yanıtlayın — çocuğunuz mantık arıyor, bilimsel bir ders değil.",
        "Sınırları cezayla değil, kişisel varlığınızla sevgiyle koyun ('Vurmanı istemiyorum').",
      ],
      practical_tip: "Bir sonraki 'neden' sorusunda önce duyguyu yansıtın ('Meraklısın!'), sonra tek cümleyle yanıtlayın.",
      discussion_body: "Çocuğunuz onuncu kez 'neden' diye sorduğunda hangi kısa, sakin ifade size yardımcı oluyor?",
      companion_quick: "Bugün bir neden sorusuna sadece sakin bir yanıt verin ve sonrasında bilinçli olarak kısa kalın.",
      companion_reflect: "Çocuğunuz bugün en çok ne zaman bağlantı aradı — ve ona nasıl sakin bir yön verebildiniz?",
    },
    gfk_grenzen: {
      title: 'Sınırları sevgiyle ve netlikle koymak',
      parent_lens: "Sevgi dolu sınırlar bir çelişki değildir. Çocukların ikisine de ihtiyacı var: sevildiğini hissetmek VE nelerin olmadığı konusunda net bir yönlendirme. Bağlantısız sınırlar duvar gibi hissettirir — bağlantılı sınırlar korkuluk gibi hissettirir.",
      parent_tips: [
        "Önce çocuğunuzun duygusunu, sonra sınırı adlandırın: 'Kızgın olduğunu görüyorum. Yine de: vurmak olmaz.'",
        "Bedenen sakin kalın — tonunuz sözlerinizden daha yüksek sesle konuşur. Tepki vermeden önce derin bir nefes alın.",
        "Sonuçları söyleyin ve uygulayın. Tehdit etmeyin, önceden bildirin: 'Eğer ... yaparsan o zaman ...'",
      ],
      practical_tip: "Bugün duygu + sınır cümlesi kurmayı deneyin: 'Bunu istediğini anlıyorum. Ve: hayır.' — ve bunu sakin bir şekilde söyleyin.",
      discussion_body: "Kendi sınırlarınıza ulaştığınızda nasıl tepki veriyorsunuz? Hangi cümle sakin kalmanıza yardımcı oluyor?",
      companion_quick: "Bir sonraki sınır tepkisinden önce derin bir nefes alın — işin yarısı bu.",
      companion_reflect: "Bugün sakin bir sınırın yüksek sesli bir hayırdan daha iyi işlediği bir durum oldu mu?",
    },
    gfk_ichbotschaft: {
      title: '"Sen" suçlamaları yerine "ben" mesajları',
      parent_lens: "'Sen' mesajları ('Çok yüksek sesle konuşuyorsun!') savunmayı tetikler. 'Ben' mesajları ('Yoruluyorum ve sessizliğe ihtiyacım var') kapıları açar. Çocuklar kendilerini saldırıya uğramış hissetmediklerinde daha çok dinler.",
      parent_tips: [
        "Suçlamaları 'ben' mesajlarına dönüştürün: 'Sen hiç dinlemiyorsun' yerine → 'Kendimi duyulmuş hissetmiyorum ve bu beni üzüyor.'",
        "İhtiyacınızı paylaşın: 'Şimdi düşünmek için kısa bir sessizliğe ihtiyacım var.' Çocuklar ihtiyaçları şaşırtıcı derecede iyi anlar.",
        "Günlük hayatta pratik yapın: klasik üç cümleyi 'ben' mesajına dönüştürün — sabah diş fırçalarken, öğlen yemekte, akşam uyku öncesi.",
      ],
      practical_tip: "Bugün genellikle 'Sen hep...' dediğiniz bir durumu seçin — ve 'Ben ... hissediyorum çünkü ... ihtiyacım var' ile değiştirin.",
      discussion_body: "Hangi 'sen' mesajını yeniden ifade etmek size en zor geliyor? Bu konuda ne yardımcı oluyor?",
      companion_quick: "Duyguyu + ihtiyacı adlandırmak — gerçek bir 'ben' mesajının formülü budur.",
      companion_reflect: "Bugün bir 'ben' mesajı sizi şaşırtan bir tepkiye yol açtı mı?",
    },
    gfk_trotz: {
      title: 'İnat dönemlerini sakin bir şekilde desteklemek',
      parent_lens: "İnat bir isyan değildir — bir gelişimdir. Bir çocuk yerde yatıp bağırdığında, prefrontal korteksi duyguyu düzenlemek için henüz yeterince olgunlaşmamıştır. Sizin ona bir eş-düzenleyici olarak ihtiyacı var.",
      parent_tips: [
        "Zorlamadan bedenen yakın kalın: diz seviyesine inin, sakin konuşun, çocuk reddediyorsa dokunmayın.",
        "Fırtınanın ortasında tartışmaktan kaçının. Konuşma ancak sakinleştiğinde gelir.",
        "'Duygu köprüleri' kullanın: 'Dondurmayı istedin. Bu senin için çok önemliydi. Bunu anlıyorum.'",
      ],
      practical_tip: "Çocuğunuz kendinden geçtiğinde: yanına oturun. Uzaklaşmayın, müdahale etmeyin — sadece orada olun. Bu bile düzenlemeye yardımcı olur.",
      discussion_body: "Çocuğunuz duygusal bir patlamanın ortasındayken siz sakin kalmak için neye ihtiyaç duyuyorsunuz?",
      companion_quick: "İnat dönemleri için üç kelime: yakın kal. Sakin nefes al. Bekle.",
      companion_reflect: "Bugün sizi en çok ne yordu — ve bu sırada sakin kalmanıza ne yardımcı oldu?",
    },
    gfk_geschwister: {
      title: 'Kardeş kavgalarını bir öğrenme alanı olarak kullanmak',
      parent_lens: "Kardeşler kavga eder — bu normaldir ve hatta önemlidir. Kavgada çocuklar uzlaşmayı, bakış açısı değiştirmeyi ve kendini savunmayı öğrenir. Sizin rolünüz hakem değil, arabulucudur.",
      parent_tips: [
        "Taraf tutmayın: 'İkinizin de şu anda kızgın olduğunu görüyorum. Önce seni, sonra seni dinleyeceğim.'",
        "Durum tırmanmıyorsa çocukların kendi çözümlerini bulmasına izin verin. Ancak gerçek bir tehlike varsa müdahale edin.",
        "Her çocuğu tek tek güçlendirin: düzenli 1:1 anlar kıskançlığı uzun vadede azaltır.",
      ],
      practical_tip: "Bir sonraki kavgada her iki çocuğa da 'Şu anda neye ihtiyacın var?' diye sorun — kimin haklı olduğuna karar vermeden önce.",
      discussion_body: "Kardeşler kavga ettiğinde bunu nasıl ele alıyorsunuz? Sizde en iyi ne işe yarıyor?",
      companion_quick: "Hakem değil, arabulucu — kardeş çatışmalarındaki rolünüz budur.",
      companion_reflect: "Bugün çocuklarınızın bir kavgayı kendi başlarına çözdüğü bir an oldu mu? Bundan ne öğrendiniz?",
    },
    gfk_gefühle: {
      title: 'Duyguları adlandırmak ve kabul etmek',
      parent_lens: "Duygularını adlandırabilen çocukların büyük bir avantajı vardır: neye ihtiyaç duyduklarını iletebilirler. Hissetmekten konuşmaya giden bu adım pratik ve sizin desteğinizi gerektirir.",
      parent_tips: [
        "'Duygu barometresini' kullanın: akşam 'Günün 1-5 arasında nasıldı?' diye sorun — ve önce siz anlatın.",
        "Kendi duygularınızı yüksek sesle adlandırın: 'Şu anda biraz stresliyim çünkü çok düşünmem gerekiyor.' Örnek olmak işe yarar.",
        "Duygularla ilgili çocuk kitapları okuyun — ve sonra durup sorun: 'Karakter ne hissetti sence? Ya sen?'",
      ],
      practical_tip: "Bu akşam sorun: 'Bugün seni ne mutlu etti? Seni ne üzdü veya kızdırdı?' — ve sadece dinleyin.",
      discussion_body: "Çocuğunuzun adlandırması en zor olan duygu hangisi? Buna nasıl yaklaşıyorsunuz?",
      companion_quick: "Önce hisset, sonra adlandır — duygu alfabesi sizin örnek olmanızla başlar.",
      companion_reflect: "Bugün çocuğunuzun hangi duygu anını hatırlamak istediniz?",
    },
    gfk_nein: {
      title: 'Vicdan azabı duymadan hayır demek',
      parent_lens: "Hiç hayır demeyen ebeveynler, sınır tanımayan çocuklar yetiştirir. Sevgi dolu bir hayır çocuğunuza şunu gösterir: kendi ihtiyaçlarımı ciddiye alıyorum — sen de alabilirsin.",
      parent_tips: [
        "Bir hayırın uzun bir açıklamaya ihtiyacı yoktur. Net bir 'Hayır, şu anda olmaz' yeterlidir.",
        "Hayırdan sonraki suçluluk bir hatanın değil, bir sinyalin işaretidir. Kendinize sorun: bu hayır gerçekten yanlış mı, yoksa sadece rahatsız edici mi?",
        "Diğer yetişkinlere de hayır demeyi pratik edin (oyun randevuları, sözler) — çocuğunuz sizin örneğinizden öğrenir.",
      ],
      practical_tip: "Bugün bilinçli olarak bir kez hayır deyin — özür dilemeden. Nasıl hissettirdiğine dikkat edin.",
      discussion_body: "Hayır demek size ne zaman en zor geliyor — çocuklarınıza mı, yoksa başkalarına mı?",
      companion_quick: "Bir şeye hayır demek, daha önemli bir şeye — genellikle kendinize — evet demektir.",
      companion_reflect: "Bugün geriye dönüp baktığınızda doğru hissettiren bir hayır oldu mu?",
    },
    inclusion_stärken: {
      title: 'Zayıflıkları değerlendirmek yerine güçlü yönleri görmek',
      parent_lens: "Her çocuğun kendine özgü bir güçlü yönler bileşimi vardır. Ebeveynler olarak genellikle önce eksikleri görürüz — oysa ham elması parlatabilecek ilk kişiler biz olabiliriz.",
      parent_tips: [
        "Bu akşam çocuğunuzun 3 güçlü yönünü yazın — başarılar değil, karakter özellikleri ('meraklı', 'şefkatli', 'azimli').",
        "Güçlü yönleri somut ve zamanında adlandırın: 'Az önce çok sabırlıydın — bu gerçekten harika.'",
        "Kardeşler veya diğer çocuklarla karşılaştırmaktan kaçının. Her gelişim eğrisi kendine özgüdür.",
      ],
      practical_tip: "Bugün çocuğunuzla güçlü yönlerinden biri hakkında konuşun — övgü olarak değil, bir gözlem olarak: 'Bugün senin ... yaptığını gördüm.'",
      discussion_body: "Bugün çocuğunuzun hangi gizli güçlü yönünü paylaşmak istersiniz?",
      companion_quick: "Güçlü yönleri görmek, zayıflıkları görmezden gelmek değildir — büyümeye olanak tanımaktır.",
      companion_reflect: "Bugün çocuğunuzun hangi güçlü yönü sizi şaşırttı veya etkiledi?",
    },
    inclusion_selbstwert: {
      title: 'Öz saygıyı her gün inşa etmek',
      parent_lens: "Öz saygı yalnızca övgüyle oluşmaz — şu deneyimle oluşur: 'Bir şey yapabiliyorum. Önemliyim. Buraya aitim.' Bu üç deneyimi her gün yaşatabilirsiniz.",
      parent_tips: [
        "Çocuğunuzun küçük kararlar almasına izin verin: 'Önce ödevleri mi yapmak istersin, önce oynamak mı?' Özerklik = öz saygı.",
        "Gerçek ilgi gösterin: telefonu bırakın, yüzüne bakın, sorular sorun. 10 dakika tam dikkat mucizeler yaratır.",
        "Sadece sonucu değil, süreci kutlayın: 'Bunu bu kadar uzun süre denedin — önemli olan kısım bu.'",
      ],
      practical_tip: "Bugün: çocuğunuza 10 dakika bölünmemiş dikkat gösterin — telefon yok, dikkat dağıtıcı yok, sadece ilgi.",
      discussion_body: "Çocuğunuzu kendisiyle özellikle gururlandıran nedir — ve bu duyguyu nasıl destekliyorsunuz?",
      companion_quick: "Öz saygı aynadan değil, bizi sevenlerin gözlerinden gelir.",
      companion_reflect: "Çocuğunuz bugün hangi anda 'Bunu yapabilirim!' dedi?",
    },
    inclusion_scheitern: {
      title: 'Başarısızlığı bir öğrenme fırsatı olarak görmek',
      parent_lens: "Beyin en güçlü şekilde hatalardan öğrenir — başarılardan değil. Çocuğunuz başarısız olduğunda siz sakin kalırsanız, ona en güçlü sinyali verirsiniz: 'Başarısız olmak güvenlidir. Ben bunu kaldırabilirim.'",
      parent_tips: [
        "Başarısızlıkta önce şefkat, sonra çözüm: 'Bu sinir bozucuydu. Bir dahaki sefere ne farklı yapabiliriz?'",
        "Kendi başarısızlıklarınızdan bahsedin: 'Ben de bir keresinde ... ve sonra ... öğrendim.' Örnek olmak tabuyu kaldırır.",
        "'Sana söylemiştim'den kaçının. Bu kapıları kapatır. Bunun yerine: 'Bundan ne çıkardın?'",
      ],
      practical_tip: "Bugün çocuğunuza kendi başarısızlıklarınızdan birinden bahsedin — ve bundan ne öğrendiğinizi anlatın.",
      discussion_body: "Aile olarak yenilgilerle nasıl başa çıkıyorsunuz? Başarısızlığı öğrenmenin bir parçası olarak görmenize ne yardımcı oluyor?",
      companion_quick: "Hata yapmasına izin verilen çocuklar daha cesur yetişkinler olur.",
      companion_reflect: "Bugün çocuğunuzun iyi atlattığı bir başarısızlık oldu mu? Buna ne yardımcı oldu?",
    },
    inclusion_hochsensibel: {
      title: 'Yüksek duyarlı çocukları anlamak ve desteklemek',
      parent_lens: "Çocukların yaklaşık %20'si yüksek duyarlıdır — daha fazlasını algılar, daha yoğun hisseder ve daha fazla dinlenme süresine ihtiyaç duyarlar. Bu bir zayıflık değil, kendine özgü güçlü yönleri olan bir kişilik özelliğidir.",
      parent_tips: [
        "Uyaran yoğunluğunu azaltın: yüksek baskılı durumlardan önce (alışveriş, okul, parti) sakin geçiş süreleri planlayın.",
        "Öngörülebilirlik korur: neler olacağını önceden bildirin ('10 dakika sonra gidiyoruz'). Sürprizler yüksek duyarlı çocuklar için yorucudur.",
        "Duyarlılıkları bir güçtür: birinin üzgün olduğunu fark eder ve derin düşünürler. Bunu olumlu bir şekilde adlandırın.",
      ],
      practical_tip: "Bugün yüksek baskılı bir durumdan sonra çocuğunuz için 15 dakikalık sessiz bir 'şarj olma zamanı' planlayın — ekran yok, beklenti yok.",
      discussion_body: "Çocuğunuzda yüksek duyarlı özellikler fark ediyor musunuz? Günlük hayatta bununla başa çıkmanıza ne yardımcı oluyor?",
      companion_quick: "Yüksek duyarlı çocukların katılaşmaya değil, korunaklı alanlara ve anlayışa ihtiyacı vardır.",
      companion_reflect: "Çocuğunuz bugün en çok ne zaman çok fazla izlenim işledi — ve bundan sonra nasıl toparlandı?",
    },
    inclusion_freundschaft: {
      title: 'Arkadaşlıklara eşlik etmek — yönlendirmemek',
      parent_lens: "Arkadaşlıklar sosyal beceriler için en önemli öğrenme yeridir. Çocuklar vermeyi ve almayı, müzakere etmeyi ve vazgeçmeyi öğrenir — ama sadece ebeveynler olarak biz bırakıp yönlendirmek yerine eşlik edersek.",
      parent_tips: [
        "Sorun ama yargılamayın: 'Bugün ... ile nasıl geçti?' 'Onu sevmiyorum, geçenlerde ... yaptı' demekten daha iyidir.",
        "Çocukların önce kendi aralarındaki çatışmaları çözmesine izin verin — ancak gerçek bir sıkıntı olduğunda müdahale edin.",
        "Arkadaşlıkları aktif olarak mümkün kılın: oyun randevuları, davetler. Sosyal fırsatlar kendiliğinden ortaya çıkmaz.",
      ],
      practical_tip: "Bugün çocuğunuza sorun: 'Sınıfından / grubundan kim senin sevdiğin şeyleri seviyor?' — ve birlikte zaman yaratmayı düşünün.",
      discussion_body: "Seçimlerini her zaman anlamasanız bile çocuklarınıza kendi arkadaşlıkları için nasıl alan tanıyorsunuz?",
      companion_quick: "Gerçek arkadaşlık zorla oluşturulamaz — ama birlikte verimli bir zemin hazırlayabilirsiniz.",
      companion_reflect: "Çocuğunuz bugün kendisi için önemli olan biri hakkında konuştu mu? Bundan ne öğrendiniz?",
    },
    inclusion_resilienz: {
      title: 'Dayanıklılık — çocuklar zorluklarla nasıl büyür',
      parent_lens: "Dayanıklılık doğuştan gelmez — pratikle kazanılır. Çocuklar zorluklar yaşadıklarında VE bu sırada desteklendiklerinde dayanıklı hale gelirler. Anahtar koruma değil, eşliktir.",
      parent_tips: [
        "Çocuğunuzun zorlukları tamamlamasına izin verin: çok erken yardım etmeyin. Gerçekten daha fazla ilerleyemediğinde yardım teklif edin.",
        "İçsel diyaloğu güçlendirin: doğrudan çözümü vermek yerine 'Ne yapabileceğini düşünüyorsun?' diye sorun.",
        "Aile krizlerini yaşına uygun şekilde konuşun: dışlanan çocuklar gerçeğinden daha kötü fanteziler geliştirir.",
      ],
      practical_tip: "Çocuğunuz bugün başarısız olursa: müdahale etmeden önce 30 saniye bekleyin. Çözüm genellikle kendiliğinden gelir.",
      discussion_body: "Çocuğunuz sizi şaşırtan hangi zorluğun üstesinden geldi?",
      companion_quick: "Dayanıklılık, zorluk ile destek arasındaki alanda büyür — öncesinde veya sonrasında değil.",
      companion_reflect: "Çocuğunuzun bugün içsel olarak büyüdüğünü nereden anlıyorsunuz?",
    },
    inclusion_vielfalt: {
      title: 'Çeşitliliği deneyimlemek — farklılık bir güçtür',
      parent_lens: "İnsanların köken, yetenek ve düşünce biçimi açısından farklı olduğunu erken öğrenen çocuklar, daha fazla empati ve daha az temas korkusu geliştirir. Çeşitliliği günlük hayatta canlı kılabilirsiniz.",
      parent_tips: [
        "Farklılıklar hakkında açıkça konuşun — çocuklar bunları zaten fark eder. 'Evet, Lara'nın ten rengi senden farklı — ve ailesi ... 'dan geliyor.'",
        "Farklı karakterlerin olduğu kitaplar, filmler ve oyunlar seçin — temsil dünya görüşünü etkiler.",
        "Aile kendine özgülüklerini kutlayın: 'Bizde böyle, başka ailelerde farklı — güzel olan da bu.'",
      ],
      practical_tip: "Bugün çocuğunuzdan farklı bir ana karakterin olduğu bir çocuk kitabı okuyun — ve sonrasında bunu konuşun.",
      discussion_body: "Çocuklara insanlar arasındaki farklılıkları korku yerine merak uyandıracak şekilde nasıl anlatıyorsunuz?",
      companion_quick: "Çocuklar doğal olarak farklılıklara meraklıdır — önyargıyı ancak sonradan öğrenirler.",
      companion_reflect: "Çocuğunuz bugün sizi düşündüren, farklılıklarla ilgili bir soru sordu mu?",
    },
    leadership_struktur: {
      title: 'Günlük yapı bir güven demiri olarak',
      parent_lens: "Bir çocuğun beyni öngörülebilirliği sever. Ritüeller ve yapılar bir kısıtlama değildir — çocuklara güvenle gelişme özgürlüğü veren bir iskelettir.",
      parent_tips: [
        "Günde sabit demirler: uyanma ritüeli, öğünler, uyku saati. Gerçek istikrar için bu üçü yeterlidir.",
        "Geçiş ritüelleri planlayın: etkinlikler arasında kısa geçişleri önceden bildirin. '5 dakika sonra topluyoruz.'",
        "Yapı stres değildir — gerektiğinde aniden değil, kademeli olarak değiştirin.",
      ],
      practical_tip: "Bugün çocuğunuzla birlikte günlük plana bakın — ne geleceğini konuşun. Bu direnci ve belirsizliği azaltır.",
      discussion_body: "Ailenizde hangi günlük ritüel özellikle önemli — ve neden?",
      companion_quick: "Öngörülebilirlik güven yaratır. Güven öğrenmeye hazır olmayı yaratır.",
      companion_reflect: "Bugün hangi an çocuğunuzun yapıya ihtiyaç duyduğunu — veya bundan keyif aldığını gösterdi?",
    },
    leadership_schlaf: {
      title: 'Uyku ritüelleri — beden ve zihin için huzur yaratmak',
      parent_lens: "Uyku bir mola değil, gelişim zamanıdır. Uyku sırasında beyin günü işler, anıları pekiştirir ve yenilenir. İyi bir uyku ritüeli çocuğunuza yapılan en etkili yatırımlardan biridir.",
      parent_tips: [
        "Uyumadan 30 dakika önce: ekran yok, heyecanlı oyunlar yok. Sakinleşmek zaman alır.",
        "Her zaman aynı sıra: dişler, pijama, hikaye, ışık kapalı. Ritüeller beyne 'Şimdi uyku zamanı' sinyalini verir.",
        "Çocuğunuz uyuyamıyorsa: birlikte nefes alın. 4 saniye al, 6 saniye ver — bu parasempatik sinir sistemini aktive eder.",
      ],
      practical_tip: "Bu akşam uyumadan önce 3 dakikalık bir nefes ritüeli uygulayın — nefes alın, verin, birlikte.",
      discussion_body: "En sevdiğiniz uyku ritüeli nedir — ve onu nasıl geliştirdiniz?",
      companion_quick: "Sakin bir kapanış ritüeli iyi bir uykuya en iyi başlangıçtır.",
      companion_reflect: "Bugün uykuya dalmak nasıldı — ne yardımcı oldu, ne rahatsız etti?",
    },
    leadership_bildschirm: {
      title: 'Ekran süresini bilinçli olarak şekillendirmek',
      parent_lens: "Sorun olan ekran süresinin kendisi değil — sonrasında konuşma olmadan kontrolsüz, pasif tüketimdir. Basit çerçeve koşullarıyla ekran sağlıklı bir boş zaman etkinliği haline gelir.",
      parent_tips: [
        "Ani yasaklar yerine sabit zamanlar: 'Ödevlerden sonra saat 17'ye kadar' 'çok fazla değil' den daha nettir.",
        "Birlikte izleyin ve sonra konuşun: 'Neyi beğendin? Ne tuhaf veya garip geldi?' medya okuryazarlığını güçlendirir.",
        "Ekransız alanlar oluşturun: yatak odası ve yemek masası iyi başlangıç sınırlarıdır.",
      ],
      practical_tip: "Bugün birlikte 15 dakika bir şey izleyin — ve sonrasında bununla ilgili 2 soru sorun. Bu çocuğunuzun medyayı algılama biçimini değiştirir.",
      discussion_body: "Ekran süresini evinizde nasıl yönetiyorsunuz — ne işe yaradı, ne daha az işe yaradı?",
      companion_quick: "Bilinçli medya kullanımı yasakla değil, konuşmayla öğrenilir.",
      companion_reflect: "Çocuğunuz bugün medyayı nasıl kullandı — aktif mi, pasif mi? Ne fark ettiniz?",
    },
    leadership_autoritaet: {
      title: 'Korkuyla değil, bağla otorite',
      parent_lens: "Otoriter olmak yüksek sesli ve katı olmak anlamına gelmez. Gerçek ebeveyn otoritesi, bir çocuk şunu bildiğinde ortaya çıkar: 'Beni seviyorsun VE nettsin.' Bağ ve liderlik birbirini dışlamaz — birbirini tamamlar.",
      parent_tips: [
        "Tartışma olmadan net ifadeler: 'Bunu şimdi böyle yapıyoruz.' Sonrasında pazarlık yok — sadece anlayış sunun.",
        "Özürler yetişkinleri daha zayıf değil, daha güçlü yapar. 'Az önce bu benden adil değildi' — çocuklar buna saygı duyar.",
        "Bazı kuralları birlikte oluşturun — bu onlara uyma isteğini artırır.",
      ],
      practical_tip: "Bugün bir kuralı yasak yerine olumlu bir görev olarak ifade edin: 'Oynadıktan sonra topluyoruz' yerine 'Ortalıkta bırakma.'",
      discussion_body: "Liderlik ile çocuklarınızın söz hakkı arasındaki dengeyi nasıl buluyorsunuz?",
      companion_quick: "Bağlantısız otorite kontroldür. Otoritesiz bağlantı kaostur. İkisi birlikte liderliktir.",
      companion_reflect: "Bugün sakin netliğinizin güçlü bir sözden daha fazla işe yaradığı bir an oldu mu?",
    },
    leadership_hausaufgaben: {
      title: 'Stressiz ödev — işe yarayan bir çerçeve',
      parent_lens: "Ödev stresi genellikle bir öğrenme sorunu değildir — bir ritüel sorunudur. Doğru yapı ve doğru zamanlamayla konu kendiliğinden rahatlar.",
      parent_tips: [
        "Doğru zamanı bulun: okuldan hemen sonra veya kısa bir dinlenmeden sonra — ama akşamdan önce.",
        "Buradayım ama hemen yardım etmiyorum: önce kendisi denesin. 10 dakika ilerleme olmazsa: 'Nerede takıldın?' diye sorun.",
        "Çalışma alanını hazırlayın: sabit bir yer, düzenli bir masa, görüş alanında telefon yok — bu dikkat dağınıklığını azaltır.",
      ],
      practical_tip: "Bugün çocuğunuzla birlikte hafta için TEK bir ödev zamanı belirleyin — ve yazın.",
      discussion_body: "Sizde ödevleri daha az stresli hale getiren ne oldu? Hangi rutinler işe yarıyor?",
      companion_quick: "Öğrenirken yapı bir kısıtlama değildir — konsantrasyonun motorudur.",
      companion_reflect: "Bugün öğrenme nasıl geçti? Yarın farklı ne deneyebilirsiniz?",
    },
    leadership_selbstaendigkeit: {
      title: 'Bağımsızlık — bırakmak da sevgidir',
      parent_lens: "Çocuklar onlara güvendiğimizde bağımsız hale gelir. Ama bırakmak riskli hissettirir — ve bu normaldir. Sanat, sorumluluğu adım adım devretmektir.",
      parent_tips: [
        "Yaşa uygun görevler verin: 3 yaşındakiler oyuncakları toplar, 6 yaşındakiler masayı kurar, 10 yaşındakiler yemek pişirmeye yardım eder.",
        "Yavaş gittiğinde araya girmeyin. Yavaş ve kendi başına, hızlı ve yardımla olmaktan daha değerlidir.",
        "Bağımsız görevlerdeki hataları kabul edin: süt bardağı devrilir — bu başarısızlık değil, alıştırmadır.",
      ],
      practical_tip: "Bugün çocuğunuza şimdiye kadar kendinizin yaptığı yeni bir görev devredin — ve tamamen kendi başına yapmasına izin verin.",
      discussion_body: "Çocuğunuzun ikinizin de gurur duyduğu en büyük bağımsızlık başarısı nedir?",
      companion_quick: "Çocuğun kendi başına tamamladığı her görev, gelecekteki özgüvenine yapılan bir yatırımdır.",
      companion_reflect: "Bugün ne zaman bıraktınız — ve bu size nasıl hissettirdi?",
    },
    leadership_natur: {
      title: 'Aile ritüeli olarak doğa ve hareket',
      parent_lens: "Düzenli olarak dışarıda olan çocuklar daha iyi uyur, daha odaklıdır ve duygusal olarak daha dengelidir. Doğa bir boş zaman etkinliği değildir — temel bir ihtiyaçtır.",
      parent_tips: [
        "Günde 15 dakika dışarıda olmak bile ölçülebilir etkiye sahiptir — gezi gerekmez, okul yolu bile sayılır.",
        "Birlikte hareket edin: bisiklet, yürüyüş, oyun alanı. Birlikte hareket etmek bağı güçlendirir.",
        "Çocuğunuzun doğayı keşfetmesine izin verin: taşlar, böcekler, su birikintileri. Program yok — sadece açıklık.",
      ],
      practical_tip: "Bugün dışarıda 15 dakikalık bir tur planlayın — hedef yok, program yok, sadece birlikte.",
      discussion_body: "Çocukluğunuzdan hangi doğa deneyimini çocuklarınıza aktarmak istersiniz?",
      companion_quick: "Dışarıda olmak beyin için besindir — çocuklar ve yetişkinler için.",
      companion_reflect: "Bugün dışarıda geçirdiğiniz zaman ruh halinizi nasıl değiştirdi?",
    },
    milestone_sprache: {
      title: 'Dil gelişimi — oyunla nasıl desteklersiniz',
      parent_lens: "Dil gelişimi kelime çalışmasıyla değil, diyalogla gerçekleşir. Çocuklar, yetişkinler onlarla konuştuğunda, onları dinlediğinde ve söylediklerine tepki verdiğinde konuşmayı öğrenir.",
      parent_tips: [
        "Günlük hayatınızı yüksek sesle anlatın: 'Şimdi havuçları kesiyorum' — bu pasif kelime dağarcığını zenginleştirir.",
        "Çocuğunuzun ifadelerini alıp genişletin: 'Top!' — 'Evet, kırmızı top yuvarlanıyor.'",
        "Çocuk kendisi okuyabilse bile her gün sesli okuyun. Kitaplardaki metinler günlük konuşmadan farklı yapılara sahiptir.",
      ],
      practical_tip: "Bugün 10 dakika sesli okuyun — ve okurken sorun: 'Sence şimdi ne olacak?'",
      discussion_body: "Çocuğunuzun son zamanlarda söylediği hangi kelimeler veya cümleler sizi özellikle şaşırttı veya duygulandırdı?",
      companion_quick: "Dil, sessizlikte değil, konuşmada büyür.",
      companion_reflect: "Bugün çocuğunuzun hangi dil ilerlemesini fark ettiniz?",
    },
    milestone_schule: {
      title: 'Okul başlangıcı ve geçişleri sakin bir şekilde desteklemek',
      parent_lens: "Geçişler — okula başlama, sınıf değişikliği, yeni kreş — çocuklar için en yoğun öğrenme dönemleridir. Sizin sakinliğiniz ve güveniniz çocuğunuza yansır. Siz düzenleme temelisiniz.",
      parent_tips: [
        "Yeni yerleri önceden tanıyın: mümkünse ilk günden önce yeni sınıfı veya okulu ziyaret edin.",
        "Duygular hakkında konuşun: 'Heyecanlanmak sorun değil. Ben de ilk okul gününde gergindim.'",
        "Küçük geçiş nesneleri yardımcı olur: çantada bir fotoğraf, küçük bir hatıra — nesneler güven yaratır.",
      ],
      practical_tip: "Bugün çocuğunuza sorun: '... hakkında neyi sabırsızlıkla bekliyorsun? Seni hâlâ ne endişelendiriyor?' — ve yargılamadan dinleyin.",
      discussion_body: "Çocuğunuzun önemli bir geçişine nasıl eşlik ettiniz? Ne yardımcı oldu?",
      companion_quick: "Geçişler aynı anda hem bir son hem bir başlangıçtır — ve ikisi de hissedilebilir.",
      companion_reflect: "Bugün çocuğunuz bir geçişle ilgili hangi duyguyu gösterdi?",
    },
    milestone_sozial: {
      title: '21. yüzyılın en önemli becerisi — sosyal zeka',
      parent_lens: "IQ kapıları açar. EQ (duygusal zeka) insanları içeri alır. Yüksek sosyal yeterliliğe sahip çocuklar daha iyi işbirliği yapabilir, iletişim kurabilir ve kendilerini başkalarının yerine koyabilir — bunu sizden öğrenirler.",
      parent_tips: [
        "Her gün empatiyi modelleyin: 'Kedi üzgün görünüyor. Sence neden?'",
        "Bakış açısı değiştirmeyi pratik edin: 'Bunu söylediğinde ... sence nasıl hissetti?'",
        "Sosyal davranışı açıkça övün: 'Konuşmasını bitirene kadar bekledin. Bu çok saygılıydı.'",
      ],
      practical_tip: "Bugün kreş veya okuldan sonra sosyal bir durum hakkında konuşun: 'Bugün biri güzel bir şey yaptı mı?'",
      discussion_body: "Bugün için çocuklar ve yetişkinler için sosyal yeterliliğin hangi yönünü en önemli buluyorsunuz?",
      companion_quick: "Sosyal yeterlilik bir yetenek değildir — pratikle kazanılan bir beceridir.",
      companion_reflect: "Çocuğunuz bugün ne zaman empati gösterdi — belki fark edilmese bile?",
    },
    milestone_emotion: {
      title: 'Duygusal olgunluk — duygular işlendiğinde',
      parent_lens: "Duygusal olgunluk hiç duygu yaşamamakla değil, onları işlemekle kendini gösterir. Duygularını ifade etmesine izin verilen çocuklar uzun vadede bunlarla daha iyi başa çıkmayı öğrenir.",
      parent_tips: [
        "Tüm duygulara izin var — tüm davranışlara değil. 'Kızgın olabilirsin. Vuramazsın.'",
        "Duyguları küçümsemeyin: 'O kadar da kötü değil' yerine → 'Bunun seni gerçekten etkilediğini görüyorum.'",
        "Duyguların bedende hissedilmesine izin verin: 'Bunu şu anda nerede hissediyorsun? Karnında mı? Göğsünde mi?'",
      ],
      practical_tip: "Bugün sorun: 'Bu bedeninde nasıl hissettiriyor?' — ve gelen her yanıtı kabul edin.",
      discussion_body: "Ailenizde hangi duyguyu açıkça göstermek en zor?",
      companion_quick: "Duygulara izin vermek zayıflık değildir — duygusal güçtür.",
      companion_reflect: "Çocuğunuz bugün hangi duyguyu açıkça gösterdi — ve buna birlikte nasıl eşlik ettiniz?",
    },
    milestone_kreativitaet: {
      title: 'Sonuç odaklı olmadan yaratıcılığı desteklemek',
      parent_lens: "Yaratıcılık kılık değiştirmiş problem çözme becerisidir. Çocuklar resim yaptığında, inşa ettiğinde, el işi yaptığında veya oynadığında esnekliği ve özgünlüğü geliştirirler — geleceğin becerileri bunlardır.",
      parent_tips: [
        "Son ürüne odaklanmayın: 'Ne yaptığını anlat' 'Bu ne olacaktı?' demekten daha iyidir.",
        "Talimatsız malzemeler sunun: kumaş, karton, doğal malzemeler — ve sonra bırakın.",
        "Kendiniz yaratıcı olun: ebeveynler mükemmellik aramadan resim yaptığında, inşa ettiğinde, şarkı söylediğinde çocuklarına da aynısına izin verirler.",
      ],
      practical_tip: "Bugün 20 dakika serbest el işi sunun — şablon yok, talimat yok, sadece malzemeler.",
      discussion_body: "Çocuğunuzun şimdiye kadar kendisinin geliştirdiği en yaratıcı proje nedir?",
      companion_quick: "Yaratıcılığın alana, zamana ve yargılamayan bir yetişkine ihtiyacı vardır.",
      companion_reflect: "Çocuğunuz bugün ne icat etti, inşa etti veya hayal etti — sizi şaşırtan?",
    },
    milestone_koerper: {
      title: 'Beden farkındalığını güçlendirmek — gelişim motoru olarak hareket',
      parent_lens: "Motor gelişim ve bilişsel gelişim ayrılmaz bir şekilde bağlantılıdır. Tırmanan, denge kuran ve dans eden çocuklar mekansal düşünme becerilerini ve konsantrasyonlarını da geliştirirler.",
      parent_tips: [
        "Hareketi günlük hayata dahil edin: bir spor programı olarak değil, günlük yaşam olarak — asansör yerine merdiven, taşımak yerine yürümek.",
        "Kaba ve ince motor becerilerini değiştirin: inşa etmek (ince) ve tırmanmak (kaba) birbirini harika tamamlar.",
        "Beden imajını olumlu güçlendirin: 'Bedenin o kadar çok şey yapabiliyor' — görünüşten veya performanstan bağımsız olarak.",
      ],
      practical_tip: "Bugün 10 dakikalık bir hareket oyunu planlayın — denge kurma, zıplama, yuvarlanma. Program yok, sadece beden ve eğlence.",
      discussion_body: "Çocuğunuza en çok keyif veren hareket etkinliği hangisi — ve neden?",
      companion_quick: "Hareket bir boş zaman etkinliği değildir — öğrenme motorudur.",
      companion_reflect: "Çocuğunuz bugün bedensel olarak yeni ne denedi veya cesaret etti?",
    },
    milestone_uebergaenge: {
      title: 'Ergenliğe erken ve rahat bir şekilde hazırlanmak',
      parent_lens: "Ergenlik çoğu ebeveynin düşündüğünden daha erken başlar — ve zemin çocuklukta hazırlanır. Açık iletişim ve güvenli bir ebeveyn-çocuk ilişkisi en iyi hazırlıktır.",
      parent_tips: [
        "Beden değişiklikleri hakkında erken konuşun — dramasız, olgun bir şekilde. Bilgilendirilmiş çocuklar daha az korku yaşar.",
        "Kendi ergenlik anılarınızı (uygun şekilde) paylaşın: 'Ben de o zamanlar ... konusunda emin değildim' — bu normalleştirir.",
        "Mahremiyet için alan yaratın: kapıyı çalın, günlükleri saygıyla karşılayın. Güven saygıyla oluşur.",
      ],
      practical_tip: "Bugün çocuğunuzla birlikte (yaşına uygun) beden süreçleri hakkında bir video veya kitaba bakın — çekinmeden.",
      discussion_body: "Geriye dönüp baktığınızda ergenlikte sizin için ne önemliydi — ve ebeveynlerinizin ne yapmasını isterdiniz?",
      companion_quick: "En iyi ergenlik hazırlığı bugünkü güçlü bir ilişkidir.",
      companion_reflect: "Çocuğunuz bugün kendisi hakkında düşünmeye başladığını gösteren bir soru sordu mu?",
    },
    gfk_wiedergutmachung: {
      title: 'Ebeveynler patladığında — telafi bir güçtür',
      parent_lens: "Hiçbir ebeveyn her zaman sabırlı değildir. Patladığınızda bu bir ebeveyn olarak başarısızlık değildir — insani bir andır. Ama sonrasında gelenler, patlamanın kendisinden daha güçlü bir şekilde ilişkiyi şekillendirir.",
      parent_tips: [
        "Telafi üç adım gerektirir: sorumluluk almak ('Yanıldım'), şefkat göstermek ve gerekirse farklı yapmak.",
        "'Ama' olmadan özür dileyin: 'Bu kadar yüksek sesle konuştuğum için üzgünüm. Bu doğru değildi.' — bu kadar.",
        "Çocuğunuz sizi insan olarak görür — bu iyidir. Çocuklar onarımla ilişkilerin fırtınalara dayandığını öğrenir.",
      ],
      practical_tip: "Bugün bir durumda güzel davranmadıysanız: tekrar çocuğunuza gidin ve söyleyin. Üç cümle yeterlidir.",
      discussion_body: "Ebeveyn olarak kendi patlamalarınızla nasıl başa çıkmayı öğrendiniz — kendinizi çok sert yargılamadan?",
      companion_quick: "Telafi çocuklara hiçbir rehberin öğretemeyeceği bir şeyi öğretir: ilişkilerin onarılabilir olduğunu.",
      companion_reflect: "Bugün geriye dönüp baktığınızda farklı yapacağınız bir an oldu mu — ve bundan ne çıkardınız?",
    },
  },
  ku: {
    gfk_warum: {
      title: 'Bi arambûnê li pirsên "çima" bersiv bide',
      parent_lens: "Zarokê te rojê sed carî ji te dipirse 'Çima?'. Ev ne ji bo aciz kirina te ye, lê ji ber ku mejiyê wî girêdanan çêdike. Ew dixwaze cîhanê fêm bike.",
      parent_tips: [
        "Zimanê zirav (NVC) bikar bîne: li şûna dexlê, hest û hewcedariyên xwe bi zelalî bibêje.",
        "Pirsên 'çima' bi kurtasî û hêsanî bersiv bide — zarokê te li mantiqê digere, ne li axaftinên zanistî.",
        "Sînoran bi evîndarî bi amadebûna xwe ya kesane deyne ('Ez naxwazim tu lêxî'), ne bi ceza.",
      ],
      practical_tip: "Di pirsa 'çima' ya bê de: pêşî hestê nîşan bide ('Tu meraqdar î!'), paşê bi hevokekê bersiv bide.",
      discussion_body: "Kîjan hevoka kurt û aram ji te re dibe alîkar dema zarokê te careke dehan dipirse çima?",
      companion_quick: "Îro tenê bi bersivek aram li pirsa çima bide û paşê bi zanebûn kurt bimîne.",
      companion_reflect: "Îro zarokê te kengî li girêdanan gerand — û tu çawa karî bi aramî rê nîşan bidî?",
    },
    gfk_grenzen: {
      title: 'Sînoran bi evîndarî û zelaliyê deynin',
      parent_lens: "Sînorên evîndar ne dijberî ye. Zarok hewceyî her duyan e: hesta ku têne hezkirin Û zelaliya li ser tiştê ku nabe. Sînorên bêyî girêdanê wek dîwaran hîs dibin — sînorên bi girêdanê wek rêberan hîs dibin.",
      parent_tips: [
        "Pêşî hesta zarokê xwe bi nav bike, paşê sînorê: 'Ez dibînim tu hêrs î. Lê dîsa jî: lêdan nabe.'",
        "Bi laşî aram bimîne — dengê te ji peyvên te bilindtir e. Berî bersivdanê nefeseke kûr bikişîne.",
        "Encaman ragihîne û pêwendî bike. Tehdîd meke, ragihîne: 'Eger tu ... bikî, wê demê ...'",
      ],
      practical_tip: "Îro hevokeke hest + sînor biceribîne: 'Ez fêm dikim tu dixwazî. Lê: na.' — û di dema wê de aram bimîne.",
      discussion_body: "Dema tu digihîjî sînorên xwe tu çawa bersiv didî? Kîjan hevok ji te re dibe alîkar ku aram bimînî?",
      companion_quick: "Berî bersiva sînor a bê nefeseke kûr bikişîne — ev nîvê karî ye.",
      companion_reflect: "Îro rewşek hebû ku sînorek aram çêtir ji hayreke bilind kar kir?",
    },
    gfk_ichbotschaft: {
      title: 'Peyamên "ez" li şûna sûcdarkirinên "tu"',
      parent_lens: "Peyamên 'tu' ('Tu pir dengbilind î!') berevaniyê derdixin. Peyamên 'ez' ('Ez westiyayî me û hewceyî bêdengiyê me') deriyan vedikin. Zarok bêtir guhdarî dikin dema hîs nakin ku têne êrîşkirin.",
      parent_tips: [
        "Sûcdarkirinan bike peyamên 'ez': li şûna 'Tu qet guhdarî nakî' → 'Ez hîs nakim ku têm bihîstin û ev min xemgîn dike.'",
        "Hewcedariya xwe parve bike: 'Niha hewceyî bêdengiyeke kurt me da ku bifikirim.' Zarok hewcedariyan bi awayekî ecêb baş fêm dikin.",
        "Di jiyana rojane de biceribîne: sê hevokên klasîk wek peyamên 'ez' ji nû ve formule bike — sibe dema diranan dişo, nîvro dema xwarinê, êvarê berî xewê.",
      ],
      practical_tip: "Îro rewşeke ku tu bi gelemperî 'Tu her tim...' dibêjî hilbijêre — û wê bi 'Ez ... hîs dikim ji ber ku hewceyî ... me' biguherîne.",
      discussion_body: "Kîjan peyama 'tu' ji te re herî zor e ku were ji nû ve formulekirin? Çi ji te re dibe alîkar?",
      companion_quick: "Hest + hewcedariyê bi nav bike — formula peyameke 'ez' a rastîn ev e.",
      companion_reflect: "Îro peyameke 'ez' bersivek ku te ecêbmayî hişt derxist holê?",
    },
    gfk_trotz: {
      title: 'Bi aramî li qonaxên serhişkiyê bibe hevrê',
      parent_lens: "Serhişkî ne serhildan e — pêşveçûn e. Dema zarokek li erdê dirêj dibe û diqîre, korteksa wî ya pêşîn hê ne bi têra xwe pêşketî ye da ku hestê birêve bibe. Wî hewceyî te ye wek hev-birêveberekî.",
      parent_tips: [
        "Bêyî zorkirinê nêzîk bimîne: bikeve asta çokan, bi aramî biaxive, eger zarok red bike destlêdanê meke.",
        "Di nîvê bahozê de nîqaşan meke. Axaftin tenê dema aram bibe tê.",
        "'Pirên hestan' bikar bîne: 'Te dixwest bestenî. Ev ji te re girîng bû. Ez fêm dikim.'",
      ],
      practical_tip: "Dema zarokê te ji xwe derdikeve: li kêleka wî rûne. Neçe, destwerdanê meke — tenê li wir be. Ev bi xwe jî alîkar dibe.",
      discussion_body: "Dema zarokê te di nîvê teqîneke hestî de ye, çi ji te re alîkar dibe ku aram bimînî?",
      companion_quick: "Sê peyv ji bo qonaxên serhişkiyê: nêzîk bimîne. Bi aramî nefes bike. Bisekine.",
      companion_reflect: "Îro çi ji te re herî zêde enerjî xwar — û çi ji te re alîkar bû ku di vê de aram bimînî?",
    },
    gfk_geschwister: {
      title: 'Pevçûna xwişk û birayan wek qada fêrbûnê bikar bîne',
      parent_lens: "Xwişk û bira pevdiçin — ev normal e û tewra girîng e. Di pevçûnê de zarok lihevhatinê, guherîna dîtinê û parastina xwe fêr dibin. Rola te ne dadger e, mîyaser e.",
      parent_tips: [
        "Alî negire: 'Ez dibînim herduyên we niha hêrs in. Ez ê pêşî te, paşê te bibihîzim.'",
        "Bihêle zarok bi xwe çareseriyan bibînin dema rewş nagihîje asteke xeternak. Tenê di talûkeyê rastîn de destwerdanê bike.",
        "Her zarokî bi tenê xurt bike: kêliyên 1:1 yên rêkûpêk bêyî xwişk û bira, çavnebariyê bi demdirêjî kêm dike.",
      ],
      practical_tip: "Di pevçûna bê de: ji herdu zarokan bipirse 'Niha çi hewce dikî?' — berî ku biryar bidî kî rast e.",
      discussion_body: "Dema xwişk û bira pevdiçin hûn çawa lê dinêrin? Li ba we çi herî baş kar dike?",
      companion_quick: "Mîyaser li şûna dadger — ev role te ye di pevçûnên xwişk û bira de.",
      companion_reflect: "Îro kêliyek hebû ku zarokên te bi xwe pevçûnek çareser kirin? We ji vê çi fêr bû?",
    },
    gfk_gefühle: {
      title: 'Hestan bi nav bike û qebûl bike',
      parent_lens: "Zarokên ku dikarin hestên xwe bi nav bikin xwedan berjewendiyeke mezin in: dikarin ragihînin ka çi hewce dikin. Ev gav — ji hestkirinê ber bi axaftinê ve — pratî û piştgiriya te hewce dike.",
      parent_tips: [
        "'Barometreya hestan' bikar bîne: êvarê bipirse 'Roja te di navbera 1-5 de çawa bû?' — û pêşî tu bi xwe bibêje.",
        "Hestên xwe bi dengekî bilind bi nav bike: 'Ez niha hinekî tengezar im ji ber ku divê ez pir bifikirim.' Fêrbûna bi mînak kar dike.",
        "Pirtûkên zarokan ên li ser hestan bixwîne — û paşê bisekine: 'Tu difikirî karakter çi hîs kir? Û tu?'",
      ],
      practical_tip: "Vê êvarê bipirse: 'Çi te îro şa kir? Çi te xemgîn an hêrs kir?' — û tenê guhdarî bike.",
      discussion_body: "Kîjan hest ji zarokê te re herî zor e ku bide nasîn? Hûn çawa lê nêzîk dibin?",
      companion_quick: "Pêşî hîs bike, paşê bi nav bike — alfabeya hestan bi te re wek mînak dest pê dike.",
      companion_reflect: "Kîjan kêliya hestî ya zarokê te ya îro te xwest bihêle bimîne?",
    },
    gfk_nein: {
      title: 'Bêyî sûcdarbûnê "na" bêje',
      parent_lens: "Dêûbavên ku qet na nabêjin, zarokên ku sînoran nas nakin mezin dikin. 'Na' ya bi evîndarî ji zarokê te re nîşan dide: ez hewcedariyên xwe bi ciddî digirim — û tu jî dikarî.",
      parent_tips: [
        "'Na' hewceyî ravekirineke dirêj nake. 'Na, niha nabe' ya zelal bes e.",
        "Sûcdarbûn piştî 'na' nîşan e, ne çewtî. Ji xwe bipirse: ma ev 'na' bi rastî çewt e — an tenê ne rihet e?",
        "Li hember mezinên din jî 'na' bêje (peymanên lîstinê, soz) — zarokê te ji mînaka te fêr dibe.",
      ],
      practical_tip: "Îro carekê bi zanebûn na bêje — bêyî lêborînê. Bihîs bike ka ev çawa hîs dike.",
      discussion_body: "Na gotin ji te re kengî herî zor e — ji zarokên xwe re, an ji yên din re?",
      companion_quick: "Na li tiştekî erê ye li tiştekî girîngtir — bi gelemperî li te bi xwe.",
      companion_reflect: "Îro na hebû ku dema tu li paş dinêrî xwe rast hîs kir?",
    },
    inclusion_stärken: {
      title: 'Li şûna nirxandina qelsiyan hêzan bibîne',
      parent_lens: "Her zarokî xwedan komela hêzên xwe yên taybet e. Em wek dêûbav bi gelemperî pêşî deverên pirsgirêkê dibînin — lê em ê yên pêşîn bin ku dikarin elmasê xam biparjînin.",
      parent_tips: [
        "Vê êvarê 3 hêzên zarokê xwe binivîse — ne serkeftin, taybetmendiyên karakter ('meraqdar', 'lênêrîner', 'sernebir').",
        "Hêzan bi awayekî konkret û bi dem bi nav bike: 'Tu niha pir sebirdar bûyî — ev bi rastî xweş e.'",
        "Ji berhevdana bi xwişk û bira an zarokên din dûr bikeve. Her kêşeya pêşveçûnê taybet e.",
      ],
      practical_tip: "Îro bi zarokê xwe re li ser yek ji hêzên wî biaxive — ne wek pesn, wek dîtinek: 'Îro min dît ka tu çawa ...'",
      discussion_body: "Kîjan hêza veşartî ya zarokê te dixwazî îro parve bikî?",
      companion_quick: "Dîtina hêzan tê wateya ku qelsî neyê paşguhkirin — tê wateya pêşxistina mezinbûnê.",
      companion_reflect: "Kîjan hêza zarokê te îro te ecêbmayî hişt an bi bandor kir?",
    },
    inclusion_selbstwert: {
      title: 'Rojane nirxê xwe ava bike',
      parent_lens: "Nirxê xwe tenê bi pesn çênabe — bi ezmûnê çêdibe: 'Ez dikarim tiştekî bikim. Ez girîng im. Ez aliyê vir im.' Tu dikarî her sê ezmûnan rojane çêbikî.",
      parent_tips: [
        "Bihêle zarokê te biryarên biçûk bigire: 'Tu dixwazî pêşî erkan bikî an pêşî bilîzî?' Serbixwebûn = nirxê xwe.",
        "Eleqeya rastîn nîşan bide: têlefonê deyne, li rûyê wî binêre, bipirse. 10 deqîqe balê tam mucîzeyan çêdike.",
        "Pêvajoyê pîroz bike, ne tenê encamê: 'Te ev qas dirêj biceribî — ev beşa girîng e.'",
      ],
      practical_tip: "Îro: 10 deqîqe ji zarokê xwe re balekî tam bide — bêyî têlefon, bêyî tiştên din, tenê eleqe.",
      discussion_body: "Çi zarokê te bi taybetî bi xwe serbilind dike — û hûn vê hestê çawa piştgirî dikin?",
      companion_quick: "Nirxê xwe ne ji neynikê tê, ji çavên kesên ku me hez dikin tê.",
      companion_reflect: "Zarokê te îro di kîjan kêliyê de 'Ez dikarim vê bikim!' nîşan da?",
    },
    inclusion_scheitern: {
      title: 'Têkçûnê wek derfeta fêrbûnê bibîne',
      parent_lens: "Mejî bi qehremanî ji çewtiyan fêr dibe — ne ji serkeftinan. Dema zarokê te têk diçe û tu aram dimînî, tu jê re sînyala herî xurt dişînî: 'Têkçûn ewle ye. Ez pê re serî derdixim.'",
      parent_tips: [
        "Di têkçûnê de pêşî dilovanî, paşê çareserî: 'Ev acizker bû. Em ê carekê din çi bikin cûda?'",
        "Ji têkçûnên xwe yên taybet bibêje: 'Min jî carekê ... û paşê min ... fêr bû.' Fêrbûna bi mînak tabûyê radike.",
        "Ji 'Min ji te re got' dûr bikeve. Ev deriyan digire. Li şûna wê: 'Te ji vê çi girt?'",
      ],
      practical_tip: "Îro ji zarokê xwe re ji têkçûneke xwe ya taybet bibêje — û tiştê ku te jê fêr bû.",
      discussion_body: "Hûn wek malbat çawa li dijî têkçûnan tevdigerin? Çi ji we re alîkar dibe ku têkçûnê wek beşek ji fêrbûnê bibînin?",
      companion_quick: "Zarokên ku destûr têne dan çewtiyan bikin, mezinên wêrektir dibin.",
      companion_reflect: "Îro têkçûnek hebû ku zarokê te baş jê derket? Çi ji vê re alîkar bû?",
    },
    inclusion_hochsensibel: {
      title: 'Zarokên pir hestiyar fêm bike û piştgirî bike',
      parent_lens: "Nêzîkî %20ê zarokan pir hestiyar in — ew bêtir têbînî dikin, bi awayekî tund hîs dikin û hewceyî demeke vegerê ya zêdetir in. Ev ne qelsî ye, taybetmendiyeke kesayetî ye ku xwedî hêzên xwe yên taybet e.",
      parent_tips: [
        "Zêdebariya hestan kêm bike: berî rewşên fişarê yên bilind (kirîn, dibistan, cejn) demên veguhastinê yên aram plansaz bike.",
        "Pêşbînî diparêze: pêşiyê ragihîne çi tê ('10 deqîqe din em diçin'). Surprîz ji bo zarokên pir hestiyar giran in.",
        "Hestiyariya wan hêz e: dema kesek xemgîn e têdigihin û kûr difikirin. Vê bi awayekî erênî bi nav bike.",
      ],
      practical_tip: "Îro piştî rewşeke fişarê ya bilind ji zarokê xwe re 15 deqîqeyên 'dema şarjê' ya bêdeng plansaz bike — bêyî ekran, bêyî hêvî.",
      discussion_body: "Hûn taybetmendiyên pir hestiyar di zarokê xwe de nas dikin? Çi ji we re di jiyana rojane de alîkar dibe?",
      companion_quick: "Zarokên pir hestiyar ne hewceyî hişkbûnê, hewceyî cihên parastî û fêmkirinê ne.",
      companion_reflect: "Zarokê te îro kengî herî zêde bandor pêvajo kir — û paşê çawa xwe vegerand?",
    },
    inclusion_freundschaft: {
      title: 'Hevaltiyan bibe hevrê — neke birêve',
      parent_lens: "Hevaltî cîhê herî girîng ê fêrbûna jêhatîbûnên civakî ne. Zarok dan û standinê, danûstandinê û dev jê berdanê fêr dibin — lê tenê eger em wek dêûbav berdin û bibin hevrê li şûna ku birêve bibin.",
      parent_tips: [
        "Bipirse, lê dadgeriyê meke: 'Îro tevî ... çawa bû?' ji 'Ez jê hez nakim, wî berî nuha ... kir' çêtir e.",
        "Bihêle zarok pêşî bi xwe pevçûnan çareser bikin — tenê dema tengasiyeke rastîn çêdibe destwerdanê bike.",
        "Hevaltiyan bi çalakî mumkun bike: peymanên lîstinê, vexwendinan. Derfetên civakî bi xwe çênabin.",
      ],
      practical_tip: "Îro ji zarokê xwe bipirse: 'Kî ji polê / komê te ji tiştên ku tu jê hez dikî hez dike?' — û bi hev re bifikire ka hûn çawa dem çêdikin.",
      discussion_body: "Hûn ji zarokên xwe re cihê hevaltiyên wan ên taybet çawa didin — her çend hûn hilbijartina wan her tim fêm nekin jî?",
      companion_quick: "Hevaltiya rastîn bi zorê nayê çêkirin — lê hûn dikarin bi hev re axek berhemdar amade bikin.",
      companion_reflect: "Zarokê te îro li ser kesekî ku ji te re girîng e axivî? We ji vê çi fêr bû?",
    },
    inclusion_resilienz: {
      title: 'Berxwedan — zarok çawa bi zehmetiyan mezin dibin',
      parent_lens: "Berxwedan ne ji dayîkbûnê tê — bi pratîkê tê. Zarok dema zehmetiyan dijîn Û di vê de têne piştgirîkirin bi hêz dibin. Ne parastin, hevaltî mifta wê ye.",
      parent_tips: [
        "Bihêle zarokê te zehmetiyan biqedîne: zû alîkarî meke. Tenê dema ku bi rastî nikare pêşve here alîkariyê pêşkêş bike.",
        "Diyaloga hundirîn xurt bike: 'Tu difikirî tu çi dikarî bikî?' li şûna dayîna çareseriyê rasterast.",
        "Li ser krîzên malbatê li gorî temenê biaxive: zarokên ku têne derxistin xeyalên ji rastiyê xerabtir pêş dixin.",
      ],
      practical_tip: "Eger zarokê te îro têk biçe: berî destwerdanê 30 çirkeyan bisekine. Bi gelemperî çareserî bi xwe tê.",
      discussion_body: "Kîjan zehmetiya zarokê we serkeftî bi cih anî ku hûn ecêbmayî ma?",
      companion_quick: "Berxwedan di navbera zehmetî û piştgiriyê de mezin dibe — ne berî wê, ne jî piştî wê.",
      companion_reflect: "Hûn çawa dizanin ku zarokê we îro ji hundir ve mezin bûye?",
    },
    inclusion_vielfalt: {
      title: 'Cûrbicûrbûnê bijî — cudahî wek hêz',
      parent_lens: "Zarokên ku zû fêr dibin ku mirov cuda ne — di eslê xwe, jêhatîbûn û awayê fikirînê de — empatiyeke zêdetir û tirseke kêmtir a têkiliyê pêş dixin. Tu dikarî cûrbicûrbûnê di jiyana rojane de zindî bikî.",
      parent_tips: [
        "Bi eşkerayî li ser cudahiyan biaxive — zarok wan çawa be jî têbînî dikin. 'Erê, rengê çermê Lara ji ya te cuda ye — û malbata wê ji ... tê.'",
        "Pirtûk, fîlm û listikên bi karakterên cûrbicûr hilbijêre — nûnertî cîhanbîniyê bandor dike.",
        "Taybetmendiyên malbatê pîroz bike: 'Li ba me weha ye, li ba malbatên din cuda ye — xweşiya wê ev e.'",
      ],
      practical_tip: "Îro pirtûkeke zarokan bixwîne ku lehengê wê sereke ji zarokê te cuda ye — û paşê li ser wê biaxive.",
      discussion_body: "Hûn cudahiyên di navbera mirovan de ji zarokan re çawa şirove dikin, bi awayekî ku meraq li şûna tirsê pêş dixin?",
      companion_quick: "Zarok bi xwezayî li cudahiyan meraqdar in — pêşdaraziyê tenê paşê fêr dibin.",
      companion_reflect: "Zarokê te îro pirseke li ser cudahiyan kir ku te xist fikirînê?",
    },
    leadership_struktur: {
      title: 'Sazûmana rojane wek gîhayê ewlehiyê',
      parent_lens: "Mejiyê zarokî ji pêşbîniyê hez dike. Rîtûel û sazûman ne sînordarî ne — ew perçîna ku azadiyê dide zarokan da ku bi ewlehî pêşve biçin, ne.",
      parent_tips: [
        "Gîhayên sabît di rojê de: rîtûela şiyarbûnê, xwarin, dema xewê. Ev sê ji bo îstîqrareke rastîn bes in.",
        "Rîtûelên veguhastinê plansaz bike: di navbera çalakiyan de veguhastinên kurt ragihîne. 'Di 5 deqîqeyan de em kom dikin.'",
        "Sazûman ne stres e — eger hewce be gav bi gav biguherîne, ne bi carekê.",
      ],
      practical_tip: "Îro bi zarokê xwe re li plana rojê binêre — li ser tiştê ku tê biaxivin. Ev berxwedan û ne diyariyê kêm dike.",
      discussion_body: "Kîjan rîtûela rojane ji we re wek malbat bi taybetî girîng e — û çima?",
      companion_quick: "Pêşbînî ewlehiyê çêdike. Ewlehî amadebûna fêrbûnê çêdike.",
      companion_reflect: "Kîjan kêliya îro nîşan da ku zarokê te hewceyî sazûmanê bû — an jê hez kir?",
    },
    leadership_schlaf: {
      title: 'Rîtûelên xewê — ji bo laş û hiş aramî çêbike',
      parent_lens: "Xew ne rawestan e, dema pêşveçûnê ye. Di xewê de mejî rojê pêvajo dike, bîranînan xurt dike û ji nû ve çê dibe. Rîtûeleke xewê ya baş yek ji veberhênanên herî bi bandor e ji bo zarokê te.",
      parent_tips: [
        "30 deqîqe berî xewê: ne ekran, ne listikên heyecanewer. Aramkirin dem digire.",
        "Her tim heman rêz: diran, cilê xewê, çîrok, ronahî vemirandin. Rîtûel ji mejî re sînyalê dişînin: 'Niha dema xewê ye.'",
        "Eger zarokê te nikare rakeve: bi hev re nefes bikişînin. 4 çirke bikişîne, 6 çirke berde — ev pergala nervî ya parasempatîk çalak dike.",
      ],
      practical_tip: "Vê êvarê berî xewê rîtûeleke nefesê ya 3-deqîqeyî bide destpêkirin — bikişîne, berde, bi hev re.",
      discussion_body: "Rîtûela we ya herî hezkirî ya xewê çi ye — û we çawa pêş xist?",
      companion_quick: "Rîtûeleke dawîn a aram destpêka herî baş a xeweke baş e.",
      companion_reflect: "Çûyina xewê îro çawa bû — çi alîkar bû, çi asteng bû?",
    },
    leadership_bildschirm: {
      title: 'Dema ekranê bi hişmendî çêbike',
      parent_lens: "Ne dema ekranê bixwe pirsgirêk e — vexwarina bêkontrol û pasîf a bêyî sohbet piştî wê pirsgirêk e. Bi şertên hêsan ekran dibe çalakiyeke betlaneyê ya tendurist.",
      parent_tips: [
        "Li şûna qedexeyên spontane demên sabît: 'Piştî erkên malê heta saet 17' ji 'ne pir zêde' zelaltir e.",
        "Bi hev re temaşe bike û paşê biaxive: 'Çi ji te re xweş bû? Çi xerîb an ecêb bû?' jêhatîbûna medyayê xurt dike.",
        "Cihên bê ekran çêke: jûreya xewê û maseya xwarinê sînorên baş ên destpêkê ne.",
      ],
      practical_tip: "Îro 15 deqîqe bi hev re li tiştekî binêre — û paşê 2 pirsan li ser bike. Ev awayê ku zarokê te medyayê têdigihe diguherîne.",
      discussion_body: "Hûn dema ekranê li ba xwe çawa birêve dibin — çi bi kar hat, çi ne pir?",
      companion_quick: "Bikaranîna medyayê ya hişmend ne bi qedexeyê, bi sohbetê tê fêrbûn.",
      companion_reflect: "Zarokê te îro medya çawa bikar anî — çalak an pasîf? We çi têbînî kir?",
    },
    leadership_autoritaet: {
      title: 'Otorîte bi girêdanê — ne bi tirsê',
      parent_lens: "Otorîter ne wateya bi deng û hişk bûnê ye. Otorîteya rastîn a dêûbaviyê dema çêdibe ku zarokek dizane: 'Tu min hez dikî Û tu zelal î.' Girêdan û rêberî hev nagirin — hev pêwîst dikin.",
      parent_tips: [
        "Ragihandinên zelal bêyî nîqaşê: 'Em niha wisa dikin.' Piştre danûstandin tune — tenê fêmkirinê pêşkêş bike.",
        "Lêborîn mezinan xurttir dike, ne qelstir. 'Berê ev ji min re ne adil bû' — zarok vê rêz digirin.",
        "Hin qaîdeyan bi hev re çêke — ev amadebûna pabendbûnê zêde dike.",
      ],
      practical_tip: "Îro qaîdeyekê li şûna qedexeyekê wek erkeke erênî formule bike: 'Piştî lîstinê em kom dikin' li şûna 'Bernehêle.'",
      discussion_body: "Hûn di navbera rêberî û gotina zarokên xwe de hevsengiyê çawa dibînin?",
      companion_quick: "Otorîte bêyî girêdanê kontrol e. Girêdan bêyî otorîteyê kaos e. Herduyan bi hev re rêberî ye.",
      companion_reflect: "Îro kêliyek hebû ku zelaliya te ya aram ji peyveke bihêz bêtir kar kir?",
    },
    leadership_hausaufgaben: {
      title: 'Erkên malê bêyî stresê — çarçoveyeke ku kar dike',
      parent_lens: "Stresa erkên malê bi gelemperî ne pirsgirêkeke fêrbûnê ye — pirsgirêkeke rîtûelê ye. Bi sazûmana rast û dema rast mijar bixwe aram dibe.",
      parent_tips: [
        "Dema rast bibîne: rasterast piştî dibistanê an piştî demeke kurt a vegerê — lê berî êvarê.",
        "Ez li vir im, lê tavilê alîkarî nakim: pêşî bihêle bi xwe biceribîne. Piştî 10 deqîqeyan bêyî pêşveçûn: bipirse 'Li ku dişikilî?'",
        "Cihê xebatê amade bike: cihek sabît, maseyeke rêkûpêk, têlefon ne di dîmenê de — ev bala belavkirinê kêm dike.",
      ],
      practical_tip: "Îro bi zarokê xwe re DEMA erkên malê ya hefteyê diyar bike — û binivîse.",
      discussion_body: "Çi li ba we erkên malê kêmtir bi stres kir? Kîjan rêzik kar dikin?",
      companion_quick: "Sazûman di fêrbûnê de sînordarî nine — motora baldariyê ye.",
      companion_reflect: "Fêrbûn îro çawa çû? Sibê hûn dikarin çi cuda biceribînin?",
    },
    leadership_selbstaendigkeit: {
      title: 'Serbixwebûn — berdan jî evîn e',
      parent_lens: "Zarok dema em ji wan bawer dikin serbixwe dibin. Lê berdan xeternak dixuye — û ev normal e. Huner ev e: gav bi gav berpirsyariya zêdetir bide.",
      parent_tips: [
        "Erkên li gorî temenê bide: yên 3 salî listikan kom dikin, yên 6 salî masê amade dikin, yên 10 salî di xwarinpêjiyê de alîkarî dikin.",
        "Dema hêdî diçe destwerdanê meke. Hêdî û bi serê xwe ji bilez û bi alîkariyê hêjatir e.",
        "Çewtiyan di erkên serbixwe de qebûl bike: kasa şîr dibe — ev têkçûn nine, pratî ye.",
      ],
      practical_tip: "Îro erkekî nû ku heta niha te bi xwe dikir bide zarokê xwe — û bihêle bi tevahî bi xwe bike.",
      discussion_body: "Serkeftina serbixwebûnê ya herî mezin a zarokê we ku herduyên we serbilind in çi ye?",
      companion_quick: "Her erkê ku zarok bi xwe biqedîne, veberhênaneke li ser xwebaweriya wî ya paşerojê ye.",
      companion_reflect: "Îro hûn kengî berdan — û ev ji we re çawa hîs kir?",
    },
    leadership_natur: {
      title: 'Xwezayê û tevger wek rîtûelek malbatê',
      parent_lens: "Zarokên ku bi rêkûpêk li derve ne çêtir radizên, baldartir in û ji aliyê hestî ve aramtir in. Xweza ne çalakiyeke betlaneyê ye — hewcedariyeke bingehîn e.",
      parent_tips: [
        "15 deqîqe rojane li derve xwedan bandoreke pîvanbar e jî — ne hewceyî gerê, tewra rêya dibistanê jî tê hesibandin.",
        "Bi hev re tevbigere: bisîklet, meşî, zeviya lîstinê. Tevgera bi hev re girêdanê xurt dike.",
        "Bihêle zarokê te xwezayê keşif bike: kevir, kêzik, gol. Bêyî program — tenê vebûn.",
      ],
      practical_tip: "Îro gerek 15-deqîqeyî li derve plansaz bike — bêyî armanc, bêyî program, tenê bi hev re.",
      discussion_body: "Kîjan ezmûna xwezayê ya zaroktiya we dixwazin bidin zarokên xwe?",
      companion_quick: "Li derve bûn xwarinê mejî ye — ji bo zarok û mezinan.",
      companion_reflect: "Dema we ya li derve îro rewşê çawa guherand?",
    },
    milestone_sprache: {
      title: 'Pêşveçûna zimanî — çawa bi lîstikê piştgirî bike',
      parent_lens: "Pêşveçûna zimanî ne bi perwerdehiya peyvan çêdibe — bi diyalogê çêdibe. Zarok fêrî axaftinê dibin dema mezin pê re diaxivin, guhdariya wan dikin û bersivê didin gotinên wan.",
      parent_tips: [
        "Jiyana xwe ya rojane bi dengekî bilind rave bike: 'Niha ez gizeran dibirim' — ev ferhenga pasîf dewlemend dike.",
        "Gotinên zarokê xwe hilgire û berfirehtir bike: 'Top!' — 'Erê, topa sor digerin.'",
        "Rojane bi dengekî bilind bixwîne, her çend zarok bi xwe bikare bixwîne jî. Nivîsarên pirtûkan ji zimanê rojane cuda ne.",
      ],
      practical_tip: "Îro 10 deqîqe bi dengekî bilind bixwîne — û dema xwendinê bipirse: 'Tu difikirî paşê çi diqewime?'",
      discussion_body: "Kîjan peyv an hevokên zarokê we ya dawî we bi taybetî ecêbmayî hiştin an bandor kirin?",
      companion_quick: "Ziman di sohbetê de mezin dibe — ne di bêdengiyê de.",
      companion_reflect: "Kîjan pêşveçûna zimanî ya zarokê te te îro têbînî kir?",
    },
    milestone_schule: {
      title: 'Destpêka dibistanê û veguhastinan bi aramî bibe hevrê',
      parent_lens: "Veguhastin — destpêka dibistanê, guherîna polê, baxçeyê zarokan a nû — ji bo zarokan qonaxên fêrbûnê yên herî tund in. Arambûn û pêbaweriya te li zarokê te derbas dibe. Tu bingeha sazûmanê yî.",
      parent_tips: [
        "Cihên nû berî demê nas bike: eger gengaz be, polê an dibistana nû berî roja pêşîn ser xwe bide.",
        "Li ser hestan biaxive: 'Heyecanbûn xweş e. Ez jî di roja pêşîn a dibistanê de bêhncîkî bûm.'",
        "Tiştên biçûk ên veguhastinê alîkar dibin: wêneyek di çenteyê de, tiştek biçûk a bîranînê — tişt ewlehiyê çêdikin.",
      ],
      practical_tip: "Îro ji zarokê xwe bipirse: 'Tu ji ... çi hêvî dikî? Çi hîn jî te xemgîn dike?' — û bêyî nirxandinê guhdarî bike.",
      discussion_body: "Hûn veguhastineke girîng a zarokê xwe çawa bi hevrêtî pêşve birin? Çi alîkar bû?",
      companion_quick: "Veguhastin bi hev re dawî û destpêk in — û her duyan dikarin werin hîskirin.",
      companion_reflect: "Zarokê te îro li dora veguhastinekê kîjan hest nîşan da?",
    },
    milestone_sozial: {
      title: 'Aqilê civakî — jêhatîbûna herî girîng a sedsala 21an',
      parent_lens: "IQ deriyan vedike. EQ (aqilê hestî) mirovan dihêle têkevin. Zarokên ku xwedan jêhatîbûneke civakî ya bilind in çêtir dikarin hevkariyê bikin, ragihînin û xwe li şûna yên din deynin — ev ji te fêr dibin.",
      parent_tips: [
        "Rojane empatiyê wek mînak nîşan bide: 'Pisîk xemgîn xuya dike. Tu difikirî çima?'",
        "Guherîna dîtinê biceribîne: 'Dema te ev got, tu difikirî ... çawa hîs kir?'",
        "Tevgera civakî bi eşkereyî pesend bike: 'Te sekinî heta wî peyivîna xwe qedand. Ev pir bi rêz bû.'",
      ],
      practical_tip: "Îro piştî baxçeyê zarokan an dibistanê li ser rewşeke civakî biaxive: 'Kesekî îro tiştek xweş kir?'",
      discussion_body: "Kîjan alîyê jêhatîbûna civakî ji bo zarok û mezinan îro herî girîng dibînin?",
      companion_quick: "Jêhatîbûna civakî ne bûyereke xwezayî ye — jêhatîbûneke ku bi pratîkê tê kirin e.",
      companion_reflect: "Zarokê te îro kengî empatî nîşan da — her çend bêyî têbînîkirinê be jî?",
    },
    milestone_emotion: {
      title: 'Mezinbûna hestî — dema hest têne pêvajokirin',
      parent_lens: "Mezinbûna hestî ne bi tunebûna hestan xwe nîşan dide — bi pêvajokirina wan. Zarokên ku destûr têne dan hestên xwe îfade bikin bi demdirêjî çêtir fêrî lihevkirina wan dibin.",
      parent_tips: [
        "Hemû hest destûr in — ne hemû tevger. 'Tu dikarî hêrs bî. Tu nikarî lêxî.'",
        "Hestan nepişaftîne: li şûna 'Ne ew qas xerab e' → 'Ez dibînim ev bi rastî bandor li te kir.'",
        "Bihêle hest di laş de werin hîskirin: 'Niha tu vê li ku hîs dikî? Di zikê xwe de? Di sînga xwe de?'",
      ],
      practical_tip: "Îro bipirse: 'Ev çawa di laşê te de hîs dike?' — û her bersivê qebûl bike.",
      discussion_body: "Kîjan hest li ba we wek malbat herî zor e ku bi eşkereyî were nîşandan?",
      companion_quick: "Destûrdana hestan ne qelsî ye — hêza hestî ye.",
      companion_reflect: "Zarokê te îro kîjan hest bi eşkereyî nîşan da — û we bi hev re çawa lê hevrê bûn?",
    },
    milestone_kreativitaet: {
      title: 'Afirandinê xurt bike — bêyî fokusa encamê',
      parent_lens: "Afirandin çareserkirina pirsgirêkan e bi kincek din. Dema zarok wêne dikişînin, ava dikin, hunerê dikin an dilîzin, elastîkî û orîjînaliyê perwerde dikin — jêhatîbûnên pêşerojê ev in.",
      parent_tips: [
        "Fokus li ser hilberê dawîn nebe: 'Ji min re bibêje çi çêkirî' li şûna 'Ev dê çi be?' çêtir e.",
        "Materyalên bêyî rêwerz pêşkêş bike: qumaş, karton, materyalên xwezayî — û paşê berde.",
        "Bi xwe afirîner be: dema dêûbav bêyî bêkêmasî wêne dikişînin, ava dikin, distrên, ew heman tiştî destûrê didin zarokên xwe.",
      ],
      practical_tip: "Îro 20 deqîqe hunerkirina azad pêşkêş bike — bêyî şablon, bêyî rêwerz, tenê materyal.",
      discussion_body: "Projeya herî afirîner a zarokê we ya ku wî/wê bi xwe pêş xistiye çi ye?",
      companion_quick: "Afirandinê cih, dem û mezinekî ku nirxandinê nake hewce dike.",
      companion_reflect: "Zarokê te îro çi îcad kir, ava kir an xeyal kir ku te ecêbmayî hişt?",
    },
    milestone_koerper: {
      title: 'Haydariya laş xurt bike — tevger wek motora pêşveçûnê',
      parent_lens: "Pêşveçûna motorîk û pêşveçûna zanebûnê bi hev ve girêdayî ne. Zarokên ku hildikişin, bîlansê digirin û distirin, herwiha fikirîna xwe ya cîhî û baldariya xwe pêş dixin.",
      parent_tips: [
        "Tevgerê rojane têxe: ne wek bernameya werzîşê, wek jiyana rojane — derence li şûna asansorê, meşîn li şûna hilgirtinê.",
        "Motorîka mezin û biçûk biguherîne: avakirin (biçûk) û hilkişîn (mezin) hev bi awayekî xweş temam dikin.",
        "Wêneya laş bi awayekî erênî xurt bike: 'Laşê te ev qas dikare bike' — ji dîtin an performansê serbixwe.",
      ],
      practical_tip: "Îro 10 deqîqe lîstika tevgerê plansaz bike — bîlanskirin, pengizîn, gindirîn. Bêyî program, tenê laş û kêf.",
      discussion_body: "Kîjan çalakiya tevgerê ji zarokê te herî kêf dide — û çima?",
      companion_quick: "Tevger ne çalakiyeke betlaneyê ye — motora fêrbûnê ye.",
      companion_reflect: "Zarokê te îro bi laşî çi biceribî an wêrek kir ku nû bû?",
    },
    milestone_uebergaenge: {
      title: 'Ji bo mezinbûna cinsî zû û bi aramî amade bibe',
      parent_lens: "Mezinbûna cinsî ji ya piraniya dêûbavan difikirin zûtir dest pê dike — û rêç di zaroktiyê de tê danîn. Ragihandina vekirî û têkiliyeke ewle ya dêûbav-zarok amadebûna herî baş e.",
      parent_tips: [
        "Zû li ser guherînên laş biaxive — bi rastî, bêyî dramayê. Zarokên ku têne agahdarkirin tirseke kêmtir hene.",
        "Bîranînên xwe yên mezinbûna cinsî parve bike (li gorî guncanî): 'Ez jî wê demê ne pêbawer bûm li ser ...' — ev normal dike.",
        "Cih ji bo taybetmendiyê çêbike: li derî bide, rojnivîskan rêz bike. Baweri bi rêzgirtinê çêdibe.",
      ],
      practical_tip: "Îro bi zarokê xwe re (li gorî temenê) vîdyoyek an pirtûkek li ser pêvajoyên laş temaşe bike — bêyî fedîkirinê.",
      discussion_body: "Dema hûn li paş dinêrin, di mezinbûna cinsî de çi ji we re girîng bû — û hûn dixwazin dêûbavên we çi bikirana?",
      companion_quick: "Amadebûna herî baş a mezinbûna cinsî têkiliyeke bihêz a îro ye.",
      companion_reflect: "Zarokê te îro pirsek kir ku nîşan dide dest bi fikirîna li ser xwe dike?",
    },
    gfk_wiedergutmachung: {
      title: 'Dema dêûbav diteqin — qenckirinê wek hêz',
      parent_lens: "Ti dêûbav her tim sebir nine. Dema tu diteqî, ev ne têkçûneke te ya wek dêûbav e — kêliyeke mirovahî ye. Lê tiştê ku piştre tê, têkiliyê ji teqînê bixwe bihêztir teşe dide.",
      parent_tips: [
        "Qenckirinê hewceyî sê gavan e: berpirsyariyê hilgire ('Min xelet kir'), dilovanî nîşan bide û eger hewce be cuda bike.",
        "Bêyî 'lê' lêborînê bike: 'Bibore ku ez ev qas bi deng bûm. Ev ne rast bû.' — temam.",
        "Zarokê te te wek mirov dibîne — ev baş e. Zarok bi qenckirinê fêr dibin ku têkilî li ber bahozan berxwe didin.",
      ],
      practical_tip: "Eger îro tu di rewşekê de bi xweşî tevnegerî: dîsa here ba zarokê xwe û bibêje. Sê hevok bes in.",
      discussion_body: "Hûn wek dêûbav fêrî çi bûn ka bi teqînên xwe yên taybet re çawa mijûl bibin — bêyî ku xwe pir hişk nirxînin?",
      companion_quick: "Qenckirin tiştekî ji zarokan re fêr dike ku ti rêbernameyek nikare: ku têkilî têne çêkirin.",
      companion_reflect: "Îro kêliyek hebû ku tu li paş dinêrî bixwestana cuda bikira — û te ji vê çi girt?",
    },
  },
    fr: {
      gfk_warum: {
        title: 'Accompagner les questions "pourquoi" avec sérénité',
        parent_lens: 'Ton enfant te pose la question "pourquoi ?" cent fois par jour. Il ne le fait pas pour t\'agacer, mais parce que son cerveau tisse des liens. Il cherche à comprendre le monde.',
        parent_tips: [
          'Utilise la communication non violente (CNV) : nomme clairement tes propres émotions et besoins au lieu de gronder.',
          'Réponds aux "pourquoi" de façon courte et simple : ton enfant cherche de la logique, pas un exposé scientifique.',
          'Pose des limites avec tendresse grâce à ta présence personnelle ("Je ne veux pas que tu frappes") plutôt que par des punitions.',
        ],
        practical_tip: 'À la prochaine question "pourquoi" : reflète d\'abord l\'émotion ("Tu es curieux !"), puis réponds en une seule phrase.',
        discussion_body: 'Quelle formulation courte et calme vous aide lorsque votre enfant demande "pourquoi" pour la dixième fois ?',
        companion_quick: 'Aujourd\'hui, choisis une seule réponse calme à une question "pourquoi" et reste ensuite volontairement bref.',
        companion_reflect: 'Quand ton enfant a-t-il cherché le plus de liens aujourd\'hui, et comment as-tu pu lui offrir une orientation en restant serein ?',
      },
      gfk_grenzen: {
        title: 'Poser des limites avec tendresse et clarté',
        parent_lens: 'Des limites bienveillantes ne sont pas une contradiction. Les enfants ont besoin des deux : se sentir aimés ET recevoir une orientation claire sur ce qui n\'est pas possible. Des limites sans lien ressemblent à des murs ; des limites avec lien ressemblent à des garde-fous.',
        parent_tips: [
          'Nomme d\'abord l\'émotion de ton enfant, puis la limite : "Je vois que tu es en colère. Et pourtant : frapper, ce n\'est pas possible."',
          'Garde ton corps calme : ton ton de voix parle plus fort que tes mots. Une profonde respiration avant de réagir aide beaucoup.',
          'Annonce les conséquences et tiens-les. Ne menace pas, annonce : "Si tu... alors..."',
        ],
        practical_tip: 'Entraîne-toi aujourd\'hui à une phrase avec émotion + limite : "Je comprends que tu le veuilles. Et : non." tout en restant calme.',
        discussion_body: 'Comment réagissez-vous lorsque vous atteignez vos propres limites ? Quelle phrase vous aide à rester calme ?',
        companion_quick: 'Une profonde respiration avant la prochaine limite : c\'est déjà la moitié du chemin.',
        companion_reflect: 'Y a-t-il eu aujourd\'hui une situation où une limite calme a mieux fonctionné qu\'un non lancé fort ?',
      },
      gfk_ichbotschaft: {
        title: 'Messages en "je" plutôt que reproches en "tu"',
        parent_lens: 'Les messages en "tu" ("Tu es tellement bruyant !") déclenchent de la défense. Les messages en "je" ("Je commence à être fatigué et j\'ai besoin de calme") ouvrent des portes. Les enfants écoutent davantage quand ils ne se sentent pas attaqués.',
        parent_tips: [
          'Transforme les reproches en messages en "je" : au lieu de "Tu n\'écoutes jamais" → "Je ne me sens pas écouté et cela me rend triste."',
          'Partage ton besoin : "J\'ai besoin d\'un petit moment de silence pour réfléchir." Les enfants comprennent les besoins étonnamment bien.',
          'Entraîne-toi au quotidien : reformule trois phrases classiques en messages en "je" : le matin au brossage des dents, le midi au repas, le soir au coucher.',
        ],
        practical_tip: 'Aujourd\'hui, choisis une situation où tu dirais d\'habitude "Tu fais toujours..." et remplace-la par "Je ressens... parce que j\'ai besoin de..."',
        discussion_body: 'Quel message en "tu" vous est le plus difficile à reformuler ? Et qu\'est-ce qui vous aide à le faire ?',
        companion_quick: 'Nommer l\'émotion + le besoin : c\'est la formule d\'un vrai message en "je".',
        companion_reflect: 'Un message en "je" a-t-il provoqué aujourd\'hui une réaction qui t\'a surpris ?',
      },
      gfk_trotz: {
        title: 'Accompagner les crises d\'opposition avec sérénité',
        parent_lens: 'L\'opposition n\'est pas une rébellion, c\'est du développement. Quand un enfant est allongé par terre et crie, son cortex préfrontal n\'est tout simplement pas encore assez mûr pour réguler l\'émotion. Il a besoin de toi comme figure de corégulation.',
        parent_tips: [
          'Reste physiquement proche sans forcer : mets-toi à sa hauteur, parle calmement, ne le touche pas s\'il le refuse.',
          'Évite les discussions au cœur de la tempête. La conversation vient seulement une fois le calme revenu.',
          'Utilise des "ponts d\'émotion" : "Tu voulais la glace. C\'était tellement important pour toi. Je comprends."',
        ],
        practical_tip: 'Quand ton enfant est hors de lui : assieds-toi à côté de lui. Ne pars pas, n\'interviens pas, sois simplement là. Cela aide déjà à réguler.',
        discussion_body: 'Qu\'est-ce qui vous aide, vous, à rester calme quand votre enfant est en pleine explosion émotionnelle ?',
        companion_quick: 'Trois mots pour les crises d\'opposition : rester proche. Respirer calmement. Attendre que ça passe.',
        companion_reflect: 'Qu\'est-ce qui t\'a demandé le plus d\'énergie aujourd\'hui, et qu\'est-ce qui t\'a aidé à rester serein ?',
      },
      gfk_geschwister: {
        title: 'Faire des disputes entre frères et sœurs un terrain d\'apprentissage',
        parent_lens: 'Les frères et sœurs se disputent : c\'est normal et même important. Dans le conflit, les enfants apprennent le compromis, le changement de perspective et l\'affirmation de soi. Ton rôle est celui de médiateur, pas de juge.',
        parent_tips: [
          'Ne prends pas parti : "Je vois que vous êtes tous les deux en colère. Je t\'écoute d\'abord toi, puis toi."',
          'Laisse les enfants trouver eux-mêmes des solutions quand la situation ne dégénère pas. N\'interviens qu\'en cas de danger réel.',
          'Renforce chaque enfant individuellement : des moments réguliers en tête-à-tête, sans les autres, réduisent la jalousie sur le long terme.',
        ],
        practical_tip: 'À la prochaine dispute : demande aux deux enfants "De quoi as-tu besoin en ce moment ?" avant de décider qui a raison.',
        discussion_body: 'Comment gérez-vous les disputes entre frères et sœurs ? Qu\'est-ce qui fonctionne le mieux chez vous ?',
        companion_quick: 'Médiateur plutôt que juge : voilà ton rôle dans les conflits entre frères et sœurs.',
        companion_reflect: 'Y a-t-il eu aujourd\'hui un moment où tes enfants ont résolu une dispute par eux-mêmes ? Qu\'avez-vous appris ensemble ?',
      },
      gfk_gefühle: {
        title: 'Nommer et reconnaître les émotions',
        parent_lens: 'Les enfants capables de nommer leurs émotions ont un avantage énorme : ils peuvent communiquer ce dont ils ont besoin. Ce passage, du ressenti à la parole, demande de l\'entraînement et ton soutien.',
        parent_tips: [
          'Utilise le "baromètre des émotions" : demande le soir "Comment s\'est passée ta journée sur une échelle de 1 à 5 ?" et raconte d\'abord la tienne.',
          'Nomme tes propres émotions à voix haute : "Je suis un peu stressé en ce moment parce que j\'ai beaucoup à réfléchir." L\'apprentissage par l\'exemple fonctionne.',
          'Lisez des livres pour enfants sur les émotions, puis faites une pause : "Qu\'a bien pu ressentir le personnage ? Et toi ?"',
        ],
        practical_tip: 'Ce soir, pose la question : "Qu\'est-ce qui t\'a rendu joyeux aujourd\'hui ? Qu\'est-ce qui t\'a rendu triste ou en colère ?" et écoute simplement.',
        discussion_body: 'Quelle émotion votre enfant a-t-il particulièrement du mal à nommer ? Comment l\'accompagnez-vous là-dessus ?',
        companion_quick: 'D\'abord ressentir, puis nommer : l\'abécédaire des émotions commence avec toi comme modèle.',
        companion_reflect: 'Quel moment d\'émotion de ton enfant voulais-tu retenir aujourd\'hui ?',
      },
      gfk_nein: {
        title: 'Dire non, sans mauvaise conscience',
        parent_lens: 'Les parents qui ne disent jamais non élèvent des enfants qui ne connaissent pas les limites. Un non bienveillant montre à ton enfant : je prends mes propres besoins au sérieux, et toi aussi tu as le droit de le faire.',
        parent_tips: [
          'Un non n\'a pas besoin d\'une longue explication. Un clair "Non, ce n\'est pas possible maintenant" est complet.',
          'La culpabilité après un non est un signal, pas une faute. Demande-toi : ce non est-il vraiment injuste, ou simplement inconfortable ?',
          'Entraîne-toi à dire non aussi aux autres adultes (rendez-vous de jeu, engagements) : ton enfant apprend par ton exemple.',
        ],
        practical_tip: 'Aujourd\'hui, dis non une fois, de façon consciente, sans t\'excuser. Ressens l\'effet que cela produit.',
        discussion_body: 'Quand vous est-il le plus difficile de dire non : à vos enfants, ou aux autres ?',
        companion_quick: 'Un non à une chose est un oui à quelque chose de plus important : le plus souvent, à toi-même.',
        companion_reflect: 'Y a-t-il eu aujourd\'hui un non qui, avec le recul, t\'a semblé juste ?',
      },
      inclusion_stärken: {
        title: 'Voir les forces plutôt que juger les faiblesses',
        parent_lens: 'Chaque enfant possède une constellation de forces unique. En tant que parents, nous voyons souvent d\'abord les chantiers, alors que nous pourrions être les premiers à polir le diamant brut.',
        parent_tips: [
          'Ce soir, note 3 forces de ton enfant : non pas des réussites, mais des traits de caractère ("curieux", "attentionné", "persévérant").',
          'Nomme les forces de façon concrète et sans attendre : "Tu as été tellement patient à l\'instant, c\'est vraiment formidable."',
          'Évite les comparaisons avec les frères et sœurs ou d\'autres enfants. Chaque courbe de développement est unique.',
        ],
        practical_tip: 'Parle aujourd\'hui avec ton enfant d\'une de ses forces, non comme un éloge mais comme une observation : "J\'ai vu aujourd\'hui comment tu..."',
        discussion_body: 'Quelle force cachée de votre enfant aimeriez-vous partager aujourd\'hui ?',
        companion_quick: 'Voir les forces ne veut pas dire ignorer les faiblesses : cela veut dire rendre la croissance possible.',
        companion_reflect: 'Quelle force de ton enfant t\'a surpris ou impressionné aujourd\'hui ?',
      },
      inclusion_selbstwert: {
        title: 'Construire l\'estime de soi chaque jour',
        parent_lens: 'L\'estime de soi ne naît pas des seuls compliments : elle naît de l\'expérience "Je sais faire quelque chose. Je compte. J\'ai ma place." Tu peux intégrer ces trois expériences chaque jour.',
        parent_tips: [
          'Laisse ton enfant prendre de petites décisions : "Tu veux d\'abord faire tes devoirs ou d\'abord jouer ?" Autonomie = estime de soi.',
          'Montre un intérêt sincère : pose ton téléphone, regarde son visage, pose des questions. 10 minutes d\'attention pleine font des merveilles.',
          'Célèbre le processus, pas seulement le résultat : "Tu as essayé si longtemps, c\'est ça le plus important."',
        ],
        practical_tip: 'Aujourd\'hui : 10 minutes d\'attention entière pour ton enfant, sans téléphone, sans distraction, juste de l\'intérêt.',
        discussion_body: 'Qu\'est-ce qui rend votre enfant particulièrement fier de lui, et comment soutenez-vous ce sentiment ?',
        companion_quick: 'L\'estime de soi ne vient pas du miroir, mais du regard des personnes qui nous aiment.',
        companion_reflect: 'À quel moment ton enfant a-t-il montré aujourd\'hui "Je sais le faire !" ?',
      },
      inclusion_scheitern: {
        title: 'Voir l\'échec comme une chance d\'apprendre',
        parent_lens: 'Le cerveau apprend le plus par les erreurs, pas par les réussites. Quand ton enfant échoue et que tu restes calme, tu lui envoies le signal le plus fort : "Échouer est sans danger. Je peux le supporter."',
        parent_tips: [
          'En cas d\'échec, d\'abord la compassion, ensuite la solution : "C\'était frustrant. Que pourrions-nous faire autrement la prochaine fois ?"',
          'Raconte tes propres échecs : "Moi aussi j\'ai déjà... et puis j\'ai appris..." L\'exemple lève le tabou.',
          'Évite le "Je te l\'avais bien dit". Cela ferme des portes. À la place : "Qu\'est-ce que tu en retires ?"',
        ],
        practical_tip: 'Raconte aujourd\'hui à ton enfant un de tes propres échecs, et ce que tu en as appris.',
        discussion_body: 'Comment votre famille gère-t-elle les revers ? Qu\'est-ce qui vous aide à voir l\'échec comme une partie de l\'apprentissage ?',
        companion_quick: 'Les enfants autorisés à faire des erreurs deviennent des adultes plus courageux.',
        companion_reflect: 'Y a-t-il eu aujourd\'hui un échec que ton enfant a bien surmonté ? Qu\'est-ce qui l\'a aidé ?',
      },
      inclusion_hochsensibel: {
        title: 'Comprendre et accompagner les enfants hypersensibles',
        parent_lens: 'Environ 20 % des enfants sont hypersensibles : ils perçoivent plus, ressentent plus intensément et ont besoin de plus de temps de récupération. Ce n\'est pas une faiblesse, mais un trait de personnalité avec ses propres forces.',
        parent_tips: [
          'Réduis la surcharge sensorielle : prévois des moments de transition calmes avant les situations de forte pression (courses, école, fête).',
          'La prévisibilité protège : annonce ce qui vient ("Dans 10 minutes, on part"). Les surprises sont éprouvantes pour les enfants hypersensibles.',
          'Leur sensibilité est une force : ils remarquent quand quelqu\'un est triste et réfléchissent en profondeur. Nomme cela de façon positive.',
        ],
        practical_tip: 'Aujourd\'hui, prévois 15 minutes de "temps de ressourcement" au calme pour ton enfant après une situation de forte pression, sans écran et sans attente.',
        discussion_body: 'Reconnaissez-vous des traits d\'hypersensibilité chez votre enfant ? Qu\'est-ce qui vous aide à les gérer au quotidien ?',
        companion_quick: 'Les enfants hypersensibles n\'ont pas besoin d\'être endurcis : ils ont besoin d\'espaces protégés et de compréhension.',
        companion_reflect: 'Quand ton enfant a-t-il eu beaucoup d\'impressions à traiter aujourd\'hui, et comment s\'en est-il remis ensuite ?',
      },
      inclusion_freundschaft: {
        title: 'Accompagner les amitiés, sans les diriger',
        parent_lens: 'Les amitiés sont le lieu d\'apprentissage le plus important des compétences sociales. Les enfants apprennent à donner et à recevoir, à négocier et à renoncer, mais seulement si, en tant que parents, nous lâchons prise et accompagnons au lieu de diriger.',
        parent_tips: [
          'Pose des questions, mais ne juge pas : "Comment ça s\'est passé avec... aujourd\'hui ?" vaut mieux que "Je ne l\'aime pas, l\'autre jour il a..."',
          'Laisse d\'abord les enfants résoudre eux-mêmes leurs conflits : n\'interviens que lorsqu\'une vraie détresse apparaît.',
          'Favorise activement les amitiés : rendez-vous de jeu, invitations. Les occasions sociales n\'arrivent pas toutes seules.',
        ],
        practical_tip: 'Demande aujourd\'hui à ton enfant : "Qui dans ta classe ou ton groupe aime les mêmes choses que toi ?" et réfléchissez ensemble à comment créer du temps pour cela.',
        discussion_body: 'Comment laissez-vous à vos enfants de l\'espace pour leurs propres amitiés, même quand vous ne comprenez pas toujours leurs choix ?',
        companion_quick: 'Une vraie amitié ne se force pas, mais vous pouvez ensemble créer un terrain fertile.',
        companion_reflect: 'Ton enfant a-t-il parlé aujourd\'hui de quelqu\'un qui compte pour lui ? Qu\'as-tu appris ?',
      },
      inclusion_resilienz: {
        title: 'La résilience : comment les enfants grandissent face aux défis',
        parent_lens: 'La résilience n\'est pas innée, elle se cultive. Les enfants deviennent résistants quand ils vivent des défis ET qu\'ils sont soutenus. Ce n\'est pas la protection, mais l\'accompagnement qui est la clé.',
        parent_tips: [
          'Laisse ton enfant mener un défi jusqu\'au bout : n\'aide pas trop tôt. Propose ton aide seulement quand il n\'avance vraiment plus.',
          'Renforce le dialogue intérieur : "Qu\'est-ce que tu penses pouvoir faire ?" plutôt que de donner directement la solution.',
          'Parle des crises familiales de façon adaptée à l\'âge : les enfants qu\'on tient à l\'écart développent des fantasmes pires que la vérité.',
        ],
        practical_tip: 'Si ton enfant échoue aujourd\'hui : attends 30 secondes avant d\'intervenir. Souvent, la solution vient d\'elle-même.',
        discussion_body: 'Quel défi votre enfant a-t-il relevé en vous surprenant ?',
        companion_quick: 'La résilience grandit dans l\'espace entre le défi et le soutien : ni avant, ni après.',
        companion_reflect: 'À quoi reconnaissez-vous que votre enfant a grandi intérieurement aujourd\'hui ?',
      },
      inclusion_vielfalt: {
        title: 'Vivre la diversité : la différence comme force',
        parent_lens: 'Les enfants qui apprennent tôt que les gens sont différents, par leurs origines, leurs capacités, leur façon de penser, développent plus d\'empathie et moins de peur du contact. Tu peux faire vivre la diversité au quotidien.',
        parent_tips: [
          'Parle ouvertement des différences : les enfants les remarquent de toute façon. "Oui, Lara a une couleur de peau différente de la tienne, et sa famille vient de..."',
          'Choisis des livres, des films et des jeux avec des personnages variés : la représentation influence la vision du monde.',
          'Célèbre les particularités familiales : "Chez nous, c\'est comme ça, et dans d\'autres familles c\'est autrement, et c\'est ça qui est beau."',
        ],
        practical_tip: 'Lis aujourd\'hui un livre pour enfants avec un personnage principal différent de ton enfant, et parlez-en ensuite.',
        discussion_body: 'Comment expliquez-vous aux enfants les différences entre les gens d\'une manière qui éveille la curiosité plutôt que la peur ?',
        companion_quick: 'Les enfants sont naturellement curieux des différences : les préjugés, ils les apprennent plus tard.',
        companion_reflect: 'Ton enfant a-t-il posé aujourd\'hui une question sur les différences qui t\'a fait réfléchir ?',
      },
      leadership_struktur: {
        title: 'La structure de la journée comme ancre de sécurité',
        parent_lens: 'Le cerveau de l\'enfant adore la prévisibilité. Les rituels et les structures ne sont pas une contrainte : ils sont l\'échafaudage qui donne aux enfants la liberté de s\'épanouir en sécurité.',
        parent_tips: [
          'Des ancres fixes dans la journée : le rituel du réveil, les repas, le coucher. Ces trois-là suffisent pour une vraie stabilité.',
          'Prévois des rituels de transition : annonce de courtes transitions entre les activités. "Dans 5 minutes, on range."',
          'La structure n\'est pas du stress : modifie-la peu à peu si nécessaire, pas brusquement.',
        ],
        practical_tip: 'Aujourd\'hui, regarde le programme de la journée avec ton enfant : discutez de ce qui vient. Cela réduit la résistance et l\'incertitude.',
        discussion_body: 'Quel rituel quotidien est particulièrement important pour votre famille, et pourquoi ?',
        companion_quick: 'La prévisibilité crée la sécurité. La sécurité crée la disposition à apprendre.',
        companion_reflect: 'Quel moment aujourd\'hui a montré que ton enfant a besoin de structure, ou en a profité ?',
      },
      leadership_schlaf: {
        title: 'Rituels du sommeil : créer le calme pour le corps et l\'esprit',
        parent_lens: 'Le sommeil est un temps de développement, pas une pause. Pendant le sommeil, le cerveau traite la journée, consolide les souvenirs et se régénère. Un bon rituel d\'endormissement est un des investissements les plus efficaces pour ton enfant.',
        parent_tips: [
          '30 minutes avant le coucher : pas d\'écran, pas de jeux excitants. Le retour au calme demande du temps.',
          'Toujours le même ordre : dents, pyjama, histoire, lumière éteinte. Les rituels signalent au cerveau : "Maintenant, c\'est l\'heure de dormir."',
          'Si ton enfant n\'arrive pas à s\'endormir : respirez ensemble. 4 secondes à l\'inspiration, 6 secondes à l\'expiration, cela active le système nerveux parasympathique.',
        ],
        practical_tip: 'Ce soir, instaure un rituel de respiration de 3 minutes avant le coucher : inspirer, expirer, ensemble.',
        discussion_body: 'Quel est votre rituel d\'endormissement préféré, et comment l\'avez-vous développé ?',
        companion_quick: 'Un rituel de clôture calme est la meilleure entrée vers un bon sommeil.',
        companion_reflect: 'Comment s\'est passé l\'endormissement aujourd\'hui ? Qu\'est-ce qui a aidé, qu\'est-ce qui a gêné ?',
      },
      leadership_bildschirm: {
        title: 'Aménager le temps d\'écran en conscience',
        parent_lens: 'Ce n\'est pas le temps d\'écran en soi qui pose problème, c\'est la consommation passive et non encadrée, sans échange ensuite. Avec quelques règles simples, l\'écran devient une activité de loisir saine.',
        parent_tips: [
          'Des horaires fixes plutôt que des interdictions spontanées : "Après les devoirs, jusqu\'à 17 h" est plus clair que "pas trop".',
          'Regardez ensemble et parlez-en après : "Qu\'est-ce qui t\'a plu ? Qu\'est-ce qui était bizarre ou étrange ?" Cela renforce l\'esprit critique face aux médias.',
          'Aménagez des espaces sans écran : la chambre et la table du repas sont de bonnes limites pour commencer.',
        ],
        practical_tip: 'Aujourd\'hui, regardez quelque chose ensemble pendant 15 minutes, puis pose 2 questions à ce sujet. Cela change la façon dont ton enfant perçoit les médias.',
        discussion_body: 'Comment gérez-vous le temps d\'écran chez vous : qu\'est-ce qui a fait ses preuves, qu\'est-ce qui marche moins bien ?',
        companion_quick: 'L\'usage réfléchi des médias ne s\'apprend pas par l\'interdiction, mais par l\'échange.',
        companion_reflect: 'Comment ton enfant a-t-il utilisé les médias aujourd\'hui : de façon active ou passive ? Qu\'as-tu remarqué ?',
      },
      leadership_autoritaet: {
        title: 'L\'autorité par le lien, pas par la peur',
        parent_lens: 'Faire autorité ne veut pas dire être bruyant et sévère. La véritable autorité parentale naît quand un enfant sait : "Tu m\'aimes ET tu es clair." Lien et guidance ne s\'excluent pas : ils se renforcent l\'un l\'autre.',
        parent_tips: [
          'Des consignes claires sans discussion : "On fait comme ça maintenant." Ensuite, pas de négociation, seulement de la compréhension à offrir.',
          'Les excuses rendent les adultes plus forts, pas plus faibles. "Ce n\'était pas juste de ma part tout à l\'heure" : les enfants respectent cela.',
          'Élaborez certaines règles ensemble : cela augmente la disposition à les respecter.',
        ],
        practical_tip: 'Aujourd\'hui, formule une règle comme une consigne positive plutôt que comme une interdiction : "On range après avoir joué" au lieu de "Ne laisse pas traîner".',
        discussion_body: 'Comment trouvez-vous l\'équilibre entre la guidance et la participation de vos enfants ?',
        companion_quick: 'L\'autorité sans lien, c\'est du contrôle. Le lien sans autorité, c\'est le chaos. Les deux ensemble, c\'est la guidance.',
        companion_reflect: 'Y a-t-il eu aujourd\'hui un moment où ta clarté sereine a eu plus d\'effet qu\'un mot d\'autorité ?',
      },
      leadership_hausaufgaben: {
        title: 'Les devoirs sans stress : un cadre qui fonctionne',
        parent_lens: 'Le stress des devoirs n\'est souvent pas un problème d\'apprentissage, mais un problème de rituel. Avec la bonne structure et le bon moment, le sujet se détend de lui-même.',
        parent_tips: [
          'Trouve le bon moment : juste après l\'école ou après une courte pause de récupération, mais avant le soir.',
          'Je suis là, mais je n\'aide pas tout de suite : d\'abord essayer soi-même. Après 10 minutes sans progrès : demander "Où est-ce que ça coince ?"',
          'Prépare l\'espace de travail : un endroit fixe, un bureau rangé, pas de téléphone en vue, cela réduit les distractions.',
        ],
        practical_tip: 'Aujourd\'hui, définis avec ton enfant LE moment des devoirs pour la semaine, et notez-le.',
        discussion_body: 'Qu\'est-ce qui a rendu les devoirs moins stressants chez vous ? Quelles routines fonctionnent ?',
        companion_quick: 'La structure pendant l\'apprentissage n\'est pas une contrainte : c\'est le moteur de la concentration.',
        companion_reflect: 'Comment s\'est passé l\'apprentissage aujourd\'hui ? Que pourriez-vous essayer autrement demain ?',
      },
      leadership_selbstaendigkeit: {
        title: 'L\'autonomie : lâcher prise, c\'est aussi de l\'amour',
        parent_lens: 'Les enfants deviennent autonomes quand nous leur faisons confiance. Mais lâcher prise semble risqué, et c\'est normal. L\'art, c\'est de transmettre pas à pas davantage de responsabilités.',
        parent_tips: [
          'Confie des tâches adaptées à l\'âge : à 3 ans, ranger les jouets ; à 6 ans, mettre la table ; à 10 ans, cuisiner avec toi.',
          'N\'interviens pas quand ça va lentement. Lentement et par soi-même vaut mieux que vite et avec de l\'aide.',
          'Accepte les erreurs dans les tâches autonomes : le verre de lait se renverse, ce n\'est pas un échec, c\'est de l\'entraînement.',
        ],
        practical_tip: 'Aujourd\'hui, confie à ton enfant une nouvelle tâche que tu faisais toi-même jusqu\'ici, et laisse-le la faire entièrement seul.',
        discussion_body: 'Quelle est la plus grande preuve d\'autonomie de votre enfant dont vous êtes tous les deux fiers ?',
        companion_quick: 'Chaque tâche que l\'enfant accomplit seul est un investissement dans sa confiance en lui future.',
        companion_reflect: 'Quand avez-vous lâché prise aujourd\'hui, et comment cela vous a-t-il fait sentir ?',
      },
      leadership_natur: {
        title: 'La nature et le mouvement comme rituel familial',
        parent_lens: 'Les enfants qui sont régulièrement dehors dorment mieux, sont plus concentrés et plus stables émotionnellement. La nature n\'est pas une occupation de loisir : c\'est un besoin fondamental.',
        parent_tips: [
          '15 minutes dehors chaque jour ont déjà un effet mesurable : pas besoin d\'excursion, le trajet vers l\'école compte aussi.',
          'Bougez ensemble : vélo, promenade, terrain de jeu. Bouger ensemble renforce le lien.',
          'Laisse ton enfant découvrir la nature : cailloux, insectes, flaques. Pas de programme, juste de l\'ouverture.',
        ],
        practical_tip: 'Aujourd\'hui, prévois une sortie de 15 minutes dehors : sans but, sans programme, simplement ensemble.',
        discussion_body: 'Quelle expérience de la nature de votre enfance aimeriez-vous transmettre à vos enfants ?',
        companion_quick: 'Être dehors, c\'est de la nourriture pour le cerveau, pour les enfants comme pour les adultes.',
        companion_reflect: 'Comment votre temps dehors aujourd\'hui a-t-il changé l\'ambiance ?',
      },
      milestone_sprache: {
        title: 'Le développement du langage : soutenir en jouant',
        parent_lens: 'Le développement du langage ne passe pas par l\'apprentissage de vocabulaire : il naît dans le dialogue. Les enfants apprennent à parler quand les adultes parlent avec eux, les écoutent et réagissent à ce qu\'ils disent.',
        parent_tips: [
          'Décris ton quotidien à voix haute : "Maintenant, je coupe les carottes." Cela enrichit le vocabulaire passif.',
          'Reprends les propos de ton enfant et développe-les : "Balle !" → "Oui, la balle rouge roule."',
          'Lis à voix haute chaque jour, même si l\'enfant sait déjà lire. Les textes des livres ont d\'autres structures que le langage du quotidien.',
        ],
        practical_tip: 'Aujourd\'hui, lis à voix haute pendant 10 minutes, et demande en lisant : "À ton avis, qu\'est-ce qui va se passer ensuite ?"',
        discussion_body: 'Quels mots ou quelles phrases de votre enfant vous ont récemment surpris ou touchés ?',
        companion_quick: 'Le langage grandit dans la conversation, pas dans le silence.',
        companion_reflect: 'Quel progrès langagier de votre enfant avez-vous remarqué aujourd\'hui ?',
      },
      milestone_schule: {
        title: 'Accompagner la rentrée et les transitions avec sérénité',
        parent_lens: 'Les transitions, la rentrée scolaire, le changement de classe, une nouvelle crèche, sont pour les enfants les phases d\'apprentissage les plus intenses. Ton calme et ta confiance se transmettent à ton enfant. Tu es sa base de régulation.',
        parent_tips: [
          'Découvrir les nouveaux lieux à l\'avance : si possible, visiter la nouvelle salle de classe ou l\'école avant le premier jour.',
          'Parler des émotions : "C\'est normal d\'être impatient. Moi aussi j\'étais nerveux lors de mon premier jour d\'école."',
          'De petits objets de transition aident : une photo dans le sac, un petit souvenir ; les objets créent de la sécurité.',
        ],
        practical_tip: 'Demande aujourd\'hui à ton enfant : "Qu\'est-ce qui te réjouit à propos de... ? Qu\'est-ce qui t\'inquiète encore ?" et écoute sans juger.',
        discussion_body: 'Comment avez-vous accompagné une transition importante de votre enfant ? Qu\'est-ce qui a aidé ?',
        companion_quick: 'Les transitions sont à la fois une fin et un début, et les deux ont le droit d\'être ressentis.',
        companion_reflect: 'Quelle émotion ton enfant a-t-il montrée aujourd\'hui autour d\'une transition ?',
      },
      milestone_sozial: {
        title: 'L\'intelligence sociale : la compétence la plus importante du XXIe siècle',
        parent_lens: 'Le QI ouvre les portes. Le QE (l\'intelligence émotionnelle) fait entrer les gens. Les enfants dotés d\'une grande compétence sociale coopèrent, communiquent et se mettent mieux à la place des autres, et c\'est auprès de toi qu\'ils l\'apprennent.',
        parent_tips: [
          'Modélise l\'empathie chaque jour : "Le chat a l\'air triste. Pourquoi, à ton avis ?"',
          'Entraîne le changement de perspective : "Comment ... s\'est-il senti, à ton avis, quand tu as dit ça ?"',
          'Souligne explicitement le comportement social : "Tu as attendu qu\'il finisse de parler. C\'était très respectueux."',
        ],
        practical_tip: 'Aujourd\'hui, après la crèche ou l\'école, parle d\'une situation sociale : "Est-ce que quelqu\'un a fait quelque chose de gentil aujourd\'hui ?"',
        discussion_body: 'Quel aspect de la compétence sociale trouvez-vous le plus important aujourd\'hui, pour les enfants comme pour les adultes ?',
        companion_quick: 'La compétence sociale n\'est pas un talent : c\'est une capacité qui se cultive.',
        companion_reflect: 'Quand ton enfant a-t-il montré de l\'empathie aujourd\'hui, même si c\'est peut-être passé inaperçu ?',
      },
      milestone_emotion: {
        title: 'La maturité émotionnelle : quand les émotions sont traitées',
        parent_lens: 'La maturité émotionnelle ne consiste pas à n\'avoir aucune émotion, mais à les traiter. Les enfants autorisés à exprimer leurs émotions apprennent à long terme à mieux les gérer.',
        parent_tips: [
          'Toutes les émotions sont permises, pas toutes les actions. "Tu as le droit d\'être en colère. Tu n\'as pas le droit de frapper."',
          'Ne minimise pas les émotions : au lieu de "Ce n\'est pas si grave" → "Je vois que ça te touche vraiment."',
          'Laisse ressentir les émotions dans le corps : "Où est-ce que tu ressens ça en ce moment ? Dans le ventre ? Dans la poitrine ?"',
        ],
        practical_tip: 'Aujourd\'hui, demande : "Comment ça se ressent dans ton corps ?" et accepte chaque réponse.',
        discussion_body: 'Quelle émotion est la plus difficile à montrer ouvertement dans votre famille ?',
        companion_quick: 'Accueillir les émotions n\'est pas une faiblesse : c\'est une force émotionnelle.',
        companion_reflect: 'Quelle émotion ton enfant a-t-il montrée ouvertement aujourd\'hui, et comment l\'avez-vous accompagnée ensemble ?',
      },
      milestone_kreativitaet: {
        title: 'Encourager la créativité, sans viser le résultat',
        parent_lens: 'La créativité est une capacité à résoudre des problèmes déguisée. Quand les enfants dessinent, construisent, bricolent ou jouent, ils entraînent leur souplesse et leur originalité, les compétences de l\'avenir.',
        parent_tips: [
          'Pas de focalisation sur le produit fini : "Raconte-moi ce que tu as fait" plutôt que "C\'est censé être quoi ?"',
          'Propose des matériaux sans mode d\'emploi : tissu, carton, éléments naturels, puis lâche prise.',
          'Sois créatif toi-même : quand les parents dessinent, construisent, chantent, sans chercher la perfection, ils autorisent leurs enfants à faire de même.',
        ],
        practical_tip: 'Aujourd\'hui, propose 20 minutes de bricolage libre : sans modèle, sans consigne, juste des matériaux.',
        discussion_body: 'Quel est le projet le plus créatif que votre enfant ait imaginé tout seul ?',
        companion_quick: 'La créativité a besoin d\'espace, de temps et d\'un adulte qui ne juge pas.',
        companion_reflect: 'Qu\'est-ce que ton enfant a inventé, construit ou imaginé aujourd\'hui qui t\'a surpris ?',
      },
      milestone_koerper: {
        title: 'Renforcer la perception du corps : le mouvement comme moteur du développement',
        parent_lens: 'Le développement moteur et le développement cognitif sont indissociables. Les enfants qui grimpent, gardent l\'équilibre et dansent développent aussi leur pensée spatiale et leur concentration.',
        parent_tips: [
          'Intègre le mouvement chaque jour : non comme un programme sportif, mais comme le quotidien, les escaliers plutôt que l\'ascenseur, marcher plutôt que porter.',
          'Alterne motricité globale et motricité fine : construire (fine) et grimper (globale) se complètent à merveille.',
          'Renforce une image du corps positive : "Ton corps est capable de tant de choses", indépendamment de l\'apparence ou de la performance.',
        ],
        practical_tip: 'Aujourd\'hui, prévois 10 minutes de jeu de mouvement : équilibre, sauts, roulades. Pas de programme, juste le corps et le plaisir.',
        discussion_body: 'Quelle activité de mouvement procure le plus de joie à votre enfant, et pourquoi ?',
        companion_quick: 'Le mouvement n\'est pas une occupation de loisir : c\'est un moteur d\'apprentissage.',
        companion_reflect: 'Qu\'est-ce que ton enfant a essayé ou osé physiquement aujourd\'hui qui était nouveau ?',
      },
      milestone_uebergaenge: {
        title: 'Préparer la puberté, tôt et avec sérénité',
        parent_lens: 'La puberté commence plus tôt que ne le pensent la plupart des parents, et les bases se posent dès l\'enfance. Une communication ouverte et une relation parent-enfant sécurisante sont la meilleure préparation.',
        parent_tips: [
          'Parle tôt des changements du corps, de façon factuelle, sans dramatiser. Les enfants informés ont moins peur.',
          'Partage tes propres souvenirs de puberté (de façon appropriée) : "Moi aussi j\'étais peu sûr de moi avec...", cela normalise.',
          'Crée des espaces d\'intimité : frapper avant d\'entrer, respecter les journaux intimes. La confiance naît du respect.',
        ],
        practical_tip: 'Aujourd\'hui, regarde avec ton enfant (de façon adaptée à son âge) une vidéo ou un livre sur les processus du corps, sans gêne.',
        discussion_body: 'Avec le recul, qu\'est-ce qui comptait pour vous pendant la puberté, et qu\'auriez-vous aimé que vos parents fassent ?',
        companion_quick: 'La meilleure préparation à la puberté, c\'est une relation solide aujourd\'hui.',
        companion_reflect: 'Ton enfant a-t-il posé aujourd\'hui une question qui montre qu\'il commence à réfléchir sur lui-même ?',
      },
      gfk_wiedergutmachung: {
        title: 'Quand les parents craquent : la réparation comme force',
        parent_lens: 'Aucun parent n\'est toujours patient. Quand tu craques, ce n\'est pas un échec en tant que parent, c\'est un moment humain. Mais ce qui vient après façonne la relation plus fort que l\'éclat lui-même.',
        parent_tips: [
          'La réparation demande trois étapes : prendre ses responsabilités ("Je me suis trompé"), montrer de la compassion, et faire autrement si besoin.',
          'Des excuses sans "mais" : "Je suis désolé d\'avoir été si fort. Ce n\'était pas correct." C\'est tout.',
          'Ton enfant te voit comme un être humain, et c\'est une bonne chose. Par la réparation, les enfants apprennent que les relations survivent aux tempêtes.',
        ],
        practical_tip: 'Si aujourd\'hui tu ne t\'es pas comporté joliment dans une situation : retourne voir ton enfant et dis-le-lui. Trois phrases suffisent.',
        discussion_body: 'Comment, en tant que parents, avez-vous appris à gérer vos propres éclats, sans vous juger trop durement ?',
        companion_quick: 'La réparation enseigne aux enfants ce qu\'aucun guide ne peut : que les relations peuvent être réparées.',
        companion_reflect: 'Y a-t-il eu aujourd\'hui un moment que tu aurais géré autrement avec le recul, et qu\'en as-tu fait ?',
      },
    },
    es: {
      gfk_warum: {
        title: 'Acompañar con calma las preguntas de "por qué"',
        parent_lens: 'Tu hijo te pregunta "¿por qué?" cien veces al día. No lo hace para fastidiarte, sino porque su cerebro está tejiendo conexiones. Quiere comprender el mundo.',
        parent_tips: [
          'Usa la comunicación no violenta (CNV): nombra con claridad tus propios sentimientos y necesidades en lugar de regañar.',
          'Responde a los "por qué" de forma breve y sencilla: tu hijo busca lógica, no conferencias científicas.',
          'Pon límites con cariño a través de tu presencia personal ("No quiero que pegues"), no mediante castigos.',
        ],
        practical_tip: 'Ante el próximo "por qué": primero refleja el sentimiento ("¡Tienes curiosidad!") y luego responde en una sola frase.',
        discussion_body: '¿Qué frase breve y tranquila os ayuda cuando vuestro hijo pregunta por décima vez el porqué de algo?',
        companion_quick: 'Hoy elige solo una respuesta tranquila a un "por qué" y, después, mantente conscientemente breve.',
        companion_reflect: '¿Cuándo buscó hoy tu hijo más conexiones y cómo pudiste darle orientación con calma?',
      },
      gfk_grenzen: {
        title: 'Poner límites con cariño y claridad',
        parent_lens: 'Los límites cariñosos no son una contradicción. Los niños necesitan ambas cosas: sentirse queridos Y una orientación clara sobre lo que no se puede. Los límites sin conexión parecen muros; los límites con conexión funcionan como barreras de protección.',
        parent_tips: [
          'Nombra primero el sentimiento de tu hijo y luego el límite: "Veo que estás enfadado. Y aun así: no se puede pegar."',
          'Mantén la calma en el cuerpo: tu tono habla más alto que tus palabras. Respirar hondo antes de reaccionar ayuda.',
          'Anuncia las consecuencias y cúmplelas. No amenaces, anticipa: "Si... entonces..."',
        ],
        practical_tip: 'Practica hoy una frase con sentimiento + límite: "Entiendo que quieras eso. Y: no.", manteniendo la calma al decirlo.',
        discussion_body: '¿Cómo reaccionáis cuando llegáis a vuestros propios límites? ¿Qué frase os ayuda a mantener la calma?',
        companion_quick: 'Respirar hondo una vez antes de la próxima reacción ante un límite: eso ya es media batalla ganada.',
        companion_reflect: '¿Hubo hoy una situación en la que un límite tranquilo funcionó mejor que un "no" a gritos?',
      },
      gfk_ichbotschaft: {
        title: 'Mensajes en primera persona en lugar de reproches',
        parent_lens: 'Los reproches ("¡Eres tan ruidoso!") provocan rechazo. Los mensajes en primera persona ("Me estoy cansando y necesito tranquilidad") abren puertas. Los niños escuchan más cuando no se sienten atacados.',
        parent_tips: [
          'Transforma los reproches en mensajes en primera persona: en vez de "Nunca escuchas" → "No me siento escuchado y eso me pone triste."',
          'Comparte tu necesidad: "Ahora necesito un momento de silencio para pensar." Los niños entienden las necesidades sorprendentemente bien.',
          'Practica en el día a día: reformula tres frases habituales como mensajes en primera persona: por la mañana al lavarse los dientes, al mediodía en la comida y por la noche al dormir.',
        ],
        practical_tip: 'Hoy elige una situación en la que sueles decir "Tú siempre..." y sustitúyela por "Yo siento... porque necesito..."',
        discussion_body: '¿Qué reproche os cuesta más reformular? ¿Y qué os ayuda a conseguirlo?',
        companion_quick: 'Nombrar el sentimiento + la necesidad: esa es la fórmula de un verdadero mensaje en primera persona.',
        companion_reflect: '¿Un mensaje en primera persona provocó hoy una reacción que te sorprendió?',
      },
      gfk_trotz: {
        title: 'Acompañar con calma las rabietas',
        parent_lens: 'La rabieta no es rebeldía, es desarrollo. Cuando un niño se tira al suelo gritando, su córtex prefrontal simplemente aún no está lo bastante maduro para regular la emoción. Te necesita como apoyo para la corregulación.',
        parent_tips: [
          'Quédate cerca físicamente sin forzar: ponte a su altura, habla con calma y no lo toques si te lo rechaza.',
          'Evita las discusiones en plena tormenta. La conversación llega cuando se haya calmado.',
          'Usa "puentes de sentimientos": "Querías el helado. Era muy importante para ti. Lo entiendo."',
        ],
        practical_tip: 'Cuando tu hijo esté fuera de sí: siéntate a su lado. No te vayas ni intervengas, solo acompáñalo. Eso ya ayuda a regular.',
        discussion_body: '¿Qué os ayuda a vosotros a mantener la calma cuando vuestro hijo está en plena explosión emocional?',
        companion_quick: 'Tres ideas para las rabietas: quédate cerca, respira con calma y espera a que pase.',
        companion_reflect: '¿Qué te costó hoy más energía y qué te ayudó a mantener la calma durante ese momento?',
      },
      gfk_geschwister: {
        title: 'Usar las peleas entre hermanos como terreno de aprendizaje',
        parent_lens: 'Los hermanos discuten, y eso es normal e incluso importante. En el conflicto, los niños aprenden a llegar a acuerdos, a cambiar de perspectiva y a afirmarse. Tu papel es el de mediador, no el de juez.',
        parent_tips: [
          'No tomes partido: "Veo que ahora mismo los dos estáis enfadados. Primero te escucho a ti y luego a ti."',
          'Deja que los niños encuentren soluciones por sí mismos cuando la situación no se desborda. Interviene solo si hay peligro.',
          'Fortalece a cada hijo por separado: los momentos regulares a solas, sin hermanos, reducen los celos a largo plazo.',
        ],
        practical_tip: 'En la próxima pelea: pregunta a ambos niños "¿Qué necesitas ahora mismo?" antes de decidir quién tiene razón.',
        discussion_body: '¿Cómo lo gestionáis cuando los hermanos se pelean? ¿Qué os funciona mejor?',
        companion_quick: 'Mediador en lugar de juez: ese es tu papel en los conflictos entre hermanos.',
        companion_reflect: '¿Hubo hoy un momento en el que tus hijos resolvieron una pelea por sí mismos? ¿Qué aprendisteis de ello?',
      },
      gfk_gefühle: {
        title: 'Nombrar y reconocer los sentimientos',
        parent_lens: 'Los niños que saben nombrar sus sentimientos tienen una enorme ventaja: pueden comunicar lo que necesitan. Ese paso, del sentir al hablar, requiere práctica y tu apoyo.',
        parent_tips: [
          'Usa el "barómetro de sentimientos": pregunta por la noche "¿Cómo ha ido tu día en una escala del 1 al 5?" y cuenta tú primero.',
          'Nombra tus propios sentimientos en voz alta: "Ahora estoy un poco estresado porque tengo mucho en que pensar." Aprender con el ejemplo funciona.',
          'Leed cuentos sobre sentimientos y, después, haz una pausa: "¿Qué crees que sintió el personaje? ¿Y tú?"',
        ],
        practical_tip: 'Esta noche haz la pregunta: "¿Qué te ha hecho feliz hoy? ¿Qué te ha puesto triste o enfadado?" y simplemente escucha.',
        discussion_body: '¿Qué sentimiento le cuesta especialmente nombrar a vuestro hijo? ¿Cómo lo abordáis?',
        companion_quick: 'Primero sentir, luego nombrar: el abecé de los sentimientos empieza contigo como modelo.',
        companion_reflect: '¿Qué momento emocional de tu hijo quisiste guardar hoy?',
      },
      gfk_nein: {
        title: 'Decir que no, sin mala conciencia',
        parent_lens: 'Los padres que nunca dicen que no crían a niños que no conocen los límites. Un "no" cariñoso le muestra a tu hijo: me tomo en serio mis necesidades, y tú también puedes hacerlo.',
        parent_tips: [
          'Un "no" no necesita una larga explicación. Un claro "No, ahora no puede ser" es suficiente.',
          'La culpa después de un "no" es una señal, no un error. Pregúntate: ¿este "no" es realmente injusto o solo incómodo?',
          'Practica el "no" también con otros adultos (quedadas, compromisos): tu hijo aprende con tu ejemplo.',
        ],
        practical_tip: 'Hoy di que no una vez, de forma consciente, sin disculparte. Fíjate en cómo se siente.',
        discussion_body: '¿Cuándo os cuesta más decir que no, a vuestros hijos o a los demás?',
        companion_quick: 'Un "no" a una cosa es un "sí" a algo más importante; casi siempre, a ti mismo.',
        companion_reflect: '¿Hubo hoy un "no" que, visto en perspectiva, se sintió acertado?',
      },
      inclusion_stärken: {
        title: 'Ver las fortalezas en lugar de juzgar las debilidades',
        parent_lens: 'Cada niño tiene una constelación única de fortalezas. Como padres, muchas veces vemos primero las carencias, cuando podríamos ser los primeros en pulir ese diamante en bruto.',
        parent_tips: [
          'Esta noche anota 3 fortalezas de tu hijo: no logros, sino rasgos de carácter ("curioso", "cuidadoso", "perseverante").',
          'Nombra las fortalezas de forma concreta y en el momento: "Qué paciente has sido hace un momento, eso es genial."',
          'Evita las comparaciones con hermanos u otros niños. Cada curva de desarrollo es única.',
        ],
        practical_tip: 'Hoy habla con tu hijo sobre una de sus fortalezas, no como elogio, sino como observación: "Hoy he visto cómo tú..."',
        discussion_body: '¿Qué fortaleza oculta de vuestro hijo os gustaría compartir hoy?',
        companion_quick: 'Ver las fortalezas no significa ignorar las debilidades: significa hacer posible el crecimiento.',
        companion_reflect: '¿Qué fortaleza de tu hijo te sorprendió o te impresionó hoy?',
      },
      inclusion_selbstwert: {
        title: 'Construir la autoestima cada día',
        parent_lens: 'La autoestima no nace solo del elogio: nace de la experiencia de "Sé hacer algo. Soy importante. Pertenezco." Puedes integrar las tres experiencias cada día.',
        parent_tips: [
          'Deja que tu hijo tome pequeñas decisiones: "¿Quieres hacer primero las tareas o jugar primero?" Autonomía = autoestima.',
          'Muestra interés de verdad: deja el móvil, míralo a la cara, pregúntale. 10 minutos de atención plena hacen maravillas.',
          'Celebra el proceso, no solo el resultado: "Lo intentaste durante tanto rato, esa es la parte importante."',
        ],
        practical_tip: 'Hoy: 10 minutos de atención exclusiva para tu hijo, sin móvil, sin distracciones, solo interés.',
        discussion_body: '¿Qué hace que vuestro hijo se sienta especialmente orgulloso de sí mismo y cómo apoyáis ese sentimiento?',
        companion_quick: 'La autoestima no viene del espejo, sino de los ojos de las personas que nos quieren.',
        companion_reflect: '¿En qué momento mostró hoy tu hijo un "¡yo puedo!"?',
      },
      inclusion_scheitern: {
        title: 'Ver el fracaso como una oportunidad de aprender',
        parent_lens: 'El cerebro aprende con más fuerza de los errores, no de los éxitos. Cuando tu hijo fracasa y tú mantienes la calma, le das la señal más poderosa: "Fracasar es seguro. Yo lo sostengo."',
        parent_tips: [
          'Ante el fracaso, primero compasión y luego solución: "Qué frustrante. ¿Qué podríamos hacer distinto la próxima vez?"',
          'Cuenta tus propios fracasos: "A mí también me pasó... y entonces aprendí..." El ejemplo quita el tabú.',
          'Evita el "ya te lo dije". Eso cierra puertas. En su lugar: "¿Qué te llevas de esto?"',
        ],
        practical_tip: 'Cuéntale hoy a tu hijo un fracaso propio y lo que aprendiste de él.',
        discussion_body: '¿Cómo afrontáis como familia los reveses? ¿Qué os ayuda a ver el fracaso como parte del aprendizaje?',
        companion_quick: 'Los niños a los que se les permite equivocarse se convierten en adultos más valientes.',
        companion_reflect: '¿Hubo hoy un fracaso que tu hijo encajó bien? ¿Qué ayudó a lograrlo?',
      },
      inclusion_hochsensibel: {
        title: 'Entender y acompañar a los niños altamente sensibles',
        parent_lens: 'Alrededor del 20 % de los niños son altamente sensibles: perciben más, sienten con más intensidad y necesitan más tiempo de recuperación. No es una debilidad, sino un rasgo de personalidad con sus propias fortalezas.',
        parent_tips: [
          'Reduce la sobrecarga de estímulos: planifica momentos de transición tranquilos antes de las situaciones de mucha intensidad (compras, colegio, fiestas).',
          'La previsibilidad protege: anuncia lo que viene ("Nos vamos en 10 minutos"). Las sorpresas resultan estresantes para los niños altamente sensibles.',
          'Su sensibilidad es una fortaleza: se dan cuenta cuando alguien está triste y piensan en profundidad. Nómbralo en positivo.',
        ],
        practical_tip: 'Hoy planifica 15 minutos de "tiempo de recarga" en silencio para tu hijo tras una situación intensa: sin pantallas, sin expectativas.',
        discussion_body: '¿Reconocéis rasgos de alta sensibilidad en vuestro hijo? ¿Qué os ayuda a gestionarlo en el día a día?',
        companion_quick: 'Los niños altamente sensibles no necesitan endurecerse: necesitan espacios protegidos y comprensión.',
        companion_reflect: '¿Cuándo procesó hoy tu hijo especialmente muchas impresiones y cómo se recuperó después?',
      },
      inclusion_freundschaft: {
        title: 'Acompañar las amistades, no dirigirlas',
        parent_lens: 'Las amistades son el lugar más importante para aprender competencias sociales. Los niños aprenden a dar y recibir, a negociar y a renunciar, pero solo si como padres soltamos y acompañamos en lugar de dirigir.',
        parent_tips: [
          'Pregunta, pero no juzgues: "¿Cómo ha ido hoy con...?" es mejor que "No me cae bien, el otro día hizo..."',
          'Deja que los niños resuelvan primero los conflictos entre ellos; interviene solo cuando surja verdadera angustia.',
          'Favorece las amistades de forma activa: quedadas, invitaciones. Las oportunidades sociales no surgen solas.',
        ],
        practical_tip: 'Pregúntale hoy a tu hijo: "¿Quién de tu clase o grupo tiene los mismos gustos que tú?" y pensad juntos cómo crear tiempo para verse.',
        discussion_body: '¿Cómo dais a vuestros hijos espacio para sus propias amistades, aunque no siempre entendáis sus elecciones?',
        companion_quick: 'La amistad verdadera no se puede forzar, pero juntos podéis crear un terreno fértil para ella.',
        companion_reflect: '¿Habló hoy tu hijo de alguien importante para él? ¿Qué aprendiste de ello?',
      },
      inclusion_resilienz: {
        title: 'Resiliencia: cómo crecen los niños ante los desafíos',
        parent_lens: 'La resiliencia no es innata, se entrena. Los niños se vuelven resistentes cuando viven desafíos Y reciben apoyo en ellos. La clave no es la protección, sino el acompañamiento.',
        parent_tips: [
          'Deja que tu hijo complete los desafíos: no ayudes demasiado pronto. Ofrece ayuda solo cuando de verdad no pueda seguir.',
          'Fortalece el diálogo interno: "¿Qué crees que podrías hacer?" en lugar de darle la solución directamente.',
          'Habla de las crisis familiares de forma adecuada a la edad: los niños que quedan al margen desarrollan fantasías peores que la verdad.',
        ],
        practical_tip: 'Si tu hijo fracasa hoy: espera 30 segundos antes de intervenir. Muchas veces la solución llega sola.',
        discussion_body: '¿Qué desafío superó vuestro hijo y os sorprendió?',
        companion_quick: 'La resiliencia crece en el espacio entre el desafío y el apoyo, ni antes ni después.',
        companion_reflect: '¿En qué notáis que vuestro hijo ha crecido por dentro hoy?',
      },
      inclusion_vielfalt: {
        title: 'Vivir la diversidad: la diferencia como fortaleza',
        parent_lens: 'Los niños que aprenden pronto que las personas son distintas (en origen, capacidades, formas de pensar) desarrollan más empatía y menos miedo al contacto. Puedes dar vida a la diversidad en el día a día.',
        parent_tips: [
          'Habla con naturalidad de las diferencias; los niños las notan igualmente. "Sí, Lara tiene un color de piel distinto al tuyo, y su familia viene de..."',
          'Elige libros, películas y juegos con personajes diversos: la representación moldea la visión del mundo.',
          'Celebra las particularidades de la familia: "En nuestra casa es así, y en otras familias es distinto; eso es lo bonito."',
        ],
        practical_tip: 'Hoy lee un cuento con un personaje principal distinto a tu hijo y hablad de ello después.',
        discussion_body: '¿Cómo explicáis a los niños las diferencias entre las personas de un modo que despierte curiosidad en lugar de miedo?',
        companion_quick: 'Los niños sienten curiosidad natural por las diferencias; los prejuicios se aprenden después.',
        companion_reflect: '¿Hizo hoy tu hijo una pregunta sobre las diferencias que te hizo reflexionar?',
      },
      leadership_struktur: {
        title: 'La rutina diaria como ancla de seguridad',
        parent_lens: 'El cerebro de un niño adora la previsibilidad. Los rituales y las rutinas no son una limitación: son el andamio que da a los niños libertad para desarrollarse con seguridad.',
        parent_tips: [
          'Anclas fijas en el día: ritual al despertar, comidas y hora de dormir. Con estos tres hay estabilidad de verdad.',
          'Planifica rituales de transición: anuncia transiciones breves entre actividades. "En 5 minutos recogemos."',
          'La estructura no es estrés: cámbiala poco a poco si hace falta, no de forma brusca.',
        ],
        practical_tip: 'Hoy mira el plan del día junto a tu hijo y comentad qué viene. Eso reduce la resistencia y la inseguridad.',
        discussion_body: '¿Qué ritual diario es especialmente importante para vuestra familia, y por qué?',
        companion_quick: 'La previsibilidad crea seguridad. La seguridad crea ganas de aprender.',
        companion_reflect: '¿Qué momento de hoy mostró que tu hijo necesita estructura o que la disfrutó?',
      },
      leadership_schlaf: {
        title: 'Rituales de sueño: crear calma para el cuerpo y la mente',
        parent_lens: 'El sueño es tiempo de desarrollo, no una pausa. Durante el sueño, el cerebro procesa el día, consolida recuerdos y se regenera. Un buen ritual para dormir es una de las inversiones más eficaces en tu hijo.',
        parent_tips: [
          '30 minutos antes de dormir: nada de pantallas ni juegos emocionantes. Bajar el ritmo lleva su tiempo.',
          'Siempre el mismo orden: dientes, pijama, cuento, luz apagada. Los rituales le indican al cerebro: "Ahora toca dormir."',
          'Si tu hijo no logra dormirse: respirad juntos. 4 segundos al inhalar, 6 al exhalar; eso activa el sistema nervioso parasimpático.',
        ],
        practical_tip: 'Esta noche introduce un ritual de respiración de 3 minutos antes de dormir: inhalar, exhalar, juntos.',
        discussion_body: '¿Cuál es vuestro ritual favorito para dormir, y cómo lo fuisteis creando?',
        companion_quick: 'Un ritual de cierre tranquilo es la mejor entrada a un buen sueño.',
        companion_reflect: '¿Cómo fue hoy el momento de dormir? ¿Qué ayudó y qué molestó?',
      },
      leadership_bildschirm: {
        title: 'Dar forma al tiempo de pantalla de manera consciente',
        parent_lens: 'El problema no es el tiempo de pantalla en sí, sino el consumo pasivo y sin control, sin una conversación después. Con reglas sencillas, la pantalla se convierte en una actividad de ocio saludable.',
        parent_tips: [
          'Horarios fijos en vez de prohibiciones espontáneas: "Después de los deberes hasta las 17 h" es más claro que "no tanto".',
          'Ved juntos y hablad después: "¿Qué te ha gustado? ¿Qué te ha parecido raro o extraño?" refuerza la competencia mediática.',
          'Crea espacios sin pantallas: el dormitorio y la mesa de la comida son buenos límites para empezar.',
        ],
        practical_tip: 'Hoy ved algo juntos durante 15 minutos y, después, hazle 2 preguntas sobre ello. Eso cambia cómo tu hijo percibe los medios.',
        discussion_body: '¿Cómo gestionáis el tiempo de pantalla en casa? ¿Qué os ha funcionado y qué menos?',
        companion_quick: 'El uso consciente de los medios no se aprende con prohibiciones, sino con conversación.',
        companion_reflect: '¿Cómo usó hoy tu hijo los medios, de forma activa o pasiva? ¿Qué te llamó la atención?',
      },
      leadership_autoritaet: {
        title: 'Autoridad a través del vínculo, no del miedo',
        parent_lens: 'Tener autoridad no significa ser estricto y gritar. La verdadera autoridad parental surge cuando un niño sabe: "Me quieres Y eres claro." El vínculo y el liderazgo no se excluyen: se necesitan mutuamente.',
        parent_tips: [
          'Mensajes claros sin discusión: "Ahora lo hacemos así." Después no hay negociación, solo ofrecer comprensión.',
          'Las disculpas hacen a los adultos más fuertes, no más débiles. "Antes no fui justo contigo": los niños lo respetan.',
          'Elaborad algunas reglas juntos: eso aumenta la disposición a cumplirlas.',
        ],
        practical_tip: 'Hoy formula una regla como una indicación positiva en lugar de una prohibición: "Recogemos después de jugar" en vez de "No dejes las cosas tiradas".',
        discussion_body: '¿Cómo encontráis el equilibrio entre el liderazgo y la participación de vuestros hijos?',
        companion_quick: 'Autoridad sin vínculo es control. Vínculo sin autoridad es caos. Las dos cosas juntas son liderazgo.',
        companion_reflect: '¿Hubo hoy un momento en el que tu claridad tranquila logró más que una orden tajante?',
      },
      leadership_hausaufgaben: {
        title: 'Deberes sin estrés: un marco que funciona',
        parent_lens: 'El estrés con los deberes muchas veces no es un problema de aprendizaje, sino de rutina. Con la estructura y el momento adecuados, el tema se relaja solo.',
        parent_tips: [
          'Encuentra el momento adecuado: justo después del colegio o tras un breve descanso, pero antes de la noche.',
          'Estoy aquí, pero no ayudo de inmediato: primero que lo intente solo. Tras 10 minutos sin avanzar, pregunta: "¿Dónde te atascas?"',
          'Prepara el lugar de trabajo: un sitio fijo, la mesa ordenada y el móvil fuera de la vista; eso reduce las distracciones.',
        ],
        practical_tip: 'Hoy define junto a tu hijo EL momento de los deberes para la semana, y anotadlo.',
        discussion_body: '¿Qué os ha hecho los deberes menos estresantes? ¿Qué rutinas funcionan?',
        companion_quick: 'La estructura al estudiar no es una limitación: es el motor de la concentración.',
        companion_reflect: '¿Cómo fue hoy el estudio? ¿Qué podríais probar distinto mañana?',
      },
      leadership_selbstaendigkeit: {
        title: 'Autonomía: soltar también es amor',
        parent_lens: 'Los niños se vuelven autónomos cuando confiamos en ellos. Pero soltar se siente arriesgado, y eso es normal. El arte está en ir delegando más responsabilidad, paso a paso.',
        parent_tips: [
          'Asigna tareas adecuadas a la edad: los niños de 3 años recogen los juguetes, los de 6 ponen la mesa, los de 10 ayudan a cocinar.',
          'No intervengas cuando va despacio. Lento y por sí mismo vale más que rápido y con ayuda.',
          'Acepta los errores en las tareas autónomas: si se derrama el vaso de leche, no es un fracaso, es práctica.',
        ],
        practical_tip: 'Hoy dale a tu hijo una tarea nueva que hasta ahora hacías tú, y deja que la haga del todo por sí mismo.',
        discussion_body: '¿Cuál es el mayor logro de autonomía de vuestro hijo del que ambos os sentís orgullosos?',
        companion_quick: 'Cada tarea que el niño hace por sí mismo es una inversión en su futura confianza.',
        companion_reflect: '¿Cuándo soltasteis hoy, y cómo os sentisteis al hacerlo?',
      },
      leadership_natur: {
        title: 'Naturaleza y movimiento como ritual familiar',
        parent_lens: 'Los niños que salen al aire libre con regularidad duermen mejor, se concentran más y son más estables emocionalmente. La naturaleza no es un pasatiempo: es una necesidad básica.',
        parent_tips: [
          '15 minutos al aire libre al día ya tienen un efecto medible: no hace falta una excursión, hasta el camino al colegio cuenta.',
          'Moveos juntos: bici, paseo, campo de juego. Moverse en común refuerza el vínculo.',
          'Deja que tu hijo descubra la naturaleza: piedras, escarabajos, charcos. Sin programa, solo apertura.',
        ],
        practical_tip: 'Hoy planifica una vuelta de 15 minutos al aire libre: sin destino, sin programa, simplemente juntos.',
        discussion_body: '¿Qué vivencia en la naturaleza de vuestra infancia os gustaría transmitir a vuestros hijos?',
        companion_quick: 'Estar al aire libre es alimento para el cerebro, de niños y de adultos.',
        companion_reflect: '¿Cómo cambió el ánimo vuestro rato al aire libre de hoy?',
      },
      milestone_sprache: {
        title: 'Desarrollo del lenguaje: cómo fomentarlo jugando',
        parent_lens: 'El desarrollo del lenguaje no ocurre memorizando vocabulario: surge en el diálogo. Los niños aprenden a hablar cuando los adultos hablan con ellos, los escuchan y responden a lo que dicen.',
        parent_tips: [
          'Describe tu día a día en voz alta: "Ahora corto las zanahorias"; eso enriquece el vocabulario pasivo.',
          'Recoge lo que dice tu hijo y amplíalo: "¡Pelota!" → "Sí, la pelota roja rueda."',
          'Leed en voz alta a diario, aunque el niño ya sepa leer. Los textos de los libros tienen estructuras distintas al habla cotidiana.',
        ],
        practical_tip: 'Hoy lee en voz alta durante 10 minutos y pregunta mientras lees: "¿Qué crees que pasará ahora?"',
        discussion_body: '¿Qué palabras o frases de vuestro hijo os han sorprendido o conmovido últimamente?',
        companion_quick: 'El lenguaje crece en la conversación, no en el silencio.',
        companion_reflect: '¿Qué avance en el lenguaje de vuestro hijo notasteis hoy?',
      },
      milestone_schule: {
        title: 'Acompañar con calma el inicio escolar y las transiciones',
        parent_lens: 'Las transiciones (empezar el colegio, cambiar de clase, una nueva guardería) son las fases de aprendizaje más intensas para los niños. Tu calma y tu confianza se les transmiten. Tú eres su base de regulación.',
        parent_tips: [
          'Conoced antes los lugares nuevos: si es posible, visitad el aula o el colegio nuevos antes del primer día.',
          'Hablad de los sentimientos: "Está bien estar nervioso. Yo también lo estaba el primer día de cole."',
          'Los pequeños objetos de transición ayudan: una foto en la mochila, un recuerdo pequeño; los objetos dan seguridad.',
        ],
        practical_tip: 'Hoy pregúntale a tu hijo: "¿Qué te hace ilusión de...? ¿Qué te sigue preocupando?" y escucha sin juzgar.',
        discussion_body: '¿Cómo habéis acompañado una transición importante de vuestro hijo? ¿Qué ayudó?',
        companion_quick: 'Las transiciones son final y principio a la vez, y ambos se pueden sentir.',
        companion_reflect: '¿Qué emoción mostró hoy tu hijo en torno a una transición?',
      },
      milestone_sozial: {
        title: 'Inteligencia social: la competencia más importante del siglo XXI',
        parent_lens: 'El CI abre puertas. La IE (inteligencia emocional) hace que la gente te deje entrar. Los niños con alta competencia social cooperan, comunican y se ponen mejor en el lugar del otro, y eso lo aprenden contigo.',
        parent_tips: [
          'Modela la empatía a diario: "El gato parece triste. ¿Por qué crees que será?"',
          'Practica el cambio de perspectiva: "¿Cómo crees que se sintió... cuando dijiste eso?"',
          'Reconoce el comportamiento social de forma explícita: "Esperaste a que terminara de hablar. Eso fue muy respetuoso."',
        ],
        practical_tip: 'Hoy, al salir de la guardería o del colegio, hablad de una situación social: "¿Alguien ha hecho algo bonito hoy?"',
        discussion_body: '¿Qué aspecto de la competencia social os parece hoy más importante, para niños y adultos?',
        companion_quick: 'La competencia social no es un talento: es una habilidad que se practica.',
        companion_reflect: '¿Cuándo mostró hoy tu hijo empatía, aunque quizá pasara desapercibido?',
      },
      milestone_emotion: {
        title: 'Madurez emocional: cuando los sentimientos se procesan',
        parent_lens: 'La madurez emocional no consiste en no tener sentimientos, sino en procesarlos. Los niños a los que se les permite expresar sus sentimientos aprenden, a la larga, a manejarlos mejor.',
        parent_tips: [
          'Todos los sentimientos están permitidos, no todas las acciones. "Puedes estar enfadado. No puedes pegar."',
          'No quites importancia a los sentimientos: en vez de "No es para tanto" → "Veo que esto te afecta de verdad."',
          'Deja que las emociones se sientan en el cuerpo: "¿Dónde lo notas ahora? ¿En la tripa? ¿En el pecho?"',
        ],
        practical_tip: 'Hoy pregunta: "¿Cómo se siente eso en tu cuerpo?" y acepta cualquier respuesta.',
        discussion_body: '¿Qué sentimiento os cuesta más mostrar abiertamente en vuestra familia?',
        companion_quick: 'Permitir los sentimientos no es debilidad: es fortaleza emocional.',
        companion_reflect: '¿Qué emoción mostró hoy tu hijo abiertamente, y cómo la acompañasteis juntos?',
      },
      milestone_kreativitaet: {
        title: 'Fomentar la creatividad, sin fijarse en el resultado',
        parent_lens: 'La creatividad es la capacidad de resolver problemas disfrazada. Cuando los niños pintan, construyen, hacen manualidades o juegan, entrenan la flexibilidad y la originalidad: las competencias del futuro.',
        parent_tips: [
          'Sin fijarse en el producto final: "Cuéntame qué has hecho" en lugar de "¿Y eso qué se supone que es?"',
          'Ofrece materiales sin instrucciones: tela, cartón, materiales naturales, y luego suelta.',
          'Sé creativo tú mismo: cuando los padres pintan, construyen o cantan, sin perfección, permiten a sus hijos hacer lo mismo.',
        ],
        practical_tip: 'Hoy ofrece 20 minutos de manualidades libres: sin plantilla, sin instrucciones, solo materiales.',
        discussion_body: '¿Cuál es el proyecto más creativo que vuestro hijo ha ideado por sí mismo?',
        companion_quick: 'La creatividad necesita espacio, tiempo y un adulto que no juzgue.',
        companion_reflect: '¿Qué inventó, construyó o imaginó hoy tu hijo que te sorprendió?',
      },
      milestone_koerper: {
        title: 'Fortalecer la percepción del cuerpo: el movimiento como motor del desarrollo',
        parent_lens: 'El desarrollo motor y el cognitivo están unidos de forma inseparable. Los niños que trepan, se equilibran y bailan también desarrollan su pensamiento espacial y su concentración.',
        parent_tips: [
          'Integra el movimiento a diario: no como un programa deportivo, sino como parte de la vida: escaleras en vez de ascensor, caminar en vez de llevar en brazos.',
          'Alterna la motricidad gruesa y la fina: construir (fina) y trepar (gruesa) se complementan de maravilla.',
          'Refuerza en positivo la imagen corporal: "Tu cuerpo puede hacer muchísimo", al margen del aspecto o del rendimiento.',
        ],
        practical_tip: 'Hoy planifica 10 minutos de juego de movimiento: equilibrios, saltos, rodar. Sin programa, solo cuerpo y diversión.',
        discussion_body: '¿Qué actividad de movimiento le da más alegría a vuestro hijo, y por qué?',
        companion_quick: 'El movimiento no es un pasatiempo: es un motor para aprender.',
        companion_reflect: '¿Qué probó o se atrevió a hacer hoy tu hijo con su cuerpo que era nuevo?',
      },
      milestone_uebergaenge: {
        title: 'Preparar la pubertad: con antelación y con calma',
        parent_lens: 'La pubertad empieza antes de lo que piensan la mayoría de los padres, y las bases se sientan en la infancia. Una comunicación abierta y una relación segura entre padres e hijos son la mejor preparación.',
        parent_tips: [
          'Habla pronto de los cambios del cuerpo, con naturalidad y sin dramatismo. Los niños informados tienen menos miedo.',
          'Comparte recuerdos propios de la pubertad (de forma adecuada): "Yo también me sentía inseguro con..."; eso lo normaliza.',
          'Crea espacios de intimidad: llamar a la puerta, respetar los diarios. La confianza nace del respeto.',
        ],
        practical_tip: 'Hoy mira junto a tu hijo (de forma adecuada a su edad) un vídeo o un libro sobre los procesos del cuerpo, sin reparos.',
        discussion_body: 'Mirando atrás, ¿qué os importó durante la pubertad, y qué os habría gustado que hubieran hecho vuestros padres?',
        companion_quick: 'La mejor preparación para la pubertad es una relación fuerte hoy.',
        companion_reflect: '¿Hizo hoy tu hijo una pregunta que muestre que empieza a reflexionar sobre sí mismo?',
      },
      gfk_wiedergutmachung: {
        title: 'Cuando los padres pierden los nervios: reparar como fortaleza',
        parent_lens: 'Ningún padre o madre es paciente siempre. Cuando pierdes los nervios, no es un fracaso como madre o padre: es un momento humano. Pero lo que viene después moldea la relación con más fuerza que el propio estallido.',
        parent_tips: [
          'Reparar necesita tres pasos: asumir la responsabilidad ("Me equivoqué"), mostrar compasión y, si hace falta, hacerlo de otra manera.',
          'Disculpas sin "pero": "Siento haber gritado así. No estuvo bien.", y punto.',
          'Tu hijo te ve como una persona, y eso es bueno. A través de la reparación, los niños aprenden que las relaciones resisten las tormentas.',
        ],
        practical_tip: 'Si hoy no te comportaste bien en alguna situación: vuelve con tu hijo y díselo. Con tres frases basta.',
        discussion_body: '¿Cómo habéis aprendido como padres a manejar vuestros propios estallidos, sin juzgaros con demasiada dureza?',
        companion_quick: 'Reparar enseña a los niños algo que ningún manual puede: que las relaciones se pueden reparar.',
        companion_reflect: '¿Hubo hoy un momento que, visto en perspectiva, habrías hecho de otra manera, y qué sacaste de ello?',
      },
    },
    it: {
      gfk_warum: {
        title: 'Accompagnare con serenità le domande sul perché',
        parent_lens: 'Tuo figlio ti chiede \'perché?\' cento volte al giorno. Non lo fa per darti fastidio, ma perché il suo cervello sta costruendo collegamenti. Vuole capire il mondo.',
        parent_tips: [
          'Usa la comunicazione nonviolenta (CNV): dai un nome ai tuoi sentimenti e bisogni in modo chiaro, invece di sgridare.',
          'Rispondi alle domande sul perché in modo breve e semplice: tuo figlio cerca una logica, non una lezione scientifica.',
          'Metti i limiti con amore attraverso la tua presenza personale (\'Non voglio che tu picchi\'), non con le punizioni.',
        ],
        practical_tip: 'Alla prossima domanda sul perché: rispecchia prima il sentimento (\'Sei curioso!\'), poi rispondi con una sola frase.',
        discussion_body: 'Quale frase breve e tranquilla vi aiuta quando vostro figlio chiede \'perché\' per la decima volta?',
        companion_quick: 'Oggi scegli una sola risposta tranquilla a una domanda sul perché e dopo resta volutamente breve.',
        companion_reflect: 'Quando oggi tuo figlio ha cercato più collegamenti, e come sei riuscito a dare orientamento con calma?',
      },
      gfk_grenzen: {
        title: 'Mettere limiti con amore e chiarezza',
        parent_lens: 'I limiti amorevoli non sono una contraddizione. I bambini hanno bisogno di entrambe le cose: sentirsi amati E avere un orientamento chiaro su ciò che non va. I limiti senza relazione sembrano muri; i limiti con relazione sono come guardrail.',
        parent_tips: [
          'Nomina prima il sentimento di tuo figlio, poi il limite: \'Vedo che sei arrabbiato. E comunque: picchiare non si fa.\'',
          'Resta fisicamente calmo: il tuo tono parla più forte delle parole. Un respiro profondo prima di reagire aiuta.',
          'Annuncia le conseguenze e mantienile. Non minacciare, ma preannuncia: \'Se tu... allora...\'',
        ],
        practical_tip: 'Oggi esercitati con una frase che unisce sentimento e limite: \'Capisco che lo desideri. E: no.\' — restando calmo mentre la dici.',
        discussion_body: 'Come reagite quando siete voi a raggiungere i vostri limiti? Quale frase vi aiuta a restare calmi?',
        companion_quick: 'Un respiro profondo prima della prossima reazione di fronte a un limite: è già metà del lavoro.',
        companion_reflect: 'Oggi c\'è stata una situazione in cui un limite posto con calma ha funzionato meglio di un no urlato?',
      },
      gfk_ichbotschaft: {
        title: 'Messaggi in prima persona invece di accuse in seconda',
        parent_lens: 'I messaggi del tipo \'Tu sei...\' (\'Sei così rumoroso!\') scatenano difesa. I messaggi in prima persona (\'Mi sto stancando e ho bisogno di quiete\') aprono le porte. I bambini ascoltano di più quando non si sentono attaccati.',
        parent_tips: [
          'Trasforma le accuse in messaggi in prima persona: invece di \'Non ascolti mai\' → \'Non mi sento ascoltato e questo mi rattrista.\'',
          'Condividi il tuo bisogno: \'Ora ho bisogno di un momento di silenzio per riflettere.\' I bambini capiscono i bisogni sorprendentemente bene.',
          'Esercitati nella vita quotidiana: riformula tre frasi classiche come messaggi in prima persona — la mattina mentre lavate i denti, a pranzo, la sera prima di dormire.',
        ],
        practical_tip: 'Oggi scegli una situazione in cui di solito diresti \'Tu sempre...\' e sostituiscila con \'Io provo... perché ho bisogno di...\'',
        discussion_body: 'Quale messaggio in seconda persona vi è più difficile riformulare? E cosa vi aiuta a farlo?',
        companion_quick: 'Nomina il sentimento e il bisogno: è questa la formula di un vero messaggio in prima persona.',
        companion_reflect: 'Oggi un messaggio in prima persona ha scatenato una reazione che ti ha sorpreso?',
      },
      gfk_trotz: {
        title: 'Accompagnare con serenità le fasi di opposizione',
        parent_lens: 'L\'opposizione non è ribellione, è sviluppo. Quando un bambino si butta a terra e urla, la sua corteccia prefrontale semplicemente non è ancora abbastanza matura da regolare l\'emozione. Ha bisogno di te come sostegno alla coregolazione.',
        parent_tips: [
          'Resta fisicamente vicino senza forzare: mettiti alla sua altezza, parla con calma, non toccarlo se il bambino lo rifiuta.',
          'Evita le discussioni nel pieno della tempesta. Il dialogo arriva solo quando si è calmato.',
          'Usa i \'ponti del sentimento\': \'Volevi il gelato. Era davvero importante per te. Lo capisco.\'',
        ],
        practical_tip: 'Quando tuo figlio è fuori di sé: siediti accanto a lui. Non andartene, non intervenire, basta esserci. Questo già aiuta a regolare.',
        discussion_body: 'Cosa aiuta voi stessi a restare calmi quando vostro figlio è nel pieno di uno scoppio emotivo?',
        companion_quick: 'Tre parole per le fasi di opposizione: resta vicino, respira con calma, aspetta.',
        companion_reflect: 'Cosa ti ha richiesto più energia oggi, e cosa ti ha aiutato a restare sereno?',
      },
      gfk_geschwister: {
        title: 'Usare i litigi tra fratelli come terreno di apprendimento',
        parent_lens: 'I fratelli litigano: è normale e perfino importante. Litigando i bambini imparano il compromesso, il cambio di prospettiva e l\'autoaffermazione. Il tuo ruolo è quello del mediatore, non del giudice.',
        parent_tips: [
          'Non prendere le parti: \'Vedo che siete arrabbiati tutti e due. Ascolto prima te, poi te.\'',
          'Lascia che i bambini trovino da soli le soluzioni, se la situazione non degenera. Intervieni solo in caso di pericolo.',
          'Rafforza ogni bambino singolarmente: momenti regolari uno-a-uno senza i fratelli riducono la gelosia nel lungo periodo.',
        ],
        practical_tip: 'Al prossimo litigio: chiedi a entrambi i bambini \'Di cosa hai bisogno adesso?\' — prima di decidere chi ha ragione.',
        discussion_body: 'Come gestite i litigi tra fratelli? Cosa funziona meglio per voi?',
        companion_quick: 'Mediatore invece di giudice: è questo il tuo ruolo nei conflitti tra fratelli.',
        companion_reflect: 'Oggi c\'è stato un momento in cui i tuoi figli hanno risolto un litigio da soli? Cosa avete imparato?',
      },
      gfk_gefühle: {
        title: 'Dare un nome ai sentimenti e riconoscerli',
        parent_lens: 'I bambini capaci di nominare i propri sentimenti hanno un enorme vantaggio: sanno comunicare di cosa hanno bisogno. Questo passaggio, dal sentire al dire, richiede pratica e il tuo sostegno.',
        parent_tips: [
          'Usa il \'barometro dei sentimenti\': la sera chiedi \'Com\'è stata la tua giornata, da 1 a 5?\' — e raccontati tu per primo.',
          'Nomina ad alta voce i tuoi sentimenti: \'Adesso sono un po\' stressato perché ho molte cose a cui pensare.\' L\'apprendimento per modello funziona.',
          'Leggete libri per bambini sui sentimenti, e poi fermatevi: \'Cosa avrà provato il personaggio? E tu?\'',
        ],
        practical_tip: 'Stasera fai questa domanda: \'Cosa ti ha reso felice oggi? Cosa ti ha reso triste o arrabbiato?\' — e ascolta e basta.',
        discussion_body: 'Quale sentimento è particolarmente difficile da nominare per vostro figlio? Come lo affrontate?',
        companion_quick: 'Prima sentire, poi nominare: l\'abbecedario dei sentimenti comincia da te come modello.',
        companion_reflect: 'Quale momento emotivo di tuo figlio avresti voluto trattenere oggi?',
      },
      gfk_nein: {
        title: 'Dire di no, senza sensi di colpa',
        parent_lens: 'I genitori che non dicono mai di no crescono bambini che non conoscono i limiti. Un no amorevole mostra a tuo figlio: prendo sul serio i miei bisogni, e puoi farlo anche tu.',
        parent_tips: [
          'Un no non ha bisogno di una lunga spiegazione. Un chiaro \'No, adesso non si può\' è completo.',
          'Il senso di colpa dopo un no è un segnale, non un errore. Chiediti: questo no è davvero sbagliato, o solo scomodo?',
          'Esercitati a dire di no anche agli altri adulti (appuntamenti di gioco, impegni): tuo figlio impara dal tuo esempio.',
        ],
        practical_tip: 'Oggi di\' di no una volta in modo consapevole, senza scusarti. Senti come ti fa stare.',
        discussion_body: 'Quando vi è più difficile dire di no: ai vostri figli o agli altri?',
        companion_quick: 'Un no a una cosa è un sì a qualcosa di più importante, di solito a te stesso.',
        companion_reflect: 'Oggi c\'è stato un no che, ripensandoci, ti è sembrato giusto?',
      },
      inclusion_stärken: {
        title: 'Vedere i punti di forza invece di giudicare le debolezze',
        parent_lens: 'Ogni bambino ha una costellazione di punti di forza unica. Spesso come genitori vediamo prima le lacune, eppure saremmo i primi a poter lucidare quel diamante grezzo.',
        parent_tips: [
          'Stasera scrivi 3 punti di forza di tuo figlio: non risultati, ma tratti del carattere (\'curioso\', \'premuroso\', \'tenace\').',
          'Nomina i punti di forza in modo concreto e tempestivo: \'Sei stato così paziente poco fa, è davvero bello.\'',
          'Evita i confronti con i fratelli o con altri bambini. Ogni curva di sviluppo è unica.',
        ],
        practical_tip: 'Oggi parla con tuo figlio di uno dei suoi punti di forza, non come un elogio ma come un\'osservazione: \'Oggi ho visto come tu...\'',
        discussion_body: 'Quale punto di forza nascosto di vostro figlio vorreste condividere oggi?',
        companion_quick: 'Vedere i punti di forza non significa ignorare le debolezze: significa rendere possibile la crescita.',
        companion_reflect: 'Quale punto di forza di tuo figlio ti ha sorpreso o colpito oggi?',
      },
      inclusion_selbstwert: {
        title: 'Costruire l\'autostima ogni giorno',
        parent_lens: 'L\'autostima non nasce solo dagli elogi: nasce dall\'esperienza di \'So fare qualcosa. Sono importante. Faccio parte di qualcosa.\' Puoi inserire tutte e tre queste esperienze ogni giorno.',
        parent_tips: [
          'Lascia che tuo figlio prenda piccole decisioni: \'Vuoi fare prima i compiti o giocare prima?\' Autonomia uguale autostima.',
          'Mostra un interesse autentico: metti via il telefono, guardalo in faccia, fai domande. 10 minuti di piena attenzione fanno miracoli.',
          'Festeggia il processo, non solo il risultato: \'Hai provato per così tanto tempo, è questa la parte importante.\'',
        ],
        practical_tip: 'Oggi: 10 minuti di attenzione tutta per tuo figlio — niente telefono, nessuna distrazione, solo interesse.',
        discussion_body: 'Cosa rende vostro figlio particolarmente orgoglioso di sé, e come sostenete questo sentimento?',
        companion_quick: 'L\'autostima non viene dallo specchio, ma dagli occhi delle persone che ci amano.',
        companion_reflect: 'In quale momento oggi tuo figlio ha mostrato \'Io ce la faccio!\'?',
      },
      inclusion_scheitern: {
        title: 'Vedere il fallimento come occasione di apprendimento',
        parent_lens: 'Il cervello impara di più dagli errori che dai successi. Quando tuo figlio fallisce e tu resti calmo, gli dai il segnale più forte: \'Fallire è sicuro. Io reggo questa cosa.\'',
        parent_tips: [
          'Di fronte a un fallimento, prima la compassione, poi la soluzione: \'È stato frustrante. Cosa potremmo fare diversamente la prossima volta?\'',
          'Racconta i tuoi fallimenti: \'Anche a me è successo di... e poi ho imparato...\' L\'apprendimento per modello sdrammatizza.',
          'Evita il \'Te l\'avevo detto\'. Chiude le porte. Piuttosto: \'Cosa ne hai ricavato?\'',
        ],
        practical_tip: 'Oggi racconta a tuo figlio un tuo fallimento, e cosa ne hai imparato.',
        discussion_body: 'Come affrontate le sconfitte come famiglia? Cosa vi aiuta a vedere il fallimento come parte dell\'apprendimento?',
        companion_quick: 'I bambini a cui è permesso sbagliare diventano adulti più coraggiosi.',
        companion_reflect: 'Oggi c\'è stato un fallimento che tuo figlio ha gestito bene? Cosa lo ha aiutato?',
      },
      inclusion_hochsensibel: {
        title: 'Capire e accompagnare i bambini altamente sensibili',
        parent_lens: 'Circa il 20% dei bambini è altamente sensibile: percepisce di più, sente in modo più intenso e ha bisogno di più tempo per recuperare. Non è una debolezza, ma un tratto della personalità con punti di forza propri.',
        parent_tips: [
          'Riduci il sovraccarico di stimoli: prevedi momenti di transizione tranquilli prima delle situazioni ad alta intensità (spesa, scuola, feste).',
          'La prevedibilità protegge: annuncia ciò che arriva (\'Tra 10 minuti andiamo via\'). Le sorprese sono stressanti per i bambini altamente sensibili.',
          'La loro sensibilità è un punto di forza: notano quando qualcuno è triste e riflettono in profondità. Nominalo in modo positivo.',
        ],
        practical_tip: 'Oggi prevedi 15 minuti di \'tempo per ricaricarsi\' in silenzio per tuo figlio dopo una situazione ad alta intensità — senza schermo, senza aspettative.',
        discussion_body: 'Riconoscete tratti di alta sensibilità in vostro figlio? Cosa vi aiuta a gestirli nella quotidianità?',
        companion_quick: 'I bambini altamente sensibili non hanno bisogno di essere induriti: hanno bisogno di spazi protetti e di comprensione.',
        companion_reflect: 'Quando oggi tuo figlio ha elaborato particolarmente tante impressioni, e come si è ripreso dopo?',
      },
      inclusion_freundschaft: {
        title: 'Accompagnare le amicizie, non guidarle',
        parent_lens: 'Le amicizie sono il luogo più importante per imparare le competenze sociali. I bambini imparano a dare e ricevere, a negoziare e a rinunciare, ma solo se noi genitori lasciamo andare e accompagniamo invece di guidare.',
        parent_tips: [
          'Chiedi, ma non giudicare: \'Com\'è andata oggi con...?\' è meglio di \'Quello non mi piace, l\'altro giorno ha...\'',
          'Lascia che i bambini risolvano da soli i conflitti all\'inizio, intervieni solo quando nasce un vero disagio.',
          'Favorisci attivamente le amicizie: appuntamenti di gioco, inviti. Le occasioni sociali non nascono da sole.',
        ],
        practical_tip: 'Oggi chiedi a tuo figlio: \'Chi nella tua classe o nel tuo gruppo ama le stesse cose che ami tu?\' — e pensate insieme a come trovare il tempo per stare insieme.',
        discussion_body: 'Come date ai vostri figli lo spazio per le proprie amicizie, anche quando non capite sempre le loro scelte?',
        companion_quick: 'Una vera amicizia non si può imporre, ma insieme potete creare un terreno fertile.',
        companion_reflect: 'Oggi tuo figlio ha parlato di qualcuno che è importante per lui? Cosa ne hai imparato?',
      },
      inclusion_resilienz: {
        title: 'Resilienza: come i bambini crescono di fronte alle sfide',
        parent_lens: 'La resilienza non è innata, si allena. I bambini diventano resistenti quando vivono delle sfide E vengono sostenuti nel farlo. Non la protezione, ma l\'accompagnamento è la chiave.',
        parent_tips: [
          'Lascia che tuo figlio porti a termine le sfide: non aiutarlo troppo presto. Offri aiuto solo quando davvero non riesce ad andare avanti.',
          'Rafforza il dialogo interiore: \'Cosa pensi di poter fare?\' invece di dare subito la soluzione.',
          'Parla delle crisi in famiglia in modo adatto all\'età: i bambini tenuti all\'oscuro sviluppano fantasie peggiori della verità.',
        ],
        practical_tip: 'Se oggi tuo figlio fallisce: aspetta 30 secondi prima di intervenire. Spesso la soluzione arriva da sola.',
        discussion_body: 'Quale sfida ha superato vostro figlio sorprendendovi?',
        companion_quick: 'La resilienza cresce nello spazio tra la sfida e il sostegno: non prima e non dopo.',
        companion_reflect: 'Da cosa capite che oggi vostro figlio è cresciuto interiormente?',
      },
      inclusion_vielfalt: {
        title: 'Vivere la diversità: la differenza come punto di forza',
        parent_lens: 'I bambini che imparano presto che le persone sono diverse — per origine, capacità, modo di pensare — sviluppano più empatia e meno timore del contatto. Puoi rendere viva la diversità nella quotidianità.',
        parent_tips: [
          'Parla apertamente delle differenze: i bambini le notano comunque. \'Sì, Lara ha un colore della pelle diverso dal tuo, e la sua famiglia viene da...\'',
          'Scegli libri, film e giochi con personaggi diversi tra loro: la rappresentazione influenza la visione del mondo.',
          'Festeggia le particolarità della vostra famiglia: \'Da noi è così, in altre famiglie è diverso, ed è questa la cosa bella.\'',
        ],
        practical_tip: 'Oggi leggi un libro per bambini con un protagonista diverso da tuo figlio, e poi parlatene insieme.',
        discussion_body: 'Come spiegate ai bambini le differenze tra le persone in un modo che susciti curiosità invece di paura?',
        companion_quick: 'I bambini sono per natura curiosi verso le differenze: i pregiudizi li imparano dopo.',
        companion_reflect: 'Oggi tuo figlio ha fatto una domanda sulle differenze che ti ha fatto riflettere?',
      },
      leadership_struktur: {
        title: 'La struttura della giornata come àncora di sicurezza',
        parent_lens: 'Il cervello di un bambino ama la prevedibilità. Rituali e strutture non sono una restrizione: sono l\'impalcatura che dà ai bambini la libertà di crescere in sicurezza.',
        parent_tips: [
          'Àncore fisse nella giornata: il rituale del risveglio, i pasti, l\'ora di andare a letto. Questi tre bastano per una vera stabilità.',
          'Prevedi rituali di transizione: annuncia brevi passaggi tra un\'attività e l\'altra. \'Tra 5 minuti mettiamo in ordine.\'',
          'La struttura non è stress: cambiala gradualmente se serve, non all\'improvviso.',
        ],
        practical_tip: 'Oggi guarda insieme a tuo figlio il programma della giornata, parlate di ciò che arriva. Questo riduce la resistenza e l\'incertezza.',
        discussion_body: 'Quale rituale quotidiano è particolarmente importante per la vostra famiglia, e perché?',
        companion_quick: 'La prevedibilità crea sicurezza. La sicurezza crea voglia di imparare.',
        companion_reflect: 'Quale momento oggi ha mostrato che tuo figlio ha bisogno di struttura, o che l\'ha apprezzata?',
      },
      leadership_schlaf: {
        title: 'Rituali del sonno: creare calma per corpo e mente',
        parent_lens: 'Il sonno è tempo di sviluppo, non una pausa. Durante il sonno il cervello elabora la giornata, consolida i ricordi e si rigenera. Un buon rituale per addormentarsi è uno degli investimenti più efficaci per tuo figlio.',
        parent_tips: [
          '30 minuti prima di dormire: niente schermi, niente giochi eccitanti. Calmarsi richiede tempo.',
          'Sempre lo stesso ordine: denti, pigiama, storia, luce spenta. I rituali segnalano al cervello: \'Ora arriva il sonno.\'',
          'Se tuo figlio non riesce ad addormentarsi: respirate insieme. 4 secondi inspirando, 6 secondi espirando — questo attiva il sistema nervoso parasimpatico.',
        ],
        practical_tip: 'Stasera introduci un rituale di respirazione di 3 minuti prima di dormire — inspirare, espirare, insieme.',
        discussion_body: 'Qual è il vostro rituale preferito per addormentarvi, e come l\'avete sviluppato?',
        companion_quick: 'Un rituale di chiusura tranquillo è il miglior inizio per un buon sonno.',
        companion_reflect: 'Com\'è stato l\'addormentamento oggi? Cosa ha aiutato e cosa ha disturbato?',
      },
      leadership_bildschirm: {
        title: 'Gestire con consapevolezza il tempo davanti allo schermo',
        parent_lens: 'Non è il tempo davanti allo schermo in sé il problema: è il consumo passivo e incontrollato senza una conversazione dopo. Con regole semplici, lo schermo diventa un\'attività del tempo libero sana.',
        parent_tips: [
          'Orari fissi invece di divieti improvvisi: \'Dopo i compiti fino alle 17\' è più chiaro di \'non troppo\'.',
          'Guardate insieme e poi parlatene: \'Cosa ti è piaciuto? Cosa era strano o buffo?\' rafforza la competenza mediatica.',
          'Create spazi senza schermi: la camera da letto e il tavolo da pranzo sono buoni limiti per iniziare.',
        ],
        practical_tip: 'Oggi guardate qualcosa insieme per 15 minuti, e poi fai 2 domande al riguardo. Questo cambia il modo in cui tuo figlio percepisce i media.',
        discussion_body: 'Come gestite il tempo davanti allo schermo a casa vostra? Cosa ha funzionato e cosa meno?',
        companion_quick: 'L\'uso consapevole dei media non si impara con i divieti, ma con il dialogo.',
        companion_reflect: 'Come ha usato i media oggi tuo figlio, in modo attivo o passivo? Cosa hai notato?',
      },
      leadership_autoritaet: {
        title: 'Autorevolezza attraverso la relazione, non attraverso la paura',
        parent_lens: 'Autorevole non significa urlare ed essere severi. La vera autorevolezza genitoriale nasce quando un bambino sa: \'Mi vuoi bene E sei chiaro.\' Relazione e guida non si escludono: si sostengono a vicenda.',
        parent_tips: [
          'Indicazioni chiare senza discussione: \'Adesso facciamo così.\' Dopo non si negozia — si offre solo comprensione.',
          'Le scuse rendono gli adulti più forti, non più deboli. \'Prima non sono stato giusto con te\' — i bambini lo rispettano.',
          'Elaborate insieme alcune regole: questo aumenta la disponibilità a rispettarle.',
        ],
        practical_tip: 'Oggi formula una regola come indicazione positiva invece che come divieto: \'Dopo aver giocato mettiamo in ordine\' invece di \'Non lasciare le cose in giro\'.',
        discussion_body: 'Come trovate l\'equilibrio tra la guida e il diritto di parola dei vostri figli?',
        companion_quick: 'Autorevolezza senza relazione è controllo. Relazione senza autorevolezza è caos. Le due cose insieme sono guida.',
        companion_reflect: 'Oggi c\'è stato un momento in cui la tua calma chiarezza ha ottenuto più di un\'imposizione?',
      },
      leadership_hausaufgaben: {
        title: 'Compiti senza stress: una cornice che funziona',
        parent_lens: 'Lo stress da compiti spesso non è un problema di apprendimento: è un problema di rituale. Con la struttura giusta e il momento giusto, la questione si distende da sola.',
        parent_tips: [
          'Trova il momento giusto: subito dopo la scuola o dopo una breve pausa di recupero, ma prima della sera.',
          'Io ci sono, ma non aiuto subito: prima prova da solo. Dopo 10 minuti senza progressi: chiedi \'Dove ti sei bloccato?\'',
          'Prepara la postazione: un posto fisso, una scrivania in ordine, nessun telefono in vista — questo riduce le distrazioni.',
        ],
        practical_tip: 'Oggi definisci insieme a tuo figlio QUEL momento dei compiti per la settimana, e scrivetelo.',
        discussion_body: 'Cosa ha reso i compiti meno stressanti per voi? Quali routine funzionano?',
        companion_quick: 'La struttura nello studio non è una restrizione: è il motore della concentrazione.',
        companion_reflect: 'Com\'è andato lo studio oggi? Cosa potreste provare in modo diverso domani?',
      },
      leadership_selbstaendigkeit: {
        title: 'Autonomia: lasciar andare è anche amore',
        parent_lens: 'I bambini diventano autonomi quando ci fidiamo di loro. Ma lasciar andare sembra rischioso, ed è normale. L\'arte sta nell\'affidare più responsabilità un passo alla volta.',
        parent_tips: [
          'Affida compiti adatti all\'età: i bambini di 3 anni riordinano i giochi, quelli di 6 apparecchiano, quelli di 10 cucinano con te.',
          'Non intervenire quando va lentamente. Lento e da solo vale più di veloce e con aiuto.',
          'Accetta gli errori nei compiti svolti in autonomia: il bicchiere di latte si rovescia — non è un fallimento, è esercizio.',
        ],
        practical_tip: 'Oggi affida a tuo figlio un compito nuovo che finora hai sempre fatto tu, e lascia che lo faccia tutto da solo.',
        discussion_body: 'Qual è la più grande conquista di autonomia di vostro figlio di cui siete entrambi orgogliosi?',
        companion_quick: 'Ogni compito che il bambino svolge da solo è un investimento nella sua futura fiducia in sé.',
        companion_reflect: 'Quando avete lasciato andare oggi, e come vi è sembrato?',
      },
      leadership_natur: {
        title: 'Natura e movimento come rituale di famiglia',
        parent_lens: 'I bambini che stanno regolarmente all\'aperto dormono meglio, sono più concentrati e più stabili emotivamente. La natura non è un passatempo: è un bisogno fondamentale.',
        parent_tips: [
          '15 minuti al giorno all\'aperto hanno già un effetto misurabile — non serve una gita, conta anche il tragitto verso scuola.',
          'Muovetevi insieme: bicicletta, passeggiata, campetto. Muoversi insieme rafforza il legame.',
          'Lascia che tuo figlio scopra la natura: sassi, insetti, pozzanghere. Nessun programma, solo apertura.',
        ],
        practical_tip: 'Oggi prevedi un giro di 15 minuti all\'aperto — senza meta, senza programma, semplicemente insieme.',
        discussion_body: 'Quale esperienza nella natura della vostra infanzia vorreste trasmettere ai vostri figli?',
        companion_quick: 'Stare all\'aperto è nutrimento per il cervello, per i bambini e per gli adulti.',
        companion_reflect: 'Come ha cambiato l\'umore oggi il vostro tempo all\'aperto?',
      },
      milestone_sprache: {
        title: 'Sviluppo del linguaggio: come favorirlo giocando',
        parent_lens: 'Lo sviluppo del linguaggio non avviene con l\'esercizio dei vocaboli: nasce nel dialogo. I bambini imparano a parlare quando gli adulti parlano con loro, li ascoltano e rispondono a ciò che dicono.',
        parent_tips: [
          'Descrivi ad alta voce la tua quotidianità: \'Adesso taglio le carote\' — questo arricchisce il vocabolario passivo.',
          'Riprendi le affermazioni di tuo figlio e ampliale: \'Palla!\' — \'Sì, la palla rossa rotola.\'',
          'Leggete ad alta voce ogni giorno, anche quando il bambino sa già leggere. I testi dei libri hanno strutture diverse dal linguaggio quotidiano.',
        ],
        practical_tip: 'Oggi leggi ad alta voce per 10 minuti, e durante la lettura chiedi: \'Secondo te cosa succede adesso?\'',
        discussion_body: 'Quali parole o frasi di vostro figlio vi hanno sorpreso o commosso di recente?',
        companion_quick: 'Il linguaggio cresce nella conversazione, non nel silenzio.',
        companion_reflect: 'Quale progresso linguistico di vostro figlio avete notato oggi?',
      },
      milestone_schule: {
        title: 'Accompagnare con serenità l\'inizio della scuola e i passaggi',
        parent_lens: 'I passaggi — l\'inizio della scuola, il cambio di classe, un nuovo asilo — sono per i bambini le fasi di apprendimento più intense. La tua calma e la tua fiducia si trasmettono a tuo figlio. Tu sei la base della regolazione.',
        parent_tips: [
          'Conoscere prima i nuovi luoghi: se possibile, visitate la nuova aula o la scuola prima del primo giorno.',
          'Parlate dei sentimenti: \'Va bene essere agitati. Anch\'io ero nervoso il primo giorno di scuola.\'',
          'Piccoli oggetti di transizione aiutano: una foto nello zaino, un piccolo ricordo — gli oggetti creano sicurezza.',
        ],
        practical_tip: 'Oggi chiedi a tuo figlio: \'Cosa ti fa piacere di...? Cosa ti preoccupa ancora?\' — e ascolta senza giudicare.',
        discussion_body: 'Come avete accompagnato un passaggio importante di vostro figlio? Cosa ha aiutato?',
        companion_quick: 'I passaggi sono fine e inizio allo stesso tempo, ed entrambi possono essere sentiti.',
        companion_reflect: 'Quale emozione ha mostrato tuo figlio oggi attorno a un passaggio?',
      },
      milestone_sozial: {
        title: 'Intelligenza sociale: la competenza più importante del XXI secolo',
        parent_lens: 'Il QI apre le porte. L\'intelligenza emotiva fa entrare le persone. I bambini con un\'alta competenza sociale sanno cooperare, comunicare e mettersi nei panni degli altri meglio, e lo imparano da te.',
        parent_tips: [
          'Mostra l\'empatia ogni giorno: \'Il gatto sembra triste. Secondo te perché?\'',
          'Esercita il cambio di prospettiva: \'Come pensi si sia sentito... quando gli hai detto quella cosa?\'',
          'Riconosci esplicitamente il comportamento sociale: \'Hai aspettato che finisse di parlare. È stato molto rispettoso.\'',
        ],
        practical_tip: 'Oggi, dopo l\'asilo o la scuola, parla di una situazione sociale: \'Qualcuno ha fatto qualcosa di gentile oggi?\'',
        discussion_body: 'Quale aspetto della competenza sociale ritenete oggi più importante, per i bambini e per gli adulti?',
        companion_quick: 'La competenza sociale non è un talento: è un\'abilità che si allena.',
        companion_reflect: 'Quando oggi tuo figlio ha mostrato empatia, anche se forse è passato inosservato?',
      },
      milestone_emotion: {
        title: 'Maturità emotiva: quando i sentimenti vengono elaborati',
        parent_lens: 'La maturità emotiva non si vede nel non avere sentimenti, ma nell\'elaborarli. I bambini a cui è permesso esprimere i sentimenti imparano a gestirli meglio nel lungo periodo.',
        parent_tips: [
          'Tutti i sentimenti sono permessi, non tutte le azioni. \'Puoi essere arrabbiato. Non puoi colpire.\'',
          'Non sminuire i sentimenti: invece di \'Non è poi così grave\' → \'Vedo che questa cosa ti colpisce davvero.\'',
          'Lascia sentire le emozioni nel corpo: \'Dove lo senti adesso? Nella pancia? Nel petto?\'',
        ],
        practical_tip: 'Oggi chiedi: \'Come lo senti nel tuo corpo?\' — e accetta qualunque risposta.',
        discussion_body: 'Quale sentimento è più difficile mostrare apertamente nella vostra famiglia?',
        companion_quick: 'Permettere i sentimenti non è debolezza: è forza emotiva.',
        companion_reflect: 'Quale emozione ha mostrato apertamente tuo figlio oggi, e come l\'avete accompagnata insieme?',
      },
      milestone_kreativitaet: {
        title: 'Favorire la creatività, senza orientarsi al risultato',
        parent_lens: 'La creatività è capacità di risolvere problemi travestita. Quando i bambini disegnano, costruiscono, creano o giocano, allenano flessibilità e originalità: le competenze del futuro.',
        parent_tips: [
          'Nessuna attenzione al prodotto finale: \'Raccontami cosa hai fatto\' invece di \'Cosa dovrebbe essere?\'',
          'Offri materiali senza istruzioni: stoffa, cartone, materiali naturali — e poi lascia andare.',
          'Sii creativo tu stesso: quando i genitori disegnano, costruiscono, cantano — senza perfezione — lo permettono anche ai loro figli.',
        ],
        practical_tip: 'Oggi proponi 20 minuti di attività creativa libera — senza modello, senza istruzioni, solo materiali.',
        discussion_body: 'Qual è il progetto più creativo che vostro figlio abbia mai inventato da solo?',
        companion_quick: 'La creatività ha bisogno di spazio, tempo e di un adulto che non giudica.',
        companion_reflect: 'Cosa ha inventato, costruito o immaginato tuo figlio oggi che ti ha sorpreso?',
      },
      milestone_koerper: {
        title: 'Rafforzare la percezione del corpo: il movimento come motore di sviluppo',
        parent_lens: 'Lo sviluppo motorio e quello cognitivo sono inscindibilmente legati. I bambini che si arrampicano, stanno in equilibrio e ballano sviluppano anche il pensiero spaziale e la concentrazione.',
        parent_tips: [
          'Inserisci il movimento ogni giorno: non come programma sportivo, ma come quotidianità — le scale invece dell\'ascensore, camminare invece di farsi portare.',
          'Alterna motricità grossolana e fine: costruire (fine) e arrampicarsi (grossolana) si completano a meraviglia.',
          'Rafforza positivamente l\'immagine del corpo: \'Il tuo corpo sa fare tantissimo\' — indipendentemente dall\'aspetto o dalla prestazione.',
        ],
        practical_tip: 'Oggi prevedi 10 minuti di gioco di movimento — equilibrio, saltelli, rotolamenti. Nessun programma, solo corpo e divertimento.',
        discussion_body: 'Quale attività di movimento dà più gioia a vostro figlio, e perché?',
        companion_quick: 'Il movimento non è un passatempo: è un motore di apprendimento.',
        companion_reflect: 'Cosa ha provato o osato fisicamente tuo figlio oggi, di nuovo?',
      },
      milestone_uebergaenge: {
        title: 'Prepararsi alla pubertà: per tempo e con serenità',
        parent_lens: 'La pubertà inizia prima di quanto pensino la maggior parte dei genitori, e le basi si pongono nell\'infanzia. Una comunicazione aperta e un rapporto genitore-figlio sicuro sono la miglior preparazione.',
        parent_tips: [
          'Parla per tempo dei cambiamenti del corpo — in modo concreto, senza drammi. I bambini informati hanno meno paura.',
          'Condividi i tuoi ricordi della pubertà (in modo adeguato): \'Anch\'io allora ero insicuro riguardo a...\' — questo normalizza.',
          'Crea spazi di privacy: bussare, rispettare i diari. La fiducia nasce dal rispetto.',
        ],
        practical_tip: 'Oggi guarda insieme a tuo figlio (in modo adatto all\'età) un video o un libro sui processi del corpo, senza imbarazzo.',
        discussion_body: 'Ripensandoci, cosa è stato importante per voi durante la pubertà, e cosa avreste voluto che i vostri genitori facessero?',
        companion_quick: 'La miglior preparazione alla pubertà è una relazione forte oggi.',
        companion_reflect: 'Oggi tuo figlio ha fatto una domanda che mostra che sta cominciando a riflettere su se stesso?',
      },
      gfk_wiedergutmachung: {
        title: 'Quando i genitori perdono le staffe: riparare come forza',
        parent_lens: 'Nessun genitore è sempre paziente. Quando perdi le staffe non è un fallimento come genitore: è un momento umano. Ma ciò che viene dopo plasma la relazione più dello scoppio in sé.',
        parent_tips: [
          'Riparare richiede tre passi: assumersi la responsabilità (\'Ho sbagliato\'), mostrare compassione e, se serve, fare diversamente.',
          'Scuse senza \'ma\': \'Mi dispiace di aver alzato così tanto la voce. Non è stato giusto.\' — fine.',
          'Tuo figlio ti vede come persona, ed è un bene. I bambini imparano dalla riparazione che le relazioni superano le tempeste.',
        ],
        practical_tip: 'Se oggi in una situazione non ti sei comportato bene: torna da tuo figlio e diglielo. Bastano tre frasi.',
        discussion_body: 'Come avete imparato come genitori a gestire i vostri scoppi, senza giudicarvi con troppa durezza?',
        companion_quick: 'Riparare insegna ai bambini qualcosa che nessun manuale può: che le relazioni si possono riparare.',
        companion_reflect: 'Oggi c\'è stato un momento che, ripensandoci, avresti gestito diversamente, e cosa ne hai ricavato?',
      },
    },
    ar: {
      gfk_warum: {
        title: 'مرافقة أسئلة «لماذا» بهدوء',
        parent_lens: 'يسألك طفلك «لماذا؟» عشرات المرات في اليوم. إنه لا يفعل ذلك ليزعجك، بل لأن دماغه ينسج روابط جديدة. هو يرغب ببساطة في فهم العالم من حوله.',
        parent_tips: [
          'استعمل لغة التواصل اللاعنفي: عبّر عن مشاعرك واحتياجاتك بوضوح بدلاً من التوبيخ.',
          'أجب عن أسئلة «لماذا» بإيجاز وبساطة؛ طفلك يبحث عن منطق واضح، لا عن محاضرة علمية.',
          'ضع الحدود بمحبة من خلال حضورك الشخصي («لا أريدك أن تضرب») بدلاً من العقاب.',
        ],
        practical_tip: 'عند سؤال «لماذا» التالي: اعكس الشعور أولاً («أنت فضولي!»)، ثم أجب بجملة واحدة.',
        discussion_body: 'ما الصياغة القصيرة والهادئة التي تساعدكما عندما يسأل طفلكما عن السبب للمرة العاشرة؟',
        companion_quick: 'اختر اليوم إجابة هادئة واحدة عن سؤال «لماذا»، وابقَ بعدها موجزاً عن قصد.',
        companion_reflect: 'متى بحث طفلك اليوم عن أكبر قدر من الروابط، وكيف استطعت أن تمنحه التوجيه بهدوء؟',
      },
      gfk_grenzen: {
        title: 'وضع الحدود بمحبة ووضوح',
        parent_lens: 'الحدود المحِبّة ليست تناقضاً. يحتاج الأطفال إلى الأمرين معاً: الشعور بأنهم محبوبون، وإلى توجيه واضح حول ما لا يجوز. الحدود بلا رابط تبدو كالجدران، أما الحدود مع الرابط فتبدو كحواجز حماية ترشد الطريق.',
        parent_tips: [
          'سمِّ شعور طفلك أولاً، ثم اذكر الحدّ: «أرى أنك غاضب. ومع ذلك: الضرب غير مسموح».',
          'ابقَ هادئاً في جسدك؛ فنبرتك أعلى صوتاً من كلماتك. نفَسٌ عميق قبل ردة الفعل يساعد كثيراً.',
          'أعلن النتائج والتزم بها. لا تهدّد، بل أخبِر مسبقاً: «إذا فعلت كذا، فسيحدث كذا».',
        ],
        practical_tip: 'تدرّب اليوم على جملة تجمع الشعور مع الحدّ: «أتفهّم أنك تريد ذلك. ومع ذلك: لا» مع البقاء هادئاً.',
        discussion_body: 'كيف تتصرفان عندما تبلغان حدودكما الشخصية؟ وما الجملة التي تساعدكما على البقاء هادئين؟',
        companion_quick: 'نفَسٌ عميق واحد قبل ردة الفعل عند الحدّ التالي، وهذا نصف الطريق.',
        companion_reflect: 'هل مرّ موقف اليوم نجح فيه حدّ هادئ أكثر من رفض عالي الصوت؟',
      },
      gfk_ichbotschaft: {
        title: 'رسائل الأنا بدلاً من اتهامات الأنت',
        parent_lens: 'رسائل الأنت («أنت مزعج جداً!») تثير الدفاع والمقاومة. أما رسائل الأنا («أشعر بالتعب وأحتاج إلى الهدوء») فتفتح الأبواب. يصغي الأطفال أكثر حين لا يشعرون بأنهم مهاجَمون.',
        parent_tips: [
          'حوّل الاتهامات إلى رسائل أنا: بدلاً من «أنت لا تصغي أبداً» ← «لا أشعر بأنني مسموع، وهذا يحزنني».',
          'شارك حاجتك: «أحتاج الآن إلى لحظة هدوء كي أفكر». يفهم الأطفال الاحتياجات بشكل مدهش.',
          'تدرّب في حياتك اليومية: أعِد صياغة ثلاث جمل كرسائل أنا؛ صباحاً عند تنظيف الأسنان، ظهراً عند الطعام، مساءً عند النوم.',
        ],
        practical_tip: 'اختر اليوم موقفاً اعتدت أن تقول فيه «أنت دائماً...»، واستبدله بـ«أشعر بـ... لأنني أحتاج إلى...».',
        discussion_body: 'أي رسالة أنت تجدان صعوبة في إعادة صياغتها؟ وما الذي يساعد على ذلك؟',
        companion_quick: 'سمِّ الشعور ثم الحاجة؛ هذه هي صيغة رسالة الأنا الحقيقية.',
        companion_reflect: 'هل أثارت رسالة أنا اليوم ردة فعل فاجأتك؟',
      },
      gfk_trotz: {
        title: 'مرافقة نوبات العناد بهدوء',
        parent_lens: 'العناد ليس تمرّداً، بل هو نموّ. حين يستلقي الطفل على الأرض ويصرخ، فإن قشرته الجبهية الأمامية لم تنضج بعد بما يكفي لتنظيم المشاعر. إنه يحتاج إليك كشريك في التنظيم المشترك.',
        parent_tips: [
          'ابقَ قريباً جسدياً من دون إجبار: انزل إلى مستوى عينيه، تكلّم بهدوء، ولا تلمسه إن رفض ذلك.',
          'تجنّب النقاش في وسط العاصفة. الحوار يأتي فقط بعد أن يهدأ.',
          'استعمل «جسور المشاعر»: «أردت المثلجات. كان ذلك مهماً جداً بالنسبة إليك. أنا أتفهّم ذلك».',
        ],
        practical_tip: 'حين يفقد طفلك السيطرة: اجلس بجانبه. لا تبتعد ولا تتدخل، فقط كن حاضراً. هذا وحده ينظّم المشاعر.',
        discussion_body: 'ما الذي يساعدكما على البقاء هادئين حين يكون طفلكما في وسط انفجار عاطفي؟',
        companion_quick: 'ثلاث كلمات لنوبات العناد: ابقَ قريباً. تنفّس بهدوء. انتظر حتى تمرّ.',
        companion_reflect: 'ما الذي استنزف طاقتك أكثر اليوم، وما الذي ساعدك على البقاء هادئاً خلاله؟',
      },
      gfk_geschwister: {
        title: 'استثمار شجار الإخوة كمجال للتعلّم',
        parent_lens: 'يتشاجر الإخوة، وهذا أمر طبيعي بل ومهمّ. في الشجار يتعلّم الأطفال التسوية وتبادل وجهات النظر وتأكيد الذات. دورك هو دور الوسيط لا القاضي.',
        parent_tips: [
          'لا تنحز إلى أحد: «أرى أن كليكما غاضب الآن. سأستمع إليك أولاً، ثم إليك».',
          'دع الأطفال يجدون الحلول بأنفسهم ما دام الموقف لا يتصاعد. لا تتدخل إلا عند وجود خطر حقيقي.',
          'عزّز كل طفل على حِدة: لحظات فردية منتظمة من دون الإخوة تقلّل الغيرة على المدى البعيد.',
        ],
        practical_tip: 'في الشجار التالي: اسأل كلا الطفلين «ما الذي تحتاج إليه الآن؟» قبل أن تقرّر من على حقّ.',
        discussion_body: 'كيف تتعاملان حين يتشاجر الإخوة؟ وما الذي ينجح معكما أكثر من غيره؟',
        companion_quick: 'وسيط لا قاضٍ؛ هذا هو دورك في نزاعات الإخوة.',
        companion_reflect: 'هل مرّت لحظة اليوم حلّ فيها أطفالك نزاعاً بأنفسهم؟ وما الذي تعلّمتموه منها؟',
      },
      gfk_gefühle: {
        title: 'تسمية المشاعر والاعتراف بها',
        parent_lens: 'الأطفال القادرون على تسمية مشاعرهم يملكون ميزة كبيرة: يستطيعون التعبير عمّا يحتاجون إليه. هذه الخطوة، من الشعور إلى الكلام، تحتاج إلى تمرين وإلى دعمك.',
        parent_tips: [
          'استعمل «مقياس المشاعر»: اسأل مساءً «كيف كان يومك على مقياس من 1 إلى 5؟» وابدأ بسرد يومك أنت أولاً.',
          'سمِّ مشاعرك بصوت عالٍ: «أشعر الآن ببعض التوتر لأن لديّ الكثير لأفكر فيه». التعلّم بالقدوة فعّال.',
          'اقرأ كتب الأطفال عن المشاعر، ثم توقّف بعدها: «برأيك، بماذا شعرت الشخصية؟ وأنت؟»',
        ],
        practical_tip: 'اطرح الليلة هذا السؤال: «ما الذي أسعدك اليوم؟ وما الذي أحزنك أو أغضبك؟» ثم أنصِت فقط.',
        discussion_body: 'أي شعور يصعب على طفلكما تسميته بوجه خاص؟ وكيف تتعاملان مع ذلك؟',
        companion_quick: 'اشعر أولاً، ثم سمِّ؛ أبجدية المشاعر تبدأ بك أنت كقدوة.',
        companion_reflect: 'أي لحظة شعورية لطفلك أردت أن تحتفظ بها اليوم؟',
      },
      gfk_nein: {
        title: 'قول «لا» بلا شعور بالذنب',
        parent_lens: 'الآباء الذين لا يقولون «لا» أبداً يربّون أطفالاً لا يعرفون الحدود. إن «لا» المحبّة تُظهر لطفلك: أنا آخذ احتياجاتي على محمل الجدّ، ويحقّ لك أنت أيضاً أن تفعل ذلك.',
        parent_tips: [
          '«لا» لا تحتاج إلى شرح طويل. جملة واضحة مثل «لا، هذا غير ممكن الآن» كافية وتامة.',
          'الشعور بالذنب بعد قول «لا» إشارة لا خطأ. اسأل نفسك: هل هذا الرفض خاطئ فعلاً، أم أنه مزعج فقط؟',
          'تدرّب على قول «لا» للكبار أيضاً (مواعيد اللعب، الالتزامات)؛ طفلك يتعلّم من قدوتك.',
        ],
        practical_tip: 'قل «لا» اليوم مرة واحدة عن وعي، من دون أن تعتذر. وتأمّل كيف يكون شعورك.',
        discussion_body: 'متى يصعب عليكما قول «لا» أكثر، لأطفالكما أم للآخرين؟',
        companion_quick: '«لا» لأمرٍ ما هي «نعم» لأمرٍ أهمّ، غالباً «نعم» لنفسك أنت.',
        companion_reflect: 'هل كان هناك اليوم «لا» شعرت لاحقاً بأنه كان صائباً؟',
      },
      inclusion_stärken: {
        title: 'رؤية نقاط القوة بدلاً من الحكم على الضعف',
        parent_lens: 'لكل طفل مجموعة فريدة من نقاط القوة. غالباً ما نرى نحن الآباء مواطن الضعف أولاً، مع أننا أول من يمكنه أن يصقل الجوهرة الخام.',
        parent_tips: [
          'اكتب الليلة 3 من نقاط قوة طفلك؛ ليست إنجازات بل صفات شخصية («فضولي»، «حنون»، «مثابر»).',
          'سمِّ نقاط القوة بوضوح وفي حينها: «كنت صبوراً جداً الآن، وهذا رائع حقاً».',
          'تجنّب المقارنات مع الإخوة أو الأطفال الآخرين. كل منحنى نموّ فريد من نوعه.',
        ],
        practical_tip: 'تحدّث اليوم مع طفلك عن إحدى نقاط قوّته، لا كمديح بل كملاحظة: «رأيت اليوم كيف أنك...».',
        discussion_body: 'أي نقطة قوة خفية لدى طفلكما تودّان مشاركتها اليوم؟',
        companion_quick: 'رؤية القوة لا تعني تجاهل الضعف، بل تعني إتاحة النموّ.',
        companion_reflect: 'أي نقطة قوة لدى طفلك فاجأتك أو أثّرت فيك اليوم؟',
      },
      inclusion_selbstwert: {
        title: 'بناء تقدير الذات يومياً',
        parent_lens: 'تقدير الذات لا ينشأ من المديح وحده، بل من التجربة: «أنا قادر على شيء. أنا مهمّ. أنا أنتمي». يمكنك أن تدمج هذه التجارب الثلاث يومياً.',
        parent_tips: [
          'دع طفلك يتخذ قرارات صغيرة: «أتريد أن تنجز الواجبات أولاً أم تلعب أولاً؟» الاستقلالية تعني تقدير الذات.',
          'أظهر اهتماماً حقيقياً: ضع الهاتف جانباً، انظر إلى وجهه، واسأله. 10 دقائق من الانتباه الكامل تصنع العجائب.',
          'احتفِ بالمسار لا بالنتيجة وحدها: «حاولت طويلاً جداً، وهذا هو الجزء المهمّ».',
        ],
        practical_tip: 'اليوم: 10 دقائق من الانتباه الكامل لطفلك، بلا هاتف وبلا تشتّت، فقط اهتمام.',
        discussion_body: 'ما الذي يجعل طفلكما فخوراً بنفسه بوجه خاص؟ وكيف تدعمان هذا الشعور؟',
        companion_quick: 'تقدير الذات لا يأتي من المرآة، بل من عيون من يحبوننا.',
        companion_reflect: 'في أي لحظة أظهر طفلك اليوم شعور «أنا قادر على ذلك!»؟',
      },
      inclusion_scheitern: {
        title: 'رؤية الفشل كفرصة للتعلّم',
        parent_lens: 'يتعلّم الدماغ بأقوى صورة من الأخطاء لا من النجاحات. حين يفشل طفلك وتبقى أنت هادئاً، تمنحه أقوى رسالة: «الفشل آمن. أنا أتحمّله».',
        parent_tips: [
          'عند الفشل: التعاطف أولاً ثم الحلّ: «كان ذلك محبطاً. ما الذي يمكننا أن نفعله بشكل مختلف في المرة القادمة؟»',
          'احكِ عن إخفاقاتك أنت: «أنا أيضاً فعلت ذات مرة... ثم تعلّمت...». التعلّم بالقدوة يكسر الحرج.',
          'تجنّب عبارة «قلت لك ذلك». إنها تغلق الأبواب. بدلاً منها: «ماذا استفدت من ذلك؟»',
        ],
        practical_tip: 'احكِ لطفلك اليوم عن إخفاق مررت به أنت، وما الذي تعلّمته منه.',
        discussion_body: 'كيف تتعاملون كعائلة مع الهزائم؟ وما الذي يساعدكم على رؤية الفشل جزءاً من التعلّم؟',
        companion_quick: 'الأطفال الذين يُسمح لهم بارتكاب الأخطاء يصبحون كباراً أكثر شجاعة.',
        companion_reflect: 'هل كان هناك إخفاق اليوم تجاوزه طفلك بشكل جيد؟ وما الذي ساعد على ذلك؟',
      },
      inclusion_hochsensibel: {
        title: 'فهم الأطفال شديدي الحساسية ومرافقتهم',
        parent_lens: 'نحو 20% من الأطفال شديدو الحساسية؛ يدركون أكثر، ويشعرون بعمق أكبر، ويحتاجون إلى وقت أطول للتعافي. هذه ليست نقطة ضعف، بل سمة شخصية لها نقاط قوّتها الخاصة.',
        parent_tips: [
          'قلّل من فرط التنبيه الحسّي: خطّط لأوقات انتقال هادئة قبل المواقف المرهِقة (التسوّق، المدرسة، الحفلات).',
          'القابلية للتوقّع تحمي: أخبِر بما سيأتي («سنغادر بعد 10 دقائق»). المفاجآت مرهِقة للأطفال شديدي الحساسية.',
          'حساسيتهم نقطة قوة: يلاحظون حين يكون أحدهم حزيناً، ويفكرون بعمق. سمِّ ذلك بشكل إيجابي.',
        ],
        practical_tip: 'خطّط اليوم لـ15 دقيقة هادئة لإعادة شحن طاقة طفلك بعد موقف مرهِق، بلا شاشة وبلا توقّعات.',
        discussion_body: 'هل تلاحظان سمات الحساسية الشديدة لدى طفلكما؟ وما الذي يساعدكما على التعامل معها يومياً؟',
        companion_quick: 'الأطفال شديدو الحساسية لا يحتاجون إلى تقسية، بل إلى مساحات آمنة وإلى تفهّم.',
        companion_reflect: 'متى عالج طفلك اليوم قدراً كبيراً من الانطباعات، وكيف تعافى بعد ذلك؟',
      },
      inclusion_freundschaft: {
        title: 'مرافقة الصداقات لا التحكّم بها',
        parent_lens: 'الصداقات هي أهمّ ميدان لتعلّم الكفاءة الاجتماعية. يتعلّم الأطفال العطاء والأخذ والتفاوض والتنازل، لكن فقط حين نترك نحن الآباء زمام الأمور ونرافق بدلاً من أن نتحكّم.',
        parent_tips: [
          'اسأل من دون أن تحكم: «كيف كان الأمر اليوم مع...؟» أفضل من «لا يعجبني فلان، فقد فعل مؤخراً...».',
          'دع النزاعات بين الأطفال تُحلّ بينهم أولاً، ولا تتدخل إلا حين ينشأ ضيق حقيقي.',
          'أتِح الصداقات بنشاط: مواعيد لعب، دعوات. الفرص الاجتماعية لا تأتي من تلقاء نفسها.',
        ],
        practical_tip: 'اسأل طفلك اليوم: «من في صفّك أو مجموعتك يحبّ ما تحبّه أنت؟» وفكّرا معاً في كيفية تخصيص وقت لذلك.',
        discussion_body: 'كيف تمنحان أطفالكما مساحة لصداقاتهم الخاصة، حتى حين لا تفهمان اختياراتهم دائماً؟',
        companion_quick: 'الصداقة الحقيقية لا تُفرض، لكن يمكنكما معاً أن تهيّئا لها أرضاً خصبة.',
        companion_reflect: 'هل تحدّث طفلك اليوم عن شخص مهمّ بالنسبة إليه؟ وما الذي تعلّمته من ذلك؟',
      },
      inclusion_resilienz: {
        title: 'المرونة النفسية: كيف ينمو الأطفال عبر التحديات',
        parent_lens: 'المرونة النفسية ليست فطرية، بل تُكتسب بالتمرين. يصبح الأطفال أكثر صلابة حين يختبرون التحديات ويُدعَمون خلالها في آن معاً. المفتاح ليس الحماية، بل المرافقة.',
        parent_tips: [
          'دع طفلك يُكمِل التحديات: لا تساعده مبكراً جداً. اعرض المساعدة فقط حين يعجز فعلاً عن المضيّ قدماً.',
          'عزّز الحوار الداخلي: «برأيك، ماذا يمكنك أن تفعل؟» بدلاً من إعطاء الحلّ مباشرة.',
          'تحدّثوا عن أزمات العائلة بما يناسب العمر: الأطفال الذين يُستبعَدون ينسجون تخيّلات أسوأ من الحقيقة.',
        ],
        practical_tip: 'إذا فشل طفلك اليوم: انتظر 30 ثانية قبل أن تتدخل. غالباً ما يأتي الحلّ من تلقاء نفسه.',
        discussion_body: 'أي تحدٍّ تغلّب عليه طفلكما وفاجأكما بذلك؟',
        companion_quick: 'تنمو المرونة في المساحة بين التحدي والدعم، لا قبلها ولا بعدها.',
        companion_reflect: 'كيف تلاحظان أن طفلكما قد نما في داخله اليوم؟',
      },
      inclusion_vielfalt: {
        title: 'اختبار التنوّع: الاختلاف مصدر قوة',
        parent_lens: 'الأطفال الذين يتعلّمون مبكراً أن الناس مختلفون، في الأصل والقدرات وطرائق التفكير، ينمّون تعاطفاً أكبر وخوفاً أقلّ من الاختلاف. يمكنك أن تجعل التنوّع حاضراً في الحياة اليومية.',
        parent_tips: [
          'تحدّث بصراحة عن الاختلافات؛ فالأطفال يلاحظونها على أي حال: «نعم، لارا لون بشرتها مختلف عن لونك، وعائلتها من...».',
          'اختر الكتب والأفلام والألعاب التي تضمّ شخصيات متنوعة؛ فالتمثيل يشكّل نظرة الطفل إلى العالم.',
          'احتفِ بخصوصيات عائلتك: «نحن نفعل هذا هكذا، والعائلات الأخرى تفعله بشكل مختلف، وهذا هو الجميل في الأمر».',
        ],
        practical_tip: 'اقرأ اليوم كتاب أطفال بطله مختلف عن طفلك، ثم تحدّثا عنه بعد ذلك.',
        discussion_body: 'كيف تشرحان للأطفال الفروق بين الناس بطريقة تثير الفضول بدلاً من الخوف؟',
        companion_quick: 'الأطفال فضوليون بطبعهم تجاه الاختلافات، أما الأحكام المسبقة فيتعلّمونها لاحقاً.',
        companion_reflect: 'هل طرح طفلك اليوم سؤالاً عن الاختلافات جعلك تتأمّل؟',
      },
      leadership_struktur: {
        title: 'روتين اليوم كمرساة للأمان',
        parent_lens: 'يحبّ دماغ الطفل القابلية للتوقّع. الطقوس والروتين ليست قيداً، بل هي الهيكل الذي يمنح الأطفال حرّية أن ينمو في أمان.',
        parent_tips: [
          'مراسٍ ثابتة في اليوم: طقس الاستيقاظ، أوقات الطعام، وقت النوم. هذه الثلاثة تكفي لاستقرار حقيقي.',
          'خطّط لطقوس الانتقال: أعلِن انتقالات قصيرة بين الأنشطة. «بعد 5 دقائق سنرتّب».',
          'الروتين ليس توتراً؛ غيّره تدريجياً عند الحاجة لا بشكل مفاجئ.',
        ],
        practical_tip: 'انظر اليوم مع طفلك إلى جدول اليوم وتحدّثا عمّا سيأتي. هذا يقلّل المقاومة وعدم الاطمئنان.',
        discussion_body: 'أي طقس يومي يحظى بأهمية خاصة لديكما كعائلة، ولماذا؟',
        companion_quick: 'القابلية للتوقّع تصنع الأمان، والأمان يصنع الاستعداد للتعلّم.',
        companion_reflect: 'أي لحظة اليوم أظهرت أن طفلك يحتاج إلى الروتين، أو أنه استمتع به؟',
      },
      leadership_schlaf: {
        title: 'طقوس النوم: خلق الهدوء للجسد والعقل',
        parent_lens: 'النوم وقت نموّ لا استراحة فقط. أثناء النوم يعالج الدماغ أحداث اليوم، ويرسّخ الذكريات، ويتجدّد. إن طقس النوم الجيد من أكثر الاستثمارات تأثيراً في طفلك.',
        parent_tips: [
          'قبل 30 دقيقة من النوم: لا شاشات ولا ألعاب مثيرة. تهدئة الطاقة تحتاج إلى وقت.',
          'الترتيب نفسه دائماً: الأسنان، البيجاما، القصة، إطفاء النور. الطقوس تشير للدماغ: «حان وقت النوم».',
          'إذا لم يستطع طفلك النوم: تنفّسا معاً. شهيق 4 ثوانٍ، وزفير 6 ثوانٍ؛ هذا ينشّط الجهاز العصبي الباراسمبثاوي المهدّئ.',
        ],
        practical_tip: 'ابدأ الليلة طقس تنفّس مدّته 3 دقائق قبل النوم: شهيق، زفير، معاً.',
        discussion_body: 'ما طقس النوم المفضّل لديكما، وكيف طوّرتماه؟',
        companion_quick: 'طقس ختامي هادئ هو أفضل مدخل إلى نوم عميق.',
        companion_reflect: 'كيف كان النوم اليوم؟ ما الذي ساعد وما الذي أعاق؟',
      },
      leadership_bildschirm: {
        title: 'تنظيم وقت الشاشة بوعي',
        parent_lens: 'ليست مدة الشاشة بحدّ ذاتها هي المشكلة، بل الاستهلاك السلبي غير المنضبط من دون حوار بعده. ببعض الأطر البسيطة تتحوّل الشاشة إلى نشاط ترفيهي صحّي.',
        parent_tips: [
          'أوقات ثابتة بدلاً من المنع المفاجئ: «بعد الواجبات حتى الساعة 5 مساءً» أوضح من «ليس كثيراً».',
          'شاهدا معاً وتحدّثا بعدها: «ما الذي أعجبك؟ وما الذي كان غريباً؟» هذا يعزّز الوعي الإعلامي.',
          'خصّص مساحات خالية من الشاشات: غرفة النوم ومائدة الطعام حدّان جيدان للبداية.',
        ],
        practical_tip: 'شاهدا معاً شيئاً لمدة 15 دقيقة اليوم، ثم اطرح سؤالين عنه بعد ذلك. هذا يغيّر طريقة إدراك طفلك للإعلام.',
        discussion_body: 'كيف تنظّمان وقت الشاشة لديكما؟ ما الذي أثبت نجاحه وما الذي كان أقلّ نفعاً؟',
        companion_quick: 'الاستخدام الواعي للإعلام لا يُتعلّم بالمنع، بل بالحوار.',
        companion_reflect: 'كيف استخدم طفلك الإعلام اليوم، بنشاط أم بسلبية؟ وما الذي لفت انتباهك؟',
      },
      leadership_autoritaet: {
        title: 'السلطة عبر الرابط لا عبر الخوف',
        parent_lens: 'أن تكون ذا سلطة لا يعني أن تكون صارماً وعالي الصوت. تنشأ سلطة الوالدين الحقيقية حين يعرف الطفل: «أنت تحبّني وأنت واضح في آنٍ معاً». الرابط والقيادة لا يتعارضان، بل يكمّل أحدهما الآخر.',
        parent_tips: [
          'تعليمات واضحة بلا نقاش: «هكذا سنفعل الآن». بعدها لا مساومة، بل تقديم التفهّم فقط.',
          'الاعتذار يجعل الكبار أقوى لا أضعف: «لم يكن تصرّفي قبل قليل عادلاً»؛ الأطفال يحترمون ذلك.',
          'ضَعوا بعض القواعد معاً؛ هذا يزيد الاستعداد للالتزام بها.',
        ],
        practical_tip: 'صُغ اليوم قاعدة كأمر إيجابي بدلاً من المنع: «نرتّب بعد اللعب» بدلاً من «لا تترك الأشياء مبعثرة».',
        discussion_body: 'كيف تجدان التوازن بين القيادة ومشاركة أطفالكما في الرأي؟',
        companion_quick: 'سلطة بلا رابط تحكّم. ورابط بلا سلطة فوضى. وكلاهما معاً قيادة.',
        companion_reflect: 'هل مرّت لحظة اليوم حقّق فيها وضوحك الهادئ أثراً أكبر من كلمة سلطة حازمة؟',
      },
      leadership_hausaufgaben: {
        title: 'واجبات بلا توتر: إطار ناجح يعمل',
        parent_lens: 'غالباً ما لا يكون توتر الواجبات مشكلة تعلّم، بل مشكلة طقس. مع الهيكل المناسب والتوقيت المناسب يهدأ الموضوع من تلقاء نفسه.',
        parent_tips: [
          'اعثر على التوقيت المناسب: مباشرة بعد المدرسة أو بعد فترة راحة قصيرة، لكن قبل المساء.',
          'أنا حاضر لكنني لا أساعد فوراً: يحاول بنفسه أولاً. بعد 10 دقائق بلا تقدّم: اسأل «أين تعثّرت؟».',
          'هيّئ مكان العمل: مكان ثابت، طاولة مرتّبة، ولا هاتف في مجال النظر؛ هذا يقلّل التشتّت.',
        ],
        practical_tip: 'حدّد اليوم مع طفلك موعد الواجبات الواحد لهذا الأسبوع، واكتبه.',
        discussion_body: 'ما الذي جعل الواجبات أقلّ توتراً لديكم؟ وأي روتين ينجح معكم؟',
        companion_quick: 'الهيكل أثناء التعلّم ليس قيداً، بل هو محرّك التركيز.',
        companion_reflect: 'كيف سار التعلّم اليوم؟ وما الذي يمكنكم تجربته بشكل مختلف غداً؟',
      },
      leadership_selbstaendigkeit: {
        title: 'الاستقلالية: الترك أيضاً محبة',
        parent_lens: 'يصبح الأطفال مستقلّين حين نثق بهم. لكن الترك يبدو محفوفاً بالمخاطر، وهذا طبيعي. الفنّ هو تسليم المزيد من المسؤولية خطوة بخطوة.',
        parent_tips: [
          'وزّع مهامّ تناسب العمر: ابن 3 سنوات يرتّب الألعاب، وابن 6 يرتّب المائدة، وابن 10 يساعد في الطبخ.',
          'لا تتدخّل حين يسير الأمر ببطء. البطء مع الاستقلال أثمن من السرعة مع المساعدة.',
          'اقبل الأخطاء في المهامّ المستقلة: ينسكب كوب الحليب، وهذا ليس فشلاً، بل تمرين.',
        ],
        practical_tip: 'سلّم طفلك اليوم مهمة جديدة كنت تقوم بها بنفسك، ودعه ينجزها كاملة بمفرده.',
        discussion_body: 'ما أكبر إنجاز استقلالي حقّقه طفلكما وتفخران به معاً؟',
        companion_quick: 'كل مهمة يُنجزها الطفل بنفسه هي استثمار في ثقته بنفسه مستقبلاً.',
        companion_reflect: 'متى تركتما زمام الأمور اليوم، وكيف كان شعوركما حيال ذلك؟',
      },
      leadership_natur: {
        title: 'الطبيعة والحركة كطقس عائلي',
        parent_lens: 'الأطفال الذين يخرجون بانتظام ينامون أفضل، ويركّزون أكثر، وأكثر استقراراً عاطفياً. الطبيعة ليست نشاطاً ترفيهياً، بل حاجة أساسية.',
        parent_tips: [
          '15 دقيقة يومياً في الخارج لها أثر ملموس بالفعل؛ لا حاجة إلى رحلة، فحتى الطريق إلى المدرسة يُحسَب.',
          'تحرّكوا معاً: دراجة، نزهة، ملعب. الحركة معاً تقوّي الرابط.',
          'دع طفلك يكتشف الطبيعة: الحجارة، الخنافس، البرك. بلا برنامج، فقط انفتاح.',
        ],
        practical_tip: 'خطّط اليوم لجولة مدتها 15 دقيقة في الخارج؛ بلا هدف وبلا برنامج، معاً فقط.',
        discussion_body: 'أي تجربة في الطبيعة من طفولتكما تودّان أن تنقلاها إلى أطفالكما؟',
        companion_quick: 'الخروج إلى الهواء الطلق غذاء للدماغ، للأطفال والكبار على حدّ سواء.',
        companion_reflect: 'كيف غيّر وقتكم في الخارج اليوم المزاج العام؟',
      },
      milestone_sprache: {
        title: 'تطوّر اللغة: كيف تدعمه باللعب',
        parent_lens: 'لا يحدث تطوّر اللغة في تدريبات المفردات، بل في الحوار. يتعلّم الأطفال الكلام حين يتحدّث الكبار معهم، ويصغون إليهم، ويتفاعلون مع ما يقولون.',
        parent_tips: [
          'صِف يومياتك بصوت عالٍ: «أنا الآن أقطّع الجزر»؛ هذا يُثري المفردات الكامنة.',
          'التقط عبارات طفلك ووسّعها: «كرة!» ← «نعم، الكرة الحمراء تتدحرج».',
          'اقرأ بصوت عالٍ يومياً، حتى لو كان الطفل يعرف القراءة. نصوص الكتب لها بنى مختلفة عن لغة الحياة اليومية.',
        ],
        practical_tip: 'اقرأ اليوم بصوت عالٍ لمدة 10 دقائق، واسأل أثناء القراءة: «برأيك، ماذا سيحدث بعد ذلك؟»',
        discussion_body: 'أي كلمات أو جُمَل قالها طفلكما مؤخراً فاجأتكما أو أثّرت فيكما بوجه خاص؟',
        companion_quick: 'تنمو اللغة في الحوار لا في الصمت.',
        companion_reflect: 'أي تقدّم لغوي لدى طفلكما لفت انتباهكما اليوم؟',
      },
      milestone_schule: {
        title: 'مرافقة بدء المدرسة والانتقالات بهدوء',
        parent_lens: 'الانتقالات، كبدء المدرسة أو تغيير الصفّ أو روضة جديدة، هي أشدّ مراحل التعلّم كثافة بالنسبة للأطفال. هدوؤك وثقتك ينتقلان إلى طفلك. أنت قاعدة التنظيم بالنسبة إليه.',
        parent_tips: [
          'تعرّفوا إلى الأماكن الجديدة مسبقاً: إن أمكن، زوروا الصفّ أو المدرسة الجديدة قبل اليوم الأول.',
          'تحدّثوا عن المشاعر: «لا بأس أن تكون متحمّساً وقلقاً. أنا أيضاً كنت متوتراً في أول يوم مدرسي».',
          'الأغراض الانتقالية الصغيرة تساعد: صورة في الحقيبة، تذكار صغير؛ الأشياء الملموسة تمنح الأمان.',
        ],
        practical_tip: 'اسأل طفلك اليوم: «ما الذي يسعدك بشأن...؟ وما الذي ما زال يقلقك؟» وأنصِت من دون إصدار أحكام.',
        discussion_body: 'كيف رافقتما انتقالاً مهماً في حياة طفلكما؟ وما الذي ساعد؟',
        companion_quick: 'الانتقالات نهاية وبداية في آنٍ معاً، ويحقّ الشعور بالأمرين.',
        companion_reflect: 'أي شعور أظهره طفلك اليوم حيال انتقالٍ ما؟',
      },
      milestone_sozial: {
        title: 'الذكاء الاجتماعي: أهمّ كفاءة في القرن الحادي والعشرين',
        parent_lens: 'الذكاء العقلي يفتح الأبواب، أما الذكاء العاطفي فيُدخِل الناس إلى القلوب. الأطفال ذوو الكفاءة الاجتماعية العالية يتعاونون ويتواصلون ويتفهّمون الآخرين بشكل أفضل، وهم يتعلّمون ذلك منك.',
        parent_tips: [
          'اعرِض التعاطف يومياً كقدوة: «القطة تبدو حزينة. برأيك، لماذا؟»',
          'تدرّبوا على تبادل وجهات النظر: «برأيك، بماذا شعر فلان حين قلت ذلك؟»',
          'امدح السلوك الاجتماعي بوضوح: «انتظرت حتى أنهى كلامه. كان ذلك محترماً جداً».',
        ],
        practical_tip: 'تحدّث اليوم بعد الروضة أو المدرسة عن موقف اجتماعي: «هل فعل أحدهم اليوم شيئاً لطيفاً؟»',
        discussion_body: 'أي جانب من جوانب الكفاءة الاجتماعية تجدانه الأهمّ اليوم، للأطفال والكبار؟',
        companion_quick: 'الكفاءة الاجتماعية ليست موهبة، بل مهارة تُكتسب بالتمرين.',
        companion_reflect: 'متى أظهر طفلك التعاطف اليوم، حتى لو مرّ ذلك من دون أن يلاحظه أحد؟',
      },
      milestone_emotion: {
        title: 'النضج العاطفي: حين تُعالَج المشاعر',
        parent_lens: 'لا يظهر النضج العاطفي في غياب المشاعر، بل في معالجتها. الأطفال الذين يُسمح لهم بالتعبير عن مشاعرهم يتعلّمون التعامل معها بشكل أفضل على المدى البعيد.',
        parent_tips: [
          'كل المشاعر مسموحة، لكن ليست كل التصرّفات: «يحقّ لك أن تغضب. لا يحقّ لك أن تضرب».',
          'لا تقلّل من شأن المشاعر: بدلاً من «الأمر ليس بهذا السوء» ← «أرى أن هذا يؤثّر فيك حقاً».',
          'دع المشاعر تُحَسّ في الجسد: «أين تشعر بذلك الآن؟ في بطنك؟ في صدرك؟»',
        ],
        practical_tip: 'اسأل اليوم: «كيف يبدو هذا الشعور في جسدك؟» واقبل أي إجابة تأتي.',
        discussion_body: 'أي شعور يصعب على عائلتكما إظهاره بصراحة أكثر من غيره؟',
        companion_quick: 'السماح بالمشاعر ليس ضعفاً، بل قوة عاطفية.',
        companion_reflect: 'أي شعور أظهره طفلك بصراحة اليوم، وكيف رافقتماه معاً؟',
      },
      milestone_kreativitaet: {
        title: 'تنمية الإبداع من دون التركيز على النتيجة',
        parent_lens: 'الإبداع هو قدرة على حلّ المشكلات في ثوب آخر. حين يرسم الأطفال ويبنون ويصنعون ويلعبون، يدرّبون المرونة والأصالة، وهما كفاءتا المستقبل.',
        parent_tips: [
          'لا تركّز على المنتج النهائي: «احكِ لي ماذا صنعت» بدلاً من «ما المفترض أن يكون هذا؟»',
          'اعرِض موادّ بلا تعليمات: قماش، كرتون، موادّ طبيعية، ثم اترك المجال.',
          'كن مبدعاً أنت أيضاً: حين يرسم الآباء ويبنون ويغنّون بلا سعي للكمال، يسمحون لأطفالهم بالأمر نفسه.',
        ],
        practical_tip: 'اعرِض اليوم 20 دقيقة من الصناعة الحرّة؛ بلا نموذج وبلا تعليمات، فقط موادّ.',
        discussion_body: 'ما أكثر مشروع إبداعي طوّره طفلكما بنفسه؟',
        companion_quick: 'الإبداع يحتاج إلى مساحة ووقت وإلى شخص بالغ لا يصدر أحكاماً.',
        companion_reflect: 'ما الذي ابتكره طفلك أو بناه أو تخيّله اليوم وفاجأك؟',
      },
      milestone_koerper: {
        title: 'تقوية الوعي الجسدي: الحركة محرّك للنموّ',
        parent_lens: 'التطوّر الحركي والتطوّر المعرفي مترابطان بشكل لا ينفصل. الأطفال الذين يتسلّقون ويوازنون ويرقصون ينمّون أيضاً تفكيرهم المكاني وتركيزهم.',
        parent_tips: [
          'ادمِج الحركة يومياً: ليس كبرنامج رياضي، بل كجزء من الحياة اليومية؛ الدرج بدلاً من المصعد، والمشي بدلاً من الحمل.',
          'بدّلوا بين المهارات الحركية الكبرى والدقيقة: البناء (دقيق) والتسلّق (كبير) يكمّل أحدهما الآخر بشكل رائع.',
          'عزّز صورة الجسد بشكل إيجابي: «جسدك قادر على الكثير» بصرف النظر عن المظهر أو الأداء.',
        ],
        practical_tip: 'خطّط اليوم لـ10 دقائق من لعب الحركة؛ موازنة، قفز، تدحرج. بلا برنامج، فقط جسد ومرح.',
        discussion_body: 'أي نشاط حركي يمنح طفلكما أكبر قدر من الفرح، ولماذا؟',
        companion_quick: 'الحركة ليست نشاطاً ترفيهياً، بل محرّك للتعلّم.',
        companion_reflect: 'ما الذي جرّبه طفلك جسدياً أو تجرّأ عليه اليوم وكان جديداً؟',
      },
      milestone_uebergaenge: {
        title: 'التحضير للمراهقة مبكراً وبهدوء',
        parent_lens: 'تبدأ المراهقة أبكر مما يظنّ معظم الآباء، وتُرسَم ملامحها في مرحلة الطفولة. التواصل المنفتح وعلاقة آمنة بين الوالد والطفل هما أفضل تحضير لها.',
        parent_tips: [
          'تحدّثوا مبكراً عن تغيّرات الجسد، بموضوعية وبلا دراما. الأطفال المطّلعون يخافون أقلّ.',
          'شاركوا ذكرياتكم عن المراهقة بما يناسب الموقف: «أنا أيضاً كنت غير واثق حيال... حينها»؛ هذا يجعل الأمر طبيعياً.',
          'هيّئوا مساحات للخصوصية: الطَرق قبل الدخول، احترام المذكّرات. الثقة تنشأ عبر الاحترام.',
        ],
        practical_tip: 'شاهد اليوم مع طفلك (بما يناسب عمره) مقطعاً أو كتاباً عن عمليات الجسد، بلا حرج.',
        discussion_body: 'ما الذي كان مهماً بالنسبة إليكما في المراهقة عند النظر إلى الوراء، وما الذي تتمنّيان لو فعله والداكما؟',
        companion_quick: 'أفضل تحضير للمراهقة هو علاقة قوية اليوم.',
        companion_reflect: 'هل طرح طفلك اليوم سؤالاً يدلّ على أنه بدأ يفكّر في ذاته؟',
      },
      gfk_wiedergutmachung: {
        title: 'حين يفقد الوالدان أعصابهما: جبر الخاطر مصدر قوة',
        parent_lens: 'لا يوجد والد صبور طوال الوقت. حين تفقد أعصابك فهذا ليس فشلاً في دورك كوالد، بل لحظة إنسانية. لكن ما يأتي بعدها يصوغ العلاقة أقوى من الانفجار نفسه.',
        parent_tips: [
          'جبر الخاطر يحتاج إلى ثلاث خطوات: تحمّل المسؤولية («لقد أخطأت»)، وإظهار التعاطف، والتصرّف بشكل مختلف عند الحاجة.',
          'اعتذار بلا «لكن»: «أنا آسف لأنني كنت عالي الصوت. لم يكن ذلك مقبولاً». وانتهى.',
          'طفلك يراك إنساناً، وهذا جيد. يتعلّم الأطفال عبر الإصلاح أن العلاقات تصمد أمام العواصف.',
        ],
        practical_tip: 'إن لم يكن تصرّفك جميلاً في موقف اليوم: عُد إلى طفلك وقل له ذلك. ثلاث جُمَل تكفي.',
        discussion_body: 'كيف تعلّمتما كوالدين التعامل مع لحظات فقدان الأعصاب من دون أن تحكما على نفسيكما بقسوة؟',
        companion_quick: 'جبر الخاطر يعلّم الأطفال ما لا يعلّمه أي دليل تربوي: أن العلاقات قابلة للإصلاح.',
        companion_reflect: 'هل مرّت لحظة اليوم كنت ستتصرّف فيها بشكل مختلف لاحقاً، وما الذي صنعته منها؟',
      },
    },
};

// Returns the impulse topic for today, cycling through the pool by day-of-year.
function getTodayImpulseTopic() {
  const now = new Date();
  const start = new Date(now.getFullYear(), 0, 0);
  const dayOfYear = Math.floor((now - start) / (1000 * 60 * 60 * 24));
  return DAILY_IMPULSE_POOL[dayOfYear % DAILY_IMPULSE_POOL.length];
}

function buildWeeklyImpulseSeedPosts(schema, impulseId) {
  if (!allowDemoBootstrap) {
    return [];
  }

  return [
    {
      id: `${impulseId}_parent_seed`,
      author_name: 'Miriam, Mama von 2 Kindern',
      role: 'Elternteil',
      verified_expert: false,
      verification_label: '',
      title: 'Kurze Antworten haben uns entlastet',
      body:
        'Seit wir nicht mehr alles komplett erklären, sondern erst das Gefühl sehen und dann kurz antworten, sind unsere Nachmittage deutlich entspannter.',
      seed_like_count: 18,
      seed_comments: [
        'Das probieren wir heute direkt aus.',
        'Kurz und freundlich klappt bei uns auch besser als lange Diskussionen.',
      ],
    },
    {
      id: `${impulseId}_educator_seed`,
      author_name: 'Seda, Erzieherin',
      role: 'Paedagog:in',
      verified_expert: true,
      verification_label: 'Verifizierte Fachstimme',
      title: 'Praxis aus der Gruppe',
      body:
        'Ein ruhiger Blickkontakt und ein Satz wie Ich hoere dich, ich antworte dir kurz hilft vielen Kindern schneller als eine lange Erklärung.',
      seed_like_count: 24,
      seed_comments: ['Sehr nah am Alltag, danke.'],
    },
  ];
}

function localizeWeeklyImpulseTopic(topic, language) {
  // German is the source in DAILY_IMPULSE_POOL; other languages overlay their
  // translatable text fields from DAILY_IMPULSE_TRANSLATIONS. A missing
  // language or topic falls back to the German original.
  const translation = DAILY_IMPULSE_TRANSLATIONS[language]?.[topic.key];
  return translation ? { ...topic, ...translation } : topic;
}

function buildWeeklyImpulseResponse({ schema, viewerUserId, language = 'de' }) {
  const lang = supportedAppLanguageNames.has(language) ? language : 'de';
  const today = new Date().toISOString().slice(0, 10);
  const topic = localizeWeeklyImpulseTopic(getTodayImpulseTopic(), lang);
  const impulseId = `imp_daily_${today}_${topic.key}`;
  const state = getWeeklyImpulseCommunityEntry(impulseId);
  const seedPosts = buildWeeklyImpulseSeedPosts(schema, impulseId);
  const mergedPosts = [...seedPosts, ...state.customPosts]
    .filter(post => !state.hiddenPostIds?.[post.id]?.hidden)
    .map(post => {
      const likedBy = state.likedByPostId[post.id] || [];
      const extraComments = state.commentsByPostId[post.id] || [];
      const seedComments = Array.isArray(post.seed_comments) ? post.seed_comments : [];
      const seedLikeCount = Number.isFinite(post.seed_like_count) ? post.seed_like_count : 0;
      return {
        ...post,
        seed_like_count: seedLikeCount + likedBy.length,
        seed_comments: [...seedComments, ...extraComments.map(item => item.text)],
        viewer_has_liked: viewerUserId ? likedBy.includes(viewerUserId) : false,
      };
    });

  const labels = {
    de: {
      hero_headline: 'Dein Tagesimpuls für heute',
      prefix: 'Drei alltagsnahe Impulse:',
      greeting: 'Hallo und schön, dass du da bist.',
      closing: 'Du machst das gut.',
      quick_title: 'Heute in 2 Minuten',
      quick_fmt: 'Sofort-Impuls',
      und_title: 'Kurz verstanden',
      und_fmt: 'Verstehen',
      prac_title: 'Praxis für heute',
      prac_fmt: 'Praxis',
      refl_title: 'Abend-Reflexion',
      refl_fmt: 'Reflexion',
      deep_title: 'Tipp für den Alltag',
      deep_fmt: 'Artikel',
      question_title: 'Frage des Tages',
      min: 'Min',
    },
    en: {
      hero_headline: 'Your Daily Impulse',
      prefix: 'Three practical tips:',
      greeting: 'Hello and welcome!',
      closing: 'You are doing great.',
      quick_title: 'Today in 2 minutes',
      quick_fmt: 'Instant Impulse',
      und_title: 'Quick Summary',
      und_fmt: 'Understanding',
      prac_title: 'Practice for Today',
      prac_fmt: 'Practice',
      refl_title: 'Evening Reflection',
      refl_fmt: 'Reflection',
      deep_title: 'Daily Life Tip',
      deep_fmt: 'Article',
      question_title: 'Question of the Day',
      min: 'min',
    },
    tr: {
      hero_headline: 'Günün İlhamı',
      prefix: 'Üç pratik ipucu:',
      greeting: 'Merhaba, hoş geldin.',
      closing: 'Harika gidiyorsun.',
      quick_title: 'Bugün 2 Dakikada',
      quick_fmt: 'Hızlı İlham',
      und_title: 'Özetle',
      und_fmt: 'Anlama',
      prac_title: 'Günün Uygulaması',
      prac_fmt: 'Uygulama',
      refl_title: 'Akşam Değerlendirmesi',
      refl_fmt: 'Düşünce',
      deep_title: 'Günlük Hayat İpucu',
      deep_fmt: 'Makale',
      question_title: 'Günün Sorusu',
      min: 'dk',
    },
    ku: {
      hero_headline: 'Îlhama Te ya Rojê',
      prefix: 'Sê şîretên me yên ji bo jiyanê:',
      greeting: 'Merheba, bi xêr hatî.',
      closing: 'Tu vê yekê pir baş dikî.',
      quick_title: 'Îro di 2 Deqîqeyan de',
      quick_fmt: 'Îlhama Bilez',
      und_title: 'Kurtenêrîn',
      und_fmt: 'Têgihîştin',
      prac_title: 'Prensîba Îro',
      prac_fmt: 'Pratîk',
      refl_title: 'Ramana Êvarê',
      refl_fmt: 'Ramana Kûr',
      deep_title: 'Şîreta Jiyana Rojane',
      deep_fmt: 'Gutar',
      question_title: 'Pirsiyarê Rojê',
      min: 'deq',
    },
    fr: {
      hero_headline: 'Ton impulsion du jour',
      prefix: 'Trois conseils concrets au quotidien :',
      greeting: 'Bonjour et ravi que tu sois là.',
      closing: 'Tu fais du bon travail.',
      quick_title: "Aujourd'hui en 2 minutes",
      quick_fmt: 'Impulsion express',
      und_title: 'En bref',
      und_fmt: 'Comprendre',
      prac_title: "Pratique pour aujourd'hui",
      prac_fmt: 'Pratique',
      refl_title: 'Réflexion du soir',
      refl_fmt: 'Réflexion',
      deep_title: 'Astuce pour le quotidien',
      deep_fmt: 'Article',
      question_title: 'Question du jour',
      min: 'min',
    },
    es: {
      hero_headline: 'Tu impulso del día',
      prefix: 'Tres consejos prácticos para el día a día:',
      greeting: 'Hola, qué bien que estés aquí.',
      closing: 'Lo estás haciendo muy bien.',
      quick_title: 'Hoy en 2 minutos',
      quick_fmt: 'Impulso rápido',
      und_title: 'En resumen',
      und_fmt: 'Entender',
      prac_title: 'Práctica para hoy',
      prac_fmt: 'Práctica',
      refl_title: 'Reflexión de la tarde',
      refl_fmt: 'Reflexión',
      deep_title: 'Consejo para el día a día',
      deep_fmt: 'Artículo',
      question_title: 'Pregunta del día',
      min: 'min',
    },
    it: {
      hero_headline: 'Il tuo spunto del giorno',
      prefix: 'Tre consigli pratici per la quotidianità:',
      greeting: 'Ciao, che bello averti qui.',
      closing: 'Stai facendo un ottimo lavoro.',
      quick_title: 'Oggi in 2 minuti',
      quick_fmt: 'Spunto veloce',
      und_title: 'In breve',
      und_fmt: 'Capire',
      prac_title: 'Pratica per oggi',
      prac_fmt: 'Pratica',
      refl_title: 'Riflessione della sera',
      refl_fmt: 'Riflessione',
      deep_title: 'Consiglio per la quotidianità',
      deep_fmt: 'Articolo',
      question_title: 'Domanda del giorno',
      min: 'min',
    },
    ar: {
      hero_headline: 'إلهامك اليومي',
      prefix: 'ثلاث نصائح عملية للحياة اليومية:',
      greeting: 'مرحبًا، يسعدنا وجودك هنا.',
      closing: 'أنت تقوم بعمل رائع.',
      quick_title: 'اليوم في دقيقتين',
      quick_fmt: 'إلهام سريع',
      und_title: 'باختصار',
      und_fmt: 'فهم',
      prac_title: 'تطبيق اليوم',
      prac_fmt: 'تطبيق',
      refl_title: 'تأمل المساء',
      refl_fmt: 'تأمل',
      deep_title: 'نصيحة للحياة اليومية',
      deep_fmt: 'مقال',
      question_title: 'سؤال اليوم',
      min: 'دقيقة',
    },
  }[lang] || {
    hero_headline: 'Your Daily Impulse',
    prefix: 'Three practical tips:',
    greeting: 'Hello and welcome!',
    closing: 'You are doing great.',
    quick_title: 'Today in 2 minutes',
    quick_fmt: 'Instant Impulse',
    und_title: 'Quick Summary',
    und_fmt: 'Understanding',
    prac_title: 'Practice for Today',
    prac_fmt: 'Practice',
    refl_title: 'Evening Reflection',
    refl_fmt: 'Reflection',
    deep_title: 'Daily Life Tip',
    deep_fmt: 'Article',
    question_title: 'Question of the Day',
    min: 'min',
  };

  const contentBody =
    `${topic.parent_lens}\n\n` +
    `${labels.prefix}\n` +
    `- ${topic.parent_tips[0]}\n` +
    `- ${topic.parent_tips[1]}\n` +
    `- ${topic.parent_tips[2]}`;

  return {
    id: impulseId,
    title: topic.title,
    hero_headline: labels.hero_headline,
    hero_description: topic.parent_lens,
    content_body: contentBody,
    practical_tip: topic.practical_tip,
    audio_script:
      `${labels.greeting} ${topic.parent_lens} ` +
      `${topic.practical_tip} ${labels.closing}`,
    category: topic.category,
    publish_date: today,
    companion_impulses: [
      {
        id: `${impulseId}_quick`,
        title: labels.quick_title,
        summary: topic.companion_quick,
        duration_label: `2 ${labels.min}`,
        format_label: labels.quick_fmt,
      },
      {
        id: `${impulseId}_understand`,
        title: labels.und_title,
        summary: topic.parent_lens,
        duration_label: `3 ${labels.min}`,
        format_label: labels.und_fmt,
      },
      {
        id: `${impulseId}_practice`,
        title: labels.prac_title,
        summary: topic.parent_tips[0],
        duration_label: `4 ${labels.min}`,
        format_label: labels.prac_fmt,
      },
      {
        id: `${impulseId}_reflect`,
        title: labels.refl_title,
        summary: topic.companion_reflect,
        duration_label: `2 ${labels.min}`,
        format_label: labels.refl_fmt,
      },
      {
        id: `${impulseId}_deepdive`,
        title: labels.deep_title,
        summary: topic.parent_tips[1],
        duration_label: `5 ${labels.min}`,
        format_label: labels.deep_fmt,
      },
    ],
    discussion_prompt: {
      id: `${impulseId}_discussion`,
      title: labels.question_title,
      body: topic.discussion_body,
    },
    community_posts: mergedPosts,
  };
}

function findWeeklyImpulseCommunityPost({ schema, impulseId, postId }) {
  const state = getWeeklyImpulseCommunityEntry(impulseId);
  const seedPosts = buildWeeklyImpulseSeedPosts(schema, impulseId);
  return [...seedPosts, ...state.customPosts].find(post => post.id === postId) || null;
}

function buildWeeklyImpulseReportItems({ schema, impulseId }) {
  const state = getWeeklyImpulseCommunityEntry(impulseId);
  const seedPosts = buildWeeklyImpulseSeedPosts(schema, impulseId);
  const allPosts = [...seedPosts, ...state.customPosts];
  const items = [];

  for (const [postId, reports] of Object.entries(state.reportsByPostId || {})) {
    const post = allPosts.find(entry => entry.id === postId);
    for (const report of reports || []) {
      items.push({
        id: report.id,
        postId,
        postTitle: post?.title || 'Unbekannter Beitrag',
        postAuthorName: post?.author_name || 'Unbekannt',
        postRole: post?.role || 'Community',
        reason: report.reason,
        reporterName: report.reporterName,
        reporterUserId: report.reporterUserId,
        createdAt: report.createdAt,
        resolvedAt: report.resolvedAt || null,
        resolvedBy: report.resolvedBy || '',
        moderatorNote: report.moderatorNote || '',
        lastAction: report.lastAction || '',
        lastActionAt: report.lastActionAt || null,
        hiddenByModeration: state.hiddenPostIds?.[postId]?.hidden === true,
        hiddenAt: state.hiddenPostIds?.[postId]?.hiddenAt || null,
        hiddenBy: state.hiddenPostIds?.[postId]?.hiddenBy || '',
      });
    }
  }

  items.sort((a, b) => String(b.createdAt).localeCompare(String(a.createdAt)));
  return items;
}

function parseStripeSignatureHeader(headerValue) {
  if (!headerValue || typeof headerValue !== 'string') {
    return { timestamp: null, signatures: [] };
  }

  let timestamp = null;
  const signatures = [];

  for (const part of headerValue.split(',')) {
    const [key, value] = part.split('=');
    if (!key || !value) continue;
    const trimmedKey = key.trim();
    const trimmedValue = value.trim();

    if (trimmedKey === 't') {
      const parsed = Number.parseInt(trimmedValue, 10);
      if (Number.isFinite(parsed)) {
        timestamp = parsed;
      }
    }

    if (trimmedKey === 'v1' && trimmedValue) {
      signatures.push(trimmedValue);
    }
  }

  return { timestamp, signatures };
}

function verifyStripeWebhookSignature({ rawBody, signatureHeader, secret, toleranceSec }) {
  const { timestamp, signatures } = parseStripeSignatureHeader(signatureHeader);
  if (!timestamp || signatures.length === 0 || !secret) {
    return false;
  }

  const nowSec = Math.floor(Date.now() / 1000);
  if (Math.abs(nowSec - timestamp) > toleranceSec) {
    return false;
  }

  const payloadToSign = `${timestamp}.${rawBody}`;
  const expected = crypto
    .createHmac('sha256', secret)
    .update(payloadToSign, 'utf8')
    .digest('hex');

  const expectedBuffer = Buffer.from(expected, 'hex');
  for (const candidate of signatures) {
    try {
      const candidateBuffer = Buffer.from(candidate, 'hex');
      if (
        candidateBuffer.length === expectedBuffer.length &&
        crypto.timingSafeEqual(candidateBuffer, expectedBuffer)
      ) {
        return true;
      }
    } catch (_) {
      // Ignore malformed signature fragments.
    }
  }

  return false;
}

// Missing Admin configuration never produces a verified identity.
async function verifyFirebaseIdToken(req, { strictAvailability = false } = {}) {
  if (!firebaseAdmin) return { uid: null, verified: false };
  const authHeader = req.headers.authorization || '';
  if (!authHeader.startsWith('Bearer ')) return { uid: null, verified: false };
  const idToken = authHeader.slice(7);
  try {
    const decoded = await firebaseAdmin.auth().verifyIdToken(idToken);
    return {
      uid: decoded.uid,
      verified: true,
      email: typeof decoded.email === 'string' ? decoded.email.trim().toLowerCase() : '',
      emailVerified: decoded.email_verified === true,
    };
  } catch (error) {
    if (strictAvailability && [
      'app/network-error', 'app/network-timeout', 'auth/internal-error',
      'auth/certificate-fetch-failed', 'auth/too-many-requests',
    ].includes(error?.code)) {
      console.error('Firebase token verification unavailable:', error.code);
      return { uid: null, verified: false, unavailable: true };
    }
    return { uid: null, verified: false };
  }
}

async function requireVerifiedUser(req, res, next) {
  const { uid, verified, unavailable, email, emailVerified } =
    await verifyFirebaseIdToken(req, { strictAvailability: true });
  if (unavailable) {
    return res.status(503).json({ error: 'Kontopruefung derzeit nicht verfuegbar', code: 'identity_unavailable' });
  }
  if (!verified || !uid) {
    return res.status(401).json({ error: 'Gueltiger Firebase ID-Token erforderlich' });
  }
  req.firebaseUid = uid;
  req.firebaseIdentity = { uid, email, emailVerified };
  for (const claimedUid of [req.body?.userId, req.query?.userId]) {
    if (claimedUid !== undefined &&
        (typeof claimedUid !== 'string' || claimedUid.trim() !== uid)) {
      return res.status(403).json({ error: 'Nur fuer das eigene Konto erlaubt' });
    }
  }
  return next();
}

function resolveVerifiedUserId(req, fallbackUserId) {
  if (req.firebaseUid && req.firebaseUid.trim()) {
    return String(req.firebaseUid).trim();
  }
  const normalizedFallback = typeof fallbackUserId === 'string'
    ? fallbackUserId.trim()
    : String(fallbackUserId ?? '').trim();
  return normalizedFallback || null;
}

function hasExplicitUserMismatch(req, requestedUserId) {
  if (!req.firebaseUid) return false;
  if (requestedUserId === undefined || requestedUserId === null) return false;
  const normalized = String(requestedUserId).trim();
  if (!normalized) return false;
  return normalized !== req.firebaseUid;
}

async function authorizeAccountOwner(req, res, userId) {
  if (req.firebaseUid) {
    if (req.firebaseUid !== userId) {
      res.status(403).json({ error: 'Konto-Loeschung nur fuer das eigene Konto erlaubt' });
      return false;
    }
    return true;
  }
  const authHeader = req.headers.authorization || '';
  if (backendApiToken && authHeader === `Bearer ${backendApiToken}`) {
    return true;
  }

  const { uid, verified } = await verifyFirebaseIdToken(req);
  if (verified) {
    if (uid !== userId) {
      res.status(403).json({ error: 'Konto-Loeschung nur fuer das eigene Konto erlaubt' });
      return false;
    }
    req.firebaseUid = uid;
    return true;
  }

  if (!isProduction && !requireAuthForWrites && !firebaseRequireAuth) {
    return true;
  }

  res.status(401).json({ error: 'Gueltiger Firebase ID-Token erforderlich' });
  return false;
}

async function authorizeProfileOwner(req, res, userId) {
  const { uid, verified } = await verifyFirebaseIdToken(req);
  if (!verified) {
    res.status(401).json({ error: 'Firebase ID-Token erforderlich' });
    return false;
  }
  if (uid !== userId) {
    res.status(403).json({ error: 'Nur fuer das eigene Konto erlaubt' });
    return false;
  }
  req.firebaseUid = uid;
  return true;
}

// Middleware: if FIREBASE_REQUIRE_AUTH=1 AND Firebase Admin is configured,
// reject write requests whose token does not match the acting userId.
const firebaseRequireAuth = (process.env.FIREBASE_REQUIRE_AUTH || '0') === '1';

// Legacy-Ausnahmen fuer Web-Session-Restore. Kalender und weitere gehaertete
// Routen verlangen unabhaengig davon lokal einen verifizierten Firebase-Token.
// Muss mit der zweiten Middleware konsistent sein.
const socialNoTokenWritePaths = [
  '/calendar/events', '/todo', '/todos', '/shopping', '/friend-chat',
  '/api/friends', '/api/safety', '/api/onboarding', '/api/account',
  '/api/profile', '/api/friendships', '/api/recipes',
];

function isNoTokenWritePath(reqPath) {
  return socialNoTokenWritePaths.some(
    p => reqPath === p || reqPath.startsWith(p + '/'));
}

async function firebaseAuthMiddleware(req, res, next) {
  // Stripe authenticates this one public callback using its raw-body signature.
  if (req.method === 'POST' && req.path === '/payments/stripe/webhook') {
    return next();
  }
  if (!firebaseRequireAuth || !firebaseAdmin || !WRITE_METHODS.has(req.method)) {
    return next();
  }
  // userId-basierte Social-Endpoints: Token optional (best-effort verifizieren),
  // aber nie hart ablehnen — sonst gehen Profil/Freundschaft auf Web verloren.
  if (isNoTokenWritePath(req.path)) {
    const { uid, verified } = await verifyFirebaseIdToken(req);
    if (verified) req.firebaseUid = uid;
    return next();
  }
  const authHeader = req.headers.authorization || '';
  if (backendApiToken && authHeader === `Bearer ${backendApiToken}`) {
    return next();
  }
  const { uid, verified } = await verifyFirebaseIdToken(req);
  if (!verified) {
    return res.status(401).json({ error: 'Gültiger Firebase ID-Token erforderlich' });
  }
  req.firebaseUid = uid;
  return next();
}

// Middleware
app.use(firebaseAuthMiddleware);
app.use(async (req, res, next) => {
  // Baseline hardening headers for API traffic.
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('Referrer-Policy', 'no-referrer');
  res.setHeader('Permissions-Policy', 'geolocation=(), microphone=(), camera=()');
  // HSTS nur in Produktion (lokal laeuft HTTP). Render terminiert TLS; dieser
  // Header weist Browser an, kuenftig ausschliesslich HTTPS zu verwenden.
  if (isProduction) {
    res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
  }
  next();
});

app.use(
  cors({
    origin(origin, callback) {
      if (!origin) {
        callback(null, true);
        return;
      }

      if (allowedOrigins.length === 0) {
        if (isProduction) {
          callback(null, false);
          return;
        }
        callback(null, true);
        return;
      }

      if (allowedOrigins.includes(origin)) {
        callback(null, true);
        return;
      }

      callback(null, false);
    },
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    maxAge: 600,
  }),
);

app.post('/payments/stripe/webhook', express.raw({ type: 'application/json' }), async (req, res) => {
  if (!stripeWebhookSecret) {
    return res.status(503).json({ error: 'STRIPE_WEBHOOK_SECRET fehlt' });
  }

  const signatureHeader = req.headers['stripe-signature'];
  const rawBody = Buffer.isBuffer(req.body) ? req.body.toString('utf8') : '';
  const isValid = verifyStripeWebhookSignature({
    rawBody,
    signatureHeader,
    secret: stripeWebhookSecret,
    toleranceSec: stripeWebhookToleranceSec,
  });

  if (!isValid) {
    return res.status(400).json({ error: 'Ungueltige Stripe-Signatur' });
  }

  let event;
  try {
    event = JSON.parse(rawBody);
  } catch (_) {
    return res.status(400).json({ error: 'Ungueltiges Stripe-Webhook-JSON' });
  }

  const eventType = (event?.type || '').toString();
  const obj = event?.data?.object || {};
  let targetStatus = null;

  if (eventType === 'payment_intent.succeeded') {
    targetStatus = 'completed';
  } else if (eventType === 'payment_intent.payment_failed') {
    targetStatus = 'failed';
  } else if (eventType === 'charge.refunded') {
    targetStatus = 'refunded';
  }

  if (!targetStatus) {
    return res.json({ received: true, ignored: true, reason: 'event_not_mapped' });
  }

  const providerTransactionRef =
    (obj?.payment_intent || obj?.id || '').toString().trim();

  if (!providerTransactionRef) {
    return res.status(400).json({ error: 'Stripe event ohne payment reference' });
  }

  const result = await applyProviderTransactionStatusUpdate({
    provider: 'stripe',
    providerTransactionRef,
    targetStatus,
    verified: true,
  });

  if (!result.ok) {
    if (result.code === 'not_found') {
      return res.status(202).json({
        received: true,
        pending: true,
        reason: 'transaction_not_found',
      });
    }
    return res.status(result.httpStatus).json({ error: result.error });
  }

  return res.json({
    received: true,
    transactionId: result.item.id,
    status: result.item.status,
  });
});

app.use('/ai/generate', express.json({ limit: '6mb' }));
app.use(express.json({ limit: '1mb' }));

app.use(async (req, res, next) => {
  if (!isWriteRequest(req)) {
    next();
    return;
  }

  const now = Date.now();
  const key = `${getClientIp(req)}:${req.method}`;
  const bucket = writeRateBuckets.get(key);

  if (!bucket || now - bucket.start > writeRateWindowMs) {
    writeRateBuckets.set(key, { start: now, count: 1 });
    next();
    return;
  }

  bucket.count += 1;
  if (bucket.count > writeRateMax) {
    res.status(429).json({ error: 'Zu viele Anfragen. Bitte später erneut versuchen.' });
    return;
  }

  next();
});

app.use(async (req, res, next) => {
  if (!isWriteRequest(req)) {
    next();
    return;
  }

  if (!requireAuthForWrites) {
    next();
    return;
  }

  // Legacy exceptions; hardened routes such as calendar enforce Firebase
  // identity locally even when these global guards continue.
  const noTokenPaths = ['/calendar/events', '/todo', '/todos', '/shopping', '/friend-chat', '/api/friends', '/api/safety', '/api/onboarding', '/api/account', '/api/profile', '/api/friendships'];
  if (noTokenPaths.some(p => req.path === p || req.path.startsWith(p + '/'))) {
    const authHeader = req.headers.authorization || '';
    if (authHeader.startsWith('Bearer ') && firebaseAdmin) {
      const { uid, verified } = await verifyFirebaseIdToken(req);
      if (verified) req.firebaseUid = uid;
    }
    // Continue to route-local authorization.
    next();
    return;
  }

  const authHeader = req.headers.authorization || '';
  const hasBearer = authHeader.startsWith('Bearer ');

  if (backendApiToken && authHeader === `Bearer ${backendApiToken}`) {
    next();
    return;
  }

  if (hasBearer && firebaseAdmin) {
    const { uid, verified } = await verifyFirebaseIdToken(req);
    if (verified) {
      req.firebaseUid = uid;
      next();
      return;
    }
  }

  if (!backendApiToken && !firebaseAdmin) {
    res.status(503).json({ error: 'Server-Konfiguration unvollstaendig (Auth nicht konfiguriert).' });
    return;
  }

  res.status(401).json({ error: 'Unauthorized' });
});

const allowedGeminiModels = new Set([
  'gemini-3.5-flash-lite',
  'gemini-3.5-flash',
]);
const supportedAppLanguageNames = new Map([
  ['de', 'German'],
  ['en', 'English'],
  ['tr', 'Turkish'],
  ['ku', 'Kurmancî Kurdish in Latin Hawar script'],
  ['ar', 'Arabic'],
  ['fa', 'Farsi'],
  ['ckb', 'Sorani Kurdish'],
  ['fr', 'French'],
  ['es', 'Spanish'],
  ['it', 'Italian'],
  ['pt', 'Portuguese'],
  ['nl', 'Dutch'],
  ['pl', 'Polish'],
  ['ja', 'Japanese'],
  ['zh', 'Simplified Chinese'],
  ['hi', 'Hindi'],
]);

function normalizeAppLanguage(value) {
  const language = String(value || 'de').trim().toLowerCase();
  return supportedAppLanguageNames.has(language) ? language : 'de';
}

function buildLanguageInstruction(language) {
  return `Respond exclusively in ${supportedAppLanguageNames.get(language)}. Do not mix languages.`;
}

// ============================================================================
// AI PARENTING MEMORY — DSGVO-konformes Kind-Kontext-Gedächtnis
// Standardmäßig AUS (opt-in). Serverseitige Prompt-Anreicherung nur bei
// aktiviertem Gedächtnis und nur mit vom Nutzer bestätigten Einträgen.
// ============================================================================

const AI_MEMORY_MAX_CONTEXT_CHARS = 2800;
const AI_MEMORY_CATEGORIES = new Set([
  'topic',
  'medical',
  'medical_clarification',
  'tried_strategy',
  'helpful_strategy',
  'preference',
  'note',
]);
const AI_MEMORY_STATUSES = new Set(['confirmed', 'archived']);

async function requireAiMemoryUser(req, res) {
  const { uid, verified } = await verifyFirebaseIdToken(req);
  if (!verified || !uid) {
    res.status(401).json({ error: 'Gueltiger Firebase ID-Token erforderlich' });
    return null;
  }
  req.firebaseUid = uid;
  return uid;
}

function parseOptionalDate(value) {
  if (value === undefined || value === null || value === '') return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? undefined : date;
}

function validateAiChildPayload(body, { partial = false } = {}) {
  const result = {};
  if (!partial || body.name !== undefined) {
    const name = String(body.name || '').trim();
    if (!name || name.length > 100) return { error: 'name ist erforderlich und darf maximal 100 Zeichen haben' };
    result.name = name;
  }
  if (body.birthDate !== undefined) {
    const birthDate = parseOptionalDate(body.birthDate);
    if (birthDate === undefined) return { error: 'birthDate ist ungueltig' };
    result.birthDate = birthDate;
  }
  if (body.gender !== undefined) {
    const gender = String(body.gender || '').trim();
    if (gender.length > 50) return { error: 'gender darf maximal 50 Zeichen haben' };
    result.gender = gender || null;
  }
  return { data: result };
}

function validateAiMemoryPayload(body, { partial = false } = {}) {
  const result = {};
  if (!partial || body.category !== undefined) {
    const category = String(body.category || '').trim();
    if (!AI_MEMORY_CATEGORIES.has(category)) return { error: 'category ist ungueltig' };
    result.category = category;
  }
  if (!partial || body.key !== undefined) {
    const key = String(body.key || '').trim();
    if (!key || key.length > 100) return { error: 'key ist erforderlich und darf maximal 100 Zeichen haben' };
    result.key = key;
  }
  if (!partial || body.value !== undefined) {
    const value = String(body.value || '').trim();
    if (!value || value.length > 1000) return { error: 'value ist erforderlich und darf maximal 1000 Zeichen haben' };
    result.value = value;
  }
  if (body.status !== undefined) {
    const status = String(body.status || '').trim();
    if (!AI_MEMORY_STATUSES.has(status)) return { error: 'status ist ungueltig' };
    result.status = status;
  }
  return { data: result };
}

async function getAiMemoryContext(userId, childProfileId) {
  const settings = await prisma.aiMemorySettings.findUnique({ where: { userId } });
  if (!hasMemoryConsent(settings)) return '';

  const children = await prisma.aiChildProfile.findMany({
    where: {
      userId,
      ...(childProfileId ? { id: childProfileId } : {}),
    },
    include: {
      memoryItems: {
        where: { status: 'confirmed' },
        orderBy: { updatedAt: 'desc' },
      },
    },
    orderBy: { updatedAt: 'desc' },
  });
  if (!children.length) return '';

  const otherChildren = childProfileId ? await prisma.aiChildProfile.findMany({
    where: { userId, id: { not: childProfileId } },
    select: { name: true, birthDate: true },
  }) : [];
  return buildMemoryContext(children, new Date(), [...children, ...otherChildren]).slice(0, AI_MEMORY_MAX_CONTEXT_CHARS);
}

async function minimizeAiMemoryData(userId, childId, data) {
  const children = await prisma.aiChildProfile.findMany({
    where: { userId }, select: { id: true, name: true, birthDate: true },
  });
  for (const key of ['category', 'key', 'value']) {
    if (data[key] !== undefined) data[key] = minimizeMemoryText(data[key], children,
      child => child.id === childId ? '[THIS_CHILD]' : '[OTHER_CHILD]');
  }
}

async function requireAiMemoryConsent(userId, req, res) {
  const settings = await prisma.aiMemorySettings.findUnique({ where: { userId } });
  if (req.body?.memoryConsentVersion !== MEMORY_CONSENT_VERSION || !hasMemoryConsent(settings)) {
    res.status(403).json({ error: 'Memory consent required', code: 'MEMORY_CONSENT_REQUIRED' });
    return false;
  }
  return true;
}

app.get('/ai/settings', async (req, res) => {
  const userId = await requireAiMemoryUser(req, res);
  if (!userId) return;
  const settings = await prisma.aiMemorySettings.findUnique({ where: { userId } });
  return res.json({ enabled: hasMemoryConsent(settings), consentVersion: settings?.consentVersion ?? null });
});

app.put('/ai/settings', async (req, res) => {
  const userId = await requireAiMemoryUser(req, res);
  if (!userId) return;
  if (typeof req.body?.enabled !== 'boolean') {
    return res.status(400).json({ error: 'enabled muss boolean sein' });
  }
  if (req.body.enabled && req.body.memoryConsentVersion !== MEMORY_CONSENT_VERSION) {
    return res.status(403).json({ error: 'Memory consent required', code: 'MEMORY_CONSENT_REQUIRED' });
  }
  const consentVersion = req.body.enabled ? MEMORY_CONSENT_VERSION : null;
  const consentRevision = crypto.randomUUID();
  const settings = await prisma.aiMemorySettings.upsert({
    where: { userId },
    create: { userId, enabled: req.body.enabled, consentVersion, consentRevision },
    update: { enabled: req.body.enabled, consentVersion, consentRevision },
  });
  return res.json({ enabled: hasMemoryConsent(settings), consentVersion: settings.consentVersion });
});

app.get('/ai/children', async (req, res) => {
  const userId = await requireAiMemoryUser(req, res);
  if (!userId) return;
  const children = await prisma.aiChildProfile.findMany({
    where: { userId },
    include: { memoryItems: { orderBy: { updatedAt: 'desc' } } },
    orderBy: { updatedAt: 'desc' },
  });
  return res.json({ items: children });
});

app.post('/ai/children', async (req, res) => {
  const userId = await requireAiMemoryUser(req, res);
  if (!userId) return;
  if (!await requireAiMemoryConsent(userId, req, res)) return;
  const validated = validateAiChildPayload(req.body || {});
  if (validated.error) return res.status(400).json({ error: validated.error });
  validated.data.name = '[CHILD_1]';
  if (!await requireAiMemoryConsent(userId, req, res)) return;
  const child = await prisma.aiChildProfile.create({
    data: { userId, ...validated.data },
  });
  return res.status(201).json({ item: child });
});

app.put('/ai/children/:id', async (req, res) => {
  const userId = await requireAiMemoryUser(req, res);
  if (!userId) return;
  if (!await requireAiMemoryConsent(userId, req, res)) return;
  const validated = validateAiChildPayload(req.body || {}, { partial: true });
  if (validated.error) return res.status(400).json({ error: validated.error });
  if (validated.data.name !== undefined) validated.data.name = '[CHILD_1]';
  const existing = await prisma.aiChildProfile.findFirst({
    where: { id: req.params.id, userId },
  });
  if (!existing) return res.status(404).json({ error: 'Kinderprofil nicht gefunden' });
  if (!await requireAiMemoryConsent(userId, req, res)) return;
  const child = await prisma.aiChildProfile.update({
    where: { id: existing.id },
    data: validated.data,
  });
  return res.json({ item: child });
});

app.delete('/ai/children/:id', async (req, res) => {
  const userId = await requireAiMemoryUser(req, res);
  if (!userId) return;
  const result = await prisma.aiChildProfile.deleteMany({
    where: { id: req.params.id, userId },
  });
  if (result.count === 0) return res.status(404).json({ error: 'Kinderprofil nicht gefunden' });
  return res.json({ deleted: true });
});

app.get('/ai/children/:id/memory', async (req, res) => {
  const userId = await requireAiMemoryUser(req, res);
  if (!userId) return;
  const child = await prisma.aiChildProfile.findFirst({
    where: { id: req.params.id, userId },
    include: { memoryItems: { orderBy: { updatedAt: 'desc' } } },
  });
  if (!child) return res.status(404).json({ error: 'Kinderprofil nicht gefunden' });
  return res.json({ items: child.memoryItems });
});

app.post('/ai/children/:id/memory', async (req, res) => {
  const userId = await requireAiMemoryUser(req, res);
  if (!userId) return;
  if (!await requireAiMemoryConsent(userId, req, res)) return;
  const validated = validateAiMemoryPayload(req.body || {});
  if (validated.error) return res.status(400).json({ error: validated.error });
  const child = await prisma.aiChildProfile.findFirst({
    where: { id: req.params.id, userId },
    select: { id: true },
  });
  if (!child) return res.status(404).json({ error: 'Kinderprofil nicht gefunden' });
  await minimizeAiMemoryData(userId, child.id, validated.data);
  if (!await requireAiMemoryConsent(userId, req, res)) return;
  const item = await prisma.aiMemoryItem.upsert({
    where: {
      childId_category_key: {
        childId: child.id,
        category: validated.data.category,
        key: validated.data.key,
      },
    },
    create: {
      childId: child.id,
      ...validated.data,
      userConfirmedAt: new Date(),
    },
    update: {
      value: validated.data.value,
      status: validated.data.status || 'confirmed',
      userConfirmedAt: new Date(),
    },
  });
  return res.status(201).json({ item });
});

app.put('/ai/children/:id/memory/:itemId', async (req, res) => {
  const userId = await requireAiMemoryUser(req, res);
  if (!userId) return;
  if (!await requireAiMemoryConsent(userId, req, res)) return;
  const validated = validateAiMemoryPayload(req.body || {}, { partial: true });
  if (validated.error) return res.status(400).json({ error: validated.error });
  const item = await prisma.aiMemoryItem.findFirst({
    where: { id: req.params.itemId, child: { id: req.params.id, userId } },
  });
  if (!item) return res.status(404).json({ error: 'Memory-Eintrag nicht gefunden' });
  await minimizeAiMemoryData(userId, req.params.id, validated.data);
  if (!await requireAiMemoryConsent(userId, req, res)) return;
  const updated = await prisma.aiMemoryItem.update({
    where: { id: item.id },
    data: {
      ...validated.data,
      ...(validated.data.status === 'confirmed' ? { userConfirmedAt: new Date() } : {}),
    },
  });
  return res.json({ item: updated });
});

app.delete('/ai/children/:id/memory/:itemId', async (req, res) => {
  const userId = await requireAiMemoryUser(req, res);
  if (!userId) return;
  const result = await prisma.aiMemoryItem.deleteMany({
    where: { id: req.params.itemId, child: { id: req.params.id, userId } },
  });
  if (result.count === 0) return res.status(404).json({ error: 'Memory-Eintrag nicht gefunden' });
  return res.json({ deleted: true });
});

app.get('/ai/context', async (req, res) => {
  const userId = await requireAiMemoryUser(req, res);
  if (!userId) return;
  const context = await getAiMemoryContext(userId, String(req.query.childId || '').trim() || null);
  return res.json({ context, characterCount: context.length });
});

/**
 * GET /ai/health
 * Öffentlicher Selbsttest: prüft ob der Gemini-Key funktioniert
 * (ohne Secrets preiszugeben). Für Launch-Monitoring.
 */
app.get('/ai/health', async (req, res) => {
  if (!geminiApiKey) {
    return res.json({ ok: false, reason: 'GEMINI_API_KEY nicht gesetzt' });
  }
  const model = 'gemini-3.5-flash';
  // Mit ?grounding=1 wird der ECHTE Event-Suchpfad getestet (Google-Search-Tool
  // + JSON-Array-Antwort), nicht nur die Key-Gültigkeit. So deckt der Health-
  // Check genau das ab, was der KI-Feed in der App nutzt.
  const testGrounding = String(req.query.grounding || '') === '1';
  const body = testGrounding
    ? JSON.stringify({
        contents: [{
          role: 'user',
          parts: [{
            text: 'Heute. Finde bis zu 3 Familienevents in "Berlin" (20 km). '
              + 'Nutze Google Search. Antworte nur als kompaktes JSON-Array mit '
              + 'title, location. Ohne Treffer [].',
          }],
        }],
        generationConfig: { temperature: 1.0, maxOutputTokens: 2000 },
        tools: [{ google_search: {} }],
      })
    : JSON.stringify({
        contents: [{ role: 'user', parts: [{ text: 'ping' }] }],
        generationConfig: { maxOutputTokens: 5 },
      });
  const baseUrl = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;
  try {
    // Erst Header, dann Query-Param (wie im Proxy)
    let up = await fetch(baseUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-goog-api-key': geminiApiKey },
      body,
      signal: AbortSignal.timeout(30000),
    });
    let method = 'header';
    if (up.status === 401 || up.status === 403) {
      up = await fetch(`${baseUrl}?key=${encodeURIComponent(geminiApiKey)}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body,
        signal: AbortSignal.timeout(30000),
      });
      method = 'query';
    }

    if (!up.ok) {
      return res.json({
        ok: false,
        status: up.status,
        reason: `Gemini antwortet mit ${up.status}`,
      });
    }

    // Beim Grounding-Test zusätzlich prüfen, ob brauchbarer Text + JSON-Array
    // zurückkommt (das ist der Teil, der den Event-Feed real speist).
    if (testGrounding) {
      const payload = await up.json().catch(() => ({}));
      const cand = Array.isArray(payload.candidates) ? payload.candidates[0] : null;
      const parts = Array.isArray(cand?.content?.parts) ? cand.content.parts : [];
      const text = parts.map(p => String(p?.text || '')).join('').trim();
      const start = text.indexOf('[');
      const end = text.lastIndexOf(']');
      let arrayParsed = false;
      let itemCount = null;
      if (start !== -1 && end > start) {
        try {
          const arr = JSON.parse(text.slice(start, end + 1));
          arrayParsed = Array.isArray(arr);
          itemCount = Array.isArray(arr) ? arr.length : null;
        } catch (_) { /* nicht parsebar */ }
      }
      return res.json({
        ok: true,
        status: up.status,
        authMethod: method,
        grounding: true,
        textLength: text.length,
        hasJsonArray: arrayParsed,
        itemCount,
        reason: arrayParsed
          ? 'Grounding liefert parsebares JSON-Array'
          : 'Grounding erreichbar, aber kein parsebares JSON-Array',
      });
    }

    return res.json({
      ok: up.ok,
      status: up.status,
      authMethod: up.ok ? method : null,
      reason: up.ok ? 'Gemini erreichbar' : `Gemini antwortet mit ${up.status}`,
    });
  } catch (e) {
    return res.json({ ok: false, reason: `Fehler: ${e.message}` });
  }
});

app.post('/ai/generate', async (req, res) => {
  if (!geminiApiKey) {
    return res.status(503).json({ error: 'KI-Dienst nicht konfiguriert' });
  }

  // Dediziertes KI-Limit pro Nutzer (UID) bzw. IP: schützt die Gemini-Kosten
  // gegen Missbrauch, auch durch ein einzelnes eingeloggtes Konto.
  const aiRateKey = `ai:${req.firebaseUid || getClientIp(req)}`;
  if (!checkRateLimit(aiRateBuckets, aiRateKey,
      { windowMs: aiRateWindowMs, max: aiRateMax })) {
    return res.status(429).json({
      error: 'KI-Limit erreicht. Bitte in einigen Minuten erneut versuchen.',
    });
  }

  // Globales Tages-Hard-Cap über alle Nutzer: letzte Verteidigungslinie gegen
  // Kosten-Explosion. Erst NACH dem Per-Nutzer-Limit, damit bereits gedrosselte
  // Einzelanfragen das Gesamtbudget nicht belasten.
  if (!checkDailyBudget(aiDailyBudget, aiDailyBudgetMax)) {
    console.warn(`AI daily budget reached (${aiDailyBudgetMax}) — blocking further calls today`);
    return res.status(503).json({
      error: 'KI-Dienst heute stark ausgelastet. Bitte morgen erneut versuchen.',
    });
  }

  const model = String(req.body?.model || 'gemini-3.5-flash-lite').trim();
  const prompt = String(req.body?.prompt || '').trim();
  const systemInstruction = String(req.body?.systemInstruction || '').trim();
  const appLanguage = normalizeAppLanguage(req.body?.language);
  const useGoogleSearch = req.body?.useGoogleSearch === true;
  const childProfileId = String(req.body?.childProfileId || '').trim();
  const imageBase64 = String(req.body?.imageBase64 || '').trim();
  const imageMimeType = String(req.body?.imageMimeType || '').trim();
  const allowedImageMimeTypes = new Set(['image/jpeg', 'image/png', 'image/webp']);

  if (!allowedGeminiModels.has(model)) {
    return res.status(400).json({ error: 'Nicht unterstütztes KI-Modell' });
  }
  if (!prompt || prompt.length > 30000 || systemInstruction.length > 10000) {
    return res.status(400).json({ error: 'Ungültige Prompt-Länge' });
  }
  if (imageBase64) {
    if (!allowedImageMimeTypes.has(imageMimeType)) {
      return res.status(400).json({ error: 'Nicht unterstütztes Bildformat' });
    }
    const estimatedBytes = Math.floor(imageBase64.length * 0.75);
    if (estimatedBytes > 4 * 1024 * 1024) {
      return res.status(413).json({ error: 'Bild ist zu groß' });
    }
  }

  // KI-Gedächtnis: nur wenn eine childProfileId mitkommt UND der Nutzer per
  // Firebase-Token verifiziert ist, serverseitig den bestätigten Familien-
  // kontext (opt-in) in die System-Instruktion einspeisen.
  let aiMemoryContext = '';
  let memoryOwner = null;
  let memoryRevision = null;
  try {
    if (childProfileId) {
      const { uid, verified } = await verifyFirebaseIdToken(req);
      if (!verified || !uid) return res.status(401).json({ error: 'Memory authentication required' });
      if (!await requireAiMemoryConsent(uid, req, res)) return;
      memoryOwner = uid;
      const settings = await prisma.aiMemorySettings.findUnique({ where: { userId: uid } });
      if (!hasMemoryConsent(settings)) {
        return res.status(403).json({ error: 'Memory consent changed', code: 'MEMORY_CONSENT_REQUIRED' });
      }
      memoryRevision = settings.consentRevision;
      req.firebaseUid = uid;
      aiMemoryContext = await getAiMemoryContext(uid, childProfileId);
    }
  } catch (error) {
    console.error(`Memory lookup failed: ${error.message}`);
    return res.status(503).json({ error: 'Memory context could not be verified' });
  }

  async function checkMemoryTransfer() {
    if (!memoryOwner) return;
    const settings = await prisma.aiMemorySettings.findUnique({ where: { userId: memoryOwner } });
    if (!hasMemoryConsent(settings) || settings.consentRevision !== memoryRevision) {
      const error = new Error('Memory consent changed during request');
      error.code = 'MEMORY_CONSENT_REQUIRED';
      throw error;
    }
  }

  const finalSystemInstruction = [
    systemInstruction,
    aiMemoryContext,
    buildLanguageInstruction(appLanguage),
  ].filter(Boolean).join('\n\n');

  const requestBody = {
    contents: [{
      role: 'user',
      parts: [
        { text: prompt },
        ...(imageBase64
          ? [{ inline_data: { mime_type: imageMimeType, data: imageBase64 } }]
          : []),
      ],
    }],
    generationConfig: {
      temperature: useGoogleSearch ? 1.0 : 0.7,
      maxOutputTokens: useGoogleSearch ? 6000 : 8192,
    },
    systemInstruction: { parts: [{ text: finalSystemInstruction }] },
    ...(useGoogleSearch ? { tools: [{ google_search: {} }] } : {}),
  };

  // Hilfsfunktion: einen Gemini-Aufruf ausführen und Text + Grounding-URLs zurückgeben.
  // Robust: probiert erst den Header, bei 401/403 den Key als Query-Parameter
  // (neuere AQ.-Keys akzeptieren teils nur eine der beiden Methoden).
  async function callGemini(body) {
    const baseUrl = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;
    const jsonBody = JSON.stringify(body);

    async function attempt(useQueryParam) {
      const url = useQueryParam
        ? `${baseUrl}?key=${encodeURIComponent(geminiApiKey)}`
        : baseUrl;
      const headers = { 'Content-Type': 'application/json' };
      if (!useQueryParam) headers['x-goog-api-key'] = geminiApiKey;
      await checkMemoryTransfer();
      const response = await fetch(url, {
        method: 'POST',
        headers,
        body: jsonBody,
        signal: AbortSignal.timeout(35000),
      });
      await checkMemoryTransfer();
      return response;
    }

    let upstream = await attempt(false);
    // Bei Auth-Fehler: mit Query-Parameter erneut versuchen
    if (upstream.status === 401 || upstream.status === 403) {
      upstream = await attempt(true);
    }

    const payload = await upstream.json().catch(() => ({}));
    await checkMemoryTransfer();
    if (!upstream.ok) {
      const detail = payload?.error?.message || `HTTP ${upstream.status}`;
      throw new Error(detail);
    }
    const candidate = Array.isArray(payload.candidates) ? payload.candidates[0] : null;
    const parts = Array.isArray(candidate?.content?.parts) ? candidate.content.parts : [];
    const text = parts.map(part => String(part?.text || '')).join('').trim();
    const groundingChunks = Array.isArray(candidate?.groundingMetadata?.groundingChunks)
      ? candidate.groundingMetadata.groundingChunks
      : [];
    const groundingUrls = groundingChunks
      .map(chunk => chunk?.web?.uri)
      .filter(uri => typeof uri === 'string' && uri.startsWith('https://'));
    return { text, groundingUrls };
  }

  try {
    let result;
    try {
      result = await callGemini(requestBody);
    } catch (groundingError) {
      if (groundingError.code === 'MEMORY_CONSENT_REQUIRED') throw groundingError;
      // Wenn Grounding fehlschlägt: automatisch OHNE Grounding erneut versuchen.
      if (useGoogleSearch) {
        console.warn(`Grounding failed (${groundingError.message}) — retry without grounding`);
        const fallbackBody = {
          ...requestBody,
          generationConfig: { temperature: 0.7, maxOutputTokens: 8192 },
        };
        delete fallbackBody.tools;
        result = await callGemini(fallbackBody);
      } else {
        throw groundingError;
      }
    }

    // Wenn Grounding zwar erfolgreich, aber leerer Text: ohne Grounding erneut.
    if ((!result.text || result.text.length === 0) && useGoogleSearch) {
      const fallbackBody = {
        ...requestBody,
        generationConfig: { temperature: 0.7, maxOutputTokens: 8192 },
      };
      delete fallbackBody.tools;
      result = await callGemini(fallbackBody);
    }

    if (!result.text) {
      return res.status(502).json({ error: 'KI-Dienst lieferte keine Antwort' });
    }
    await checkMemoryTransfer();
    return res.json({ text: result.text, groundingUrls: result.groundingUrls });
  } catch (error) {
    if (error.code === 'MEMORY_CONSENT_REQUIRED') {
      return res.status(403).json({ error: 'Memory consent changed', code: error.code });
    }
    console.error(`Gemini proxy failed: ${error.message}`);
    return res.status(502).json({ error: 'KI-Dienst vorübergehend nicht verfügbar' });
  }
});

// Providers-Daten aus JSON laden
const providersPath = path.join(__dirname, 'providers.json');
const weeklyImpulseSchemaOverridePath = (process.env.WEEKLY_IMPULSE_SCHEMA_PATH || '').trim();
const weeklyImpulseSchemaPathCandidates = [
  weeklyImpulseSchemaOverridePath,
  path.join(__dirname, 'weekly_impulse_schema_year3.json'),
  path.join(process.cwd(), 'backend', 'weekly_impulse_schema_year3.json'),
  path.join(process.cwd(), 'weekly_impulse_schema_year3.json'),
].filter(Boolean);

function getProviders() {
  try {
    const data = fs.readFileSync(providersPath, 'utf8');
    return JSON.parse(data).providers;
  } catch (error) {
    console.error('Fehler beim Lesen der Providers:', error);
    return [];
  }
}

function saveProviders(providers) {
  try {
    fs.writeFileSync(providersPath, JSON.stringify({ providers }, null, 2));
    return true;
  } catch (error) {
    console.error('Fehler beim Speichern der Providers:', error);
    return false;
  }
}

let providerReviewSchemaEnsured = false;

async function ensureProviderReviewSchemaReady() {
  if (providerReviewSchemaEnsured) {
    return;
  }

  await prisma.$executeRawUnsafe(`
    CREATE TABLE IF NOT EXISTS "ProviderReview" (
      "id" TEXT PRIMARY KEY,
      "providerId" TEXT NOT NULL,
      "rating" INTEGER NOT NULL,
      "comment" TEXT,
      "parentName" TEXT,
      "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
  `);

  await prisma.$executeRawUnsafe(`
    CREATE INDEX IF NOT EXISTS "ProviderReview_providerId_idx"
    ON "ProviderReview"("providerId");
  `);

  providerReviewSchemaEnsured = true;
}

async function getProviderReviewStatsMap() {
  await ensureProviderReviewSchemaReady();

  const rows = await prisma.$queryRawUnsafe(`
    SELECT
      "providerId",
      COUNT(*)::INT AS "reviewCount",
      AVG("rating")::FLOAT8 AS "averageRating"
    FROM "ProviderReview"
    GROUP BY "providerId";
  `);

  const stats = new Map();
  for (const row of rows) {
    const providerId = (row.providerId || '').toString();
    if (!providerId) continue;
    stats.set(providerId, {
      reviewCount: Number(row.reviewCount || 0),
      averageRating: Number(row.averageRating || 0),
    });
  }

  return stats;
}

function mergeProviderWithReviewStats(provider, reviewStats) {
  const stats = reviewStats.get(provider.id);
  if (!stats) {
    return provider;
  }

  const baseReviews = Number(provider.reviews || 0);
  const baseRating = Number(provider.rating || 0);
  const dbReviews = Number(stats.reviewCount || 0);
  const dbRating = Number(stats.averageRating || 0);
  const mergedReviewCount = baseReviews + dbReviews;

  if (mergedReviewCount <= 0) {
    return provider;
  }

  const mergedRating = ((baseRating * baseReviews) + (dbRating * dbReviews)) / mergedReviewCount;

  return {
    ...provider,
    reviews: mergedReviewCount,
    rating: Math.round(mergedRating * 10) / 10,
  };
}

async function getProvidersWithReviewStats() {
  const providers = getProviders();
  try {
    const reviewStats = await getProviderReviewStatsMap();
    return providers.map(provider => mergeProviderWithReviewStats(provider, reviewStats));
  } catch (error) {
    console.error('Provider review stats konnten nicht geladen werden:', error?.message || error);
    return providers;
  }
}

function getWeeklyImpulseSchema() {
  for (const schemaPath of weeklyImpulseSchemaPathCandidates) {
    try {
      if (!fs.existsSync(schemaPath)) {
        continue;
      }
      const data = fs.readFileSync(schemaPath, 'utf8');
      return JSON.parse(data);
    } catch (error) {
      console.error(
        `Fehler beim Lesen des Weekly-Impulse-Schemas (${schemaPath}):`,
        error,
      );
    }
  }

  console.error(
    'Weekly-Impulse-Schema konnte nicht geladen werden. Gepruefte Pfade:',
    weeklyImpulseSchemaPathCandidates,
  );
  return {
    id: 'years_3',
    parent_lens:
      'Kinder in der Warum-Phase suchen vor allem Verbindung und Orientierung, nicht perfekte Erklärungen.',
    pedagogical_focus: 'Gefühle sehen, klar begrenzen, ruhig beantworten',
    parent_tips: [
      'Spiegele zuerst das Gefühl deines Kindes, bevor du auf die Frage eingehst.',
      'Antworte kurz in einem Satz und vermeide lange Erklaerketten.',
      'Wiederhole Grenzen freundlich und konsistent statt in Diskussionen zu gehen.',
    ],
    reassurance:
      'Du musst nicht jede Frage perfekt loesen. Verlaessliche Präsenz ist für dein Kind wichtiger als die perfekte Antwort.',
  };
}

// In-memory stores for app endpoints
const todos = [
  {
    id: 'todo-1',
    familyId: 'demo-family-001',
    title: 'Hausaufgaben machen',
    completed: false,
    assigneeName: 'Leon',
    category: 'Schule',
  },
  {
    id: 'todo-2',
    familyId: 'demo-family-001',
    title: 'Arzttermin buchen',
    completed: false,
    assigneeName: 'Mama',
    category: 'Gesundheit',
  },
];

const shoppingItems = [
  {
    id: 'shop-1',
    familyId: 'demo-family-001',
    name: 'Milch',
    checked: false,
    category: 'Lebensmittel',
  },
  {
    id: 'shop-2',
    familyId: 'demo-family-001',
    name: 'Windeln',
    checked: true,
    category: 'Baby',
  },
];

const calendarEvents = [
  {
    id: 'cal-1',
    familyId: 'demo-family-001',
    title: 'Elternabend',
    startsAt: new Date(Date.now() + 2 * 24 * 60 * 60 * 1000).toISOString(),
    location: 'Kita Sonnenschein',
  },
];

const photoAlbums = [
  {
    id: 'album-1',
    familyId: 'demo-family-001',
    title: 'Familienausflug',
    photoCount: 12,
    createdAt: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000).toISOString(),
  },
  {
    id: 'album-2',
    familyId: 'demo-family-001',
    title: 'Geburtstag Leon',
    photoCount: 24,
    createdAt: new Date(Date.now() - 15 * 24 * 60 * 60 * 1000).toISOString(),
  },
];

const parentProfiles = [
  {
    id: 'p1',
    ownerUserId: 'seed-user-miriam',
    name: 'Miriam',
    age: 34,
    city: 'Berlin',
    latitude: 52.520008,
    longitude: 13.404954,
    bio: 'Ich suche Eltern für gemeinsame Wochenendaktivitäten und ehrlichen Austausch.',
    interests: ['Spielplatz', 'Outdoor', 'Familienzeit', 'Bildung'],
    languages: ['Deutsch', 'Englisch'],
    valuesFocus: ['Gewaltfrei', 'Empathie', 'Inklusion'],
    childAges: ['3-5', '6-9'],
    familyForm: 'Kernfamilie',
    verificationLevel: 'recommended',
    phoneVerified: true,
    identityVerified: true,
    moderationChecked: true,
  },
  {
    id: 'p2',
    ownerUserId: 'seed-user-sibel',
    name: 'Sibel',
    age: 37,
    city: 'Köln',
    latitude: 50.937531,
    longitude: 6.960279,
    bio: 'Alleinerziehend, offen für neue Freundschaften mit Eltern in ähnlicher Situation.',
    interests: ['Gesundheit', 'Bildung', 'Kreativ'],
    languages: ['Deutsch', 'Türkisch'],
    valuesFocus: ['Respekt', 'Offenheit', 'Empathie'],
    childAges: ['6-9', '10-13'],
    familyForm: 'Alleinerziehend',
    verificationLevel: 'checked',
    phoneVerified: true,
    identityVerified: false,
    moderationChecked: true,
  },
];

const parentMatchingActions = [];
const parentMatchingMessages = [];
const friendChatMessages = new Map(); // roomId → [{ id, roomId, authorUserId, authorName, content, createdAt }]
const parentMatchingAllowedActions = new Set(['like', 'report', 'block', 'contact', 'pass', 'favorite']);
const parentMatchingMessageSubscribers = new Map();
const parentMatchingOtpStore = new Map();
const parentMatchingOtpRateLimit = new Map();
let parentMatchingSchemaEnsured = false;
let socialSchemaEnsured = false;

const otpTtlMs = Number.parseInt(process.env.PARENT_MATCHING_OTP_TTL_MS || `${10 * 60 * 1000}`, 10);
const otpMaxAttempts = Number.parseInt(process.env.PARENT_MATCHING_OTP_MAX_ATTEMPTS || '5', 10);
const otpRateWindowMs = Number.parseInt(
  process.env.PARENT_MATCHING_OTP_RATE_WINDOW_MS || `${10 * 60 * 1000}`,
  10,
);
const otpRateMax = Number.parseInt(process.env.PARENT_MATCHING_OTP_RATE_MAX || '3', 10);
const allowDevOtpEcho = (process.env.ALLOW_DEV_OTP_ECHO || '1') === '1' && !isProduction;

function redactSensitiveString(value) {
  const input = (value || '').toString();
  if (!input) return input;
  return input
    .replace(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi, '[EMAIL]')
    .replace(/\b\+?\d[\d\s()./-]{6,}\d\b/g, '[PHONE]')
    .replace(/\b\d{5}\b/g, '[PLZ]')
    .replace(/\b-?\d{1,3}\.\d{4,}\s*,\s*-?\d{1,3}\.\d{4,}\b/g, '[COORDS]');
}

function sanitizeLogMeta(input) {
  if (input == null) return input;
  if (typeof input === 'string') return redactSensitiveString(input);
  if (Array.isArray(input)) return input.map(item => sanitizeLogMeta(item));
  if (typeof input === 'object') {
    const out = {};
    for (const [key, value] of Object.entries(input)) {
      const lower = key.toLowerCase();
      if (
        lower.includes('token') ||
        lower.includes('secret') ||
        lower.includes('password') ||
        lower.includes('authorization') ||
        lower.includes('signature')
      ) {
        out[key] = '[REDACTED]';
        continue;
      }
      out[key] = sanitizeLogMeta(value);
    }
    return out;
  }
  return input;
}

function logSafeError(route, error, meta = {}) {
  const payload = {
    route,
    error: redactSensitiveString(error?.message || String(error || 'unknown_error')),
    meta: sanitizeLogMeta(meta),
  };
  console.error('API_ERROR', JSON.stringify(payload));
}

function maskPhone(phone) {
  const digits = (phone || '').replace(/\D/g, '');
  if (digits.length < 4) return '***';
  return `***${digits.slice(-2)}`;
}

function hashOtpForUser(userId, code) {
  return crypto
    .createHmac('sha256', runtimeOtpHashSecret)
    .update(`${userId}:${code}`, 'utf8')
    .digest('hex');
}

async function ensureParentMatchingSchemaReady() {
  if (parentMatchingSchemaEnsured) {
    return;
  }

  await prisma.$executeRawUnsafe(`
    CREATE TABLE IF NOT EXISTS "ParentMatchingProfile" (
      "id" TEXT PRIMARY KEY,
      "externalId" TEXT,
      "ownerUserId" TEXT,
      "name" TEXT NOT NULL,
      "age" INTEGER,
      "city" TEXT NOT NULL,
      "latitude" DOUBLE PRECISION,
      "longitude" DOUBLE PRECISION,
      "bio" TEXT,
      "interests" TEXT[] DEFAULT ARRAY[]::TEXT[],
      "languages" TEXT[] DEFAULT ARRAY[]::TEXT[],
      "valuesFocus" TEXT[] DEFAULT ARRAY[]::TEXT[],
      "childAges" TEXT[] DEFAULT ARRAY[]::TEXT[],
      "familyForm" TEXT NOT NULL,
      "verificationLevel" TEXT NOT NULL DEFAULT 'basic',
      "phoneVerified" BOOLEAN NOT NULL DEFAULT false,
      "identityVerified" BOOLEAN NOT NULL DEFAULT false,
      "moderationChecked" BOOLEAN NOT NULL DEFAULT false,
      "isActive" BOOLEAN NOT NULL DEFAULT true,
      "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
      "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
  `);

  await prisma.$executeRawUnsafe(`
    ALTER TABLE "ParentMatchingProfile"
    ADD COLUMN IF NOT EXISTS "externalId" TEXT,
    ADD COLUMN IF NOT EXISTS "ownerUserId" TEXT,
    ADD COLUMN IF NOT EXISTS "bio" TEXT,
    ADD COLUMN IF NOT EXISTS "interests" TEXT[] DEFAULT ARRAY[]::TEXT[],
    ADD COLUMN IF NOT EXISTS "languages" TEXT[] DEFAULT ARRAY[]::TEXT[],
    ADD COLUMN IF NOT EXISTS "valuesFocus" TEXT[] DEFAULT ARRAY[]::TEXT[],
    ADD COLUMN IF NOT EXISTS "childAges" TEXT[] DEFAULT ARRAY[]::TEXT[],
    ADD COLUMN IF NOT EXISTS "latitude" DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS "longitude" DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS "familyForm" TEXT,
    ADD COLUMN IF NOT EXISTS "verificationLevel" TEXT DEFAULT 'basic',
    ADD COLUMN IF NOT EXISTS "phoneVerified" BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS "identityVerified" BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS "moderationChecked" BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS "isActive" BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ADD COLUMN IF NOT EXISTS "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;
  `);

  await prisma.$executeRawUnsafe(`
    ALTER TABLE "ParentMatchingProfile" ALTER COLUMN "age" DROP NOT NULL;
  `);

  await prisma.$executeRawUnsafe(`
    CREATE TABLE IF NOT EXISTS "ParentMatchingAction" (
      "id" TEXT PRIMARY KEY,
      "familyId" TEXT NOT NULL,
      "profileId" TEXT NOT NULL,
      "action" TEXT NOT NULL,
      "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
      "actorUserId" TEXT
    );
  `);

  await prisma.$executeRawUnsafe(`
    ALTER TABLE "ParentMatchingAction"
    ADD COLUMN IF NOT EXISTS "actorUserId" TEXT,
    ADD COLUMN IF NOT EXISTS "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;
  `);

  await prisma.$executeRawUnsafe(`
    CREATE TABLE IF NOT EXISTS "ParentMatchingMessage" (
      "id" TEXT PRIMARY KEY,
      "familyId" TEXT NOT NULL,
      "profileId" TEXT NOT NULL,
      "authorUserId" TEXT NOT NULL,
      "authorName" TEXT NOT NULL,
      "content" TEXT NOT NULL,
      "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
  `);

  await prisma.$executeRawUnsafe(`
    ALTER TABLE "ParentMatchingMessage"
    ADD COLUMN IF NOT EXISTS "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;
  `);

  await prisma.$executeRawUnsafe(`
    CREATE UNIQUE INDEX IF NOT EXISTS "ParentMatchingProfile_externalId_key"
    ON "ParentMatchingProfile"("externalId");
  `);
  await prisma.$executeRawUnsafe(`
    CREATE INDEX IF NOT EXISTS "ParentMatchingProfile_city_idx"
    ON "ParentMatchingProfile"("city");
  `);
  await prisma.$executeRawUnsafe(`
    CREATE INDEX IF NOT EXISTS "ParentMatchingProfile_ownerUserId_idx"
    ON "ParentMatchingProfile"("ownerUserId");
  `);
  await prisma.$executeRawUnsafe(`
    CREATE INDEX IF NOT EXISTS "ParentMatchingProfile_isActive_idx"
    ON "ParentMatchingProfile"("isActive");
  `);
  await prisma.$executeRawUnsafe(`
    CREATE INDEX IF NOT EXISTS "ParentMatchingProfile_createdAt_idx"
    ON "ParentMatchingProfile"("createdAt");
  `);
  await prisma.$executeRawUnsafe(`
    CREATE INDEX IF NOT EXISTS "ParentMatchingAction_familyId_idx"
    ON "ParentMatchingAction"("familyId");
  `);
  await prisma.$executeRawUnsafe(`
    CREATE INDEX IF NOT EXISTS "ParentMatchingAction_profileId_idx"
    ON "ParentMatchingAction"("profileId");
  `);
  await prisma.$executeRawUnsafe(`
    CREATE INDEX IF NOT EXISTS "ParentMatchingAction_action_idx"
    ON "ParentMatchingAction"("action");
  `);
  await prisma.$executeRawUnsafe(`
    CREATE INDEX IF NOT EXISTS "ParentMatchingAction_createdAt_idx"
    ON "ParentMatchingAction"("createdAt");
  `);
  await prisma.$executeRawUnsafe(`
    CREATE INDEX IF NOT EXISTS "ParentMatchingAction_actorUserId_idx"
    ON "ParentMatchingAction"("actorUserId");
  `);
  await prisma.$executeRawUnsafe(`
    CREATE INDEX IF NOT EXISTS "ParentMatchingMessage_familyId_idx"
    ON "ParentMatchingMessage"("familyId");
  `);
  await prisma.$executeRawUnsafe(`
    CREATE INDEX IF NOT EXISTS "ParentMatchingMessage_profileId_idx"
    ON "ParentMatchingMessage"("profileId");
  `);
  await prisma.$executeRawUnsafe(`
    CREATE INDEX IF NOT EXISTS "ParentMatchingMessage_createdAt_idx"
    ON "ParentMatchingMessage"("createdAt");
  `);

  parentMatchingSchemaEnsured = true;
}

async function ensureSocialSchemaReady() {
  if (socialSchemaEnsured) return;
  await prisma.$executeRawUnsafe(`
    CREATE TABLE IF NOT EXISTS "FriendRegistry" (
      "code" TEXT PRIMARY KEY,
      "name" TEXT NOT NULL,
      "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
  // code -> userId, damit Push-Nachrichten den echten Empfaenger erreichen.
  await prisma.$executeRawUnsafe(
    `ALTER TABLE "FriendRegistry" ADD COLUMN IF NOT EXISTS "userId" TEXT;`
  );
  await prisma.$executeRawUnsafe(`
    CREATE TABLE IF NOT EXISTS "FriendPendingConnection" (
      "id" TEXT PRIMARY KEY,
      "toCode" TEXT NOT NULL,
      "fromCode" TEXT NOT NULL,
      "fromName" TEXT NOT NULL,
      "connectedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
  await prisma.$executeRawUnsafe(`
    CREATE TABLE IF NOT EXISTS "FriendChatMessage" (
      "id" TEXT PRIMARY KEY,
      "roomId" TEXT NOT NULL,
      "authorUserId" TEXT NOT NULL,
      "authorName" TEXT NOT NULL,
      "content" TEXT NOT NULL,
      "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
  await prisma.$executeRawUnsafe(
    `CREATE INDEX IF NOT EXISTS "idx_friendchat_room_time" ON "FriendChatMessage"("roomId", "createdAt");`
  );
  // Gelesen-Status pro Raum + Nutzer. Grundlage für ehrliche Ungelesen-Badges
  // in der Chat-Übersicht: Nachrichten nach "lastReadAt" von anderen gelten
  // als ungelesen.
  await prisma.$executeRawUnsafe(`
    CREATE TABLE IF NOT EXISTS "ChatRead" (
      "roomId" TEXT NOT NULL,
      "userId" TEXT NOT NULL,
      "lastReadAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY ("roomId", "userId")
    );
  `);
  // "Für mich löschen" (WhatsApp-Stil): Nachrichten vor "clearedAt" werden
  // für diesen Nutzer ausgeblendet; der Verlauf des anderen bleibt erhalten.
  await prisma.$executeRawUnsafe(`
    CREATE TABLE IF NOT EXISTS "ChatCleared" (
      "roomId" TEXT NOT NULL,
      "userId" TEXT NOT NULL,
      "clearedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY ("roomId", "userId")
    );
  `);
  // ─── Gruppenchat (Stufe 2) ────────────────────────────────────────────────
  // Eine Gruppe (z.B. "Kita-Gruppe Sonnenschein"). roomId = 'group_<id>'.
  await prisma.$executeRawUnsafe(`
    CREATE TABLE IF NOT EXISTS "ChatGroup" (
      "id" TEXT PRIMARY KEY,
      "name" TEXT NOT NULL,
      "ownerUserId" TEXT NOT NULL,
      "photoUrl" TEXT NOT NULL DEFAULT '',
      "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
  // Mitglieder einer Gruppe. role: 'owner' | 'member'.
  await prisma.$executeRawUnsafe(`
    CREATE TABLE IF NOT EXISTS "ChatGroupMember" (
      "groupId" TEXT NOT NULL,
      "userId" TEXT NOT NULL,
      "memberName" TEXT NOT NULL DEFAULT 'Elternteil',
      "role" TEXT NOT NULL DEFAULT 'member',
      "joinedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY ("groupId", "userId")
    );
  `);
  await prisma.$executeRawUnsafe(
    `CREATE INDEX IF NOT EXISTS "idx_groupmember_user" ON "ChatGroupMember"("userId");`
  );
  await prisma.$executeRawUnsafe(`
    CREATE TABLE IF NOT EXISTS "PendingReferral" (
      "id" TEXT PRIMARY KEY,
      "referralCode" TEXT NOT NULL,
      "inviteeId" TEXT NOT NULL,
      "inviteeName" TEXT NOT NULL,
      "ts" BIGINT NOT NULL DEFAULT 0
    );
  `);
  await prisma.$executeRawUnsafe(`
    CREATE TABLE IF NOT EXISTS "CalendarEvent" (
      "id" TEXT PRIMARY KEY,
      "userId" TEXT NOT NULL,
      "familyId" TEXT NOT NULL DEFAULT 'demo-family-001',
      "title" TEXT NOT NULL,
      "startAt" TIMESTAMPTZ NOT NULL,
      "endAt" TIMESTAMPTZ,
      "location" TEXT NOT NULL DEFAULT '',
      "person" TEXT NOT NULL DEFAULT 'Eltern',
      "allDay" BOOLEAN NOT NULL DEFAULT FALSE,
      "recurrence" TEXT NOT NULL DEFAULT 'Einmalig',
      "recurrenceEndMode" TEXT NOT NULL DEFAULT 'Kein Ende',
      "recurrenceEndDate" TIMESTAMPTZ,
      "recurrenceCount" INT,
      "reminderMinutes" INT NOT NULL DEFAULT 0,
      "packReminder" TEXT,
      "bringer" TEXT,
      "abholer" TEXT,
      "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
  await prisma.$executeRawUnsafe(`CREATE INDEX IF NOT EXISTS "idx_calendar_user" ON "CalendarEvent"("userId");`);
  // Durable friend list per user (survives reinstall). Symmetric edges are
  // written on both sides so each user can restore their own list by code.
  await prisma.$executeRawUnsafe(`
    CREATE TABLE IF NOT EXISTS "FriendEdge" (
      "ownerCode" TEXT NOT NULL,
      "friendCode" TEXT NOT NULL,
      "friendName" TEXT NOT NULL DEFAULT 'Familie',
      "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY ("ownerCode", "friendCode")
    );
  `);
  await prisma.$executeRawUnsafe(`CREATE INDEX IF NOT EXISTS "idx_friendedge_owner" ON "FriendEdge"("ownerCode");`);
  // Server-side safety: blocked users + reports (moderation trail).
  await prisma.$executeRawUnsafe(`
    CREATE TABLE IF NOT EXISTS "SafetyBlock" (
      "blockerUserId" TEXT NOT NULL,
      "blockedUserId" TEXT NOT NULL,
      "blockedName" TEXT NOT NULL DEFAULT '',
      "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY ("blockerUserId", "blockedUserId")
    );
  `);
  await prisma.$executeRawUnsafe(`CREATE INDEX IF NOT EXISTS "idx_safetyblock_blocker" ON "SafetyBlock"("blockerUserId");`);
  await prisma.$executeRawUnsafe(`
    CREATE TABLE IF NOT EXISTS "SafetyReport" (
      "id" TEXT PRIMARY KEY,
      "reporterUserId" TEXT NOT NULL,
      "reportedUserId" TEXT NOT NULL,
      "contentType" TEXT NOT NULL DEFAULT 'profile',
      "content" TEXT NOT NULL DEFAULT '',
      "reason" TEXT NOT NULL DEFAULT 'other',
      "status" TEXT NOT NULL DEFAULT 'pending',
      "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
  await prisma.$executeRawUnsafe(`CREATE INDEX IF NOT EXISTS "idx_safetyreport_reported" ON "SafetyReport"("reportedUserId");`);
  // Soft-Suspend (umkehrbar): gesperrte Accounts, gesetzt durch Moderation.
  await prisma.$executeRawUnsafe(`
    CREATE TABLE IF NOT EXISTS "SafetySuspension" (
      "userId" TEXT PRIMARY KEY,
      "reason" TEXT NOT NULL DEFAULT '',
      "suspendedBy" TEXT NOT NULL DEFAULT '',
      "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
  // Onboarding Minimal-Sync (Option A): nur unkritische Stammdaten, damit der
  // Nutzer auf einem neuen Geraet nicht erneut durchs Onboarding muss.
  // KEINE sensiblen Kinderdaten hier.
  await prisma.$executeRawUnsafe(`
    CREATE TABLE IF NOT EXISTS "OnboardingProfile" (
      "userId" TEXT PRIMARY KEY,
      "completed" BOOLEAN NOT NULL DEFAULT FALSE,
      "familyName" TEXT NOT NULL DEFAULT '',
      "parentRole" TEXT NOT NULL DEFAULT '',
      "priorities" TEXT NOT NULL DEFAULT '',
      "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
  // ── NEUES FUNDAMENT: UserProfile (uid = Identitaet, Name app-weit) ────────
  // displayName kommt aus der Registrierung. username optional, Default privat
  // + nicht auffindbar (Datenschutz fuer Familien).
  await prisma.$executeRawUnsafe(`
    CREATE TABLE IF NOT EXISTS "UserProfile" (
      "userId" TEXT PRIMARY KEY,
      "displayName" TEXT NOT NULL DEFAULT '',
      "avatarUrl" TEXT,
      "username" TEXT,
      "searchable" BOOLEAN NOT NULL DEFAULT FALSE,
      "isPrivate" BOOLEAN NOT NULL DEFAULT TRUE,
      "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
  await prisma.$executeRawUnsafe(`ALTER TABLE "UserProfile" ADD COLUMN IF NOT EXISTS "avatarUrl" TEXT;`);
  await prisma.$executeRawUnsafe(`CREATE UNIQUE INDEX IF NOT EXISTS "idx_userprofile_username" ON "UserProfile"(LOWER("username")) WHERE "username" IS NOT NULL;`);
  // Freundschaft als UID-zu-UID-Beziehung. userLow/userHigh sind die beiden
  // UIDs kanonisch sortiert (userLow < userHigh) -> genau EINE Zeile pro Paar.
  await prisma.$executeRawUnsafe(`
    CREATE TABLE IF NOT EXISTS "Friendship" (
      "userLow" TEXT NOT NULL,
      "userHigh" TEXT NOT NULL,
      "status" TEXT NOT NULL DEFAULT 'pending',
      "requestedBy" TEXT NOT NULL DEFAULT '',
      "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY ("userLow", "userHigh")
    );
  `);
  await prisma.$executeRawUnsafe(`CREATE INDEX IF NOT EXISTS "idx_friendship_low" ON "Friendship"("userLow");`);
  await prisma.$executeRawUnsafe(`CREATE INDEX IF NOT EXISTS "idx_friendship_high" ON "Friendship"("userHigh");`);
  // Kurzlebige Einladungs-Token (Link/QR): token -> einladende UID.
  await prisma.$executeRawUnsafe(`
    CREATE TABLE IF NOT EXISTS "FriendInvite" (
      "token" TEXT PRIMARY KEY,
      "userId" TEXT NOT NULL,
      "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
  // ── Phase 3a: Familien-Rezepte teilen ──────────────────────────────────────
  // Sichtbarkeit: 'public' (Fuer alle Familien) | 'friends' (Nur meine Freunde,
  // Default) | 'private' (Nur fuer mich). Zutaten/Schritte als JSON-Text.
  await prisma.$executeRawUnsafe(`
    CREATE TABLE IF NOT EXISTS "Recipe" (
      "id" TEXT PRIMARY KEY,
      "authorUserId" TEXT NOT NULL,
      "authorName" TEXT NOT NULL DEFAULT 'Familie',
      "title" TEXT NOT NULL,
      "description" TEXT NOT NULL DEFAULT '',
      "photoUrl" TEXT NOT NULL DEFAULT '',
      "ingredients" TEXT NOT NULL DEFAULT '[]',
      "steps" TEXT NOT NULL DEFAULT '[]',
      "prepMinutes" INT NOT NULL DEFAULT 0,
      "visibility" TEXT NOT NULL DEFAULT 'friends',
      "tags" TEXT NOT NULL DEFAULT '[]',
      "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
  await prisma.$executeRawUnsafe(`CREATE INDEX IF NOT EXISTS "idx_recipe_author" ON "Recipe"("authorUserId");`);
  await prisma.$executeRawUnsafe(`CREATE INDEX IF NOT EXISTS "idx_recipe_visibility" ON "Recipe"("visibility");`);
  // Reaktionen: 'cook' ("Das kochen wir nach!") | 'tasty' ("Hat geschmeckt!").
  // Genau eine Zeile pro (Rezept, Nutzer, Typ) -> togglebar.
  await prisma.$executeRawUnsafe(`
    CREATE TABLE IF NOT EXISTS "RecipeReaction" (
      "recipeId" TEXT NOT NULL,
      "userId" TEXT NOT NULL,
      "type" TEXT NOT NULL,
      "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY ("recipeId", "userId", "type")
    );
  `);
  await prisma.$executeRawUnsafe(`CREATE INDEX IF NOT EXISTS "idx_recipereaction_recipe" ON "RecipeReaction"("recipeId");`);
  socialSchemaEnsured = true;
}

// Datenschutz: grobe Rundung einer Koordinate auf ~1 km Raster (2 Dezimal-
// stellen). Fremden Nutzern wird NIEMALS die exakte Position einer Familie
// ausgeliefert — fürs "Familien in der Nähe"-Matching reicht die grobe Lage.
function coarseCoordinate(value) {
  if (value === null || value === undefined || value === '') return null;
  const num = Number(value);
  if (!Number.isFinite(num)) return null;
  return Math.round(num * 100) / 100;
}

function mapParentMatchingProfileForClient(profile) {
  return {
    id: profile.id,
    ownerUserId: profile.ownerUserId || null,
    name: profile.name,
    age: profile.age,
    city: profile.city,
    // Nur grob gerundete Position ausliefern (keine punktgenaue Adresse einer
    // Familie mit Kindern). Die genaue Distanz berechnet der Server separat.
    latitude: coarseCoordinate(profile.latitude),
    longitude: coarseCoordinate(profile.longitude),
    approximateLocation: true,
    bio: profile.bio || '',
    interests: Array.isArray(profile.interests) ? profile.interests : [],
    languages: Array.isArray(profile.languages) ? profile.languages : [],
    valuesFocus: Array.isArray(profile.valuesFocus) ? profile.valuesFocus : [],
    childAges: Array.isArray(profile.childAges) ? profile.childAges : [],
    familyForm: profile.familyForm || 'Kernfamilie',
    verificationLevel: profile.verificationLevel || 'basic',
    phoneVerified: profile.phoneVerified === true,
    identityVerified: profile.identityVerified === true,
    moderationChecked: profile.moderationChecked === true,
  };
}

async function ensureParentMatchingProfilesSeeded() {
  await ensureParentMatchingSchemaReady();

  const existingCount = await prisma.parentMatchingProfile.count({
    where: { isActive: true },
  });

  if (existingCount > 0) {
    return;
  }

  await prisma.$transaction(
    parentProfiles.map(profile =>
      prisma.parentMatchingProfile.upsert({
        where: { externalId: profile.id },
        update: {
          ownerUserId: profile.ownerUserId || null,
          name: profile.name,
          age: Number(profile.age) || 30,
          city: profile.city || 'Unbekannt',
          latitude:
            Number.isFinite(Number(profile.latitude)) ? Number(profile.latitude) : null,
          longitude:
            Number.isFinite(Number(profile.longitude)) ? Number(profile.longitude) : null,
          bio: profile.bio || '',
          interests: Array.isArray(profile.interests) ? profile.interests : [],
          languages: Array.isArray(profile.languages) ? profile.languages : [],
          valuesFocus: Array.isArray(profile.valuesFocus) ? profile.valuesFocus : [],
          childAges: Array.isArray(profile.childAges) ? profile.childAges : [],
          familyForm: profile.familyForm || 'Kernfamilie',
          verificationLevel: profile.verificationLevel || 'basic',
          phoneVerified: profile.phoneVerified === true,
          identityVerified: profile.identityVerified === true,
          moderationChecked: profile.moderationChecked === true,
          isActive: true,
        },
        create: {
          externalId: profile.id,
          ownerUserId: profile.ownerUserId || null,
          name: profile.name,
          age: Number(profile.age) || 30,
          city: profile.city || 'Unbekannt',
          latitude:
            Number.isFinite(Number(profile.latitude)) ? Number(profile.latitude) : null,
          longitude:
            Number.isFinite(Number(profile.longitude)) ? Number(profile.longitude) : null,
          bio: profile.bio || '',
          interests: Array.isArray(profile.interests) ? profile.interests : [],
          languages: Array.isArray(profile.languages) ? profile.languages : [],
          valuesFocus: Array.isArray(profile.valuesFocus) ? profile.valuesFocus : [],
          childAges: Array.isArray(profile.childAges) ? profile.childAges : [],
          familyForm: profile.familyForm || 'Kernfamilie',
          verificationLevel: profile.verificationLevel || 'basic',
          phoneVerified: profile.phoneVerified === true,
          identityVerified: profile.identityVerified === true,
          moderationChecked: profile.moderationChecked === true,
          isActive: true,
        },
      }),
    ),
  );
}

function inferCityForUser(userId) {
  const lower = (userId || '').toLowerCase();
  if (lower.includes('koeln') || lower.includes('cologne')) return 'Köln';
  if (lower.includes('hamburg')) return 'Hamburg';
  if (lower.includes('muenchen') || lower.includes('munich')) return 'München';
  if (lower.includes('frankfurt')) return 'Frankfurt';
  return 'Berlin';
}

function inferCoordinatesForCity(city) {
  switch ((city || '').toLowerCase()) {
    case 'köln':
    case 'koeln':
      return { latitude: 50.937531, longitude: 6.960279 };
    case 'hamburg':
      return { latitude: 53.551086, longitude: 9.993682 };
    case 'münchen':
    case 'muenchen':
      return { latitude: 48.137154, longitude: 11.576124 };
    case 'frankfurt':
      return { latitude: 50.110924, longitude: 8.682127 };
    default:
      return { latitude: 52.520008, longitude: 13.404954 };
  }
}

async function ensureParentMatchingProfileForUser(userId) {
  if (!userId) return;

  await ensureParentMatchingSchemaReady();
  const existing = await prisma.parentMatchingProfile.findFirst({
    where: {
      ownerUserId: userId,
      isActive: true,
    },
    select: { id: true },
  });

  if (existing) {
    return;
  }

  const city = inferCityForUser(userId);
  const coords = inferCoordinatesForCity(city);
  const shortUserId = userId.length > 10 ? userId.substring(0, 10) : userId;

  await prisma.parentMatchingProfile.upsert({
    where: { externalId: `self-${userId}` },
    update: {
      ownerUserId: userId,
      isActive: true,
    },
    create: {
      externalId: `self-${userId}`,
      ownerUserId: userId,
      name: `Elternteil ${shortUserId}`,
      age: 33,
      city,
      latitude: coords.latitude,
      longitude: coords.longitude,
      bio: 'Ich suche Familien für freundlichen Austausch und passende Playdates.',
      interests: ['Familienzeit', 'Spielplatz'],
      languages: ['Deutsch'],
      valuesFocus: ['Respekt', 'Empathie'],
      childAges: ['3-5', '6-9'],
      familyForm: 'Kernfamilie',
      verificationLevel: 'basic',
      phoneVerified: false,
      identityVerified: false,
      moderationChecked: false,
      isActive: true,
    },
  });
}

function latestActionByProfile(actions) {
  const latest = new Map();
  for (const action of actions) {
    if (!latest.has(action.profileId)) {
      latest.set(action.profileId, action.action);
    }
  }
  return latest;
}

function parentMatchingStreamKey(familyId, profileId) {
  return `${familyId}::${profileId}`;
}

function publishParentMatchingMessage(item) {
  const key = parentMatchingStreamKey(item.familyId, item.profileId);
  const subscribers = parentMatchingMessageSubscribers.get(key);
  if (!subscribers || subscribers.size === 0) {
    return;
  }

  const payload = `data: ${JSON.stringify({ type: 'message', item })}\n\n`;
  for (const response of subscribers) {
    response.write(payload);
  }
}

async function getMyParentMatchingProfile(userId) {
  await ensureParentMatchingSchemaReady();
  return prisma.parentMatchingProfile.findFirst({
    where: {
      ownerUserId: userId,
      isActive: true,
    },
    orderBy: { createdAt: 'desc' },
  });
}

async function getMutualConnectionProfileIds(familyId, userId) {
  await ensureParentMatchingSchemaReady();

  const myOwnedProfiles = await prisma.parentMatchingProfile.findMany({
    where: {
      ownerUserId: userId,
      isActive: true,
    },
    select: { id: true },
  });
  const myOwnedProfileIds = myOwnedProfiles.map(item => item.id);
  if (myOwnedProfileIds.length === 0) {
    return [];
  }

  const myActions = await prisma.parentMatchingAction.findMany({
    where: {
      familyId,
      actorUserId: userId,
    },
    orderBy: { createdAt: 'desc' },
  });

  const latestMine = latestActionByProfile(myActions);
  const myLikedProfileIds = Array.from(latestMine.entries())
    .filter(([, action]) => action === 'like')
    .map(([profileId]) => profileId);

  if (myLikedProfileIds.length === 0) {
    return [];
  }

  const likedProfiles = await prisma.parentMatchingProfile.findMany({
    where: { id: { in: myLikedProfileIds } },
    select: { id: true, ownerUserId: true },
  });

  const targetOwnerIds = Array.from(new Set(
    likedProfiles
      .map(item => item.ownerUserId)
      .filter(value => typeof value === 'string' && value.trim().length > 0),
  ));

  if (targetOwnerIds.length === 0) {
    return [];
  }

  // Each parent's consent is recorded in that parent's own family context.
  const reverseActions = await prisma.parentMatchingAction.findMany({
    where: {
      OR: targetOwnerIds.map(ownerId => ({
        familyId: ownFamilyId(ownerId),
        actorUserId: ownerId,
      })),
      profileId: { in: myOwnedProfileIds },
    },
    orderBy: { createdAt: 'desc' },
  });

  const reverseLatest = new Map();
  for (const action of reverseActions) {
    const key = `${action.actorUserId}::${action.profileId}`;
    if (!reverseLatest.has(key)) {
      reverseLatest.set(key, action.action);
    }
  }

  const reverseLikeByOwner = new Map();
  for (const ownerId of targetOwnerIds) {
    reverseLikeByOwner.set(ownerId, false);
  }
  for (const [key, action] of reverseLatest.entries()) {
    const ownerId = key.split('::')[0];
    if (action === 'like') {
      reverseLikeByOwner.set(ownerId, true);
    }
  }

  return likedProfiles
    .filter(item => reverseLikeByOwner.get(item.ownerUserId) === true)
    .map(item => item.id);
}

function getMutualConnectionProfileIdsInMemory(familyId, userId) {
  const myOwnedProfileIds = parentProfiles
    .filter(item => item.ownerUserId === userId)
    .map(item => item.id);

  if (myOwnedProfileIds.length === 0) {
    return [];
  }

  const myActions = parentMatchingActions
    .filter(item => item.familyId === familyId && item.userId === userId)
    .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());

  const latestMine = new Map();
  for (const action of myActions) {
    if (!latestMine.has(action.profileId)) {
      latestMine.set(action.profileId, action.action);
    }
  }
  const myLikedProfileIds = Array.from(latestMine.entries())
    .filter(([, action]) => action === 'like')
    .map(([profileId]) => profileId);

  if (myLikedProfileIds.length === 0) {
    return [];
  }

  const likedProfiles = parentProfiles.filter(item => myLikedProfileIds.includes(item.id));
  const targetOwnerIds = Array.from(new Set(
    likedProfiles
      .map(item => item.ownerUserId)
      .filter(value => typeof value === 'string' && value.trim().length > 0),
  ));

  const reverseActions = parentMatchingActions
    .filter(item => item.familyId === ownFamilyId(item.userId))
    .filter(item => targetOwnerIds.includes(item.userId))
    .filter(item => myOwnedProfileIds.includes(item.profileId))
    .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());

  const reverseLatest = new Map();
  for (const action of reverseActions) {
    const key = `${action.userId}::${action.profileId}`;
    if (!reverseLatest.has(key)) {
      reverseLatest.set(key, action.action);
    }
  }

  const reverseLikeByOwner = new Map();
  for (const ownerId of targetOwnerIds) {
    reverseLikeByOwner.set(ownerId, false);
  }
  for (const [key, action] of reverseLatest.entries()) {
    const ownerId = key.split('::')[0];
    if (action === 'like') {
      reverseLikeByOwner.set(ownerId, true);
    }
  }

  return likedProfiles
    .filter(item => reverseLikeByOwner.get(item.ownerUserId) === true)
    .map(item => item.id);
}

function ensureParentMatchingProfileForUserInMemory(userId) {
  if (!userId) return;
  const exists = parentProfiles.some(item => item.ownerUserId === userId);
  if (exists) return;

  const city = inferCityForUser(userId);
  const coords = inferCoordinatesForCity(city);
  const shortUserId = userId.length > 10 ? userId.substring(0, 10) : userId;
  parentProfiles.push({
    id: `self-${userId}`,
    ownerUserId: userId,
    name: `Elternteil ${shortUserId}`,
    age: 33,
    city,
    latitude: coords.latitude,
    longitude: coords.longitude,
    bio: 'Ich suche Familien für freundlichen Austausch und passende Playdates.',
    interests: ['Familienzeit', 'Spielplatz'],
    languages: ['Deutsch'],
    valuesFocus: ['Respekt', 'Empathie'],
    childAges: ['3-5', '6-9'],
    familyForm: 'Kernfamilie',
    verificationLevel: 'basic',
    phoneVerified: false,
    identityVerified: false,
    moderationChecked: false,
  });
}

function getMyParentMatchingProfileInMemory(userId) {
  if (!userId) return null;
  return parentProfiles.find(item => item.ownerUserId === userId) || null;
}

function upsertMyParentMatchingProfileInMemory({
  userId,
  name,
  age,
  city,
  latitude,
  longitude,
  bio,
  interests,
  languages,
  valuesFocus,
  childAges,
  familyForm,
}) {
  const existingIndex = parentProfiles.findIndex(item => item.ownerUserId === userId);
  const existing = existingIndex >= 0 ? parentProfiles[existingIndex] : null;
  const next = {
    id: existing?.id || `self-${userId}`,
    ownerUserId: userId,
    name,
    age,
    city,
    latitude,
    longitude,
    bio,
    interests,
    languages,
    valuesFocus,
    childAges,
    familyForm,
    verificationLevel: existing?.verificationLevel || 'basic',
    phoneVerified: existing?.phoneVerified === true,
    identityVerified: existing?.identityVerified === true,
    moderationChecked: existing?.moderationChecked === true,
    isActive: true,
    updatedAt: new Date().toISOString(),
    createdAt: existing?.createdAt || new Date().toISOString(),
  };

  if (existingIndex >= 0) {
    parentProfiles[existingIndex] = next;
  } else {
    parentProfiles.unshift(next);
  }
  return next;
}

const familyContacts = [
  {
    userId: 'host_001',
    displayName: 'Mia Schneider',
    city: 'Berlin',
    childrenSummary: 'Kind: 4 Jahre',
  },
  {
    userId: 'host_002',
    displayName: 'Lena Yilmaz',
    city: 'Berlin',
    childrenSummary: 'Kinder: 7 und 10 Jahre',
  },
  {
    userId: 'host_003',
    displayName: 'Noah Weber',
    city: 'Berlin',
    childrenSummary: 'Kind: 2 Jahre',
  },
];

const familyRequests = [
  {
    id: 'req_1',
    fromUserId: 'host_003',
    toUserId: 'host_demo_001',
    fromDisplayName: 'Noah Weber',
    sentAt: new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString(),
    status: 'pending',
  },
];

const events = [
  {
    id: 'event-1',
    hosterId: 'host_001',
    title: 'Spielplatz Treffen',
    description: 'Treffen für Kinder zum gemeinsamen Spielen auf dem Spielplatz',
    category: 'socialGathering',
    ageGroups: ['toddler', 'preschool'],
    location: 'Zentralpark, Berlin',
    latitude: 52.52,
    longitude: 13.405,
    eventDate: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000).toISOString(),
    createdAt: new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString(),
    paymentDate: new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString(),
    maxParticipants: 15,
    currentParticipants: 5,
    photoUrl: '',
    status: 'active',
    visibility: 'publicNearby',
    shareRadiusKm: 25,
    invitedUserIds: [],
    inviteCodeExpiresAt: null,
  },
  {
    id: 'event-2',
    hosterId: 'host_002',
    title: 'Kinderturnen im Park',
    description: 'Altersgerechtes Turntraining für kleine Sportler',
    category: 'sports',
    ageGroups: ['elementary'],
    location: 'Sportplatz Mitte, Berlin',
    latitude: 52.53,
    longitude: 13.415,
    eventDate: new Date(Date.now() + 5 * 24 * 60 * 60 * 1000).toISOString(),
    createdAt: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000).toISOString(),
    paymentDate: new Date(Date.now() - 60 * 60 * 1000).toISOString(),
    maxParticipants: 20,
    currentParticipants: 12,
    photoUrl: '',
    status: 'active',
    visibility: 'publicNearby',
    shareRadiusKm: 25,
    invitedUserIds: [],
    inviteCodeExpiresAt: null,
  },
];

const eventInvitations = [];
const eventParticipations = [];
const eventInviteCodes = {};
const eventInviteExpiresAt = {};
const paymentTransactions = [];
const eventChatMessages = {};
const eventChatReports = [];

function generateInviteCode(eventId) {
  const suffix = (eventId || '').slice(-4).toUpperCase() || '0000';
  return `PP-${suffix}`;
}

function isInviteExpired(eventId) {
  const expiresAt = eventInviteExpiresAt[eventId];
  if (!expiresAt) return false;
  return new Date() > new Date(expiresAt);
}

function isInviteExpiredAt(expiresAt) {
  if (!expiresAt) return false;
  return new Date() > new Date(expiresAt);
}

function canViewerSeeEvent(event, viewerUserId) {
  if (!event || event.status !== 'active') return false;
  if (event.hosterId === viewerUserId) return true;

  if (event.visibility === 'privateOnly') return false;

  if (event.visibility === 'familyCircle') {
    return familyRequests.some(
      request =>
        request.status === 'accepted' &&
        ((request.fromUserId === viewerUserId && request.toUserId === event.hosterId) ||
          (request.toUserId === viewerUserId && request.fromUserId === event.hosterId)),
    );
  }

  if (event.visibility === 'inviteOnly') {
    return eventInvitations.some(
      invitation =>
        invitation.eventId === event.id &&
        invitation.invitedUserId === viewerUserId &&
        invitation.status === 'accepted',
    );
  }

  return true;
}

function generateId(prefix) {
  return `${prefix}-${Date.now()}-${Math.floor(Math.random() * 1000)}`;
}

async function ensureDemoFamilyContext(familyId) {
  const targetFamilyId = (familyId || DEMO_FAMILY_ID).toString().trim() || DEMO_FAMILY_ID;

  if (!allowDemoBootstrap) {
    const existingFamily = await prisma.family.findUnique({ where: { id: targetFamilyId } });
    if (!existingFamily) {
      throw new Error('Familie nicht gefunden');
    }
    return targetFamilyId;
  }

  await prisma.user.upsert({
    where: { id: DEMO_USER_ID },
    update: {},
    create: {
      id: DEMO_USER_ID,
      email: 'demo-host-001@parentpeak.local',
      passwordHash: 'demo',
      passwordSalt: 'demo',
      firstName: 'Demo',
      lastName: 'Host',
    },
  });

  await prisma.family.upsert({
    where: { id: targetFamilyId },
    update: {},
    create: {
      id: targetFamilyId,
      name: targetFamilyId === DEMO_FAMILY_ID ? 'Demo Familie' : `Familie ${targetFamilyId}`,
      createdById: DEMO_USER_ID,
      memberUsers: {
        connect: [{ id: DEMO_USER_ID }],
      },
    },
  });

  return targetFamilyId;
}

function parseTodoDescription(description) {
  if (!description || typeof description !== 'string') {
    return { assigneeName: 'Familie', category: 'Allgemein' };
  }

  try {
    const parsed = JSON.parse(description);
    return {
      assigneeName: (parsed.assigneeName || 'Familie').toString(),
      category: (parsed.category || 'Allgemein').toString(),
    };
  } catch (_) {
    return { assigneeName: 'Familie', category: 'Allgemein' };
  }
}

function buildTodoDescription(meta) {
  return JSON.stringify({
    assigneeName: (meta.assigneeName || 'Familie').toString(),
    category: (meta.category || 'Allgemein').toString(),
  });
}

function mapTodoRecordToApiItem(record) {
  const meta = parseTodoDescription(record.description);
  return {
    id: record.id,
    familyId: record.familyId,
    title: record.title,
    completed: Boolean(record.done),
    assigneeName: meta.assigneeName,
    category: meta.category,
    createdAt: record.createdAt,
    updatedAt: record.completedAt || null,
  };
}

function mapShoppingRecordToApiItem(record) {
  return {
    id: record.id,
    familyId: record.familyId,
    name: record.name,
    checked: Boolean(record.bought),
    category: 'Allgemein',
    createdAt: record.createdAt,
    updatedAt: record.boughtAt || null,
  };
}

function buildLocalEmail(identifier) {
  const safeIdentifier = (identifier || 'user')
    .toString()
    .toLowerCase()
    .replace(/[^a-z0-9._-]/g, '_');
  return `${safeIdentifier}@parentpeak.local`;
}

async function ensureBackendUser(userId, displayName) {
  const trimmedUserId = (userId || DEMO_USER_ID).toString().trim() || DEMO_USER_ID;
  const [firstName, ...restName] = (displayName || trimmedUserId).toString().split(' ');

  if (!allowDemoBootstrap) {
    const existingUser = await prisma.user.findUnique({ where: { id: trimmedUserId } });
    if (!existingUser) {
      throw new Error('Benutzer nicht gefunden');
    }
    return trimmedUserId;
  }

  await prisma.user.upsert({
    where: { id: trimmedUserId },
    update: {},
    create: {
      id: trimmedUserId,
      email: buildLocalEmail(trimmedUserId),
      passwordHash: 'demo',
      passwordSalt: 'demo',
      firstName: firstName || 'Demo',
      lastName: restName.join(' ') || 'User',
    },
  });

  return trimmedUserId;
}

async function ensureAuthenticatedEventUser(req, userId) {
  if (!req.firebaseUid) {
    return ensureBackendUser(userId, req.body.userName || userId);
  }
  if (req.firebaseUid !== userId) {
    throw new Error('Firebase UID stimmt nicht mit userId ueberein');
  }

  return ensureVerifiedBackendUser(req.firebaseUid);
}

class FamilyContextError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

function ownFamilyId(firebaseUid) {
  if (typeof firebaseUid !== 'string' || !firebaseUid || firebaseUid !== firebaseUid.trim()) {
    throw new FamilyContextError(401, 'identity_required', 'Firebase-Anmeldung erforderlich');
  }
  return `account-family-v1-${crypto.createHash('sha256').update(firebaseUid).digest('hex')}`;
}

async function ensureVerifiedBackendUser(firebaseUid) {
  ownFamilyId(firebaseUid);
  const existingUser = await prisma.user.findUnique({ where: { id: firebaseUid } });
  if (existingUser) return existingUser.id;

  if (!firebaseAdmin) {
    throw new FamilyContextError(503, 'identity_unavailable', 'Kontopruefung derzeit nicht verfuegbar');
  }
  const account = await firebaseAdmin.auth().getUser(firebaseUid);
  if (account.uid !== firebaseUid || account.disabled) {
    throw new FamilyContextError(401, 'identity_required', 'Firebase-Konto ist nicht gueltig');
  }
  const email = account.emailVerified && account.email
    ? account.email.trim().toLowerCase()
    : `firebase-${crypto.createHash('sha256').update(account.uid).digest('hex')}@firebase.local.invalid`;
  const [firstName, ...lastName] = (account.displayName || '').trim().split(/\s+/);
  const passwordSalt = crypto.randomBytes(32).toString('hex');
  try {
    const user = await prisma.user.upsert({
      where: { id: account.uid },
      update: {},
      create: {
        id: account.uid,
        email,
        passwordHash: crypto.scryptSync(crypto.randomBytes(32), passwordSalt, 64).toString('hex'),
        passwordSalt,
        firstName: firstName || null,
        lastName: lastName.join(' ') || null,
      },
    });
    return user.id;
  } catch (error) {
    if (error?.code !== 'P2002') throw error;
    // A concurrent provision of this exact UID is safe; email matching is not.
    const concurrentUser = await prisma.user.findUnique({ where: { id: firebaseUid } });
    if (concurrentUser) return concurrentUser.id;
    throw new FamilyContextError(409, 'account_conflict', 'Backend-Kontozuordnung widerspruechlich');
  }
}

function assertOwnFamily(family, firebaseUid) {
  if (family.createdById !== firebaseUid ||
      family.memberUsers.length !== 1 || family.memberUsers[0].id !== firebaseUid) {
    throw new FamilyContextError(409, 'family_conflict', 'Privater Familienkontext widerspruechlich');
  }
  return family;
}

async function resolveOwnFamily(firebaseUid) {
  const id = ownFamilyId(firebaseUid);
  await ensureVerifiedBackendUser(firebaseUid);
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      return await prisma.$transaction(async transaction => {
        const family = await transaction.family.upsert({
          where: { id },
          update: {},
          create: {
            id,
            name: 'Familie',
            createdById: firebaseUid,
            memberUsers: { connect: [{ id: firebaseUid }] },
          },
          include: { memberUsers: { select: { id: true } } },
        });
        return assertOwnFamily(family, firebaseUid);
      }, { isolationLevel: 'Serializable' });
    } catch (error) {
      if (attempt < 2 && ['P2034', 'P2002'].includes(error?.code)) continue;
      throw error;
    }
  }
}

async function requireOwnFamily(req, res, next) {
  try {
    const id = ownFamilyId(req.firebaseUid);
    for (const claimedId of [req.query?.familyId, req.body?.familyId]) {
      if (claimedId !== undefined &&
          (typeof claimedId !== 'string' || claimedId !== id)) {
        throw new FamilyContextError(403, 'not_owner', 'Nur fuer die eigene Familie erlaubt');
      }
    }
    req.ownFamily = await resolveOwnFamily(req.firebaseUid);
    return next();
  } catch (error) {
    return respondFamilyPersistenceError(res, 'Familienkontext', error);
  }
}

function respondFamilyPersistenceError(res, label, error) {
  console.error(`${label}:`, error?.code || error?.name || 'Error');
  const status = error instanceof FamilyContextError ? error.status : 503;
  return res.status(status).json({
    error: error instanceof FamilyContextError ? error.message : 'Familiendaten derzeit nicht verfuegbar',
    code: error instanceof FamilyContextError ? error.code : 'persistence_unavailable',
  });
}

function allowPrivateFamilyFallback() {
  return process.env.NODE_ENV !== 'production' && !disableInMemoryFallbacks;
}

// Validiert einen Pfad-/Request-Parameter gegen die aufgeloeste eigene Familie.
// Der reservierte Selector 'own' bedeutet "Familie der Token-UID". Eine explizite
// echte Familien-ID ist nur zulaessig, wenn sie exakt der eigenen entspricht.
// Die aufgeloeste Familien-ID ist niemals eine Berechtigung an sich; sie wird
// ausschliesslich aus req.ownFamily (verifizierte UID + Owner-Pruefung) abgeleitet.
function assertOwnFamilyParam(req, claimedFamilyId) {
  const ownId = req.ownFamily.id;
  if (claimedFamilyId === 'own') return ownId;
  if (typeof claimedFamilyId !== 'string' || claimedFamilyId !== ownId) {
    throw new FamilyContextError(403, 'not_owner', 'Nur fuer die eigene Familie erlaubt');
  }
  return ownId;
}

async function exportOwnFamilyItems(firebaseUid) {
  const id = ownFamilyId(firebaseUid);
  return prisma.$transaction(async transaction => {
    const family = await transaction.family.findUnique({
      where: { id },
      include: { memberUsers: { select: { id: true } } },
    });
    if (!family) return { todos: [], shoppingItems: [], mealPlans: [] };
    assertOwnFamily(family, firebaseUid);
    const [todos, shoppingItems, mealPlans] = await Promise.all([
      transaction.todo.findMany({ where: { familyId: id }, orderBy: { createdAt: 'desc' } }),
      transaction.shoppingItem.findMany({ where: { familyId: id }, orderBy: { createdAt: 'desc' } }),
      // MealPlan hat keine Family-Relation (familyId ist nur ein String), daher
      // explizit ueber die aufgeloeste eigene Familien-ID.
      transaction.mealPlan.findMany({
        where: { familyId: id },
        orderBy: { date: 'desc' },
        include: { meals: { orderBy: { createdAt: 'asc' } } },
      }),
    ]);
    return { todos, shoppingItems, mealPlans };
  }, { isolationLevel: 'Serializable' });
}

function paymentError(status, message) {
  return Object.assign(new Error(message), { paymentHttpStatus: status, httpStatus: status });
}

function assertPaymentActor(req) {
  for (const claimed of [
    req.body?.payerId, req.body?.payerUid, req.body?.firebaseUid,
    req.query?.payerId, req.query?.payerUid, req.query?.firebaseUid,
  ]) {
    if (claimed !== undefined && claimed !== req.firebaseUid) {
      throw paymentError(403, 'Nur fuer das eigene Zahlerkonto erlaubt');
    }
  }
}

function respondPaymentError(res, error) {
  if (!error.paymentHttpStatus) {
    console.error('Payment operation unavailable:', error?.code || error?.name || 'Error');
  }
  return res.status(error.paymentHttpStatus || 503).json({
    error: error.paymentHttpStatus ? error.message : 'Zahlungsdienst derzeit nicht verfuegbar',
  });
}

async function ensurePaymentContext(eventId, hosterId, payerUid, body = {}) {
  if (typeof eventId !== 'string' || !eventId.trim()) {
    throw paymentError(400, 'eventId erforderlich');
  }
  const eventRecord = await prisma.event.findUnique({ where: { id: eventId.trim() } });
  if (!eventRecord) throw paymentError(404, 'Gespeichertes Event nicht gefunden');
  if (hosterId !== undefined && hosterId !== eventRecord.hosterId) {
    throw paymentError(403, 'Hoster stimmt nicht mit dem Event ueberein');
  }
  if (['cancelled', 'completed'].includes(eventRecord.status)) {
    throw paymentError(409, 'Event nicht zahlbar');
  }
  const amount = Number(eventRecord.costPerPerson);
  const amountMinor = Math.round(amount * 100);
  const currency = String(eventRecord.currency || '').toLowerCase();
  // This checkout supports two-decimal EUR prices only, not arbitrary currency exponents.
  if (!Number.isSafeInteger(amountMinor) || amountMinor <= 0 ||
      Math.abs(amount * 100 - amountMinor) > 0.00001 || currency !== 'eur') {
    throw paymentError(409, 'Kein unterstuetzter gespeicherter Eventpreis');
  }
  if ((body.amount !== undefined && Number(body.amount) !== amount) ||
      (body.currency !== undefined && String(body.currency).toLowerCase() !== currency)) {
    throw paymentError(409, 'Preis stimmt nicht mit dem gespeicherten Event ueberein');
  }
  const payer = await prisma.user.findUnique({ where: { id: payerUid } });
  if (!payer) throw paymentError(409, 'Zahlerkonto muss zuerst synchronisiert werden');
  return { eventId: eventRecord.id, hosterId: eventRecord.hosterId, payerUid, amount, amountMinor, currency };
}

function paymentPayer(record) {
  const audit = getPaymentAuditDetails(record);
  // Legacy rows stored the host as userId and cannot establish a payer.
  return audit.bindingVersion === 1 && audit.payerUid === record.userId ? record.userId : null;
}

function paymentHost(record) {
  return getPaymentAuditDetails(record).hosterId || record.userId;
}

function assertPaymentOwner(record, uid, { payerOnly = false, hostOnly = false } = {}) {
  if (!record) throw paymentError(404, 'Transaktion nicht gefunden');
  if (hostOnly ? paymentHost(record) !== uid
    : payerOnly ? paymentPayer(record) !== uid
      : paymentPayer(record) !== uid && paymentHost(record) !== uid) {
    throw paymentError(403, 'Kein Zugriff auf diese Transaktion');
  }
}

async function verifyStripePaymentRecord(record) {
  if (!stripe) throw paymentError(503, 'Stripe ist nicht konfiguriert');
  const audit = getPaymentAuditDetails(record);
  if (!paymentPayer(record) || audit.paymentMethod !== 'stripe') {
    throw paymentError(409, 'Zahlung ohne sichere Provider-/Zahlerbindung nicht unterstuetzt');
  }
  const intent = await stripe.paymentIntents.retrieve(record.stripePaymentIntentId, {
    expand: ['latest_charge'],
  });
  const expectedAmount = Math.round(Number(record.amount) * 100);
  if (intent.id !== record.stripePaymentIntentId ||
      intent.metadata?.orderId !== record.id ||
      intent.metadata?.payerUid !== paymentPayer(record) ||
      intent.metadata?.eventId !== record.eventId ||
      intent.metadata?.hosterId !== paymentHost(record) ||
      intent.amount !== expectedAmount ||
      intent.currency !== String(record.currency).toLowerCase() ||
      (intent.status === 'succeeded' && intent.amount_received !== expectedAmount)) {
    throw paymentError(409, 'Stripe-Nachweis stimmt nicht mit dem gespeicherten Auftrag ueberein');
  }
  let status = 'pending';
  if (intent.status === 'succeeded') status = 'completed';
  // A declined PaymentIntent can still be retried; only cancellation is terminal.
  if (intent.status === 'canceled') status = 'failed';
  const charge = intent.latest_charge;
  if (charge && typeof charge === 'object' && charge.refunded === true &&
      charge.amount_refunded === expectedAmount && charge.payment_intent === intent.id &&
      charge.currency === intent.currency) status = 'refunded';
  return { intent, status };
}

async function syncStripePaymentRecord(record, verifiedByType = 'stripe_api') {
  const { intent, status } = await verifyStripePaymentRecord(record);
  const result = await persistVerifiedPaymentStatus(record, status, verifiedByType);
  return { ...result, intent };
}

async function persistVerifiedPaymentStatus(record, status, verifiedByType) {
  const currentStatus = normalizeStoredPaymentStatus(record.status);
  if (!canTransitionPaymentStatus(currentStatus, status)) {
    throw paymentError(409, 'Providerstatus kann den gespeicherten Status nicht ersetzen');
  }
  const now = new Date();
  const audit = getPaymentAuditDetails(record);
  await prisma.paymentTransaction.updateMany({
    where: { id: record.id, status: record.status },
    data: {
      status,
      verifiedAt: now,
      verifiedByType,
      ...(status === 'refunded' ? { refundedAt: now, refundedAmount: record.amount } : {}),
      auditDetails: {
        ...audit,
        providerVerified: true,
        ...(status === 'completed' ? { completedAt: audit.completedAt || now.toISOString() } : {}),
        ...(status === 'failed' ? { failedAt: now.toISOString() } : {}),
        ...(status === 'refunded' ? { refundedAt: now.toISOString() } : {}),
      },
    },
  });
  const updated = await prisma.paymentTransaction.findUnique({ where: { id: record.id } });
  const item = mapPaymentRecordToApiItem(updated);
  await updateEventPaymentDateIfCompleted(item);
  return { item };
}

async function findPaymentRecord(where) {
  return prisma.paymentTransaction.findUnique({ where });
}

async function findPaymentRecords(args) {
  return prisma.paymentTransaction.findMany(args);
}

function normalizeStoredPaymentStatus(value) {
  if (value === 'succeeded') return 'completed';
  return normalizePaymentStatus(value) || 'pending';
}

function getPaymentAuditDetails(record) {
  if (!record?.auditDetails || typeof record.auditDetails !== 'object') {
    return {};
  }
  return record.auditDetails;
}

function mapPaymentRecordToApiItem(record) {
  const audit = getPaymentAuditDetails(record);
  const status = normalizeStoredPaymentStatus(record.status);
  return {
    id: record.id,
    mode: audit.mode || 'prisma',
    eventId: record.eventId,
    hosterId: audit.hosterId || record.userId,
    payerUid: paymentPayer(record),
    amount: Number(record.amount),
    currency: record.currency,
    status,
    paymentMethod: audit.paymentMethod || 'stripe',
    providerTransactionRef: audit.providerTransactionRef || record.stripePaymentIntentId || null,
    providerVerified: Boolean(paymentPayer(record) && record.verifiedAt),
    stripePaymentIntentId: record.stripePaymentIntentId || null,
    createdAt: record.createdAt,
    updatedAt: record.updatedAt,
    completedAt: audit.completedAt || (status === 'completed' ? (record.verifiedAt || record.updatedAt) : null),
    failedAt: audit.failedAt || null,
    refundedAt: record.refundedAt || audit.refundedAt || null,
  };
}

function mapDbEventStatusToApi(status) {
  if (status === 'upcoming' || status === 'ongoing') return 'active';
  if (status === 'completed') return 'completed';
  if (status === 'cancelled') return 'cancelled';
  return 'active';
}

function mapApiEventStatusToDb(status) {
  const normalized = (status || '').toString().trim().toLowerCase();
  if (!normalized || normalized === 'active') return 'upcoming';
  if (['upcoming', 'ongoing', 'completed', 'cancelled'].includes(normalized)) {
    return normalized;
  }
  return 'upcoming';
}

function getInMemoryEventById(eventId) {
  return events.find(item => item.id === eventId) || null;
}

// Felder des Event-Modells OHNE die optionale ageGroups-Spalte. Wird als
// expliziter Fallback-select genutzt, falls die ageGroups-Migration in der
// Zieldatenbank noch nicht angewandt wurde (z.B. Code live vor Migration).
const EVENT_SCALAR_SELECT_WITHOUT_AGE_GROUPS = {
  id: true,
  title: true,
  description: true,
  hosterId: true,
  familyId: true,
  startDate: true,
  endDate: true,
  location: true,
  latitude: true,
  longitude: true,
  status: true,
  eventType: true,
  participationMode: true,
  externalUrl: true,
  visibility: true,
  shareRadiusKm: true,
  inviteCode: true,
  inviteCodeExpiresAt: true,
  seriesId: true,
  costPerPerson: true,
  currency: true,
  maxParticipants: true,
  imageUrl: true,
  createdAt: true,
  updatedAt: true,
};

function isMissingAgeGroupsColumnError(error) {
  const message = String(error && error.message ? error.message : error);
  return message.includes('ageGroups') && /does not exist|column/i.test(message);
}

// Robuste Variante von prisma.event.findMany: Scheitert die Query daran, dass
// die ageGroups-Spalte in der DB (noch) fehlt, wird transparent erneut ohne
// diese Spalte geladen und ageGroups mit [] ergänzt. So funktioniert der
// Event-Feed sowohl vor als auch nach der Migration.
async function resilientEventFindMany(args) {
  try {
    return await prisma.event.findMany(args);
  } catch (error) {
    if (!isMissingAgeGroupsColumnError(error)) throw error;
    const fallbackArgs = { ...args };
    // include und select schließen sich bei Prisma gegenseitig aus. Wir bauen
    // einen select, der die bisherigen Relationen (include) übernimmt.
    const relations = fallbackArgs.include || {};
    delete fallbackArgs.include;
    fallbackArgs.select = {
      ...EVENT_SCALAR_SELECT_WITHOUT_AGE_GROUPS,
      ...relations,
    };
    const rows = await prisma.event.findMany(fallbackArgs);
    return rows.map(row => ({ ...row, ageGroups: [] }));
  }
}

function mapEventRecordToApiItem(record, options = {}) {
  const memoryEvent = getInMemoryEventById(record.id);
  const currentParticipants = Number(options.currentParticipants || 0);
  return {
    id: record.id,
    hosterId: record.hosterId,
    title: record.title,
    description: record.description || '',
    participationMode: record.participationMode || 'legacyApproval',
    externalUrl: record.externalUrl || null,
    category: record.eventType || memoryEvent?.category || 'other',
    ageGroups: Array.isArray(record.ageGroups) && record.ageGroups.length > 0
      ? record.ageGroups
      : (Array.isArray(memoryEvent?.ageGroups) ? memoryEvent.ageGroups : []),
    location: record.location || '',
    latitude: Number(record.latitude || 0),
    longitude: Number(record.longitude || 0),
    eventDate: record.startDate,
    createdAt: record.createdAt,
    paymentDate: memoryEvent?.paymentDate || null,
    maxParticipants: Number(record.maxParticipants || memoryEvent?.maxParticipants || 20),
    currentParticipants,
    photoUrl: record.imageUrl || memoryEvent?.photoUrl || '',
    status: mapDbEventStatusToApi(record.status),
    price: record.costPerPerson != null ? Number(record.costPerPerson) : (memoryEvent?.price ?? null),
    visibility: record.visibility || memoryEvent?.visibility || 'publicNearby',
    shareRadiusKm: Number(record.shareRadiusKm || memoryEvent?.shareRadiusKm || 25),
    invitedUserIds: Array.isArray(memoryEvent?.invitedUserIds) ? memoryEvent.invitedUserIds : [],
    inviteCode: record.inviteCode || eventInviteCodes[record.id] || null,
    inviteCodeExpiresAt:
      record.inviteCodeExpiresAt || eventInviteExpiresAt[record.id] || memoryEvent?.inviteCodeExpiresAt || null,
  };
}

function mapInvitationRecordToApiItem(record) {
  return {
    id: record.id,
    eventId: record.eventId,
    hostUserId: null,
    invitedUserId: record.userId,
    createdAt: record.createdAt,
    updatedAt: record.updatedAt,
    status: record.status === 'invited' ? 'pending' : CONFIRMED.includes(record.status) ? 'accepted' : record.status,
  };
}

function mapParticipationRecordToApiItem(record) {
  const approvedAt = record.status === 'approved' ? record.updatedAt : null;
  const declinedAt = record.status === 'declined' ? record.updatedAt : null;
  const cancelledAt = record.status === 'cancelled' ? record.updatedAt : null;
  return {
    id: record.id,
    eventId: record.eventId,
    userId: record.userId,
    requestedAt: record.createdAt,
    approvedAt,
    declinedAt,
    cancelledAt,
    status: CONFIRMED.includes(record.status) ? 'approved' : record.status,
  };
}

async function buildParticipantCountMap(eventIds) {
  if (!Array.isArray(eventIds) || eventIds.length === 0) {
    return new Map();
  }

  const grouped = await prisma.eventParticipation.groupBy({
    by: ['eventId'],
    where: {
      eventId: { in: eventIds },
      status: { in: ['approved', 'accepted', 'attended'] },
    },
    _count: {
      eventId: true,
    },
  });

  const counts = new Map();
  for (const row of grouped) {
    counts.set(row.eventId, Number(row._count.eventId || 0));
  }
  return counts;
}

async function ensureEventContext(eventId, hosterId) {
  const safeEventId = (eventId || '').toString().trim();
  const safeHosterId = (hosterId || '').toString().trim();

  if (!safeEventId || !safeHosterId) {
    throw new Error('eventId und hosterId sind erforderlich');
  }

  if (!allowDemoBootstrap) {
    const existingEvent = await prisma.event.findUnique({ where: { id: safeEventId } });
    if (!existingEvent) {
      throw new Error('Event nicht gefunden');
    }

    const existingHoster = await prisma.user.findUnique({ where: { id: safeHosterId } });
    if (!existingHoster) {
      throw new Error('Hoster nicht gefunden');
    }

    return existingEvent;
  }

  const resolvedHosterId = await ensureBackendUser(safeHosterId, safeHosterId || 'Demo Host');
  const source = getInMemoryEventById(safeEventId);

  const record = await prisma.event.upsert({
    where: { id: safeEventId },
    update: {},
    create: {
      id: safeEventId,
      hosterId: resolvedHosterId,
      title: source?.title || `Event ${safeEventId}`,
      description: source?.description || '',
      startDate: source?.eventDate ? new Date(source.eventDate) : new Date(),
      location: source?.location || '',
      latitude: Number(source?.latitude || 0),
      longitude: Number(source?.longitude || 0),
      status: mapApiEventStatusToDb(source?.status || 'active'),
      eventType: source?.category || 'other',
      maxParticipants: Number.isFinite(Number(source?.maxParticipants))
        ? Number(source.maxParticipants)
        : null,
      imageUrl: source?.photoUrl || '',
      costPerPerson: source?.price != null ? Number(source.price) : null,
    },
  });

  return record;
}

async function ensureEventChatRecord(eventId) {
  const event = await prisma.event.findUnique({ where: { id: eventId } });
  if (!event) {
    return null;
  }

  const chat = await prisma.eventChat.upsert({
    where: { eventId },
    update: {},
    create: { eventId },
  });

  return chat;
}

function asIsoDate(value) {
  if (!value) return null;
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return null;
  return parsed.toISOString();
}

function parsePositiveNumber(value) {
  const amount = Number(value);
  if (!Number.isFinite(amount) || amount <= 0) return null;
  return amount;
}

function normalizePaymentStatus(value) {
  const raw = (value || '').toString().trim().toLowerCase();
  if (!raw) return 'completed';
  const allowed = new Set(['initiated', 'pending', 'completed', 'failed', 'refunded']);
  if (!allowed.has(raw)) return null;
  return raw;
}

function canTransitionPaymentStatus(fromStatus, toStatus) {
  if (fromStatus === toStatus) return true;
  const transitions = {
    initiated: new Set(['pending', 'completed', 'failed']),
    pending: new Set(['completed', 'failed', 'refunded']),
    completed: new Set(['refunded']),
    failed: new Set([]),
    refunded: new Set([]),
  };
  return transitions[fromStatus]?.has(toStatus) === true;
}

async function updateEventPaymentDateIfCompleted(transaction) {
  if (!transaction || transaction.status !== 'completed') {
    return;
  }
  const eventIndex = events.findIndex(event => event.id === transaction.eventId);
  if (eventIndex !== -1) {
    events[eventIndex] = {
      ...events[eventIndex],
      paymentDate: transaction.completedAt || new Date().toISOString(),
    };
  }

  try {
    await prisma.event.update({
      where: { id: transaction.eventId },
      data: {
        updatedAt: new Date(),
      },
    });
  } catch (_) {
    // Ignore DB event update failures here; payment persistence remains primary.
  }
}

async function applyTransactionStatusUpdateByIndex(index, targetStatus) {
  const current = paymentTransactions[index];
  if (!canTransitionPaymentStatus(current.status, targetStatus)) {
    return {
      ok: false,
      code: 'invalid_transition',
      httpStatus: 409,
      error: `Statuswechsel ${current.status} -> ${targetStatus} nicht erlaubt`,
    };
  }

  const nowIso = new Date().toISOString();
  const updated = {
    ...current,
    status: targetStatus,
    updatedAt: nowIso,
    completedAt: targetStatus === 'completed' ? (current.completedAt || nowIso) : current.completedAt,
    failedAt: targetStatus === 'failed' ? nowIso : current.failedAt,
    refundedAt: targetStatus === 'refunded' ? nowIso : current.refundedAt,
  };

  paymentTransactions[index] = updated;
  await updateEventPaymentDateIfCompleted(updated);
  return { ok: true, item: updated };
}

async function applyTransactionStatusUpdateByRecord(record, targetStatus) {
  const currentStatus = normalizeStoredPaymentStatus(record.status);
  if (!canTransitionPaymentStatus(currentStatus, targetStatus)) {
    return {
      ok: false,
      code: 'invalid_transition',
      httpStatus: 409,
      error: `Statuswechsel ${currentStatus} -> ${targetStatus} nicht erlaubt`,
    };
  }

  const audit = getPaymentAuditDetails(record);
  const nowIso = new Date().toISOString();
  const nextAudit = {
    ...audit,
    completedAt: targetStatus === 'completed' ? (audit.completedAt || nowIso) : audit.completedAt || null,
    failedAt: targetStatus === 'failed' ? nowIso : audit.failedAt || null,
    refundedAt: targetStatus === 'refunded' ? nowIso : audit.refundedAt || null,
  };

  const updated = await prisma.paymentTransaction.update({
    where: { id: record.id },
    data: {
      status: targetStatus,
      refundedAt: targetStatus === 'refunded' ? new Date(nowIso) : record.refundedAt,
      auditDetails: nextAudit,
    },
  });

  const mapped = mapPaymentRecordToApiItem(updated);
  await updateEventPaymentDateIfCompleted(mapped);
  return { ok: true, item: mapped };
}

async function applyProviderTransactionStatusUpdate({
  provider,
  providerTransactionRef,
  targetStatus,
  verified,
  transactionId,
}) {
  try {
    if (provider !== 'stripe' || !providerTransactionRef || verified !== true || transactionId) {
      throw paymentError(400, 'Nur signierte Stripe-Webhook-Referenzen erlaubt');
    }
    const record = await findPaymentRecord({ stripePaymentIntentId: providerTransactionRef });
    if (!record) {
      return { ok: false, code: 'not_found', httpStatus: 404, error: 'Transaktion nicht gefunden' };
    }
    // Re-read current Stripe state: signed but delayed events must not roll an order back.
    const result = await syncStripePaymentRecord(record, 'webhook');
    return { ok: true, item: result.item };
  } catch (error) {
    return {
      ok: false,
      httpStatus: error.paymentHttpStatus || 503,
      error: error.paymentHttpStatus ? error.message : 'Providerpruefung derzeit nicht verfuegbar',
    };
  }
}

function removeMatching(list, predicate) {
  if (!Array.isArray(list) || list.length === 0) return 0;
  const originalLength = list.length;
  for (let i = list.length - 1; i >= 0; i -= 1) {
    if (predicate(list[i])) {
      list.splice(i, 1);
    }
  }
  return originalLength - list.length;
}

function countAccountDataByUserIdInMemory(userId) {
  let removed = 0;
  const familyId = ownFamilyId(userId);
  removed += todos.filter(item => item.familyId === familyId).length;
  removed += shoppingItems.filter(item => item.familyId === familyId).length;

  removed += familyContacts.filter(item => item.userId === userId).length;
  removed += familyRequests.filter(
    item => item.fromUserId === userId || item.toUserId === userId,
  ).length;

  const removedEventIds = events
    .filter(item => item.hosterId === userId)
    .map(item => item.id)
    .filter(Boolean);
  removed += removedEventIds.length;

  removed += eventInvitations.filter(
    item =>
      item.invitedUserId === userId ||
      item.hostUserId === userId ||
      removedEventIds.includes(item.eventId),
  ).length;

  removed += eventParticipations.filter(
    item => item.userId === userId || removedEventIds.includes(item.eventId),
  ).length;

  removed += paymentTransactions.filter(
    item => item.userId === userId || item.hostUserId === userId,
  ).length;

  removed += eventChatReports.filter(item => item.userId === userId).length;

  for (const [eventId, messages] of Object.entries(eventChatMessages)) {
    if (!Array.isArray(messages)) continue;
    if (removedEventIds.includes(eventId)) {
      removed += messages.length;
      continue;
    }
    removed += messages.filter(item => item?.userId === userId).length;
  }

  removed += parentMatchingActions.filter(
    item => item.userId === userId || item.actorUserId === userId,
  ).length;

  return removed;
}

function deleteAccountDataByUserIdInMemory(userId) {
  let removed = 0;
  const familyId = ownFamilyId(userId);
  removed += removeMatching(todos, item => item.familyId === familyId);
  removed += removeMatching(shoppingItems, item => item.familyId === familyId);

  removed += removeMatching(familyContacts, item => item.userId === userId);
  removed += removeMatching(
    familyRequests,
    item => item.fromUserId === userId || item.toUserId === userId,
  );

  const removedEventIds = [];
  removed += removeMatching(events, item => {
    const shouldRemove = item.hosterId === userId;
    if (shouldRemove && item.id) {
      removedEventIds.push(item.id);
      delete eventInviteCodes[item.id];
      delete eventInviteExpiresAt[item.id];
      delete eventChatMessages[item.id];
    }
    return shouldRemove;
  });

  removed += removeMatching(
    eventInvitations,
    item =>
      item.invitedUserId === userId ||
      item.hostUserId === userId ||
      removedEventIds.includes(item.eventId),
  );

  removed += removeMatching(
    eventParticipations,
    item => item.userId === userId || removedEventIds.includes(item.eventId),
  );

  removed += removeMatching(
    paymentTransactions,
    item => item.userId === userId || item.hostUserId === userId,
  );

  removed += removeMatching(eventChatReports, item => item.userId === userId);

  for (const [eventId, messages] of Object.entries(eventChatMessages)) {
    if (!Array.isArray(messages)) continue;
    const before = messages.length;
    for (let i = messages.length - 1; i >= 0; i -= 1) {
      if (messages[i]?.userId === userId) {
        messages.splice(i, 1);
      }
    }
    removed += before - messages.length;
    if (messages.length === 0) {
      delete eventChatMessages[eventId];
    }
  }

  removed += removeMatching(
    parentMatchingActions,
    item => item.userId === userId || item.actorUserId === userId,
  );

  return removed;
}

function localUploadFilenameFromUrl(value) {
  if (typeof value !== 'string' || !value.trim()) return null;
  try {
    const pathname = decodeURIComponent(new URL(value, 'http://localhost').pathname);
    const match = pathname.match(/^\/uploads\/([^/]+)$/);
    if (!match || !/^[a-zA-Z0-9._-]+$/.test(match[1])) return null;
    return match[1];
  } catch (_) {
    return null;
  }
}

function firebaseStorageObjectFromUrl(value) {
  if (!firebaseStorageBucket || typeof value !== 'string' || !value.trim()) return null;
  try {
    const url = new URL(value);
    let bucket = '';
    let objectPath = '';

    if (url.hostname === 'firebasestorage.googleapis.com') {
      const match = url.pathname.match(/^\/v0\/b\/([^/]+)\/o\/(.+)$/);
      if (!match) return null;
      bucket = decodeURIComponent(match[1]);
      objectPath = decodeURIComponent(match[2]);
    } else if (url.hostname === 'storage.googleapis.com') {
      const parts = url.pathname.split('/').filter(Boolean);
      bucket = decodeURIComponent(parts.shift() || '');
      objectPath = decodeURIComponent(parts.join('/'));
    } else if (url.hostname === `${firebaseStorageBucket}.storage.googleapis.com`) {
      bucket = firebaseStorageBucket;
      objectPath = decodeURIComponent(url.pathname.replace(/^\//, ''));
    } else {
      return null;
    }

    if (bucket !== firebaseStorageBucket || objectPath.includes('..')) return null;
    if (!/^(?:treasures\/(?:[^/]+\/)?[^/]+|events\/[^/]+)$/.test(objectPath)) return null;
    return objectPath;
  } catch (_) {
    return null;
  }
}

async function getRemainingMediaReferences() {
  const rows = await prisma.$queryRawUnsafe(
    `SELECT "imageUrl" AS url FROM "Event" WHERE "imageUrl" IS NOT NULL
     UNION ALL SELECT "photoUrl" FROM "TreasureItem" WHERE "photoUrl" IS NOT NULL
     UNION ALL SELECT unnest("photoUrls") FROM "TreasureItem"
     UNION ALL SELECT "imageUrl" FROM "SharedRecipe" WHERE "imageUrl" IS NOT NULL
     UNION ALL SELECT "imageUrl" FROM "CommunityEvent" WHERE "imageUrl" IS NOT NULL
     UNION ALL SELECT "avatar" FROM "User" WHERE "avatar" IS NOT NULL`,
  );
  return rows.map(row => row.url).filter(Boolean);
}

async function deleteUnreferencedAccountMedia(mediaUrls, userId) {
  const remainingUrls = await getRemainingMediaReferences();
  const referencedLocalFiles = new Set(
    remainingUrls.map(localUploadFilenameFromUrl).filter(Boolean),
  );
  const referencedFirebaseObjects = new Set(
    remainingUrls.map(firebaseStorageObjectFromUrl).filter(Boolean),
  );
  const filenames = [...new Set(mediaUrls.map(localUploadFilenameFromUrl).filter(Boolean))];
  const firebaseObjects = [
    ...new Set(mediaUrls.map(firebaseStorageObjectFromUrl).filter(Boolean)),
  ];
  let removedLocalFiles = 0;
  let removedFirebaseObjects = 0;

  for (const filename of filenames) {
    if (referencedLocalFiles.has(filename)) continue;

    const filePath = path.join(uploadsDir, filename);
    if (path.dirname(filePath) !== uploadsDir) continue;
    try {
      await fs.promises.unlink(filePath);
      removedLocalFiles += 1;
    } catch (error) {
      if (error?.code !== 'ENOENT') {
        console.warn(`Upload-Cleanup fehlgeschlagen (${filename}):`, error?.message || error);
      }
    }
  }

  if (firebaseAdmin && firebaseStorageBucket) {
    const bucket = firebaseAdmin.storage().bucket(firebaseStorageBucket);
    for (const objectPath of firebaseObjects) {
      const parts = objectPath.split('/');
      if (parts[0] === 'treasures' && parts.length === 3 && parts[1] !== userId) {
        console.warn('Firebase-Storage-Cleanup skipped foreign owner folder');
        continue;
      }
      if (referencedFirebaseObjects.has(objectPath)) continue;
      try {
        await bucket.file(objectPath).delete({ ignoreNotFound: true });
        removedFirebaseObjects += 1;
      } catch (error) {
        console.warn(
          `Firebase-Storage-Cleanup fehlgeschlagen (${objectPath}):`,
          error?.message || error,
        );
      }
    }
  }

  return { removedLocalFiles, removedFirebaseObjects };
}

async function deleteAccountDataByUserIdPrisma(userId, options = {}) {
  const ownItems = await exportOwnFamilyItems(userId);
  const ownMealCount = ownItems.mealPlans.reduce(
    (sum, plan) => sum + 1 + (Array.isArray(plan.meals) ? plan.meals.length : 0),
    0,
  );
  // Todos/ShoppingItems cascaden ueber die Family-Relation bei User-Loeschung.
  // MealPlans NICHT (familyId ist nur ein String ohne FK) -> separat loeschen.
  const familyItemCount = ownItems.todos.length + ownItems.shoppingItems.length;
  const [userMedia, hostedEvents, ownedTreasures, ownedRecipes, ownedCommunityEvents] =
    await Promise.all([
      prisma.user.findUnique({
        where: { id: userId },
        select: { avatar: true },
      }),
      prisma.event.findMany({
        where: { hosterId: userId },
        select: { id: true, imageUrl: true },
      }),
      prisma.treasureItem.findMany({
        where: { userId },
        select: { photoUrl: true, photoUrls: true },
      }),
      prisma.sharedRecipe.findMany({
        where: { creatorUserId: userId },
        select: { imageUrl: true },
      }),
      prisma.communityEvent.findMany({
        where: { creatorId: userId },
        select: { imageUrl: true },
      }),
    ]);

  const mediaUrls = [
    userMedia?.avatar,
    ...hostedEvents.map(item => item.imageUrl),
    ...ownedTreasures.flatMap(item => [item.photoUrl, ...item.photoUrls]),
    ...ownedRecipes.map(item => item.imageUrl),
    ...ownedCommunityEvents.map(item => item.imageUrl),
  ].filter(Boolean);

  const directlyOwnedCounts = await Promise.all([
    prisma.aiChildProfile.count({ where: { userId } }),
    prisma.aiMemoryItem.count({ where: { child: { userId } } }),
    prisma.aiMemorySettings.count({ where: { userId } }),
    prisma.treasureReport.count({ where: { reporterUserId: userId } }),
    prisma.treasureItem.count({ where: { userId } }),
    prisma.parentMatchingProfile.count({ where: { ownerUserId: userId } }),
    prisma.sharedRecipe.count({ where: { creatorUserId: userId } }),
    prisma.foodOfferComment.count({ where: { userId } }),
    prisma.foodOfferReservation.count({ where: { userId } }),
    prisma.recipeRating.count({ where: { userId } }),
    prisma.recipeFavorite.count({ where: { userId } }),
    prisma.recipeReport.count({ where: { reportedById: userId } }),
    prisma.communityEvent.count({ where: { creatorId: userId } }),
    prisma.communityEventFlag.count({ where: { userId } }),
    prisma.communityEventInterest.count({ where: { userId } }),
    prisma.userEntitlement.count({ where: { userId } }),
    prisma.adsConsent.count({ where: { userId } }),
  ]);

  const familyRequestCount = await prisma.familyRequest.count({
    where: {
      OR: [{ fromUserId: userId }, { toUserId: userId }],
    },
  });

  const hostAuditPaymentCount = await prisma.paymentTransaction.count({
    where: {
      auditDetails: {
        path: ['hosterId'],
        equals: userId,
      },
    },
  });

  const userCount = await prisma.user.count({ where: { id: userId } });
  const parentMatchingActionCount =
    typeof prisma.parentMatchingAction?.count === 'function'
      ? await prisma.parentMatchingAction.count({
          where: { actorUserId: userId },
        })
      : 0;

  if (options.dryRun === true) {
    return {
      removed:
        hostedEvents.length +
        directlyOwnedCounts.reduce((sum, count) => sum + count, 0) +
        familyRequestCount +
        hostAuditPaymentCount +
        userCount +
        parentMatchingActionCount +
        familyItemCount +
        ownMealCount,
      parentMatchingActionCount,
      hostedEventIds: hostedEvents.map(item => item.id),
      mediaUrls,
      dryRun: true,
    };
  }

  let removed = 0;
  removed += (await prisma.familyRequest.deleteMany({
    where: {
      OR: [{ fromUserId: userId }, { toUserId: userId }],
    },
  })).count;

  removed += (await prisma.paymentTransaction.deleteMany({
    where: {
      auditDetails: {
        path: ['hosterId'],
        equals: userId,
      },
    },
  })).count;

  removed += (await prisma.event.deleteMany({
    where: { hosterId: userId },
  })).count;

  // KI-Gedächtnis (DSGVO): Memory-Items hängen per Cascade an AiChildProfile.
  removed += (await prisma.aiMemoryItem.deleteMany({
    where: { child: { userId } },
  })).count;
  removed += (await prisma.aiChildProfile.deleteMany({
    where: { userId },
  })).count;
  removed += (await prisma.aiMemorySettings.deleteMany({
    where: { userId },
  })).count;

  removed += (await prisma.treasureReport.deleteMany({
    where: { reporterUserId: userId },
  })).count;
  removed += (await prisma.treasureItem.deleteMany({
    where: { userId },
  })).count;

  removed += (await prisma.foodOfferComment.deleteMany({ where: { userId } })).count;
  removed += (await prisma.foodOfferReservation.deleteMany({ where: { userId } })).count;
  removed += (await prisma.recipeRating.deleteMany({ where: { userId } })).count;
  removed += (await prisma.recipeFavorite.deleteMany({ where: { userId } })).count;
  removed += (await prisma.recipeReport.deleteMany({
    where: { reportedById: userId },
  })).count;
  removed += (await prisma.sharedRecipe.deleteMany({
    where: { creatorUserId: userId },
  })).count;

  removed += (await prisma.communityEventFlag.deleteMany({ where: { userId } })).count;
  removed += (await prisma.communityEventInterest.deleteMany({ where: { userId } })).count;
  removed += (await prisma.communityEvent.deleteMany({
    where: { creatorId: userId },
  })).count;

  removed += (await prisma.parentMatchingProfile.deleteMany({
    where: { ownerUserId: userId },
  })).count;

  if (typeof prisma.parentMatchingAction?.deleteMany === 'function') {
    removed += (await prisma.parentMatchingAction.deleteMany({
      where: { actorUserId: userId },
    })).count;
  }

  // MealPlan hat keine Family-Relation und cascadet daher NICHT bei der
  // User-Loeschung. Meals cascaden von MealPlan, also reicht das Loeschen der
  // Plaene der eigenen Familie. Owner-geprueft ueber die aufgeloeste Familien-ID.
  const ownFamilyIdForDelete = ownFamilyId(userId);
  removed += (await prisma.mealPlan.deleteMany({
    where: { familyId: ownFamilyIdForDelete },
  })).count;
  removed += ownMealCount - ownItems.mealPlans.length; // zusaetzlich entfernte Meals

  removed += (await prisma.userEntitlement.deleteMany({
    where: { userId },
  })).count;
  removed += (await prisma.adsConsent.deleteMany({
    where: { userId },
  })).count;

  // User -> created Family -> Todo/ShoppingItem cascades are defined in Prisma.
  const deletedUsers = (await prisma.user.deleteMany({ where: { id: userId } })).count;
  removed += deletedUsers + (deletedUsers ? familyItemCount : 0);

  return {
    removed,
    hostedEventIds: hostedEvents.map(item => item.id),
    mediaUrls,
  };
}

async function exportAccountDataByUserIdPrisma(userId) {
  const ownItems = await exportOwnFamilyItems(userId);
  const [
    user,
    createdFamilies,
    hostedEvents,
    eventParticipations,
    messages,
    chatReports,
    treasureItems,
    treasureRatings,
    treasureHandovers,
    treasureReports,
    paymentTransactions,
    parentMatchingProfiles,
    parentMatchingActions,
    sharedRecipes,
    foodOfferComments,
    foodOfferReservations,
    recipeRatings,
    recipeFavorites,
    recipeReports,
    communityEvents,
    communityEventFlags,
    communityEventInterests,
    entitlement,
    adsConsent,
  ] = await Promise.all([
    prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        firstName: true,
        lastName: true,
        avatar: true,
        bio: true,
        createdAt: true,
        trialExpiresAt: true,
        isPremium: true,
        premiumExpiresAt: true,
      },
    }),
    prisma.family.findMany({ where: { createdById: userId } }),
    resilientEventFindMany({ where: { hosterId: userId } }),
    prisma.eventParticipation.findMany({ where: { userId } }),
    prisma.message.findMany({ where: { authorId: userId } }),
    prisma.chatReport.findMany({ where: { reportedById: userId } }),
    prisma.treasureItem.findMany({ where: { userId } }),
    prisma.treasureRating.findMany({ where: { fromUserId: userId } }),
    prisma.treasureHandover.findMany({ where: { requesterId: userId } }),
    prisma.treasureReport.findMany({ where: { reporterUserId: userId } }),
    prisma.paymentTransaction.findMany({ where: { userId } }),
    prisma.parentMatchingProfile.findMany({ where: { ownerUserId: userId } }),
    prisma.parentMatchingAction.findMany({ where: { actorUserId: userId } }),
    prisma.sharedRecipe.findMany({ where: { creatorUserId: userId } }),
    prisma.foodOfferComment.findMany({ where: { userId } }),
    prisma.foodOfferReservation.findMany({ where: { userId } }),
    prisma.recipeRating.findMany({ where: { userId } }),
    prisma.recipeFavorite.findMany({ where: { userId } }),
    prisma.recipeReport.findMany({ where: { reportedById: userId } }),
    prisma.communityEvent.findMany({ where: { creatorId: userId } }),
    prisma.communityEventFlag.findMany({ where: { userId } }),
    prisma.communityEventInterest.findMany({ where: { userId } }),
    prisma.userEntitlement.findUnique({
      where: { userId },
      select: {
        tier: true,
        access: true,
        validFrom: true,
        validUntil: true,
        verifiedAt: true,
        adsEligibleByEntitlement: true,
        revokedAt: true,
        createdAt: true,
        updatedAt: true,
      },
    }),
    prisma.adsConsent.findUnique({
      where: { userId },
      select: {
        decision: true,
        consentVersion: true,
        consentRevision: true,
        consentedAt: true,
        withdrawnAt: true,
        createdAt: true,
        updatedAt: true,
      },
    }),
  ]);

  return {
    user,
    createdFamilies,
    todos: ownItems.todos,
    shoppingItems: ownItems.shoppingItems,
    mealPlans: ownItems.mealPlans,
    hostedEvents,
    eventParticipations,
    messages,
    chatReports,
    treasureItems,
    treasureRatings,
    treasureHandovers,
    treasureReports,
    paymentTransactions,
    parentMatchingProfiles,
    parentMatchingActions,
    sharedRecipes,
    foodOfferComments,
    foodOfferReservations,
    recipeRatings,
    recipeFavorites,
    recipeReports,
    communityEvents,
    communityEventFlags,
    communityEventInterests,
    entitlement,
    adsConsent,
  };
}

// ============================================================================
// REFERRAL TRACKING
// ============================================================================
const _pendingReferrals = new Map(); // in-memory fallback

app.post('/referrals/record', async (req, res) => {
  const { referralCode, inviteeId, inviteeName } = req.body;
  if (!referralCode || !inviteeId) {
    return res.status(400).json({ error: 'referralCode und inviteeId sind erforderlich' });
  }
  const code = String(referralCode).toUpperCase().trim();
  const name = String(inviteeName || 'Neues Mitglied');
  try {
    await ensureSocialSchemaReady();
    const existing = await prisma.$queryRawUnsafe(
      `SELECT "id" FROM "PendingReferral" WHERE "referralCode" = $1 AND "inviteeId" = $2`,
      code, String(inviteeId)
    );
    if (existing.length === 0) {
      await prisma.$executeRawUnsafe(
        `INSERT INTO "PendingReferral" ("id", "referralCode", "inviteeId", "inviteeName", "ts") VALUES ($1, $2, $3, $4, $5)`,
        generateId('ref'), code, String(inviteeId), name, Date.now()
      );
    }
    console.log(`📬 Referral recorded (DB): ${code} ← ${inviteeId}`);
    return res.json({ success: true });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'POST /referrals/record', error)) return;
    if (!_pendingReferrals.has(code)) _pendingReferrals.set(code, []);
    const existing = _pendingReferrals.get(code);
    if (!existing.some(r => r.inviteeId === inviteeId)) {
      existing.push({ inviteeId: String(inviteeId), inviteeName: name, ts: Date.now() });
    }
    console.log(`📬 Referral recorded (memory): ${code} ← ${inviteeId}`);
    return res.json({ success: true });
  }
});

app.get('/referrals/pending/:code', async (req, res) => {
  const code = String(req.params.code || '').toUpperCase().trim();
  if (!code) return res.status(400).json({ error: 'code erforderlich' });
  try {
    await ensureSocialSchemaReady();
    const rows = await prisma.$queryRawUnsafe(
      `SELECT "inviteeId", "inviteeName", "ts" FROM "PendingReferral" WHERE "referralCode" = $1`,
      code
    );
    return res.json({ referrals: rows });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'GET /referrals/pending', error)) return;
    return res.json({ referrals: _pendingReferrals.get(code) || [] });
  }
});

app.delete('/referrals/claim/:code', async (req, res) => {
  const code = String(req.params.code || '').toUpperCase().trim();
  try {
    await ensureSocialSchemaReady();
    const rows = await prisma.$queryRawUnsafe(
      `SELECT "id" FROM "PendingReferral" WHERE "referralCode" = $1`, code
    );
    await prisma.$executeRawUnsafe(
      `DELETE FROM "PendingReferral" WHERE "referralCode" = $1`, code
    );
    console.log(`✅ Referral claimed (DB): ${code} (${rows.length} entries)`);
    return res.json({ claimed: rows.length });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'DELETE /referrals/claim', error)) return;
    const claimed = (_pendingReferrals.get(code) || []).length;
    _pendingReferrals.delete(code);
    console.log(`✅ Referral claimed (memory): ${code} (${claimed} entries)`);
    return res.json({ claimed });
  }
});

app.post('/account/delete-data', requireVerifiedUser, async (req, res) => {
  const userId = (req.body.userId || '').toString().trim();
  const dryRun =
    String(req.query.dryRun || req.body.dryRun || '')
      .toLowerCase()
      .trim() === 'true';
  if (!userId) {
    return res.status(400).json({ error: 'userId ist erforderlich' });
  }
  if (!(await authorizeAccountOwner(req, res, userId))) return;

  try {
    const prismaResult = await deleteAccountDataByUserIdPrisma(userId, { dryRun });
    const removedMemoryEntries = dryRun
      ? countAccountDataByUserIdInMemory(userId)
      : deleteAccountDataByUserIdInMemory(userId);

    if (!dryRun) {
      for (const eventId of prismaResult.hostedEventIds) {
        delete eventInviteCodes[eventId];
        delete eventInviteExpiresAt[eventId];
        delete eventChatMessages[eventId];
      }
    }

    const mediaCleanup = dryRun
      ? { removedLocalFiles: 0, removedFirebaseObjects: 0 }
      : await deleteUnreferencedAccountMedia(prismaResult.mediaUrls, userId);

    const removedEntries = prismaResult.removed + removedMemoryEntries;
    return res.json({
      ok: true,
      userId,
      dryRun,
      removedEntries,
      removedDbEntries: prismaResult.removed,
      removedMemoryEntries,
      ...mediaCleanup,
      mode: 'prisma',
    });
  } catch (error) {
    return respondFamilyPersistenceError(res, 'POST /account/delete-data', error);
  }
});

app.get('/account/export-data', requireVerifiedUser, async (req, res) => {
  const userId = (req.query.userId || '').toString().trim();
  if (!userId) {
    return res.status(400).json({ error: 'userId ist erforderlich' });
  }
  if (!(await authorizeAccountOwner(req, res, userId))) return;

  try {
    const data = await exportAccountDataByUserIdPrisma(userId);
    return res.json({
      exportDate: new Date().toISOString(),
      userId,
      data,
    });
  } catch (error) {
    return respondFamilyPersistenceError(res, 'GET /account/export-data', error);
  }
});

// Ads consent metadata only; these routes never request or deliver advertising.
app.get('/ads/consent/me', requireVerifiedUser, async (req, res) => {
  res.setHeader('Cache-Control', 'no-store');
  try {
    await ensureVerifiedBackendUser(req.firebaseUid);
    return res.json({ item: await readAdsConsent(prisma, req.firebaseUid) });
  } catch (error) {
    return respondFamilyPersistenceError(res, 'GET /ads/consent/me', error);
  }
});

app.put('/ads/consent/me', requireVerifiedUser, async (req, res) => {
  res.setHeader('Cache-Control', 'no-store');
  try {
    await ensureVerifiedBackendUser(req.firebaseUid);
    return res.json({ item: await setAdsConsent(prisma, req.firebaseUid, req.body) });
  } catch (error) {
    if (error.code === 'invalid_ads_consent' || error.code === 'ads_consent_conflict') {
      return res.status(error.status).json({ error: error.message, code: error.code });
    }
    return respondFamilyPersistenceError(res, 'PUT /ads/consent/me', error);
  }
});

app.get('/entitlements/me', requireVerifiedUser, async (req, res) => {
  const userId = req.firebaseUid;
  try {
    await ensureVerifiedBackendUser(userId);
    const item = await readEntitlementSnapshot(prisma, userId);
    return res.json({ item });
  } catch (error) {
    return respondFamilyPersistenceError(res, 'GET /entitlements/me', error);
  }
});

app.post('/entitlements/:userId/activate-premium', requireVerifiedUser, (req, res) => {
  if (req.params.userId && req.params.userId !== req.firebaseUid) {
    return res.status(403).json({
      error: 'Nur fuer das eigene Konto erlaubt',
      code: 'not_owner',
    });
  }

  return res.status(410).json({
    error: 'Premium kann erst nach serverseitiger Store-Verifikation aktiviert werden',
    code: 'store_verification_required',
  });
});

// 0. Weekly Impulse abrufen
app.get('/api/weekly-impulse', (req, res) => {
  const schema = getWeeklyImpulseSchema();

  if (!schema) {
    return res.status(500).json({ error: 'Weekly Impulse Schema fehlt' });
  }

  const viewerUserId =
    typeof req.query.viewerUserId === 'string' && req.query.viewerUserId.trim()
      ? req.query.viewerUserId.trim()
      : '';
  const language = normalizeAppLanguage(req.query.language);

  res.json(buildWeeklyImpulseResponse({ schema, viewerUserId, language }));
});

app.post('/api/weekly-impulse/community/posts', requireVerifiedUser, (req, res) => {
  const schema = getWeeklyImpulseSchema();
  if (!schema) {
    return res.status(500).json({ error: 'Weekly Impulse Schema fehlt' });
  }

  const impulseId = typeof req.body?.impulseId === 'string' ? req.body.impulseId.trim() : '';
  const title = typeof req.body?.title === 'string' ? req.body.title.trim() : '';
  const body = typeof req.body?.body === 'string' ? req.body.body.trim() : '';
  const authorName =
    typeof req.body?.authorName === 'string' ? req.body.authorName.trim() : '';
  const role = typeof req.body?.role === 'string' ? req.body.role.trim() : '';
  const authorUserId = req.firebaseUid;
  const authorEmail = req.firebaseIdentity.emailVerified ? req.firebaseIdentity.email : '';

  if (!impulseId || !title || !body || !authorName || !role) {
    return res.status(400).json({ error: 'impulseId, title, body, authorName und role sind erforderlich' });
  }

  const expectedImpulseId = `imp_${schema.id}_gfk_w1`;
  if (impulseId !== expectedImpulseId) {
    return res.status(404).json({ error: 'Weekly Impulse nicht gefunden' });
  }

  const state = getWeeklyImpulseCommunityEntry(impulseId);
  const verifiedRecord = role === 'Paedagog:in'
    ? getVerifiedExpertRecord({ userId: authorUserId, email: authorEmail })
    : null;
  const item = {
    id: `${impulseId}_community_${Date.now()}_${crypto.randomBytes(3).toString('hex')}`,
    author_name: authorName,
    role,
    verified_expert: !!verifiedRecord,
    verification_label: verifiedRecord?.verificationLabel || '',
    title,
    body,
    seed_like_count: 0,
    seed_comments: [],
  };

  state.customPosts.unshift(item);
  return res.status(201).json({ item });
});

app.get('/api/weekly-impulse/community/verification-status', requireVerifiedUser, (req, res) => {
  const userId = req.firebaseUid;
  const email = req.firebaseIdentity.emailVerified ? req.firebaseIdentity.email : '';

  const verifiedRecord = getVerifiedExpertRecord({ userId, email });
  const latestRequest = weeklyImpulseVerificationRequests
    .filter(item =>
      (userId && item.userId === userId) || (email && item.email.toLowerCase() === email),
    )
    .sort((a, b) => String(b.createdAt).localeCompare(String(a.createdAt)))[0] || null;

  return res.json({
    verified: !!verifiedRecord,
    verificationLabel: verifiedRecord?.verificationLabel || '',
    verifiedAt: verifiedRecord?.verifiedAt || null,
    pendingRequest: latestRequest?.status === 'pending',
    verifiedProfile: verifiedRecord
      ? {
          displayName: verifiedRecord.displayName || '',
          roleTitle: verifiedRecord.roleTitle || '',
          organization: verifiedRecord.organization || '',
          verificationLabel: verifiedRecord.verificationLabel || '',
          verifiedAt: verifiedRecord.verifiedAt || null,
          reviewedBy: verifiedRecord.reviewedBy || '',
          reviewNote: verifiedRecord.reviewNote || '',
        }
      : null,
    latestRequest,
  });
});

app.post('/api/weekly-impulse/community/verification-requests', requireVerifiedUser, (req, res) => {
  const userId = req.firebaseUid;
  const email = req.firebaseIdentity.email;
  if (!email || !req.firebaseIdentity.emailVerified) {
    return res.status(403).json({
      error: 'Bestaetigte E-Mail-Adresse erforderlich',
      code: 'verified_email_required',
    });
  }
  const displayName = typeof req.body?.displayName === 'string' ? req.body.displayName.trim() : '';
  const roleTitle = typeof req.body?.roleTitle === 'string' ? req.body.roleTitle.trim() : '';
  const organization = typeof req.body?.organization === 'string' ? req.body.organization.trim() : '';
  const note = typeof req.body?.note === 'string' ? req.body.note.trim() : '';

  if (!displayName || !roleTitle) {
    return res.status(400).json({
      error: 'displayName und roleTitle sind erforderlich',
    });
  }

  const existingPending = weeklyImpulseVerificationRequests.find(item =>
    item.status === 'pending' && (item.userId === userId || item.email.toLowerCase() === email),
  );
  if (existingPending) {
    return res.status(409).json({ error: 'Es gibt bereits eine offene Verifizierungsanfrage' });
  }

  const item = {
    id: `verif_${Date.now()}_${crypto.randomBytes(3).toString('hex')}`,
    userId,
    email,
    displayName,
    roleTitle,
    organization,
    note,
    status: 'pending',
    verificationLabel: 'Verifizierte Fachstimme',
    createdAt: new Date().toISOString(),
    reviewedAt: null,
    reviewedBy: '',
    reviewNote: '',
  };
  weeklyImpulseVerificationRequests.unshift(item);
  return res.status(201).json({ item });
});

app.get('/api/weekly-impulse/community/verification-requests', requireVerifiedUser, requireInternalModerator, (req, res) => {
  const status =
    typeof req.query.status === 'string' ? req.query.status.trim().toLowerCase() : '';
  const items = weeklyImpulseVerificationRequests.filter(item =>
    status ? item.status === status : true,
  );
  return res.json({ items });
});

app.post('/api/weekly-impulse/community/verification-requests/:requestId/approve', requireVerifiedUser, requireInternalModerator, (req, res) => {
  const { requestId } = req.params;
  const reviewerName = req.firebaseIdentity.email;
  const reviewNote =
    typeof req.body?.reviewNote === 'string' ? req.body.reviewNote.trim() : '';
  const verificationLabel =
    typeof req.body?.verificationLabel === 'string' && req.body.verificationLabel.trim()
      ? req.body.verificationLabel.trim()
      : 'Verifizierte Fachstimme';

  const request = weeklyImpulseVerificationRequests.find(item => item.id === requestId);
  if (!request) {
    return res.status(404).json({ error: 'Verifizierungsanfrage nicht gefunden' });
  }

  request.status = 'approved';
  request.reviewedAt = new Date().toISOString();
  request.reviewedBy = reviewerName;
  request.reviewNote = reviewNote;
  request.verificationLabel = verificationLabel;

  storeVerifiedExpertRecord({
    userId: request.userId,
    email: request.email,
    displayName: request.displayName,
    roleTitle: request.roleTitle,
    organization: request.organization,
    verificationLabel,
    verifiedAt: request.reviewedAt,
    reviewedBy: reviewerName,
    reviewNote,
  });

  return res.json({ item: request });
});

app.post('/api/weekly-impulse/community/posts/:postId/like', requireVerifiedUser, (req, res) => {
  const schema = getWeeklyImpulseSchema();
  if (!schema) {
    return res.status(500).json({ error: 'Weekly Impulse Schema fehlt' });
  }

  const { postId } = req.params;
  const impulseId = typeof req.body?.impulseId === 'string' ? req.body.impulseId.trim() : '';
  const userId = req.firebaseUid;
  const isLiked = req.body?.isLiked === true;

  if (!impulseId || !postId || !userId) {
    return res.status(400).json({ error: 'impulseId, postId und userId sind erforderlich' });
  }

  const post = findWeeklyImpulseCommunityPost({ schema, impulseId, postId });
  if (!post) {
    return res.status(404).json({ error: 'Community-Post nicht gefunden' });
  }

  const state = getWeeklyImpulseCommunityEntry(impulseId);
  const likedBy = new Set(state.likedByPostId[postId] || []);
  if (isLiked) {
    likedBy.add(userId);
  } else {
    likedBy.delete(userId);
  }
  state.likedByPostId[postId] = [...likedBy];

  const baseLikeCount = Number.isFinite(post.seed_like_count) ? post.seed_like_count : 0;
  return res.json({
    liked: isLiked,
    likeCount: baseLikeCount + state.likedByPostId[postId].length,
  });
});

app.post('/api/weekly-impulse/community/posts/:postId/comments', requireVerifiedUser, (req, res) => {
  const schema = getWeeklyImpulseSchema();
  if (!schema) {
    return res.status(500).json({ error: 'Weekly Impulse Schema fehlt' });
  }

  const { postId } = req.params;
  const impulseId = typeof req.body?.impulseId === 'string' ? req.body.impulseId.trim() : '';
  const authorName =
    typeof req.body?.authorName === 'string' ? req.body.authorName.trim() : '';
  const role = typeof req.body?.role === 'string' ? req.body.role.trim() : '';
  const comment = typeof req.body?.comment === 'string' ? req.body.comment.trim() : '';

  if (!impulseId || !postId || !authorName || !role || !comment) {
    return res.status(400).json({ error: 'impulseId, postId, authorName, role und comment sind erforderlich' });
  }

  const post = findWeeklyImpulseCommunityPost({ schema, impulseId, postId });
  if (!post) {
    return res.status(404).json({ error: 'Community-Post nicht gefunden' });
  }

  const state = getWeeklyImpulseCommunityEntry(impulseId);
  const comments = state.commentsByPostId[postId] || [];
  const item = {
    id: `${postId}_comment_${Date.now()}_${crypto.randomBytes(3).toString('hex')}`,
    authorName,
    role,
    text: comment,
  };
  comments.push(item);
  state.commentsByPostId[postId] = comments;

  const baseCommentCount = Array.isArray(post.seed_comments) ? post.seed_comments.length : 0;
  return res.status(201).json({
    item,
    commentCount: baseCommentCount + comments.length,
  });
});

app.post('/api/weekly-impulse/community/posts/:postId/report', requireVerifiedUser, (req, res) => {
  const schema = getWeeklyImpulseSchema();
  if (!schema) {
    return res.status(500).json({ error: 'Weekly Impulse Schema fehlt' });
  }

  const { postId } = req.params;
  const impulseId = typeof req.body?.impulseId === 'string' ? req.body.impulseId.trim() : '';
  const reporterUserId = req.firebaseUid;
  const reporterName =
    typeof req.body?.reporterName === 'string' ? req.body.reporterName.trim() : '';
  const reason = typeof req.body?.reason === 'string' ? req.body.reason.trim() : '';

  if (!impulseId || !postId || !reporterUserId || !reporterName || !reason) {
    return res.status(400).json({
      error: 'impulseId, postId, reporterUserId, reporterName und reason sind erforderlich',
    });
  }

  const post = findWeeklyImpulseCommunityPost({ schema, impulseId, postId });
  if (!post) {
    return res.status(404).json({ error: 'Community-Post nicht gefunden' });
  }

  const state = getWeeklyImpulseCommunityEntry(impulseId);
  const reports = state.reportsByPostId[postId] || [];
  const item = {
    id: `${postId}_report_${Date.now()}_${crypto.randomBytes(3).toString('hex')}`,
    reporterUserId,
    reporterName,
    reason,
    createdAt: new Date().toISOString(),
  };
  reports.push(item);
  state.reportsByPostId[postId] = reports;

  return res.status(201).json({ item, reportCount: reports.length });
});

app.get('/api/weekly-impulse/community/reports', requireVerifiedUser, requireInternalModerator, (req, res) => {
  const schema = getWeeklyImpulseSchema();
  if (!schema) {
    return res.status(500).json({ error: 'Weekly Impulse Schema fehlt' });
  }

  const impulseId =
    typeof req.query.impulseId === 'string' && req.query.impulseId.trim()
      ? req.query.impulseId.trim()
      : `imp_${schema.id}_gfk_w1`;
  const includeResolved = req.query.includeResolved === '1';

  const items = buildWeeklyImpulseReportItems({ schema, impulseId }).filter(item =>
    includeResolved ? true : !item.resolvedAt,
  );
  return res.json({ items });
});

app.post('/api/weekly-impulse/community/reports/:reportId/resolve', requireVerifiedUser, requireInternalModerator, (req, res) => {
  const schema = getWeeklyImpulseSchema();
  if (!schema) {
    return res.status(500).json({ error: 'Weekly Impulse Schema fehlt' });
  }

  const { reportId } = req.params;
  const impulseId = typeof req.body?.impulseId === 'string' ? req.body.impulseId.trim() : '';
  const moderatorName = req.firebaseIdentity.email;
  const moderatorNote =
    typeof req.body?.moderatorNote === 'string' ? req.body.moderatorNote.trim() : '';

  if (!impulseId || !reportId) {
    return res.status(400).json({ error: 'impulseId und reportId sind erforderlich' });
  }

  const state = getWeeklyImpulseCommunityEntry(impulseId);
  for (const reports of Object.values(state.reportsByPostId || {})) {
    const match = (reports || []).find(item => item.id === reportId);
    if (match) {
      match.resolvedAt = new Date().toISOString();
      match.resolvedBy = moderatorName;
      match.moderatorNote = moderatorNote;
      match.lastAction = 'resolved';
      match.lastActionAt = match.resolvedAt;
      return res.json({ item: match });
    }
  }

  return res.status(404).json({ error: 'Report nicht gefunden' });
});

app.post('/api/weekly-impulse/community/posts/:postId/moderation-visibility', requireVerifiedUser, requireInternalModerator, (req, res) => {
  const schema = getWeeklyImpulseSchema();
  if (!schema) {
    return res.status(500).json({ error: 'Weekly Impulse Schema fehlt' });
  }

  const { postId } = req.params;
  const impulseId = typeof req.body?.impulseId === 'string' ? req.body.impulseId.trim() : '';
  const moderatorName = req.firebaseIdentity.email;
  const moderatorNote =
    typeof req.body?.moderatorNote === 'string' ? req.body.moderatorNote.trim() : '';
  const reportId = typeof req.body?.reportId === 'string' ? req.body.reportId.trim() : '';
  const hidden = req.body?.hidden === true;

  if (!impulseId || !postId) {
    return res.status(400).json({ error: 'impulseId und postId sind erforderlich' });
  }

  const post = findWeeklyImpulseCommunityPost({ schema, impulseId, postId });
  if (!post) {
    return res.status(404).json({ error: 'Community-Post nicht gefunden' });
  }

  const state = getWeeklyImpulseCommunityEntry(impulseId);
  if (hidden) {
    state.hiddenPostIds[postId] = {
      hidden: true,
      hiddenAt: new Date().toISOString(),
      hiddenBy: moderatorName,
    };
  } else {
    delete state.hiddenPostIds[postId];
  }

  if (reportId) {
    for (const reports of Object.values(state.reportsByPostId || {})) {
      const match = (reports || []).find(item => item.id === reportId);
      if (match) {
        match.moderatorNote = moderatorNote;
        match.lastAction = hidden ? 'hidden' : 'restored';
        match.lastActionAt = new Date().toISOString();
        break;
      }
    }
  }

  return res.json({
    postId,
    hidden,
    hiddenAt: state.hiddenPostIds[postId]?.hiddenAt || null,
    hiddenBy: state.hiddenPostIds[postId]?.hiddenBy || '',
  });
});

// 1. Alle Anbieter abrufen
app.get('/api/providers', async (req, res) => {
  const providers = await getProvidersWithReviewStats();
  res.json(providers);
});

// 2. Anbieter nach Kategorie filtern
app.get('/api/providers/category/:category', async (req, res) => {
  const { category } = req.params;
  const providers = await getProvidersWithReviewStats();
  const filtered = providers.filter(p => p.category === category || p.subcategory === category);
  res.json(filtered);
});

// 3. Anbieter nach ID abrufen
app.get('/api/providers/:id', async (req, res) => {
  const { id } = req.params;
  const providers = await getProvidersWithReviewStats();
  const provider = providers.find(p => p.id === id);

  if (!provider) {
    return res.status(404).json({ error: 'Anbieter nicht gefunden' });
  }

  res.json(provider);
});

// 4. Suche nach Name
app.get('/api/search', async (req, res) => {
  const { q } = req.query;

  if (!q) {
    return res.status(400).json({ error: 'Suchtext erforderlich' });
  }

  const providers = await getProvidersWithReviewStats();
  const filtered = providers.filter(p =>
    p.name.toLowerCase().includes(q.toLowerCase()) ||
    p.category.toLowerCase().includes(q.toLowerCase()) ||
    p.description.toLowerCase().includes(q.toLowerCase())
  );

  res.json(filtered);
});

// 5. Alle Kategorien abrufen
app.get('/api/categories', async (req, res) => {
  const providers = await getProvidersWithReviewStats();
  const categories = [...new Set(providers.map(p => p.category))];
  res.json(categories);
});

// 6. Neue Bewertung hinzufügen (dateibasiert persistiert)
app.post('/api/providers/:id/review', async (req, res) => {
  const { id } = req.params;
  const { rating, comment, parentName } = req.body;

  if (!rating || rating < 1 || rating > 5) {
    return res.status(400).json({ error: 'Bewertung muss zwischen 1 und 5 liegen' });
  }

  const providers = getProviders();
  const provider = providers.find(p => p.id === id);

  if (!provider) {
    return res.status(404).json({ error: 'Anbieter nicht gefunden' });
  }

  const normalizedRating = Number(rating);
  const normalizedComment = (comment || '').toString().trim();
  const normalizedParentName = (parentName || 'Anonym').toString().trim();
  provider.reviewEntries = Array.isArray(provider.reviewEntries) ? provider.reviewEntries : [];
  provider.reviewEntries.unshift({
    id: `review-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
    rating: normalizedRating,
    comment: normalizedComment,
    parentName: normalizedParentName,
    createdAt: new Date().toISOString(),
  });

  // Aktualisiere aggregiertes Rating und Reviews-Zaehler dateibasiert persistent.
  provider.reviews += 1;
  provider.rating = ((provider.rating * (provider.reviews - 1)) + normalizedRating) / provider.reviews;

  let persistedToDatabase = false;
  try {
    await ensureProviderReviewSchemaReady();
    await prisma.$executeRaw`
      INSERT INTO "ProviderReview" ("id", "providerId", "rating", "comment", "parentName", "createdAt")
      VALUES (${`review-${Date.now()}-${Math.floor(Math.random() * 1000)}`}, ${id}, ${Math.round(normalizedRating)}, ${normalizedComment || null}, ${normalizedParentName || null}, ${new Date()})
    `;
    persistedToDatabase = true;
  } catch (error) {
    console.error('ProviderReview konnte nicht in DB gespeichert werden:', error?.message || error);
  }

  const saved = saveProviders(providers);
  if (!saved) {
    return res.status(500).json({ error: 'Bewertung konnte nicht gespeichert werden' });
  }

  res.json({
    message: 'Bewertung hinzugefügt',
    persistedToDatabase,
    provider: provider
  });
});

// 7. Filter nach Kriterien
app.post('/api/providers/filter', async (req, res) => {
  const { categories, maxPrice, minRating } = req.body;

  let providers = await getProvidersWithReviewStats();

  if (categories && categories.length > 0) {
    providers = providers.filter(p => categories.includes(p.category));
  }

  if (maxPrice) {
    providers = providers.filter(p => p.price <= maxPrice);
  }

  if (minRating) {
    providers = providers.filter(p => p.rating >= minRating);
  }

  res.json(providers);
});

// 8. Todos (Prisma-first with in-memory fallback)
app.get('/todos', requireVerifiedUser, requireOwnFamily, async (req, res) => {
  try {
    const familyId = req.ownFamily.id;
    const items = await prisma.todo.findMany({
      where: { familyId },
      orderBy: { createdAt: 'desc' },
    });
    return res.json({ items: items.map(mapTodoRecordToApiItem) });
  } catch (error) {
    if (!allowPrivateFamilyFallback()) {
      respondFamilyPersistenceError(res, 'GET /todos', error);
      return;
    }
    console.error('GET /todos: isolated development fallback', error?.code || error?.name);
    return res.json({ items: todos.filter(item => item.familyId === req.ownFamily.id) });
  }
});

app.post('/todos', requireVerifiedUser, requireOwnFamily, async (req, res) => {
  try {
    const familyId = req.ownFamily.id;
    const completed = Boolean(req.body.completed);
    const item = await prisma.todo.create({
      data: {
        familyId,
        title: (req.body.title || '').toString(),
        description: buildTodoDescription({
          assigneeName: req.body.assigneeName || 'Familie',
          category: req.body.category || 'Allgemein',
        }),
        done: completed,
        completedAt: completed ? new Date() : null,
      },
    });
    return res.status(201).json({ item: mapTodoRecordToApiItem(item) });
  } catch (error) {
    if (!allowPrivateFamilyFallback()) {
      respondFamilyPersistenceError(res, 'POST /todos', error);
      return;
    }
    console.error('POST /todos: isolated development fallback', error?.code || error?.name);
    const item = {
      id: generateId('todo'),
      familyId: req.ownFamily.id,
      title: req.body.title || '',
      completed: Boolean(req.body.completed),
      assigneeName: req.body.assigneeName || 'Familie',
      category: req.body.category || 'Allgemein',
      createdAt: new Date().toISOString(),
    };
    todos.unshift(item);
    return res.status(201).json({ item });
  }
});

app.put('/todos/:id', requireVerifiedUser, requireOwnFamily, async (req, res) => {
  try {
    const item = await prisma.$transaction(async transaction => {
      const where = { id: req.params.id, familyId: req.ownFamily.id };
      const existing = await transaction.todo.findUnique({ where });
      if (!existing) return null;
      const currentMeta = parseTodoDescription(existing.description);
      const completed = Boolean(req.body.completed);
      return transaction.todo.update({
        where,
        data: {
          done: completed,
          completedAt: completed ? (existing.completedAt || new Date()) : null,
          description: buildTodoDescription({
            assigneeName: req.body.assigneeName || currentMeta.assigneeName,
            category: req.body.category || currentMeta.category,
          }),
        },
      });
    }, { isolationLevel: 'Serializable' });
    if (!item) {
      return res.status(404).json({ error: 'Todo nicht gefunden' });
    }
    return res.json({ item: mapTodoRecordToApiItem(item) });
  } catch (error) {
    if (error?.code === 'P2025') return res.status(404).json({ error: 'Todo nicht gefunden' });
    if (!allowPrivateFamilyFallback() || error?.code === 'P2034') {
      respondFamilyPersistenceError(res, 'PUT /todos/:id', error);
      return;
    }
    console.error('PUT /todos/:id: isolated development fallback', error?.code || error?.name);
    const index = todos.findIndex(item => item.id === req.params.id && item.familyId === req.ownFamily.id);
    if (index === -1) {
      return res.status(404).json({ error: 'Todo nicht gefunden' });
    }
    todos[index] = {
      ...todos[index],
      completed: Boolean(req.body.completed),
      updatedAt: new Date().toISOString(),
    };
    return res.json({ item: todos[index] });
  }
});

app.delete('/todos/:id', requireVerifiedUser, requireOwnFamily, async (req, res) => {
  try {
    await prisma.todo.delete({ where: { id: req.params.id, familyId: req.ownFamily.id } });
    return res.status(204).send();
  } catch (error) {
    if (error?.code === 'P2025') {
      return res.status(404).json({ error: 'Todo nicht gefunden' });
    }

    if (!allowPrivateFamilyFallback()) {
      respondFamilyPersistenceError(res, 'DELETE /todos/:id', error);
      return;
    }
    console.error('DELETE /todos/:id: isolated development fallback', error?.code || error?.name);
    const index = todos.findIndex(item => item.id === req.params.id && item.familyId === req.ownFamily.id);
    if (index === -1) {
      return res.status(404).json({ error: 'Todo nicht gefunden' });
    }
    todos.splice(index, 1);
    return res.status(204).send();
  }
});

// 9. Shopping (Prisma-first with in-memory fallback)
app.get('/shopping', requireVerifiedUser, requireOwnFamily, async (req, res) => {
  try {
    const familyId = req.ownFamily.id;
    const items = await prisma.shoppingItem.findMany({
      where: { familyId },
      orderBy: { createdAt: 'desc' },
    });
    return res.json({ items: items.map(mapShoppingRecordToApiItem) });
  } catch (error) {
    if (!allowPrivateFamilyFallback()) {
      respondFamilyPersistenceError(res, 'GET /shopping', error);
      return;
    }
    console.error('GET /shopping: isolated development fallback', error?.code || error?.name);
    return res.json({ items: shoppingItems.filter(item => item.familyId === req.ownFamily.id) });
  }
});

app.post('/shopping', requireVerifiedUser, requireOwnFamily, async (req, res) => {
  try {
    const familyId = req.ownFamily.id;
    const checked = Boolean(req.body.checked);
    const item = await prisma.shoppingItem.create({
      data: {
        familyId,
        name: (req.body.name || '').toString(),
        quantity: 1,
        bought: checked,
        boughtAt: checked ? new Date() : null,
      },
    });
    return res.status(201).json({ item: mapShoppingRecordToApiItem(item) });
  } catch (error) {
    if (!allowPrivateFamilyFallback()) {
      respondFamilyPersistenceError(res, 'POST /shopping', error);
      return;
    }
    console.error('POST /shopping: isolated development fallback', error?.code || error?.name);
    const item = {
      id: generateId('shop'),
      familyId: req.ownFamily.id,
      name: req.body.name || '',
      checked: Boolean(req.body.checked),
      category: req.body.category || 'Allgemein',
      createdAt: new Date().toISOString(),
    };
    shoppingItems.unshift(item);
    return res.status(201).json({ item });
  }
});

app.put('/shopping/:id', requireVerifiedUser, requireOwnFamily, async (req, res) => {
  try {
    const checked = Boolean(req.body.checked);
    const item = await prisma.shoppingItem.update({
      where: { id: req.params.id, familyId: req.ownFamily.id },
      data: {
        bought: checked,
        boughtAt: checked ? new Date() : null,
      },
    });
    return res.json({ item: mapShoppingRecordToApiItem(item) });
  } catch (error) {
    if (error?.code === 'P2025') {
      return res.status(404).json({ error: 'Shopping-Item nicht gefunden' });
    }

    if (!allowPrivateFamilyFallback()) {
      respondFamilyPersistenceError(res, 'PUT /shopping/:id', error);
      return;
    }
    console.error('PUT /shopping/:id: isolated development fallback', error?.code || error?.name);
    const index = shoppingItems.findIndex(item => item.id === req.params.id && item.familyId === req.ownFamily.id);
    if (index === -1) {
      return res.status(404).json({ error: 'Shopping-Item nicht gefunden' });
    }

    shoppingItems[index] = {
      ...shoppingItems[index],
      checked: Boolean(req.body.checked),
      updatedAt: new Date().toISOString(),
    };
    return res.json({ item: shoppingItems[index] });
  }
});

app.delete('/shopping/:id', requireVerifiedUser, requireOwnFamily, async (req, res) => {
  try {
    await prisma.shoppingItem.delete({ where: { id: req.params.id, familyId: req.ownFamily.id } });
    return res.status(204).send();
  } catch (error) {
    if (error?.code === 'P2025') {
      return res.status(404).json({ error: 'Shopping-Item nicht gefunden' });
    }

    if (!allowPrivateFamilyFallback()) {
      respondFamilyPersistenceError(res, 'DELETE /shopping/:id', error);
      return;
    }
    console.error('DELETE /shopping/:id: isolated development fallback', error?.code || error?.name);
    const index = shoppingItems.findIndex(item => item.id === req.params.id && item.familyId === req.ownFamily.id);
    if (index === -1) {
      return res.status(404).json({ error: 'Shopping-Item nicht gefunden' });
    }
    shoppingItems.splice(index, 1);
    return res.status(204).send();
  }
});

// 10. Calendar events
app.get('/calendar/events', requireVerifiedUser, async (req, res) => {
  const userId = req.firebaseUid;
  try {
    await ensureSocialSchemaReady();
    const rows = await prisma.$queryRawUnsafe(
      `SELECT * FROM "CalendarEvent" WHERE "userId" = $1 ORDER BY "startAt" ASC`,
      userId
    );
    return res.json({ items: rows });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'GET /calendar/events', error)) return;
    return res.json({ items: calendarEvents.filter(e => e.userId === userId) });
  }
});

app.post('/calendar/events', requireVerifiedUser, async (req, res) => {
  const userId = req.firebaseUid;
  const event = {
    id: generateId('cal'),
    userId,
    familyId: req.body.familyId || userId,
    title: (req.body.title || 'Neuer Termin').toString().trim(),
    startAt: req.body.startAt || req.body.startsAt || new Date().toISOString(),
    endAt: req.body.endAt || null,
    location: (req.body.location || '').toString().trim(),
    person: (req.body.personName || req.body.person || 'Eltern').toString().trim(),
    allDay: req.body.allDay === true,
    recurrence: (req.body.recurrence || 'Einmalig').toString().trim(),
    recurrenceEndMode: (req.body.recurrenceEndMode || 'Kein Ende').toString().trim(),
    recurrenceEndDate: req.body.recurrenceEndDate || null,
    recurrenceCount: req.body.recurrenceCount ? Number(req.body.recurrenceCount) : null,
    reminderMinutes: Number(req.body.reminderMinutes || 0),
    packReminder: req.body.packReminder || null,
    bringer: req.body.bringer || null,
    abholer: req.body.abholer || null,
  };
  try {
    await ensureSocialSchemaReady();
    await prisma.$executeRawUnsafe(
      `INSERT INTO "CalendarEvent" ("id","userId","familyId","title","startAt","endAt","location","person","allDay","recurrence","recurrenceEndMode","recurrenceEndDate","recurrenceCount","reminderMinutes","packReminder","bringer","abholer") VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17)`,
      event.id, event.userId, event.familyId, event.title,
      event.startAt, event.endAt, event.location, event.person,
      event.allDay, event.recurrence, event.recurrenceEndMode,
      event.recurrenceEndDate, event.recurrenceCount, event.reminderMinutes,
      event.packReminder, event.bringer, event.abholer
    );
    return res.status(201).json({ item: event });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'POST /calendar/events', error)) return;
    calendarEvents.unshift(event);
    return res.status(201).json({ item: event });
  }
});

app.delete('/calendar/events/:id', requireVerifiedUser, async (req, res) => {
  const id = (req.params.id || '').toString().trim();
  if (!id) return res.status(400).json({ error: 'id erforderlich' });
  try {
    await ensureSocialSchemaReady();
    const deleted = await prisma.$executeRawUnsafe(
      `DELETE FROM "CalendarEvent" WHERE "id" = $1 AND "userId" = $2`,
      id, req.firebaseUid
    );
    if (deleted === 0) return res.status(404).json({ error: 'Termin nicht gefunden' });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'DELETE /calendar/events/:id', error)) return;
    const idx = calendarEvents.findIndex(e => e.id === id && e.userId === req.firebaseUid);
    if (idx === -1) return res.status(404).json({ error: 'Termin nicht gefunden' });
    calendarEvents.splice(idx, 1);
  }
  return res.status(200).json({ deleted: id });
});

// 11. Photos
app.get('/photos', (req, res) => {
  res.json({ items: photoAlbums });
});

app.post('/photos', (req, res) => {
  const album = {
    id: generateId('album'),
    familyId: req.body.familyId || 'demo-family-001',
    title: req.body.title || 'Neues Album',
    photoCount: Number(req.body.photoCount || 0),
    createdAt: req.body.createdAt || new Date().toISOString(),
  };
  photoAlbums.unshift(album);
  res.status(201).json({ item: album });
});

// 12. Parent matching
app.post('/parent-matching/verification/request-otp', async (req, res) => {
  const userId = (req.body.userId || '').toString().trim();
  const phoneNumber = (req.body.phoneNumber || '').toString().trim();

  if (!userId) {
    return res.status(400).json({ error: 'userId fehlt' });
  }
  const digits = phoneNumber.replace(/\D/g, '');
  if (digits.length < 7 || digits.length > 15) {
    return res.status(400).json({ error: 'Ungueltige Telefonnummer' });
  }

  const now = Date.now();
  const bucket = parentMatchingOtpRateLimit.get(userId);
  if (!bucket || now - bucket.start > otpRateWindowMs) {
    parentMatchingOtpRateLimit.set(userId, { start: now, count: 1 });
  } else {
    bucket.count += 1;
    if (bucket.count > otpRateMax) {
      return res.status(429).json({ error: 'Zu viele OTP-Anfragen. Bitte später erneut versuchen.' });
    }
  }

  const code = `${Math.floor(100000 + Math.random() * 900000)}`;
  const expiresAt = now + otpTtlMs;
  parentMatchingOtpStore.set(userId, {
    codeHash: hashOtpForUser(userId, code),
    expiresAt,
    attempts: 0,
    phoneNumber: digits,
  });

  // In Produktion sollte der OTP-Code ueber einen SMS-Provider zugestellt werden.
  // Dieser Endpoint gibt den Code nur in Entwicklungsumgebungen zurück.
  return res.status(202).json({
    ok: true,
    channel: 'sms',
    phoneHint: maskPhone(digits),
    expiresInSec: Math.floor(otpTtlMs / 1000),
    ...(allowDevOtpEcho ? { devCode: code } : {}),
  });
});

app.post('/parent-matching/verification/confirm-otp', async (req, res) => {
  const userId = (req.body.userId || '').toString().trim();
  const code = (req.body.code || '').toString().trim();

  if (!userId) {
    return res.status(400).json({ error: 'userId fehlt' });
  }
  if (!/^\d{6}$/.test(code)) {
    return res.status(400).json({ error: 'OTP-Code ungueltig' });
  }

  const stored = parentMatchingOtpStore.get(userId);
  if (!stored) {
    return res.status(404).json({ error: 'Keine offene OTP-Anfrage gefunden' });
  }
  if (Date.now() > stored.expiresAt) {
    parentMatchingOtpStore.delete(userId);
    return res.status(410).json({ error: 'OTP-Code abgelaufen' });
  }
  if ((stored.attempts || 0) >= otpMaxAttempts) {
    parentMatchingOtpStore.delete(userId);
    return res.status(429).json({ error: 'Zu viele Fehlversuche. Bitte neuen OTP anfordern.' });
  }

  stored.attempts = (stored.attempts || 0) + 1;
  parentMatchingOtpStore.set(userId, stored);

  const codeHash = hashOtpForUser(userId, code);
  if (codeHash !== stored.codeHash) {
    return res.status(401).json({ error: 'OTP-Code falsch' });
  }

  parentMatchingOtpStore.delete(userId);

  try {
    await ensureParentMatchingSchemaReady();
    await ensureParentMatchingProfileForUser(userId);
    const updated = await prisma.parentMatchingProfile.updateMany({
      where: {
        ownerUserId: userId,
        isActive: true,
      },
      data: {
        phoneVerified: true,
        verificationLevel: 'checked',
        updatedAt: new Date(),
      },
    });

    return res.json({
      ok: true,
      verified: true,
      updatedProfiles: updated.count,
    });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'POST /parent-matching/verification/confirm-otp', error)) {
      return;
    }
    ensureParentMatchingProfileForUserInMemory(userId);
    const existing = getMyParentMatchingProfileInMemory(userId);
    if (!existing) {
      return res.status(404).json({ error: 'Matching-Profil nicht gefunden' });
    }
    existing.phoneVerified = true;
    existing.verificationLevel = 'checked';
    existing.updatedAt = new Date().toISOString();
    return res.json({ ok: true, verified: true, updatedProfiles: 1 });
  }
});

app.get('/parent-matching/my-profile', async (req, res) => {
  const userId = (req.query.userId || '').toString().trim();
  if (!userId) {
    return res.status(400).json({ error: 'userId fehlt' });
  }
  if (!req.firebaseUid) {
    const { uid, verified } = await verifyFirebaseIdToken(req);
    if (verified) req.firebaseUid = uid;
  }
  if (!req.firebaseUid) {
    return res.status(401).json({ error: 'Firebase sign-in required' });
  }
  if (req.firebaseUid !== userId) {
    return res.status(403).json({ error: 'Own profile only' });
  }

  try {
    const profile = await getMyParentMatchingProfile(userId);
    if (!profile) {
      return res.status(404).json({ error: 'Matching-Profil nicht gefunden' });
    }
    return res.json({ item: mapParentMatchingProfileForClient(profile) });
  } catch (error) {
    console.error('[parent-matching/my-profile] Verification failed:', error);
    return res.status(503).json({ error: 'Profile verification unavailable' });
  }
});

function parseOptionalParentAge(value, min = 16, max = 99) {
  if (value === undefined || value === null || value === '') return null;
  if (typeof value !== 'number' && typeof value !== 'string') return undefined;
  if (typeof value === 'string' && !value.trim()) return undefined;
  const age = Number(value);
  return Number.isInteger(age) && age >= min && age <= max ? age : undefined;
}

function parseOptionalParentCoordinate(value, maxAbsolute) {
  if (value === undefined || value === null || value === '') return null;
  if (typeof value !== 'number' && typeof value !== 'string') return undefined;
  if (typeof value === 'string' && !value.trim()) return undefined;
  const coordinate = Number(value);
  return Number.isFinite(coordinate) && Math.abs(coordinate) <= maxAbsolute
    ? coordinate : undefined;
}

app.post('/parent-matching/my-profile', async (req, res) => {
  const userId = (req.body.userId || '').toString().trim();
  if (!userId) {
    return res.status(400).json({ error: 'userId fehlt' });
  }
  if (!req.firebaseUid) {
    const { uid, verified } = await verifyFirebaseIdToken(req);
    if (verified) req.firebaseUid = uid;
  }
  if (!req.firebaseUid) {
    return res.status(401).json({ error: 'Firebase sign-in required' });
  }
  if (req.firebaseUid !== userId) {
    return res.status(403).json({ error: 'Own profile only' });
  }

  const name = (req.body.name || '').toString().trim();
  if (!name) {
    return res.status(400).json({ error: 'Name fehlt' });
  }

  const age = parseOptionalParentAge(req.body.age);
  const city = (req.body.city || '').toString().trim();
  const familyForm = (req.body.familyForm || '').toString().trim();
  const bio = (req.body.bio || '').toString().trim();
  const latitude = parseOptionalParentCoordinate(req.body.latitude, 90);
  const longitude = parseOptionalParentCoordinate(req.body.longitude, 180);
  if (latitude === undefined || longitude === undefined ||
      (latitude === null) !== (longitude === null)) {
    return res.status(400).json({ error: 'Koordinaten sind ungueltig oder unvollstaendig' });
  }

  const toList = value => Array.isArray(value)
    ? value.map(item => item?.toString().trim()).filter(Boolean)
    : [];

  const interests = toList(req.body.interests);
  const languages = toList(req.body.languages);
  const valuesFocus = toList(req.body.valuesFocus || req.body.values);
  const childAges = toList(req.body.childAges);

  if (age === undefined) {
    return res.status(400).json({ error: 'Alter ist ungültig' });
  }
  if (!city) {
    return res.status(400).json({ error: 'Stadt fehlt' });
  }
  if (!familyForm) {
    return res.status(400).json({ error: 'Familienform fehlt' });
  }

  try {
    await ensureParentMatchingSchemaReady();
    const profile = await prisma.parentMatchingProfile.upsert({
      where: { externalId: `self-${userId}` },
      update: {
        ownerUserId: userId,
        name,
        age,
        city,
        latitude,
        longitude,
        bio,
        interests,
        languages,
        valuesFocus,
        childAges,
        familyForm,
        isActive: true,
      },
      create: {
        externalId: `self-${userId}`,
        ownerUserId: userId,
        name,
        age,
        city,
        latitude,
        longitude,
        bio,
        interests,
        languages,
        valuesFocus,
        childAges,
        familyForm,
        verificationLevel: 'basic',
        phoneVerified: false,
        identityVerified: false,
        moderationChecked: false,
        isActive: true,
      },
    });

    return res.status(201).json({ item: mapParentMatchingProfileForClient(profile) });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'POST /parent-matching/my-profile', error)) {
      return;
    }
    const profile = upsertMyParentMatchingProfileInMemory({
      userId,
      name,
      age,
      city,
      latitude,
      longitude,
      bio,
      interests,
      languages,
      valuesFocus,
      childAges,
      familyForm,
    });
    return res.status(201).json({ item: mapParentMatchingProfileForClient(profile) });
  }
});

app.delete('/parent-matching/my-profile', async (req, res) => {
  const userId = (req.query.userId || '').toString().trim();
  if (!req.firebaseUid) {
    return res.status(401).json({ error: 'Firebase sign-in required' });
  }
  if (userId !== req.firebaseUid) {
    return res.status(403).json({ error: 'Own account only' });
  }
  try {
    await ensureParentMatchingSchemaReady();
    await prisma.parentMatchingProfile.deleteMany({ where: { ownerUserId: userId } });
    for (let i = parentProfiles.length - 1; i >= 0; i--) {
      if (parentProfiles[i].ownerUserId === userId) parentProfiles.splice(i, 1);
    }
    return res.json({ success: true });
  } catch (error) {
    console.error('Matching-Profil konnte nicht geloescht werden:', error);
    return res.status(503).json({ error: 'Profil konnte nicht geloescht werden' });
  }
});

app.get('/parent-matching/profiles', requireVerifiedUser, async (req, res) => {
  const userId = req.firebaseUid;
  try {
    const result = await discoverParentMatchingProfiles({
      userId,
      limit: req.query.limit || '100',
      maxDistanceKm: req.query.maxDistanceKm || '25',
    });
    if (result === null) {
      return res.status(409).json({ error: 'Bitte zuerst eigenes Matching-Profil anlegen' });
    }
    return res.json({ profiles: result.matches.map(match => match.profile) });
  } catch (error) {
    console.error('Parent matching profiles unavailable:', error);
    return res.status(503).json({ error: 'Matching discovery unavailable' });
  }
});

app.get('/parent-matching/connections', requireVerifiedUser, requireOwnFamily, async (req, res) => {
  const familyId = req.ownFamily.id;
  const userId = req.firebaseUid;

  try {
    const ownProfile = await getMyParentMatchingProfile(userId);
    if (!ownProfile) {
      return res.status(409).json({ error: 'Bitte zuerst eigenes Matching-Profil anlegen' });
    }

    const connectedProfileIds = await getMutualConnectionProfileIds(familyId, userId);

    return res.json({ profileIds: connectedProfileIds });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'GET /parent-matching/connections', error)) {
      return;
    }
    const ownProfile = getMyParentMatchingProfileInMemory(userId);
    if (!ownProfile) {
      return res.status(409).json({ error: 'Bitte zuerst eigenes Matching-Profil anlegen' });
    }
    const connectedProfileIds = getMutualConnectionProfileIdsInMemory(familyId, userId);
    return res.json({ profileIds: connectedProfileIds });
  }
});

async function recordParentMatchingAction(req, res) {
  const familyId = req.ownFamily.id;
  const profileIdInput = (req.body.profileId || req.body.matchedProfileId || '').toString().trim();
  const actionValue = (req.body.action || 'unknown').toString().trim().toLowerCase();
  const actorUserId = req.firebaseUid;

  if (!profileIdInput) {
    return res.status(400).json({ error: 'profileId fehlt' });
  }
  if (!actorUserId) {
    return res.status(400).json({ error: 'userId fehlt' });
  }

  if (!parentMatchingAllowedActions.has(actionValue)) {
    return res.status(400).json({ error: 'Ungültige Aktion' });
  }

  try {
    await ensureParentMatchingSchemaReady();
    const ownProfile = await getMyParentMatchingProfile(actorUserId);
    if (!ownProfile) {
      return res.status(409).json({ error: 'Bitte zuerst eigenes Matching-Profil anlegen' });
    }

    let targetProfile = await prisma.parentMatchingProfile.findUnique({
      where: { id: profileIdInput },
      select: { id: true, ownerUserId: true, isActive: true },
    });

    if (!targetProfile) {
      targetProfile = await prisma.parentMatchingProfile.findUnique({
        where: { externalId: profileIdInput },
        select: { id: true, ownerUserId: true, isActive: true },
      });
    }

    if (!targetProfile || targetProfile.isActive === false || !targetProfile.ownerUserId) {
      return res.status(404).json({ error: 'Profil nicht gefunden' });
    }
    if (targetProfile.ownerUserId === actorUserId) {
      return res.status(403).json({ error: 'Eigenes Profil kann nicht kontaktiert werden' });
    }

    const createdAction = await prisma.parentMatchingAction.create({
      data: {
        familyId,
        profileId: targetProfile.id,
        action: actionValue,
        createdAt: new Date(),
        actorUserId,
      },
    });

    const mutualProfileIds = await getMutualConnectionProfileIds(familyId, actorUserId);
    const connected = actionValue === 'like' && mutualProfileIds.includes(targetProfile.id);

    return res.status(201).json({
      item: createdAction,
      action: createdAction,
      connected,
      matchState: connected
        ? 'matched'
        : (actionValue === 'like' ? 'pending' : 'none'),
    });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'POST /parent-matching/actions', error)) {
      return;
    }
    if (!getMyParentMatchingProfileInMemory(actorUserId)) {
      return res.status(409).json({ error: 'Bitte zuerst eigenes Matching-Profil anlegen' });
    }
    const targetProfile = parentProfiles.find(item =>
      item.id === profileIdInput || item.externalId === profileIdInput);
    if (!targetProfile || targetProfile.isActive === false || !targetProfile.ownerUserId) {
      return res.status(404).json({ error: 'Profil nicht gefunden' });
    }
    if (targetProfile.ownerUserId === actorUserId) {
      return res.status(403).json({ error: 'Eigenes Profil kann nicht kontaktiert werden' });
    }
    const createdAction = {
      id: generateId('pm-action'),
      familyId,
      profileId: targetProfile.id,
      action: actionValue,
      userId: actorUserId,
      createdAt: new Date().toISOString(),
    };
    parentMatchingActions.unshift(createdAction);
    const mutualProfileIds = getMutualConnectionProfileIdsInMemory(familyId, actorUserId);
    const connected = actionValue === 'like' && mutualProfileIds.includes(targetProfile.id);
    return res.status(201).json({
      item: createdAction,
      action: createdAction,
      connected,
      matchState: connected
        ? 'matched'
        : (actionValue === 'like' ? 'pending' : 'none'),
    });
  }
}

app.post('/parent-matching/actions', requireVerifiedUser, requireOwnFamily, recordParentMatchingAction);

app.get('/parent-matching/messages/stream', requireVerifiedUser, async (req, res) => {
  const familyId = (req.query.familyId || DEMO_FAMILY_ID).toString().trim();
  const profileId = (req.query.profileId || '').toString().trim();
  // Identitaet ausschliesslich aus dem verifizierten Token; eine abweichende
  // query.userId wird bereits von requireVerifiedUser mit 403 abgelehnt.
  const userId = req.firebaseUid;

  if (!profileId) {
    return res.status(400).json({ error: 'profileId fehlt' });
  }

  try {
    const ownProfile = await getMyParentMatchingProfile(userId);
    if (!ownProfile) {
      return res.status(409).json({ error: 'Bitte zuerst eigenes Matching-Profil anlegen' });
    }

    const connectedProfileIds = await getMutualConnectionProfileIds(familyId, userId);
    if (!connectedProfileIds.includes(profileId)) {
      return res.status(403).json({ error: 'Chat erst nach beidseitigem Match verfügbar' });
    }

    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('X-Accel-Buffering', 'no');
    if (typeof res.flushHeaders === 'function') {
      res.flushHeaders();
    }
    res.write('event: ready\ndata: {"type":"ready"}\n\n');

    const key = parentMatchingStreamKey(familyId, profileId);
    if (!parentMatchingMessageSubscribers.has(key)) {
      parentMatchingMessageSubscribers.set(key, new Set());
    }
    const subscribers = parentMatchingMessageSubscribers.get(key);
    subscribers.add(res);

    const heartbeat = setInterval(() => {
      res.write('event: ping\ndata: {"type":"ping"}\n\n');
    }, 25000);

    req.on('close', () => {
      clearInterval(heartbeat);
      const current = parentMatchingMessageSubscribers.get(key);
      if (!current) return;
      current.delete(res);
      if (current.size === 0) {
        parentMatchingMessageSubscribers.delete(key);
      }
    });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'GET /parent-matching/messages/stream', error)) {
      return;
    }
    const ownProfile = getMyParentMatchingProfileInMemory(userId);
    if (!ownProfile) {
      return res.status(409).json({ error: 'Bitte zuerst eigenes Matching-Profil anlegen' });
    }
    const connectedProfileIds = getMutualConnectionProfileIdsInMemory(familyId, userId);
    if (!connectedProfileIds.includes(profileId)) {
      return res.status(403).json({ error: 'Chat erst nach beidseitigem Match verfügbar' });
    }
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('X-Accel-Buffering', 'no');
    if (typeof res.flushHeaders === 'function') {
      res.flushHeaders();
    }
    res.write('event: ready\ndata: {"type":"ready"}\n\n');
    const key = parentMatchingStreamKey(familyId, profileId);
    if (!parentMatchingMessageSubscribers.has(key)) {
      parentMatchingMessageSubscribers.set(key, new Set());
    }
    const subscribers = parentMatchingMessageSubscribers.get(key);
    subscribers.add(res);
    const heartbeat = setInterval(() => {
      res.write('event: ping\ndata: {"type":"ping"}\n\n');
    }, 25000);
    req.on('close', () => {
      clearInterval(heartbeat);
      const current = parentMatchingMessageSubscribers.get(key);
      if (!current) return;
      current.delete(res);
      if (current.size === 0) {
        parentMatchingMessageSubscribers.delete(key);
      }
    });
  }
});

app.get('/parent-matching/messages', requireVerifiedUser, async (req, res) => {
  const familyId = (req.query.familyId || DEMO_FAMILY_ID).toString().trim();
  const profileId = (req.query.profileId || '').toString().trim();
  const userId = req.firebaseUid;

  if (!profileId) {
    return res.status(400).json({ error: 'profileId fehlt' });
  }

  try {
    const ownProfile = await getMyParentMatchingProfile(userId);
    if (!ownProfile) {
      return res.status(409).json({ error: 'Bitte zuerst eigenes Matching-Profil anlegen' });
    }

    const connectedProfileIds = await getMutualConnectionProfileIds(familyId, userId);
    if (!connectedProfileIds.includes(profileId)) {
      return res.status(403).json({ error: 'Chat erst nach beidseitigem Match verfügbar' });
    }

    const rows = await prisma.$queryRaw`
      SELECT "id", "familyId", "profileId", "authorUserId", "authorName", "content", "createdAt"
      FROM "ParentMatchingMessage"
      WHERE "familyId" = ${familyId} AND "profileId" = ${profileId}
      ORDER BY "createdAt" ASC
      LIMIT 300
    `;

    return res.json({
      items: rows.map(item => ({
        id: item.id,
        familyId: item.familyId,
        profileId: item.profileId,
        authorUserId: item.authorUserId,
        authorName: item.authorName,
        content: item.content,
        createdAt: item.createdAt,
      })),
    });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'GET /parent-matching/messages', error)) {
      return;
    }
    const ownProfile = getMyParentMatchingProfileInMemory(userId);
    if (!ownProfile) {
      return res.status(409).json({ error: 'Bitte zuerst eigenes Matching-Profil anlegen' });
    }
    const connectedProfileIds = getMutualConnectionProfileIdsInMemory(familyId, userId);
    if (!connectedProfileIds.includes(profileId)) {
      return res.status(403).json({ error: 'Chat erst nach beidseitigem Match verfügbar' });
    }
    const items = parentMatchingMessages
      .filter(item => item.familyId === familyId && item.profileId === profileId)
      .sort((a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime())
      .slice(0, 300);
    return res.json({ items });
  }
});

app.post('/parent-matching/messages', requireVerifiedUser, async (req, res) => {
  const familyId = (req.body.familyId || DEMO_FAMILY_ID).toString().trim();
  const profileId = (req.body.profileId || '').toString().trim();
  // Autor ist der verifizierte Token-Nutzer; eine abweichende body.userId wird
  // bereits von requireVerifiedUser mit 403 abgelehnt.
  const authorUserId = req.firebaseUid;
  const authorName = (req.body.userName || 'Elternteil').toString().trim();
  const content = (req.body.content || '').toString().trim();

  if (!profileId) {
    return res.status(400).json({ error: 'profileId fehlt' });
  }
  if (!content) {
    return res.status(400).json({ error: 'Nachricht fehlt' });
  }

  try {
    const ownProfile = await getMyParentMatchingProfile(authorUserId);
    if (!ownProfile) {
      return res.status(409).json({ error: 'Bitte zuerst eigenes Matching-Profil anlegen' });
    }

    const connectedProfileIds = await getMutualConnectionProfileIds(familyId, authorUserId);
    if (!connectedProfileIds.includes(profileId)) {
      return res.status(403).json({ error: 'Chat erst nach beidseitigem Match verfügbar' });
    }

    await ensureParentMatchingSchemaReady();
    const id = generateId('pm-msg');
    await prisma.$executeRaw`
      INSERT INTO "ParentMatchingMessage" (
        "id", "familyId", "profileId", "authorUserId", "authorName", "content", "createdAt"
      ) VALUES (
        ${id}, ${familyId}, ${profileId}, ${authorUserId}, ${authorName}, ${content}, ${new Date()}
      )
    `;

    const item = {
      id,
      familyId,
      profileId,
      authorUserId,
      authorName,
      content,
      createdAt: new Date().toISOString(),
    };
    publishParentMatchingMessage(item);
    return res.status(201).json({ item });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'POST /parent-matching/messages', error)) {
      return;
    }
    const ownProfile = getMyParentMatchingProfileInMemory(authorUserId);
    if (!ownProfile) {
      return res.status(409).json({ error: 'Bitte zuerst eigenes Matching-Profil anlegen' });
    }
    const connectedProfileIds = getMutualConnectionProfileIdsInMemory(familyId, authorUserId);
    if (!connectedProfileIds.includes(profileId)) {
      return res.status(403).json({ error: 'Chat erst nach beidseitigem Match verfügbar' });
    }
    const item = {
      id: generateId('pm-msg'),
      familyId,
      profileId,
      authorUserId,
      authorName,
      content,
      createdAt: new Date().toISOString(),
    };
    parentMatchingMessages.push(item);
    publishParentMatchingMessage(item);
    return res.status(201).json({ item });
  }
});

// ── Friend connections ──────────────────────────────────────────────────────
const friendRegistry = new Map();          // in-memory fallback
const friendPendingConnections = new Map(); // in-memory fallback

// Aufloesen von Name + UID zu einem (alten) Freundes-Code. BEHALTEN als
// Bruecke: alte Einladungslinks + resolveCode im Client + DSGVO/Push-Altlasten.
app.get('/api/friends/lookup/:code', async (req, res) => {
  const code = canonicalCode(req.params.code);
  try {
    await ensureSocialSchemaReady();
    const rows = await prisma.$queryRawUnsafe(
      `SELECT "name", "userId" FROM "FriendRegistry" WHERE "code" = $1`, code
    );
    // Gibt jetzt auch die userId zurueck -> Code kann in eine UID-Freundschaft
    // ueberfuehrt werden (Bruecke vom alten Code-Weg ins neue UID-System).
    if (rows.length > 0) {
      return res.json({ name: rows[0].name, uid: rows[0].userId || null });
    }
    const mem = friendRegistry.get(code);
    if (mem) return res.json({ name: mem.name, uid: mem.userId || null });
    return res.status(404).json({ error: 'Nicht gefunden' });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'GET /api/friends/lookup', error)) return;
    const entry = friendRegistry.get(code);
    if (!entry) return res.status(404).json({ error: 'Nicht gefunden' });
    return res.json({ name: entry.name, uid: entry.userId || null });
  }
});

// ─── Durable friend list (Prio 2): survives reinstall ──────────────────────
const friendEdges = new Map();   // in-memory fallback: ownerCode -> [{friendCode, friendName}]
const safetyBlocks = new Map();  // in-memory fallback: blockerUserId -> Set(blockedUserId)
const safetyReports = [];        // in-memory fallback
const safetySuspensions = new Map(); // in-memory fallback: userId -> {reason, suspendedBy, createdAt}

// ─── Echter Bann (Suspension) — zentraler Check ────────────────────────────
// Kleiner Cache, damit haeufige Schreib-Aktionen die DB nicht ueberlasten.
const _suspensionCache = new Map(); // userId -> { suspended: bool, ts: number }
const _suspensionCacheTtlMs = 30 * 1000;

/// Prueft, ob ein Nutzer gesperrt ist. Fehlertolerant: bei DB-Problemen
/// greift der In-Memory-Fallback. Leere userId -> nie gesperrt.
async function isUserSuspended(userId, { strict = false } = {}) {
  const id = (userId || '').toString().trim();
  if (!id) return false;
  const cached = _suspensionCache.get(id);
  if (!strict && cached && Date.now() - cached.ts < _suspensionCacheTtlMs) {
    return cached.suspended;
  }
  // "Check both": Der uebergebene Wert kann eine Firebase-UID ODER ein
  // Freundes-Code sein. Wir sammeln beide Identitaeten (UID + Code) und
  // pruefen, ob EINE davon gesperrt ist. So greift der Bann unabhaengig davon,
  // ob per Code oder per UID gesperrt wurde.
  const candidates = new Set([id]);
  try {
    await ensureSocialSchemaReady();
    if (id.startsWith('pp-')) {
      // id ist ein Code -> zugehoerige userId ergaenzen.
      const reg = await resolveFriendRegistry(id);
      if (reg.userId) candidates.add(reg.userId);
    } else {
      // id ist (vermutlich) eine UID -> zugehoerige(n) Code(s) ergaenzen.
      const codeRows = await prisma.$queryRawUnsafe(
        `SELECT "code" FROM "FriendRegistry" WHERE "userId" = $1`, id
      );
      for (const r of codeRows) if (r.code) candidates.add(r.code);
    }
  } catch (error) {
    if (strict) throw error;
    // Fallback: Registry ueber In-Memory-Map.
    if (id.startsWith('pp-')) {
      const mem = friendRegistry.get(id);
      if (mem && mem.userId) candidates.add(mem.userId);
    } else {
      for (const [code, v] of friendRegistry.entries()) {
        if (v && v.userId === id) candidates.add(code);
      }
    }
  }

  let suspended = false;
  const list = [...candidates];
  try {
    const rows = await prisma.$queryRawUnsafe(
      `SELECT 1 FROM "SafetySuspension" WHERE "userId" = ANY($1::text[]) LIMIT 1`,
      list
    );
    suspended = rows.length > 0;
  } catch (error) {
    if (strict) throw error;
    suspended = list.some(c => safetySuspensions.has(c));
  }
  _suspensionCache.set(id, { suspended, ts: Date.now() });
  return suspended;
}

/// Einheitliche 403-Antwort fuer gesperrte Konten.
function respondSuspended(res) {
  return res.status(403).json({
    error:
      'Dein Konto wurde vorübergehend eingeschränkt. Bei Fragen wende dich an unseren Support.',
    code: 'account_suspended',
  });
}

// Cache invalidieren, wenn sich der Suspend-Status aendert.
function invalidateSuspensionCache(userId) {
  const id = (userId || '').toString().trim();
  if (id) _suspensionCache.delete(id);
}

/// Liefert alle Identitaeten (UID + Code) zu einem gegebenen Wert, damit
/// Sperren/Entsperren immer beide Seiten trifft.
async function expandIdentities(rawId) {
  const id = (rawId || '').toString().trim();
  if (!id) return [];
  const out = new Set([id]);
  try {
    await ensureSocialSchemaReady();
    if (id.startsWith('pp-')) {
      const reg = await resolveFriendRegistry(id);
      if (reg.userId) out.add(reg.userId);
    } else {
      const rows = await prisma.$queryRawUnsafe(
        `SELECT "code" FROM "FriendRegistry" WHERE "userId" = $1`, id
      );
      for (const r of rows) if (r.code) out.add(r.code);
    }
  } catch (_) {
    if (id.startsWith('pp-')) {
      const mem = friendRegistry.get(id);
      if (mem && mem.userId) out.add(mem.userId);
    } else {
      for (const [code, v] of friendRegistry.entries()) {
        if (v && v.userId === id) out.add(code);
      }
    }
  }
  return [...out];
}

// Loest Name + userId zu einem Freundes-Code auf (DB + In-Memory-Fallback).
// BEHALTEN: von isUserSuspended + Chat-Push (Alt-Raeume) + DSGVO genutzt.
async function resolveFriendRegistry(code) {
  const c = (code || '').toString().trim().toLowerCase();
  if (!c) return { name: null, userId: null };
  try {
    await ensureSocialSchemaReady();
    const rows = await prisma.$queryRawUnsafe(
      `SELECT "name", "userId" FROM "FriendRegistry" WHERE "code" = $1`, c
    );
    if (rows.length > 0) {
      return { name: rows[0].name || null, userId: rows[0].userId || null };
    }
  } catch (_) {
    const mem = friendRegistry.get(c);
    if (mem) return { name: mem.name || null, userId: mem.userId || null };
  }
  return { name: null, userId: null };
}

// Bringt einen Freundes-Code in die kanonische Form 'pp-xxxxxx' (klein, genau
// ein Bindestrich nach 'pp'). Verhindert kaputte Codes ohne Bindestrich.
function canonicalCode(raw) {
  let s = (raw || '').toString().trim().toLowerCase().replace(/\s/g, '');
  s = s.replace(/-/g, '');
  if (s.startsWith('pp')) {
    const rest = s.slice(2);
    return rest ? `pp-${rest}` : 'pp-';
  }
  return s ? `pp-${s}` : '';
}

// Diagnose (read-only) fuer Freundschaft/Chat. Gibt KEINE Geheimnisse preis:
// ─── Onboarding Minimal-Sync (Option A) ────────────────────────────────────
const onboardingProfiles = new Map(); // in-memory fallback: userId -> {...}

// Onboarding-Status/Stammdaten fuer einen Nutzer abrufen.
app.get('/api/onboarding/:userId', async (req, res) => {
  const userId = (req.params.userId || '').toString().trim();
  if (!userId) return res.status(400).json({ error: 'userId erforderlich' });
  if (!await authorizeProfileOwner(req, res, userId)) return;
  try {
    await ensureSocialSchemaReady();
    const rows = await prisma.$queryRawUnsafe(
      `SELECT "completed", "familyName", "parentRole", "priorities" FROM "OnboardingProfile" WHERE "userId" = $1`,
      userId
    );
    if (rows.length === 0) {
      return res.json({ completed: false });
    }
    const r = rows[0];
    return res.json({
      completed: r.completed === true,
      familyName: r.familyName || '',
      parentRole: r.parentRole || '',
      priorities: r.priorities ? r.priorities.split('|').filter(Boolean) : [],
    });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'GET /api/onboarding', error)) return;
    const mem = onboardingProfiles.get(userId);
    if (!mem) return res.json({ completed: false });
    return res.json(mem);
  }
});

// Onboarding-Status/Stammdaten speichern (nur unkritische Felder).
app.post('/api/onboarding', async (req, res) => {
  const userId = (req.body.userId || '').toString().trim();
  if (!userId) return res.status(400).json({ error: 'userId erforderlich' });
  if (!await authorizeProfileOwner(req, res, userId)) return;
  const completed = req.body.completed === true;
  const familyName = (req.body.familyName || '').toString().trim().slice(0, 100);
  const parentRole = (req.body.parentRole || '').toString().trim().slice(0, 50);
  const priorities = Array.isArray(req.body.priorities)
      ? req.body.priorities.map(p => p.toString().trim()).filter(Boolean).join('|').slice(0, 300)
      : '';
  try {
    await ensureSocialSchemaReady();
    await prisma.$executeRawUnsafe(
      `INSERT INTO "OnboardingProfile" ("userId", "completed", "familyName", "parentRole", "priorities", "updatedAt")
       VALUES ($1, $2, $3, $4, $5, NOW())
       ON CONFLICT ("userId") DO UPDATE SET
         "completed" = "OnboardingProfile"."completed" OR $2,
         "familyName" = COALESCE(NULLIF($3, ''), "OnboardingProfile"."familyName"),
         "parentRole" = COALESCE(NULLIF($4, ''), "OnboardingProfile"."parentRole"),
         "priorities" = COALESCE(NULLIF($5, ''), "OnboardingProfile"."priorities"),
         "updatedAt" = NOW()`,
      userId, completed, familyName, parentRole, priorities
    );
    return res.json({ ok: true });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'POST /api/onboarding', error)) return;
    const prev = onboardingProfiles.get(userId) || { completed: false, familyName: '', parentRole: '', priorities: [] };
    onboardingProfiles.set(userId, {
      completed: prev.completed || completed,
      familyName: familyName || prev.familyName,
      parentRole: parentRole || prev.parentRole,
      priorities: priorities ? priorities.split('|').filter(Boolean) : prev.priorities,
    });
    return res.json({ ok: true });
  }
});

// ─── UserProfile (Identitaet: uid -> Name) ─────────────────────────────────
const userProfiles = new Map(); // in-memory fallback: uid -> {displayName, username, searchable, isPrivate}

// Aufloesen des Anzeigenamens fuer eine UID (UserProfile bevorzugt).
async function resolveDisplayName(uid) {
  const id = (uid || '').toString().trim();
  if (!id) return '';
  try {
    await ensureSocialSchemaReady();
    const rows = await prisma.$queryRawUnsafe(
      `SELECT "displayName" FROM "UserProfile" WHERE "userId" = $1`, id
    );
    if (rows.length > 0 && rows[0].displayName) return rows[0].displayName;
  } catch (_) {
    const mem = userProfiles.get(id);
    if (mem && mem.displayName) return mem.displayName;
  }
  return '';
}

app.get('/api/profile/:userId', requireVerifiedUser, async (req, res) => {
  const userId = (req.params.userId || '').toString().trim();
  if (!userId) return res.status(400).json({ error: 'userId erforderlich' });
  try {
    await ensureSocialSchemaReady();
    const rows = await prisma.$queryRawUnsafe(
      `SELECT "displayName", "avatarUrl", "username", "searchable", "isPrivate" FROM "UserProfile" WHERE "userId" = $1`,
      userId
    );
    if (rows.length === 0) return res.json({ exists: false });
    const r = rows[0];
    return res.json({
      exists: true,
      displayName: r.displayName || '',
      avatarUrl: r.avatarUrl || null,
      username: r.username || null,
      searchable: r.searchable === true,
      isPrivate: r.isPrivate !== false,
    });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'GET /api/profile', error)) return;
    const mem = userProfiles.get(userId);
    if (!mem) return res.json({ exists: false });
    return res.json({ exists: true, ...mem });
  }
});

app.post('/api/profile', async (req, res) => {
  const userId = (req.body.userId || '').toString().trim();
  if (!userId) return res.status(400).json({ error: 'userId erforderlich' });
  if (!await authorizeProfileOwner(req, res, userId)) return;
  const displayName = (req.body.displayName || '').toString().trim().slice(0, 100);
  const hasAvatarUrl = Object.prototype.hasOwnProperty.call(req.body, 'avatarUrl');
  const avatarUrl = hasAvatarUrl
      ? (req.body.avatarUrl || '').toString().trim().slice(0, 500)
      : undefined;
  const hasUsername = Object.prototype.hasOwnProperty.call(req.body, 'username');
  const username = hasUsername
      ? (req.body.username || '').toString().trim().toLowerCase().slice(0, 30)
      : undefined;
  const hasSearchable = Object.prototype.hasOwnProperty.call(req.body, 'searchable');
  const searchable = req.body.searchable === true;
  const hasPrivate = Object.prototype.hasOwnProperty.call(req.body, 'isPrivate');
  const isPrivate = req.body.isPrivate !== false;
  try {
    await ensureSocialSchemaReady();
    // Upsert; leere Felder ueberschreiben bestehende Werte nicht.
    await prisma.$executeRawUnsafe(
      // WICHTIG: username als NULLIF(...,'') einfuegen, damit leere Usernames
      // NULL sind und NICHT vom partiellen Unique-Index erfasst werden
      // (sonst kollidieren mehrere Profile mit username='' -> Fehler).
      `INSERT INTO "UserProfile" ("userId", "displayName", "avatarUrl", "username", "searchable", "isPrivate", "updatedAt")
       VALUES ($1, $2, NULLIF($3, ''), NULLIF($4, ''), $5, $6, NOW())
       ON CONFLICT ("userId") DO UPDATE SET
         "displayName" = COALESCE(NULLIF($2, ''), "UserProfile"."displayName"),
         "avatarUrl" = ${hasAvatarUrl ? 'NULLIF($3, \'\')' : '"UserProfile"."avatarUrl"'},
         "username" = ${hasUsername ? 'NULLIF($4, \'\')' : '"UserProfile"."username"'},
         "searchable" = ${hasSearchable ? '$5' : '"UserProfile"."searchable"'},
         "isPrivate" = ${hasPrivate ? '$6' : '"UserProfile"."isPrivate"'},
         "updatedAt" = NOW()`,
      userId, displayName, avatarUrl ?? '', username ?? '', searchable, isPrivate
    );
    return res.json({ ok: true });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'POST /api/profile', error)) return;
    const prev = userProfiles.get(userId) || { displayName: '', avatarUrl: null, username: null, searchable: false, isPrivate: true };
    userProfiles.set(userId, {
      displayName: displayName || prev.displayName,
      avatarUrl: hasAvatarUrl ? (avatarUrl || null) : prev.avatarUrl,
      username: hasUsername ? (username || null) : prev.username,
      searchable: hasSearchable ? searchable : prev.searchable,
      isPrivate: hasPrivate ? isPrivate : prev.isPrivate,
    });
    return res.json({ ok: true });
  }
});

// ─── Freundschaft (UID-zu-UID, Anfrage/Annehmen) ───────────────────────────
const friendships = new Map(); // in-memory fallback: "low__high" -> {status, requestedBy}
const friendInvites = new Map(); // token -> uid

function pairKey(a, b) {
  return [a, b].sort();
}

// App-weiter Check: sind zwei UIDs bestaetigte Freunde?
async function areFriends(uidA, uidB, { strict = false } = {}) {
  const a = (uidA || '').toString().trim();
  const b = (uidB || '').toString().trim();
  if (!a || !b || a === b) return false;
  const [low, high] = pairKey(a, b);
  try {
    await ensureSocialSchemaReady();
    const rows = await prisma.$queryRawUnsafe(
      `SELECT 1 FROM "Friendship" WHERE "userLow" = $1 AND "userHigh" = $2 AND "status" = 'accepted' LIMIT 1`,
      low, high
    );
    return rows.length > 0;
  } catch (error) {
    if (strict) throw error;
    const f = friendships.get(`${low}__${high}`);
    return !!f && f.status === 'accepted';
  }
}

// Deterministische Chat-Raum-ID aus zwei UIDs (beide Seiten identisch).
function friendRoomId(uidA, uidB) {
  return pairKey(uidA, uidB).join('__');
}

// Aus einer roomId die Gegenseite (die UID, die NICHT selfUid ist) im NEUEN
// Format uidA__uidB herausloesen. Altes pp-Format -> null (hier nicht relevant).
function otherUidFromRoomId(roomId, selfUid) {
  const rid = (roomId || '').toString().trim();
  const me = (selfUid || '').toString().trim();
  if (!rid.includes('__')) return null;
  const parts = rid.split('__').filter(Boolean);
  return parts.find(p => p !== me) || null;
}

function directChatParticipant(roomId, uid) {
  if (typeof roomId !== 'string' || !roomId || roomId !== roomId.trim()) return null;
  const parts = roomId.split('__');
  if (parts.length !== 2 ||
      parts.some(part => !part || part !== part.trim()) ||
      parts[0] === parts[1] || friendRoomId(...parts) !== roomId ||
      !parts.includes(uid)) return null;
  return { roomId, otherUid: otherUidFromRoomId(roomId, uid) };
}

function requireActorClaims(req, res, claims) {
  if (claims.some(value => value !== undefined &&
      (typeof value !== 'string' || value.trim() !== req.firebaseUid))) {
    res.status(403).json({ error: 'Nur fuer das eigene Konto erlaubt', code: 'not_owner' });
    return false;
  }
  return true;
}

function respondChatPersistenceError(res, label, error) {
  console.error(`${label}:`, error?.message || error);
  return res.status(503).json({ error: 'Chat derzeit nicht verfuegbar', code: 'persistence_unavailable' });
}

async function authorizeChatParticipant(req, res, roomId) {
  if (typeof roomId !== 'string' || !roomId || roomId !== roomId.trim()) {
    res.status(403).json({ error: 'Unterhaltung nicht verfuegbar', code: 'not_participant' });
    return null;
  }
  if (roomId.startsWith('group_')) {
    const groupId = roomId.slice('group_'.length);
    if (!groupId || groupId !== groupId.trim()) {
      res.status(403).json({ error: 'Unterhaltung nicht verfuegbar', code: 'not_participant' });
      return null;
    }
    try {
      await ensureSocialSchemaReady();
      const members = await prisma.$queryRawUnsafe(
        `SELECT 1 FROM "ChatGroupMember" WHERE "groupId" = $1 AND "userId" = $2 LIMIT 1`,
        groupId, req.firebaseUid
      );
      if (!members.length) {
        res.status(403).json({ error: 'Du bist kein Mitglied dieser Gruppe', code: 'not_member' });
        return null;
      }
      return { roomId, groupId };
    } catch (error) {
      respondChatPersistenceError(res, 'Chat-Mitgliedschaft', error);
      return null;
    }
  }
  const participant = directChatParticipant(roomId, req.firebaseUid);
  if (!participant) {
    res.status(403).json({ error: 'Unterhaltung nicht verfuegbar', code: 'not_participant' });
    return null;
  }
  return participant;
}

// Hat einer der beiden den anderen blockiert (Richtung egal)? Fehlertolerant.
async function isBlockedBetween(uidA, uidB, { strict = false } = {}) {
  const a = (uidA || '').toString().trim();
  const b = (uidB || '').toString().trim();
  if (!a || !b) return false;
  try {
    await ensureSocialSchemaReady();
    const rows = await prisma.$queryRawUnsafe(
      `SELECT 1 FROM "SafetyBlock"
       WHERE ("blockerUserId" = $1 AND "blockedUserId" = $2)
          OR ("blockerUserId" = $2 AND "blockedUserId" = $1) LIMIT 1`,
      a, b
    );
    return rows.length > 0;
  } catch (error) {
    if (strict) throw error;
    const setA = safetyBlocks.get(a);
    const setB = safetyBlocks.get(b);
    return (!!setA && setA.has(b)) || (!!setB && setB.has(a));
  }
}

// Hat der ANDERE mich blockiert? (Einseitig: otherUid -> me.) Fuer den
// Lese-Zugriff: Wer blockiert wurde, verliert den Zugriff auf den Chat.
async function hasBlockedMe(otherUid, selfUid, { strict = false } = {}) {
  const other = (otherUid || '').toString().trim();
  const me = (selfUid || '').toString().trim();
  if (!other || !me) return false;
  try {
    await ensureSocialSchemaReady();
    const rows = await prisma.$queryRawUnsafe(
      `SELECT 1 FROM "SafetyBlock" WHERE "blockerUserId" = $1 AND "blockedUserId" = $2 LIMIT 1`,
      other, me
    );
    return rows.length > 0;
  } catch (error) {
    if (strict) throw error;
    const set = safetyBlocks.get(other);
    return !!set && set.has(me);
  }
}

// Freundschaftsanfrage senden (oder direkt bestaetigen, wenn Ziel nicht privat).
app.post('/api/friendships/request', requireVerifiedUser, async (req, res) => {
  if (!requireActorClaims(req, res, [req.body.fromUid])) return;
  const fromUid = req.firebaseUid;
  const toUid = (req.body.toUid || '').toString().trim();
  if (!fromUid || !toUid) return res.status(400).json({ error: 'fromUid und toUid erforderlich' });
  if (fromUid === toUid) return res.status(400).json({ error: 'Eigene UID nicht erlaubt' });
  const [low, high] = pairKey(fromUid, toUid);
  try {
    await ensureSocialSchemaReady();
    if (await isBlockedBetween(fromUid, toUid, { strict: true })) {
      return res.status(403).json({ error: 'Verbindung nicht verfuegbar', code: 'blocked' });
    }
    // Ist das Ziel-Profil oeffentlich (nicht privat)? Dann sofort 'accepted'.
    let targetPrivate = true;
    const p = await prisma.$queryRawUnsafe(
      `SELECT "isPrivate" FROM "UserProfile" WHERE "userId" = $1`, toUid
    );
    if (p.length > 0) targetPrivate = p[0].isPrivate !== false;
    const status = targetPrivate ? 'pending' : 'accepted';
    await prisma.$executeRawUnsafe(
      `INSERT INTO "Friendship" ("userLow", "userHigh", "status", "requestedBy", "createdAt", "updatedAt")
       VALUES ($1, $2, $3, $4, NOW(), NOW())
       ON CONFLICT ("userLow", "userHigh") DO UPDATE SET
         "status" = CASE WHEN "Friendship"."status" = 'accepted' THEN 'accepted' ELSE $3 END,
         "updatedAt" = NOW()`,
      low, high, status, fromUid
    );
    return res.json({ ok: true, status, roomId: friendRoomId(fromUid, toUid) });
  } catch (error) {
    return respondChatPersistenceError(res, 'POST /api/friendships/request', error);
  }
});

// Anfrage annehmen.
app.post('/api/friendships/accept', requireVerifiedUser, async (req, res) => {
  if (!requireActorClaims(req, res, [req.body.uid])) return;
  const uid = req.firebaseUid;
  const otherUid = (req.body.otherUid || '').toString().trim();
  if (!uid || !otherUid) return res.status(400).json({ error: 'uid und otherUid erforderlich' });
  if (uid === otherUid) return res.status(403).json({ error: 'Eigene UID nicht erlaubt' });
  const [low, high] = pairKey(uid, otherUid);
  try {
    await ensureSocialSchemaReady();
    if (await isBlockedBetween(uid, otherUid, { strict: true })) {
      return res.status(403).json({ error: 'Verbindung nicht verfuegbar', code: 'blocked' });
    }
    const accepted = await prisma.$executeRawUnsafe(
      `UPDATE "Friendship" SET "status" = 'accepted', "updatedAt" = NOW()
       WHERE "userLow" = $1 AND "userHigh" = $2
         AND "requestedBy" = $3 AND "status" IN ('pending', 'accepted')`,
      low, high, otherUid
    );
    if (accepted === 0) return res.status(403).json({ error: 'Keine eingehende Anfrage', code: 'not_recipient' });
    return res.json({ ok: true, roomId: friendRoomId(uid, otherUid) });
  } catch (error) {
    return respondChatPersistenceError(res, 'POST /api/friendships/accept', error);
  }
});

// Freundschaft/Anfrage entfernen (unfriend / ablehnen).
app.delete('/api/friendships', requireVerifiedUser, async (req, res) => {
  if (!requireActorClaims(req, res, [req.query.uid, req.body?.uid])) return;
  const uid = req.firebaseUid;
  const otherUid = (req.query.otherUid || req.body?.otherUid || '').toString().trim();
  if (!uid || !otherUid) return res.status(400).json({ error: 'uid und otherUid erforderlich' });
  const [low, high] = pairKey(uid, otherUid);
  try {
    await ensureSocialSchemaReady();
    await prisma.$executeRawUnsafe(
      `DELETE FROM "Friendship" WHERE "userLow" = $1 AND "userHigh" = $2`, low, high
    );
    return res.json({ ok: true });
  } catch (error) {
    return respondChatPersistenceError(res, 'DELETE /api/friendships', error);
  }
});

// Freundesliste + offene Anfragen (mit Namen) fuer eine UID.
app.get('/api/friendships/:uid', requireVerifiedUser, async (req, res) => {
  if (!requireActorClaims(req, res, [req.params.uid])) return;
  const uid = req.firebaseUid;
  if (!uid) return res.status(400).json({ error: 'uid erforderlich' });
  try {
    await ensureSocialSchemaReady();
    const rows = await prisma.$queryRawUnsafe(
      `SELECT f."userLow", f."userHigh", f."status", f."requestedBy",
              pl."displayName" AS "lowName", ph."displayName" AS "highName",
              pl."avatarUrl" AS "lowAvatarUrl", ph."avatarUrl" AS "highAvatarUrl"
       FROM "Friendship" f
       LEFT JOIN "UserProfile" pl ON pl."userId" = f."userLow"
       LEFT JOIN "UserProfile" ph ON ph."userId" = f."userHigh"
       WHERE f."userLow" = $1 OR f."userHigh" = $1`,
      uid
    );
    const friends = [];
    const incoming = []; // Anfragen an mich
    const outgoing = []; // von mir gesendete Anfragen
    for (const r of rows) {
      const otherUid = r.userLow === uid ? r.userHigh : r.userLow;
      const otherName =
          (r.userLow === uid ? r.highName : r.lowName) || 'Familie';
      const avatarUrl = r.userLow === uid ? r.highAvatarUrl : r.lowAvatarUrl;
      const entry = {
        uid: otherUid,
        name: otherName,
        avatarUrl: avatarUrl || null,
        roomId: friendRoomId(uid, otherUid),
      };
      if (r.status === 'accepted') friends.push(entry);
      else if (r.requestedBy === uid) outgoing.push(entry);
      else incoming.push(entry);
    }
    return res.json({ friends, incoming, outgoing });
  } catch (error) {
    return respondChatPersistenceError(res, 'GET /api/friendships', error);
  }
});

// Einladungs-Token erzeugen (fuer Link/QR).
app.post('/api/friendships/invite', requireVerifiedUser, async (req, res) => {
  const userId = req.firebaseUid;
  if (!userId) return res.status(400).json({ error: 'userId erforderlich' });
  const token = generateId('inv').replace(/[^a-zA-Z0-9]/g, '').slice(0, 16);
  try {
    await ensureSocialSchemaReady();
    await prisma.$executeRawUnsafe(
      `INSERT INTO "FriendInvite" ("token", "userId", "createdAt") VALUES ($1, $2, NOW())
       ON CONFLICT ("token") DO NOTHING`,
      token, userId
    );
    return res.json({ ok: true, token });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'POST /api/friendships/invite', error)) return;
    friendInvites.set(token, userId);
    return res.json({ ok: true, token });
  }
});

// Einladungs-Token aufloesen -> UID + Name des Einladenden.
app.get('/api/friendships/resolve-invite/:token', async (req, res) => {
  const token = (req.params.token || '').toString().trim();
  if (!token) return res.status(400).json({ error: 'token erforderlich' });
  try {
    await ensureSocialSchemaReady();
    const rows = await prisma.$queryRawUnsafe(
      `SELECT "userId" FROM "FriendInvite" WHERE "token" = $1`, token
    );
    if (rows.length === 0) return res.status(404).json({ error: 'Einladung ungueltig' });
    const uid = rows[0].userId;
    const name = await resolveDisplayName(uid);
    return res.json({ ok: true, uid, name });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'GET /api/friendships/resolve-invite', error)) return;
    const uid = friendInvites.get(token);
    if (!uid) return res.status(404).json({ error: 'Einladung ungueltig' });
    return res.json({ ok: true, uid, name: userProfiles.get(uid)?.displayName || '' });
  }
});

// ─── Phase 3a: Familien-Rezepte teilen ─────────────────────────────────────
const recipes = new Map();          // in-memory fallback: id -> recipe row
const recipeReactions = new Map();  // in-memory fallback: recipeId -> [{userId,type}]

// Erlaubte Sichtbarkeiten.
const RECIPE_VISIBILITIES = new Set(['public', 'friends', 'private']);

// Sicheres JSON-Parsen einer Text-Spalte (Zutaten/Schritte/Tags).
function parseJsonArray(raw) {
  try {
    const v = typeof raw === 'string' ? JSON.parse(raw) : raw;
    return Array.isArray(v) ? v.map(x => x.toString()) : [];
  } catch (_) {
    return [];
  }
}

// Baut die Client-Antwort fuer ein Rezept inkl. Reaktions-Zaehler und ob der
// anfragende Nutzer selbst reagiert hat.
async function buildRecipeForClient(row, requesterUid) {
  const id = row.id;
  let cook = 0;
  let tasty = 0;
  let myCook = false;
  let myTasty = false;
  try {
    const rows = await prisma.$queryRawUnsafe(
      `SELECT "userId", "type" FROM "RecipeReaction" WHERE "recipeId" = $1`, id
    );
    for (const r of rows) {
      if (r.type === 'cook') { cook++; if (r.userId === requesterUid) myCook = true; }
      else if (r.type === 'tasty') { tasty++; if (r.userId === requesterUid) myTasty = true; }
    }
  } catch (_) {
    const list = recipeReactions.get(id) || [];
    for (const r of list) {
      if (r.type === 'cook') { cook++; if (r.userId === requesterUid) myCook = true; }
      else if (r.type === 'tasty') { tasty++; if (r.userId === requesterUid) myTasty = true; }
    }
  }
  return {
    id,
    authorUserId: row.authorUserId,
    authorName: row.authorName || 'Familie',
    title: row.title || '',
    description: row.description || '',
    photoUrl: row.photoUrl || '',
    ingredients: parseJsonArray(row.ingredients),
    steps: parseJsonArray(row.steps),
    prepMinutes: Number(row.prepMinutes) || 0,
    visibility: row.visibility || 'friends',
    tags: parseJsonArray(row.tags),
    createdAt: row.createdAt,
    cookCount: cook,
    tastyCount: tasty,
    myCook,
    myTasty,
    isMine: row.authorUserId === requesterUid,
  };
}

// Rezept erstellen. Foto-URL kommt vom bereits vorhandenen /uploads/image.
app.post('/api/recipes', requireVerifiedUser, async (req, res) => {
  // Identitaet kommt ausschliesslich aus dem verifizierten Token.
  const authorUserId = req.firebaseUid;
  const claimedAuthor = (req.body.authorUserId || '').toString().trim();
  if (claimedAuthor && claimedAuthor !== authorUserId) {
    return res.status(403).json({ error: 'Nur fuer das eigene Konto erlaubt' });
  }
  const title = (req.body.title || '').toString().trim().slice(0, 120);
  if (!title) return res.status(400).json({ error: 'Titel erforderlich' });
  // Echter Bann: gesperrte Nutzer koennen keine Rezepte mehr teilen.
  if (await isUserSuspended(authorUserId)) return respondSuspended(res);

  const authorName = (req.body.authorName || 'Familie').toString().trim().slice(0, 100) || 'Familie';
  const description = (req.body.description || '').toString().trim().slice(0, 2000);
  const photoUrl = (req.body.photoUrl || '').toString().trim().slice(0, 500);
  const ingredients = Array.isArray(req.body.ingredients)
      ? req.body.ingredients.map(x => x.toString().trim()).filter(Boolean).slice(0, 60)
      : [];
  const steps = Array.isArray(req.body.steps)
      ? req.body.steps.map(x => x.toString().trim()).filter(Boolean).slice(0, 40)
      : [];
  const prepMinutes = Math.max(0, Math.min(600, parseInt(req.body.prepMinutes, 10) || 0));
  let visibility = (req.body.visibility || 'friends').toString().trim();
  if (!RECIPE_VISIBILITIES.has(visibility)) visibility = 'friends';
  const tags = Array.isArray(req.body.tags)
      ? req.body.tags.map(x => x.toString().trim()).filter(Boolean).slice(0, 12)
      : [];
  const id = generateId('rcp');
  const row = {
    id, authorUserId, authorName, title, description, photoUrl,
    ingredients: JSON.stringify(ingredients), steps: JSON.stringify(steps),
    prepMinutes, visibility, tags: JSON.stringify(tags),
    createdAt: new Date().toISOString(),
  };
  try {
    await ensureSocialSchemaReady();
    await prisma.$executeRawUnsafe(
      `INSERT INTO "Recipe" ("id","authorUserId","authorName","title","description","photoUrl","ingredients","steps","prepMinutes","visibility","tags","createdAt")
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,NOW())`,
      id, authorUserId, authorName, title, description, photoUrl,
      row.ingredients, row.steps, prepMinutes, visibility, row.tags
    );
    const out = await buildRecipeForClient(row, authorUserId);
    return res.status(201).json({ ok: true, recipe: out });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'POST /api/recipes', error)) return;
    recipes.set(id, row);
    const out = await buildRecipeForClient(row, authorUserId);
    return res.status(201).json({ ok: true, recipe: out });
  }
});

// Rezept-Liste fuer einen Nutzer: eigene + oeffentliche + von bestaetigten
// Freunden. Sichtbarkeit wird SERVERSEITIG durchgesetzt. Optional: Suche (q)
// ueber Titel/Beschreibung/Zutaten und Filter-Tags.
app.get('/api/recipes', requireVerifiedUser, async (req, res) => {
  // Identitaet aus verifiziertem Token; eine abweichende query.userId wird
  // bereits von requireVerifiedUser mit 403 abgelehnt. Der oeffentliche
  // Rezept-Feed laeuft ueber /api/food-feed/recipes und ist davon unberuehrt.
  const uid = req.firebaseUid;
  const q = (req.query.q || '').toString().trim().toLowerCase();
  try {
    await ensureSocialSchemaReady();
    const rows = await prisma.$queryRawUnsafe(
      `SELECT * FROM "Recipe" ORDER BY "createdAt" DESC LIMIT 500`
    );
    // Bestaetigte Freunde des Anfragenden ermitteln (fuer 'friends'-Sicht).
    let friendUids = new Set();
    if (uid) {
      try {
        const fr = await prisma.$queryRawUnsafe(
          `SELECT "userLow", "userHigh" FROM "Friendship"
           WHERE ("userLow" = $1 OR "userHigh" = $1) AND "status" = 'accepted'`,
          uid
        );
        for (const f of fr) {
          friendUids.add(f.userLow === uid ? f.userHigh : f.userLow);
        }
      } catch (_) {}
    }
    const visible = rows.filter(r => {
      if (r.authorUserId === uid) return true;              // eigene immer
      if (r.visibility === 'public') return true;           // fuer alle
      if (r.visibility === 'friends') return friendUids.has(r.authorUserId);
      return false;                                          // 'private': nie fremd
    });
    const matched = q
      ? visible.filter(r => {
          const hay = [
            r.title || '', r.description || '',
            parseJsonArray(r.ingredients).join(' '),
            parseJsonArray(r.tags).join(' '),
          ].join(' ').toLowerCase();
          return hay.includes(q);
        })
      : visible;
    const out = [];
    for (const r of matched) out.push(await buildRecipeForClient(r, uid));
    return res.json({ recipes: out });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'GET /api/recipes', error)) return;
    return res.json({ recipes: [] });
  }
});

// Einzelnes Rezept (mit Sichtbarkeitspruefung).
app.get('/api/recipes/:id', requireVerifiedUser, async (req, res) => {
  const id = (req.params.id || '').toString().trim();
  const uid = req.firebaseUid;
  if (!id) return res.status(400).json({ error: 'id erforderlich' });
  try {
    await ensureSocialSchemaReady();
    const rows = await prisma.$queryRawUnsafe(
      `SELECT * FROM "Recipe" WHERE "id" = $1`, id
    );
    if (rows.length === 0) return res.status(404).json({ error: 'Rezept nicht gefunden' });
    const r = rows[0];
    let allowed = r.authorUserId === uid || r.visibility === 'public';
    if (!allowed && r.visibility === 'friends' && uid) {
      allowed = await areFriends(uid, r.authorUserId);
    }
    if (!allowed) return res.status(403).json({ error: 'Kein Zugriff', code: 'not_visible' });
    return res.json({ recipe: await buildRecipeForClient(r, uid) });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'GET /api/recipes/:id', error)) return;
    return res.status(404).json({ error: 'Rezept nicht gefunden' });
  }
});

// Rezept loeschen (nur der Autor).
app.delete('/api/recipes/:id', requireVerifiedUser, async (req, res) => {
  const id = (req.params.id || '').toString().trim();
  const uid = req.firebaseUid;
  if (!id) return res.status(400).json({ error: 'id erforderlich' });
  try {
    await ensureSocialSchemaReady();
    const rows = await prisma.$queryRawUnsafe(
      `SELECT "authorUserId" FROM "Recipe" WHERE "id" = $1`, id
    );
    if (rows.length === 0) return res.json({ ok: true }); // schon weg
    if (rows[0].authorUserId !== uid) {
      return res.status(403).json({ error: 'Nur der Autor darf loeschen' });
    }
    await prisma.$executeRawUnsafe(`DELETE FROM "RecipeReaction" WHERE "recipeId" = $1`, id);
    await prisma.$executeRawUnsafe(`DELETE FROM "Recipe" WHERE "id" = $1`, id);
    return res.json({ ok: true });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'DELETE /api/recipes/:id', error)) return;
    recipes.delete(id);
    recipeReactions.delete(id);
    return res.json({ ok: true });
  }
});

// Reaktion toggeln: 'cook' ("Das kochen wir nach!") oder 'tasty'
// ("Hat geschmeckt!"). Nur erlaubt, wenn das Rezept fuer den Nutzer sichtbar
// ist. Gesperrte Nutzer koennen nicht reagieren.
app.post('/api/recipes/:id/react', requireVerifiedUser, async (req, res) => {
  const id = (req.params.id || '').toString().trim();
  const uid = req.firebaseUid;
  const type = (req.body.type || '').toString().trim();
  if (!id) return res.status(400).json({ error: 'id erforderlich' });
  if (type !== 'cook' && type !== 'tasty') {
    return res.status(400).json({ error: 'type muss cook oder tasty sein' });
  }
  if (await isUserSuspended(uid)) return respondSuspended(res);
  try {
    await ensureSocialSchemaReady();
    const rows = await prisma.$queryRawUnsafe(
      `SELECT * FROM "Recipe" WHERE "id" = $1`, id
    );
    if (rows.length === 0) return res.status(404).json({ error: 'Rezept nicht gefunden' });
    const r = rows[0];
    let allowed = r.authorUserId === uid || r.visibility === 'public';
    if (!allowed && r.visibility === 'friends' && uid) {
      allowed = await areFriends(uid, r.authorUserId);
    }
    if (!allowed) return res.status(403).json({ error: 'Kein Zugriff', code: 'not_visible' });
    // Toggle: existiert die Reaktion, entfernen; sonst anlegen.
    const existing = await prisma.$queryRawUnsafe(
      `SELECT 1 FROM "RecipeReaction" WHERE "recipeId" = $1 AND "userId" = $2 AND "type" = $3 LIMIT 1`,
      id, uid, type
    );
    if (existing.length > 0) {
      await prisma.$executeRawUnsafe(
        `DELETE FROM "RecipeReaction" WHERE "recipeId" = $1 AND "userId" = $2 AND "type" = $3`,
        id, uid, type
      );
    } else {
      await prisma.$executeRawUnsafe(
        `INSERT INTO "RecipeReaction" ("recipeId","userId","type","createdAt") VALUES ($1,$2,$3,NOW())
         ON CONFLICT ("recipeId","userId","type") DO NOTHING`,
        id, uid, type
      );
    }
    return res.json({ ok: true, recipe: await buildRecipeForClient(r, uid) });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'POST /api/recipes/:id/react', error)) return;
    return res.json({ ok: true });
  }
});

// ─── DSGVO: Konto-Loeschung (Recht auf Loeschung, Art. 17) ─────────────────
// Entfernt ALLE personenbezogenen Zeilen zu einem Nutzer (per userId UND per
// zugehoerigem Freundes-Code). Token-exempt (/api/onboarding-Muster: userId
// identifiziert), aber der Client ruft es mit Firebase-Token auf.
app.delete('/api/account/:userId', async (req, res) => {
  const userId = (req.params.userId || '').toString().trim();
  if (!userId) return res.status(400).json({ error: 'userId erforderlich' });
  if (!(await authorizeAccountOwner(req, res, userId))) return;
  const deleted = {};
  try {
    await ensureSocialSchemaReady();
    // Zugehoerige Freundes-Codes dieses Nutzers ermitteln (fuer code-basierte Tabellen).
    let codes = [];
    try {
      const rows = await prisma.$queryRawUnsafe(
        `SELECT "code" FROM "FriendRegistry" WHERE "userId" = $1`, userId
      );
      codes = rows.map(r => r.code).filter(Boolean);
    } catch (_) {}
    const idList = [userId, ...codes];

    const run = async (label, sql, ...params) => {
      try {
        const r = await prisma.$executeRawUnsafe(sql, ...params);
        deleted[label] = typeof r === 'number' ? r : 1;
      } catch (e) {
        deleted[label] = `error: ${e?.message || e}`;
      }
    };

    // Onboarding + Profil
    await run('onboarding', `DELETE FROM "OnboardingProfile" WHERE "userId" = $1`, userId);
    await run('userProfile', `DELETE FROM "UserProfile" WHERE "userId" = $1`, userId);
    // UID-Freundschaften + Einladungen
    await run('friendships', `DELETE FROM "Friendship" WHERE "userLow" = $1 OR "userHigh" = $1`, userId);
    await run('friendInvites', `DELETE FROM "FriendInvite" WHERE "userId" = $1`, userId);
    // Familien-Rezepte + Reaktionen dieses Nutzers
    await run('recipeReactionsByUser', `DELETE FROM "RecipeReaction" WHERE "userId" = $1`, userId);
    await run('recipeReactionsOnOwn', `DELETE FROM "RecipeReaction" WHERE "recipeId" IN (SELECT "id" FROM "Recipe" WHERE "authorUserId" = $1)`, userId);
    // DSGVO: Foto-URLs der eigenen Rezepte VOR dem Loeschen einsammeln, damit
    // wir die Bilddateien anschliessend physisch entfernen koennen. Die
    // Tabelle "Recipe" (Phase 3a) wird vom Prisma-Loeschpfad nicht erfasst.
    let recipePhotoUrls = [];
    try {
      const rows = await prisma.$queryRawUnsafe(
        `SELECT "photoUrl" FROM "Recipe" WHERE "authorUserId" = $1 AND "photoUrl" <> ''`,
        userId
      );
      recipePhotoUrls = rows.map(r => r.photoUrl).filter(Boolean);
    } catch (_) {}
    await run('recipes', `DELETE FROM "Recipe" WHERE "authorUserId" = $1`, userId);
    // UID-basierte Chat-Raeume (roomId enthaelt die UID)
    await run('chatRoomsUid', `DELETE FROM "FriendChatMessage" WHERE "roomId" LIKE $1`, `%${userId}%`);
    // Freundschafts-Registry + Kanten (per userId-Code)
    await run('friendEdges', `DELETE FROM "FriendEdge" WHERE "ownerCode" = ANY($1::text[]) OR "friendCode" = ANY($1::text[])`, idList);
    await run('friendRegistry', `DELETE FROM "FriendRegistry" WHERE "userId" = $1 OR "code" = ANY($2::text[])`, userId, idList);
    await run('pendingConnections', `DELETE FROM "FriendPendingConnection" WHERE "toCode" = ANY($1::text[]) OR "fromCode" = ANY($1::text[])`, idList);
    // Chat-Nachrichten dieses Autors + Raeume, die seinen Code enthalten
    await run('chatByAuthor', `DELETE FROM "FriendChatMessage" WHERE "authorUserId" = $1`, userId);
    for (const c of codes) {
      await run(`chatRoom_${c}`, `DELETE FROM "FriendChatMessage" WHERE "roomId" LIKE $1`, `%${c}%`);
    }
    // Safety
    await run('safetyBlocksBy', `DELETE FROM "SafetyBlock" WHERE "blockerUserId" = ANY($1::text[]) OR "blockedUserId" = ANY($1::text[])`, idList);
    await run('safetyReports', `DELETE FROM "SafetyReport" WHERE "reporterUserId" = ANY($1::text[]) OR "reportedUserId" = ANY($1::text[])`, idList);
    await run('safetySuspension', `DELETE FROM "SafetySuspension" WHERE "userId" = ANY($1::text[])`, idList);

    // In-Memory-Fallbacks ebenfalls saeubern (best-effort).
    onboardingProfiles.delete(userId);
    userProfiles.delete(userId);
    friendInvites.forEach((v, k) => { if (v === userId) friendInvites.delete(k); });
    friendships.forEach((v, k) => { if (k.includes(userId)) friendships.delete(k); });
    for (const id of idList) {
      friendRegistry.delete(id);
      friendEdges.delete(id);
      friendPendingConnections.delete(id);
      safetyBlocks.delete(id);
      safetySuspensions.delete(id);
      invalidateSuspensionCache(id);
    }

    // DSGVO: Rezept-Bilddateien physisch entfernen (referenz-sicher — loescht
    // nur, wenn kein anderer Datensatz das Bild noch nutzt). Fehler hier sind
    // unkritisch fuer die Konto-Loeschung (best effort), werden aber gemeldet.
    if (recipePhotoUrls.length > 0) {
      try {
        const media = await deleteUnreferencedAccountMedia(recipePhotoUrls, userId);
        deleted.recipeMedia = media;
      } catch (e) {
        deleted.recipeMedia = `error: ${e?.message || e}`;
      }
    }

    return res.json({ ok: true, userId, codes, deleted });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'DELETE /api/account', error)) return;
    return res.status(500).json({ error: 'Konto-Loeschung fehlgeschlagen' });
  }
});

// ─── Safety (Prio 4): server-side block + report ───────────────────────────
app.post('/api/safety/block', requireVerifiedUser, async (req, res) => {
  if (!requireActorClaims(req, res, [req.body.blockerUserId])) return;
  const blockerUserId = req.firebaseUid;
  const blockedUserId = (req.body.blockedUserId || '').toString().trim();
  const blockedName = (req.body.blockedName || '').toString().trim().slice(0, 100);
  if (!blockerUserId || !blockedUserId) {
    return res.status(400).json({ error: 'blockerUserId und blockedUserId erforderlich' });
  }
  try {
    await ensureSocialSchemaReady();
    await prisma.$executeRawUnsafe(
      `INSERT INTO "SafetyBlock" ("blockerUserId", "blockedUserId", "blockedName", "createdAt")
       VALUES ($1, $2, $3, NOW())
       ON CONFLICT ("blockerUserId", "blockedUserId") DO UPDATE SET "blockedName" = $3`,
      blockerUserId, blockedUserId, blockedName
    );
    return res.json({ ok: true });
  } catch (error) {
    return respondChatPersistenceError(res, 'POST /api/safety/block', error);
  }
});

app.post('/api/safety/unblock', requireVerifiedUser, async (req, res) => {
  if (!requireActorClaims(req, res, [req.body.blockerUserId])) return;
  const blockerUserId = req.firebaseUid;
  const blockedUserId = (req.body.blockedUserId || '').toString().trim();
  if (!blockerUserId || !blockedUserId) {
    return res.status(400).json({ error: 'blockerUserId und blockedUserId erforderlich' });
  }
  try {
    await ensureSocialSchemaReady();
    await prisma.$executeRawUnsafe(
      `DELETE FROM "SafetyBlock" WHERE "blockerUserId" = $1 AND "blockedUserId" = $2`,
      blockerUserId, blockedUserId
    );
    return res.json({ ok: true });
  } catch (error) {
    return respondChatPersistenceError(res, 'POST /api/safety/unblock', error);
  }
});

app.get('/api/safety/blocks/:userId', requireVerifiedUser, async (req, res) => {
  if (!requireActorClaims(req, res, [req.params.userId])) return;
  const userId = req.firebaseUid;
  if (!userId) return res.status(400).json({ error: 'userId erforderlich' });
  try {
    await ensureSocialSchemaReady();
    const rows = await prisma.$queryRawUnsafe(
      `SELECT "blockedUserId", "blockedName", "createdAt" FROM "SafetyBlock" WHERE "blockerUserId" = $1`,
      userId
    );
    return res.json({ blocks: rows });
  } catch (error) {
    return respondChatPersistenceError(res, 'GET /api/safety/blocks', error);
  }
});

app.post('/api/safety/report', requireVerifiedUser, async (req, res) => {
  const reporterUserId = req.firebaseUid;
  const claimedReporter = (req.body.reporterUserId || '').toString().trim();
  if (claimedReporter && claimedReporter !== reporterUserId) {
    return res.status(403).json({ error: 'Nur fuer das eigene Konto erlaubt' });
  }
  const reportedUserId = (req.body.reportedUserId || '').toString().trim();
  const contentType = (req.body.contentType || 'profile').toString().trim().slice(0, 30);
  const content = (req.body.content || '').toString().trim().slice(0, 1000);
  const reason = (req.body.reason || 'other').toString().trim().slice(0, 50);
  if (!reportedUserId) {
    return res.status(400).json({ error: 'reportedUserId erforderlich' });
  }
  const id = generateId('rep');
  try {
    await ensureSocialSchemaReady();
    await prisma.$executeRawUnsafe(
      `INSERT INTO "SafetyReport" ("id", "reporterUserId", "reportedUserId", "contentType", "content", "reason", "status", "createdAt")
       VALUES ($1, $2, $3, $4, $5, $6, 'pending', NOW())`,
      id, reporterUserId || 'anonymous', reportedUserId, contentType, content, reason
    );
    const countRows = await prisma.$queryRawUnsafe(
      `SELECT COUNT(*)::int AS n FROM "SafetyReport" WHERE "reportedUserId" = $1`,
      reportedUserId
    );
    const reportCount = countRows?.[0]?.n ?? 1;
    return res.json({ ok: true, id, reportCount });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'POST /api/safety/report', error)) return;
    safetyReports.push({ id, reporterUserId, reportedUserId, contentType, content, reason, createdAt: new Date().toISOString() });
    const reportCount = safetyReports.filter(r => r.reportedUserId === reportedUserId).length;
    return res.json({ ok: true, id, reportCount });
  }
});

// ─── Moderations-Dashboard (Admin) ─────────────────────────────────────────
// Zugriff nur fuer Firebase-UIDs aus ADMIN_USER_IDS (Render-Env). Der
// Backend-API-Token wird als Fallback fuer serverseitige Tools akzeptiert.
async function requireAdmin(req, res, next) {
  // Fallback: statischer Server-Token (nur fuer serverseitige Tools).
  const authHeader = req.headers.authorization || '';
  if (backendApiToken && authHeader === `Bearer ${backendApiToken}`) {
    return next();
  }
  // Regulaer: Firebase-ID-Token pruefen und UID gegen die Admin-Liste.
  const { uid, verified } = await verifyFirebaseIdToken(req);
  if (!verified || !uid) {
    return res.status(401).json({ error: 'Anmeldung erforderlich' });
  }
  if (adminUserIds.size === 0 || !adminUserIds.has(uid)) {
    return res.status(403).json({ error: 'Kein Admin-Zugriff' });
  }
  req.firebaseUid = uid;
  return next();
}

// Liste aller Meldungen, gruppiert pro gemeldetem User.
app.get('/admin/reports', requireAdmin, async (req, res) => {
  const status = (req.query.status || 'pending').toString().trim();
  try {
    await ensureSocialSchemaReady();
    const where = status === 'all' ? '' : `WHERE r."status" = '${status.replace(/'/g, '')}'`;
    const rows = await prisma.$queryRawUnsafe(
      `SELECT r."reportedUserId",
              COUNT(*)::int AS "reportCount",
              MAX(r."createdAt") AS "lastReportedAt",
              (ARRAY_AGG(r."reason" ORDER BY r."createdAt" DESC))[1] AS "lastReason",
              BOOL_OR(s."userId" IS NOT NULL) AS "suspended",
              MAX(reg."name") AS "displayName"
       FROM "SafetyReport" r
       LEFT JOIN "SafetySuspension" s ON s."userId" = r."reportedUserId"
       LEFT JOIN "FriendRegistry" reg ON reg."code" = r."reportedUserId" OR reg."userId" = r."reportedUserId"
       ${where}
       GROUP BY r."reportedUserId"
       ORDER BY "lastReportedAt" DESC
       LIMIT 200`
    );
    // Detail-Meldungen mitliefern (kompakt), damit das Dashboard sie zeigen kann.
    const detailRows = await prisma.$queryRawUnsafe(
      `SELECT "id", "reportedUserId", "reporterUserId", "contentType", "content", "reason", "status", "createdAt"
       FROM "SafetyReport"
       ${status === 'all' ? '' : `WHERE "status" = '${status.replace(/'/g, '')}'`}
       ORDER BY "createdAt" DESC
       LIMIT 500`
    );
    return res.json({ groups: rows, reports: detailRows });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'GET /admin/reports', error)) return;
    // In-memory Fallback
    const byUser = new Map();
    for (const r of safetyReports) {
      if (status !== 'all' && (r.status || 'pending') !== status) continue;
      const g = byUser.get(r.reportedUserId) || { reportedUserId: r.reportedUserId, reportCount: 0, lastReportedAt: r.createdAt, lastReason: r.reason, suspended: safetySuspensions.has(r.reportedUserId) };
      g.reportCount += 1;
      if (r.createdAt > g.lastReportedAt) { g.lastReportedAt = r.createdAt; g.lastReason = r.reason; }
      byUser.set(r.reportedUserId, g);
    }
    return res.json({ groups: [...byUser.values()], reports: safetyReports.slice(-500).reverse() });
  }
});

// Meldung(en) als geprueft/ignoriert markieren. Ohne :id -> alle eines Users.
app.post('/admin/reports/resolve', requireAdmin, async (req, res) => {
  const reportId = (req.body.reportId || '').toString().trim();
  const reportedUserId = (req.body.reportedUserId || '').toString().trim();
  if (!reportId && !reportedUserId) {
    return res.status(400).json({ error: 'reportId oder reportedUserId erforderlich' });
  }
  try {
    await ensureSocialSchemaReady();
    if (reportId) {
      await prisma.$executeRawUnsafe(
        `UPDATE "SafetyReport" SET "status" = 'resolved' WHERE "id" = $1`, reportId
      );
    } else {
      await prisma.$executeRawUnsafe(
        `UPDATE "SafetyReport" SET "status" = 'resolved' WHERE "reportedUserId" = $1`, reportedUserId
      );
    }
    return res.json({ ok: true });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'POST /admin/reports/resolve', error)) return;
    for (const r of safetyReports) {
      if ((reportId && r.id === reportId) || (reportedUserId && r.reportedUserId === reportedUserId)) {
        r.status = 'resolved';
      }
    }
    return res.json({ ok: true });
  }
});

// Account sperren (Soft-Suspend, umkehrbar).
app.post('/admin/users/:userId/suspend', requireAdmin, async (req, res) => {
  const userId = (req.params.userId || '').toString().trim();
  const reason = (req.body.reason || '').toString().trim().slice(0, 300);
  if (!userId) return res.status(400).json({ error: 'userId erforderlich' });
  // Beide Identitaeten (UID + Code) sperren, damit der Bann ueberall greift.
  const identities = await expandIdentities(userId);
  try {
    await ensureSocialSchemaReady();
    for (const ident of identities) {
      await prisma.$executeRawUnsafe(
        `INSERT INTO "SafetySuspension" ("userId", "reason", "suspendedBy", "createdAt")
         VALUES ($1, $2, $3, NOW())
         ON CONFLICT ("userId") DO UPDATE SET "reason" = $2, "suspendedBy" = $3`,
        ident, reason, req.firebaseUid || 'admin'
      );
      invalidateSuspensionCache(ident);
    }
    return res.json({ ok: true, suspended: true, identities });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'POST /admin/users/suspend', error)) return;
    for (const ident of identities) {
      safetySuspensions.set(ident, { reason, suspendedBy: req.firebaseUid || 'admin', createdAt: new Date().toISOString() });
      invalidateSuspensionCache(ident);
    }
    return res.json({ ok: true, suspended: true, identities });
  }
});

// Account entsperren.
app.post('/admin/users/:userId/unsuspend', requireAdmin, async (req, res) => {
  const userId = (req.params.userId || '').toString().trim();
  if (!userId) return res.status(400).json({ error: 'userId erforderlich' });
  const identities = await expandIdentities(userId);
  try {
    await ensureSocialSchemaReady();
    await prisma.$executeRawUnsafe(
      `DELETE FROM "SafetySuspension" WHERE "userId" = ANY($1::text[])`, identities
    );
    for (const ident of identities) invalidateSuspensionCache(ident);
    return res.json({ ok: true, suspended: false });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'POST /admin/users/unsuspend', error)) return;
    for (const ident of identities) { safetySuspensions.delete(ident); invalidateSuspensionCache(ident); }
    return res.json({ ok: true, suspended: false });
  }
});

// ─── Admin: Cleanup kaputter Freundschafts-Kanten (Altlasten) ──────────────
// Eine Kante gilt als kaputt, wenn ein Code nicht kanonisch ist
// (z.B. 'pprkfns8' statt 'pp-rkfns8') ODER auf einen Code ohne Registry-
// Eintrag zeigt (Phantom-Code, den es als Nutzer nie gab).
async function findBrokenFriendEdges() {
  await ensureSocialSchemaReady();
  const edges = await prisma.$queryRawUnsafe(
    `SELECT "ownerCode", "friendCode", "friendName" FROM "FriendEdge"`
  );
  const regRows = await prisma.$queryRawUnsafe(
    `SELECT "code" FROM "FriendRegistry"`
  );
  const known = new Set(regRows.map(r => r.code));
  const broken = [];
  for (const e of edges) {
    const ownerBad = e.ownerCode !== canonicalCode(e.ownerCode);
    const friendBad = e.friendCode !== canonicalCode(e.friendCode);
    // Ein Code ist "Phantom", wenn er kanonisch ist, aber keine Registry hat.
    const ownerPhantom = !ownerBad && !known.has(e.ownerCode);
    const friendPhantom = !friendBad && !known.has(e.friendCode);
    if (ownerBad || friendBad || ownerPhantom || friendPhantom) {
      broken.push({
        ownerCode: e.ownerCode,
        friendCode: e.friendCode,
        friendName: e.friendName,
        reasons: [
          ownerBad ? 'ownerCode nicht kanonisch' : null,
          friendBad ? 'friendCode nicht kanonisch' : null,
          ownerPhantom ? 'ownerCode ohne Registry (Phantom)' : null,
          friendPhantom ? 'friendCode ohne Registry (Phantom)' : null,
        ].filter(Boolean),
      });
    }
  }
  return { totalEdges: edges.length, broken };
}

// Ein Identifikator ist eine roomId (nie eine gueltige Nutzer-Identitaet):
// - NEUES Format: enthaelt '__' (uidA__uidB)
// - ALTES Format: mehr als ein 'pp-' (pp-13za66-pp-rkfns8)
function looksLikeRoomId(id) {
  const s = (id || '').toString();
  if (s.includes('__')) return true;
  const matches = s.toLowerCase().match(/pp-/g);
  return matches != null && matches.length >= 2;
}

// Findet Registry-Fehlmappings: mehrere Codes, die auf dieselbe userId zeigen.
// Behalten wird der zuletzt aktualisierte Code; die aelteren werden entkoppelt.
async function findBrokenRegistryMappings() {
  await ensureSocialSchemaReady();
  const rows = await prisma.$queryRawUnsafe(
    `SELECT "code", "userId", "updatedAt" FROM "FriendRegistry"
     WHERE "userId" IS NOT NULL AND "userId" <> '' ORDER BY "updatedAt" DESC`
  );
  const seen = new Set();
  const staleCodes = []; // aeltere Codes, die dieselbe UID doppeln
  for (const r of rows) {
    if (seen.has(r.userId)) {
      staleCodes.push(r.code); // aelter (weil nach DESC-Sortierung spaeter)
    } else {
      seen.add(r.userId);
    }
  }
  return staleCodes;
}

// Findet verwaiste Safety-Eintraege (Suspension/Report), deren id eine roomId
// ist — diese entstanden durch den frueheren Melden/Sperren-Bug.
async function findBrokenSafetyEntries() {
  await ensureSocialSchemaReady();
  const suspensions = await prisma.$queryRawUnsafe(
    `SELECT "userId" FROM "SafetySuspension"`
  );
  const reports = await prisma.$queryRawUnsafe(
    `SELECT "id", "reportedUserId" FROM "SafetyReport"`
  );
  const badSuspensions = suspensions
    .filter(s => looksLikeRoomId(s.userId))
    .map(s => s.userId);
  const badReports = reports
    .filter(r => looksLikeRoomId(r.reportedUserId))
    .map(r => r.id);
  return { badSuspensions, badReports };
}

// Vorschau (Dry-Run): zeigt, WAS geloescht wuerde. Loescht nichts.
app.get('/admin/friends/cleanup-preview', requireAdmin, async (req, res) => {
  try {
    const { totalEdges, broken } = await findBrokenFriendEdges();
    const { badSuspensions, badReports } = await findBrokenSafetyEntries();
    const staleRegistryCodes = await findBrokenRegistryMappings();
    return res.json({
      totalEdges,
      brokenCount:
          broken.length + badSuspensions.length + badReports.length +
          staleRegistryCodes.length,
      broken,
      badSuspensions,
      badReports,
      staleRegistryCodes,
      note: 'Nur Vorschau. Zum Loeschen: POST /admin/friends/cleanup mit {"confirm":true}.',
    });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'GET /admin/friends/cleanup-preview', error)) return;
    return res.status(500).json({ error: 'Cleanup-Vorschau fehlgeschlagen' });
  }
});

// Loeschen — nur mit explizitem confirm:true. Ohne confirm -> Vorschau.
app.post('/admin/friends/cleanup', requireAdmin, async (req, res) => {
  const confirm = req.body && req.body.confirm === true;
  try {
    const { totalEdges, broken } = await findBrokenFriendEdges();
    const { badSuspensions, badReports } = await findBrokenSafetyEntries();
    const staleRegistryCodes = await findBrokenRegistryMappings();
    const totalBroken = broken.length + badSuspensions.length +
        badReports.length + staleRegistryCodes.length;
    if (!confirm) {
      return res.json({
        dryRun: true,
        totalEdges,
        brokenCount: totalBroken,
        broken,
        badSuspensions,
        badReports,
        staleRegistryCodes,
        note: 'Kein confirm:true -> nichts geloescht. Sende {"confirm":true} zum Loeschen.',
      });
    }
    let deleted = 0;
    for (const e of broken) {
      await prisma.$executeRawUnsafe(
        `DELETE FROM "FriendEdge" WHERE "ownerCode" = $1 AND "friendCode" = $2`,
        e.ownerCode, e.friendCode
      );
      deleted += 1;
    }
    // Verwaiste roomId-Sperren + -Meldungen entfernen (frueherer Bug).
    for (const uid of badSuspensions) {
      await prisma.$executeRawUnsafe(
        `DELETE FROM "SafetySuspension" WHERE "userId" = $1`, uid
      );
      invalidateSuspensionCache(uid);
      deleted += 1;
    }
    for (const rid of badReports) {
      await prisma.$executeRawUnsafe(
        `DELETE FROM "SafetyReport" WHERE "id" = $1`, rid
      );
      deleted += 1;
    }
    // Fehlgemappte Alt-Codes entkoppeln (userId -> NULL), damit eine UID nur
    // noch zu ihrem aktuellen Code gehoert. Registry-Zeile bleibt erhalten.
    for (const staleCode of staleRegistryCodes) {
      await prisma.$executeRawUnsafe(
        `UPDATE "FriendRegistry" SET "userId" = NULL WHERE "code" = $1`, staleCode
      );
      deleted += 1;
    }
    return res.json({ ok: true, deleted, scanned: totalEdges });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'POST /admin/friends/cleanup', error)) return;
    return res.status(500).json({ error: 'Cleanup fehlgeschlagen' });
  }
});

app.get('/friend-chat/messages', requireVerifiedUser, async (req, res) => {
  const roomId = req.query.roomId;
  const participant = await authorizeChatParticipant(req, res, roomId);
  if (!participant) return;
  // Block-Schutz beim LESEN: Wer vom anderen blockiert wurde, verliert den
  // Zugriff auf den Chat komplett. 'Entfernen' (unfriend) sperrt NICHT das
  // Lesen -> Verlauf bleibt Nur-Lese-Archiv. Nur ein echter Block sperrt.
  const requesterUid = req.firebaseUid;
  try {
    if (participant.otherUid &&
        await hasBlockedMe(participant.otherUid, requesterUid, { strict: true })) {
      return res.status(403).json({
        error: 'Diese Unterhaltung ist nicht mehr verfügbar.',
        code: 'blocked',
      });
    }
    await ensureSocialSchemaReady();
    // "Für mich löschen": Nachrichten vor dem clearedAt dieses Nutzers
    // ausblenden (der Verlauf des anderen bleibt unberührt).
    let clearedAt = null;
    if (requesterUid) {
      const clearedRows = await prisma.$queryRawUnsafe(
        `SELECT "clearedAt" FROM "ChatCleared" WHERE "roomId" = $1 AND "userId" = $2 LIMIT 1`,
        roomId, requesterUid
      );
      clearedAt = clearedRows[0] ? clearedRows[0].clearedAt : null;
    }
    const messages = await prisma.$queryRawUnsafe(
      `SELECT "id", "roomId", "authorUserId", "authorName", "content", "createdAt"
       FROM "FriendChatMessage"
       WHERE "roomId" = $1 AND ("createdAt" > $2 OR $2 IS NULL)
       ORDER BY "createdAt" ASC`,
      roomId, clearedAt
    );
    return res.json({ messages });
  } catch (error) {
    return respondChatPersistenceError(res, 'GET /friend-chat/messages', error);
  }
});

app.post('/friend-chat/messages', requireVerifiedUser, async (req, res) => {
  const roomId = req.body.roomId;
  const participant = await authorizeChatParticipant(req, res, roomId);
  if (!participant) return;
  const userId = req.firebaseUid;
  const userName = (req.body.userName || 'Elternteil').toString().trim();
  const content  = (req.body.content  || '').toString().trim();
  if (!roomId || !userId || !content) {
    return res.status(400).json({ error: 'roomId, userId und content erforderlich' });
  }
  try {
    if (await isUserSuspended(userId, { strict: true })) return respondSuspended(res);
    const otherUid = participant.otherUid;
    if (otherUid && await isBlockedBetween(userId, otherUid, { strict: true })) {
      return res.status(403).json({
        error: 'Diese Unterhaltung ist nicht mehr verfügbar.',
        code: 'blocked',
      });
    }
    if (otherUid && !(await areFriends(userId, otherUid, { strict: true }))) {
      return res.status(403).json({
        error: 'Ihr seid aktuell nicht mehr verbunden. Frühere Nachrichten '
          + 'kannst du weiter nachlesen.',
        code: 'not_friends',
      });
    }
  } catch (error) {
    return respondChatPersistenceError(res, 'Chat-Schreibberechtigung', error);
  }

  const item = { id: generateId('fc'), roomId, authorUserId: userId, authorName: userName, content, createdAt: new Date().toISOString() };

  // Empfaenger stammt aus der zuvor verifizierten Teilnahme.
  const pushToRecipient = async () => {
    try {
      let recipientUid = null;
      if (roomId.startsWith('group_')) {
        // Gruppen-Push: Benachrichtigung an ALLE Mitglieder außer dem Sender.
        // Parallel per allSettled, damit ein langsamer/fehlerhafter Empfaenger
        // die Zustellung an die anderen nicht blockiert (zuverlaessig + schnell).
        const groupId = roomId.substring('group_'.length);
        const [members, groupRows] = await Promise.all([
          prisma.$queryRawUnsafe(
            `SELECT "userId" FROM "ChatGroupMember" WHERE "groupId" = $1 AND "userId" <> $2`,
            groupId, userId
          ),
          prisma.$queryRawUnsafe(
            `SELECT "name" FROM "ChatGroup" WHERE "id" = $1 LIMIT 1`,
            groupId
          ),
        ]);
        const groupName = (groupRows[0] && groupRows[0].name) || 'Gruppe';
        // Im Gruppen-Push den Gruppennamen + Absender zeigen ("Gruppe · Name").
        const title = `${groupName} · ${userName || 'Neue Nachricht'}`;
        const body =
          content.length > 100 ? content.substring(0, 100) + '...' : content;
        await Promise.allSettled(
          members.map((m) =>
            sendPushToUser(m.userId, {
              title,
              body,
              data: { type: 'group_chat', roomId, groupId, senderId: userId },
            })
          )
        );
        return;
      }
      recipientUid = participant.otherUid;
      if (!recipientUid) return;
      await sendPushToUser(recipientUid, {
        title: userName || 'Neue Nachricht',
        body: content.length > 100 ? content.substring(0, 100) + '...' : content,
        data: { type: 'friend_chat', roomId, senderId: userId },
      });
    } catch (error) {
      console.error('Friend-Chat Push fehlgeschlagen:', error?.message || error);
    }
  };

  try {
    await ensureSocialSchemaReady();
    await prisma.$executeRawUnsafe(
      `INSERT INTO "FriendChatMessage" ("id", "roomId", "authorUserId", "authorName", "content", "createdAt") VALUES ($1, $2, $3, $4, $5, NOW())`,
      item.id, roomId, userId, userName, content
    );
    await pushToRecipient();
    return res.status(201).json({ item });
  } catch (error) {
    return respondChatPersistenceError(res, 'POST /friend-chat/messages', error);
  }
});

// ─── Chat-Übersicht: alle Unterhaltungen eines Nutzers ──────────────────────
// Liefert pro Raum (1:1 + Gruppen) die letzte Nachricht, Zeit und die Zahl
// ungelesener Nachrichten (basierend auf ChatRead.lastReadAt). Grundlage für
// die Messenger-Liste im Chats-Tab.
app.get('/friend-chat/overview', requireVerifiedUser, async (req, res) => {
  const userId = req.firebaseUid;
  try {
    await ensureSocialSchemaReady();

    // Kandidaten nach exakten Segmenten; vor Vorschau nochmals kanonisch pruefen.
    const directRooms = await prisma.$queryRawUnsafe(
      `SELECT DISTINCT "roomId" FROM "FriendChatMessage"
       WHERE split_part("roomId", '__', 1) = $1
          OR split_part("roomId", '__', 2) = $1`,
      userId
    );
    // Gruppen-Räume: alle Gruppen, in denen der Nutzer Mitglied ist.
    const groupRows = await prisma.$queryRawUnsafe(
      `SELECT g."id", g."name", g."photoUrl"
       FROM "ChatGroup" g
       JOIN "ChatGroupMember" m ON m."groupId" = g."id"
       WHERE m."userId" = $1`,
      userId
    );

    const conversations = [];

    // Lese-Zeitpunkte des Nutzers für alle Räume einsammeln.
    const reads = await prisma.$queryRawUnsafe(
      `SELECT "roomId", "lastReadAt" FROM "ChatRead" WHERE "userId" = $1`,
      userId
    );
    const lastReadByRoom = new Map();
    for (const r of reads) lastReadByRoom.set(r.roomId, r.lastReadAt);

    // "Für mich gelöscht"-Zeitpunkte: Nachrichten davor zählen für diesen
    // Nutzer nicht und blenden einen 1:1-Chat aus, solange nichts Neues kam.
    const cleared = await prisma.$queryRawUnsafe(
      `SELECT "roomId", "clearedAt" FROM "ChatCleared" WHERE "userId" = $1`,
      userId
    );
    const clearedByRoom = new Map();
    for (const c of cleared) clearedByRoom.set(c.roomId, c.clearedAt);

    async function summarize(roomId, { isGroup, name, photoUrl }) {
      const clearedAt = clearedByRoom.get(roomId) || null;
      // Letzte für den Nutzer SICHTBARE Nachricht (nach clearedAt).
      const lastRows = await prisma.$queryRawUnsafe(
        `SELECT "authorUserId", "authorName", "content", "createdAt"
         FROM "FriendChatMessage"
         WHERE "roomId" = $1 AND ("createdAt" > $2 OR $2 IS NULL)
         ORDER BY "createdAt" DESC LIMIT 1`,
        roomId, clearedAt
      );
      const last = lastRows[0] || null;
      const lastReadAt = lastReadByRoom.get(roomId) || null;
      // Ungelesen = fremde Nachrichten nach lastReadAt UND nach clearedAt.
      const unreadRows = await prisma.$queryRawUnsafe(
        `SELECT COUNT(*)::int AS "c" FROM "FriendChatMessage"
         WHERE "roomId" = $1 AND "authorUserId" <> $2
         AND ("createdAt" > $3 OR $3 IS NULL)
         AND ("createdAt" > $4 OR $4 IS NULL)`,
        roomId, userId, lastReadAt, clearedAt
      );
      const unread = unreadRows[0] ? Number(unreadRows[0].c || 0) : 0;
      return {
        roomId,
        isGroup: !!isGroup,
        name: name || null,
        photoUrl: photoUrl || '',
        lastMessage: last ? last.content : '',
        lastAuthorName: last ? last.authorName : '',
        lastAuthorUserId: last ? last.authorUserId : '',
        lastMessageAt: last ? last.createdAt : null,
        unreadCount: unread,
        _hasVisibleMessage: last != null,
      };
    }

    for (const row of directRooms) {
      const participant = directChatParticipant(row.roomId, userId);
      if (!participant ||
          await hasBlockedMe(participant.otherUid, userId, { strict: true })) continue;
      const summary = await summarize(row.roomId, { isGroup: false });
      // 1:1-Chats ohne sichtbare Nachricht (komplett "für mich gelöscht")
      // werden aus der Übersicht ausgeblendet, bis etwas Neues kommt.
      if (summary._hasVisibleMessage) conversations.push(summary);
    }
    for (const g of groupRows) {
      // Gruppen bleiben sichtbar, solange man Mitglied ist (auch ohne
      // sichtbare Nachricht), damit man weiter hineinschreiben kann.
      conversations.push(
        await summarize(`group_${g.id}`, {
          isGroup: true,
          name: g.name,
          photoUrl: g.photoUrl,
        })
      );
    }

    // Neueste Unterhaltung zuerst; Räume ohne Nachricht ans Ende.
    conversations.sort((a, b) => {
      const ta = a.lastMessageAt ? new Date(a.lastMessageAt).getTime() : 0;
      const tb = b.lastMessageAt ? new Date(b.lastMessageAt).getTime() : 0;
      return tb - ta;
    });

    // Internes Hilfsfeld nicht nach außen geben.
    for (const c of conversations) delete c._hasVisibleMessage;

    return res.json({ conversations });
  } catch (error) {
    return respondChatPersistenceError(res, 'GET /friend-chat/overview', error);
  }
});

// ─── Gelesen-Status setzen ──────────────────────────────────────────────────
// Markiert einen Raum für den Nutzer bis jetzt als gelesen (Ungelesen → 0).
app.post('/friend-chat/read', requireVerifiedUser, async (req, res) => {
  const roomId = req.body.roomId;
  if (!await authorizeChatParticipant(req, res, roomId)) return;
  const userId = req.firebaseUid;
  if (!roomId || !userId) {
    return res.status(400).json({ error: 'roomId und userId erforderlich' });
  }
  try {
    await ensureSocialSchemaReady();
    await prisma.$executeRawUnsafe(
      `INSERT INTO "ChatRead" ("roomId", "userId", "lastReadAt")
       VALUES ($1, $2, NOW())
       ON CONFLICT ("roomId", "userId")
       DO UPDATE SET "lastReadAt" = NOW()`,
      roomId, userId
    );
    return res.json({ ok: true });
  } catch (error) {
    return respondChatPersistenceError(res, 'POST /friend-chat/read', error);
  }
});

// ─── Chat löschen (WhatsApp-Stil) ────────────────────────────────────────────
// "Für mich löschen": blendet den bisherigen Verlauf nur für diesen Nutzer aus
// (clearedAt). Der Verlauf der anderen Seite bleibt vollständig erhalten.
app.post('/friend-chat/clear-for-me', requireVerifiedUser, async (req, res) => {
  const roomId = req.body.roomId;
  if (!await authorizeChatParticipant(req, res, roomId)) return;
  const userId = req.firebaseUid;
  if (!roomId || !userId) {
    return res.status(400).json({ error: 'roomId und userId erforderlich' });
  }
  try {
    await ensureSocialSchemaReady();
    await prisma.$executeRawUnsafe(
      `INSERT INTO "ChatCleared" ("roomId", "userId", "clearedAt")
       VALUES ($1, $2, NOW())
       ON CONFLICT ("roomId", "userId")
       DO UPDATE SET "clearedAt" = NOW()`,
      roomId, userId
    );
    return res.json({ ok: true });
  } catch (error) {
    return respondChatPersistenceError(res, 'POST /friend-chat/clear-for-me', error);
  }
});

// "Für alle löschen": entfernt den Verlauf physisch für ALLE Teilnehmer.
// Nur ein echter Teilnehmer (1:1) bzw. ein Gruppenmitglied darf das auslösen.
app.post('/friend-chat/delete-for-all', requireVerifiedUser, async (req, res) => {
  const roomId = req.body.roomId;
  if (!await authorizeChatParticipant(req, res, roomId)) return;
  try {
    await ensureSocialSchemaReady();

    await prisma.$executeRawUnsafe(
      `DELETE FROM "FriendChatMessage" WHERE "roomId" = $1`,
      roomId
    );
    // Aufräumen: Lese-/Lösch-Marker dieses Raums entfernen (Verlauf ist weg).
    await prisma.$executeRawUnsafe(`DELETE FROM "ChatRead" WHERE "roomId" = $1`, roomId);
    await prisma.$executeRawUnsafe(`DELETE FROM "ChatCleared" WHERE "roomId" = $1`, roomId);
    return res.json({ ok: true });
  } catch (error) {
    return respondChatPersistenceError(res, 'POST /friend-chat/delete-for-all', error);
  }
});

// ─── Gruppenchat (Stufe 2) ───────────────────────────────────────────────────
// Gruppe erstellen. Ersteller wird automatisch Owner-Mitglied.
app.post('/chat-groups', requireVerifiedUser, async (req, res) => {
  if (!requireActorClaims(req, res, [req.body.ownerUserId])) return;
  const name = (req.body.name || '').toString().trim();
  const ownerUserId = req.firebaseUid;
  const ownerName = (req.body.ownerName || 'Elternteil').toString().trim();
  const photoUrl = (req.body.photoUrl || '').toString().trim();
  const memberUids = Array.isArray(req.body.memberUids) ? req.body.memberUids : [];
  const memberNames = (req.body.memberNames && typeof req.body.memberNames === 'object')
    ? req.body.memberNames : {};
  if (!name || !ownerUserId) {
    return res.status(400).json({ error: 'name und ownerUserId erforderlich' });
  }
  if (await isUserSuspended(ownerUserId)) return respondSuspended(res);
  try {
    await ensureSocialSchemaReady();
    const id = generateId('grp');
    await prisma.$executeRawUnsafe(
      `INSERT INTO "ChatGroup" ("id", "name", "ownerUserId", "photoUrl") VALUES ($1, $2, $3, $4)`,
      id, name, ownerUserId, photoUrl
    );
    // Owner + eingeladene Mitglieder (dedupliziert) eintragen.
    const members = new Map();
    members.set(ownerUserId, { name: ownerName, role: 'owner' });
    for (const uid of memberUids) {
      const u = (uid || '').toString().trim();
      if (!u || members.has(u)) continue;
      members.set(u, { name: (memberNames[u] || 'Elternteil').toString(), role: 'member' });
    }
    for (const [uid, info] of members) {
      await prisma.$executeRawUnsafe(
        `INSERT INTO "ChatGroupMember" ("groupId", "userId", "memberName", "role")
         VALUES ($1, $2, $3, $4) ON CONFLICT ("groupId", "userId") DO NOTHING`,
        id, uid, info.name, info.role
      );
    }
    return res.status(201).json({
      group: { id, name, ownerUserId, photoUrl, roomId: `group_${id}` },
    });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'POST /chat-groups', error)) return;
    return res.status(500).json({ error: 'Gruppe konnte nicht erstellt werden' });
  }
});

// Alle Gruppen eines Nutzers (für die Chat-Übersicht / Gruppen-Liste).
app.get('/chat-groups', requireVerifiedUser, async (req, res) => {
  const userId = req.firebaseUid;
  if (!userId) return res.status(400).json({ error: 'userId erforderlich' });
  try {
    await ensureSocialSchemaReady();
    const rows = await prisma.$queryRawUnsafe(
      `SELECT g."id", g."name", g."ownerUserId", g."photoUrl", g."createdAt"
       FROM "ChatGroup" g
       JOIN "ChatGroupMember" m ON m."groupId" = g."id"
       WHERE m."userId" = $1
       ORDER BY g."createdAt" DESC`,
      userId
    );
    const groups = rows.map(g => ({ ...g, roomId: `group_${g.id}` }));
    return res.json({ groups });
  } catch (error) {
    return respondChatPersistenceError(res, 'GET /chat-groups', error);
  }
});

// Mitglieder einer Gruppe.
app.get('/chat-groups/:id/members', requireVerifiedUser, async (req, res) => {
  const groupId = (req.params.id || '').toString().trim();
  if (!groupId) return res.status(400).json({ error: 'id erforderlich' });
  if (!await authorizeChatParticipant(req, res, `group_${groupId}`)) return;
  try {
    await ensureSocialSchemaReady();
    const members = await prisma.$queryRawUnsafe(
      `SELECT "userId", "memberName", "role", "joinedAt"
       FROM "ChatGroupMember" WHERE "groupId" = $1 ORDER BY "joinedAt" ASC`,
      groupId
    );
    return res.json({ members });
  } catch (error) {
    return respondChatPersistenceError(res, 'GET /chat-groups/:id/members', error);
  }
});

// Mitglieder zu einer Gruppe hinzufügen (nur Mitglieder dürfen einladen).
app.post('/chat-groups/:id/members', requireVerifiedUser, async (req, res) => {
  if (!requireActorClaims(req, res, [req.body.actingUserId])) return;
  const groupId = (req.params.id || '').toString().trim();
  const actingUserId = req.firebaseUid;
  const memberUids = Array.isArray(req.body.memberUids) ? req.body.memberUids : [];
  const memberNames = (req.body.memberNames && typeof req.body.memberNames === 'object')
    ? req.body.memberNames : {};
  if (!groupId || !actingUserId) {
    return res.status(400).json({ error: 'id und actingUserId erforderlich' });
  }
  if (!await authorizeChatParticipant(req, res, `group_${groupId}`)) return;
  try {
    await ensureSocialSchemaReady();
    for (const uid of memberUids) {
      const u = (uid || '').toString().trim();
      if (!u) continue;
      await prisma.$executeRawUnsafe(
        `INSERT INTO "ChatGroupMember" ("groupId", "userId", "memberName", "role")
         VALUES ($1, $2, $3, 'member') ON CONFLICT ("groupId", "userId") DO NOTHING`,
        groupId, u, (memberNames[u] || 'Elternteil').toString()
      );
    }
    return res.json({ ok: true });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'POST /chat-groups/:id/members', error)) return;
    return res.status(500).json({ error: 'Mitglieder konnten nicht hinzugefügt werden' });
  }
});

// Gruppe verlassen.
app.delete('/chat-groups/:id/members/:userId', requireVerifiedUser, async (req, res) => {
  if (!requireActorClaims(req, res, [req.params.userId])) return;
  const groupId = (req.params.id || '').toString().trim();
  const userId = req.firebaseUid;
  if (!groupId || !userId) {
    return res.status(400).json({ error: 'id und userId erforderlich' });
  }
  if (!await authorizeChatParticipant(req, res, `group_${groupId}`)) return;
  try {
    await ensureSocialSchemaReady();
    await prisma.$executeRawUnsafe(
      `DELETE FROM "ChatGroupMember" WHERE "groupId" = $1 AND "userId" = $2`,
      groupId, userId
    );
    return res.json({ ok: true });
  } catch (error) {
    return respondChatPersistenceError(res, 'DELETE /chat-groups/:id/members/:userId', error);
  }
});

app.get('/family/requests', requireVerifiedUser, async (req, res) => {
  const userId = (req.query.userId || '').toString().trim();
  const toUserId = (req.query.toUserId || userId || '').toString().trim();
  const fromUserId = (req.query.fromUserId || '').toString().trim();
  const status = (req.query.status || '').toString().trim();
  const allowedStatuses = new Set(['pending', 'accepted', 'declined']);
  if ((toUserId || fromUserId) && toUserId !== req.firebaseUid && fromUserId !== req.firebaseUid) {
    return res.status(403).json({ error: 'Own family requests only' });
  }

  if (status && !allowedStatuses.has(status)) {
    return res.status(400).json({ error: 'Ungültiger Status' });
  }

  const where = { OR: [{ fromUserId: req.firebaseUid }, { toUserId: req.firebaseUid }] };
  if (toUserId) {
    where.toUserId = toUserId;
  }
  if (fromUserId) {
    where.fromUserId = fromUserId;
  }
  if (status) {
    where.status = status;
  }

  try {
    const requests = await prisma.familyRequest.findMany({
      where: Object.keys(where).length > 0 ? where : undefined,
      orderBy: { createdAt: 'desc' },
    });
    return res.json({ requests });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'GET /family/requests', error)) {
      return;
    }
    const requests = familyRequests.filter(item => {
      if (item.fromUserId !== req.firebaseUid && item.toUserId !== req.firebaseUid) return false;
      if (toUserId && item.toUserId !== toUserId) return false;
      if (fromUserId && item.fromUserId !== fromUserId) return false;
      if (status && item.status !== status) return false;
      return true;
    });
    return res.json({ requests });
  }
});

app.post('/family/requests', requireVerifiedUser, async (req, res) => {
  if (!requireActorClaims(req, res, [req.body.fromUserId, req.body.actingUserId])) return;
  const fromUserId = req.firebaseUid;
  const toUserId = (req.body.toUserId || '').toString().trim();
  const actingUserId = (req.body.actingUserId || '').toString().trim();
  const status = (req.body.status || 'pending').toString().trim();

  if (!fromUserId || !toUserId) {
    return res.status(400).json({ error: 'fromUserId und toUserId sind erforderlich' });
  }
  if (fromUserId === toUserId) {
    return res.status(400).json({ error: 'fromUserId und toUserId dürfen nicht identisch sein' });
  }
  if (status !== 'pending') {
    return res.status(403).json({ error: 'New family requests must be pending' });
  }
  if (actingUserId && actingUserId !== fromUserId) {
    return res.status(403).json({ error: 'actingUserId muss mit fromUserId übereinstimmen' });
  }

  try {
    const existing = await prisma.familyRequest.findFirst({
      where: {
        OR: [
          {
            fromUserId,
            toUserId,
          },
          {
            fromUserId: toUserId,
            toUserId: fromUserId,
          },
        ],
      },
      orderBy: { createdAt: 'desc' },
    });

    if (existing && ['pending', 'accepted'].includes(existing.status)) {
      return res.status(409).json({
        error: 'Anfrage existiert bereits',
        existingRequestId: existing.id,
      });
    }

    const item = await prisma.familyRequest.create({
      data: {
        fromUserId,
        toUserId,
        status,
      },
    });

    familyRequests.unshift({
      id: item.id,
      fromUserId: item.fromUserId,
      toUserId: item.toUserId,
      status: item.status,
      sentAt: item.createdAt,
      updatedAt: item.updatedAt,
    });

    return res.status(201).json({ item });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'POST /family/requests', error)) {
      return;
    }

    const existing = familyRequests
      .filter(
        request =>
          (request.fromUserId === fromUserId && request.toUserId === toUserId) ||
          (request.fromUserId === toUserId && request.toUserId === fromUserId),
      )
      .sort(
        (a, b) =>
          new Date(b.updatedAt || b.sentAt || 0).getTime() -
          new Date(a.updatedAt || a.sentAt || 0).getTime(),
      )[0];

    if (existing && ['pending', 'accepted'].includes(existing.status)) {
      return res.status(409).json({
        error: 'Anfrage existiert bereits',
        existingRequestId: existing.id,
      });
    }

    const item = {
      id: generateId('req'),
      fromUserId,
      toUserId,
      status,
      sentAt: new Date().toISOString(),
      updatedAt: null,
    };
    familyRequests.unshift(item);
    return res.status(201).json({ item });
  }
});

app.put('/family/requests/:id', requireVerifiedUser, async (req, res) => {
  if (!requireActorClaims(req, res, [req.body.actingUserId])) return;
  const status = req.body.status;
  const actingUserId = req.firebaseUid;

  if (!['accepted', 'declined'].includes(status)) {
    return res.status(400).json({ error: 'Ungültiger Status' });
  }

  try {
    const current = await prisma.familyRequest.findUnique({ where: { id: req.params.id } });
    if (!current) {
      return res.status(404).json({ error: 'Anfrage nicht gefunden' });
    }

    if (actingUserId) {
      const isRecipient = actingUserId === current.toUserId;
      const isSender = actingUserId === current.fromUserId;

      if (!isRecipient && !isSender) {
        return res.status(403).json({ error: 'Keine Berechtigung, diese Anfrage zu ändern' });
      }
      // Only the recipient may accept; the sender may only withdraw (decline).
      if (isSender && !isRecipient && status === 'accepted') {
        return res.status(403).json({ error: 'Nur der Empfänger kann eine Anfrage annehmen' });
      }
    }

    const item = await prisma.familyRequest.update({
      where: { id: req.params.id },
      data: { status },
    });

    const index = familyRequests.findIndex(entry => entry.id === req.params.id);
    if (index !== -1) {
      familyRequests[index] = {
        ...familyRequests[index],
        status: item.status,
        updatedAt: item.updatedAt,
      };
    }

    return res.json({ item });
  } catch (error) {
    if (error?.code === 'P2025') {
      return res.status(404).json({ error: 'Anfrage nicht gefunden' });
    }

    if (respondWithStrictPersistenceError(res, 'PUT /family/requests/:id', error)) {
      return;
    }
    const index = familyRequests.findIndex(entry => entry.id === req.params.id);
    if (index === -1) {
      return res.status(404).json({ error: 'Anfrage nicht gefunden' });
    }

    const entry = familyRequests[index];
    if (actingUserId) {
      const isRecipient = actingUserId === entry.toUserId;
      const isSender = actingUserId === entry.fromUserId;
      if (!isRecipient && !isSender) {
        return res.status(403).json({ error: 'Keine Berechtigung, diese Anfrage zu ändern' });
      }
      if (isSender && !isRecipient && status === 'accepted') {
        return res.status(403).json({ error: 'Nur der Empfänger kann eine Anfrage annehmen' });
      }
    }

    familyRequests[index] = {
      ...entry,
      status,
      updatedAt: new Date().toISOString(),
    };
    return res.json({ item: familyRequests[index] });
  }
});

app.delete('/family/requests/:id', requireVerifiedUser, async (req, res) => {
  if (!requireActorClaims(req, res, [req.body?.actingUserId, req.query.actingUserId])) return;
  const actingUserId = req.firebaseUid;

  try {
    const current = await prisma.familyRequest.findUnique({ where: { id: req.params.id } });
    if (!current) {
      return res.status(404).json({ error: 'Anfrage nicht gefunden' });
    }

    if (actingUserId) {
      const involved = actingUserId === current.fromUserId || actingUserId === current.toUserId;
      if (!involved) {
        return res.status(403).json({ error: 'Keine Berechtigung, diese Anfrage zu löschen' });
      }
    }

    await prisma.familyRequest.delete({ where: { id: req.params.id } });

    const idx = familyRequests.findIndex(item => item.id === req.params.id);
    if (idx !== -1) familyRequests.splice(idx, 1);

    return res.status(204).send();
  } catch (error) {
    if (error?.code === 'P2025') {
      return res.status(404).json({ error: 'Anfrage nicht gefunden' });
    }

    if (respondWithStrictPersistenceError(res, 'DELETE /family/requests/:id', error)) {
      return;
    }
    const idx = familyRequests.findIndex(item => item.id === req.params.id);
    if (idx === -1) {
      return res.status(404).json({ error: 'Anfrage nicht gefunden' });
    }

    const entry = familyRequests[idx];
    if (actingUserId) {
      const involved = actingUserId === entry.fromUserId || actingUserId === entry.toUserId;
      if (!involved) {
        return res.status(403).json({ error: 'Keine Berechtigung, diese Anfrage zu löschen' });
      }
    }

    familyRequests.splice(idx, 1);
    return res.status(204).send();
  }
});

// 14. Events (Prisma-first with in-memory fallback)
async function eventIdentityMiddleware(req, res, next) {
  if (req.firebaseUid) return next();
  if (!req.headers.authorization) return next();
  const { uid, verified } = await verifyFirebaseIdToken(req);
  if (!verified) return res.status(401).json({ error: 'Valid Firebase token required for events' });
  req.firebaseUid = uid;
  return next();
}

app.use(['/events', '/api/events'], eventIdentityMiddleware);

app.get('/events', async (req, res) => {
  const MAX_LIMIT = 100;
  const limit = Math.min(Math.max(Number.parseInt(req.query.limit || '50', 10) || 50, 1), MAX_LIMIT);
  const offset = Math.max(Number.parseInt(req.query.offset || '0', 10) || 0, 0);

  try {
    const hostUserId = (req.query.hostUserId || '').toString().trim();
    const records = await resilientEventFindMany({
      where: hostUserId ? { hosterId: hostUserId } : undefined,
      orderBy: { createdAt: 'desc' },
      skip: offset,
      take: limit,
    });

    const visibleRecords = [];
    for (const record of records) {
      try {
        const current = req.firebaseUid ? await prisma.eventParticipation.findUnique({
          where: { eventId_userId: { eventId: record.id, userId: req.firebaseUid } },
        }) : null;
        await authorizeEventParticipation(prisma, record, req.firebaseUid, current);
        visibleRecords.push(record);
      } catch (error) { if (error.httpStatus !== 403) throw error; }
    }

    const countMap = await buildParticipantCountMap(records.map(item => item.id));
    let items = visibleRecords.map(item =>
      mapEventRecordToApiItem(item, { currentParticipants: countMap.get(item.id) || 0 }),
    );

    if (req.query.status) {
      const requestedStatus = req.query.status.toString();
      items = items.filter(event => event.status === requestedStatus);
    }

    return res.json({ items, limit, offset, hasMore: items.length === limit });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'GET /events', error)) {
      return;
    }
    let items = [...events];
    if (req.query.status) {
      items = items.filter(event => event.status === req.query.status);
    }
    if (req.query.hostUserId) {
      items = items.filter(event => event.hosterId === req.query.hostUserId);
    }
    const page = items.slice(offset, offset + limit);
    return res.json({ items: page, limit, offset, hasMore: page.length === limit });
  }
});

app.get('/events/discover', async (req, res) => {
  const viewerUserId = req.firebaseUid || 'guest_user';

  try {
    const acceptedInvites = await prisma.eventParticipation.findMany({
      where: {
        userId: viewerUserId,
        status: 'accepted',
      },
      select: { eventId: true },
    });
    const acceptedInviteEventIds = new Set(acceptedInvites.map(item => item.eventId));

    const records = await resilientEventFindMany({
      orderBy: { createdAt: 'desc' },
    });
    const candidateHostIds = [...new Set(records.map(item => item.hosterId).filter(Boolean))].filter(
      hostId => hostId !== viewerUserId,
    );
    const acceptedFamilyLinks = candidateHostIds.length
      ? await prisma.familyRequest.findMany({
          where: {
            status: 'accepted',
            OR: [
              {
                fromUserId: viewerUserId,
                toUserId: { in: candidateHostIds },
              },
              {
                toUserId: viewerUserId,
                fromUserId: { in: candidateHostIds },
              },
            ],
          },
          select: {
            fromUserId: true,
            toUserId: true,
          },
        })
      : [];
    const familyHostIds = new Set();
    for (const request of acceptedFamilyLinks) {
      if (request.fromUserId === viewerUserId) {
        familyHostIds.add(request.toUserId);
      } else {
        familyHostIds.add(request.fromUserId);
      }
    }

    // Keep existing in-memory accepted links as compatibility fallback during partial migrations.
    for (const request of familyRequests) {
      if (!request || request.status !== 'accepted') continue;
      if (request.fromUserId === viewerUserId) {
        familyHostIds.add(request.toUserId);
      }
      if (request.toUserId === viewerUserId) {
        familyHostIds.add(request.fromUserId);
      }
    }

    const countMap = await buildParticipantCountMap(records.map(item => item.id));
    let items = records
      .map(item => mapEventRecordToApiItem(item, { currentParticipants: countMap.get(item.id) || 0 }))
      .filter(event => {
        if (!event || event.status !== 'active') return false;
        if (event.hosterId === viewerUserId) return true;
        if (event.visibility === 'privateOnly') return false;
        if (event.visibility === 'familyCircle') {
          return familyHostIds.has(event.hosterId);
        }
        if (event.visibility === 'inviteOnly') {
          return acceptedInviteEventIds.has(event.id);
        }
        return true;
      });

    if (req.query.ageGroups) {
      const requested = req.query.ageGroups
        .toString()
        .split(',')
        .map(value => value.trim())
        .filter(Boolean);
      if (requested.length > 0) {
        items = items.filter(event =>
          (event.ageGroups || []).some(group => requested.includes(group)),
        );
      }
    }

    const MAX_LIMIT = 100;
    const limit = Math.min(Math.max(Number.parseInt(req.query.limit || '50', 10) || 50, 1), MAX_LIMIT);
    const offset = Math.max(Number.parseInt(req.query.offset || '0', 10) || 0, 0);
    const page = items.slice(offset, offset + limit);
    return res.json({ items: page, limit, offset, hasMore: page.length === limit });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'GET /events/discover', error)) {
      return;
    }
    let items = events.filter(event => canViewerSeeEvent(event, viewerUserId));
    if (req.query.ageGroups) {
      const requested = req.query.ageGroups
        .toString()
        .split(',')
        .map(value => value.trim())
        .filter(Boolean);
      if (requested.length > 0) {
        items = items.filter(event =>
          (event.ageGroups || []).some(group => requested.includes(group)),
        );
      }
    }
    const MAX_LIMIT = 100;
    const limit = Math.min(Math.max(Number.parseInt(req.query.limit || '50', 10) || 50, 1), MAX_LIMIT);
    const offset = Math.max(Number.parseInt(req.query.offset || '0', 10) || 0, 0);
    const page = items.slice(offset, offset + limit);
    return res.json({ items: page, limit, offset, hasMore: page.length === limit });
  }
});

app.put('/events/item/:id', async (req, res) => {
  const body = req.body || {};
  if (!req.firebaseUid) return res.status(401).json({ error: 'Firebase sign-in required' });
  const requestingUserId = (body.requestingUserId || '').toString().trim();

  const updatableFields = {
    ...(body.title !== undefined && { title: body.title }),
    ...(body.description !== undefined && { description: body.description }),
    ...(body.location !== undefined && { location: body.location }),
    ...(body.latitude !== undefined && { latitude: Number(body.latitude) }),
    ...(body.longitude !== undefined && { longitude: Number(body.longitude) }),
    ...(body.eventDate !== undefined && { startDate: new Date(body.eventDate) }),
    ...(body.maxParticipants !== undefined && { maxParticipants: Number(body.maxParticipants) }),
    ...(body.photoUrl !== undefined && { imageUrl: body.photoUrl }),
    ...(body.status !== undefined && { status: mapApiEventStatusToDb(body.status) }),
    ...(body.visibility !== undefined && { visibility: body.visibility }),
    ...(body.shareRadiusKm !== undefined && { shareRadiusKm: Number(body.shareRadiusKm) }),
    ...(body.price !== undefined && { costPerPerson: body.price != null ? Number(body.price) : null }),
  };

  if (Object.keys(updatableFields).length === 0) {
    return res.status(400).json({ error: 'Keine Felder zum Aktualisieren angegeben' });
  }

  try {
    const record = await prisma.event.findUnique({
      where: { id: req.params.id },
      select: { id: true, hosterId: true },
    });

    if (!record) {
      return res.status(404).json({ error: 'Event nicht gefunden' });
    }
    if (requestingUserId && requestingUserId !== record.hosterId) {
      return res.status(403).json({ error: 'Nur der Hoster darf dieses Event bearbeiten' });
    }

    const updated = await updateOwnedEvent(prisma, req.params.id, req.firebaseUid, updatableFields);

    const countMap = await buildParticipantCountMap([updated.id]);
    const item = mapEventRecordToApiItem(updated, {
      currentParticipants: countMap.get(updated.id) || 0,
    });

    const idx = events.findIndex(ev => ev.id === req.params.id);
    if (idx !== -1) {
      events[idx] = { ...events[idx], ...item };
    }

    return res.json({ item });
  } catch (error) {
    return res.status(error.httpStatus || 503).json({ error: error.message });
  }
});

app.get('/events/item/:id', async (req, res) => {
  try {
    const record = await prisma.event.findUnique({ where: { id: req.params.id } });
    if (!record) {
      return res.status(404).json({ error: 'Event nicht gefunden' });
    }

    const current = req.firebaseUid ? await prisma.eventParticipation.findUnique({
      where: { eventId_userId: { eventId: record.id, userId: req.firebaseUid } },
    }) : null;
    await authorizeEventParticipation(prisma, record, req.firebaseUid, current);

    const countMap = await buildParticipantCountMap([record.id]);
    const item = mapEventRecordToApiItem(record, {
      currentParticipants: countMap.get(record.id) || 0,
    });
    const inviteCode = item.inviteCode || eventInviteCodes[item.id] || null;
    const inviteCodeExpiresAt = eventInviteExpiresAt[item.id] || item.inviteCodeExpiresAt || null;
    return res.json({ item: { ...item, inviteCode, inviteCodeExpiresAt } });
  } catch (error) {
    if (error.httpStatus) return res.status(error.httpStatus).json({ error: error.message });
    if (respondWithStrictPersistenceError(res, 'GET /events/item/:id', error)) {
      return;
    }
    const item = events.find(event => event.id === req.params.id);
    if (!item) {
      return res.status(404).json({ error: 'Event nicht gefunden' });
    }
    const inviteCode = item.inviteCode || eventInviteCodes[item.id] || null;
    const inviteCodeExpiresAt = eventInviteExpiresAt[item.id] || item.inviteCodeExpiresAt || null;
    return res.json({ item: { ...item, inviteCode, inviteCodeExpiresAt } });
  }
});

app.post('/events', requireVerifiedUser, async (req, res) => {
  const body = req.body || {};
  if (!req.firebaseUid) return res.status(401).json({ error: 'Firebase sign-in required' });
  if (req.firebaseUid !== body.hosterId) return res.status(403).json({ error: 'Own account only' });
  if (body.participationMode || body.externalUrl) return res.status(400).json({ error: 'Use /api/events for explicit modes' });
  // Echter Bann: gesperrte Nutzer koennen keine Events mehr erstellen.
  if (body.hosterId && await isUserSuspended(body.hosterId.toString().trim())) {
    return respondSuspended(res);
  }
  const item = {
    id: body.id || generateId('event'),
    hosterId: body.hosterId || 'host_demo_001',
    title: body.title || 'Neues Event',
    description: body.description || '',
    category: body.category || 'other',
    ageGroups: Array.isArray(body.ageGroups) ? body.ageGroups : [],
    location: body.location || '',
    latitude: Number(body.latitude || 0),
    longitude: Number(body.longitude || 0),
    eventDate: body.eventDate || new Date().toISOString(),
    createdAt: body.createdAt || new Date().toISOString(),
    paymentDate: body.paymentDate || null,
    maxParticipants: Number(body.maxParticipants || 20),
    currentParticipants: Number(body.currentParticipants || 0),
    photoUrl: body.photoUrl || '',
    status: body.status || 'active',
    price: body.price ?? null,
    visibility: body.visibility || 'publicNearby',
    shareRadiusKm: Number(body.shareRadiusKm || 25),
    invitedUserIds: Array.isArray(body.invitedUserIds) ? body.invitedUserIds : [],
    inviteCodeExpiresAt: body.inviteCodeExpiresAt || null,
  };

  try {
    let inviteCode = null;
    let inviteCodeExpiresAt = item.inviteCodeExpiresAt || null;
    if (item.visibility === 'inviteOnly') {
      inviteCode = generateInviteCode(item.id);
      inviteCodeExpiresAt =
        inviteCodeExpiresAt || new Date(Date.now() + 14 * 24 * 60 * 60 * 1000).toISOString();
    }

    const hosterId = await ensureBackendUser(item.hosterId, item.hosterId);
    const created = await prisma.event.create({
      data: {
        id: item.id,
        hosterId,
        title: item.title,
        description: item.description,
        startDate: new Date(item.eventDate),
        location: item.location,
        latitude: item.latitude,
        longitude: item.longitude,
        status: mapApiEventStatusToDb(item.status),
        eventType: item.category,
        maxParticipants: item.maxParticipants,
        imageUrl: item.photoUrl,
        visibility: item.visibility,
        shareRadiusKm: item.shareRadiusKm,
        inviteCode,
        inviteCodeExpiresAt: inviteCodeExpiresAt ? new Date(inviteCodeExpiresAt) : null,
        costPerPerson: item.price != null ? Number(item.price) : null,
      },
    });

    const mirroredIndex = events.findIndex(event => event.id === item.id);
    if (mirroredIndex === -1) {
      events.push(item);
    } else {
      events[mirroredIndex] = item;
    }

    if (item.visibility === 'inviteOnly') {
      eventInviteCodes[item.id] = inviteCode;
      eventInviteExpiresAt[item.id] = inviteCodeExpiresAt;

      for (const invitedUserIdRaw of item.invitedUserIds) {
        const invitedUserId = await ensureBackendUser(invitedUserIdRaw, invitedUserIdRaw);
        await prisma.eventParticipation.upsert({
          where: {
            eventId_userId: {
              eventId: created.id,
              userId: invitedUserId,
            },
          },
          update: { status: 'invited' },
          create: {
            eventId: created.id,
            userId: invitedUserId,
            status: 'invited',
          },
        });
      }
    }

    return res.status(201).json({
      item: {
        ...item,
        inviteCode: created.inviteCode || eventInviteCodes[item.id] || null,
        inviteCodeExpiresAt:
          created.inviteCodeExpiresAt || eventInviteExpiresAt[item.id] || item.inviteCodeExpiresAt,
      },
    });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'POST /events', error)) {
      return;
    }
    events.push(item);

    if (item.visibility === 'inviteOnly') {
      const code = generateInviteCode(item.id);
      eventInviteCodes[item.id] = code;
      eventInviteExpiresAt[item.id] =
        item.inviteCodeExpiresAt || new Date(Date.now() + 14 * 24 * 60 * 60 * 1000).toISOString();

      for (const invitedUserId of item.invitedUserIds) {
        eventInvitations.push({
          id: `inv_${item.id}_${invitedUserId}`,
          eventId: item.id,
          hostUserId: item.hosterId,
          invitedUserId,
          createdAt: new Date().toISOString(),
          status: 'pending',
        });
      }
    }

    return res.status(201).json({
      item: {
        ...item,
        inviteCode: eventInviteCodes[item.id] || null,
        inviteCodeExpiresAt: eventInviteExpiresAt[item.id] || item.inviteCodeExpiresAt,
      },
    });
  }
});

app.delete('/events/item/:id', requireVerifiedUser, async (req, res) => {
  if (!requireActorClaims(req, res, [req.query.requestingUserId, req.body?.requestingUserId])) return;
  const requestingUserId = req.firebaseUid;

  try {
    const record = await prisma.event.findUnique({
      where: { id: req.params.id },
      select: { id: true, hosterId: true },
    });

    if (!record) {
      return res.status(404).json({ error: 'Event nicht gefunden' });
    }
    if (requestingUserId && requestingUserId !== record.hosterId) {
      return res.status(403).json({ error: 'Nur der Hoster darf dieses Event löschen' });
    }

    await prisma.event.delete({ where: { id: req.params.id } });

    const index = events.findIndex(event => event.id === req.params.id);
    if (index !== -1) {
      events.splice(index, 1);
    }
    delete eventInviteCodes[req.params.id];
    delete eventInviteExpiresAt[req.params.id];
    return res.status(204).send();
  } catch (error) {
    if (error?.code === 'P2025') {
      return res.status(404).json({ error: 'Event nicht gefunden' });
    }

    if (respondWithStrictPersistenceError(res, 'DELETE /events/item/:id', error)) {
      return;
    }
    const index = events.findIndex(event => event.id === req.params.id);
    if (index === -1) {
      return res.status(404).json({ error: 'Event nicht gefunden' });
    }

    const eventEntry = events[index];
    if (requestingUserId && requestingUserId !== eventEntry.hosterId) {
      return res.status(403).json({ error: 'Nur der Hoster darf dieses Event löschen' });
    }

    const [removed] = events.splice(index, 1);
    delete eventInviteCodes[removed.id];
    delete eventInviteExpiresAt[removed.id];

    for (let i = eventInvitations.length - 1; i >= 0; i -= 1) {
      if (eventInvitations[i].eventId === removed.id) {
        eventInvitations.splice(i, 1);
      }
    }

    return res.status(204).send();
  }
});

// 15. Event invitations (Prisma-first with in-memory fallback)
app.get('/events/invitations', async (req, res) => {
  if (!req.firebaseUid) return res.status(401).json({ error: 'Firebase sign-in required' });
  if (req.query.userId !== req.firebaseUid) return res.status(403).json({ error: 'Own invitations only' });
  try {
    let statusFilter = null;
    if (req.query.status) {
      const rawStatus = req.query.status.toString();
      statusFilter = rawStatus === 'pending' ? 'invited' : rawStatus;
    }

    const items = await prisma.eventParticipation.findMany({
      where: {
        status: statusFilter || undefined,
        userId: req.query.userId ? req.query.userId.toString() : undefined,
        eventId: req.query.eventId ? req.query.eventId.toString() : undefined,
      },
      orderBy: { createdAt: 'desc' },
    });

    const invitationItems = items
      .filter(item => ['invited', 'accepted', 'approved', 'attended', 'declined'].includes(item.status))
      .map(mapInvitationRecordToApiItem);

    return res.json({ items: invitationItems });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'GET /events/invitations', error)) {
      return;
    }
    let items = [...eventInvitations];
    if (req.query.userId) {
      items = items.filter(invitation => invitation.invitedUserId === req.query.userId);
    }
    if (req.query.eventId) {
      items = items.filter(invitation => invitation.eventId === req.query.eventId);
    }
    if (req.query.status) {
      items = items.filter(invitation => invitation.status === req.query.status);
    }
    return res.json({ items });
  }
});

app.put('/events/invitations/:id/respond', async (req, res) => {
  if (!req.firebaseUid) return res.status(401).json({ error: 'Firebase sign-in required' });
  try {
    const current = await prisma.eventParticipation.findUnique({ where: { id: req.params.id } });
    if (!current || !['invited', 'accepted', 'approved', 'attended', 'declined'].includes(current.status)) {
      return res.status(404).json({ error: 'Einladung nicht gefunden' });
    }
    if (current.userId !== req.firebaseUid) return res.status(403).json({ error: 'Own invitation only' });

    const accept = Boolean(req.body.accept);
    const updated = await changeParticipation(prisma, {
      eventId: current.eventId, userId: req.firebaseUid,
      action: accept ? 'acceptInvite' : 'declineInvite',
      authorize: async (transaction, event, invitation) => {
        if (!invitation) { const error = new Error('Invitation not found'); error.httpStatus = 404; throw error; }
        await authorizeEventParticipation(transaction, event, req.firebaseUid, invitation);
      },
    });

    return res.json({ item: mapInvitationRecordToApiItem(updated) });
  } catch (error) {
    return res.status(error.httpStatus || 503).json({ error: error.message });
  }
});

app.post('/events/invitations/join', async (req, res) => {
  const codeInput = (req.body.code || '').toString().trim().toUpperCase();
  const userId = (req.body.userId || '').toString().trim();

  if (!req.firebaseUid) return res.status(401).json({ error: 'Firebase sign-in required' });
  if (req.firebaseUid !== userId) return res.status(403).json({ error: 'Own account only' });

  if (!codeInput || !userId) {
    return res.status(400).json({ error: 'Code und UserId sind erforderlich' });
  }

  try {
    const eventByCode = await prisma.event.findFirst({
      where: {
        inviteCode: codeInput,
      },
      select: {
        id: true,
        hosterId: true,
        inviteCodeExpiresAt: true,
      },
    });

    if (!eventByCode || isInviteExpiredAt(eventByCode.inviteCodeExpiresAt)) {
      return res.status(404).json({ error: 'Code ungültig oder abgelaufen' });
    }

    const safeUserId = await ensureAuthenticatedEventUser(req, userId);
    const invitation = await changeParticipation(prisma, {
      eventId: eventByCode.id, userId: safeUserId, action: 'acceptInvite',
      authorize: async (_transaction, event) => {
        if (event.inviteCode !== codeInput || isInviteExpiredAt(event.inviteCodeExpiresAt)) {
          const error = new Error('Invalid or expired invitation'); error.httpStatus = 404; throw error;
        }
      },
    });

    return res.status(201).json({ item: mapInvitationRecordToApiItem(invitation) });
  } catch (error) {
    return res.status(error.httpStatus || 503).json({ error: error.message });
  }
});

app.get('/events/hosted-invite-only', requireVerifiedUser, async (req, res) => {
  if (!requireActorClaims(req, res, [req.query.hostUserId])) return;
  const hostUserId = req.firebaseUid;

  try {
    const records = await resilientEventFindMany({
      where: hostUserId ? { hosterId: hostUserId } : undefined,
      orderBy: { createdAt: 'desc' },
    });
    const countMap = await buildParticipantCountMap(records.map(item => item.id));
    const items = records
      .map(item => mapEventRecordToApiItem(item, { currentParticipants: countMap.get(item.id) || 0 }))
      .filter(
        event =>
          event.visibility === 'inviteOnly' &&
          event.status === 'active' &&
          (!hostUserId || event.hosterId === hostUserId),
      );
    return res.json({ items });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'GET /events/hosted-invite-only', error)) {
      return;
    }
    const items = events.filter(
      event =>
        event.visibility === 'inviteOnly' &&
        event.status === 'active' &&
        (!hostUserId || event.hosterId === hostUserId),
    );
    return res.json({ items });
  }
});

app.get('/events/:id/invitations/accepted', requireVerifiedUser, async (req, res) => {
  try {
    const event = await prisma.event.findUnique({
      where: { id: req.params.id }, select: { hosterId: true },
    });
    if (!event) return res.status(404).json({ error: 'Event not found' });
    if (event.hosterId !== req.firebaseUid) return res.status(403).json({ error: 'Host only' });
    const items = await prisma.eventParticipation.findMany({
      where: { eventId: req.params.id, status: 'accepted' },
      orderBy: { createdAt: 'desc' },
    });
    return res.json({ items: items.map(mapInvitationRecordToApiItem) });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'GET /events/:id/invitations/accepted', error)) {
      return;
    }
    const event = events.find(item => item.id === req.params.id);
    if (!event) return res.status(404).json({ error: 'Event not found' });
    if (event.hosterId !== req.firebaseUid) return res.status(403).json({ error: 'Host only' });
    const items = eventInvitations.filter(
      item => item.eventId === req.params.id && item.status === 'accepted',
    );
    return res.json({ items });
  }
});

// 16. Event participations (Prisma-first with in-memory fallback)
app.get('/events/participations', async (req, res) => {
  if (!req.firebaseUid) return res.status(401).json({ error: 'Firebase sign-in required' });
  if (req.query.userId !== req.firebaseUid) return res.status(403).json({ error: 'Own account only' });
  try {
    const items = await prisma.eventParticipation.findMany({
      where: {
        userId: req.query.userId ? req.query.userId.toString() : undefined,
        eventId: req.query.eventId ? req.query.eventId.toString() : undefined,
      },
      orderBy: { createdAt: 'desc' },
    });
    return res.json({ items: items.map(mapParticipationRecordToApiItem) });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'GET /events/participations', error)) {
      return;
    }
    let items = [...eventParticipations];
    if (req.query.userId) {
      items = items.filter(item => item.userId === req.query.userId);
    }
    if (req.query.eventId) {
      items = items.filter(item => item.eventId === req.query.eventId);
    }
    return res.json({ items });
  }
});

app.get('/events/participations/pending', async (req, res) => {
  const hostUserId = (req.query.hostUserId || '').toString();
  if (!req.firebaseUid) return res.status(401).json({ error: 'Firebase sign-in required' });
  if (hostUserId !== req.firebaseUid) return res.status(403).json({ error: 'Host account only' });

  try {
    const hostEvents = await prisma.event.findMany({
      where: hostUserId ? { hosterId: hostUserId } : undefined,
      select: { id: true },
    });
    const hostEventIds = hostEvents.map(item => item.id);
    const items = await prisma.eventParticipation.findMany({
      where: {
        eventId: { in: hostEventIds },
        status: 'pending',
      },
      orderBy: { createdAt: 'desc' },
    });
    return res.json({ items: items.map(mapParticipationRecordToApiItem) });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'GET /events/participations/pending', error)) {
      return;
    }
    const hostEventIds = events
      .filter(event => !hostUserId || event.hosterId === hostUserId)
      .map(event => event.id);
    const items = eventParticipations.filter(
      item => hostEventIds.includes(item.eventId) && item.status === 'pending',
    );
    return res.json({ items });
  }
});

app.post('/events/participations', async (req, res) => {
  const eventId = (req.body.eventId || '').toString();
  const userId = (req.body.userId || '').toString();

  if (!req.firebaseUid) return res.status(401).json({ error: 'Firebase sign-in required' });
  if (req.firebaseUid && req.firebaseUid !== userId) {
    return res.status(403).json({ error: 'Teilnahme nur fuer das eigene Konto erlaubt' });
  }

  if (!eventId || !userId) {
    return res.status(400).json({ error: 'eventId und userId sind erforderlich' });
  }

  try {
    const event = await prisma.event.findUnique({ where: { id: eventId } });
    if (!event) {
      return res.status(404).json({ error: 'Event nicht gefunden' });
    }

    const safeUserId = await ensureAuthenticatedEventUser(req, userId);
    const item = await changeParticipation(prisma, {
      eventId, userId: safeUserId,
      authorize: async (transaction, lockedEvent, current) => {
        await authorizeEventParticipation(transaction, lockedEvent, safeUserId, current);
      },
    });
    return res.status(201).json({ item: mapParticipationRecordToApiItem(item) });
  } catch (error) {
    return res.status(error.httpStatus || 503).json({ error: error.message, route: 'POST /events/participations' });
  }
});

async function authorizeEventParticipation(transaction, event, userId, current) {
  if (userId && event.hosterId === userId) return;
  let allowed = event.visibility == null || event.visibility === 'publicNearby' || event.hosterId === userId;
  if (event.visibility === 'inviteOnly') allowed = event.hosterId === userId || current != null;
  if (event.visibility === 'familyCircle') {
    allowed = Boolean(await transaction.familyRequest.findFirst({ where: {
      status: 'accepted', OR: [
        { fromUserId: userId, toUserId: event.hosterId },
        { fromUserId: event.hosterId, toUserId: userId },
      ],
    } }));
  }
  if (!allowed) {
    const error = new Error('Event is not accessible'); error.httpStatus = 403; throw error;
  }
}

app.put('/events/participations/withdraw', async (req, res) => {
  const { eventId, userId } = req.body || {};
  if (!req.firebaseUid) return res.status(401).json({ error: 'Firebase sign-in required' });
  if (req.firebaseUid !== userId) return res.status(403).json({ error: 'Own account only' });
  if (!eventId) return res.status(400).json({ error: 'eventId required' });
  try {
    const item = await changeParticipation(prisma, { eventId, userId, action: 'withdraw' });
    return res.json({ item: item ? mapParticipationRecordToApiItem(item) : null, success: true });
  } catch (error) {
    return res.status(error.httpStatus || 503).json({ error: error.message });
  }
});

app.put('/events/participations/:id/respond', async (req, res) => {
  if (!req.firebaseUid) return res.status(401).json({ error: 'Firebase sign-in required' });
  if (typeof req.body.accept !== 'boolean') return res.status(400).json({ error: 'accept must be boolean' });
  try {
    const current = await prisma.eventParticipation.findUnique({ where: { id: req.params.id } });
    if (!current) {
      return res.status(404).json({ error: 'Teilnahme nicht gefunden' });
    }

    const updated = await changeParticipation(prisma, {
      eventId: current.eventId, userId: current.userId,
      action: req.body.accept ? 'approve' : 'decline',
      authorize: async (_transaction, event) => {
        if (event.hosterId !== req.firebaseUid) {
          const error = new Error('Host only'); error.httpStatus = 403; throw error;
        }
      },
    });
    return res.json({ item: mapParticipationRecordToApiItem(updated) });
  } catch (error) {
    return res.status(error.httpStatus || 503).json({ error: error.message });
  }
});

app.get('/events/:id/participations/approved', async (req, res) => {
  try {
    const event = await prisma.event.findUnique({ where: { id: req.params.id } });
    if (!event) return res.status(404).json({ error: 'Event not found' });
    const current = req.firebaseUid ? await prisma.eventParticipation.findUnique({
      where: { eventId_userId: { eventId: event.id, userId: req.firebaseUid } },
    }) : null;
    await authorizeEventParticipation(prisma, event, req.firebaseUid, current);
    if (event.participationMode === 'interest') return res.json({ items: [] });
    const items = await prisma.eventParticipation.findMany({
      where: { eventId: req.params.id, status: { in: CONFIRMED } },
      orderBy: { createdAt: 'desc' },
    });
    return res.json({ items: items.map(mapParticipationRecordToApiItem) });
  } catch (error) {
    if (error.httpStatus) return res.status(error.httpStatus).json({ error: error.message });
    if (respondWithStrictPersistenceError(res, 'GET /events/:id/participations/approved', error)) {
      return;
    }
    const items = eventParticipations.filter(
      item => item.eventId === req.params.id && item.status === 'approved',
    );
    return res.json({ items });
  }
});

// 17. Event chat: authorization and private messages fail closed on database errors.
async function authorizeEventChat(req, res, eventId, { moderatorOnly = false, accessProbe = false } = {}) {
  try {
    const event = await prisma.event.findUnique({ where: { id: eventId } });
    if (!event) {
      res.status(404).json({ error: 'Event not found' });
      return null;
    }
    const isModerator = event.hosterId === req.firebaseUid || adminUserIds.has(req.firebaseUid);
    if (moderatorOnly && !isModerator) {
      res.status(403).json({ error: 'Event moderator required' });
      return null;
    }
    const participation = isModerator ? null : await prisma.eventParticipation.findFirst({
      where: { eventId, userId: req.firebaseUid, status: { in: CONFIRMED } },
    });
    const hasAccess = isModerator || Boolean(participation);
    if (!hasAccess && !accessProbe) {
      res.status(403).json({ error: 'Confirmed event participation required' });
      return null;
    }
    return { event, isModerator, hasAccess };
  } catch (error) {
    respondChatPersistenceError(res, 'Event chat authorization', error);
    return null;
  }
}

app.get('/events/:id/chat/messages', requireVerifiedUser, async (req, res) => {
  if (!await authorizeEventChat(req, res, req.params.id)) return;
  try {
    const chat = await prisma.eventChat.findUnique({
      where: { eventId: req.params.id },
      include: {
        event: { select: { hosterId: true } },
        messages: {
          include: { author: true },
          orderBy: { createdAt: 'asc' },
        },
      },
    });

    if (!chat) {
      return res.json({ items: [] });
    }

    const items = chat.messages.map(message => ({
      id: message.id,
      eventId: req.params.id,
      userId: message.authorId,
      userName: [message.author.firstName, message.author.lastName].filter(Boolean).join(' ') || message.authorId,
      userAvatarUrl: message.author.avatar || '',
      content: message.content,
      timestamp: message.createdAt,
      isHost: message.authorId === chat.event.hosterId,
    }));

    return res.json({ items });
  } catch (error) {
    return respondChatPersistenceError(res, 'GET /events/:id/chat/messages', error);
  }
});

app.post('/events/:id/chat/messages', requireVerifiedUser, async (req, res) => {
  const eventId = req.params.id;
  const access = await authorizeEventChat(req, res, eventId);
  if (!access) return;

  try {
    const authorId = await ensureAuthenticatedEventUser(req, req.firebaseUid);
    const chat = await ensureEventChatRecord(eventId);
    if (!chat) {
      return res.status(404).json({ error: 'Event nicht gefunden' });
    }

    const message = await prisma.message.create({
      data: {
        chatId: chat.id,
        authorId,
        content: (req.body.content || '').toString(),
        attachmentUrl: (req.body.userAvatarUrl || '').toString(),
      },
      include: {
        author: true,
      },
    });

    const item = {
      id: message.id,
      eventId,
      userId: message.authorId,
      userName: [message.author.firstName, message.author.lastName].filter(Boolean).join(' ') || message.authorId,
      userAvatarUrl: message.author.avatar || req.body.userAvatarUrl || '',
      content: message.content,
      timestamp: message.createdAt,
      isHost: message.authorId === access.event.hosterId,
    };

    return res.status(201).json({ item });
  } catch (error) {
    return respondChatPersistenceError(res, 'POST /events/:id/chat/messages', error);
  }
});

app.delete('/events/:eventId/chat/messages/:messageId', requireVerifiedUser, async (req, res) => {
  const access = await authorizeEventChat(req, res, req.params.eventId);
  if (!access) return;
  try {
    const message = await prisma.message.findUnique({
      where: { id: req.params.messageId },
      include: { chat: true },
    });
    if (!message || message.chat.eventId !== req.params.eventId) {
      return res.status(404).json({ error: 'Nachricht nicht gefunden' });
    }
    if (!access.isModerator && message.authorId !== req.firebaseUid) {
      return res.status(403).json({ error: 'Only the author or event moderator may delete a message' });
    }

    await prisma.message.delete({ where: { id: req.params.messageId } });
    return res.status(204).send();
  } catch (error) {
    return respondChatPersistenceError(res, 'DELETE /events/:eventId/chat/messages/:messageId', error);
  }
});

app.post('/events/:id/chat/reports', requireVerifiedUser, async (req, res) => {
  if (!requireActorClaims(req, res, [req.body.reporterId])) return;
  if (!await authorizeEventChat(req, res, req.params.id)) return;
  try {
    const chat = await ensureEventChatRecord(req.params.id);
    if (!chat) {
      return res.status(404).json({ error: 'Event nicht gefunden' });
    }

    const messageId = (req.body.reportedMessageId || '').toString();
    const message = await prisma.message.findUnique({ where: { id: messageId } });
    if (!message || message.chatId !== chat.id) {
      return res.status(404).json({ error: 'Nachricht nicht gefunden' });
    }

    const reporterId = await ensureAuthenticatedEventUser(req, req.firebaseUid);

    const report = await prisma.chatReport.create({
      data: {
        chatId: chat.id,
        messageId,
        reportedById: reporterId,
        reason: (req.body.reason || 'other').toString(),
        details: req.body.description || null,
      },
    });

    return res.status(201).json({
      item: {
        id: report.id,
        eventId: req.params.id,
        reportedMessageId: report.messageId,
        reporterId: report.reportedById,
        reason: report.reason,
        description: report.details,
        reportedAt: report.createdAt,
      },
    });
  } catch (error) {
    return respondChatPersistenceError(res, 'POST /events/:id/chat/reports', error);
  }
});

app.get('/events/:id/chat/reports', requireVerifiedUser, async (req, res) => {
  if (!await authorizeEventChat(req, res, req.params.id, { moderatorOnly: true })) return;
  try {
    const chat = await prisma.eventChat.findUnique({ where: { eventId: req.params.id } });
    if (!chat) {
      return res.json({ items: [] });
    }

    const reports = await prisma.chatReport.findMany({
      where: { chatId: chat.id },
      orderBy: { createdAt: 'desc' },
    });

    const items = reports.map(report => ({
      id: report.id,
      eventId: req.params.id,
      reportedMessageId: report.messageId,
      reporterId: report.reportedById,
      reason: report.reason,
      description: report.details,
      reportedAt: report.createdAt,
    }));
    return res.json({ items });
  } catch (error) {
    return respondChatPersistenceError(res, 'GET /events/:id/chat/reports', error);
  }
});

app.get('/events/:id/chat/access', requireVerifiedUser, async (req, res) => {
  const access = await authorizeEventChat(req, res, req.params.id, { accessProbe: true });
  if (!access) return;
  if (req.query.hosterId && req.query.hosterId !== access.event.hosterId) {
    return res.status(403).json({ error: 'Host identity does not match the event' });
  }
  return res.json({ hasAccess: access.hasAccess });
});

// 18. Payments
app.post('/payments/stripe/initiate', requireVerifiedUser, async (req, res) => {
  try {
    assertPaymentActor(req);
    if (!stripe) throw paymentError(503, 'Stripe ist nicht konfiguriert');
    const body = req.body || {};
    const context = await ensurePaymentContext(body.eventId, body.hosterId, req.firebaseUid, body);
    // Persist payer and immutable price before exposing any payable provider intent.
    const order = await prisma.paymentTransaction.create({
      data: {
        eventId: context.eventId,
        userId: req.firebaseUid,
        amount: context.amount,
        currency: context.currency.toUpperCase(),
        stripePaymentIntentId: `uninitialized_${crypto.randomUUID()}`,
        idempotencyKey: `stripe-order:${crypto.randomUUID()}`,
        status: 'pending',
        auditDetails: {
          bindingVersion: 1,
          payerUid: req.firebaseUid,
          hosterId: context.hosterId,
          paymentMethod: 'stripe',
          mode: 'real_stripe',
        },
      },
    });
    const intent = await stripe.paymentIntents.create({
      amount: context.amountMinor,
      currency: context.currency,
      description: `Parentpeak Event ${context.eventId}`,
      metadata: {
        orderId: order.id,
        payerUid: req.firebaseUid,
        eventId: context.eventId,
        hosterId: context.hosterId,
      },
    }, { idempotencyKey: order.idempotencyKey });
    const stored = await prisma.paymentTransaction.update({
      where: { id: order.id },
      data: { stripePaymentIntentId: intent.id },
    });
    return res.status(201).json({
      item: {
        ...mapPaymentRecordToApiItem(stored),
        provider: 'stripe',
        clientSecret: intent.client_secret,
      },
    });
  } catch (error) {
    return respondPaymentError(res, error);
  }
});

// Get Stripe PaymentIntent status (for payment confirmation)
app.get('/payments/stripe/confirm/:intentId', requireVerifiedUser, async (req, res) => {
  try {
    assertPaymentActor(req);
    const record = await findPaymentRecord({ stripePaymentIntentId: req.params.intentId });
    assertPaymentOwner(record, req.firebaseUid, { payerOnly: true });
    const { item } = await syncStripePaymentRecord(record);
    return res.json({ item });
  } catch (error) {
    return respondPaymentError(res, error);
  }
});

app.post('/payments/paypal/initiate', requireVerifiedUser, (req, res) => {
  try {
    assertPaymentActor(req);
    return res.status(503).json({ error: 'PayPal-Providerpruefung ist nicht konfiguriert' });
  } catch (error) {
    return respondPaymentError(res, error);
  }
});

app.post('/payments/confirm', requireVerifiedUser, async (req, res) => {
  try {
    assertPaymentActor(req);
    const body = req.body || {};
    if (body.paymentMethod && body.paymentMethod !== 'stripe') {
      throw paymentError(503, 'Providerpruefung fuer diese Zahlungsart nicht unterstuetzt');
    }
    const reference = body.stripePaymentIntentId || body.providerTransactionRef;
    if (typeof reference !== 'string' || !/^pi_[A-Za-z0-9]+$/.test(reference)) {
      throw paymentError(400, 'Stripe PaymentIntent-ID erforderlich, kein Client-Secret');
    }
    if (body.providerTransactionRef && body.providerTransactionRef !== reference) {
      throw paymentError(409, 'Widerspruechliche Providerreferenzen');
    }
    const record = await findPaymentRecord({ stripePaymentIntentId: reference });
    assertPaymentOwner(record, req.firebaseUid, { payerOnly: true });
    if ((body.eventId !== undefined && body.eventId !== record.eventId) ||
        (body.hosterId !== undefined && body.hosterId !== paymentHost(record))) {
      throw paymentError(403, 'Auftragskontext stimmt nicht ueberein');
    }
    if ((body.amount !== undefined && Number(body.amount) !== Number(record.amount)) ||
        (body.currency !== undefined && String(body.currency).toUpperCase() !== record.currency.toUpperCase())) {
      throw paymentError(409, 'Auftragspreis stimmt nicht ueberein');
    }
    const { item } = await syncStripePaymentRecord(record);
    return res.json({ item });
  } catch (error) {
    return respondPaymentError(res, error);
  }
});

app.post('/payments/provider-events', requireVerifiedUser, async (req, res) => {
  try {
    assertPaymentActor(req);
    return res.status(403).json({ error: 'Client Provider-Events sind deaktiviert; signierten Webhook verwenden' });
  } catch (error) {
    return respondPaymentError(res, error);
  }
});

app.get('/payments/transactions', requireVerifiedUser, async (req, res) => {
  try {
    assertPaymentActor(req);
    const hosterId = (req.query.hosterId || '').toString().trim();
    if (hosterId && hosterId !== req.firebaseUid) {
      throw paymentError(403, 'Nur eigene Host-Transaktionen erlaubt');
    }
    const items = await findPaymentRecords({
      where: hosterId ? {
        OR: [
          { auditDetails: { path: ['hosterId'], equals: req.firebaseUid } },
          { userId: req.firebaseUid },
        ],
      } : { OR: [
        { userId: req.firebaseUid },
        { auditDetails: { path: ['hosterId'], equals: req.firebaseUid } },
      ] },
      orderBy: { createdAt: 'desc' },
    });
    return res.json({ items: items.filter(item =>
      hosterId ? paymentHost(item) === req.firebaseUid :
        paymentPayer(item) === req.firebaseUid || paymentHost(item) === req.firebaseUid,
    ).map(mapPaymentRecordToApiItem) });
  } catch (error) {
    return respondPaymentError(res, error);
  }
});

app.get('/payments/transactions/:id', requireVerifiedUser, async (req, res) => {
  try {
    assertPaymentActor(req);
    const item = await findPaymentRecord({ id: req.params.id });
    assertPaymentOwner(item, req.firebaseUid);
    if (paymentPayer(item) && ['pending', 'initiated'].includes(normalizeStoredPaymentStatus(item.status))) {
      const result = await syncStripePaymentRecord(item);
      return res.json({ item: result.item });
    }
    return res.json({ item: mapPaymentRecordToApiItem(item) });
  } catch (error) {
    return respondPaymentError(res, error);
  }
});

app.get('/payments/host/:hosterId', requireVerifiedUser, async (req, res) => {
  try {
    assertPaymentActor(req);
    const hosterId = (req.params.hosterId || '').toString().trim();
    if (hosterId !== req.firebaseUid) throw paymentError(403, 'Nur eigene Host-Transaktionen erlaubt');
    const items = await findPaymentRecords({
      where: {
        OR: [
          { userId: hosterId },
          { auditDetails: { path: ['hosterId'], equals: hosterId } },
        ],
      },
      orderBy: { createdAt: 'desc' },
    });
    return res.json({ items: items.filter(item => paymentHost(item) === req.firebaseUid).map(mapPaymentRecordToApiItem) });
  } catch (error) {
    return respondPaymentError(res, error);
  }
});

app.post('/payments/transactions/:id/refund', requireVerifiedUser, async (req, res) => {
  try {
    assertPaymentActor(req);
    const current = await findPaymentRecord({ id: req.params.id });
    assertPaymentOwner(current, req.firebaseUid, { hostOnly: true });
    const { status } = await verifyStripePaymentRecord(current);
    if (status === 'refunded') {
      const { item } = await persistVerifiedPaymentStatus(current, status, 'stripe_api');
      return res.json({ item });
    }
    if (status !== 'completed' || normalizeStoredPaymentStatus(current.status) !== 'completed') {
      throw paymentError(409, 'Rueckerstattung nur fuer verifiziert abgeschlossene Zahlungen erlaubt');
    }
    const refund = await stripe.refunds.create({
      payment_intent: current.stripePaymentIntentId,
      amount: Math.round(Number(current.amount) * 100),
    }, { idempotencyKey: `payment-refund:${current.id}` });
    if (refund.payment_intent !== current.stripePaymentIntentId ||
        refund.amount !== Math.round(Number(current.amount) * 100) ||
        refund.currency !== String(current.currency).toLowerCase()) {
      throw paymentError(409, 'Rueckerstattungsnachweis stimmt nicht mit dem Auftrag ueberein');
    }
    if (refund.status !== 'succeeded') {
      throw paymentError(409, 'Rueckerstattung vom Provider noch nicht erfolgreich bestaetigt');
    }
    const { item } = await persistVerifiedPaymentStatus(current, 'refunded', 'stripe_refund_api');
    return res.json({ item });
  } catch (error) {
    return respondPaymentError(res, error);
  }
});

app.post('/payments/transactions/:id/status', requireVerifiedUser, async (req, res) => {
  try {
    assertPaymentActor(req);
    const current = await findPaymentRecord({ id: req.params.id });
    assertPaymentOwner(current, req.firebaseUid);
    const { item } = await syncStripePaymentRecord(current);
    return res.json({ item });
  } catch (error) {
    return respondPaymentError(res, error);
  }
});

// Health Check
app.get('/release/readiness', async (req, res) => {
  res.setHeader('Cache-Control', 'no-store');
  try {
    const { releaseReadiness } = require('./release_readiness');
    const evidence = await releaseReadiness(prisma, process.env.RENDER_GIT_COMMIT);
    res.json(evidence);
  } catch (error) {
    console.error('Release readiness failed:', error.name, error.code || 'unavailable');
    res.status(503).json({ status: 'not-ready' });
  }
});

app.get('/health', (req, res) => {
  res.json({ status: 'OK', message: 'Parentpeak Backend läuft!' });
});

// ── Admin: Database Migrations ───────────────────────────────────────────────
app.post('/admin/migrate-db', requireAdmin, async (req, res) => {

  try {
    // Drop foreign key constraint for Event if it exists
    await prisma.$executeRawUnsafe(`
      ALTER TABLE "Event" DROP CONSTRAINT IF EXISTS "Event_hosterId_fkey";
    `);

    // Drop foreign key constraint for TreasureItem userId if it exists
    await prisma.$executeRawUnsafe(`
      ALTER TABLE "TreasureItem" DROP CONSTRAINT IF EXISTS "TreasureItem_userId_fkey";
    `);

    // Create TreasureItem table if it doesn't exist
    await prisma.$executeRawUnsafe(`
      CREATE TABLE IF NOT EXISTS "TreasureItem" (
        "id" TEXT NOT NULL PRIMARY KEY,
        "userId" TEXT NOT NULL,
        "familyId" TEXT,
        "title" TEXT NOT NULL,
        "description" TEXT,
        "category" TEXT NOT NULL DEFAULT 'other',
        "subcategory" TEXT,
        "condition" TEXT NOT NULL DEFAULT 'good',
        "location" TEXT,
        "latitude" DOUBLE PRECISION,
        "longitude" DOUBLE PRECISION,
        "visibility" TEXT NOT NULL DEFAULT 'nearby',
        "shareRadiusKm" DOUBLE PRECISION NOT NULL DEFAULT 10,
        "isFree" BOOLEAN NOT NULL DEFAULT true,
        "price" DECIMAL(10,2),
        "currency" TEXT NOT NULL DEFAULT 'EUR',
        "photoUrl" TEXT,
        "photoUrls" TEXT[] DEFAULT ARRAY[]::TEXT[],
        "availableForPickup" BOOLEAN NOT NULL DEFAULT true,
        "pickupLocation" TEXT,
        "pickupSlots" TEXT[] DEFAULT ARRAY[]::TEXT[],
        "status" TEXT NOT NULL DEFAULT 'available',
        "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        "expiresAt" TIMESTAMP(3),
        "updatedAt" TIMESTAMP(3) NOT NULL,
        "views" INTEGER NOT NULL DEFAULT 0,
        "rating" DOUBLE PRECISION NOT NULL DEFAULT 0,
        "ratingCount" INTEGER NOT NULL DEFAULT 0,
        CONSTRAINT "TreasureItem_familyId_fkey" FOREIGN KEY ("familyId") REFERENCES "Family" ("id") ON DELETE SET NULL
      );
    `);

    // Create TreasureRating table if it doesn't exist
    await prisma.$executeRawUnsafe(`
      CREATE TABLE IF NOT EXISTS "TreasureRating" (
        "id" TEXT NOT NULL PRIMARY KEY,
        "treasureId" TEXT NOT NULL,
        "fromUserId" TEXT NOT NULL,
        "rating" INTEGER NOT NULL,
        "comment" TEXT,
        "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        CONSTRAINT "TreasureRating_treasureId_fkey" FOREIGN KEY ("treasureId") REFERENCES "TreasureItem" ("id") ON DELETE CASCADE,
        CONSTRAINT "TreasureRating_fromUserId_fkey" FOREIGN KEY ("fromUserId") REFERENCES "User" ("id") ON DELETE CASCADE
      );
    `);

    // Create TreasureHandover table if it doesn't exist
    await prisma.$executeRawUnsafe(`
      CREATE TABLE IF NOT EXISTS "TreasureHandover" (
        "id" TEXT NOT NULL PRIMARY KEY,
        "treasureId" TEXT NOT NULL,
        "requesterId" TEXT NOT NULL,
        "status" TEXT NOT NULL DEFAULT 'pending',
        "scheduledTime" TIMESTAMP(3),
        "location" TEXT,
        "notes" TEXT,
        "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        "updatedAt" TIMESTAMP(3) NOT NULL,
        CONSTRAINT "TreasureHandover_treasureId_fkey" FOREIGN KEY ("treasureId") REFERENCES "TreasureItem" ("id") ON DELETE CASCADE,
        CONSTRAINT "TreasureHandover_requesterId_fkey" FOREIGN KEY ("requesterId") REFERENCES "User" ("id") ON DELETE CASCADE
      );
    `);

    // Create TreasureReport table if it doesn't exist
    await prisma.$executeRawUnsafe(`
      CREATE TABLE IF NOT EXISTS "TreasureReport" (
        "id" TEXT NOT NULL PRIMARY KEY,
        "treasureId" TEXT NOT NULL,
        "reporterUserId" TEXT NOT NULL,
        "reason" TEXT NOT NULL,
        "note" TEXT,
        "status" TEXT NOT NULL DEFAULT 'pending',
        "moderatorId" TEXT,
        "moderatorNote" TEXT,
        "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        "resolvedAt" TIMESTAMP(3),
        "updatedAt" TIMESTAMP(3) NOT NULL,
        CONSTRAINT "TreasureReport_treasureId_fkey" FOREIGN KEY ("treasureId") REFERENCES "TreasureItem" ("id") ON DELETE CASCADE
      );
    `);

    // Create indexes if they don't exist
    await prisma.$executeRawUnsafe(`
      CREATE INDEX IF NOT EXISTS "TreasureItem_userId_idx" ON "TreasureItem"("userId");
      CREATE INDEX IF NOT EXISTS "TreasureItem_status_idx" ON "TreasureItem"("status");
      CREATE INDEX IF NOT EXISTS "TreasureItem_visibility_idx" ON "TreasureItem"("visibility");
      CREATE INDEX IF NOT EXISTS "TreasureItem_createdAt_idx" ON "TreasureItem"("createdAt");
      CREATE INDEX IF NOT EXISTS "TreasureItem_category_idx" ON "TreasureItem"("category");
      CREATE INDEX IF NOT EXISTS "TreasureReport_treasureId_idx" ON "TreasureReport"("treasureId");
      CREATE INDEX IF NOT EXISTS "TreasureReport_reporterUserId_idx" ON "TreasureReport"("reporterUserId");
      CREATE INDEX IF NOT EXISTS "TreasureReport_status_idx" ON "TreasureReport"("status");
      CREATE INDEX IF NOT EXISTS "TreasureReport_createdAt_idx" ON "TreasureReport"("createdAt");
    `);

    // Create FoodOfferComment table if it doesn't exist
    await prisma.$executeRawUnsafe(`
      CREATE TABLE IF NOT EXISTS "FoodOfferComment" (
        "id" TEXT NOT NULL PRIMARY KEY,
        "recipeId" TEXT NOT NULL,
        "userId" TEXT NOT NULL,
        "text" TEXT NOT NULL,
        "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        CONSTRAINT "FoodOfferComment_recipeId_fkey" FOREIGN KEY ("recipeId") REFERENCES "SharedRecipe" ("id") ON DELETE CASCADE
      );
    `);

    // Create FoodOfferReservation table if it doesn't exist
    await prisma.$executeRawUnsafe(`
      CREATE TABLE IF NOT EXISTS "FoodOfferReservation" (
        "id" TEXT NOT NULL PRIMARY KEY,
        "recipeId" TEXT NOT NULL,
        "userId" TEXT NOT NULL,
        "portions" INTEGER NOT NULL DEFAULT 1,
        "completedAt" TIMESTAMP(3),
        "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        CONSTRAINT "FoodOfferReservation_recipeId_fkey" FOREIGN KEY ("recipeId") REFERENCES "SharedRecipe" ("id") ON DELETE CASCADE
      );
    `);

    await prisma.$executeRawUnsafe(`
      ALTER TABLE "FoodOfferReservation"
      ADD COLUMN IF NOT EXISTS "completedAt" TIMESTAMP(3);
    `);

    await prisma.$executeRawUnsafe(`
      CREATE UNIQUE INDEX IF NOT EXISTS "FoodOfferReservation_recipeId_userId_key"
      ON "FoodOfferReservation"("recipeId", "userId");
      CREATE INDEX IF NOT EXISTS "FoodOfferComment_recipeId_idx" ON "FoodOfferComment"("recipeId");
      CREATE INDEX IF NOT EXISTS "FoodOfferComment_createdAt_idx" ON "FoodOfferComment"("createdAt");
      CREATE INDEX IF NOT EXISTS "FoodOfferReservation_recipeId_idx" ON "FoodOfferReservation"("recipeId");
      CREATE INDEX IF NOT EXISTS "FoodOfferReservation_userId_idx" ON "FoodOfferReservation"("userId");
    `);

    res.json({ success: true, message: 'Database migrated successfully (Events + Treasures + Reports + Food Offers)' });
  } catch (err) {
    console.error('Migration error:', err.message);
    res.status(500).json({ error: `Migration failed: ${err.message}` });
  }
});

// ── FCM Device Tokens ────────────────────────────────────────────────────────
const deviceTokens = new Map(); // userId -> Set<token>

app.post('/devices/register-token', async (req, res) => {
  const userId = (req.body.userId || '').toString().trim();
  const token = (req.body.token || '').toString().trim();
  const platform = (req.body.platform || 'unknown').toString().trim();

  if (!userId || !token) {
    return res.status(400).json({ error: 'userId und token sind erforderlich' });
  }
  if (!(await authorizeProfileOwner(req, res, userId))) return;
  for (const [owner, tokens] of deviceTokens) {
    if (owner !== userId && tokens.has(token)) {
      return res.status(409).json({ error: 'Device token already bound to another account' });
    }
  }

  const existing = deviceTokens.get(userId) || new Set();
  existing.add(token);
  deviceTokens.set(userId, existing);

  // Persist in DB if Prisma is available.
  try {
    await ensureBackendUser(userId, userId);
    // Upsert a marker in a custom field via raw SQL to avoid schema migration dependency.
    // The token set lives in-memory and is restored on restart via DB if schema has a DeviceToken table.
    // For now in-memory is the source of truth; schema migration is a separate step.
  } catch (error) {
    console.warn('Device token user persistence failed; token remains in memory');
  }

  return res.json({ ok: true, userId, platform, tokenCount: existing.size });
});

app.delete('/devices/register-token', async (req, res) => {
  const userId = (req.body.userId || '').toString().trim();
  const token = (req.body.token || '').toString().trim();

  if (!userId || !token) {
    return res.status(400).json({ error: 'userId und token sind erforderlich' });
  }
  if (!(await authorizeProfileOwner(req, res, userId))) return;

  const existing = deviceTokens.get(userId);
  if (existing) {
    existing.delete(token);
    if (existing.size === 0) deviceTokens.delete(userId);
  }

  return res.json({ ok: true });
});

// Internal helper to send an FCM push to all tokens of a user.
async function sendPushToUser(userId, { title, body, data = {} }) {
  if (!firebaseAdmin) return;
  const tokens = [...(deviceTokens.get(userId) || [])];
  if (tokens.length === 0) return;

  try {
    const result = await firebaseAdmin.messaging().sendEachForMulticast({
      tokens,
      notification: { title, body },
      data: Object.fromEntries(
        Object.entries({ ...data, accountUserId: userId }).map(([k, v]) => [k, String(v)]),
      ),
    });

    // Clean up invalid tokens.
    result.responses.forEach((resp, idx) => {
      if (!resp.success) {
        const code = resp.error?.code;
        if (
          code === 'messaging/invalid-registration-token' ||
          code === 'messaging/registration-token-not-registered'
        ) {
          const tokenSet = deviceTokens.get(userId);
          if (tokenSet) tokenSet.delete(tokens[idx]);
        }
      }
    });
  } catch (err) {
    console.error('FCM sendPushToUser failed:', err?.message || err);
  }
}

// ── Firebase Custom Auth Action Handler ─────────────────────────────────────
// Serves the branded German auth-action page. Firebase sends users here for
// password reset, email verification and email-change recovery.
// Set this URL in Firebase Console → Auth → Settings → Email action handler URL:
//   https://parentpeak.onrender.com/auth/action
const publicDir = path.join(__dirname, 'public');
if (!fs.existsSync(publicDir)) fs.mkdirSync(publicDir, { recursive: true });
app.get('/auth/action', (_req, res) => {
  res.sendFile(path.join(publicDir, 'auth-action.html'));
});

// ── Branded Email Service (modern alternative to Firebase email templates) ───
// Uses nodemailer + Firebase Admin SDK to send fully custom German HTML emails.
// Required env vars: SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS
// Optional: SMTP_FROM_NAME (default: "ParentPeak"), SMTP_FROM_EMAIL
// The custom auth-action.html page handles the user interaction after click.

const ACTION_HANDLER_BASE = process.env.AUTH_ACTION_URL || 'https://parentpeak.onrender.com/auth/action';
const SMTP_FROM_NAME  = process.env.SMTP_FROM_NAME  || 'ParentPeak';
const SMTP_FROM_EMAIL = process.env.SMTP_FROM_EMAIL || (process.env.SMTP_USER || 'noreply@parentpeak.app');

/** Lazy-create the nodemailer transporter (returns null if SMTP not configured) */
function createMailTransporter() {
  const host = process.env.SMTP_HOST;
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;
  if (!host || !user || !pass) return null;
  return nodemailer.createTransport({
    host,
    port: parseInt(process.env.SMTP_PORT || '587', 10),
    secure: process.env.SMTP_SECURE === 'true', // true for port 465
    auth: { user, pass },
    tls: { rejectUnauthorized: true },
  });
}

/**
 * sendEmail({ to, subject, html })
 * Priority: 1) Resend API  2) SMTP/nodemailer  3) returns false (Firebase fallback)
 */
async function sendEmail({ to, subject, html }) {
  // ── 1. Resend (recommended: modern API, excellent deliverability, free 3k/mo) ──
  const resendKey = process.env.RESEND_API_KEY;
  if (resendKey) {
    const resend = new Resend(resendKey);
    const { error } = await resend.emails.send({
      from: `${SMTP_FROM_NAME} <${SMTP_FROM_EMAIL}>`,
      to,
      subject,
      html,
    });
    if (error) throw new Error(`Resend error: ${error.message}`);
    return true;
  }

  // ── 2. SMTP / nodemailer (classic: Gmail, SendGrid, Mailgun, etc.) ─────────
  const transporter = createMailTransporter();
  if (transporter) {
    await transporter.sendMail({
      from: `"${SMTP_FROM_NAME}" <${SMTP_FROM_EMAIL}>`,
      to,
      subject,
      html,
    });
    return true;
  }

  // ── 3. No email provider configured ───────────────────────────────────────
  console.warn('⚠️ Email provider not configured. Set RESEND_API_KEY or SMTP_HOST/SMTP_USER/SMTP_PASS.');
  return false;
}

/** Build a custom action URL pointing to our handler, preserving oobCode + mode */
function buildCustomActionUrl(firebaseLink, mode) {
  try {
    const u = new URL(firebaseLink);
    const oobCode   = u.searchParams.get('oobCode');
    const apiKey    = u.searchParams.get('apiKey');
    const continueUrl = u.searchParams.get('continueUrl');
    const custom = new URL(ACTION_HANDLER_BASE);
    custom.searchParams.set('mode', mode);
    if (oobCode)    custom.searchParams.set('oobCode', oobCode);
    if (apiKey)     custom.searchParams.set('apiKey', apiKey);
    if (continueUrl) custom.searchParams.set('continueUrl', continueUrl);
    return custom.toString();
  } catch {
    return firebaseLink; // fallback to original if URL parsing fails
  }
}

const EMAIL_STYLE = `
  font-family:-apple-system,Arial,sans-serif;max-width:520px;margin:0 auto;
  padding:32px 24px;background:#ffffff;color:#2D3748;
`;

function buildPasswordResetEmail(actionUrl) {
  return `
<div style="${EMAIL_STYLE}">
  <div style="font-size:36px;margin-bottom:12px;text-align:center;">🌿</div>
  <h2 style="font-size:22px;font-weight:800;color:#2D3748;margin:0 0 8px 0;">Passwort zurücksetzen</h2>
  <p style="font-size:15px;color:#718096;margin:0 0 20px 0;">
    Hallo!<br><br>
    Kein Stress — das passiert den Besten. 😊<br>
    Klick auf den Button um ein neues Passwort für dein <strong>ParentPeak</strong>-Konto festzulegen:
  </p>
  <a href="${actionUrl}" style="display:inline-block;background:#4CAF50;color:#ffffff;text-decoration:none;padding:14px 28px;border-radius:12px;font-weight:700;font-size:15px;">
    Neues Passwort festlegen →
  </a>
  <p style="font-size:13px;color:#A0AEC0;margin:20px 0 8px 0;">⏱ Der Link ist <strong>1 Stunde</strong> gültig.</p>
  <p style="font-size:13px;color:#A0AEC0;margin:0 0 24px 0;">
    Falls du diese Anfrage <strong>nicht</strong> gestellt hast, kannst du diese E-Mail ignorieren. Dein Konto bleibt sicher.
  </p>
  <hr style="border:none;border-top:1px solid #EDF2F7;margin:24px 0;">
  <p style="font-size:12px;color:#CBD5E0;margin:0;">
    Liebe Grüße,<br>
    <strong style="color:#4CAF50;">Dein ParentPeak-Team 💚</strong><br>
    <em>Dein digitaler Begleiter für Eltern</em>
  </p>
</div>`;
}

function buildVerificationEmail(displayName, actionUrl) {
  const name = displayName || 'dort';
  return `
<div style="${EMAIL_STYLE}">
  <div style="font-size:36px;margin-bottom:12px;text-align:center;">🌿</div>
  <h2 style="font-size:22px;font-weight:800;color:#2D3748;margin:0 0 8px 0;">E-Mail-Adresse bestätigen</h2>
  <p style="font-size:15px;color:#718096;margin:0 0 20px 0;">
    Hallo ${name}! 🎉<br><br>
    Schön, dass du dabei bist. Bestätige jetzt deine E-Mail-Adresse:
  </p>
  <a href="${actionUrl}" style="display:inline-block;background:#4CAF50;color:#ffffff;text-decoration:none;padding:14px 28px;border-radius:12px;font-weight:700;font-size:15px;">
    E-Mail bestätigen →
  </a>
  <p style="font-size:13px;color:#A0AEC0;margin:20px 0 24px 0;">
    Falls du kein ParentPeak-Konto erstellt hast, kannst du diese E-Mail ignorieren.
  </p>
  <hr style="border:none;border-top:1px solid #EDF2F7;margin:24px 0;">
  <p style="font-size:12px;color:#CBD5E0;margin:0;">
    Herzlich willkommen,<br>
    <strong style="color:#4CAF50;">Dein ParentPeak-Team 💚</strong><br>
    <em>Dein digitaler Begleiter für Eltern</em>
  </p>
</div>`;
}

/**
 * POST /auth/send-password-reset
 * Body: { email: string }
 * Generates a Firebase password reset link via Admin SDK and sends it
 * through nodemailer with a fully branded German HTML email.
 * Always returns 200 to avoid leaking user existence.
 */
app.post('/auth/send-password-reset', async (req, res) => {
  const email = (req.body?.email || '').trim().toLowerCase();

  // Basic email format validation (prevents unnecessary Firebase calls)
  if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return res.status(400).json({ error: 'Ungültige E-Mail-Adresse' });
  }

  // Always 200 so callers can't enumerate users
  res.json({ success: true });

  // Async: generate link + send email (fire-and-forget after response)
  try {
    if (!firebaseAdmin) {
      console.warn('⚠️ /auth/send-password-reset: Firebase Admin nicht initialisiert');
      return;
    }

    const firebaseLink = await firebaseAdmin.auth().generatePasswordResetLink(email, {
      url: ACTION_HANDLER_BASE,
    });
    const actionUrl = buildCustomActionUrl(firebaseLink, 'resetPassword');

    const sent = await sendEmail({
      to: email,
      subject: 'Dein ParentPeak-Passwort zurücksetzen',
      html: buildPasswordResetEmail(actionUrl),
    });
    if (sent) {
      console.log(`✉️ Passwort-Reset E-Mail gesendet an ${email.slice(0, 3)}***`);
    }
  } catch (err) {
    // Don't expose errors — user is already told "success"
    if (err.code !== 'auth/user-not-found') {
      console.error('❌ Password reset email error:', err.message);
    }
  }
});

/**
 * POST /auth/send-verification-email
 * Body: { idToken: string }  (Firebase ID token of the signed-in user)
 * Generates an email verification link and sends branded German email.
 */
app.post('/auth/send-verification-email', async (req, res) => {
  const idToken = (req.body?.idToken || '').trim();
  if (!idToken) return res.status(400).json({ error: 'idToken erforderlich' });

  try {
    if (!firebaseAdmin) {
      return res.status(503).json({ error: 'Firebase Admin nicht verfügbar' });
    }
    const decoded = await firebaseAdmin.auth().verifyIdToken(idToken);
    if (decoded.email_verified) {
      return res.json({ success: true, already_verified: true });
    }

    const firebaseLink = await firebaseAdmin.auth().generateEmailVerificationLink(decoded.email, {
      url: ACTION_HANDLER_BASE,
    });
    const actionUrl   = buildCustomActionUrl(firebaseLink, 'verifyEmail');
    const displayName = decoded.name || '';

    await sendEmail({
      to: decoded.email,
      subject: 'Bestätige deine ParentPeak E-Mail-Adresse ✅',
      html: buildVerificationEmail(displayName, actionUrl),
    });

    console.log(`✉️ Verification E-Mail gesendet an ${decoded.email.slice(0, 3)}***`);
    res.json({ success: true });
  } catch (err) {
    console.error('❌ Verification email error:', err.message);
    res.status(500).json({ error: 'E-Mail konnte nicht gesendet werden' });
  }
});

// ── Image Upload ─────────────────────────────────────────────────────────────
app.use('/uploads', express.static(uploadsDir));

app.post('/uploads/image', (req, res) => {
  upload.single('image')(req, res, err => {
    if (err) {
      return res.status(400).json({ error: err.message || 'Bild-Upload fehlgeschlagen' });
    }

    if (!req.file) {
      return res.status(400).json({ error: 'Kein Bild empfangen' });
    }

    const publicBase = (process.env.PUBLIC_BASE_URL || '').trim().replace(/\/$/, '');
    const relPath = `/uploads/${req.file.filename}`;
    const url = publicBase ? `${publicBase}${relPath}` : relPath;

    return res.status(201).json({ url, filename: req.file.filename, size: req.file.size });
  });
});

// ============================================================================
// MEAL PLANNER / ESSENSPLANER ENDPOINTS
// ============================================================================

/**
 * GET /api/meal-plans/:familyId?date=YYYY-MM-DD
 * Hole Essensplan für einen bestimmten Tag einer Familie
 */
app.get('/api/meal-plans/:familyId', requireVerifiedUser, requireOwnFamily, async (req, res) => {
  const { date } = req.query;

  try {
    const familyId = assertOwnFamilyParam(req, req.params.familyId);
    if (!date) {
      return res.status(400).json({ error: 'date query parameter required' });
    }

    const targetDate = new Date(date);
    targetDate.setUTCHours(0, 0, 0, 0);

    const mealPlan = await prisma.mealPlan.findUnique({
      where: {
        familyId_date: {
          familyId,
          date: targetDate,
        },
      },
      include: {
        meals: {
          orderBy: { createdAt: 'asc' },
        },
      },
    });

    res.json(mealPlan || { familyId, date: targetDate, meals: [] });
  } catch (err) {
    return respondFamilyPersistenceError(res, 'GET /api/meal-plans/:familyId', err);
  }
});

/**
 * GET /api/meal-plans/:familyId/week?startDate=YYYY-MM-DD
 * Hole komplette Woche (7 Tage) für eine Familie
 */
app.get('/api/meal-plans/:familyId/week', requireVerifiedUser, requireOwnFamily, async (req, res) => {
  const { startDate } = req.query;

  try {
    const familyId = assertOwnFamilyParam(req, req.params.familyId);
    if (!startDate) {
      return res.status(400).json({ error: 'startDate query parameter required' });
    }

    const start = new Date(startDate);
    start.setUTCHours(0, 0, 0, 0);

    const end = new Date(start);
    end.setDate(end.getDate() + 7);

    const mealPlans = await prisma.mealPlan.findMany({
      where: {
        familyId,
        date: {
          gte: start,
          lt: end,
        },
      },
      include: {
        meals: {
          orderBy: { createdAt: 'asc' },
        },
      },
      orderBy: { date: 'asc' },
    });

    res.json(mealPlans);
  } catch (err) {
    return respondFamilyPersistenceError(res, 'GET /api/meal-plans/:familyId/week', err);
  }
});

/**
 * POST /api/meal-plans/:familyId
 * Erstelle oder aktualisiere Essensplan für einen Tag
 */
app.post('/api/meal-plans/:familyId', requireVerifiedUser, requireOwnFamily, async (req, res) => {
  const { date, meals } = req.body;

  try {
    const familyId = assertOwnFamilyParam(req, req.params.familyId);
    const targetDate = new Date(date);
    targetDate.setUTCHours(0, 0, 0, 0);

    // Replace in EINER Transaktion: alte Meals loeschen, Plan upserten, neue Meals
    // schreiben. Ein Fehler rollt alles zurueck, statt einen halb geleerten Plan
    // zu hinterlassen.
    const updated = await prisma.$transaction(async transaction => {
      await transaction.meal.deleteMany({
        where: {
          mealPlan: {
            familyId,
            date: targetDate,
          },
        },
      });

      const mealPlan = await transaction.mealPlan.upsert({
        where: {
          familyId_date: {
            familyId,
            date: targetDate,
          },
        },
        update: { updatedAt: new Date() },
        create: {
          familyId,
          date: targetDate,
        },
      });

      if (Array.isArray(meals) && meals.length > 0) {
        for (const meal of meals) {
          await transaction.meal.create({
            data: {
              mealPlanId: mealPlan.id,
              title: meal.title,
              type: meal.type,
              description: meal.description || null,
              ingredients: JSON.stringify(meal.ingredients || []),
            },
          });
        }
      }

      return transaction.mealPlan.findUnique({
        where: { id: mealPlan.id },
        include: {
          meals: {
            orderBy: { createdAt: 'asc' },
          },
        },
      });
    });

    res.status(201).json(updated);
  } catch (err) {
    return respondFamilyPersistenceError(res, 'POST /api/meal-plans/:familyId', err);
  }
});

/**
 * POST /api/meals/:mealPlanId
 * Füge einzelne Mahlzeit zum Essensplan hinzu
 */
app.post('/api/meals/:mealPlanId', requireVerifiedUser, requireOwnFamily, async (req, res) => {
  const { mealPlanId } = req.params;
  const { title, type, description, ingredients } = req.body;

  try {
    const meal = await prisma.$transaction(async transaction => {
      const plan = await transaction.mealPlan.findUnique({
        where: { id: mealPlanId },
        select: { id: true, familyId: true },
      });
      // Fremder/fehlender Plan: einheitlich 404, verraet keine Existenz.
      if (!plan || plan.familyId !== req.ownFamily.id) return null;
      return transaction.meal.create({
        data: {
          mealPlanId: plan.id,
          title,
          type,
          description: description || null,
          ingredients: JSON.stringify(ingredients || []),
        },
      });
    });

    if (!meal) return res.status(404).json({ error: 'Essensplan nicht gefunden' });
    res.status(201).json(meal);
  } catch (err) {
    return respondFamilyPersistenceError(res, 'POST /api/meals/:mealPlanId', err);
  }
});

/**
 * PUT /api/meals/:mealId
 * Aktualisiere eine Mahlzeit
 */
app.put('/api/meals/:mealId', requireVerifiedUser, requireOwnFamily, async (req, res) => {
  const { mealId } = req.params;
  const { title, type, description, ingredients } = req.body;

  try {
    const meal = await prisma.$transaction(async transaction => {
      const existing = await transaction.meal.findUnique({
        where: { id: mealId },
        select: { id: true, mealPlan: { select: { familyId: true } } },
      });
      // Autorisierung ueber meal.mealPlan.familyId; fremd/fehlend -> null -> 404.
      if (!existing || existing.mealPlan?.familyId !== req.ownFamily.id) return null;
      return transaction.meal.update({
        where: { id: mealId },
        data: {
          title,
          type,
          description: description || null,
          ingredients: JSON.stringify(ingredients || []),
          updatedAt: new Date(),
        },
      });
    });

    if (!meal) return res.status(404).json({ error: 'Mahlzeit nicht gefunden' });
    res.json(meal);
  } catch (err) {
    return respondFamilyPersistenceError(res, 'PUT /api/meals/:mealId', err);
  }
});

/**
 * DELETE /api/meals/:mealId
 * Lösche eine Mahlzeit
 */
app.delete('/api/meals/:mealId', requireVerifiedUser, requireOwnFamily, async (req, res) => {
  const { mealId } = req.params;

  try {
    const deleted = await prisma.$transaction(async transaction => {
      const existing = await transaction.meal.findUnique({
        where: { id: mealId },
        select: { id: true, mealPlan: { select: { familyId: true } } },
      });
      if (!existing || existing.mealPlan?.familyId !== req.ownFamily.id) return false;
      await transaction.meal.delete({ where: { id: mealId } });
      return true;
    });

    if (!deleted) return res.status(404).json({ error: 'Mahlzeit nicht gefunden' });
    res.json({ success: true, message: 'Mahlzeit gelöscht' });
  } catch (err) {
    return respondFamilyPersistenceError(res, 'DELETE /api/meals/:mealId', err);
  }
});

// ============================================================================
// PARENT MATCHING - Modern Smart Matching Algorithm
// ============================================================================

/**
 * Haversine formula for geographic distance
 */
function haversineDistance(lat1, lon1, lat2, lon2) {
  const R = 6371; // Earth's radius in km
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

/**
 * Jaccard similarity for interest/hobby matching
 */
function jaccardSimilarity(arr1, arr2) {
  if (!Array.isArray(arr1)) arr1 = [];
  if (!Array.isArray(arr2)) arr2 = [];
  const set1 = new Set(arr1.map(s => String(s).toLowerCase()));
  const set2 = new Set(arr2.map(s => String(s).toLowerCase()));
  const intersection = new Set([...set1].filter(x => set2.has(x)));
  const union = new Set([...set1, ...set2]);
  return union.size === 0 ? 0 : intersection.size / union.size;
}

/**
 * POST /api/parent-matching/profiles
 * Create or update user's matching profile
 */
app.post('/api/parent-matching/profiles', requireVerifiedUser, async (req, res) => {
  const userId = req.firebaseUid;
  const { name, city, interests, languages, valuesFocus, childAges, familyForm, bio } = req.body;
  const age = parseOptionalParentAge(req.body.age, 18, 120);
  const latitude = parseOptionalParentCoordinate(req.body.latitude, 90);
  const longitude = parseOptionalParentCoordinate(req.body.longitude, 180);
  if (latitude === undefined || longitude === undefined ||
      (latitude === null) !== (longitude === null)) {
    return res.status(400).json({ error: 'Koordinaten sind ungueltig oder unvollstaendig' });
  }

  if (!userId || !name || !city) {
    return res.status(400).json({ error: 'userId, name, city erforderlich' });
  }
  // Echter Bann: gesperrte Nutzer koennen ihr Profil nicht (neu) veroeffentlichen.
  if (await isUserSuspended(userId)) return respondSuspended(res);

  if (age === undefined) {
    return res.status(400).json({ error: 'Alter muss zwischen 18 und 120 liegen' });
  }

  try {
    await ensureParentMatchingSchemaReady();
    const profile = await prisma.parentMatchingProfile.upsert({
      where: { externalId: `self-${userId}` },
      update: {
        ownerUserId: userId,
        name: String(name).slice(0, 100),
        age,
        city: String(city).slice(0, 50),
        latitude,
        longitude,
        bio: bio ? String(bio).slice(0, 500) : null,
        interests: Array.isArray(interests) ? interests.map(i => String(i).slice(0, 50)) : [],
        languages: Array.isArray(languages) ? languages.map(l => String(l).slice(0, 30)) : [],
        valuesFocus: Array.isArray(valuesFocus) ? valuesFocus.map(v => String(v).slice(0, 50)) : [],
        childAges: Array.isArray(childAges) ? childAges.map(c => String(c).slice(0, 30)) : [],
        familyForm: familyForm ? String(familyForm).slice(0, 50) : null,
        updatedAt: new Date(),
      },
      create: {
        externalId: `self-${userId}`,
        ownerUserId: userId,
        name: String(name).slice(0, 100),
        age,
        city: String(city).slice(0, 50),
        latitude,
        longitude,
        bio: bio ? String(bio).slice(0, 500) : null,
        interests: Array.isArray(interests) ? interests.map(i => String(i).slice(0, 50)) : [],
        languages: Array.isArray(languages) ? languages.map(l => String(l).slice(0, 30)) : [],
        valuesFocus: Array.isArray(valuesFocus) ? valuesFocus.map(v => String(v).slice(0, 50)) : [],
        childAges: Array.isArray(childAges) ? childAges.map(c => String(c).slice(0, 30)) : [],
        familyForm: familyForm ? String(familyForm).slice(0, 50) : null,
      },
    });

    res.json({ profile: mapParentMatchingProfileForClient(profile) });
  } catch (err) {
    console.error('❌ Fehler beim Speichern des Matching-Profils:', err);
    res.status(500).json({ error: 'Profil konnte nicht gespeichert werden' });
  }
});

function normalizeParentMatchingCity(value) {
  return String(value || '')
    .trim()
    .toLocaleLowerCase('de-DE')
    .split(',')[0]
    .replace(/[^a-z0-9äöüß]/g, '');
}

function scoreParentMatchingCandidates({ userProfile, candidates, blockedIds, suspendedIds, limit, maxDistanceKm }) {
  const maxDistance = Number.parseFloat(maxDistanceKm) || 25;
  const ownCity = normalizeParentMatchingCity(userProfile.city);
  const hasCoordinates = profile =>
    Number.isFinite(profile.latitude) && Number.isFinite(profile.longitude);
  const hasOwnCoordinates = hasCoordinates(userProfile);

  const matches = candidates
    .filter(profile => !blockedIds.has(profile.ownerUserId) && !suspendedIds.has(profile.ownerUserId))
    .map(candidate => {
      const reasons = [];
      const breakdown = {};
      let score = 0;
      const sameCity = ownCity && ownCity === normalizeParentMatchingCity(candidate.city);
      const candidateHasCoordinates = hasCoordinates(candidate);

      if (hasOwnCoordinates && candidateHasCoordinates) {
        const distance = haversineDistance(
          userProfile.latitude, userProfile.longitude, candidate.latitude, candidate.longitude);
        if (distance > maxDistance) return null;
        breakdown.distanceKm = Math.round(distance);
        breakdown.proximityScore = Math.max(0, Math.round(30 - distance));
        score += breakdown.proximityScore;
        if (distance <= 10) reasons.push('nearby');
      } else if (sameCity) {
        breakdown.locationLabel = 'same_city';
        breakdown.cityScore = 18;
        score += breakdown.cityScore;
        reasons.push('same_city');
      }

      const categories = [
        ['interests', userProfile.interests, candidate.interests, 20, 'shared_interests'],
        ['childAge', userProfile.childAges, candidate.childAges, 15, 'similar_child_age'],
        ['languages', userProfile.languages, candidate.languages, 15, 'shared_languages'],
        ['values', userProfile.valuesFocus, candidate.valuesFocus, 15, 'shared_values'],
      ];
      for (const [key, ownValues, candidateValues, weight, reason] of categories) {
        const similarity = jaccardSimilarity(ownValues, candidateValues);
        const categoryScore = Math.round(similarity * weight);
        breakdown[`${key}Score`] = categoryScore;
        score += categoryScore;
        if (similarity > 0) reasons.push(reason);
      }
      if (userProfile.familyForm && candidate.familyForm && userProfile.familyForm === candidate.familyForm) {
        breakdown.familyFormScore = 5;
        score += breakdown.familyFormScore;
        reasons.push('shared_family_form');
      }

      return {
        profile: mapParentMatchingProfileForClient(candidate),
        score: Math.min(100, Math.round(score)),
        breakdown: { ...breakdown, reasons: reasons.slice(0, 3) },
      };
    })
    .filter(Boolean)
    .filter(match => match.score > 0)
    .sort((a, b) => b.score - a.score)
    .slice(0, Math.min(Math.max(Number.parseInt(limit, 10) || 10, 1), 100));

  return { matches };
}

async function discoverParentMatchingProfiles({ userId, limit, maxDistanceKm }) {
  const userProfile = await getMyParentMatchingProfile(userId);
  if (!userProfile) return null;
  const candidates = await prisma.parentMatchingProfile.findMany({
    where: { isActive: true, ownerUserId: { not: userId } },
    take: 100,
  });
  await ensureSocialSchemaReady();
  const blockRows = await prisma.$queryRawUnsafe(
    `SELECT "blockedUserId" FROM "SafetyBlock" WHERE "blockerUserId" = $1`, userId);
  const blockedIds = new Set(blockRows.map(row => row.blockedUserId));
  const suspensionRows = await prisma.$queryRawUnsafe(`SELECT "userId" FROM "SafetySuspension"`);
  const suspendedIds = new Set(suspensionRows.map(row => row.userId));
  return scoreParentMatchingCandidates({
    userProfile, candidates, blockedIds, suspendedIds, limit, maxDistanceKm,
  });
}

async function respondWithParentMatchingDiscovery(req, res) {
  const userId = (req.query.userId || '').toString().trim();
  if (!userId) return res.status(400).json({ error: 'userId erforderlich' });
  if (!req.firebaseUid) {
    const { uid, verified } = await verifyFirebaseIdToken(req);
    if (verified) req.firebaseUid = uid;
  }
  if (!req.firebaseUid) {
    return res.status(401).json({ error: 'Firebase sign-in required' });
  }
  if (req.firebaseUid !== userId) {
    return res.status(403).json({ error: 'Own discovery only' });
  }
  try {
    const result = await discoverParentMatchingProfiles({
      userId,
      limit: req.query.limit || '10',
      maxDistanceKm: req.query.maxDistanceKm || '25',
    });
    if (result === null) {
      return res.status(404).json({ error: 'Matching profile not found' });
    }
    return res.json(result);
  } catch (error) {
    console.error('Parent matching discovery failed:', error);
    return res.status(503).json({ error: 'Matching discovery unavailable' });
  }
}

app.get('/parent-matching/discover', respondWithParentMatchingDiscovery);
// Legacy adapter: keep old clients functional without maintaining a second algorithm.
app.get('/api/parent-matching/find', respondWithParentMatchingDiscovery);

/**
 * POST /api/parent-matching/record-action
 * Record user action (like, contact, pass)
 */
app.post('/api/parent-matching/record-action', requireVerifiedUser, requireOwnFamily, recordParentMatchingAction);

// ============================================================================
// GEMEINSAM SATT - Shared Recipes (Modern & Secure)
// ============================================================================

/**
 * GET /api/food-feed/recipes
 * List recipes with pagination, filtering, and sorting
 */
app.get('/api/food-feed/recipes', async (req, res) => {
  const { skip = '0', take = '20', category, difficulty, search, sortBy = 'createdAt' } = req.query;

  try {
    const where = {
      isPublished: true,
    };

    if (category) {
      where.category = String(category);
    }

    if (difficulty) {
      where.difficulty = String(difficulty);
    }

    if (search) {
      const searchTerm = String(search).toLowerCase();
      where.OR = [
        { title: { contains: searchTerm, mode: 'insensitive' } },
        { description: { contains: searchTerm, mode: 'insensitive' } },
        { tags: { hasSome: [searchTerm] } },
      ];
    }

    const recipes = await prisma.sharedRecipe.findMany({
      where,
      orderBy: sortBy === 'rating' ? { rating: 'desc' } : { createdAt: 'desc' },
      skip: Math.max(0, parseInt(skip, 10)),
      take: Math.min(100, parseInt(take, 10)),
      select: {
        id: true,
        creatorUserId: true,
        familyId: true,
        title: true,
        description: true,
        category: true,
        difficulty: true,
        prepTimeMinutes: true,
        servings: true,
        tags: true,
        imageUrl: true,
        rating: true,
        ratingCount: true,
        viewCount: true,
        isPublished: true,
        isFeatured: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    const total = await prisma.sharedRecipe.count({ where });
    const authorTrustMap = await buildAuthorTrustMapForRecipes(recipes);
    const enrichedRecipes = recipes.map((recipe) => ({
      ...recipe,
      authorTrust: authorTrustMap.get(String(recipe.creatorUserId || '').trim()) || null,
    }));

    res.json({ recipes: enrichedRecipes, total, pagination: { skip: parseInt(skip, 10), take: parseInt(take, 10) } });
  } catch (err) {
    console.error('❌ Fehler beim Abrufen von Rezepten:', err);
    res.status(500).json({ error: 'Rezepte konnten nicht geladen werden' });
  }
});

/**
 * GET /api/food-feed/recipes/:id
 * Get full recipe details
 */
app.get('/api/food-feed/recipes/:id', async (req, res) => {
  const { id } = req.params;

  try {
    const recipe = await prisma.sharedRecipe.findUnique({
      where: { id },
      include: { ratings: { take: 5 } },
    });

    if (!recipe) {
      return res.status(404).json({ error: 'Rezept nicht gefunden' });
    }

    // Increment view count
    await prisma.sharedRecipe.update({
      where: { id },
      data: { viewCount: { increment: 1 } },
    });

    const authorTrustMap = await buildAuthorTrustMapForRecipes([recipe]);
    res.json({
      recipe: {
        ...recipe,
        authorTrust: authorTrustMap.get(String(recipe.creatorUserId || '').trim()) || null,
      },
    });
  } catch (err) {
    console.error('❌ Fehler beim Abrufen des Rezepts:', err);
    res.status(500).json({ error: 'Rezept konnte nicht geladen werden' });
  }
});

/**
 * POST /api/food-feed/recipes
 * Create a new shared recipe (requires auth)
 */
app.post('/api/food-feed/recipes', async (req, res) => {
  const { userId, familyId, title, description, category, difficulty, prepTimeMinutes, servings, ingredients, instructions, tags, imageUrl } = req.body;

  // Validation
  if (!userId) {
    return res.status(401).json({ error: 'userId erforderlich' });
  }

  if (!title || title.length < 3 || title.length > 200) {
    return res.status(400).json({ error: 'Titel muss zwischen 3 und 200 Zeichen lang sein' });
  }

  if (!Array.isArray(ingredients) || ingredients.length === 0) {
    return res.status(400).json({ error: 'Mindestens ein Zutat erforderlich' });
  }

  if (!Array.isArray(instructions) || instructions.length === 0) {
    return res.status(400).json({ error: 'Mindestens eine Anweisung erforderlich' });
  }

  if (!['leicht', 'mittel', 'schwer'].includes(difficulty)) {
    return res.status(400).json({ error: 'Ungültiger Schwierigkeitsgrad' });
  }

  try {
    const recipe = await prisma.sharedRecipe.create({
      data: {
        creatorUserId: userId,
        familyId: familyId || null,
        title: String(title).slice(0, 200),
        description: description ? String(description).slice(0, 1000) : null,
        category: String(category || 'dinner').slice(0, 50),
        difficulty: String(difficulty),
        prepTimeMinutes: prepTimeMinutes ? parseInt(prepTimeMinutes, 10) : null,
        servings: servings ? Math.max(1, parseInt(servings, 10)) : 2,
        ingredients: JSON.stringify(
          ingredients.map(ing => ({
            name: String(ing.name || '').slice(0, 100),
            quantity: String(ing.quantity || ''),
            unit: String(ing.unit || '').slice(0, 20),
          })),
        ),
        instructions: JSON.stringify(instructions.map(ins => String(ins).slice(0, 500))),
        tags: Array.isArray(tags) ? tags.map(t => String(t).slice(0, 30)).slice(0, 10) : [],
        imageUrl: imageUrl ? String(imageUrl).slice(0, 500) : null,
        publishedAt: new Date(),
      },
    });

    res.status(201).json({ recipe });
  } catch (err) {
    console.error('❌ Fehler beim Erstellen des Rezepts:', err);
    res.status(500).json({ error: 'Rezept konnte nicht erstellt werden' });
  }
});

/**
 * PUT /api/food-feed/recipes/:id
 * Update a recipe (owner only)
 */
app.put('/api/food-feed/recipes/:id', async (req, res) => {
  const { id } = req.params;
  const { userId, title, description, category, difficulty, prepTimeMinutes, servings, ingredients, instructions, tags } = req.body;

  if (!userId) {
    return res.status(401).json({ error: 'userId erforderlich' });
  }

  try {
    const recipe = await prisma.sharedRecipe.findUnique({ where: { id } });

    if (!recipe) {
      return res.status(404).json({ error: 'Rezept nicht gefunden' });
    }

    if (recipe.creatorUserId !== userId) {
      return res.status(403).json({ error: 'Nur der Ersteller kann dieses Rezept bearbeiten' });
    }

    const updated = await prisma.sharedRecipe.update({
      where: { id },
      data: {
        title: title ? String(title).slice(0, 200) : undefined,
        description: description !== undefined ? (description ? String(description).slice(0, 1000) : null) : undefined,
        category: category ? String(category).slice(0, 50) : undefined,
        difficulty: difficulty && ['leicht', 'mittel', 'schwer'].includes(difficulty) ? difficulty : undefined,
        prepTimeMinutes: prepTimeMinutes ? parseInt(prepTimeMinutes, 10) : undefined,
        servings: servings ? Math.max(1, parseInt(servings, 10)) : undefined,
        ingredients: ingredients ? JSON.stringify(ingredients.map(ing => ({ name: String(ing.name || '').slice(0, 100), quantity: String(ing.quantity || ''), unit: String(ing.unit || '').slice(0, 20) }))) : undefined,
        instructions: instructions ? JSON.stringify(instructions.map(ins => String(ins).slice(0, 500))) : undefined,
        tags: tags ? tags.map(t => String(t).slice(0, 30)).slice(0, 10) : undefined,
        updatedAt: new Date(),
      },
    });

    res.json({ recipe: updated });
  } catch (err) {
    console.error('❌ Fehler beim Aktualisieren des Rezepts:', err);
    res.status(500).json({ error: 'Rezept konnte nicht aktualisiert werden' });
  }
});

/**
 * DELETE /api/food-feed/recipes/:id
 * Delete a recipe (owner only)
 */
app.delete('/api/food-feed/recipes/:id', async (req, res) => {
  const { id } = req.params;
  const userId = String(req.query.userId || req.body?.userId || '').trim();

  if (!userId) {
    return res.status(401).json({ error: 'userId erforderlich' });
  }

  try {
    const recipe = await prisma.sharedRecipe.findUnique({ where: { id } });

    if (!recipe) {
      return res.status(404).json({ error: 'Rezept nicht gefunden' });
    }

    if (recipe.creatorUserId !== userId) {
      return res.status(403).json({ error: 'Nur der Ersteller kann dieses Rezept löschen' });
    }

    await prisma.sharedRecipe.delete({ where: { id } });

    res.json({ success: true, message: 'Rezept gelöscht' });
  } catch (err) {
    console.error('❌ Fehler beim Löschen des Rezepts:', err);
    res.status(500).json({ error: 'Rezept konnte nicht gelöscht werden' });
  }
});

/**
 * POST /api/food-feed/recipes/:id/rate
 * Rate a recipe
 */
app.post('/api/food-feed/recipes/:id/rate', async (req, res) => {
  const { id } = req.params;
  const { userId, rating, comment } = req.body;

  if (!userId || !rating) {
    return res.status(400).json({ error: 'userId und rating erforderlich' });
  }

  if (rating < 1 || rating > 5) {
    return res.status(400).json({ error: 'Rating muss zwischen 1 und 5 liegen' });
  }

  try {
    // Upsert rating
    const recipeRating = await prisma.recipeRating.upsert({
      where: { recipeId_userId: { recipeId: id, userId } },
      update: { rating, comment: comment ? String(comment).slice(0, 500) : null },
      create: { recipeId: id, userId, rating, comment: comment ? String(comment).slice(0, 500) : null },
    });

    // Recalculate recipe rating stats
    const ratings = await prisma.recipeRating.findMany({ where: { recipeId: id } });
    const avgRating = ratings.length > 0 ? ratings.reduce((sum, r) => sum + r.rating, 0) / ratings.length : 0;

    await prisma.sharedRecipe.update({
      where: { id },
      data: {
        rating: Math.round(avgRating * 100) / 100,
        ratingCount: ratings.length,
      },
    });

    res.status(201).json({ rating: recipeRating });
  } catch (err) {
    console.error('❌ Fehler beim Speichern des Ratings:', err);
    res.status(500).json({ error: 'Rating konnte nicht gespeichert werden' });
  }
});

/**
 * GET /api/food-feed/recipes/:id/comments
 * List persisted comments for recipe-based food offers
 */
app.get('/api/food-feed/recipes/:id/comments', async (req, res) => {
  const { id } = req.params;
  const limit = Math.min(100, Math.max(1, Number.parseInt(req.query.limit || '40', 10)));

  try {
    const recipe = await prisma.sharedRecipe.findUnique({ where: { id } });
    if (!recipe) {
      return res.status(404).json({ error: 'Rezept nicht gefunden' });
    }

    const comments = await prisma.$queryRawUnsafe(
      `
      SELECT "id", "recipeId", "userId", "text", "createdAt"
      FROM "FoodOfferComment"
      WHERE "recipeId" = $1
      ORDER BY "createdAt" DESC
      LIMIT $2
      `,
      id,
      limit,
    );

    return res.json({ comments });
  } catch (err) {
    console.error('❌ Fehler beim Abrufen der Offer-Kommentare:', err);
    return res.status(500).json({ error: 'Kommentare konnten nicht geladen werden' });
  }
});

/**
 * POST /api/food-feed/recipes/:id/comments
 * Create a persisted comment for a recipe-based food offer
 */
app.post('/api/food-feed/recipes/:id/comments', async (req, res) => {
  const { id } = req.params;
  const userId = String(req.body.userId || '').trim();
  const text = String(req.body.text || '').trim();

  if (!userId || !text) {
    return res.status(400).json({ error: 'userId und text sind erforderlich' });
  }

  if (text.length > 600) {
    return res.status(400).json({ error: 'Kommentar zu lang (max. 600 Zeichen)' });
  }

  try {
    const recipe = await prisma.sharedRecipe.findUnique({ where: { id } });
    if (!recipe) {
      return res.status(404).json({ error: 'Rezept nicht gefunden' });
    }

    const comment = {
      id: generateId('offer_comment'),
      recipeId: id,
      userId,
      text,
      createdAt: new Date(),
    };

    await prisma.$executeRawUnsafe(
      `
      INSERT INTO "FoodOfferComment" ("id", "recipeId", "userId", "text", "createdAt")
      VALUES ($1, $2, $3, $4, $5)
      `,
      comment.id,
      comment.recipeId,
      comment.userId,
      comment.text,
      comment.createdAt,
    );

    return res.status(201).json({
      comment: {
        ...comment,
        createdAt: comment.createdAt.toISOString(),
      },
    });
  } catch (err) {
    console.error('❌ Fehler beim Speichern des Offer-Kommentars:', err);
    return res.status(500).json({ error: 'Kommentar konnte nicht gespeichert werden' });
  }
});

/**
 * GET /api/food-feed/recipes/:id/reservations
 * Get reservation summary and optionally current user's reservation
 */
app.get('/api/food-feed/recipes/:id/reservations', async (req, res) => {
  const { id } = req.params;
  const userId = String(req.query.userId || '').trim();

  try {
    const recipe = await prisma.sharedRecipe.findUnique({ where: { id } });
    if (!recipe) {
      return res.status(404).json({ error: 'Rezept nicht gefunden' });
    }

    const [summary] = await prisma.$queryRawUnsafe(
      `
      SELECT COALESCE(SUM("portions"), 0)::int AS "reservedPortions", COUNT(*)::int AS "reservationsCount"
      FROM "FoodOfferReservation"
      WHERE "recipeId" = $1 AND "completedAt" IS NULL
      `,
      id,
    );

    let myReservation = null;
    if (userId) {
      const mine = await prisma.$queryRawUnsafe(
        `
        SELECT "id", "recipeId", "userId", "portions", "createdAt", "updatedAt", "completedAt"
        FROM "FoodOfferReservation"
        WHERE "recipeId" = $1 AND "userId" = $2 AND "completedAt" IS NULL
        LIMIT 1
        `,
        id,
        userId,
      );
      myReservation = Array.isArray(mine) && mine.length > 0 ? mine[0] : null;
    }

    return res.json({
      reservedPortions: Number(summary?.reservedPortions || 0),
      reservationsCount: Number(summary?.reservationsCount || 0),
      myReservation,
    });
  } catch (err) {
    console.error('❌ Fehler beim Abrufen der Reservierungsdaten:', err);
    return res.status(500).json({ error: 'Reservierungsdaten konnten nicht geladen werden' });
  }
});

/**
 * POST /api/food-feed/recipes/:id/reserve
 * Reserve one or more portions for current user
 */
app.post('/api/food-feed/recipes/:id/reserve', async (req, res) => {
  const { id } = req.params;
  const userId = String(req.body.userId || '').trim();
  const portions = Math.max(1, Number.parseInt(req.body.portions || '1', 10));

  if (!userId) {
    return res.status(400).json({ error: 'userId ist erforderlich' });
  }

  try {
    const recipe = await prisma.sharedRecipe.findUnique({ where: { id } });
    if (!recipe) {
      return res.status(404).json({ error: 'Rezept nicht gefunden' });
    }

    const reservationId = generateId('offer_reservation');
    await prisma.$executeRawUnsafe(
      `
      INSERT INTO "FoodOfferReservation" ("id", "recipeId", "userId", "portions", "completedAt", "createdAt", "updatedAt")
      VALUES ($1, $2, $3, $4, NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ON CONFLICT ("recipeId", "userId")
      DO UPDATE SET "portions" = EXCLUDED."portions", "completedAt" = NULL, "updatedAt" = CURRENT_TIMESTAMP
      `,
      reservationId,
      id,
      userId,
      portions,
    );

    const [summary] = await prisma.$queryRawUnsafe(
      `
      SELECT COALESCE(SUM("portions"), 0)::int AS "reservedPortions"
      FROM "FoodOfferReservation"
      WHERE "recipeId" = $1 AND "completedAt" IS NULL
      `,
      id,
    );

    return res.status(201).json({
      success: true,
      reservedPortions: Number(summary?.reservedPortions || 0),
      myPortions: portions,
    });
  } catch (err) {
    console.error('❌ Fehler beim Reservieren eines Angebots:', err);
    return res.status(500).json({ error: 'Reservierung konnte nicht gespeichert werden' });
  }
});

/**
 * DELETE /api/food-feed/recipes/:id/reserve?userId=...
 * Cancel current user's reservation
 */
app.delete('/api/food-feed/recipes/:id/reserve', async (req, res) => {
  const { id } = req.params;
  const userId = String(req.query.userId || req.body?.userId || '').trim();

  if (!userId) {
    return res.status(400).json({ error: 'userId ist erforderlich' });
  }

  try {
    await prisma.$executeRawUnsafe(
      `
      DELETE FROM "FoodOfferReservation"
      WHERE "recipeId" = $1 AND "userId" = $2 AND "completedAt" IS NULL
      `,
      id,
      userId,
    );

    const [summary] = await prisma.$queryRawUnsafe(
      `
      SELECT COALESCE(SUM("portions"), 0)::int AS "reservedPortions"
      FROM "FoodOfferReservation"
      WHERE "recipeId" = $1 AND "completedAt" IS NULL
      `,
      id,
    );

    return res.json({ success: true, reservedPortions: Number(summary?.reservedPortions || 0) });
  } catch (err) {
    console.error('❌ Fehler beim Entfernen einer Reservierung:', err);
    return res.status(500).json({ error: 'Reservierung konnte nicht entfernt werden' });
  }
});

/**
 * POST /api/food-feed/recipes/:id/complete
 * Mark current user's reservation as successfully picked up/completed
 */
app.post('/api/food-feed/recipes/:id/complete', async (req, res) => {
  const { id } = req.params;
  const userId = String(req.body.userId || '').trim();

  if (!userId) {
    return res.status(400).json({ error: 'userId ist erforderlich' });
  }

  try {
    const recipe = await prisma.sharedRecipe.findUnique({ where: { id } });
    if (!recipe) {
      return res.status(404).json({ error: 'Rezept nicht gefunden' });
    }

    const existing = await prisma.$queryRawUnsafe(
      `
      SELECT "id"
      FROM "FoodOfferReservation"
      WHERE "recipeId" = $1 AND "userId" = $2 AND "completedAt" IS NULL
      LIMIT 1
      `,
      id,
      userId,
    );

    if (!Array.isArray(existing) || existing.length === 0) {
      return res.status(404).json({ error: 'Keine offene Reservierung gefunden' });
    }

    await prisma.$executeRawUnsafe(
      `
      UPDATE "FoodOfferReservation"
      SET "completedAt" = CURRENT_TIMESTAMP, "updatedAt" = CURRENT_TIMESTAMP
      WHERE "recipeId" = $1 AND "userId" = $2 AND "completedAt" IS NULL
      `,
      id,
      userId,
    );

    return res.status(200).json({ success: true, completed: true });
  } catch (err) {
    console.error('❌ Fehler beim Abschliessen einer Reservierung:', err);
    return res.status(500).json({ error: 'Reservierung konnte nicht abgeschlossen werden' });
  }
});

/**
 * POST /api/food-feed/recipes/:id/report
 * Report a recipe-based food offer for moderation
 */
app.post('/api/food-feed/recipes/:id/report', async (req, res) => {
  const { id } = req.params;
  const reportedById = String(req.body.reportedById || req.body.userId || '').trim();
  const reason = String(req.body.reason || '').trim();
  const details = String(req.body.details || req.body.note || '').trim();

  if (!reportedById || !reason) {
    return res.status(400).json({ error: 'reportedById und reason erforderlich' });
  }

  if (reason.length < 3 || reason.length > 120) {
    return res.status(400).json({ error: 'reason muss 3-120 Zeichen lang sein' });
  }

  try {
    const recipe = await prisma.sharedRecipe.findUnique({ where: { id } });
    if (!recipe) {
      return res.status(404).json({ error: 'Rezept nicht gefunden' });
    }

    const duplicate = await prisma.recipeReport.findFirst({
      where: {
        recipeId: id,
        reportedById,
        status: { in: ['pending', 'resolved'] },
      },
      orderBy: { createdAt: 'desc' },
    });
    if (duplicate) {
      return res.status(409).json({ error: 'Dieses Angebot wurde von dir bereits gemeldet' });
    }

    const report = await prisma.recipeReport.create({
      data: {
        recipeId: id,
        reportedById: reportedById.slice(0, 120),
        reason: reason.slice(0, 120),
        details: details ? details.slice(0, 1200) : null,
        status: 'pending',
      },
    });

    const recentReportCount = await prisma.recipeReport.count({
      where: {
        recipeId: id,
        createdAt: {
          gte: new Date(Date.now() - (30 * 24 * 60 * 60 * 1000)),
        },
      },
    });

    const severe = isRecipeReportSevere({ reason, details });
    let autoAction = 'none';

    if (shouldAutoUnpublishRecipe({ severe, recentReportCount })) {
      autoAction = severe ? 'unpublished_severe' : 'unpublished_threshold';
      await prisma.$transaction([
        prisma.sharedRecipe.update({
          where: { id },
          data: {
            isPublished: false,
            reportedCount: recentReportCount,
            lastReportedAt: new Date(),
            updatedAt: new Date(),
          },
        }),
        prisma.recipeReport.updateMany({
          where: {
            recipeId: id,
            status: 'pending',
          },
          data: {
            status: 'resolved',
            resolvedAt: new Date(),
          },
        }),
      ]);
    } else {
      await prisma.sharedRecipe.update({
        where: { id },
        data: {
          reportedCount: recentReportCount,
          lastReportedAt: new Date(),
          updatedAt: new Date(),
        },
      });
    }

    return res.status(201).json({
      report,
      autoModeration: {
        action: autoAction,
        recentReportCount,
      },
    });
  } catch (err) {
    console.error('❌ Food-offer report create error:', err.message);
    return res.status(500).json({ error: `Failed to create food-offer report: ${err.message}` });
  }
});

/**
 * GET /api/food-feed/reports
 * List food-offer reports (admin token required)
 */
app.get('/api/food-feed/reports', async (req, res) => {
  if (!isAdminTokenAuthorized(req)) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  const { status, maxResults = 50, offset = 0 } = req.query;

  try {
    const reports = await prisma.recipeReport.findMany({
      where: {
        ...(status ? { status: String(status) } : {}),
      },
      orderBy: { createdAt: 'desc' },
      take: Math.min(parseInt(maxResults, 10) || 50, 100),
      skip: parseInt(offset, 10) || 0,
      include: {
        recipe: {
          select: {
            id: true,
            title: true,
            creatorUserId: true,
            isPublished: true,
            createdAt: true,
          },
        },
      },
    });

    res.json({ reports, total: reports.length });
  } catch (err) {
    console.error('❌ Food-offer report list error:', err.message);
    res.status(500).json({ error: `Failed to list food-offer reports: ${err.message}` });
  }
});

/**
 * POST /api/food-feed/reports/:reportId/resolve
 * Resolve or dismiss a food-offer report (admin token required)
 */
app.post('/api/food-feed/reports/:reportId/resolve', async (req, res) => {
  if (!isAdminTokenAuthorized(req)) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  const { reportId } = req.params;
  const { action = 'resolved' } = req.body;
  const normalizedAction = String(action).trim();
  const allowedActions = new Set(['resolved', 'dismissed']);

  if (!allowedActions.has(normalizedAction)) {
    return res.status(400).json({ error: 'action muss resolved oder dismissed sein' });
  }

  try {
    const existing = await prisma.recipeReport.findUnique({ where: { id: reportId } });
    if (!existing) {
      return res.status(404).json({ error: 'Report nicht gefunden' });
    }

    const updated = await prisma.recipeReport.update({
      where: { id: reportId },
      data: {
        status: normalizedAction,
        resolvedAt: new Date(),
      },
    });

    return res.json({ report: updated });
  } catch (err) {
    console.error('❌ Food-offer report resolve error:', err.message);
    return res.status(500).json({ error: `Failed to resolve food-offer report: ${err.message}` });
  }
});

/**
 * EVENTS & AKTIVITÄTEN - Community Event System
 */

/**
 * Haversine distance calculation (in km)
 * Calculates great-circle distance between two points on Earth
 */
function haversineDistance(lat1, lon1, lat2, lon2) {
  const R = 6371; // Earth's radius in km
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) * Math.cos((lat2 * Math.PI) / 180) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

/**
 * POST /api/events
 * Create a new community event
 */
app.post('/api/events', requireVerifiedUser, async (req, res) => {
  const {
    hosterId, title, description, location, latitude, longitude,
    startDate, endDate, eventType, visibility, shareRadiusKm, maxParticipants,
    costPerPerson, imageUrl, ageGroups, seriesId, participationMode = 'legacyApproval', externalUrl,
    invitedUserIds = [], inviteCodeExpiresAt
  } = req.body;

  if (!req.firebaseUid) return res.status(401).json({ error: 'Firebase sign-in required' });
  if (req.firebaseUid !== hosterId) return res.status(403).json({ error: 'Own account only' });
  try {
    validateEventMode(participationMode, externalUrl);
    if (!startDate || !Number.isFinite(new Date(startDate).getTime()) || new Date(startDate) <= new Date()) {
      return res.status(400).json({ error: 'Future startDate required' });
    }
    if (participationMode !== 'interest' && (!Number.isInteger(maxParticipants) || maxParticipants < 1)) {
      return res.status(400).json({ error: 'Positive capacity required' });
    }
    if (participationMode === 'interest' && visibility && visibility !== 'publicNearby') {
      return res.status(400).json({ error: 'Shared offers must be public' });
    }
    if (!Array.isArray(invitedUserIds) || invitedUserIds.some(userId => typeof userId !== 'string' || !userId.trim() || userId === hosterId)) {
      return res.status(400).json({ error: 'Invalid invitees' });
    }
    if (inviteCodeExpiresAt && (!Number.isFinite(new Date(inviteCodeExpiresAt).getTime()) || new Date(inviteCodeExpiresAt) <= new Date())) {
      return res.status(400).json({ error: 'Invalid invitation expiration' });
    }
  } catch (error) { return res.status(error.httpStatus || 400).json({ error: error.message }); }
  // Validate required fields
  if (!hosterId || !title || !location || latitude === undefined || longitude === undefined) {
    return res.status(400).json({
      error: 'hosterId, title, location, latitude, longitude erforderlich'
    });
  }
  // Echter Bann: gesperrte Nutzer koennen keine Events mehr erstellen.
  if (await isUserSuspended(hosterId.toString().trim())) return respondSuspended(res);

  // Validate coordinates
  const coordinatesMissing = latitude == null && longitude == null;
  if (!coordinatesMissing && (
    typeof latitude !== 'number' || typeof longitude !== 'number' ||
    !Number.isFinite(latitude) || !Number.isFinite(longitude) ||
    latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180
  )) {
    return res.status(400).json({ error: 'Ungültige Koordinaten' });
  }
  if (costPerPerson != null && (
    typeof costPerPerson !== 'number' || !Number.isFinite(costPerPerson) || costPerPerson < 0
  )) {
    return res.status(400).json({ error: 'Ungültiger Preis' });
  }

  // Validate title length
  if (String(title).length < 3 || String(title).length > 200) {
    return res.status(400).json({ error: 'Titel muss 3-200 Zeichen lang sein' });
  }

  // Altersgruppen bereinigen: nur nicht-leere Strings, getrimmt, dedupliziert,
  // defensiv begrenzt. Nicht-Array/ungültige Eingaben -> leeres Array.
  const sanitizedAgeGroups = Array.isArray(ageGroups)
    ? [...new Set(
        ageGroups
          .filter(group => typeof group === 'string')
          .map(group => group.trim())
          .filter(group => group.length > 0 && group.length <= 40),
      )].slice(0, 12)
    : [];

  try {
    const event = await prisma.event.create({
      data: {
        hosterId: String(hosterId).slice(0, 100),
        title: String(title).slice(0, 200),
        description: description ? String(description).slice(0, 2000) : null,
        location: String(location).slice(0, 200),
        latitude: coordinatesMissing ? null : latitude,
        longitude: coordinatesMissing ? null : longitude,
        startDate: startDate ? new Date(startDate) : new Date(),
        endDate: endDate ? new Date(endDate) : null,
        eventType: eventType ? String(eventType).slice(0, 50) : 'generic',
        ageGroups: sanitizedAgeGroups,
        participationMode,
        externalUrl: externalUrl || null,
        visibility: visibility ? String(visibility).slice(0, 50) : 'publicNearby',
        inviteCode: visibility === 'inviteOnly' ? crypto.randomBytes(12).toString('hex').toUpperCase() : null,
        inviteCodeExpiresAt: visibility === 'inviteOnly' ? new Date(inviteCodeExpiresAt || Date.now() + 14 * 24 * 60 * 60 * 1000) : null,
        ...(visibility === 'inviteOnly' && invitedUserIds.length > 0 && {
          participants: { create: [...new Set(invitedUserIds)].map(userId => ({ userId, status: 'invited' })) },
        }),
        shareRadiusKm: shareRadiusKm ? parseFloat(shareRadiusKm) : 25,
        maxParticipants: participationMode === 'interest' ? null : maxParticipants,
        costPerPerson: costPerPerson ?? null,
        imageUrl: imageUrl ? String(imageUrl).slice(0, 500) : null,
        seriesId: seriesId ? String(seriesId).slice(0, 100) : null,
        status: 'upcoming',
      },
      include: { participants: true }
    });

    // Issue #47: Ist dies ein neuer konkreter Termin einer Serie, der ein
    // Veranstalter veröffentlicht, benachrichtigen wir GEZIELT nur die Eltern,
    // die dieser Serie aktiv folgen (nicht alle in der Nähe, nicht aus einer
    // KI-Erkennung). Der Ersteller selbst wird ausgenommen. Best effort.
    if (event.seriesId) {
      notifyFollowersOfNewSeriesEvent(event).catch((e) =>
        console.error('notifyFollowersOfNewSeriesEvent failed:', e?.message || e)
      );
    }

    res.status(201).json({ event });
  } catch (err) {
    console.error('❌ Event creation error:', err.message, err);
    res.status(500).json({ error: `Event creation failed: ${err.message}` });
  }
});

// Gezielte Benachrichtigung an die Follower einer Event-Serie, wenn ein neuer
// konkreter Termin veröffentlicht wurde. Nur aktive Opt-in-Follower, nie der
// Ersteller selbst. Nutzt dasselbe Push-Muster wie der Gruppen-Chat.
async function notifyFollowersOfNewSeriesEvent(event) {
  if (!event || !event.seriesId) return;
  const followers = await prisma.eventSeriesFollower.findMany({
    where: { seriesId: event.seriesId, userId: { not: event.hosterId } },
    select: { userId: true },
  });
  if (followers.length === 0) return;

  const whenLocal = (() => {
    try {
      const d = new Date(event.startDate);
      return `${d.getDate().toString().padStart(2, '0')}.${(d.getMonth() + 1)
        .toString()
        .padStart(2, '0')}.`;
    } catch (_) {
      return '';
    }
  })();
  const title = 'Neuer Termin für ein Angebot, dem du folgst';
  const body = whenLocal
    ? `${event.title} — neuer Termin am ${whenLocal}`
    : `${event.title} — neuer Termin verfügbar`;

  await Promise.allSettled(
    followers.map((f) =>
      sendPushToUser(f.userId, {
        title,
        body,
        data: {
          type: 'event_series_new_date',
          seriesId: event.seriesId,
          eventId: event.id,
        },
      })
    )
  );
}

/**
 * GET /api/events
 * Discover and list events with filtering
 * Query params: status, eventType, visibility, latitude, longitude, radiusKm, maxResults, hosterId
 */
app.get('/api/events', async (req, res) => {
  const {
    status = 'upcoming',
    eventType,
    visibility = 'publicNearby',
    latitude,
    longitude,
    radiusKm = 25,
    maxResults = 50,
    offset = 0,
    hosterId
  } = req.query;

  try {
    const numeric = value => value == null || String(value).trim() === '' ? null : Number(value);
    const validCoords = (lat, lon) => Number.isFinite(lat) && Number.isFinite(lon) &&
      Math.abs(lat) <= 90 && Math.abs(lon) <= 180 && !(lat === 0 && lon === 0);
    const viewerLat = numeric(latitude);
    const viewerLon = numeric(longitude);
    const originKnown = validCoords(viewerLat, viewerLon);
    const maxDistance = numeric(radiusKm);
    if (!Number.isFinite(maxDistance) || maxDistance <= 0 ||
        ((latitude !== undefined || longitude !== undefined) && !originKnown)) {
      return res.status(400).json({ error: 'Valid coordinates and positive radiusKm required' });
    }
    const limit = Math.min(Math.max(parseInt(req.query.limit ?? maxResults, 10) || 50, 1), 100);
    const pageOffset = Math.max(parseInt(offset, 10) || 0, 0);
    const nearbyOnly = req.query.nearbyOnly === 'true';
    const onlyFree = req.query.onlyFree === 'true';
    const timeWindow = req.query.timeWindow || 'all';
    if (!['all', 'today', 'weekend'].includes(timeWindow)) {
      return res.status(400).json({ error: 'Invalid timeWindow' });
    }
    const utcOffsetMinutes = numeric(req.query.utcOffsetMinutes) ?? 0;
    if (!Number.isFinite(utcOffsetMinutes) || Math.abs(utcOffsetMinutes) > 840) {
      return res.status(400).json({ error: 'Invalid utcOffsetMinutes' });
    }
    const now = new Date();
    const localDate = date => new Date(date.getTime() + utcOffsetMinutes * 60000);
    const today = localDate(now).toISOString().slice(0, 10);
    const requestedAges = String(req.query.ageGroups || '').split(',').filter(Boolean);
    const matchesAges = ages => requestedAges.length === 0 || ages.length === 0 ||
      ages.includes('mixed') || requestedAges.includes('mixed') || ages.some(age => requestedAges.includes(age));
    const distanceKm = (lat1, lon1, lat2, lon2) => {
      const latitudeDelta = (lat2 - lat1) * Math.PI / 180;
      const longitudeDelta = (lon2 - lon1) * Math.PI / 180;
      const haversine = Math.sin(latitudeDelta / 2) ** 2 +
        Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * Math.sin(longitudeDelta / 2) ** 2;
      return 12742 * Math.asin(Math.sqrt(Math.min(1, Math.max(0, haversine))));
    };
    const needsResolution = event => event.latitude === 52.52 && event.longitude === 13.405;
    const distance = event => originKnown && !needsResolution(event) &&
      validCoords(numeric(event.latitude), numeric(event.longitude))
        ? distanceKm(viewerLat, viewerLon, numeric(event.latitude), numeric(event.longitude)) : null;
    const knownAges = event => Array.isArray(event.ageGroups) ? event.ageGroups : [];
    const score = event => {
      const km = distance(event);
      const days = (new Date(event.startDate) - now) / 86400000;
      return Math.max(0, Math.min(30, 30 - days)) * 2 +
        (km == null ? 0 : Math.max(0, Math.min(50, 50 - km))) +
        (requestedAges.length > 0 && knownAges(event).length > 0 && matchesAges(knownAges(event)) ? 20 : 0);
    };
    const where = {
      status: status === 'active' ? 'upcoming' : String(status),
      visibility: String(visibility),
      ...(eventType && { eventType: String(eventType) }),
      ...(hosterId && { hosterId: String(hosterId) }),
    };

    let events = await resilientEventFindMany({
      where,
      orderBy: { startDate: 'asc' },
      include: {
        participants: { select: { userId: true, status: true } }
      }
    });

    const visible = [];
    for (const event of events) {
      try {
        const current = req.firebaseUid ? event.participants.find(item => item.userId === req.firebaseUid) : null;
        await authorizeEventParticipation(prisma, event, req.firebaseUid, current);
        visible.push(event);
      } catch (error) { if (error.httpStatus !== 403) throw error; }
    }
    events = visible;

    events = events.filter(event => {
      const date = new Date(event.startDate);
      if (!Number.isFinite(date.getTime()) || date < now) return false;
      const local = localDate(date);
      if (timeWindow === 'today' && local.toISOString().slice(0, 10) !== today) return false;
      if (timeWindow === 'weekend' && (!(local.getUTCDay() === 0 || local.getUTCDay() === 6) ||
          date - now >= 7 * 86400000)) return false;
      if (!matchesAges(knownAges(event))) return false;
      if (onlyFree && numeric(event.costPerPerson) !== 0) return false;
      const km = distance(event);
      if (km == null) return !nearbyOnly || (originKnown && needsResolution(event));
      const shareRadius = numeric(event.shareRadiusKm) ?? 25;
      return km <= maxDistance && (!nearbyOnly || km <= 10) &&
        (event.visibility !== 'publicNearby' || event.hosterId === req.firebaseUid || km <= shareRadius);
    });
    events.sort((first, second) => score(second) - score(first) || String(first.id).localeCompare(String(second.id)));
    const total = events.length;
    const formattedEvents = events.slice(pageOffset, pageOffset + limit).map(e => ({
      id: e.id,
      hosterId: e.hosterId,
      title: e.title,
      description: e.description,
      location: e.location,
      latitude: needsResolution(e) ? null : (validCoords(numeric(e.latitude), numeric(e.longitude)) ? numeric(e.latitude) : null),
      longitude: needsResolution(e) ? null : (validCoords(numeric(e.latitude), numeric(e.longitude)) ? numeric(e.longitude) : null),
      coordinatesNeedResolution: needsResolution(e),
      ageGroups: knownAges(e),
      startDate: e.startDate,
      endDate: e.endDate,
      eventType: e.eventType,
      participationMode: e.participationMode || 'legacyApproval',
      externalUrl: e.externalUrl,
      seriesId: e.seriesId,
      visibility: e.visibility,
      shareRadiusKm: e.shareRadiusKm,
      maxParticipants: e.maxParticipants,
      currentParticipants: e.participationMode === 'interest' ? 0 : e.participants.filter(p => CONFIRMED.includes(p.status)).length,
      costPerPerson: e.costPerPerson,
      imageUrl: e.imageUrl,
      status: e.status,
      createdAt: e.createdAt,
      updatedAt: e.updatedAt,
    }));

    res.json({ events: formattedEvents, total, limit, offset: pageOffset, hasMore: pageOffset + limit < total });
  } catch (err) {
    console.error('❌ Events list error:', err.message);
    res.status(500).json({ error: `Failed to list events: ${err.message}` });
  }
});

/**
 * GET /api/events/:id
 * Get single event details
 */
app.get('/api/events/:id', async (req, res) => {
  const { id } = req.params;

  try {
    const event = await prisma.event.findUnique({
      where: { id },
      include: {
        participants: {
          include: { user: { select: { id: true, firstName: true, lastName: true, avatar: true } } }
        },
        chat: { include: { messages: { take: 5, orderBy: { createdAt: 'desc' } } } }
      }
    });

    if (!event) {
      return res.status(404).json({ error: 'Event nicht gefunden' });
    }

    const current = req.firebaseUid ? event.participants.find(item => item.userId === req.firebaseUid) : null;
    await authorizeEventParticipation(prisma, event, req.firebaseUid, current);

    const formattedEvent = {
      ...event,
      currentParticipants: event.participationMode === 'interest' ? 0 : event.participants.filter(p => CONFIRMED.includes(p.status)).length,
      isFull: event.maxParticipants ?
        event.participants.filter(p => CONFIRMED.includes(p.status)).length >= event.maxParticipants :
        false,
      spotsAvailable: event.maxParticipants ?
        Math.max(0, event.maxParticipants - event.participants.filter(p => CONFIRMED.includes(p.status)).length) :
        null,
    };

    res.json({ event: formattedEvent });
  } catch (err) {
    console.error('❌ Event detail error:', err.message);
    res.status(err.httpStatus || 503).json({ error: `Failed to get event: ${err.message}` });
  }
});

/**
 * PUT /api/events/:id
 * Update event (owner only)
 */
app.put('/api/events/:id', async (req, res) => {
  const { id } = req.params;
  const { hosterId, title, description, location, latitude, longitude, startDate, endDate, maxParticipants } = req.body;

  if (!req.firebaseUid) return res.status(401).json({ error: 'Firebase sign-in required' });

  if (req.firebaseUid && req.firebaseUid !== String(hosterId)) {
    return res.status(403).json({ error: 'Nur der Ersteller kann das Event bearbeiten' });
  }

  if (!hosterId) {
    return res.status(400).json({ error: 'hosterId erforderlich' });
  }

  try {
    // Verify ownership
    const event = await prisma.event.findUnique({ where: { id } });
    if (!event) {
      return res.status(404).json({ error: 'Event nicht gefunden' });
    }

    if (event.hosterId !== String(hosterId)) {
      return res.status(403).json({ error: 'Nur der Ersteller kann das Event bearbeiten' });
    }

    // Validate coordinates if provided
    if (latitude !== undefined || longitude !== undefined) {
      const lat = latitude !== undefined ? parseFloat(latitude) : event.latitude;
      const lon = longitude !== undefined ? parseFloat(longitude) : event.longitude;
      if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
        return res.status(400).json({ error: 'Ungültige Koordinaten' });
      }
    }

    const updatedEvent = await updateOwnedEvent(prisma, id, req.firebaseUid || String(hosterId), {
        ...(title && { title: String(title).slice(0, 200) }),
        ...(description && { description: String(description).slice(0, 2000) }),
        ...(location && { location: String(location).slice(0, 200) }),
        ...(latitude !== undefined && { latitude: parseFloat(latitude) }),
        ...(longitude !== undefined && { longitude: parseFloat(longitude) }),
        ...(startDate && { startDate: new Date(startDate) }),
        ...(endDate && { endDate: new Date(endDate) }),
        ...(maxParticipants !== undefined && { maxParticipants }),
        ...(req.body.participationMode !== undefined && { participationMode: req.body.participationMode }),
        ...(req.body.externalUrl !== undefined && { externalUrl: req.body.externalUrl }),
        updatedAt: new Date(),
    });

    res.json({ event: updatedEvent });
  } catch (err) {
    console.error('❌ Event update error:', err.message);
    res.status(err.httpStatus || 503).json({ error: `Failed to update event: ${err.message}` });
  }
});

/**
 * DELETE /api/events/:id
 * Delete event (owner only)
 * Query param: hosterId
 */
app.delete('/api/events/:id', async (req, res) => {
  const { id } = req.params;
  const { hosterId } = req.query;

  if (!req.firebaseUid) return res.status(401).json({ error: 'Firebase sign-in required' });

  if (req.firebaseUid && req.firebaseUid !== String(hosterId)) {
    return res.status(403).json({ error: 'Nur der Ersteller kann das Event löschen' });
  }

  if (!hosterId) {
    return res.status(400).json({ error: 'hosterId erforderlich' });
  }

  try {
    // Verify ownership
    const event = await prisma.event.findUnique({ where: { id } });
    if (!event) {
      return res.status(404).json({ error: 'Event nicht gefunden' });
    }

    if (event.hosterId !== String(hosterId)) {
      return res.status(403).json({ error: 'Nur der Ersteller kann das Event löschen' });
    }

    await prisma.event.delete({ where: { id } });
    res.json({ success: true });
  } catch (err) {
    console.error('❌ Event delete error:', err.message);
    res.status(500).json({ error: `Failed to delete event: ${err.message}` });
  }
});

// ============================================================================
// EVENT SERIES FOLLOW (Issue #47)
// Eltern folgen/entfolgen einem wiederkehrenden Angebot (seriesId). Nur
// Follower werden über neue konkrete Termine der Serie benachrichtigt.
// Bewusst getrennt von EventParticipation (Teilnahme ≠ Abo).
// ============================================================================

/**
 * POST /api/events/series/:seriesId/follow
 * Opt-in: dieser Nutzer folgt der Serie. Body: { userId }
 */
app.post('/api/events/series/:seriesId/follow', async (req, res) => {
  const seriesId = (req.params.seriesId || '').toString().trim();
  const userId = (req.body.userId || '').toString().trim();
  if (!seriesId || !userId) {
    return res.status(400).json({ error: 'seriesId und userId erforderlich' });
  }
  if (await isUserSuspended(userId)) return respondSuspended(res);
  try {
    await prisma.eventSeriesFollower.upsert({
      where: { seriesId_userId: { seriesId, userId } },
      update: {},
      create: { seriesId, userId },
    });
    const count = await prisma.eventSeriesFollower.count({ where: { seriesId } });
    return res.status(201).json({ following: true, seriesId, followerCount: count });
  } catch (err) {
    console.error('❌ Series follow error:', err.message);
    return res.status(500).json({ error: `Follow failed: ${err.message}` });
  }
});

/**
 * DELETE /api/events/series/:seriesId/follow?userId=...
 * Opt-out: dieser Nutzer folgt der Serie nicht mehr.
 */
app.delete('/api/events/series/:seriesId/follow', async (req, res) => {
  const seriesId = (req.params.seriesId || '').toString().trim();
  const userId = (req.query.userId || '').toString().trim();
  if (!seriesId || !userId) {
    return res.status(400).json({ error: 'seriesId und userId erforderlich' });
  }
  try {
    await prisma.eventSeriesFollower.deleteMany({ where: { seriesId, userId } });
    const count = await prisma.eventSeriesFollower.count({ where: { seriesId } });
    return res.json({ following: false, seriesId, followerCount: count });
  } catch (err) {
    console.error('❌ Series unfollow error:', err.message);
    return res.status(500).json({ error: `Unfollow failed: ${err.message}` });
  }
});

/**
 * GET /api/events/series/:seriesId/follow?userId=...
 * Status: folgt dieser Nutzer der Serie? + Follower-Anzahl.
 */
app.get('/api/events/series/:seriesId/follow', async (req, res) => {
  const seriesId = (req.params.seriesId || '').toString().trim();
  const userId = (req.query.userId || '').toString().trim();
  if (!seriesId) {
    return res.status(400).json({ error: 'seriesId erforderlich' });
  }
  try {
    const [mine, count] = await Promise.all([
      userId
        ? prisma.eventSeriesFollower.findUnique({
            where: { seriesId_userId: { seriesId, userId } },
          })
        : Promise.resolve(null),
      prisma.eventSeriesFollower.count({ where: { seriesId } }),
    ]);
    return res.json({ following: !!mine, seriesId, followerCount: count });
  } catch (err) {
    console.error('❌ Series follow status error:', err.message);
    return res.status(500).json({ error: `Status failed: ${err.message}` });
  }
});

// ============================================================================
// COMMUNITY EVENTS API (/api/community-events)
// Kiro spec: KI-Event-Discovery + Community Events with flag/interest/attendees
// ============================================================================

/**
 * GET /api/community-events
 * List community events by city with optional filters.
 * Query params: city, limit, offset, category, free, ageGroup
 */
app.get('/api/community-events', async (req, res) => {
  const { city, limit = 20, offset = 0, category, free, ageGroup } = req.query;

  try {
    const where = {
      isHidden: false,
      ...(city && { city: { contains: String(city), mode: 'insensitive' } }),
      ...(category && { category: String(category) }),
      ...(free === 'true' && { isFree: true }),
    };

    const events = await prisma.communityEvent.findMany({
      where,
      orderBy: [{ isVerified: 'desc' }, { eventDate: 'asc' }],
      take: Math.min(parseInt(limit, 10) || 20, 100),
      skip: parseInt(offset, 10) || 0,
    });

    const now = new Date();
    const visible = events.filter(e => e.isRecurring || new Date(e.eventDate) >= now);

    const filtered = ageGroup
      ? visible.filter(e => {
          try {
            const groups = JSON.parse(e.ageGroups || '[]');
            return groups.includes(String(ageGroup));
          } catch (_) { return true; }
        })
      : visible;

    res.json(filtered);
  } catch (err) {
    console.error('❌ GET /api/community-events error:', err.message);
    res.status(500).json({ error: `Failed to list community events: ${err.message}` });
  }
});

/**
 * POST /api/community-events
 * Create a new community event. Max 3 per day per creator.
 */
app.post('/api/community-events', async (req, res) => {
  const {
    title, description, category, ageGroups, venue, location, city,
    lat, lon, isPrivateAddress, eventDate, eventEndDate, isRecurring, recurringNote,
    rainPlan, price, isFree, url, imageUrl, organizer, creatorType,
    contactName, contactPhone, contactEmail, accessibility, eventLanguage,
    source, creatorId,
  } = req.body;

  if (!title || !location || !city || !creatorId || !eventDate || !organizer) {
    return res.status(400).json({
      error: 'title, location, city, creatorId, eventDate, organizer sind erforderlich',
    });
  }

  if (String(title).length < 3 || String(title).length > 200) {
    return res.status(400).json({ error: 'Titel muss 3-200 Zeichen lang sein' });
  }

  const text = `${String(title).toLowerCase()} ${String(description || '').toLowerCase()}`;
  const spamKeywords = ['gewalt', 'hass', 'sex', 'nackt', 'missbrauch', 'betrug', 'scam', 'drohung', 'casino', 'kredit'];
  if (spamKeywords.some(kw => text.includes(kw))) {
    return res.status(422).json({ error: 'Inhalt entspricht nicht den Community-Richtlinien' });
  }

  const dayStart = new Date();
  dayStart.setHours(0, 0, 0, 0);
  const todayCount = await prisma.communityEvent.count({
    where: { creatorId: String(creatorId), createdAt: { gte: dayStart } },
  });
  if (todayCount >= 3) {
    return res.status(429).json({ error: 'Maximal 3 Events pro Tag erlaubt' });
  }

  try {
    const event = await prisma.communityEvent.create({
      data: {
        title: String(title).slice(0, 200),
        description: description ? String(description).slice(0, 2000) : '',
        category: category ? String(category).slice(0, 50) : 'sonstiges',
        ageGroups: Array.isArray(ageGroups) ? JSON.stringify(ageGroups) : '["alle"]',
        venue: venue ? String(venue) : 'beides',
        location: String(location).slice(0, 200),
        city: String(city).slice(0, 100),
        lat: lat != null ? parseFloat(lat) : null,
        lon: lon != null ? parseFloat(lon) : null,
        isPrivateAddress: isPrivateAddress === true,
        eventDate: new Date(eventDate),
        eventEndDate: eventEndDate ? new Date(eventEndDate) : null,
        isRecurring: isRecurring === true,
        recurringNote: recurringNote ? String(recurringNote).slice(0, 200) : null,
        rainPlan: rainPlan ? String(rainPlan).slice(0, 500) : null,
        price: price ? String(price).slice(0, 50) : 'kostenlos',
        isFree: isFree !== false,
        url: url ? String(url).slice(0, 500) : null,
        imageUrl: imageUrl ? String(imageUrl).slice(0, 500) : null,
        organizer: String(organizer).slice(0, 200),
        creatorType: creatorType ? String(creatorType) : 'eltern',
        contactName: contactName ? String(contactName).slice(0, 100) : null,
        contactPhone: contactPhone ? String(contactPhone).slice(0, 50) : null,
        contactEmail: contactEmail ? String(contactEmail).slice(0, 100) : null,
        accessibility: Array.isArray(accessibility) ? JSON.stringify(accessibility) : '[]',
        eventLanguage: eventLanguage ? String(eventLanguage).slice(0, 10) : 'de',
        source: source ? String(source) : 'community',
        creatorId: String(creatorId).slice(0, 100),
      },
    });
    res.status(201).json(event);
  } catch (err) {
    console.error('❌ POST /api/community-events error:', err.message);
    res.status(500).json({ error: `Failed to create community event: ${err.message}` });
  }
});

/**
 * DELETE /api/community-events/:id
 * Delete own community event. Query param: creatorId
 */
app.delete('/api/community-events/:id', async (req, res) => {
  const { id } = req.params;
  const { creatorId } = req.query;

  if (!creatorId) return res.status(400).json({ error: 'creatorId erforderlich' });

  try {
    const event = await prisma.communityEvent.findUnique({ where: { id } });
    if (!event) return res.status(404).json({ error: 'Event nicht gefunden' });
    if (event.creatorId !== String(creatorId)) {
      return res.status(403).json({ error: 'Nur der Ersteller kann das Event löschen' });
    }
    await prisma.communityEvent.delete({ where: { id } });
    res.json({ success: true });
  } catch (err) {
    console.error('❌ DELETE /api/community-events/:id error:', err.message);
    res.status(500).json({ error: `Failed to delete event: ${err.message}` });
  }
});

/**
 * POST /api/community-events/:id/flag
 * Report a community event. Auto-hides after 3 flags.
 */
app.post('/api/community-events/:id/flag', requireVerifiedUser, async (req, res) => {
  const { id } = req.params;
  const userId = req.firebaseUid;
  const { reason } = req.body;

  if (!reason) {
    return res.status(400).json({ error: 'reason erforderlich' });
  }
  const validReasons = ['spam', 'fake', 'unsafe', 'inappropriate', 'expired'];
  if (!validReasons.includes(String(reason))) {
    return res.status(400).json({ error: `reason muss einer sein von: ${validReasons.join(', ')}` });
  }

  try {
    const event = await prisma.communityEvent.findUnique({ where: { id } });
    if (!event) return res.status(404).json({ error: 'Event nicht gefunden' });

    await prisma.communityEventFlag.upsert({
      where: { eventId_userId: { eventId: id, userId: String(userId) } },
      create: { eventId: id, userId: String(userId), reason: String(reason) },
      update: { reason: String(reason) },
    });

    const flagCount = await prisma.communityEventFlag.count({ where: { eventId: id } });
    await prisma.communityEvent.update({
      where: { id },
      data: { flagCount, isHidden: flagCount >= 3 },
    });

    res.json({ success: true, flagCount, autoHidden: flagCount >= 3 });
  } catch (err) {
    console.error('❌ POST /api/community-events/:id/flag error:', err.message);
    res.status(500).json({ error: `Failed to flag event: ${err.message}` });
  }
});

/**
 * POST /api/community-events/:id/interest
 * Express interest ("Ich bin auch dabei!") with optional message.
 */
app.post('/api/community-events/:id/interest', async (req, res) => {
  const { id } = req.params;
  const { userId, displayName, message } = req.body;

  if (!userId) return res.status(400).json({ error: 'userId erforderlich' });

  try {
    const event = await prisma.communityEvent.findUnique({ where: { id } });
    if (!event) return res.status(404).json({ error: 'Event nicht gefunden' });

    await prisma.communityEventInterest.upsert({
      where: { eventId_userId: { eventId: id, userId: String(userId) } },
      create: {
        eventId: id,
        userId: String(userId),
        displayName: displayName ? String(displayName).slice(0, 100) : 'Elternteil',
        message: message ? String(message).slice(0, 500) : null,
      },
      update: {
        displayName: displayName ? String(displayName).slice(0, 100) : 'Elternteil',
        message: message ? String(message).slice(0, 500) : null,
      },
    });

    const interestCount = await prisma.communityEventInterest.count({ where: { eventId: id } });
    await prisma.communityEvent.update({ where: { id }, data: { interestCount } });

    res.json({ success: true, interestCount });
  } catch (err) {
    console.error('❌ POST /api/community-events/:id/interest error:', err.message);
    res.status(500).json({ error: `Failed to register interest: ${err.message}` });
  }
});

/**
 * GET /api/community-events/:id/attendees
 * List users who expressed interest ("Ich bin auch dabei!").
 */
app.get('/api/community-events/:id/attendees', async (req, res) => {
  const { id } = req.params;

  try {
    const interests = await prisma.communityEventInterest.findMany({
      where: { eventId: id },
      orderBy: { createdAt: 'asc' },
      take: 50,
    });

    const attendees = interests.map(i => ({
      userId: i.userId,
      displayName: i.displayName,
      initial: i.displayName ? i.displayName.charAt(0).toUpperCase() : '?',
      message: i.message,
      joinedAt: i.createdAt,
      isNetworkContact: false,
    }));

    res.json({ attendees, total: interests.length });
  } catch (err) {
    console.error('❌ GET /api/community-events/:id/attendees error:', err.message);
    res.status(500).json({ error: `Failed to load attendees: ${err.message}` });
  }
});

// ============================================================================
// TREASURE ITEMS API (Verschenkmarkt)
// ============================================================================

/**
 * POST /api/treasures
 * Create a new treasure item
 */
app.post('/api/treasures', async (req, res) => {
  const {
    userId: requestedUserId, title, description, location, latitude, longitude,
    category, condition, isFree, price, visibility, shareRadiusKm, photoUrl, photoUrls
  } = req.body;
  const userId = resolveVerifiedUserId(req, requestedUserId);

  // Validate required fields
  if (!userId || !title || !location || latitude === undefined || longitude === undefined) {
    return res.status(400).json({
      error: 'userId, title, location, latitude, longitude erforderlich'
    });
  }
  if (hasExplicitUserMismatch(req, requestedUserId)) {
    return res.status(403).json({ error: 'Anzeige kann nur fuer das eigene Konto erstellt werden' });
  }
  // Echter Bann: gesperrte Nutzer koennen nichts mehr im Verschenkmarkt einstellen.
  if (await isUserSuspended(userId.toString().trim())) return respondSuspended(res);

  // Validate coordinates
  if (!treasureGeometry.position(latitude, longitude)) {
    return res.status(400).json({ error: 'Ungültige Koordinaten' });
  }
  const publicationRadius = treasureGeometry.radiusKm(shareRadiusKm);
  if (publicationRadius === null) {
    return res.status(400).json({ error: 'Ungültiger Veröffentlichungsradius' });
  }

  // Validate title length
  if (String(title).length < 3 || String(title).length > 200) {
    return res.status(400).json({ error: 'Titel muss 3-200 Zeichen lang sein' });
  }

  try {
    // Calculate expiry: 30 days from now
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 30);
    const severeContent = isTreasureContentSevere({ title, description });

    const treasure = await prisma.treasureItem.create({
      data: {
        userId: String(userId).slice(0, 100),
        title: String(title).slice(0, 200),
        description: description ? String(description).slice(0, 2000) : null,
        location: String(location).slice(0, 200),
        latitude: parseFloat(latitude),
        longitude: parseFloat(longitude),
        category: category ? String(category).slice(0, 50) : 'other',
        condition: condition ? String(condition).slice(0, 50) : 'good',
        isFree: isFree !== false,
        price: isFree === false && price ? parseFloat(price) : null,
        visibility: visibility ? String(visibility).slice(0, 50) : 'nearby',
        shareRadiusKm: publicationRadius,
        photoUrl: photoUrl ? String(photoUrl).slice(0, 500) : null,
        photoUrls: Array.isArray(photoUrls)
          ? photoUrls
              .map(u => String(u).slice(0, 500))
              .filter(u => u.startsWith('http'))
              .slice(0, 8)
          : (photoUrl ? [String(photoUrl).slice(0, 500)] : []),
        expiresAt: expiresAt,
        status: severeContent ? 'archived' : 'available',
      },
      include: { ratings: true, handovers: true }
    });

    res.status(201).json({
      treasure,
      moderation: {
        autoArchivedOnCreate: severeContent,
        reason: severeContent ? 'severe_content_keyword_match' : 'none',
      },
    });
  } catch (err) {
    console.error('❌ Treasure creation error:', err.message, err);
    res.status(500).json({ error: `Treasure creation failed: ${err.message}` });
  }
});

/**
 * GET /api/treasures
 * List/discover treasures with filtering and pagination
 */
app.get('/api/treasures', async (req, res) => {
  const {
    status = 'available',
    visibility = 'nearby',
    category,
    condition,
    maxResults = 50,
    offset = 0,
    latitude,
    longitude,
    radiusKm = 10
  } = req.query;

  try {
    const geographic = latitude !== undefined || longitude !== undefined;
    const viewer = geographic ? treasureGeometry.position(latitude, longitude) : null;
    const requestedRadius = treasureGeometry.radiusKm(radiusKm);
    if ((geographic && !viewer) || requestedRadius === null) {
      return res.status(400).json({ error: 'Valid coordinates and positive radiusKm required' });
    }
    const limit = Math.min(Math.max(parseInt(maxResults, 10) || 50, 1), 100);
    const start = Math.max(parseInt(offset, 10) || 0, 0);
    const query = {
      where: {
        status: status,
        visibility: visibility,
        ...(category && { category: String(category) }),
        ...(condition && { condition: String(condition) })
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'asc' }],
      include: { ratings: true, handovers: true }
    };
    let results;
    if (geographic) {
      // Scan bounded DB batches before proximity sorting and result pagination.
      const matches = [];
      const batchSize = 200;
      for (let skip = 0; ; skip += batchSize) {
        const batch = await prisma.treasureItem.findMany({ ...query, take: batchSize, skip });
        matches.push(...treasureGeometry.discover(batch, viewer, requestedRadius));
        if (batch.length < batchSize) break;
      }
      results = matches.sort((a, b) => a.distance - b.distance).slice(start, start + limit);
    } else {
      const treasures = await prisma.treasureItem.findMany({ ...query, take: limit, skip: start });
      results = treasures.map(treasure => ({ treasure, distance: null }));
    }
    const formattedTreasures = results.map(({ treasure, distance }) => publicTreasure(treasure, {
      distanceKm: distance === null ? null : Math.round(distance * 1000) / 1000,
    }));

    res.json({ treasures: formattedTreasures, total: formattedTreasures.length });
  } catch (err) {
    console.error('❌ Treasures list error:', err.message);
    res.status(500).json({ error: `Failed to list treasures: ${err.message}` });
  }
});

function isAdminTokenAuthorized(req) {
  if (!backendApiToken) return false;
  const authHeader = req.headers.authorization || '';
  return authHeader === `Bearer ${backendApiToken}`;
}

function normalizeTreasureReportReason(value) {
  return String(value || '')
    .trim()
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .slice(0, 120);
}

function isTreasureReportSevere({ reason, note }) {
  const reasonText = normalizeTreasureReportReason(reason);
  const noteText = String(note || '').toLowerCase();
  const text = `${reasonText} ${noteText}`;
  const severeKeywords = [
    'gewalt',
    'hass',
    'sex',
    'nackt',
    'missbrauch',
    'betrug',
    'scam',
    'drohung',
  ];
  return severeKeywords.some(keyword => text.includes(keyword));
}

function shouldAutoArchiveTreasure({ severe, recentReportCount }) {
  if (severe) return true;
  return recentReportCount >= 3;
}

function normalizeRecipeReportReason(value) {
  return String(value || '')
    .trim()
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .slice(0, 120);
}

function isRecipeReportSevere({ reason, details }) {
  const text = `${normalizeRecipeReportReason(reason)} ${String(details || '').toLowerCase()}`;
  const severeKeywords = [
    'gewalt',
    'hass',
    'sex',
    'nackt',
    'missbrauch',
    'betrug',
    'scam',
    'drohung',
  ];
  return severeKeywords.some(keyword => text.includes(keyword));
}

function shouldAutoUnpublishRecipe({ severe, recentReportCount }) {
  if (severe) return true;
  return recentReportCount >= 3;
}

function isTreasureContentSevere({ title, description }) {
  const text = `${String(title || '').toLowerCase()} ${String(description || '').toLowerCase()}`;
  const severeKeywords = [
    'gewalt',
    'hass',
    'sex',
    'nackt',
    'missbrauch',
    'betrug',
    'scam',
    'drohung',
  ];
  return severeKeywords.some(keyword => text.includes(keyword));
}

function toFiniteNumber(value) {
  if (typeof value === 'number') return Number.isFinite(value) ? value : 0;
  if (typeof value === 'string') {
    const parsed = Number.parseFloat(value);
    return Number.isFinite(parsed) ? parsed : 0;
  }
  if (typeof value?.toNumber === 'function') {
    try {
      const parsed = value.toNumber();
      return Number.isFinite(parsed) ? parsed : 0;
    } catch (_) {
      return 0;
    }
  }
  return 0;
}

function buildAuthorTrustSummary(recipes) {
  const publishedRecipesCount = recipes.length;
  const activeOffersCount = recipes.filter((recipe) => {
    const category = String(recipe.category || '').toLowerCase();
    const tags = Array.isArray(recipe.tags)
        ? recipe.tags.map((tag) => String(tag).toLowerCase())
        : [];
    return category === 'snack' || tags.includes('angebot') || tags.includes('teilen');
  }).length;

  let weightedRatingSum = 0;
  let ratingWeight = 0;
  let totalReports = 0;
  let completedShares = 0;
  let pendingReservations = 0;
  let lastSharedAt = null;

  for (const recipe of recipes) {
    const ratingCount = Number(recipe.ratingCount || 0);
    const rating = toFiniteNumber(recipe.rating);
    weightedRatingSum += rating * ratingCount;
    ratingWeight += ratingCount;
    totalReports += Number(recipe.reportedCount || 0);
    completedShares += Number(recipe.completedReservationCount || 0);
    pendingReservations += Number(recipe.pendingReservationCount || 0);
    const reservationUpdatedAt = recipe.latestCompletedAt
      ? new Date(recipe.latestCompletedAt)
      : null;
    if (reservationUpdatedAt && !Number.isNaN(reservationUpdatedAt.getTime())) {
      if (!lastSharedAt || reservationUpdatedAt > lastSharedAt) {
        lastSharedAt = reservationUpdatedAt;
      }
    }
  }

  const averageRating = ratingWeight > 0 ? weightedRatingSum / ratingWeight : 0;
  const completionRate = completedShares + pendingReservations > 0
    ? completedShares / (completedShares + pendingReservations)
    : 0;
  let level = 'new';
  let label = 'Neu im Teilen';
  let reliabilityLevel = 'new';
  let reliabilityLabel = 'Noch wenig Nachweise';

  if (publishedRecipesCount >= 3 && averageRating >= 4 && totalReports === 0) {
    level = 'trusted';
    label = 'Verlaesslich geteilt';
  } else if (publishedRecipesCount >= 2 || activeOffersCount >= 1) {
    level = 'active';
    label = 'Aktiv in der Community';
  }

  if (totalReports === 0 && completedShares >= 2 && completionRate >= 0.85) {
    reliabilityLevel = 'strong';
    reliabilityLabel = 'Sehr verlässlich';
  } else if (totalReports <= 1 && completedShares >= 1 && completionRate >= 0.6) {
    reliabilityLevel = 'solid';
    reliabilityLabel = 'Zuverlässig';
  } else if (completedShares >= 1 || completionRate > 0) {
    reliabilityLevel = 'growing';
    reliabilityLabel = 'Wird verlässlicher';
  }

  return {
    level,
    label,
    publishedRecipesCount,
    activeOffersCount,
    completedShares,
    completionRate: Math.round(completionRate * 100) / 100,
    reliabilityLevel,
    reliabilityLabel,
    lastSharedAt: lastSharedAt ? lastSharedAt.toISOString() : null,
    averageRating: Math.round(averageRating * 100) / 100,
    totalReports,
  };
}

async function buildAuthorTrustMapForRecipes(recipes) {
  const creatorIds = [...new Set(
    recipes
      .map((recipe) => String(recipe.creatorUserId || '').trim())
      .filter(Boolean),
  )];
  if (creatorIds.length === 0) return new Map();

  const authorRecipes = await prisma.sharedRecipe.findMany({
    where: {
      creatorUserId: { in: creatorIds },
      isPublished: true,
    },
    select: {
      creatorUserId: true,
      category: true,
      tags: true,
      rating: true,
      ratingCount: true,
      reportedCount: true,
      offerReservations: {
        select: {
          completedAt: true,
        },
        orderBy: {
          completedAt: 'desc',
        },
      },
    },
  });

  const byAuthor = new Map();
  for (const recipe of authorRecipes) {
    const key = String(recipe.creatorUserId || '').trim();
    if (!key) continue;
    const reservations = Array.isArray(recipe.offerReservations) ? recipe.offerReservations : [];
    const completedReservations = reservations.filter((reservation) => reservation.completedAt);
    const pendingReservations = reservations.filter((reservation) => !reservation.completedAt);
    const items = byAuthor.get(key) || [];
    items.push({
      ...recipe,
      completedReservationCount: completedReservations.length,
      pendingReservationCount: pendingReservations.length,
      latestCompletedAt: completedReservations.reduce((latest, reservation) => {
        if (!latest) return reservation.completedAt;
        return reservation.completedAt > latest ? reservation.completedAt : latest;
      }, null),
    });
    byAuthor.set(key, items);
  }

  const trustMap = new Map();
  for (const [creatorUserId, items] of byAuthor.entries()) {
    trustMap.set(creatorUserId, buildAuthorTrustSummary(items));
  }
  return trustMap;
}

/**
 * POST /api/treasures/:id/report
 * Report a treasure listing for moderation
 */
app.post('/api/treasures/:id/report', requireVerifiedUser, async (req, res) => {
  const { id } = req.params;
  const reporterUserId = req.firebaseUid;
  const { reason, note } = req.body;
  const claimedReporter = String(req.body.reporterUserId || '').trim();
  if (claimedReporter && claimedReporter !== reporterUserId) {
    return res.status(403).json({ error: 'Nur fuer das eigene Konto erlaubt' });
  }

  if (!reason) {
    return res.status(400).json({ error: 'reason erforderlich' });
  }

  const normalizedReason = String(reason).trim();
  if (normalizedReason.length < 3 || normalizedReason.length > 120) {
    return res.status(400).json({ error: 'reason muss 3-120 Zeichen lang sein' });
  }

  try {
    const treasure = await prisma.treasureItem.findUnique({ where: { id } });
    if (!treasure) {
      return res.status(404).json({ error: 'Treasure nicht gefunden' });
    }

    // Avoid duplicate report spam from the same reporter for the same listing.
    const duplicate = await prisma.treasureReport.findFirst({
      where: {
        treasureId: id,
        reporterUserId: String(reporterUserId),
        status: { in: ['pending', 'resolved'] },
      },
      orderBy: { createdAt: 'desc' },
    });
    if (duplicate) {
      return res.status(409).json({ error: 'Dieses Angebot wurde von dir bereits gemeldet' });
    }

    const report = await prisma.treasureReport.create({
      data: {
        treasureId: id,
        reporterUserId: String(reporterUserId).slice(0, 120),
        reason: normalizedReason.slice(0, 120),
        note: note ? String(note).slice(0, 1200) : null,
        status: 'pending',
      },
    });

    const recentReportCount = await prisma.treasureReport.count({
      where: {
        treasureId: id,
        createdAt: {
          gte: new Date(Date.now() - (30 * 24 * 60 * 60 * 1000)),
        },
      },
    });

    const severe = isTreasureReportSevere({ reason: normalizedReason, note });
    let autoAction = 'none';

    if (shouldAutoArchiveTreasure({ severe, recentReportCount })) {
      autoAction = severe ? 'archived_severe' : 'archived_threshold';
      await prisma.$transaction([
        prisma.treasureItem.update({
          where: { id },
          data: {
            status: 'archived',
            updatedAt: new Date(),
          },
        }),
        prisma.treasureReport.updateMany({
          where: {
            treasureId: id,
            status: 'pending',
          },
          data: {
            status: 'resolved',
            moderatorId: 'system-auto',
            moderatorNote: severe
              ? 'Auto-resolved: severe reason triggered immediate archive.'
              : 'Auto-resolved: report threshold reached, listing archived.',
            resolvedAt: new Date(),
            updatedAt: new Date(),
          },
        }),
      ]);
    }

    res.status(201).json({
      report,
      autoModeration: {
        action: autoAction,
        recentReportCount,
      },
    });
  } catch (err) {
    console.error('❌ Treasure report create error:', err.message);
    res.status(500).json({ error: `Failed to create treasure report: ${err.message}` });
  }
});

/**
 * POST /api/treasures/:id/reserve
 * Reserviert einen Schatz für einen Nutzer (erzeugt einen TreasureHandover).
 * Der Verschenker sieht die Reservierung über GET /api/treasures/mine.
 */
app.post('/api/treasures/:id/reserve', async (req, res) => {
  const { id } = req.params;
  const { requesterUserId: requestedRequesterUserId, preferredSlot, handoverMode, message } = req.body;
  const requesterUserId = resolveVerifiedUserId(req, requestedRequesterUserId);

  if (!requesterUserId) {
    return res.status(400).json({ error: 'requesterUserId erforderlich' });
  }
  if (hasExplicitUserMismatch(req, requestedRequesterUserId)) {
    return res.status(403).json({ error: 'Reservierung nur fuer das eigene Konto erlaubt' });
  }

  const ownReservationQuery = {
    where: {
      treasureId: id,
      requesterId: String(requesterUserId),
      status: { in: ['pending', 'reserved'] },
    },
  };

  try {
    const treasure = await prisma.treasureItem.findUnique({
      where: { id },
      include: { handovers: true },
    });
    if (!treasure) {
      return res.status(404).json({ error: 'Treasure nicht gefunden' });
    }
    if (!['available', 'reserved'].includes(treasure.status)) {
      return res.status(410).json({ error: 'Dieses Angebot ist nicht mehr verfügbar' });
    }
    // Eigenes Angebot kann man nicht reservieren
    if (treasure.userId === String(requesterUserId)) {
      return res.status(400).json({ error: 'Du kannst dein eigenes Angebot nicht reservieren' });
    }

    const requester = await prisma.user.findUnique({
      where: { id: String(requesterUserId) },
      select: { id: true },
    });
    if (!requester) {
      return res.status(404).json({ error: 'Interessent nicht als Benutzer registriert' });
    }

    // Doppelte Reservierung desselben Nutzers vermeiden
    const existing = await prisma.treasureHandover.findFirst(ownReservationQuery);
    if (existing) {
      return res.status(200).json({
        handover: existing,
        alreadyReserved: true,
        message: 'Bereits von dir reserviert',
      });
    }
    if (treasure.status !== 'available') {
      return res.status(410).json({ error: 'Dieses Angebot ist nicht mehr verfügbar' });
    }

    const modeNote = handoverMode === 'swap' ? 'Stiller Tausch' : 'Kurz treffen';
    const combinedNotes = [modeNote, message]
      .filter(Boolean)
      .join(' · ')
      .slice(0, 500);

    const handover = await prisma.$transaction(async tx => {
      const claimed = await tx.treasureItem.updateMany({
        where: { id, status: 'available' },
        data: { status: 'reserved', updatedAt: new Date() },
      });
      if (claimed.count !== 1) {
        const error = new Error('Treasure ist nicht mehr verfuegbar');
        error.code = 'TREASURE_UNAVAILABLE';
        throw error;
      }
      return tx.treasureHandover.create({
        data: {
          treasureId: id,
          requesterId: String(requesterUserId).slice(0, 100),
          status: 'reserved',
          location: preferredSlot ? String(preferredSlot).slice(0, 200) : null,
          notes: combinedNotes || null,
          updatedAt: new Date(),
        },
      });
    });
    await sendPushToUser(treasure.userId, {
      title: 'Neue Reservierung',
      body: `Jemand moechte "${treasure.title}" abholen.`,
      data: { type: 'treasure_reservation', treasureId: id, handoverId: handover.id },
    });

    res.status(201).json({
      handover,
      alreadyReserved: false,
      giverUserId: treasure.userId,
      message: 'Reservierung gespeichert. Die schenkende Familie wurde benachrichtigt.',
    });
  } catch (err) {
    console.error('❌ Treasure reserve error:', err.message);
    if (err.code === 'TREASURE_UNAVAILABLE') {
      try {
        const current = await prisma.treasureItem.findUnique({
          where: { id }, select: { status: true },
        });
        if (current?.status === 'reserved') {
          const existing = await prisma.treasureHandover.findFirst(ownReservationQuery);
          if (existing) {
            return res.status(200).json({
              handover: existing,
              alreadyReserved: true,
              message: 'Bereits von dir reserviert',
            });
          }
        }
      } catch (lookupError) {
        console.error('❌ Treasure reserve retry lookup error:', lookupError.message);
        return res.status(500).json({ error: 'Reservierungsstatus konnte nicht geprüft werden' });
      }
      return res.status(410).json({ error: 'Dieses Angebot ist nicht mehr verfügbar' });
    }
    res.status(500).json({ error: `Reservierung fehlgeschlagen: ${err.message}` });
  }
});

/**
 * POST /api/treasures/:id/cancel-reservation
 * Hebt die Reservierung des anfragenden Nutzers auf.
 */
app.post('/api/treasures/:id/cancel-reservation', async (req, res) => {
  const { id } = req.params;
  const { requesterUserId: requestedRequesterUserId } = req.body;
  const requesterUserId = resolveVerifiedUserId(req, requestedRequesterUserId);
  if (!requesterUserId) {
    return res.status(400).json({ error: 'requesterUserId erforderlich' });
  }
  if (hasExplicitUserMismatch(req, requestedRequesterUserId)) {
    return res.status(403).json({ error: 'Stornierung nur fuer das eigene Konto erlaubt' });
  }
  try {
    await prisma.$transaction(async tx => {
      const committed = await tx.treasureHandover.findFirst({
        where: {
          treasureId: id,
          requesterId: String(requesterUserId),
          status: { in: ['confirmed', 'completed'] },
        },
      });
      if (committed) {
        const error = new Error('Bestaetigte oder abgeschlossene Uebergabe kann nicht storniert werden');
        error.code = 'HANDOVER_NOT_CANCELLABLE';
        throw error;
      }
      const cancelled = await tx.treasureHandover.updateMany({
        where: {
          treasureId: id,
          requesterId: String(requesterUserId),
          status: { in: ['pending', 'reserved'] },
        },
        data: { status: 'cancelled', updatedAt: new Date() },
      });
      if (cancelled.count === 0) return;
      const activeCount = await tx.treasureHandover.count({
        where: { treasureId: id, status: { in: ['pending', 'reserved', 'confirmed'] } },
      });
      if (activeCount === 0) {
        await tx.treasureItem.updateMany({
          where: { id, status: 'reserved' },
          data: { status: 'available', updatedAt: new Date() },
        });
      }
    });
    res.json({ success: true });
  } catch (err) {
    console.error('❌ Cancel reservation error:', err.message);
    if (err.code === 'HANDOVER_NOT_CANCELLABLE') {
      return res.status(409).json({ error: err.message });
    }
    res.status(500).json({ error: `Stornierung fehlgeschlagen: ${err.message}` });
  }
});

/**
 * POST /api/treasures/:id/handovers/:handoverId/confirm
 * The owner confirms a reservation for handover.
 */
app.post('/api/treasures/:id/handovers/:handoverId/confirm', async (req, res) => {
  const { id, handoverId } = req.params;
  const requestedUserId = req.body.userId;
  const userId = resolveVerifiedUserId(req, requestedUserId);
  if (!userId) {
    return res.status(400).json({ error: 'userId erforderlich' });
  }
  if (hasExplicitUserMismatch(req, requestedUserId)) {
    return res.status(403).json({ error: 'Bestaetigung nur fuer das eigene Konto erlaubt' });
  }

  try {
    const treasure = await prisma.treasureItem.findUnique({ where: { id } });
    if (!treasure) {
      return res.status(404).json({ error: 'Treasure nicht gefunden' });
    }
    if (treasure.userId !== String(userId)) {
      return res.status(403).json({ error: 'Nur der Ersteller kann eine Reservierung bestaetigen' });
    }
    const handover = await prisma.treasureHandover.findFirst({
      where: { id: handoverId, treasureId: id, status: { in: ['pending', 'reserved'] } },
    });
    if (!handover) {
      return res.status(404).json({ error: 'Aktive Reservierung nicht gefunden' });
    }

    const now = new Date();
    const updated = await prisma.$transaction(async tx => {
      const confirmed = await tx.treasureHandover.update({
        where: { id: handoverId },
        data: { status: 'confirmed', updatedAt: now },
      });
      await tx.treasureHandover.updateMany({
        where: { treasureId: id, id: { not: handoverId }, status: { in: ['pending', 'reserved'] } },
        data: { status: 'cancelled', updatedAt: now },
      });
      await tx.treasureItem.update({
        where: { id },
        data: { status: 'claimed', updatedAt: now },
      });
      return confirmed;
    });
    await sendPushToUser(updated.requesterId, {
      title: 'Uebergabe bestaetigt',
      body: `Die Uebergabe von "${treasure.title}" wurde bestaetigt.`,
      data: { type: 'treasure_handover_update', treasureId: id, handoverId },
    });
    res.json({ handover: updated, message: 'Uebergabe bestaetigt' });
  } catch (err) {
    console.error('❌ Treasure handover confirmation error:', err.message);
    res.status(500).json({ error: `Bestaetigung fehlgeschlagen: ${err.message}` });
  }
});

/**
 * POST /api/treasures/:id/handovers/:handoverId/complete
 * The owner marks a confirmed handover as completed.
 */
app.post('/api/treasures/:id/handovers/:handoverId/complete', async (req, res) => {
  const { id, handoverId } = req.params;
  const requestedUserId = req.body.userId;
  const userId = resolveVerifiedUserId(req, requestedUserId);
  if (!userId) {
    return res.status(400).json({ error: 'userId erforderlich' });
  }
  if (hasExplicitUserMismatch(req, requestedUserId)) {
    return res.status(403).json({ error: 'Abschluss nur fuer das eigene Konto erlaubt' });
  }

  try {
    const treasure = await prisma.treasureItem.findUnique({ where: { id } });
    if (!treasure) {
      return res.status(404).json({ error: 'Treasure nicht gefunden' });
    }
    if (treasure.userId !== String(userId)) {
      return res.status(403).json({ error: 'Nur der Ersteller kann die Uebergabe abschliessen' });
    }
    const handover = await prisma.treasureHandover.findFirst({
      where: { id: handoverId, treasureId: id, status: 'confirmed' },
    });
    if (!handover) {
      return res.status(404).json({ error: 'Bestaetigte Uebergabe nicht gefunden' });
    }

    const now = new Date();
    const updated = await prisma.$transaction(async tx => {
      const completed = await tx.treasureHandover.update({
        where: { id: handoverId },
        data: { status: 'completed', updatedAt: now },
      });
      await tx.treasureItem.update({
        where: { id },
        data: { status: 'archived', updatedAt: now },
      });
      return completed;
    });
    await sendPushToUser(updated.requesterId, {
      title: 'Uebergabe abgeschlossen',
      body: `"${treasure.title}" wurde als uebergeben markiert.`,
      data: { type: 'treasure_handover_update', treasureId: id, handoverId },
    });
    res.json({ handover: updated, message: 'Uebergabe abgeschlossen' });
  } catch (err) {
    console.error('❌ Treasure handover completion error:', err.message);
    res.status(500).json({ error: `Abschluss fehlgeschlagen: ${err.message}` });
  }
});

/**
 * GET /api/treasures/mine?userId=...
 * Liefert die eigenen Angebote MIT Reservierungen (für den Verschenker)
 * plus die vom Nutzer reservierten Artikel (für den Abholer).
 */
app.get('/api/treasures/mine', async (req, res) => {
  const userId = String(req.query.userId || '').trim();
  if (!userId) {
    return res.status(400).json({ error: 'userId erforderlich' });
  }
  if (!(await authorizeAccountOwner(req, res, userId))) return;

  try {
    // Eigene Angebote + wer sie reserviert hat
    const myOffers = await prisma.treasureItem.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      include: { handovers: true },
      take: 100,
    });

    // Reservierungen die der Nutzer selbst gemacht hat
    const myReservations = await prisma.treasureHandover.findMany({
      where: {
        requesterId: userId,
        status: { in: ['pending', 'reserved', 'confirmed'] },
      },
      orderBy: { createdAt: 'desc' },
      take: 100,
      include: { treasure: { select: { title: true } } },
    });

    res.json({
      offers: myOffers.map(t => ({
        id: t.id,
        title: t.title,
        photoUrl: t.photoUrl,
        status: t.status,
        reservations: (t.handovers || [])
          .filter(h =>
            h.status === 'reserved' ||
            h.status === 'pending' ||
            h.status === 'confirmed'
          )
          .map(h => ({
            id: h.id,
            requesterId: h.requesterId,
            status: h.status,
            location: h.location,
            notes: h.notes,
            createdAt: h.createdAt,
          })),
      })),
      reservedByMe: myReservations.map(h => ({
        id: h.id,
        treasureId: h.treasureId,
        treasureTitle: h.treasure.title,
        status: h.status,
        location: h.location,
        createdAt: h.createdAt,
      })),
    });
  } catch (err) {
    console.error('❌ Treasures mine error:', err.message);
    res.status(500).json({ error: `Failed to load: ${err.message}` });
  }
});

/**
 * GET /api/treasures/reports
 * List treasure reports (admin token required)
 */
app.get('/api/treasures/reports', requireAdmin, async (req, res) => {
  const {
    status,
    maxResults = 50,
    offset = 0,
  } = req.query;

  try {
    const reports = await prisma.treasureReport.findMany({
      where: {
        ...(status ? { status: String(status) } : {}),
      },
      orderBy: { createdAt: 'desc' },
      take: Math.min(parseInt(maxResults, 10) || 50, 100),
      skip: parseInt(offset, 10) || 0,
      include: {
        treasure: {
          select: {
            id: true,
            title: true,
            userId: true,
            status: true,
            createdAt: true,
          },
        },
      },
    });

    res.json({ reports, total: reports.length });
  } catch (err) {
    console.error('❌ Treasure report list error:', err.message);
    res.status(500).json({ error: `Failed to list treasure reports: ${err.message}` });
  }
});

/**
 * POST /api/treasures/reports/:reportId/resolve
 * Resolve or dismiss a treasure report (admin token required)
 */
app.post('/api/treasures/reports/:reportId/resolve', requireAdmin, async (req, res) => {
  const { reportId } = req.params;
  const { action = 'resolved', moderatorId, moderatorNote } = req.body;
  // resolved = Meldung berechtigt -> Angebot archivieren (ausser archiveListing=false).
  // dismissed = Meldung unberechtigt -> Angebot nur auf ausdruecklichen Wunsch
  // (restoreListing=true) wieder freigeben, z.B. nach einer Auto-Archivierung.
  const archiveListing = req.body.archiveListing !== false;
  const restoreListing = req.body.restoreListing === true;
  const normalizedAction = String(action).trim();
  const allowedActions = new Set(['resolved', 'dismissed']);

  if (!allowedActions.has(normalizedAction)) {
    return res.status(400).json({ error: 'action muss resolved oder dismissed sein' });
  }

  try {
    const existing = await prisma.treasureReport.findUnique({ where: { id: reportId } });
    if (!existing) {
      return res.status(404).json({ error: 'Report nicht gefunden' });
    }

    const moderatorIdentity = moderatorId
      ? String(moderatorId).slice(0, 120)
      : (req.firebaseUid || null);
    const updated = await prisma.treasureReport.update({
      where: { id: reportId },
      data: {
        status: normalizedAction,
        moderatorId: moderatorIdentity,
        moderatorNote: moderatorNote ? String(moderatorNote).slice(0, 1200) : null,
        resolvedAt: new Date(),
        updatedAt: new Date(),
      },
      include: {
        treasure: {
          select: {
            id: true,
            title: true,
            userId: true,
          },
        },
      },
    });

    let listingAction = 'none';
    if (normalizedAction === 'resolved' && archiveListing) {
      await prisma.treasureItem.updateMany({
        where: { id: existing.treasureId, status: { not: 'archived' } },
        data: { status: 'archived', updatedAt: new Date() },
      });
      listingAction = 'archived';
    } else if (normalizedAction === 'dismissed' && restoreListing) {
      await prisma.treasureItem.updateMany({
        where: { id: existing.treasureId, status: 'archived' },
        data: { status: 'available', updatedAt: new Date() },
      });
      listingAction = 'restored';
    }

    res.json({ report: updated, listingAction });
  } catch (err) {
    console.error('❌ Treasure report resolve error:', err.message);
    res.status(500).json({ error: `Failed to resolve treasure report: ${err.message}` });
  }
});

/**
 * GET /api/treasures/:id
 * Get single treasure details
 */
app.get('/api/treasures/:id', async (req, res) => {
  const { id } = req.params;

  try {
    const treasure = await prisma.treasureItem.findUnique({
      where: { id },
      include: { handovers: { select: { status: true } } }
    });

    if (!treasure) {
      return res.status(404).json({ error: 'Treasure nicht gefunden' });
    }

    // Increment view count
    await prisma.treasureItem.update({
      where: { id },
      data: { views: { increment: 1 } }
    });

    const formattedTreasure = publicTreasure(treasure);

    res.json({ treasure: formattedTreasure });
  } catch (err) {
    console.error('❌ Treasure detail error:', err.message);
    res.status(500).json({ error: `Failed to get treasure: ${err.message}` });
  }
});

/**
 * PUT /api/treasures/:id
 * Update treasure (owner only)
 */
app.put('/api/treasures/:id', async (req, res) => {
  const { id } = req.params;
  const { userId: requestedUserId, title, description, location, latitude, longitude, condition, status } = req.body;
  const userId = resolveVerifiedUserId(req, requestedUserId);

  if (!userId) {
    return res.status(400).json({ error: 'userId erforderlich' });
  }
  if (hasExplicitUserMismatch(req, requestedUserId)) {
    return res.status(403).json({ error: 'Bearbeitung nur fuer das eigene Konto erlaubt' });
  }

  try {
    // Verify ownership
    const treasure = await prisma.treasureItem.findUnique({ where: { id } });
    if (!treasure) {
      return res.status(404).json({ error: 'Treasure nicht gefunden' });
    }

    if (treasure.userId !== String(userId)) {
      return res.status(403).json({ error: 'Nur der Ersteller kann das Treasure bearbeiten' });
    }

    // Validate coordinates if provided
    if (latitude !== undefined && longitude !== undefined) {
      if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
        return res.status(400).json({ error: 'Ungültige Koordinaten' });
      }
    }

    const updatedTreasure = await prisma.treasureItem.update({
      where: { id },
      data: {
        ...(title && { title: String(title).slice(0, 200) }),
        ...(description !== undefined && { description: description ? String(description).slice(0, 2000) : null }),
        ...(location && { location: String(location).slice(0, 200) }),
        ...(latitude !== undefined && { latitude: parseFloat(latitude) }),
        ...(longitude !== undefined && { longitude: parseFloat(longitude) }),
        ...(condition && { condition: String(condition).slice(0, 50) }),
        ...(status && { status: String(status).slice(0, 50) }),
        updatedAt: new Date()
      },
      include: { ratings: true, handovers: true }
    });

    res.json({ treasure: updatedTreasure });
  } catch (err) {
    console.error('❌ Treasure update error:', err.message);
    res.status(500).json({ error: `Failed to update treasure: ${err.message}` });
  }
});

/**
 * DELETE /api/treasures/:id
 * Delete treasure (owner only)
 * Query param: userId
 */
app.delete('/api/treasures/:id', async (req, res) => {
  const { id } = req.params;
  const requestedUserId = typeof req.query.userId === 'string'
    ? req.query.userId
    : '';
  const userId = resolveVerifiedUserId(req, requestedUserId);

  if (!userId) {
    return res.status(400).json({ error: 'userId erforderlich' });
  }
  if (hasExplicitUserMismatch(req, requestedUserId)) {
    return res.status(403).json({ error: 'Loeschung nur fuer das eigene Konto erlaubt' });
  }

  try {
    // Verify ownership
    const treasure = await prisma.treasureItem.findUnique({ where: { id } });
    if (!treasure) {
      return res.status(404).json({ error: 'Treasure nicht gefunden' });
    }

    if (treasure.userId !== String(userId)) {
      return res.status(403).json({ error: 'Nur der Ersteller kann das Treasure löschen' });
    }

    await prisma.treasureItem.delete({ where: { id } });
    res.json({ success: true });
  } catch (err) {
    console.error('❌ Treasure delete error:', err.message);
    res.status(500).json({ error: `Failed to delete treasure: ${err.message}` });
  }
});

// Zentrale Fehler-Middleware: faengt unbehandelte Fehler aus allen Routen ab,
// liefert dem Client eine generische Meldung (kein err.message-/Stacktrace-Leak)
// und protokolliert Details nur serverseitig. Muss als LETZTE Middleware nach
// allen Routen stehen; Express erkennt sie an der 4-Parameter-Signatur.
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  // Multer-/Body-Parser-/JSON-Fehler bekommen einen passenden 4xx-Code.
  const status = Number.isInteger(err?.status) && err.status >= 400 && err.status < 600
    ? err.status
    : (err?.type === 'entity.parse.failed' ? 400 : 500);
  const method = req?.method || 'UNKNOWN';
  const route = req?.path || 'unknown';
  console.error(`Unhandled error on ${method} ${route}:`, err?.code || err?.name || err?.message || 'Error');
  if (res.headersSent) {
    return next(err);
  }
  const clientMessage = status >= 500
    ? 'Serverfehler. Bitte spaeter erneut versuchen.'
    : (status === 400 ? 'Ungueltige Anfrage.' : 'Anfrage nicht moeglich.');
  return res.status(status).json({ error: clientMessage, code: 'request_failed' });
});

// Server starten mit Prisma Initialization
(async () => {
  await initializePrisma();
  app.listen(PORT, '0.0.0.0', () => {
    if (allowedOrigins.length > 0) {
      console.log(`🌐 CORS allowlist aktiv (${allowedOrigins.length} Origin(s))`);
    } else if (isProduction) {
      console.warn('⚠️ CORS allowlist fehlt in Produktion; Browser-Origin-Requests werden blockiert');
    } else {
      console.log('🌐 CORS allowlist nicht gesetzt, alle Origins erlaubt');
    }
    if (requireAuthForWrites) {
      console.log('🔐 Write-Auth aktiv (Bearer Token erforderlich)');
    } else {
      console.log('🔓 Write-Auth deaktiviert (REQUIRE_AUTH_FOR_WRITES=0)');
    }
    console.log(`✅ Parentpeak Backend läuft auf http://localhost:${PORT}`);
    console.log(`📍 API verfügbar unter http://localhost:${PORT}/api`);
  });
})();
