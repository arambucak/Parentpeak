/// Content moderation for the Eltern-Netzwerk chat.
/// Filters inappropriate content to keep the community safe for families.
///
/// Based on: anthropics/claude-cookbooks moderation pattern.
/// Adapted for Parentpeak: family-friendly, no profanity, no harassment,
/// no spam, no commercial content.
class ChatModerationService {
  static final ChatModerationService instance = ChatModerationService._();
  ChatModerationService._();

  /// Check if a message is appropriate for the family community.
  /// Returns null if OK, or a reason string if blocked.
  String? checkMessage(String message) {
    if (message.trim().isEmpty) return null;

    final lower = message.toLowerCase();

    // Check for profanity/insults
    if (_containsProfanity(lower)) {
      return 'Bitte achte auf einen respektvollen Umgang in unserer Community.';
    }

    // Check for harassment
    if (_containsHarassment(lower)) {
      return 'Diese Nachricht könnte verletzend wirken. Bitte formuliere sie freundlicher.';
    }

    // Check for spam patterns
    if (_isSpam(message)) {
      return 'Diese Nachricht wurde als Spam erkannt.';
    }

    // Check for commercial content
    if (_isCommercial(lower)) {
      return 'Werbung und kommerzielle Inhalte sind in der Community nicht erlaubt.';
    }

    // Check for personal data sharing warnings
    if (_containsSensitiveData(lower)) {
      return 'Bitte teile keine persönlichen Daten (Telefonnummer, Adresse) im Chat. Nutze dafür private Nachrichten.';
    }

    return null; // Message is OK
  }

  /// Quick check - returns true if message is safe
  bool isSafe(String message) => checkMessage(message) == null;

  // ─── Private Checks ────────────────────────────────────────────────────────

  bool _containsProfanity(String text) {
    const profanityPatterns = [
      'fick',
      'scheiß',
      'arsch',
      'hurensohn',
      'wichser',
      'fotze',
      'missgeburt',
      'behindert',
      'spast',
      'mongo',
      'fuck',
      'shit',
      'bitch',
      'asshole',
      'cunt',
      'nigger',
      'faggot',
      'siktir',
      'amina',
      'orospu',
    ];
    for (final word in profanityPatterns) {
      if (text.contains(word)) return true;
    }
    return false;
  }

  bool _containsHarassment(String text) {
    const patterns = [
      'du bist dumm',
      'du bist hässlich',
      'halt die fresse',
      'du bist eine schlechte mutter',
      'du bist ein schlechter vater',
      'dein kind ist',
      'was für eltern',
      'kill yourself',
      'kys',
      'bring dich um',
    ];
    for (final pattern in patterns) {
      if (text.contains(pattern)) return true;
    }
    return false;
  }

  bool _isSpam(String message) {
    // Sehr lange Wiederholung desselben Zeichens (z. B. "aaaaaaaaa") -> Spam.
    if (RegExp(r'(.)\1{8,}').hasMatch(message)) return true;

    // Grossschreibung ist KEIN Spam. Eltern schreiben aus vielen legitimen
    // Gruenden gross ("WICHTIG", "BITTE MELDEN") oder mit aktivierter
    // Feststelltaste. Solche Nachrichten zu blockieren wirkt wie eine Strafe
    // und widerspricht der GfK-Philosophie -> bewusst KEIN Caps-Block mehr.

    // Zu viele Links deuten auf Spam hin.
    final linkCount = RegExp(r'https?://').allMatches(message).length;
    if (linkCount > 2) return true;

    return false;
  }

  bool _isCommercial(String text) {
    const patterns = [
      'kaufe jetzt',
      'buy now',
      'angebot nur heute',
      'klick hier',
      'click here',
      'gratis geschenk',
      'verdiene geld',
      'make money',
      'earn money',
      'mlm',
      'network marketing',
      'crypto invest',
      'abnehmen in',
      'weight loss',
    ];
    for (final pattern in patterns) {
      if (text.contains(pattern)) return true;
    }
    return false;
  }

  bool _containsSensitiveData(String text) {
    // Phone numbers (German format)
    if (RegExp(r'\b0\d{3,4}[\s/-]?\d{5,8}\b').hasMatch(text)) return true;
    if (RegExp(r'\+49\s?\d').hasMatch(text)) return true;

    // Full addresses (street + number)
    if (RegExp(
            r'\b[A-ZÄÖÜ][a-zäöü]+(?:straße|str\.|weg|gasse|platz|allee)\s+\d',
            caseSensitive: false)
        .hasMatch(text)) return true;

    return false;
  }
}
