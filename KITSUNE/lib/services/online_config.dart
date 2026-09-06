class OnlineConfig {
  const OnlineConfig({required this.supabaseUrl, required this.anonKey});

  final String supabaseUrl;
  final String anonKey;

  bool get isConfigured => supabaseUrl.startsWith('https://') && anonKey.isNotEmpty;

  static const current = OnlineConfig(
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    anonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
  );
}
