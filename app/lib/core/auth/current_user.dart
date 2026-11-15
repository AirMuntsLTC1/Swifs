import 'package:supabase_flutter/supabase_flutter.dart';

/// The id of the signed-in account, or null when nobody is signed in.
String? get currentUserId => Supabase.instance.client.auth.currentUser?.id;

/// True when [id] is the signed-in account. Used to hide Follow buttons on your own account.
bool isMyAccount(Object? id) => id != null && id.toString() == currentUserId;
