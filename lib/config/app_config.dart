class AppConfig {
  const AppConfig._();

  static String get groqApiKey {
    return _firstNonEmpty(const String.fromEnvironment('GROQ_API_KEY'), null);
  }

  static String get aiProxyUrl {
    return _firstNonEmpty(const String.fromEnvironment('AI_PROXY_URL'), null);
  }

  static String get aiProxyClientToken {
    return _firstNonEmpty(
      const String.fromEnvironment('AI_PROXY_CLIENT_TOKEN'),
      null,
    );
  }

  static String get privacyPolicyUrl {
    return _firstNonEmpty(const String.fromEnvironment('PRIVACY_POLICY_URL'), null);
  }

  static String get supportEmail {
    return _firstNonEmpty(const String.fromEnvironment('SUPPORT_EMAIL'), null);
  }

  static bool get hasSupportEmail => supportEmail.isNotEmpty;
  static bool get hasPrivacyPolicyUrl => privacyPolicyUrl.isNotEmpty;
  static bool get hasAiProxyUrl => aiProxyUrl.isNotEmpty;
  static bool get hasAiProxyClientToken => aiProxyClientToken.isNotEmpty;

  static String _firstNonEmpty(String primary, String? fallback) {
    final primaryTrimmed = primary.trim();
    if (primaryTrimmed.isNotEmpty) {
      return primaryTrimmed;
    }
    return fallback?.trim() ?? '';
  }
}
