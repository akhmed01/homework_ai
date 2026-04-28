import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  const AppConfig._();

  static String get groqApiKey {
    try {
      return _firstNonEmpty(
        const String.fromEnvironment('GROQ_API_KEY'),
        dotenv.env['GROQ_API_KEY'],
      );
    } catch (e) {
      return _firstNonEmpty(const String.fromEnvironment('GROQ_API_KEY'), '');
    }
  }

  static String get privacyPolicyUrl {
    try {
      return _firstNonEmpty(
        const String.fromEnvironment('PRIVACY_POLICY_URL'),
        dotenv.env['PRIVACY_POLICY_URL'],
      );
    } catch (e) {
      return _firstNonEmpty(
        const String.fromEnvironment('PRIVACY_POLICY_URL'),
        '',
      );
    }
  }

  static String get supportEmail {
    try {
      return _firstNonEmpty(
        const String.fromEnvironment('SUPPORT_EMAIL'),
        dotenv.env['SUPPORT_EMAIL'],
      );
    } catch (e) {
      return _firstNonEmpty(const String.fromEnvironment('SUPPORT_EMAIL'), '');
    }
  }

  static bool get hasSupportEmail => supportEmail.isNotEmpty;
  static bool get hasPrivacyPolicyUrl => privacyPolicyUrl.isNotEmpty;

  static String _firstNonEmpty(String primary, String? fallback) {
    final primaryTrimmed = primary.trim();
    if (primaryTrimmed.isNotEmpty) {
      return primaryTrimmed;
    }
    return fallback?.trim() ?? '';
  }
}
