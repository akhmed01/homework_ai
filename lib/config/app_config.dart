class AppConfig {
  const AppConfig._();

  static const String groqApiKey = String.fromEnvironment('GROQ_API_KEY');
  static const String privacyPolicyUrl = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
  );
  static const String supportEmail = String.fromEnvironment('SUPPORT_EMAIL');

  static bool get hasGroqApiKey => groqApiKey.trim().isNotEmpty;
  static bool get hasPrivacyPolicyUrl => privacyPolicyUrl.trim().isNotEmpty;
  static bool get hasSupportEmail => supportEmail.trim().isNotEmpty;
}
