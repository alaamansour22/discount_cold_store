class SupabaseConfig {
  const SupabaseConfig._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://wmdwxskdikwwjbhwvjkq.supabase.co', // ضع رابط مشروعك هنا
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndtZHd4c2tkaWt3d2piaHd2amtxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQ1MTE1ODAsImV4cCI6MjExMDA4NzU4MH0.KSv_UgnfUsz8w2omd3okHRk9ZJY8V-Jntk6Mpev4Rr0', // ضع مفتاح anon public هنا
  );
}