import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/config/api_config.dart';
import 'package:parentpeak/logic/auth_service.dart';

/// ParentCoin-System — Belohnungs-Engine für Einladungen.
///
/// 1 erfolgreiche Einladung = 1 ParentCoin (Wert: 1 EUR)
/// 5 ParentCoins = 1 Monat Premium kostenlos
/// Bonus: 3 Einladungen = "Community-Eltern" Badge
///
/// Coins werden lokal gespeichert + später mit Backend synchronisiert.
class ParentCoinService extends ChangeNotifier {
  ParentCoinService._();
  static final ParentCoinService instance = ParentCoinService._();

  static const int coinsForFreePremium = 5;
  static const double coinValueEur = 1.0;

  int _balance = 0;
  int _totalEarned = 0;
  int _totalSpent = 0;
  int _successfulInvites = 0;
  String? _referralCode;
  List<CoinTransaction> _history = [];

  int get balance => _balance;
  int get totalEarned => _totalEarned;
  int get totalSpent => _totalSpent;
  int get successfulInvites => _successfulInvites;
  String get referralCode => _referralCode ?? _generateReferralCode();
  bool get hasCommunityBadge => _successfulInvites >= 3;
  int get coinsUntilFreePremium => (coinsForFreePremium - _balance).clamp(0, coinsForFreePremium);
  double get progressToFreePremium => _balance / coinsForFreePremium;
  List<CoinTransaction> get history => List.unmodifiable(_history);

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _balance = prefs.getInt('coins.balance') ?? 0;
    _totalEarned = prefs.getInt('coins.earned') ?? 0;
    _totalSpent = prefs.getInt('coins.spent') ?? 0;
    _successfulInvites = prefs.getInt('coins.invites') ?? 0;
    _referralCode = prefs.getString('coins.referral_code');
    final historyRaw = prefs.getString('coins.history');
    if (historyRaw != null && historyRaw.isNotEmpty) {
      try {
        final list = jsonDecode(historyRaw) as List;
        _history = list.map((e) => CoinTransaction.fromJson(e)).toList();
      } catch (_) {}
    }
    if (_referralCode == null) {
      _referralCode = _generateReferralCode();
      await prefs.setString('coins.referral_code', _referralCode!);
    }
    _initialized = true;
    notifyListeners();
  }

  String _generateReferralCode() {
    final uid = AuthService.instance.currentUser?.uid ?? 'guest';
    final short = uid.length > 6 ? uid.substring(0, 6) : uid;
    return 'PP-${short.toUpperCase()}';
  }

  /// Wird aufgerufen wenn eine eingeladene Person sich registriert.
  Future<void> earnCoinFromInvite(String invitedUserName) async {
    _balance += 1;
    _totalEarned += 1;
    _successfulInvites += 1;
    _history.insert(0, CoinTransaction(
      type: CoinTransactionType.earned,
      amount: 1,
      reason: 'Einladung: $invitedUserName hat sich registriert',
      date: DateTime.now(),
    ));
    await _persist();
    notifyListeners();
  }

  /// Coins für Premium einloesen.
  Future<bool> redeemForPremium() async {
    if (_balance < coinsForFreePremium) return false;
    _balance -= coinsForFreePremium;
    _totalSpent += coinsForFreePremium;
    _history.insert(0, CoinTransaction(
      type: CoinTransactionType.spent,
      amount: coinsForFreePremium,
      reason: '1 Monat Premium freigeschaltet',
      date: DateTime.now(),
    ));
    await _persist();
    notifyListeners();
    return true;
  }

  /// Bonus-Coins (z.B. für App-Bewertung, erstes Kind-Profil etc.)
  Future<void> earnBonus(int amount, String reason) async {
    _balance += amount;
    _totalEarned += amount;
    _history.insert(0, CoinTransaction(
      type: CoinTransactionType.bonus,
      amount: amount,
      reason: reason,
      date: DateTime.now(),
    ));
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('coins.balance', _balance);
    await prefs.setInt('coins.earned', _totalEarned);
    await prefs.setInt('coins.spent', _totalSpent);
    await prefs.setInt('coins.invites', _successfulInvites);
    final historyJson = jsonEncode(_history.take(50).map((e) => e.toJson()).toList());
    await prefs.setString('coins.history', historyJson);
  }

  /// Generiert den Einladungslink.
  String getInviteLink() {
    return 'https://parentpeak.de/invite/$referralCode';
  }

  /// Generiert den Einladungstext für Share.
  String getInviteMessage() {
    final name = AuthService.instance.currentUser?.displayName ?? 'Ein Elternteil';
    return '$name nutzt ParentPeak für den Familienalltag und laedt dich ein! '
        'Kostenlos ausprobieren: ${getInviteLink()}';
  }

  /// Invitee: Meldet dem Backend, dass jemand über diesen Code beigetreten ist.
  Future<void> recordReferral(String code, String inviteeId, String inviteeName) async {
    final base = APIConfig.getBackendBaseUrl();
    if (base == null || base.isEmpty) return;
    try {
      await http.post(
        Uri.parse('$base/referrals/record'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'referralCode': code, 'inviteeId': inviteeId, 'inviteeName': inviteeName}),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('recordReferral error: $e');
    }
  }

  /// Inviter: Prüft ob jemand den eigenen Code benutzt hat und vergibt Coins.
  Future<void> claimPendingReferrals(BuildContext context) async {
    final base = APIConfig.getBackendBaseUrl();
    if (base == null || base.isEmpty) return;
    final myCode = referralCode;
    try {
      final resp = await http.get(
        Uri.parse('$base/referrals/pending/${Uri.encodeComponent(myCode)}'),
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final referrals = data['referrals'] as List<dynamic>? ?? [];
      if (referrals.isEmpty) return;

      for (final r in referrals) {
        final name = r['inviteeName'] as String? ?? 'Jemand';
        await earnCoinFromInvite(name);
      }

      // Mark as claimed
      await http.delete(
        Uri.parse('$base/referrals/claim/${Uri.encodeComponent(myCode)}'),
      ).timeout(const Duration(seconds: 10));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${referrals.length} Einladung${referrals.length > 1 ? 'en' : ''} erfolgreich – du hast ${referrals.length} Coin${referrals.length > 1 ? 's' : ''} erhalten! 🎉'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('claimPendingReferrals error: $e');
    }
  }
}

enum CoinTransactionType { earned, spent, bonus }

class CoinTransaction {
  final CoinTransactionType type;
  final int amount;
  final String reason;
  final DateTime date;

  const CoinTransaction({
    required this.type,
    required this.amount,
    required this.reason,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'amount': amount,
    'reason': reason,
    'date': date.toIso8601String(),
  };

  factory CoinTransaction.fromJson(Map<String, dynamic> json) => CoinTransaction(
    type: CoinTransactionType.values.firstWhere(
      (t) => t.name == json['type'], orElse: () => CoinTransactionType.earned),
    amount: json['amount'] as int? ?? 0,
    reason: json['reason'] as String? ?? '',
    date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
  );
}
