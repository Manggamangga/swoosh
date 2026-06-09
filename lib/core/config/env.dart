class Env {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://segpgjvfwlwfqkverhso.supabase.co',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNlZ3BnanZmd2x3ZnFrdmVyaHNvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEwMzQyOTYsImV4cCI6MjA5NjYxMDI5Nn0.H7PNbHS4u0KNP4JDnrHCZ4sJvKqSy-6-nwQ8Akhr_1I',
  );

  static const skipAuth = bool.fromEnvironment(
    'SKIP_AUTH',
    defaultValue: true,
  );

  static const devEmail = String.fromEnvironment(
    'DEV_EMAIL',
    defaultValue: 'dev@swoosh.app',
  );

  static const devPassword = String.fromEnvironment(
    'DEV_PASSWORD',
    defaultValue: 'swoosh-dev-local',
  );
}
