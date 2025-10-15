// Replace with your actual Supabase credentials or use environment config
const String supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://uwarslbzgvjnbsdxpcyq.supabase.co',
);

const String supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue:
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV3YXJzbGJ6Z3ZqbmJzZHhwY3lxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1ODE3NTUzMiwiZXhwIjoyMDczNzUxNTMyfQ.a1i-roTrswm7JGNEkgUGUu7X0xvIljcXNHni8MNSC3I',
);
