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

// Firebase Admin — initialised lazily so the server starts without credentials
// in local dev. Set GOOGLE_APPLICATION_CREDENTIALS or FIREBASE_SERVICE_ACCOUNT_JSON.
let firebaseAdmin = null;
try {
  const admin = require('firebase-admin');
  const serviceAccountJson = (process.env.FIREBASE_SERVICE_ACCOUNT_JSON || '').trim();
  if (serviceAccountJson) {
    const serviceAccount = JSON.parse(serviceAccountJson);
    if (!admin.apps.length) {
      admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
    }
    firebaseAdmin = admin;
    console.log('🔑 Firebase Admin SDK initialisiert');
  } else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    if (!admin.apps.length) {
      admin.initializeApp({ credential: admin.credential.applicationDefault() });
    }
    firebaseAdmin = admin;
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
  limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB
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
const prismaPool = new Pool({
  connectionString: databaseUrl,
  ssl: useDatabaseSsl ? { rejectUnauthorized: false } : undefined,
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

function ensureInternalModeratorAccess({ email, displayName }) {
  if (isInternalModeratorEmail(email)) {
    return {
      allowed: true,
      normalizedEmail: String(email || '').trim().toLowerCase(),
      normalizedDisplayName: String(displayName || '').trim(),
    };
  }

  return {
    allowed: false,
    normalizedEmail: String(email || '').trim().toLowerCase(),
    normalizedDisplayName: String(displayName || '').trim(),
  };
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

function buildWeeklyImpulseResponse({ schema, viewerUserId }) {
  const today = new Date().toISOString().slice(0, 10);
  const topic = getTodayImpulseTopic();
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

  const contentBody =
    `${topic.parent_lens}\n\n` +
    `Drei alltagsnahe Impulse:\n` +
    `- ${topic.parent_tips[0]}\n` +
    `- ${topic.parent_tips[1]}\n` +
    `- ${topic.parent_tips[2]}`;

  return {
    id: impulseId,
    title: topic.title,
    hero_headline: 'Dein Tagesimpuls für heute',
    hero_description: topic.parent_lens,
    content_body: contentBody,
    practical_tip: topic.practical_tip,
    audio_script:
      `Hallo und schön, dass du da bist. ${topic.parent_lens} ` +
      `${topic.practical_tip} Du machst das gut.`,
    category: topic.category,
    publish_date: today,
    companion_impulses: [
      {
        id: `${impulseId}_quick`,
        title: 'Heute in 2 Minuten',
        summary: topic.companion_quick,
        duration_label: '2 Min',
        format_label: 'Sofort-Impuls',
      },
      {
        id: `${impulseId}_understand`,
        title: 'Kurz verstanden',
        summary: topic.parent_lens,
        duration_label: '3 Min',
        format_label: 'Verstehen',
      },
      {
        id: `${impulseId}_practice`,
        title: 'Praxis für heute',
        summary: topic.parent_tips[0],
        duration_label: '4 Min',
        format_label: 'Praxis',
      },
      {
        id: `${impulseId}_reflect`,
        title: 'Abend-Reflexion',
        summary: topic.companion_reflect,
        duration_label: '2 Min',
        format_label: 'Reflexion',
      },
      {
        id: `${impulseId}_deepdive`,
        title: 'Tipp für den Alltag',
        summary: topic.parent_tips[1],
        duration_label: '5 Min',
        format_label: 'Artikel',
      },
    ],
    discussion_prompt: {
      id: `${impulseId}_discussion`,
      title: 'Frage des Tages',
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

// JWT verification helper: verifies a Firebase ID token if Admin SDK is
// available; otherwise accepts requests transparently (dev/fallback mode).
async function verifyFirebaseIdToken(req) {
  if (!firebaseAdmin) return { uid: null, verified: false };
  const authHeader = req.headers.authorization || '';
  if (!authHeader.startsWith('Bearer ')) return { uid: null, verified: false };
  const idToken = authHeader.slice(7);
  try {
    const decoded = await firebaseAdmin.auth().verifyIdToken(idToken);
    return { uid: decoded.uid, verified: true };
  } catch (_) {
    return { uid: null, verified: false };
  }
}

// Middleware: if FIREBASE_REQUIRE_AUTH=1 AND Firebase Admin is configured,
// reject write requests whose token does not match the acting userId.
const firebaseRequireAuth = (process.env.FIREBASE_REQUIRE_AUTH || '0') === '1';

async function firebaseAuthMiddleware(req, res, next) {
  if (!firebaseRequireAuth || !firebaseAdmin || !WRITE_METHODS.has(req.method)) {
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

  // Calendar and todo endpoints: accept userId from request body as lightweight auth.
  // Firebase token verification is still attempted; body userId is the fallback.
  const noTokenPaths = ['/calendar/events', '/todo', '/todos', '/shopping', '/friend-chat', '/api/friends'];
  if (noTokenPaths.some(p => req.path === p || req.path.startsWith(p + '/'))) {
    const authHeader = req.headers.authorization || '';
    if (authHeader.startsWith('Bearer ') && firebaseAdmin) {
      const { uid, verified } = await verifyFirebaseIdToken(req);
      if (verified) req.firebaseUid = uid;
    }
    // Always continue — userId in body identifies the owner
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
const parentMatchingAllowedActions = new Set(['like', 'report', 'block']);
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
      "age" INTEGER NOT NULL,
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
  socialSchemaEnsured = true;
}

function mapParentMatchingProfileForClient(profile) {
  return {
    id: profile.id,
    ownerUserId: profile.ownerUserId || null,
    name: profile.name,
    age: profile.age,
    city: profile.city,
    latitude: profile.latitude ?? null,
    longitude: profile.longitude ?? null,
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

  const reverseActions = await prisma.parentMatchingAction.findMany({
    where: {
      familyId,
      actorUserId: { in: targetOwnerIds },
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
    .filter(item => item.familyId === familyId)
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
const userEntitlements = new Map();

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

async function ensurePaymentContext(eventId, hosterId) {
  const trimmedEventId = (eventId || '').toString().trim();
  const trimmedHosterId = (hosterId || '').toString().trim();

  if (!trimmedEventId || !trimmedHosterId) {
    throw new Error('eventId und hosterId sind erforderlich');
  }

  const [eventRecord, userRecord] = await Promise.all([
    prisma.event.findUnique({ where: { id: trimmedEventId } }),
    prisma.user.findUnique({ where: { id: trimmedHosterId } }),
  ]);

  if (!eventRecord) {
    throw new Error('Event nicht gefunden');
  }

  if (!userRecord) {
    throw new Error('Hoster nicht gefunden');
  }

  return { eventId: trimmedEventId, hosterId: trimmedHosterId };
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
    amount: Number(record.amount),
    status,
    paymentMethod: audit.paymentMethod || 'stripe',
    providerTransactionRef: audit.providerTransactionRef || record.stripePaymentIntentId || null,
    providerVerified: Boolean(record.verifiedAt) || audit.providerVerified === true,
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

function mapEventRecordToApiItem(record, options = {}) {
  const memoryEvent = getInMemoryEventById(record.id);
  const currentParticipants = Number(options.currentParticipants || 0);
  return {
    id: record.id,
    hosterId: record.hosterId,
    title: record.title,
    description: record.description || '',
    category: record.eventType || memoryEvent?.category || 'other',
    ageGroups: Array.isArray(memoryEvent?.ageGroups) ? memoryEvent.ageGroups : [],
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
    status: record.status === 'invited' ? 'pending' : record.status,
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
    status: record.status,
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
  if (!provider || !providerTransactionRef) {
    return {
      ok: false,
      code: 'invalid_payload',
      httpStatus: 400,
      error: 'provider und providerTransactionRef sind erforderlich',
    };
  }

  if ((targetStatus === 'completed' || targetStatus === 'refunded') && !verified) {
    return {
      ok: false,
      code: 'verification_required',
      httpStatus: 409,
      error: `${targetStatus} nur mit verified=true erlaubt`,
    };
  }

  try {
    let record = null;

    if (transactionId) {
      record = await prisma.paymentTransaction.findUnique({ where: { id: transactionId } });
    }

    if (!record && provider === 'stripe' && providerTransactionRef) {
      record = await prisma.paymentTransaction.findFirst({
        where: { stripePaymentIntentId: providerTransactionRef },
      });
    }

    if (!record && providerTransactionRef) {
      record = await prisma.paymentTransaction.findFirst({
        where: { idempotencyKey: `${provider}:${providerTransactionRef}` },
      });
    }

    if (!record) {
      return {
        ok: false,
        code: 'not_found',
        httpStatus: 404,
        error: 'Transaktion nicht gefunden',
      };
    }

    const statusUpdate = await applyTransactionStatusUpdateByRecord(record, targetStatus);
    if (!statusUpdate.ok) {
      return statusUpdate;
    }

    const currentRecord = await prisma.paymentTransaction.findUnique({ where: { id: record.id } });
    const currentAudit = getPaymentAuditDetails(currentRecord);
    const nowIso = new Date().toISOString();
    const enhanced = await prisma.paymentTransaction.update({
      where: { id: record.id },
      data: {
        verifiedAt: verified ? new Date(nowIso) : currentRecord.verifiedAt,
        verifiedByType: verified ? 'webhook' : currentRecord.verifiedByType,
        auditDetails: {
          ...currentAudit,
          providerVerified: currentAudit.providerVerified === true || verified,
          providerEventStatus: targetStatus,
          providerEventReceivedAt: nowIso,
          providerTransactionRef: currentAudit.providerTransactionRef || providerTransactionRef,
          paymentMethod: currentAudit.paymentMethod || provider,
        },
      },
    });

    return { ok: true, item: mapPaymentRecordToApiItem(enhanced) };
  } catch (error) {
    console.error('Prisma payment provider update fallback:', error?.message || error);
  }

  const index = paymentTransactions.findIndex(item => {
    if (transactionId && item.id === transactionId) {
      return true;
    }
    return (
      item.paymentMethod === provider &&
      (item.providerTransactionRef || '') === providerTransactionRef
    );
  });

  if (index === -1) {
    return {
      ok: false,
      code: 'not_found',
      httpStatus: 404,
      error: 'Transaktion nicht gefunden',
    };
  }

  const statusUpdate = await applyTransactionStatusUpdateByIndex(index, targetStatus);
  if (!statusUpdate.ok) {
    return statusUpdate;
  }

  const nowIso = new Date().toISOString();
  const enhanced = {
    ...statusUpdate.item,
    providerVerified: paymentTransactions[index].providerVerified || verified,
    providerEventStatus: targetStatus,
    providerEventReceivedAt: nowIso,
  };
  paymentTransactions[index] = enhanced;

  return { ok: true, item: enhanced };
}

function ensureEntitlement(userId, options = {}) {
  const existing = userEntitlements.get(userId);
  const nowIso = new Date().toISOString();
  const registeredAtHint = asIsoDate(options.registeredAt);
  const isPremiumHint = options.isPremium === true;

  if (!existing) {
    const created = {
      userId,
      registeredAt: registeredAtHint || nowIso,
      isPremium: isPremiumHint,
      updatedAt: nowIso,
    };
    userEntitlements.set(userId, created);
    return created;
  }

  if (registeredAtHint) {
    existing.registeredAt = existing.registeredAt && existing.registeredAt < registeredAtHint
      ? existing.registeredAt
      : registeredAtHint;
  }

  if (isPremiumHint) {
    existing.isPremium = true;
  }

  existing.updatedAt = nowIso;
  userEntitlements.set(userId, existing);
  return existing;
}

function buildEntitlementStatus(record) {
  const betaFreeAccess = `${process.env.BETA_FREE_ACCESS || '1'}`.toLowerCase() !== '0'
    && `${process.env.BETA_FREE_ACCESS || '1'}`.toLowerCase() !== 'false';
  const trialDays = 30;
  const now = new Date();
  const registeredAt = new Date(record.registeredAt);
  const configuredLaunchDate = asIsoDate(process.env.PUBLIC_LAUNCH_DATE);
  const publicLaunchDate = configuredLaunchDate ? new Date(configuredLaunchDate) : null;
  const trialStartsAt = publicLaunchDate && registeredAt < publicLaunchDate
    ? publicLaunchDate
    : registeredAt;
  const trialEndsAt = new Date(trialStartsAt.getTime() + trialDays * 24 * 60 * 60 * 1000);
  const trialMillisRemaining = trialEndsAt.getTime() - now.getTime();
  const trialDaysRemaining = Math.max(0, Math.ceil(trialMillisRemaining / (24 * 60 * 60 * 1000)));
  const trialActive = betaFreeAccess || trialMillisRemaining > 0;
  const hasFullAccess = betaFreeAccess || Boolean(record.isPremium) || trialActive;

  return {
    userId: record.userId,
    isPremium: Boolean(record.isPremium),
    trialActive,
    trialDaysRemaining: betaFreeAccess ? 0 : trialDaysRemaining,
    trialEndsAt: betaFreeAccess ? null : trialEndsAt.toISOString(),
    betaFreeAccess,
    hasFullAccess,
    source: 'server',
    updatedAt: new Date().toISOString(),
  };
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

  if (userEntitlements.has(userId)) {
    removed += 1;
  }

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

  if (userEntitlements.delete(userId)) {
    removed += 1;
  }

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

async function deleteAccountDataByUserIdPrisma(userId, options = {}) {
  const hostedEvents = await prisma.event.findMany({
    where: { hosterId: userId },
    select: { id: true },
  });

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
      removed: familyRequestCount + hostAuditPaymentCount + userCount + parentMatchingActionCount,
      parentMatchingActionCount,
      hostedEventIds: hostedEvents.map(item => item.id),
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

  if (typeof prisma.parentMatchingAction?.deleteMany === 'function') {
    removed += (await prisma.parentMatchingAction.deleteMany({
      where: { actorUserId: userId },
    })).count;
  }

  removed += (await prisma.user.deleteMany({ where: { id: userId } })).count;

  return {
    removed,
    hostedEventIds: hostedEvents.map(item => item.id),
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

app.post('/account/delete-data', async (req, res) => {
  const userId = (req.body.userId || '').toString().trim();
  const dryRun =
    String(req.query.dryRun || req.body.dryRun || '')
      .toLowerCase()
      .trim() === 'true';
  if (!userId) {
    return res.status(400).json({ error: 'userId ist erforderlich' });
  }

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

    const removedEntries = prismaResult.removed + removedMemoryEntries;
    return res.json({
      ok: true,
      userId,
      dryRun,
      removedEntries,
      removedDbEntries: prismaResult.removed,
      removedMemoryEntries,
      mode: 'prisma',
    });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'POST /account/delete-data', error)) {
      return;
    }
    const removedEntries = dryRun
      ? countAccountDataByUserIdInMemory(userId)
      : deleteAccountDataByUserIdInMemory(userId);
    return res.json({ ok: true, userId, dryRun, removedEntries, mode: 'in-memory' });
  }
});

app.get('/entitlements/:userId/status', (req, res) => {
  const userId = (req.params.userId || '').toString().trim();
  if (!userId) {
    return res.status(400).json({ error: 'userId ist erforderlich' });
  }

  const hintPremium = `${req.query.isPremium || ''}`.toLowerCase() === 'true';
  const record = ensureEntitlement(userId, {
    registeredAt: req.query.registeredAt,
    isPremium: hintPremium,
  });
  const item = buildEntitlementStatus(record);
  return res.json({ item });
});

app.post('/entitlements/:userId/activate-premium', (req, res) => {
  const userId = (req.params.userId || '').toString().trim();
  if (!userId) {
    return res.status(400).json({ error: 'userId ist erforderlich' });
  }

  const record = ensureEntitlement(userId, {
    registeredAt: req.body.registeredAt,
    isPremium: true,
  });
  record.isPremium = true;
  record.updatedAt = new Date().toISOString();
  userEntitlements.set(userId, record);

  return res.status(201).json({ item: buildEntitlementStatus(record) });
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

  res.json(buildWeeklyImpulseResponse({ schema, viewerUserId }));
});

app.post('/api/weekly-impulse/community/posts', (req, res) => {
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
  const authorUserId =
    typeof req.body?.authorUserId === 'string' ? req.body.authorUserId.trim() : '';
  const authorEmail =
    typeof req.body?.authorEmail === 'string' ? req.body.authorEmail.trim() : '';

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

app.get('/api/weekly-impulse/community/verification-status', (req, res) => {
  const userId =
    typeof req.query.userId === 'string' ? req.query.userId.trim() : '';
  const email =
    typeof req.query.email === 'string' ? req.query.email.trim().toLowerCase() : '';

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

app.post('/api/weekly-impulse/community/verification-requests', (req, res) => {
  const userId = typeof req.body?.userId === 'string' ? req.body.userId.trim() : '';
  const email = typeof req.body?.email === 'string' ? req.body.email.trim().toLowerCase() : '';
  const displayName = typeof req.body?.displayName === 'string' ? req.body.displayName.trim() : '';
  const roleTitle = typeof req.body?.roleTitle === 'string' ? req.body.roleTitle.trim() : '';
  const organization = typeof req.body?.organization === 'string' ? req.body.organization.trim() : '';
  const note = typeof req.body?.note === 'string' ? req.body.note.trim() : '';

  if (!userId || !email || !displayName || !roleTitle) {
    return res.status(400).json({
      error: 'userId, email, displayName und roleTitle sind erforderlich',
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

app.get('/api/weekly-impulse/community/verification-requests', (req, res) => {
  const reviewerEmail =
    typeof req.query.reviewerEmail === 'string' ? req.query.reviewerEmail.trim() : '';
  const access = ensureInternalModeratorAccess({ email: reviewerEmail, displayName: '' });
  if (!access.allowed) {
    return res.status(403).json({ error: 'Verifizierungszugriff nicht erlaubt' });
  }

  const status =
    typeof req.query.status === 'string' ? req.query.status.trim().toLowerCase() : '';
  const items = weeklyImpulseVerificationRequests.filter(item =>
    status ? item.status === status : true,
  );
  return res.json({ items });
});

app.post('/api/weekly-impulse/community/verification-requests/:requestId/approve', (req, res) => {
  const { requestId } = req.params;
  const reviewerName =
    typeof req.body?.reviewerName === 'string' ? req.body.reviewerName.trim() : '';
  const reviewerEmail =
    typeof req.body?.reviewerEmail === 'string' ? req.body.reviewerEmail.trim() : '';
  const reviewNote =
    typeof req.body?.reviewNote === 'string' ? req.body.reviewNote.trim() : '';
  const verificationLabel =
    typeof req.body?.verificationLabel === 'string' && req.body.verificationLabel.trim()
      ? req.body.verificationLabel.trim()
      : 'Verifizierte Fachstimme';

  const access = ensureInternalModeratorAccess({
    email: reviewerEmail,
    displayName: reviewerName,
  });
  if (!access.allowed) {
    return res.status(403).json({ error: 'Verifizierungszugriff nicht erlaubt' });
  }

  if (!reviewerName) {
    return res.status(400).json({ error: 'reviewerName ist erforderlich' });
  }

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

app.post('/api/weekly-impulse/community/posts/:postId/like', (req, res) => {
  const schema = getWeeklyImpulseSchema();
  if (!schema) {
    return res.status(500).json({ error: 'Weekly Impulse Schema fehlt' });
  }

  const { postId } = req.params;
  const impulseId = typeof req.body?.impulseId === 'string' ? req.body.impulseId.trim() : '';
  const userId = typeof req.body?.userId === 'string' ? req.body.userId.trim() : '';
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

app.post('/api/weekly-impulse/community/posts/:postId/comments', (req, res) => {
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

app.post('/api/weekly-impulse/community/posts/:postId/report', (req, res) => {
  const schema = getWeeklyImpulseSchema();
  if (!schema) {
    return res.status(500).json({ error: 'Weekly Impulse Schema fehlt' });
  }

  const { postId } = req.params;
  const impulseId = typeof req.body?.impulseId === 'string' ? req.body.impulseId.trim() : '';
  const reporterUserId =
    typeof req.body?.reporterUserId === 'string' ? req.body.reporterUserId.trim() : '';
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

app.get('/api/weekly-impulse/community/reports', (req, res) => {
  const schema = getWeeklyImpulseSchema();
  if (!schema) {
    return res.status(500).json({ error: 'Weekly Impulse Schema fehlt' });
  }

  const moderatorEmail =
    typeof req.query.moderatorEmail === 'string' ? req.query.moderatorEmail.trim() : '';
  const access = ensureInternalModeratorAccess({ email: moderatorEmail, displayName: '' });
  if (!access.allowed) {
    return res.status(403).json({ error: 'Moderationszugriff nicht erlaubt' });
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

app.post('/api/weekly-impulse/community/reports/:reportId/resolve', (req, res) => {
  const schema = getWeeklyImpulseSchema();
  if (!schema) {
    return res.status(500).json({ error: 'Weekly Impulse Schema fehlt' });
  }

  const { reportId } = req.params;
  const impulseId = typeof req.body?.impulseId === 'string' ? req.body.impulseId.trim() : '';
  const moderatorName =
    typeof req.body?.moderatorName === 'string' ? req.body.moderatorName.trim() : '';
  const moderatorEmail =
    typeof req.body?.moderatorEmail === 'string' ? req.body.moderatorEmail.trim() : '';
  const moderatorNote =
    typeof req.body?.moderatorNote === 'string' ? req.body.moderatorNote.trim() : '';

  const access = ensureInternalModeratorAccess({
    email: moderatorEmail,
    displayName: moderatorName,
  });
  if (!access.allowed) {
    return res.status(403).json({ error: 'Moderationszugriff nicht erlaubt' });
  }

  if (!impulseId || !reportId || !moderatorName) {
    return res.status(400).json({ error: 'impulseId, reportId und moderatorName sind erforderlich' });
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

app.post('/api/weekly-impulse/community/posts/:postId/moderation-visibility', (req, res) => {
  const schema = getWeeklyImpulseSchema();
  if (!schema) {
    return res.status(500).json({ error: 'Weekly Impulse Schema fehlt' });
  }

  const { postId } = req.params;
  const impulseId = typeof req.body?.impulseId === 'string' ? req.body.impulseId.trim() : '';
  const moderatorName =
    typeof req.body?.moderatorName === 'string' ? req.body.moderatorName.trim() : '';
  const moderatorEmail =
    typeof req.body?.moderatorEmail === 'string' ? req.body.moderatorEmail.trim() : '';
  const moderatorNote =
    typeof req.body?.moderatorNote === 'string' ? req.body.moderatorNote.trim() : '';
  const reportId = typeof req.body?.reportId === 'string' ? req.body.reportId.trim() : '';
  const hidden = req.body?.hidden === true;

  const access = ensureInternalModeratorAccess({
    email: moderatorEmail,
    displayName: moderatorName,
  });
  if (!access.allowed) {
    return res.status(403).json({ error: 'Moderationszugriff nicht erlaubt' });
  }

  if (!impulseId || !postId || !moderatorName) {
    return res.status(400).json({ error: 'impulseId, postId und moderatorName sind erforderlich' });
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
app.get('/todos', async (req, res) => {
  try {
    const familyId = (req.query.familyId || '').toString().trim();
    const items = await prisma.todo.findMany({
      where: familyId ? { familyId } : undefined,
      orderBy: { createdAt: 'desc' },
    });
    return res.json({ items: items.map(mapTodoRecordToApiItem) });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'GET /todos', error)) {
      return;
    }
    return res.json({ items: todos });
  }
});

app.post('/todos', async (req, res) => {
  try {
    const familyId = await ensureDemoFamilyContext(req.body.familyId || DEMO_FAMILY_ID);
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
    if (respondWithStrictPersistenceError(res, 'POST /todos', error)) {
      return;
    }
    const item = {
      id: generateId('todo'),
      familyId: req.body.familyId || DEMO_FAMILY_ID,
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

app.put('/todos/:id', async (req, res) => {
  try {
    const existing = await prisma.todo.findUnique({ where: { id: req.params.id } });
    if (!existing) {
      return res.status(404).json({ error: 'Todo nicht gefunden' });
    }

    const currentMeta = parseTodoDescription(existing.description);
    const completed = Boolean(req.body.completed);
    const item = await prisma.todo.update({
      where: { id: req.params.id },
      data: {
        done: completed,
        completedAt: completed ? (existing.completedAt || new Date()) : null,
        description: buildTodoDescription({
          assigneeName: req.body.assigneeName || currentMeta.assigneeName,
          category: req.body.category || currentMeta.category,
        }),
      },
    });
    return res.json({ item: mapTodoRecordToApiItem(item) });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'PUT /todos/:id', error)) {
      return;
    }
    const index = todos.findIndex(item => item.id === req.params.id);
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

app.delete('/todos/:id', async (req, res) => {
  try {
    await prisma.todo.delete({ where: { id: req.params.id } });
    return res.status(204).send();
  } catch (error) {
    if (error?.code === 'P2025') {
      return res.status(404).json({ error: 'Todo nicht gefunden' });
    }

    if (respondWithStrictPersistenceError(res, 'DELETE /todos/:id', error)) {
      return;
    }
    const index = todos.findIndex(item => item.id === req.params.id);
    if (index === -1) {
      return res.status(404).json({ error: 'Todo nicht gefunden' });
    }
    todos.splice(index, 1);
    return res.status(204).send();
  }
});

// 9. Shopping (Prisma-first with in-memory fallback)
app.get('/shopping', async (req, res) => {
  try {
    const familyId = (req.query.familyId || '').toString().trim();
    const items = await prisma.shoppingItem.findMany({
      where: familyId ? { familyId } : undefined,
      orderBy: { createdAt: 'desc' },
    });
    return res.json({ items: items.map(mapShoppingRecordToApiItem) });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'GET /shopping', error)) {
      return;
    }
    return res.json({ items: shoppingItems });
  }
});

app.post('/shopping', async (req, res) => {
  try {
    const familyId = await ensureDemoFamilyContext(req.body.familyId || DEMO_FAMILY_ID);
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
    if (respondWithStrictPersistenceError(res, 'POST /shopping', error)) {
      return;
    }
    const item = {
      id: generateId('shop'),
      familyId: req.body.familyId || DEMO_FAMILY_ID,
      name: req.body.name || '',
      checked: Boolean(req.body.checked),
      category: req.body.category || 'Allgemein',
      createdAt: new Date().toISOString(),
    };
    shoppingItems.unshift(item);
    return res.status(201).json({ item });
  }
});

app.put('/shopping/:id', async (req, res) => {
  try {
    const checked = Boolean(req.body.checked);
    const item = await prisma.shoppingItem.update({
      where: { id: req.params.id },
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

    if (respondWithStrictPersistenceError(res, 'PUT /shopping/:id', error)) {
      return;
    }
    const index = shoppingItems.findIndex(item => item.id === req.params.id);
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

app.delete('/shopping/:id', async (req, res) => {
  try {
    await prisma.shoppingItem.delete({ where: { id: req.params.id } });
    return res.status(204).send();
  } catch (error) {
    if (error?.code === 'P2025') {
      return res.status(404).json({ error: 'Shopping-Item nicht gefunden' });
    }

    if (respondWithStrictPersistenceError(res, 'DELETE /shopping/:id', error)) {
      return;
    }
    const index = shoppingItems.findIndex(item => item.id === req.params.id);
    if (index === -1) {
      return res.status(404).json({ error: 'Shopping-Item nicht gefunden' });
    }
    shoppingItems.splice(index, 1);
    return res.status(204).send();
  }
});

// 10. Calendar events
app.get('/calendar/events', async (req, res) => {
  const userId = (req.query.userId || req.query.familyId || '').toString().trim();
  try {
    await ensureSocialSchemaReady();
    if (userId) {
      const rows = await prisma.$queryRawUnsafe(
        `SELECT * FROM "CalendarEvent" WHERE "userId" = $1 ORDER BY "startAt" ASC`,
        userId
      );
      return res.json({ items: rows });
    }
    return res.json({ items: [] });
  } catch (error) {
    // fallback to in-memory on DB error
    return res.json({ items: calendarEvents.filter(e => !userId || e.familyId === userId) });
  }
});

app.post('/calendar/events', async (req, res) => {
  const userId = (req.firebaseUid || req.body.userId || req.body.familyId || 'demo-family-001').toString().trim();
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
    // fallback to in-memory if DB unavailable
    calendarEvents.unshift(event);
    return res.status(201).json({ item: event });
  }
});

app.delete('/calendar/events/:id', async (req, res) => {
  const id = (req.params.id || '').toString().trim();
  if (!id) return res.status(400).json({ error: 'id erforderlich' });
  try {
    await ensureSocialSchemaReady();
    await prisma.$executeRawUnsafe(`DELETE FROM "CalendarEvent" WHERE "id" = $1`, id);
  } catch (_) {
    // also remove from in-memory fallback
    const idx = calendarEvents.findIndex(e => e.id === id);
    if (idx !== -1) calendarEvents.splice(idx, 1);
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

  try {
    const profile = await getMyParentMatchingProfile(userId);
    if (!profile) {
      return res.status(404).json({ error: 'Matching-Profil nicht gefunden' });
    }
    return res.json({ item: mapParentMatchingProfileForClient(profile) });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'GET /parent-matching/my-profile', error)) {
      return;
    }
    const profile = getMyParentMatchingProfileInMemory(userId);
    if (!profile) {
      return res.status(404).json({ error: 'Matching-Profil nicht gefunden' });
    }
    return res.json({ item: mapParentMatchingProfileForClient(profile) });
  }
});

app.post('/parent-matching/my-profile', async (req, res) => {
  const userId = (req.body.userId || '').toString().trim();
  if (!userId) {
    return res.status(400).json({ error: 'userId fehlt' });
  }

  const name = (req.body.name || '').toString().trim();
  if (!name) {
    return res.status(400).json({ error: 'Name fehlt' });
  }

  const age = Number.parseInt((req.body.age || '').toString(), 10);
  const city = (req.body.city || '').toString().trim();
  const familyForm = (req.body.familyForm || '').toString().trim();
  const bio = (req.body.bio || '').toString().trim();
  const latitudeRaw = Number(req.body.latitude);
  const longitudeRaw = Number(req.body.longitude);
  const latitude = Number.isFinite(latitudeRaw) ? latitudeRaw : null;
  const longitude = Number.isFinite(longitudeRaw) ? longitudeRaw : null;

  const toList = value => Array.isArray(value)
    ? value.map(item => item?.toString().trim()).filter(Boolean)
    : [];

  const interests = toList(req.body.interests);
  const languages = toList(req.body.languages);
  const valuesFocus = toList(req.body.valuesFocus || req.body.values);
  const childAges = toList(req.body.childAges);

  if (!Number.isInteger(age) || age < 16 || age > 99) {
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

app.get('/parent-matching/profiles', async (req, res) => {
  const userId = (req.query.userId || '').toString().trim();
  if (!userId) {
    return res.status(400).json({ error: 'userId fehlt' });
  }

  try {
    const ownProfile = await getMyParentMatchingProfile(userId);
    if (!ownProfile) {
      return res.status(409).json({ error: 'Bitte zuerst eigenes Matching-Profil anlegen' });
    }

    const profiles = await prisma.parentMatchingProfile.findMany({
      where: {
        isActive: true,
        ownerUserId: { not: userId },
      },
      orderBy: [{ verificationLevel: 'desc' }, { createdAt: 'desc' }],
    });

    return res.json({
      profiles: profiles.map(mapParentMatchingProfileForClient),
    });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'GET /parent-matching/profiles', error)) {
      return;
    }
    const ownProfile = getMyParentMatchingProfileInMemory(userId);
    if (!ownProfile) {
      return res.status(409).json({ error: 'Bitte zuerst eigenes Matching-Profil anlegen' });
    }
    const profiles = parentProfiles
      .filter(item => item.isActive !== false && item.ownerUserId !== userId)
      .map(mapParentMatchingProfileForClient);
    return res.json({ profiles });
  }
});

app.get('/parent-matching/connections', async (req, res) => {
  const familyId = (req.query.familyId || DEMO_FAMILY_ID).toString().trim();
  const userId = (req.query.userId || '').toString().trim();

  if (!userId) {
    return res.status(400).json({ error: 'userId fehlt' });
  }

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

app.post('/parent-matching/actions', async (req, res) => {
  const familyId = (req.body.familyId || 'demo-family-001').toString().trim();
  const profileIdInput = (req.body.profileId || '').toString().trim();
  const actionValue = (req.body.action || 'unknown').toString().trim().toLowerCase();
  const actorUserId = (req.body.userId || '').toString().trim();
  const createdAtInput = (req.body.createdAt || '').toString().trim();

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
      select: { id: true, ownerUserId: true },
    });

    if (!targetProfile) {
      targetProfile = await prisma.parentMatchingProfile.findUnique({
        where: { externalId: profileIdInput },
        select: { id: true, ownerUserId: true },
      });
    }

    if (!targetProfile) {
      return res.status(404).json({ error: 'Profil nicht gefunden' });
    }

    const createdAt = createdAtInput ? new Date(createdAtInput) : new Date();
    const createdAction = await prisma.parentMatchingAction.create({
      data: {
        familyId,
        profileId: targetProfile.id,
        action: actionValue,
        createdAt: Number.isNaN(createdAt.getTime()) ? new Date() : createdAt,
        actorUserId: actorUserId || null,
      },
    });

    const mutualProfileIds = await getMutualConnectionProfileIds(familyId, actorUserId);
    const connected = actionValue === 'like' && mutualProfileIds.includes(targetProfile.id);

    return res.status(201).json({
      item: createdAction,
      connected,
      matchState: connected
        ? 'matched'
        : (actionValue === 'like' ? 'pending' : 'none'),
    });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'POST /parent-matching/actions', error)) {
      return;
    }
    ensureParentMatchingProfileForUserInMemory(actorUserId);
    const targetProfile = parentProfiles.find(item => item.id === profileIdInput);
    if (!targetProfile) {
      return res.status(404).json({ error: 'Profil nicht gefunden' });
    }
    const createdAt = createdAtInput ? new Date(createdAtInput) : new Date();
    const createdAction = {
      id: generateId('pm-action'),
      familyId,
      profileId: targetProfile.id,
      action: actionValue,
      userId: actorUserId,
      createdAt: Number.isNaN(createdAt.getTime()) ? new Date().toISOString() : createdAt.toISOString(),
    };
    parentMatchingActions.unshift(createdAction);
    const mutualProfileIds = getMutualConnectionProfileIdsInMemory(familyId, actorUserId);
    const connected = actionValue === 'like' && mutualProfileIds.includes(targetProfile.id);
    return res.status(201).json({
      item: createdAction,
      connected,
      matchState: connected
        ? 'matched'
        : (actionValue === 'like' ? 'pending' : 'none'),
    });
  }
});

app.get('/parent-matching/messages/stream', async (req, res) => {
  const familyId = (req.query.familyId || DEMO_FAMILY_ID).toString().trim();
  const profileId = (req.query.profileId || '').toString().trim();
  const userId = (req.query.userId || '').toString().trim();

  if (!profileId) {
    return res.status(400).json({ error: 'profileId fehlt' });
  }
  if (!userId) {
    return res.status(400).json({ error: 'userId fehlt' });
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

app.get('/parent-matching/messages', async (req, res) => {
  const familyId = (req.query.familyId || DEMO_FAMILY_ID).toString().trim();
  const profileId = (req.query.profileId || '').toString().trim();
  const userId = (req.query.userId || '').toString().trim();

  if (!profileId) {
    return res.status(400).json({ error: 'profileId fehlt' });
  }
  if (!userId) {
    return res.status(400).json({ error: 'userId fehlt' });
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

app.post('/parent-matching/messages', async (req, res) => {
  const familyId = (req.body.familyId || DEMO_FAMILY_ID).toString().trim();
  const profileId = (req.body.profileId || '').toString().trim();
  const authorUserId = (req.body.userId || '').toString().trim();
  const authorName = (req.body.userName || 'Elternteil').toString().trim();
  const content = (req.body.content || '').toString().trim();

  if (!profileId) {
    return res.status(400).json({ error: 'profileId fehlt' });
  }
  if (!authorUserId) {
    return res.status(400).json({ error: 'userId fehlt' });
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

app.post('/api/friends/register', async (req, res) => {
  const code = (req.body.code || '').toString().trim().toLowerCase();
  const name = (req.body.name || '').toString().trim();
  if (!code || !name) return res.status(400).json({ error: 'code und name erforderlich' });
  try {
    await ensureSocialSchemaReady();
    await prisma.$executeRawUnsafe(
      `INSERT INTO "FriendRegistry" ("code", "name", "updatedAt") VALUES ($1, $2, NOW())
       ON CONFLICT ("code") DO UPDATE SET "name" = $2, "updatedAt" = NOW()`,
      code, name
    );
    return res.json({ ok: true });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'POST /api/friends/register', error)) return;
    friendRegistry.set(code, { name, updatedAt: new Date().toISOString() });
    return res.json({ ok: true });
  }
});

app.get('/api/friends/lookup/:code', async (req, res) => {
  const code = (req.params.code || '').toString().trim().toLowerCase();
  try {
    await ensureSocialSchemaReady();
    const rows = await prisma.$queryRawUnsafe(
      `SELECT "name" FROM "FriendRegistry" WHERE "code" = $1`, code
    );
    if (rows.length > 0) return res.json({ name: rows[0].name });
    const mem = friendRegistry.get(code);
    if (mem) return res.json({ name: mem.name });
    return res.status(404).json({ error: 'Nicht gefunden' });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'GET /api/friends/lookup', error)) return;
    const entry = friendRegistry.get(code);
    if (!entry) return res.status(404).json({ error: 'Nicht gefunden' });
    return res.json({ name: entry.name });
  }
});

app.post('/api/friends/connect', async (req, res) => {
  const fromCode = (req.body.fromCode || '').toString().trim().toLowerCase();
  const fromName = (req.body.fromName || '').toString().trim();
  const toCode   = (req.body.toCode   || '').toString().trim().toLowerCase();
  if (!fromCode || !toCode) return res.status(400).json({ error: 'fromCode und toCode erforderlich' });
  try {
    await ensureSocialSchemaReady();
    const existing = await prisma.$queryRawUnsafe(
      `SELECT "id" FROM "FriendPendingConnection" WHERE "toCode" = $1 AND "fromCode" = $2`,
      toCode, fromCode
    );
    if (existing.length === 0) {
      await prisma.$executeRawUnsafe(
        `INSERT INTO "FriendPendingConnection" ("id", "toCode", "fromCode", "fromName", "connectedAt") VALUES ($1, $2, $3, $4, NOW())`,
        generateId('fpc'), toCode, fromCode, fromName
      );
    }
    return res.json({ ok: true });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'POST /api/friends/connect', error)) return;
    if (!friendPendingConnections.has(toCode)) friendPendingConnections.set(toCode, []);
    const list = friendPendingConnections.get(toCode);
    if (!list.some(e => e.fromCode === fromCode)) {
      list.push({ fromCode, fromName, connectedAt: new Date().toISOString() });
    }
    return res.json({ ok: true });
  }
});

app.get('/api/friends/pending/:code', async (req, res) => {
  const code = (req.params.code || '').toString().trim().toLowerCase();
  try {
    await ensureSocialSchemaReady();
    const connections = await prisma.$queryRawUnsafe(
      `SELECT "fromCode", "fromName", "connectedAt" FROM "FriendPendingConnection" WHERE "toCode" = $1`,
      code
    );
    await prisma.$executeRawUnsafe(
      `DELETE FROM "FriendPendingConnection" WHERE "toCode" = $1`, code
    );
    return res.json({ connections });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'GET /api/friends/pending', error)) return;
    const connections = friendPendingConnections.get(code) || [];
    friendPendingConnections.delete(code);
    return res.json({ connections });
  }
});

app.get('/friend-chat/messages', async (req, res) => {
  const roomId = (req.query.roomId || '').toString().trim();
  if (!roomId) return res.status(400).json({ error: 'roomId fehlt' });
  try {
    await ensureSocialSchemaReady();
    const messages = await prisma.$queryRawUnsafe(
      `SELECT "id", "roomId", "authorUserId", "authorName", "content", "createdAt" FROM "FriendChatMessage" WHERE "roomId" = $1 ORDER BY "createdAt" ASC`,
      roomId
    );
    return res.json({ messages });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'GET /friend-chat/messages', error)) return;
    return res.json({ messages: friendChatMessages.get(roomId) || [] });
  }
});

app.post('/friend-chat/messages', async (req, res) => {
  const roomId   = (req.body.roomId   || '').toString().trim();
  const userId   = (req.body.userId   || '').toString().trim();
  const userName = (req.body.userName || 'Elternteil').toString().trim();
  const content  = (req.body.content  || '').toString().trim();
  if (!roomId || !userId || !content) {
    return res.status(400).json({ error: 'roomId, userId und content erforderlich' });
  }
  const item = { id: generateId('fc'), roomId, authorUserId: userId, authorName: userName, content, createdAt: new Date().toISOString() };
  try {
    await ensureSocialSchemaReady();
    await prisma.$executeRawUnsafe(
      `INSERT INTO "FriendChatMessage" ("id", "roomId", "authorUserId", "authorName", "content", "createdAt") VALUES ($1, $2, $3, $4, $5, NOW())`,
      item.id, roomId, userId, userName, content
    );
    // Send push notification to the other person
    try {
      await sendPushToUser(roomId, {
        title: userName || 'Neue Nachricht',
        body: content.length > 100 ? content.substring(0, 100) + '...' : content,
        data: { type: 'friend_chat', roomId, senderId: userId },
      });
    } catch (_) {}
    return res.status(201).json({ item });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'POST /friend-chat/messages', error)) return;
    if (!friendChatMessages.has(roomId)) friendChatMessages.set(roomId, []);
    friendChatMessages.get(roomId).push(item);
    // Send push notification to the other person (fallback path)
    try {
      await sendPushToUser(roomId, {
        title: userName || 'Neue Nachricht',
        body: content.length > 100 ? content.substring(0, 100) + '...' : content,
        data: { type: 'friend_chat', roomId, senderId: userId },
      });
    } catch (_) {}
    return res.status(201).json({ item });
  }
});

app.get('/family/requests', async (req, res) => {
  const userId = (req.query.userId || '').toString().trim();
  const toUserId = (req.query.toUserId || userId || '').toString().trim();
  const fromUserId = (req.query.fromUserId || '').toString().trim();
  const status = (req.query.status || '').toString().trim();
  const allowedStatuses = new Set(['pending', 'accepted', 'declined']);

  if (status && !allowedStatuses.has(status)) {
    return res.status(400).json({ error: 'Ungültiger Status' });
  }

  const where = {};
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
      if (toUserId && item.toUserId !== toUserId) return false;
      if (fromUserId && item.fromUserId !== fromUserId) return false;
      if (status && item.status !== status) return false;
      return true;
    });
    return res.json({ requests });
  }
});

app.post('/family/requests', async (req, res) => {
  const fromUserId = (req.body.fromUserId || '').toString().trim();
  const toUserId = (req.body.toUserId || '').toString().trim();
  const actingUserId = (req.body.actingUserId || '').toString().trim();
  const status = (req.body.status || 'pending').toString().trim();

  if (!fromUserId || !toUserId) {
    return res.status(400).json({ error: 'fromUserId und toUserId sind erforderlich' });
  }
  if (fromUserId === toUserId) {
    return res.status(400).json({ error: 'fromUserId und toUserId dürfen nicht identisch sein' });
  }
  if (!['pending', 'accepted', 'declined'].includes(status)) {
    return res.status(400).json({ error: 'Ungültiger Status' });
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

app.put('/family/requests/:id', async (req, res) => {
  const status = req.body.status;
  const actingUserId = (req.body.actingUserId || '').toString().trim();

  if (!['pending', 'accepted', 'declined'].includes(status)) {
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

app.delete('/family/requests/:id', async (req, res) => {
  const actingUserId = (req.body?.actingUserId || req.query.actingUserId || '').toString().trim();

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
app.get('/events', async (req, res) => {
  const MAX_LIMIT = 100;
  const limit = Math.min(Math.max(Number.parseInt(req.query.limit || '50', 10) || 50, 1), MAX_LIMIT);
  const offset = Math.max(Number.parseInt(req.query.offset || '0', 10) || 0, 0);

  try {
    const hostUserId = (req.query.hostUserId || '').toString().trim();
    const records = await prisma.event.findMany({
      where: hostUserId ? { hosterId: hostUserId } : undefined,
      orderBy: { createdAt: 'desc' },
      skip: offset,
      take: limit,
    });

    const countMap = await buildParticipantCountMap(records.map(item => item.id));
    let items = records.map(item =>
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
  const viewerUserId = (req.query.viewerUserId || 'guest_user').toString();

  try {
    const acceptedInvites = await prisma.eventParticipation.findMany({
      where: {
        userId: viewerUserId,
        status: 'accepted',
      },
      select: { eventId: true },
    });
    const acceptedInviteEventIds = new Set(acceptedInvites.map(item => item.eventId));

    const records = await prisma.event.findMany({
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

    const updated = await prisma.event.update({
      where: { id: req.params.id },
      data: updatableFields,
    });

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
    if (error?.code === 'P2025') {
      return res.status(404).json({ error: 'Event nicht gefunden' });
    }
    if (respondWithStrictPersistenceError(res, 'PUT /events/item/:id', error)) {
      return;
    }
    const idx = events.findIndex(ev => ev.id === req.params.id);
    if (idx === -1) {
      return res.status(404).json({ error: 'Event nicht gefunden' });
    }
    const entry = events[idx];
    if (requestingUserId && requestingUserId !== entry.hosterId) {
      return res.status(403).json({ error: 'Nur der Hoster darf dieses Event bearbeiten' });
    }
    const merged = {
      ...entry,
      ...(body.title !== undefined && { title: body.title }),
      ...(body.description !== undefined && { description: body.description }),
      ...(body.location !== undefined && { location: body.location }),
      ...(body.eventDate !== undefined && { eventDate: body.eventDate }),
      ...(body.maxParticipants !== undefined && { maxParticipants: Number(body.maxParticipants) }),
      ...(body.photoUrl !== undefined && { photoUrl: body.photoUrl }),
      ...(body.status !== undefined && { status: body.status }),
      ...(body.visibility !== undefined && { visibility: body.visibility }),
      ...(body.price !== undefined && { price: body.price }),
    };
    events[idx] = merged;
    return res.json({ item: merged });
  }
});

app.get('/events/item/:id', async (req, res) => {
  try {
    const record = await prisma.event.findUnique({ where: { id: req.params.id } });
    if (!record) {
      return res.status(404).json({ error: 'Event nicht gefunden' });
    }

    const countMap = await buildParticipantCountMap([record.id]);
    const item = mapEventRecordToApiItem(record, {
      currentParticipants: countMap.get(record.id) || 0,
    });
    const inviteCode = item.inviteCode || eventInviteCodes[item.id] || null;
    const inviteCodeExpiresAt = eventInviteExpiresAt[item.id] || item.inviteCodeExpiresAt || null;
    return res.json({ item: { ...item, inviteCode, inviteCodeExpiresAt } });
  } catch (error) {
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

app.post('/events', async (req, res) => {
  const body = req.body || {};
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

app.delete('/events/item/:id', async (req, res) => {
  const requestingUserId = (req.query.requestingUserId || req.body?.requestingUserId || '').toString().trim();

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
      .filter(item => ['invited', 'accepted', 'declined'].includes(item.status))
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
  try {
    const current = await prisma.eventParticipation.findUnique({ where: { id: req.params.id } });
    if (!current || !['invited', 'accepted', 'declined'].includes(current.status)) {
      return res.status(404).json({ error: 'Einladung nicht gefunden' });
    }

    const accept = Boolean(req.body.accept);
    const nextStatus = accept ? 'accepted' : 'declined';
    const updated = await prisma.eventParticipation.update({
      where: { id: req.params.id },
      data: { status: nextStatus },
    });

    return res.json({ item: mapInvitationRecordToApiItem(updated) });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'PUT /events/invitations/:id/respond', error)) {
      return;
    }
    const index = eventInvitations.findIndex(item => item.id === req.params.id);
    if (index === -1) {
      return res.status(404).json({ error: 'Einladung nicht gefunden' });
    }

    const accept = Boolean(req.body.accept);
    const nextStatus = accept ? 'accepted' : 'declined';
    eventInvitations[index] = {
      ...eventInvitations[index],
      status: nextStatus,
      updatedAt: new Date().toISOString(),
    };

    return res.json({ item: eventInvitations[index] });
  }
});

app.post('/events/invitations/join', async (req, res) => {
  const codeInput = (req.body.code || '').toString().trim().toUpperCase();
  const userId = (req.body.userId || '').toString().trim();

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

    const event = await ensureEventContext(eventByCode.id, eventByCode.hosterId || DEMO_USER_ID);
    const safeUserId = await ensureBackendUser(userId, userId);
    const invitation = await prisma.eventParticipation.upsert({
      where: {
        eventId_userId: {
          eventId: event.id,
          userId: safeUserId,
        },
      },
      update: { status: 'accepted' },
      create: {
        eventId: event.id,
        userId: safeUserId,
        status: 'accepted',
      },
    });

    return res.status(201).json({ item: mapInvitationRecordToApiItem(invitation) });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'POST /events/invitations/join', error)) {
      return;
    }
    const eventId = Object.keys(eventInviteCodes).find(
      id => (eventInviteCodes[id] || '').toUpperCase() === codeInput,
    );

    if (!eventId || isInviteExpired(eventId)) {
      return res.status(404).json({ error: 'Code ungültig oder abgelaufen' });
    }

    const event = events.find(item => item.id === eventId);
    if (!event) {
      return res.status(404).json({ error: 'Event nicht gefunden' });
    }

    let invitation = eventInvitations.find(
      item => item.eventId === eventId && item.invitedUserId === userId,
    );

    if (!invitation) {
      invitation = {
        id: `inv_${eventId}_${userId}`,
        eventId,
        hostUserId: event.hosterId,
        invitedUserId: userId,
        createdAt: new Date().toISOString(),
        status: 'accepted',
      };
      eventInvitations.push(invitation);
    } else {
      invitation.status = 'accepted';
      invitation.updatedAt = new Date().toISOString();
    }

    return res.status(201).json({ item: invitation });
  }
});

app.get('/events/hosted-invite-only', async (req, res) => {
  const hostUserId = (req.query.hostUserId || '').toString();

  try {
    const records = await prisma.event.findMany({
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

app.get('/events/:id/invitations/accepted', async (req, res) => {
  try {
    const items = await prisma.eventParticipation.findMany({
      where: { eventId: req.params.id, status: 'accepted' },
      orderBy: { createdAt: 'desc' },
    });
    return res.json({ items: items.map(mapInvitationRecordToApiItem) });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'GET /events/:id/invitations/accepted', error)) {
      return;
    }
    const items = eventInvitations.filter(
      item => item.eventId === req.params.id && item.status === 'accepted',
    );
    return res.json({ items });
  }
});

// 16. Event participations (Prisma-first with in-memory fallback)
app.get('/events/participations', async (req, res) => {
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

  if (!eventId || !userId) {
    return res.status(400).json({ error: 'eventId und userId sind erforderlich' });
  }

  try {
    const event = await prisma.event.findUnique({ where: { id: eventId } });
    if (!event) {
      return res.status(404).json({ error: 'Event nicht gefunden' });
    }

    const safeUserId = await ensureBackendUser(userId, req.body.userName || userId);
    const item = await prisma.eventParticipation.upsert({
      where: {
        eventId_userId: {
          eventId,
          userId: safeUserId,
        },
      },
      update: {
        status: 'pending',
      },
      create: {
        eventId,
        userId: safeUserId,
        status: 'pending',
      },
    });
    return res.status(201).json({ item: mapParticipationRecordToApiItem(item) });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'POST /events/participations', error)) {
      return;
    }
    const event = events.find(item => item.id === eventId);
    if (!event) {
      return res.status(404).json({ error: 'Event nicht gefunden' });
    }

    const existing = eventParticipations.find(
      item => item.eventId === eventId && item.userId === userId && item.status !== 'cancelled',
    );
    if (existing) {
      return res.status(200).json({ item: existing });
    }

    const item = {
      id: generateId('participation'),
      eventId,
      userId,
      requestedAt: new Date().toISOString(),
      approvedAt: null,
      declinedAt: null,
      cancelledAt: null,
      status: 'pending',
    };

    eventParticipations.unshift(item);
    return res.status(201).json({ item });
  }
});

app.put('/events/participations/:id/respond', async (req, res) => {
  try {
    const current = await prisma.eventParticipation.findUnique({ where: { id: req.params.id } });
    if (!current) {
      return res.status(404).json({ error: 'Teilnahme nicht gefunden' });
    }

    const accept = Boolean(req.body.accept);
    const nextStatus = accept ? 'approved' : 'declined';
    const updated = await prisma.eventParticipation.update({
      where: { id: req.params.id },
      data: { status: nextStatus },
    });
    return res.json({ item: mapParticipationRecordToApiItem(updated) });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'PUT /events/participations/:id/respond', error)) {
      return;
    }
    const index = eventParticipations.findIndex(item => item.id === req.params.id);
    if (index === -1) {
      return res.status(404).json({ error: 'Teilnahme nicht gefunden' });
    }

    const accept = Boolean(req.body.accept);
    const current = eventParticipations[index];
    const eventIndex = events.findIndex(event => event.id === current.eventId);
    const nextItem = {
      ...current,
      status: accept ? 'approved' : 'declined',
      approvedAt: accept ? new Date().toISOString() : null,
      declinedAt: accept ? null : new Date().toISOString(),
    };

    eventParticipations[index] = nextItem;

    if (accept && eventIndex !== -1) {
      events[eventIndex] = {
        ...events[eventIndex],
        currentParticipants: Number(events[eventIndex].currentParticipants || 0) + 1,
      };
    }

    return res.json({ item: nextItem });
  }
});

app.get('/events/:id/participations/approved', async (req, res) => {
  try {
    const items = await prisma.eventParticipation.findMany({
      where: { eventId: req.params.id, status: 'approved' },
      orderBy: { createdAt: 'desc' },
    });
    return res.json({ items: items.map(mapParticipationRecordToApiItem) });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'GET /events/:id/participations/approved', error)) {
      return;
    }
    const items = eventParticipations.filter(
      item => item.eventId === req.params.id && item.status === 'approved',
    );
    return res.json({ items });
  }
});

// 17. Event chat (Prisma-first with in-memory fallback)
app.get('/events/:id/chat/messages', async (req, res) => {
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
    if (respondWithStrictPersistenceError(res, 'GET /events/:id/chat/messages', error)) {
      return;
    }
    const items = eventChatMessages[req.params.id] || [];
    return res.json({ items });
  }
});

app.post('/events/:id/chat/messages', async (req, res) => {
  const eventId = req.params.id;

  try {
    const event = await prisma.event.findUnique({ where: { id: eventId } });
    if (!event) {
      return res.status(404).json({ error: 'Event nicht gefunden' });
    }

    const authorId = await ensureBackendUser(req.body.userId || DEMO_USER_ID, req.body.userName || 'Unbekannt');
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
      isHost: message.authorId === event.hosterId,
    };

    return res.status(201).json({ item });
  } catch (error) {
    if (respondWithStrictPersistenceError(res, 'POST /events/:id/chat/messages', error)) {
      return;
    }
    const event = events.find(item => item.id === eventId);
    if (!event) {
      return res.status(404).json({ error: 'Event nicht gefunden' });
    }

    const item = {
      id: generateId('msg'),
      eventId,
      userId: req.body.userId || '',
      userName: req.body.userName || 'Unbekannt',
      userAvatarUrl: req.body.userAvatarUrl || '',
      content: req.body.content || '',
      timestamp: new Date().toISOString(),
      isHost: Boolean(req.body.isHost),
    };

    if (!eventChatMessages[eventId]) {
      eventChatMessages[eventId] = [];
    }
    eventChatMessages[eventId].push(item);
    return res.status(201).json({ item });
  }
});

app.delete('/events/:eventId/chat/messages/:messageId', async (req, res) => {
  try {
    const message = await prisma.message.findUnique({
      where: { id: req.params.messageId },
      include: { chat: true },
    });
    if (!message || message.chat.eventId !== req.params.eventId) {
      return res.status(404).json({ error: 'Nachricht nicht gefunden' });
    }

    await prisma.message.delete({ where: { id: req.params.messageId } });
    return res.status(204).send();
  } catch (error) {
    console.error('DELETE /events/:eventId/chat/messages/:messageId fallback (in-memory):', error?.message || error);
    const items = eventChatMessages[req.params.eventId] || [];
    const before = items.length;
    eventChatMessages[req.params.eventId] = items.filter(
      item => item.id !== req.params.messageId,
    );
    if (before === eventChatMessages[req.params.eventId].length) {
      return res.status(404).json({ error: 'Nachricht nicht gefunden' });
    }
    return res.status(204).send();
  }
});

app.post('/events/:id/chat/reports', async (req, res) => {
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

    const reporterId = await ensureBackendUser(
      req.body.reporterId || DEMO_USER_ID,
      req.body.reporterName || req.body.reporterId || 'Reporter',
    );

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
    console.error('POST /events/:id/chat/reports fallback (in-memory):', error?.message || error);
    const item = {
      id: generateId('report'),
      eventId: req.params.id,
      reportedMessageId: req.body.reportedMessageId || '',
      reporterId: req.body.reporterId || '',
      reason: req.body.reason || 'other',
      description: req.body.description || null,
      reportedAt: new Date().toISOString(),
    };
    eventChatReports.unshift(item);
    return res.status(201).json({ item });
  }
});

app.get('/events/:id/chat/reports', async (req, res) => {
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
    console.error('GET /events/:id/chat/reports fallback (in-memory):', error?.message || error);
    const items = eventChatReports.filter(item => item.eventId === req.params.id);
    return res.json({ items });
  }
});

app.get('/events/:id/chat/access', async (req, res) => {
  const userId = (req.query.userId || '').toString();

  try {
    const event = await prisma.event.findUnique({ where: { id: req.params.id } });
    if (!event) {
      return res.status(404).json({ error: 'Event nicht gefunden' });
    }

    const hosterId = (req.query.hosterId || event.hosterId || '').toString();
    const participation = await prisma.eventParticipation.findFirst({
      where: {
        eventId: event.id,
        userId,
        status: { in: ['approved', 'accepted', 'attended'] },
      },
    });

    const acceptedInvite = eventInvitations.some(
      item =>
        item.eventId === event.id &&
        item.invitedUserId === userId &&
        item.status === 'accepted',
    );

    const hasAccess = userId === hosterId || Boolean(participation) || acceptedInvite;
    return res.json({ hasAccess });
  } catch (error) {
    console.error('GET /events/:id/chat/access fallback (in-memory):', error?.message || error);
    const event = events.find(item => item.id === req.params.id);
    if (!event) {
      return res.status(404).json({ error: 'Event nicht gefunden' });
    }

    const hosterId = (req.query.hosterId || event.hosterId || '').toString();
    const approvedParticipation = eventParticipations.some(
      item =>
        item.eventId === event.id &&
        item.userId === userId &&
        item.status === 'approved',
    );
    const acceptedInvite = eventInvitations.some(
      item =>
        item.eventId === event.id &&
        item.invitedUserId === userId &&
        item.status === 'accepted',
    );

    const hasAccess = userId === hosterId || approvedParticipation || acceptedInvite;
    return res.json({ hasAccess });
  }
});

// 18. Payments
app.post('/payments/stripe/initiate', async (req, res) => {
  const body = req.body || {};
  const amount = parsePositiveNumber(body.amount);
  const eventId = (body.eventId || '').toString();
  const hosterId = (body.hosterId || '').toString();

  if (!eventId || !hosterId || amount == null) {
    return res.status(400).json({
      error: 'eventId, hosterId und amount > 0 sind erforderlich',
    });
  }

  try {
    // Real Stripe: create PaymentIntent if secret key is available.
    if (stripe) {
      const intent = await stripe.paymentIntents.create({
        amount: Math.round(amount * 100), // Stripe expects cents
        currency: 'eur',
        description: `Parentpeak Event ${eventId}`,
        metadata: {
          eventId,
          hosterId,
        },
      });

      return res.status(201).json({
        item: {
          provider: 'stripe',
          mode: 'real_stripe',
          eventId,
          hosterId,
          amount,
          stripePaymentIntentId: intent.id,
          clientSecret: intent.client_secret,
          status: intent.status,
        },
      });
    }

    return res.status(503).json({
      error: 'Stripe ist nicht konfiguriert.',
    });
  } catch (error) {
    logSafeError('POST /payments/stripe/initiate failed', error, {
      eventId,
      hosterId,
      amount,
    });
    return res.status(500).json({
      error: `Stripe-Initialisierung fehlgeschlagen: ${error?.message || 'Unknown error'}`,
    });
  }
});

// Get Stripe PaymentIntent status (for payment confirmation)
app.get('/payments/stripe/confirm/:intentId', async (req, res) => {
  const { intentId } = req.params;

  if (!intentId) {
    return res.status(400).json({ error: 'intentId erforderlich' });
  }

  try {
    if (stripe) {
      const intent = await stripe.paymentIntents.retrieve(intentId);
      return res.json({
        item: {
          id: intent.id,
          amount: intent.amount / 100, // Convert back from cents
          status: intent.status,
          clientSecret: intent.client_secret,
        },
      });
    }

    return res.status(503).json({
      error: 'Stripe ist nicht konfiguriert.',
    });
  } catch (error) {
    logSafeError('GET /payments/stripe/confirm/:intentId failed', error, {
      intentId,
    });
    return res.status(500).json({
      error: `Stripe Abruf fehlgeschlagen: ${error?.message || 'Unknown error'}`,
    });
  }
});

app.post('/payments/paypal/initiate', (req, res) => {
  const body = req.body || {};
  const amount = parsePositiveNumber(body.amount);
  const eventId = (body.eventId || '').toString();
  const hosterId = (body.hosterId || '').toString();

  if (!eventId || !hosterId || amount == null) {
    return res.status(400).json({
      error: 'eventId, hosterId und amount > 0 sind erforderlich',
    });
  }

  return res.status(503).json({
    error: 'PayPal ist nicht konfiguriert.',
  });
});

app.post('/payments/confirm', async (req, res) => {
  const body = req.body || {};
  const amount = parsePositiveNumber(body.amount);
  const eventId = (body.eventId || '').toString();
  const hosterId = (body.hosterId || '').toString();
  const paymentMethod = (body.paymentMethod || 'stripe').toString();
  const allowedMethods = new Set(['stripe', 'paypal', 'apple_iap', 'google_play']);
  const normalizedStatus = normalizePaymentStatus(body.status || 'pending');
  const providerVerified = body.providerVerified === true;
  const providerTransactionRef = (body.providerTransactionRef || '').toString().trim();

  if (!eventId || !hosterId || amount == null) {
    return res.status(400).json({
      error: 'eventId, hosterId und amount > 0 sind erforderlich',
    });
  }

  if (!allowedMethods.has(paymentMethod)) {
    return res.status(400).json({ error: 'Unbekannte paymentMethod' });
  }

  if (normalizedStatus == null) {
    return res.status(400).json({ error: 'Ungueltiger payment status' });
  }

  if (normalizedStatus === 'completed' && !providerVerified) {
    return res.status(409).json({
      error: 'completed ist nur mit verifiziertem Provider-Event erlaubt',
    });
  }

  if ((paymentMethod === 'stripe' || paymentMethod === 'paypal') && !providerTransactionRef) {
    return res.status(400).json({
      error: 'providerTransactionRef ist für Stripe/PayPal erforderlich',
    });
  }

  const nowIso = new Date().toISOString();

  try {
    const context = await ensurePaymentContext(eventId, hosterId);
    const stripePaymentIntentId = paymentMethod === 'stripe'
      ? ((body.stripePaymentIntentId || providerTransactionRef || '').toString())
      : `alt_${paymentMethod}_${Date.now()}_${Math.floor(Math.random() * 1000)}`;

    if (paymentMethod === 'stripe' && !stripePaymentIntentId) {
      return res.status(400).json({
        error: 'stripePaymentIntentId oder providerTransactionRef ist erforderlich',
      });
    }

    const created = await prisma.paymentTransaction.create({
      data: {
        eventId: context.eventId,
        userId: context.hosterId,
        amount,
        currency: (body.currency || 'EUR').toString(),
        stripePaymentIntentId,
        idempotencyKey: (body.idempotencyKey || `${paymentMethod}:${providerTransactionRef || stripePaymentIntentId}`).toString(),
        status: normalizedStatus,
        verifiedAt: providerVerified ? new Date(nowIso) : null,
        verifiedByType: providerVerified ? 'api' : null,
        auditDetails: {
          mode: 'backend_record',
          hosterId: context.hosterId,
          paymentMethod,
          providerTransactionRef: providerTransactionRef || null,
          providerVerified,
          completedAt: normalizedStatus === 'completed' ? nowIso : null,
          failedAt: normalizedStatus === 'failed' ? nowIso : null,
        },
      },
    });

    const item = mapPaymentRecordToApiItem(created);
    await updateEventPaymentDateIfCompleted(item);
    return res.status(201).json({ item });
  } catch (error) {
    console.error('POST /payments/confirm fallback (in-memory):', error?.message || error);
    if (respondWithStrictPersistenceError(res, 'POST /payments/confirm', error)) {
      return;
    }

    return res.status(503).json({
      error: 'Zahlungs-Persistenz fehlgeschlagen.',
    });
  }
});

app.post('/payments/provider-events', async (req, res) => {
  if (!allowClientProviderEvents) {
    return res.status(403).json({
      error: 'Client Provider-Events sind deaktiviert',
    });
  }

  const body = req.body || {};
  const targetStatus = normalizePaymentStatus(body.status);
  const provider = (body.provider || '').toString().trim().toLowerCase();
  const providerTransactionRef = (body.providerTransactionRef || '').toString().trim();
  const transactionId = (body.transactionId || '').toString().trim();
  const verified = body.verified === true;

  if (targetStatus == null) {
    return res.status(400).json({ error: 'Ungueltiger payment status' });
  }

  const result = await applyProviderTransactionStatusUpdate({
    provider,
    providerTransactionRef,
    targetStatus,
    verified,
    transactionId,
  });

  if (!result.ok) {
    return res.status(result.httpStatus).json({ error: result.error });
  }

  return res.json({ item: result.item });
});

app.get('/payments/transactions', async (req, res) => {
  try {
    const hosterId = (req.query.hosterId || '').toString().trim();
    const items = await prisma.paymentTransaction.findMany({
      where: hosterId
        ? {
            OR: [
              { userId: hosterId },
              { auditDetails: { path: ['hosterId'], equals: hosterId } },
            ],
          }
        : undefined,
      orderBy: { createdAt: 'desc' },
    });
    return res.json({ items: items.map(mapPaymentRecordToApiItem) });
  } catch (error) {
    console.error('GET /payments/transactions fallback (in-memory):', error?.message || error);
    let items = [...paymentTransactions];
    if (req.query.hosterId) {
      items = items.filter(item => item.hosterId === req.query.hosterId);
    }
    return res.json({ items });
  }
});

app.get('/payments/transactions/:id', async (req, res) => {
  try {
    const item = await prisma.paymentTransaction.findUnique({ where: { id: req.params.id } });
    if (!item) {
      return res.status(404).json({ error: 'Transaktion nicht gefunden' });
    }
    return res.json({ item: mapPaymentRecordToApiItem(item) });
  } catch (error) {
    console.error('GET /payments/transactions/:id fallback (in-memory):', error?.message || error);
    const item = paymentTransactions.find(transaction => transaction.id === req.params.id);
    if (!item) {
      return res.status(404).json({ error: 'Transaktion nicht gefunden' });
    }
    return res.json({ item });
  }
});

app.get('/payments/host/:hosterId', async (req, res) => {
  try {
    const hosterId = (req.params.hosterId || '').toString().trim();
    const items = await prisma.paymentTransaction.findMany({
      where: {
        OR: [
          { userId: hosterId },
          { auditDetails: { path: ['hosterId'], equals: hosterId } },
        ],
      },
      orderBy: { createdAt: 'desc' },
    });
    return res.json({ items: items.map(mapPaymentRecordToApiItem) });
  } catch (error) {
    console.error('GET /payments/host/:hosterId fallback (in-memory):', error?.message || error);
    const items = paymentTransactions.filter(
      transaction => transaction.hosterId === req.params.hosterId,
    );
    return res.json({ items });
  }
});

app.post('/payments/transactions/:id/refund', async (req, res) => {
  try {
    const current = await prisma.paymentTransaction.findUnique({ where: { id: req.params.id } });
    if (!current) {
      return res.status(404).json({ error: 'Transaktion nicht gefunden' });
    }

    const mapped = mapPaymentRecordToApiItem(current);
    if (mapped.status !== 'completed') {
      return res.status(409).json({
        error: 'Rueckerstattung nur für completed-Transaktionen erlaubt',
      });
    }

    const updated = await prisma.paymentTransaction.update({
      where: { id: req.params.id },
      data: {
        status: 'refunded',
        refundedAt: new Date(),
        auditDetails: {
          ...getPaymentAuditDetails(current),
          refundedAt: new Date().toISOString(),
        },
      },
    });
    return res.json({ item: mapPaymentRecordToApiItem(updated) });
  } catch (error) {
    console.error('POST /payments/transactions/:id/refund fallback (in-memory):', error?.message || error);
    const index = paymentTransactions.findIndex(item => item.id === req.params.id);
    if (index === -1) {
      return res.status(404).json({ error: 'Transaktion nicht gefunden' });
    }

    if (paymentTransactions[index].status !== 'completed') {
      return res.status(409).json({
        error: 'Rueckerstattung nur für completed-Transaktionen erlaubt',
      });
    }

    paymentTransactions[index] = {
      ...paymentTransactions[index],
      status: 'refunded',
      refundedAt: new Date().toISOString(),
    };

    return res.json({ item: paymentTransactions[index] });
  }
});

app.post('/payments/transactions/:id/status', async (req, res) => {
  const targetStatus = normalizePaymentStatus(req.body.status);
  if (targetStatus == null) {
    return res.status(400).json({ error: 'Ungueltiger Zielstatus' });
  }

  try {
    const current = await prisma.paymentTransaction.findUnique({ where: { id: req.params.id } });
    if (!current) {
      return res.status(404).json({ error: 'Transaktion nicht gefunden' });
    }

    const result = await applyTransactionStatusUpdateByRecord(current, targetStatus);
    if (!result.ok) {
      return res.status(result.httpStatus).json({ error: result.error });
    }

    return res.json({ item: result.item });
  } catch (error) {
    console.error('POST /payments/transactions/:id/status fallback (in-memory):', error?.message || error);
    const index = paymentTransactions.findIndex(item => item.id === req.params.id);
    if (index === -1) {
      return res.status(404).json({ error: 'Transaktion nicht gefunden' });
    }

    const current = paymentTransactions[index];
    if (!canTransitionPaymentStatus(current.status, targetStatus)) {
      return res.status(409).json({
        error: `Statuswechsel ${current.status} -> ${targetStatus} nicht erlaubt`,
      });
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
    return res.json({ item: updated });
  }
});

// Health Check
app.get('/health', (req, res) => {
  res.json({ status: 'OK', message: 'Parentpeak Backend läuft!' });
});

// ── Admin: Database Migrations ───────────────────────────────────────────────
app.post('/admin/migrate-db', async (req, res) => {
  const token = req.get('Authorization')?.replace('Bearer ', '');
  if (token !== process.env.BACKEND_API_TOKEN) {
    return res.status(403).json({ error: 'Unauthorized' });
  }

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

  const existing = deviceTokens.get(userId) || new Set();
  existing.add(token);
  deviceTokens.set(userId, existing);

  // Persist in DB if Prisma is available.
  try {
    await ensureBackendUser(userId, userId);
    // Upsert a marker in a custom field via raw SQL to avoid schema migration dependency.
    // The token set lives in-memory and is restored on restart via DB if schema has a DeviceToken table.
    // For now in-memory is the source of truth; schema migration is a separate step.
  } catch (_) {
    // Non-fatal: token is still registered in memory.
  }

  return res.json({ ok: true, userId, platform, tokenCount: existing.size });
});

app.delete('/devices/register-token', async (req, res) => {
  const userId = (req.body.userId || '').toString().trim();
  const token = (req.body.token || '').toString().trim();

  if (!userId || !token) {
    return res.status(400).json({ error: 'userId und token sind erforderlich' });
  }

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
        Object.entries(data).map(([k, v]) => [k, String(v)]),
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
app.get('/api/meal-plans/:familyId', async (req, res) => {
  const { familyId } = req.params;
  const { date } = req.query;

  try {
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
    console.error('❌ Fehler beim Abrufen des Essensplans:', err);
    res.status(500).json({ error: err.message });
  }
});

/**
 * GET /api/meal-plans/:familyId/week?startDate=YYYY-MM-DD
 * Hole komplette Woche (7 Tage) für eine Familie
 */
app.get('/api/meal-plans/:familyId/week', async (req, res) => {
  const { familyId } = req.params;
  const { startDate } = req.query;

  try {
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
    console.error('❌ Fehler beim Abrufen der Woche:', err);
    res.status(500).json({ error: err.message });
  }
});

/**
 * POST /api/meal-plans/:familyId
 * Erstelle oder aktualisiere Essensplan für einen Tag
 */
app.post('/api/meal-plans/:familyId', async (req, res) => {
  const { familyId } = req.params;
  const { date, meals } = req.body;

  if (requireAuthForWrites && !req.headers.authorization) {
    return res.status(401).json({ error: 'Authorization required' });
  }

  try {
    const targetDate = new Date(date);
    targetDate.setUTCHours(0, 0, 0, 0);

    // Lösche existierende Meals für diesen Tag
    await prisma.meal.deleteMany({
      where: {
        mealPlan: {
          familyId,
          date: targetDate,
        },
      },
    });

    // Erstelle oder update MealPlan
    const mealPlan = await prisma.mealPlan.upsert({
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

    // Erstelle neue Meals
    if (meals && meals.length > 0) {
      for (const meal of meals) {
        await prisma.meal.create({
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

    const updated = await prisma.mealPlan.findUnique({
      where: { id: mealPlan.id },
      include: {
        meals: {
          orderBy: { createdAt: 'asc' },
        },
      },
    });

    res.status(201).json(updated);
  } catch (err) {
    console.error('❌ Fehler beim Erstellen des Essensplans:', err);
    res.status(500).json({ error: err.message });
  }
});

/**
 * POST /api/meals/:mealPlanId
 * Füge einzelne Mahlzeit zum Essensplan hinzu
 */
app.post('/api/meals/:mealPlanId', async (req, res) => {
  const { mealPlanId } = req.params;
  const { title, type, description, ingredients } = req.body;

  if (requireAuthForWrites && !req.headers.authorization) {
    return res.status(401).json({ error: 'Authorization required' });
  }

  try {
    const meal = await prisma.meal.create({
      data: {
        mealPlanId,
        title,
        type,
        description: description || null,
        ingredients: JSON.stringify(ingredients || []),
      },
    });

    res.status(201).json(meal);
  } catch (err) {
    console.error('❌ Fehler beim Erstellen der Mahlzeit:', err);
    res.status(500).json({ error: err.message });
  }
});

/**
 * PUT /api/meals/:mealId
 * Aktualisiere eine Mahlzeit
 */
app.put('/api/meals/:mealId', async (req, res) => {
  const { mealId } = req.params;
  const { title, type, description, ingredients } = req.body;

  if (requireAuthForWrites && !req.headers.authorization) {
    return res.status(401).json({ error: 'Authorization required' });
  }

  try {
    const meal = await prisma.meal.update({
      where: { id: mealId },
      data: {
        title,
        type,
        description: description || null,
        ingredients: JSON.stringify(ingredients || []),
        updatedAt: new Date(),
      },
    });

    res.json(meal);
  } catch (err) {
    console.error('❌ Fehler beim Aktualisieren der Mahlzeit:', err);
    res.status(500).json({ error: err.message });
  }
});

/**
 * DELETE /api/meals/:mealId
 * Lösche eine Mahlzeit
 */
app.delete('/api/meals/:mealId', async (req, res) => {
  const { mealId } = req.params;

  if (requireAuthForWrites && !req.headers.authorization) {
    return res.status(401).json({ error: 'Authorization required' });
  }

  try {
    await prisma.meal.delete({
      where: { id: mealId },
    });

    res.json({ success: true, message: 'Mahlzeit gelöscht' });
  } catch (err) {
    console.error('❌ Fehler beim Löschen der Mahlzeit:', err);
    res.status(500).json({ error: err.message });
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
app.post('/api/parent-matching/profiles', async (req, res) => {
  const { userId, name, age, city, latitude, longitude, interests, languages, valuesFocus, childAges, familyForm, bio } = req.body;

  if (!userId || !name || !city) {
    return res.status(400).json({ error: 'userId, name, city erforderlich' });
  }

  if (age && (age < 18 || age > 120)) {
    return res.status(400).json({ error: 'Alter muss zwischen 18 und 120 liegen' });
  }

  try {
    const profile = await prisma.parentMatchingProfile.upsert({
      where: { ownerUserId: userId },
      update: {
        name: String(name).slice(0, 100),
        age: age ? parseInt(age, 10) : undefined,
        city: String(city).slice(0, 50),
        latitude: latitude ? parseFloat(latitude) : null,
        longitude: longitude ? parseFloat(longitude) : null,
        bio: bio ? String(bio).slice(0, 500) : null,
        interests: Array.isArray(interests) ? interests.map(i => String(i).slice(0, 50)) : [],
        languages: Array.isArray(languages) ? languages.map(l => String(l).slice(0, 30)) : [],
        valuesFocus: Array.isArray(valuesFocus) ? valuesFocus.map(v => String(v).slice(0, 50)) : [],
        childAges: Array.isArray(childAges) ? childAges.map(c => String(c).slice(0, 30)) : [],
        familyForm: familyForm ? String(familyForm).slice(0, 50) : null,
        updatedAt: new Date(),
      },
      create: {
        ownerUserId: userId,
        name: String(name).slice(0, 100),
        age: age ? parseInt(age, 10) : null,
        city: String(city).slice(0, 50),
        latitude: latitude ? parseFloat(latitude) : null,
        longitude: longitude ? parseFloat(longitude) : null,
        bio: bio ? String(bio).slice(0, 500) : null,
        interests: Array.isArray(interests) ? interests.map(i => String(i).slice(0, 50)) : [],
        languages: Array.isArray(languages) ? languages.map(l => String(l).slice(0, 30)) : [],
        valuesFocus: Array.isArray(valuesFocus) ? valuesFocus.map(v => String(v).slice(0, 50)) : [],
        childAges: Array.isArray(childAges) ? childAges.map(c => String(c).slice(0, 30)) : [],
        familyForm: familyForm ? String(familyForm).slice(0, 50) : null,
      },
    });

    res.json({ profile });
  } catch (err) {
    console.error('❌ Fehler beim Speichern des Matching-Profils:', err);
    res.status(500).json({ error: 'Profil konnte nicht gespeichert werden' });
  }
});

/**
 * GET /api/parent-matching/find
 * Find matching parent profiles with smart algorithm
 */
app.get('/api/parent-matching/find', async (req, res) => {
  const { userId, limit = '10', maxDistanceKm = '25' } = req.query;

  if (!userId) {
    return res.status(400).json({ error: 'userId erforderlich' });
  }

  try {
    const userProfile = await prisma.parentMatchingProfile.findUnique({
      where: { ownerUserId: userId },
    });

    if (!userProfile) {
      return res.json({ matches: [], message: 'Benutzerprofil nicht gefunden' });
    }

    const allProfiles = await prisma.parentMatchingProfile.findMany({
      where: {
        isActive: true,
        ownerUserId: { not: userId },
      },
      take: 100, // Get top candidates to score
    });

    const scored = allProfiles.map(candidate => {
      let score = 0;
      let breakdown = {};

      // Geographic proximity (0-40 points)
      if (userProfile.latitude && userProfile.longitude && candidate.latitude && candidate.longitude) {
        const distance = haversineDistance(
          userProfile.latitude,
          userProfile.longitude,
          candidate.latitude,
          candidate.longitude,
        );

        breakdown.distanceKm = Math.round(distance);
        if (distance <= parseFloat(maxDistanceKm)) {
          breakdown.proximityScore = Math.max(0, 40 - distance);
          score += breakdown.proximityScore;
        }
      }

      // Interest overlap (0-30 points)
      const interestSimilarity = jaccardSimilarity(userProfile.interests, candidate.interests);
      breakdown.interestSimilarity = Math.round(interestSimilarity * 100) / 100;
      breakdown.interestScore = Math.round(interestSimilarity * 30);
      score += breakdown.interestScore;

      // Child age compatibility (0-20 points)
      const childAgeSimilarity = jaccardSimilarity(userProfile.childAges, candidate.childAges);
      breakdown.childAgeScore = Math.round(childAgeSimilarity * 20);
      score += breakdown.childAgeScore;

      // Family form alignment (0-10 points)
      if (userProfile.familyForm && candidate.familyForm && userProfile.familyForm === candidate.familyForm) {
        breakdown.familyFormScore = 10;
        score += 10;
      }

      return {
        profile: candidate,
        score: Math.round(score),
        breakdown,
      };
    });

    const topMatches = scored
      .sort((a, b) => b.score - a.score)
      .slice(0, parseInt(limit, 10))
      .filter(m => m.score > 0);

    res.json({ matches: topMatches });
  } catch (err) {
    console.error('❌ Fehler beim Matching-Algorithmus:', err);
    res.status(500).json({ error: 'Matching konnte nicht durchgeführt werden' });
  }
});

/**
 * POST /api/parent-matching/record-action
 * Record user action (like, contact, pass)
 */
app.post('/api/parent-matching/record-action', async (req, res) => {
  const { userId, matchedProfileId, action, familyId } = req.body;

  if (!userId || !matchedProfileId || !action) {
    return res.status(400).json({ error: 'userId, matchedProfileId, action erforderlich' });
  }

  const validActions = ['like', 'contact', 'pass', 'favorite'];
  if (!validActions.includes(action)) {
    return res.status(400).json({ error: `Ungültige Aktion. Erlaubt: ${validActions.join(', ')}` });
  }

  try {
    const record = await prisma.parentMatchingAction.create({
      data: {
        familyId: familyId || userId,
        profileId: matchedProfileId,
        action,
        actorUserId: userId,
      },
    });

    res.status(201).json({ action: record });
  } catch (err) {
    console.error('❌ Fehler beim Speichern der Aktion:', err);
    res.status(500).json({ error: 'Aktion konnte nicht gespeichert werden' });
  }
});

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
app.post('/api/events', async (req, res) => {
  const {
    hosterId, title, description, location, latitude, longitude,
    startDate, endDate, eventType, visibility, shareRadiusKm, maxParticipants,
    costPerPerson, imageUrl, ageGroups
  } = req.body;

  // Validate required fields
  if (!hosterId || !title || !location || latitude === undefined || longitude === undefined) {
    return res.status(400).json({
      error: 'hosterId, title, location, latitude, longitude erforderlich'
    });
  }

  // Validate coordinates
  if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
    return res.status(400).json({ error: 'Ungültige Koordinaten' });
  }

  // Validate title length
  if (String(title).length < 3 || String(title).length > 200) {
    return res.status(400).json({ error: 'Titel muss 3-200 Zeichen lang sein' });
  }

  try {
    const event = await prisma.event.create({
      data: {
        hosterId: String(hosterId).slice(0, 100),
        title: String(title).slice(0, 200),
        description: description ? String(description).slice(0, 2000) : null,
        location: String(location).slice(0, 200),
        latitude: parseFloat(latitude),
        longitude: parseFloat(longitude),
        startDate: startDate ? new Date(startDate) : new Date(),
        endDate: endDate ? new Date(endDate) : null,
        eventType: eventType ? String(eventType).slice(0, 50) : 'generic',
        visibility: visibility ? String(visibility).slice(0, 50) : 'publicNearby',
        shareRadiusKm: shareRadiusKm ? parseFloat(shareRadiusKm) : 25,
        maxParticipants: maxParticipants ? parseInt(maxParticipants, 10) : null,
        costPerPerson: costPerPerson ? parseFloat(costPerPerson) : null,
        imageUrl: imageUrl ? String(imageUrl).slice(0, 500) : null,
        status: 'upcoming',
      },
      include: { participants: true }
    });

    res.status(201).json({ event });
  } catch (err) {
    console.error('❌ Event creation error:', err.message, err);
    res.status(500).json({ error: `Event creation failed: ${err.message}` });
  }
});

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
    const where = {
      status: String(status),
      visibility: String(visibility),
      ...(eventType && { eventType: String(eventType) }),
      ...(hosterId && { hosterId: String(hosterId) }),
    };

    let events = await prisma.event.findMany({
      where,
      orderBy: { startDate: 'asc' },
      take: Math.min(parseInt(maxResults, 10) || 50, 100),
      skip: parseInt(offset, 10) || 0,
      include: {
        participants: { select: { userId: true, status: true } }
      }
    });

    // Filter by geographic proximity if coordinates provided
    if (latitude !== undefined && longitude !== undefined) {
      const viewerLat = parseFloat(latitude);
      const viewerLon = parseFloat(longitude);
      const maxDistance = parseFloat(radiusKm) || 25;

      events = events.filter(event => {
        const distance = haversineDistance(viewerLat, viewerLon, event.latitude, event.longitude);
        return distance <= maxDistance;
      }).sort((a, b) => {
        const distA = haversineDistance(viewerLat, viewerLon, a.latitude, a.longitude);
        const distB = haversineDistance(viewerLat, viewerLon, b.latitude, b.longitude);
        return distA - distB; // Closest first
      });
    }

    const formattedEvents = events.map(e => ({
      id: e.id,
      hosterId: e.hosterId,
      title: e.title,
      description: e.description,
      location: e.location,
      latitude: e.latitude,
      longitude: e.longitude,
      startDate: e.startDate,
      endDate: e.endDate,
      eventType: e.eventType,
      visibility: e.visibility,
      shareRadiusKm: e.shareRadiusKm,
      maxParticipants: e.maxParticipants,
      currentParticipants: e.participants.filter(p => p.status !== 'declined').length,
      costPerPerson: e.costPerPerson,
      imageUrl: e.imageUrl,
      status: e.status,
      createdAt: e.createdAt,
      updatedAt: e.updatedAt,
    }));

    res.json({ events: formattedEvents, total: formattedEvents.length });
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

    const formattedEvent = {
      ...event,
      currentParticipants: event.participants.filter(p => p.status !== 'declined').length,
      isFull: event.maxParticipants ? 
        event.participants.filter(p => p.status !== 'declined').length >= event.maxParticipants : 
        false,
      spotsAvailable: event.maxParticipants ? 
        Math.max(0, event.maxParticipants - event.participants.filter(p => p.status !== 'declined').length) : 
        null,
    };

    res.json({ event: formattedEvent });
  } catch (err) {
    console.error('❌ Event detail error:', err.message);
    res.status(500).json({ error: `Failed to get event: ${err.message}` });
  }
});

/**
 * PUT /api/events/:id
 * Update event (owner only)
 */
app.put('/api/events/:id', async (req, res) => {
  const { id } = req.params;
  const { hosterId, title, description, location, latitude, longitude, startDate, endDate, maxParticipants } = req.body;

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

    const updatedEvent = await prisma.event.update({
      where: { id },
      data: {
        ...(title && { title: String(title).slice(0, 200) }),
        ...(description && { description: String(description).slice(0, 2000) }),
        ...(location && { location: String(location).slice(0, 200) }),
        ...(latitude !== undefined && { latitude: parseFloat(latitude) }),
        ...(longitude !== undefined && { longitude: parseFloat(longitude) }),
        ...(startDate && { startDate: new Date(startDate) }),
        ...(endDate && { endDate: new Date(endDate) }),
        ...(maxParticipants !== undefined && { maxParticipants: parseInt(maxParticipants, 10) }),
        updatedAt: new Date(),
      },
      include: { participants: true }
    });

    res.json({ event: updatedEvent });
  } catch (err) {
    console.error('❌ Event update error:', err.message);
    res.status(500).json({ error: `Failed to update event: ${err.message}` });
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
app.post('/api/community-events/:id/flag', async (req, res) => {
  const { id } = req.params;
  const { userId, reason } = req.body;

  if (!userId || !reason) {
    return res.status(400).json({ error: 'userId und reason erforderlich' });
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
    userId, title, description, location, latitude, longitude,
    category, condition, isFree, price, visibility, shareRadiusKm, photoUrl
  } = req.body;

  // Validate required fields
  if (!userId || !title || !location || latitude === undefined || longitude === undefined) {
    return res.status(400).json({
      error: 'userId, title, location, latitude, longitude erforderlich'
    });
  }

  // Validate coordinates
  if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
    return res.status(400).json({ error: 'Ungültige Koordinaten' });
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
        shareRadiusKm: shareRadiusKm ? parseFloat(shareRadiusKm) : 10,
        photoUrl: photoUrl ? String(photoUrl).slice(0, 500) : null,
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
    let treasures = await prisma.treasureItem.findMany({
      where: {
        status: status,
        visibility: visibility,
        ...(category && { category: String(category) }),
        ...(condition && { condition: String(condition) })
      },
      orderBy: { createdAt: 'desc' },
      take: Math.min(parseInt(maxResults, 10) || 50, 100),
      skip: parseInt(offset, 10) || 0,
      include: { ratings: true, handovers: true }
    });

    // Filter by geographic proximity if coordinates provided
    if (latitude !== undefined && longitude !== undefined) {
      const viewerLat = parseFloat(latitude);
      const viewerLon = parseFloat(longitude);
      const maxDistance = parseFloat(radiusKm) || 10;

      treasures = treasures.filter(treasure => {
        if (!treasure.latitude || !treasure.longitude) return false;
        const distance = haversineDistance(viewerLat, viewerLon, treasure.latitude, treasure.longitude);
        return distance <= maxDistance;
      }).sort((a, b) => {
        const distA = haversineDistance(viewerLat, viewerLon, a.latitude, a.longitude);
        const distB = haversineDistance(viewerLat, viewerLon, b.latitude, b.longitude);
        return distA - distB; // Closest first
      });
    }

    const formattedTreasures = treasures.map(t => ({
      id: t.id,
      userId: t.userId,
      title: t.title,
      description: t.description,
      location: t.location,
      latitude: t.latitude,
      longitude: t.longitude,
      category: t.category,
      condition: t.condition,
      visibility: t.visibility,
      shareRadiusKm: t.shareRadiusKm,
      isFree: t.isFree,
      price: t.price,
      photoUrl: t.photoUrl,
      status: t.status,
      rating: t.rating,
      ratingCount: t.ratingCount,
      createdAt: t.createdAt,
      expiresAt: t.expiresAt,
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
app.post('/api/treasures/:id/report', async (req, res) => {
  const { id } = req.params;
  const { reporterUserId, reason, note } = req.body;

  if (!reporterUserId || !reason) {
    return res.status(400).json({ error: 'reporterUserId und reason erforderlich' });
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
 * GET /api/treasures/reports
 * List treasure reports (admin token required)
 */
app.get('/api/treasures/reports', async (req, res) => {
  if (!isAdminTokenAuthorized(req)) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

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
app.post('/api/treasures/reports/:reportId/resolve', async (req, res) => {
  if (!isAdminTokenAuthorized(req)) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  const { reportId } = req.params;
  const { action = 'resolved', moderatorId, moderatorNote } = req.body;
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

    const updated = await prisma.treasureReport.update({
      where: { id: reportId },
      data: {
        status: normalizedAction,
        moderatorId: moderatorId ? String(moderatorId).slice(0, 120) : null,
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

    res.json({ report: updated });
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
      include: {
        ratings: { include: { fromUser: { select: { id: true, firstName: true, lastName: true, avatar: true } } } },
        handovers: true
      }
    });

    if (!treasure) {
      return res.status(404).json({ error: 'Treasure nicht gefunden' });
    }

    // Increment view count
    await prisma.treasureItem.update({
      where: { id },
      data: { views: { increment: 1 } }
    });

    const formattedTreasure = {
      ...treasure,
      availableHandovers: treasure.handovers.filter(h => h.status === 'pending').length,
      claimedCount: treasure.handovers.filter(h => h.status === 'confirmed' || h.status === 'completed').length
    };

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
  const { userId, title, description, location, latitude, longitude, condition, status } = req.body;

  if (!userId) {
    return res.status(400).json({ error: 'userId erforderlich' });
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
  const { userId } = req.query;

  if (!userId) {
    return res.status(400).json({ error: 'userId erforderlich' });
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
