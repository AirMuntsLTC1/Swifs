import 'social_repository.dart';
import 'supabase_social_repository.dart';

SocialRepository? _instance;

/// The one data layer for the whole app. Screens call social.fetchFeed() etc.
SocialRepository get social => _instance ??= SupabaseSocialRepository();
