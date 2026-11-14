import 'social_repository.dart';
import 'supabase_social_repository.dart';

SocialRepository? _instance;
SocialRepository get social => _instance ??= SupabaseSocialRepository();


