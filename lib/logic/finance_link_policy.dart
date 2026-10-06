import 'package:parentpeak/models/country_finance_config.dart';

/// AI output may link only to exact curated URLs, never arbitrary redirects.
class FinanceLinkPolicy {
  static bool isHttps(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        (!uri.hasPort || uri.port == 443);
  }

  static bool isCurated(String url, CountryFinanceConfig country) =>
      isHttps(url) && country.benefits.any((benefit) => benefit.url == url);
}
