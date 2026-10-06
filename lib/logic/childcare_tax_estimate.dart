/// Illustration for one child's qualifying costs, not an entitlement check.
class ChildcareTaxEstimate {
  static const source = 'https://www.gesetze-im-internet.de/estg/__10.html';
  static const share = 0.8;
  static const maximum = 4800.0;

  static double deductible(double annualQualifyingCosts) {
    if (!annualQualifyingCosts.isFinite || annualQualifyingCosts < 0) {
      throw const FormatException('Invalid annual childcare costs');
    }
    return (annualQualifyingCosts * share).clamp(0, maximum);
  }
}
