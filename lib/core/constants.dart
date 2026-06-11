/// Injected at build time:
/// flutter build web --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'http://127.0.0.1:54321',
);
const supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: '',
);

const appName = "K's Journal";

class Tiers {
  static const observer = 'observer';
  static const analyst = 'analyst';
  static const innerCircle = 'inner_circle';

  static const prices = <String, double>{
    observer: 29.00,
    analyst: 79.00,
    innerCircle: 149.00,
  };
}
