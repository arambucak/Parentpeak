'use strict';

const params = new URLSearchParams(window.location.search);
const mode = params.get('mode') || '';
const oobCode = params.get('oobCode') || '';
// Keep one-time codes out of subsequent history entries and outgoing referrers.
window.history.replaceState(null, '', window.location.pathname);

function show(id) {
  document.querySelectorAll('[id^="screen-"]').forEach(element => {
    element.hidden = element.id !== id;
  });
  const heading = document.querySelector(`#${id} h1`);
  if (heading) {
    document.title = `${heading.textContent} | ParentPeak`;
    heading.focus();
  }
}

function showAlert(id, message) {
  const alert = document.getElementById(id);
  alert.textContent = message;
  alert.hidden = false;
}

function mapError(code) {
  const messages = {
    'auth/expired-action-code': 'Dieser Link ist abgelaufen. Fordere bitte in der ParentPeak-App einen neuen Link an.',
    'auth/invalid-action-code': 'Dieser Link ist ungültig oder wurde bereits verwendet. Fordere bitte in der ParentPeak-App einen neuen Link an.',
    'auth/user-disabled': 'Dieses Konto ist derzeit deaktiviert. Bitte wende dich über die App an den Support.',
    'auth/user-not-found': 'Dieser Link kann nicht mehr verwendet werden. Fordere bitte in der ParentPeak-App einen neuen Link an.',
    'auth/weak-password': 'Dieses Passwort ist zu schwach. Bitte wähle ein längeres, einzigartiges Passwort.',
    'auth/password-does-not-meet-requirements': 'Dieses Passwort erfüllt die Sicherheitsanforderungen nicht. Bitte verwende ein längeres Passwort mit Groß- und Kleinbuchstaben, Zahlen und Sonderzeichen.',
    'auth/network-request-failed': 'Die Verbindung ist gerade unterbrochen. Prüfe bitte dein Internet und versuche es erneut.',
    'auth/too-many-requests': 'Das waren gerade zu viele Versuche. Bitte warte etwas und versuche es dann erneut.',
  };
  return messages[code] || 'Das hat gerade nicht geklappt. Bitte versuche es später erneut oder fordere in der App einen neuen Link an.';
}

function showError(error, retry) {
  document.getElementById('error-detail').textContent = mapError(error.code);
  const retryButton = document.getElementById('retry-btn');
  retryButton.hidden = !retry;
  retryButton.onclick = retry || null;
  show('screen-error');
}

function checkStrength(password) {
  let score = 0;
  if (password.length >= 8) score++;
  if (password.length >= 12) score++;
  if (password.length >= 16) score++;
  if (/[A-Z]/.test(password) && /[a-z]/.test(password)) score++;
  if (/[0-9]/.test(password) && /[^A-Za-z0-9]/.test(password)) score++;
  const labels = ['', 'Noch ausbaufähig', 'Ein guter Anfang', 'Gut', 'Stark', 'Sehr stark'];
  document.getElementById('strength-fill').style.width = `${score * 20}%`;
  document.getElementById('strength-label').textContent = password ? labels[score] || 'Mindestens 8 Zeichen verwenden.' : '';
}

document.querySelectorAll('.visibility-toggle').forEach(button => {
  button.addEventListener('click', () => {
    const input = document.getElementById(button.getAttribute('aria-controls'));
    const visible = input.type === 'password';
    input.type = visible ? 'text' : 'password';
    button.setAttribute('aria-pressed', String(visible));
    button.textContent = visible ? 'Verbergen' : 'Anzeigen';
    const label = input.id === 'new-password' ? 'Neues Passwort' : 'Wiederholtes Passwort';
    button.setAttribute('aria-label', `${label} ${visible ? 'verbergen' : 'anzeigen'}`);
  });
});
document.getElementById('new-password').addEventListener('input', event => {
  checkStrength(event.target.value);
  event.target.removeAttribute('aria-invalid');
});
document.getElementById('confirm-password').addEventListener('input', event => {
  event.target.removeAttribute('aria-invalid');
});

async function initResetPassword(auth) {
  show('screen-loading');
  try {
    await auth.verifyPasswordResetCode(oobCode);
    show('screen-reset');
  } catch (error) {
    showError(error, error.code === 'auth/network-request-failed' ? () => initResetPassword(auth) : null);
    return;
  }

  document.getElementById('reset-form').onsubmit = async event => {
    event.preventDefault();
    const password = document.getElementById('new-password');
    const confirmation = document.getElementById('confirm-password');
    document.getElementById('reset-alert').hidden = true;
    password.removeAttribute('aria-invalid');
    confirmation.removeAttribute('aria-invalid');
    if (password.value.length < 8) {
      showAlert('reset-alert', 'Bitte verwende ein Passwort mit mindestens 8 Zeichen.');
      password.setAttribute('aria-invalid', 'true');
      password.focus();
      return;
    }
    if (password.value !== confirmation.value) {
      showAlert('reset-alert', 'Die Passwörter stimmen noch nicht überein. Bitte prüfe deine Eingabe.');
      confirmation.setAttribute('aria-invalid', 'true');
      confirmation.focus();
      return;
    }

    const button = document.getElementById('reset-btn');
    if (button.disabled) return;
    button.disabled = true;
    button.setAttribute('aria-busy', 'true');
    button.textContent = 'Wird gespeichert …';
    try {
      await auth.confirmPasswordReset(oobCode, password.value);
      password.value = '';
      confirmation.value = '';
      show('screen-reset-done');
    } catch (error) {
      showAlert('reset-alert', mapError(error.code));
    } finally {
      button.disabled = false;
      button.removeAttribute('aria-busy');
      button.textContent = 'Neues Passwort speichern';
    }
  };
}

async function initVerifyEmail(auth) {
  show('screen-verify');
  try {
    const info = await auth.checkActionCode(oobCode);
    if (info.operation !== 'VERIFY_EMAIL') {
      showError({ code: 'auth/invalid-action-code' });
      return;
    }
    await auth.applyActionCode(oobCode);
    show('screen-verify-done');
  } catch (error) {
    showError(error, error.code === 'auth/network-request-failed' ? () => initVerifyEmail(auth) : null);
  }
}

async function initRecoverEmail(auth) {
  show('screen-loading');
  try {
    const info = await auth.checkActionCode(oobCode);
    if (info.operation !== 'RECOVER_EMAIL') {
      showError({ code: 'auth/invalid-action-code' });
      return;
    }
    show('screen-recover');
  } catch (error) {
    showError(error, error.code === 'auth/network-request-failed' ? () => initRecoverEmail(auth) : null);
    return;
  }
  document.getElementById('recover-btn').onclick = async function () {
    if (this.disabled) return;
    this.disabled = true;
    this.textContent = 'Wird wiederhergestellt …';
    try {
      await auth.applyActionCode(oobCode);
      show('screen-recover-done');
    } catch (error) {
      showAlert('recover-alert', mapError(error.code));
    } finally {
      this.disabled = false;
      this.textContent = 'Vorherige E-Mail wiederherstellen';
    }
  };
}

function start() {
  if (!oobCode || !['resetPassword', 'verifyEmail', 'recoverEmail'].includes(mode)) {
    showError({ code: 'auth/invalid-action-code' });
    return;
  }
  if (typeof firebase === 'undefined') {
    document.getElementById('error-detail').textContent = 'Die Kontoseite konnte nicht vollständig geladen werden. Prüfe bitte deine Verbindung und öffne den Link aus deiner E-Mail erneut.';
    show('screen-error');
    return;
  }
  try {
    firebase.initializeApp({
      apiKey: 'AIzaSyAwLIoizIEAVjoM4WWBBSi9DPG5ZJDOFk0',
      authDomain: 'parentpeak-prod-2026.firebaseapp.com',
      projectId: 'parentpeak-prod-2026',
      storageBucket: 'parentpeak-prod-2026.firebasestorage.app',
      messagingSenderId: '89417219632',
      measurementId: 'G-9R8Z7RXYVP',
      appId: '1:89417219632:web:51b6fa43ffa2b52f1bf7f5',
    });
    const auth = firebase.auth();
    auth.languageCode = 'de';
    if (mode === 'resetPassword') initResetPassword(auth);
    if (mode === 'verifyEmail') initVerifyEmail(auth);
    if (mode === 'recoverEmail') initRecoverEmail(auth);
  } catch (error) {
    showError(error);
  }
}

start();
