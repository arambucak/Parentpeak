const MEMORY_CONSENT_VERSION = 'chat-memory-v1';

function hasMemoryConsent(settings) {
  return settings?.enabled === true && settings.consentVersion === MEMORY_CONSENT_VERSION &&
    typeof settings.consentRevision === 'string' && settings.consentRevision.length > 0;
}

function completedYears(birthDate, now = new Date()) {
  if (birthDate == null || birthDate === '') return null;
  const birth = new Date(birthDate);
  if (!Number.isFinite(birth.getTime())) return null;
  const birthDay = Date.UTC(birth.getUTCFullYear(), birth.getUTCMonth(), birth.getUTCDate());
  const today = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());
  if (birthDay > today) return null;
  let years = now.getUTCFullYear() - birth.getUTCFullYear();
  if (now.getUTCMonth() < birth.getUTCMonth() ||
      (now.getUTCMonth() === birth.getUTCMonth() && now.getUTCDate() < birth.getUTCDate())) years--;
  return years;
}

function minimizeMemoryText(value, children, tokenFor = (_, index) => `[CHILD_${index + 1}]`) {
  let text = String(value);
  const identities = children.map((child, index) => ({ child, index }))
    .sort((a, b) => String(b.child.name || '').length - String(a.child.name || '').length);
  for (const { index, child } of identities) {
    const name = String(child.name || '').trim();
    if (name && !name.startsWith('[CHILD')) {
      const escaped = name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      text = text.replace(new RegExp(`(?<![\\p{L}\\p{N}])${escaped}(?![\\p{L}\\p{N}])`, 'giu'), tokenFor(child, index));
    }
    if (child.birthDate) {
      const birth = new Date(child.birthDate);
      if (Number.isFinite(birth.getTime())) {
        const iso = birth.toISOString().slice(0, 10);
        const day = birth.getUTCDate(), month = birth.getUTCMonth() + 1, year = birth.getUTCFullYear();
        for (const date of [iso, `${String(day).padStart(2, '0')}.${String(month).padStart(2, '0')}.${year}`, `${day}.${month}.${year}`]) {
          text = text.split(date).join('[BIRTH_DATE]');
        }
      }
    }
  }
  return text;
}

function buildMemoryContext(children, now = new Date(), identities = children) {
  if (!children.length) return '';
  const lines = ['CONFIRMED FAMILY CONTEXT (use only when relevant):'];
  for (const [index, child] of children.entries()) {
    const age = child.birthDate ? completedYears(child.birthDate, now) : null;
    lines.push(`Child: [CHILD_${index + 1}]${age === null ? '' : `, completed age in years: ${age}`}`);
    for (const item of child.memoryItems) {
      if (item.status !== 'confirmed') continue;
      const line = `- ${item.category}/${item.key}: ${item.value}`.replaceAll('[THIS_CHILD]', `[CHILD_${index + 1}]`);
      lines.push(minimizeMemoryText(line, identities));
    }
  }
  lines.push('Use the child placeholders, never invent names or birthdays. Do not treat context as a diagnosis. Ask about contradictions.');
  return lines.join('\n');
}

module.exports = { MEMORY_CONSENT_VERSION, hasMemoryConsent, completedYears, minimizeMemoryText, buildMemoryContext };
