const crypto = require('node:crypto');
const fs = require('node:fs/promises');
const path = require('node:path');
const sharp = require('sharp');

const formats = new Set(['jpeg', 'png', 'webp', 'gif']);
const maxPixels = 40_000_000;
const maxOutputBytes = 10 * 1024 * 1024;

class InvalidImageError extends Error {}

async function publishSanitizedImage(file, uploadsDir) {
  const temporaryOutput = `${file.path}.sanitized`;
  try {
    let result;
    try {
      const image = sharp(file.path, {
        animated: true,
        limitInputPixels: maxPixels,
        failOn: 'warning',
      }).timeout({ seconds: 10 });
      const metadata = await image.metadata();
      if (!formats.has(metadata.format)) {
        throw new InvalidImageError('Nur JPEG, PNG, WebP und GIF sind erlaubt');
      }
      // Apply camera orientation before dropping all original metadata.
      result = await image.autoOrient().toFormat(metadata.format).toBuffer({ resolveWithObject: true });
    } catch (error) {
      if (error instanceof InvalidImageError) throw error;
      throw new InvalidImageError('Bild ist ungueltig oder zu gross fuer die Verarbeitung', { cause: error });
    }
    if (result.data.length > maxOutputBytes) {
      throw new InvalidImageError('Verarbeitetes Bild ist groesser als 10 MiB');
    }
    const extension = result.info.format === 'jpeg' ? 'jpg' : result.info.format;
    const filename = `sanitized-${crypto.randomBytes(16).toString('hex')}.${extension}`;
    await fs.writeFile(temporaryOutput, result.data, { flag: 'wx', mode: 0o600 });
    await fs.rename(temporaryOutput, path.join(uploadsDir, filename));
    return { filename, size: result.data.length };
  } finally {
    await fs.rm(file.path, { force: true });
    await fs.rm(temporaryOutput, { force: true });
  }
}

function allowPublicImage(req, res, next) {
  if (req.method !== 'GET' && req.method !== 'HEAD') return next();
  if (!/^\/[a-z0-9_-]+\.(?:jpe?g|png|webp|gif)$/i.test(req.path)) {
    return res.status(404).json({ error: 'Bild nicht gefunden' });
  }
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('Content-Security-Policy', "default-src 'none'; sandbox");
  return next();
}

module.exports = { publishSanitizedImage, allowPublicImage, InvalidImageError };
