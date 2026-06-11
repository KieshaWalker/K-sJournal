import 'package:supabase_flutter/supabase_flutter.dart';

import 'constants.dart';

Future<void> initSupabase() async {
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);
}

SupabaseClient get supabase => Supabase.instance.client;
