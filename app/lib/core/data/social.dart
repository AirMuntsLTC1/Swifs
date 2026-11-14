import 'mock_social_repository.dart';
import 'social_repository.dart';
// After connecting Supabase, also add:
// import 'supabase_social_repository.dart';

SocialRepository? _instance;

/// The one data layer for the whole app. Screens call social.fetchFeed() etc.
SocialRepository get social => _instance ??= createSocialRepository();

/// THE SWITCH. Sample data now. After Supabase is set up, return SupabaseSocialRepository().
SocialRepository createSocialRepository() {
  // return SupabaseSocialRepository();
  return MockSocialRepository();
}
