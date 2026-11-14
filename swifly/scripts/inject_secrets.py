import os, pathlib
url = os.environ.get('SUPABASE_URL', '')
key = os.environ.get('SUPABASE_ANON_KEY', '')
if url and key:
    p = pathlib.Path('app/lib/core/config/supabase_config.dart')
    p.write_text(f"const String kSupabaseUrl = '{url}';\nconst String kSupabaseAnonKey = '{key}';\n")
    print("✅ Supabase config injected successfully.")
else:
    print("⚠️ Secrets missing. Using placeholder config.")


