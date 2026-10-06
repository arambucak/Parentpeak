class FinanceNumber {
  // Keep entered amounts within the exact integer range on native and web.
  static const maxAmount = 9007199254740991.0;

  static bool isValid(Object? value) =>
      value is num && value.isFinite && value >= 0 && value <= maxAmount;

  static double parse(String input) {
    final text = input.trim();
    if (text.isEmpty) return 0;
    if (!RegExp(r'^\d+(?:[.,]\d{1,2})?$').hasMatch(text)) {
      throw const FormatException('Invalid financial amount');
    }
    final value = double.tryParse(text.replaceAll(',', '.'));
    if (!isValid(value)) throw const FormatException('Amount outside supported range');
    return value!;
  }
}
