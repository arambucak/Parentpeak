'use strict';

/**
 * Weekly-Impulse Lokalisierung.
 *
 * Prüft statisch (ohne den Server zu starten), dass der Tagesimpuls-Pool für
 * alle unterstützten App-Sprachen vollständig übersetzt ist und dass die
 * localize-Funktion die aktive Overlay-Map (DAILY_IMPULSE_TRANSLATIONS) nutzt.
 * Hintergrund: Zuvor las localizeWeeklyImpulseTopic eine fast leere
 * WEEKLY_IMPULSE_TRANSLATIONS-Map, wodurch der Impuls faktisch immer deutsch
 * blieb.
 */
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const SERVER = path.join(__dirname, '..', '..', 'server.js');
const src = fs.readFileSync(SERVER, 'utf8');

function extractBalanced(marker, open, close) {
  const i = src.indexOf(marker);
  assert.ok(i !== -1, `Marker nicht gefunden: ${marker}`);
  const start = src.indexOf(open, i);
  let depth = 0;
  let inStr = null;
  for (let j = start; j < src.length; j++) {
    const c = src[j];
    const p = src[j - 1];
    if (inStr) {
      if (c === inStr && p !== '\\') inStr = null;
      continue;
    }
    if (c === '"' || c === "'" || c === '`') {
      inStr = c;
      continue;
    }
    if (c === open) depth++;
    else if (c === close) {
      depth--;
      if (depth === 0) return src.slice(start, j + 1);
    }
  }
  throw new Error(`unbalanced for ${marker}`);
}

// eslint-disable-next-line no-eval
const POOL = eval('(' + extractBalanced('const DAILY_IMPULSE_POOL', '[', ']') + ')');
// eslint-disable-next-line no-eval
const TR = eval('(' + extractBalanced('const DAILY_IMPULSE_TRANSLATIONS', '{', '}') + ')');

const LANGS = ['en', 'tr', 'ku', 'fr', 'es', 'it', 'ar'];
const FIELDS = [
  'title',
  'parent_lens',
  'parent_tips',
  'practical_tip',
  'discussion_body',
  'companion_quick',
  'companion_reflect',
];

test('localizeWeeklyImpulseTopic liest DAILY_IMPULSE_TRANSLATIONS (nicht die verwaiste Weekly-Map)', () => {
  assert.ok(
    /DAILY_IMPULSE_TRANSLATIONS\[language\]\?\.\[topic\.key\]/.test(src),
    'localize-Funktion muss DAILY_IMPULSE_TRANSLATIONS[language][topic.key] nutzen',
  );
  assert.ok(
    !src.includes('WEEKLY_IMPULSE_TRANSLATIONS'),
    'die verwaiste WEEKLY_IMPULSE_TRANSLATIONS darf nicht mehr existieren',
  );
});

for (const lang of LANGS) {
  test(`Tagesimpuls-Pool ist vollständig übersetzt für ${lang}`, () => {
    assert.ok(TR[lang], `Sprache fehlt in DAILY_IMPULSE_TRANSLATIONS: ${lang}`);
    for (const topic of POOL) {
      const v = TR[lang][topic.key];
      assert.ok(v, `${lang}: Topic fehlt: ${topic.key}`);
      for (const f of FIELDS) {
        assert.ok(f in v, `${lang}/${topic.key}: Feld fehlt: ${f}`);
      }
      assert.strictEqual(
        v.parent_tips.length,
        3,
        `${lang}/${topic.key}: parent_tips muss 3 Einträge haben`,
      );
      // tatsächlich übersetzt: Titel weicht vom deutschen Original ab
      assert.notStrictEqual(
        v.title,
        topic.title,
        `${lang}/${topic.key}: Titel ist noch deutsch`,
      );
    }
  });
}

test('labels-Map deckt alle App-Sprachen ab (hero_headline/min)', () => {
  // Der labels-Block steht inline in buildWeeklyImpulseResponse; wir prüfen,
  // dass für jede Sprache ein eigener Label-Block existiert.
  for (const lang of LANGS) {
    const re = new RegExp(`\\n\\s{4}${lang}: \\{\\n\\s{6}hero_headline:`);
    assert.ok(re.test(src), `labels-Block fehlt oder unvollständig für ${lang}`);
  }
});
