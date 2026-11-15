import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/explore/hashtag_screen.dart';
import '../../features/profile/user_profile_screen.dart';

const Color _kLink = Color(0xFFFF6B35);

/// Text with @mentions and #hashtags as tappable links.
/// A mention opens that person's profile. A hashtag opens the hashtag screen.
class LinkifiedText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const LinkifiedText(this.text, {super.key, this.style});

  /// @handle (letters, digits, underscore, inner dots) or #tag.
  static final RegExp _pattern = RegExp(
    r'(@[\p{L}\p{N}_](?:[\p{L}\p{N}_.]*[\p{L}\p{N}_])?)|(#[\p{L}\p{N}_]+)',
    unicode: true,
  );

  /// The spans for [text], with links. Use inside a TextSpan or Text.rich.
  static List<InlineSpan> spans(BuildContext context, String text, {TextStyle? style}) {
    final out = <InlineSpan>[];
    var last = 0;
    for (final m in _pattern.allMatches(text)) {
      if (m.start > last) {
        out.add(TextSpan(text: text.substring(last, m.start), style: style));
      }
      final token = m.group(0)!;
      final isMention = token.startsWith('@');
      final name = token.substring(1);
      out.add(TextSpan(
        text: token,
        style: (style ?? const TextStyle()).copyWith(color: _kLink, fontWeight: FontWeight.w600),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            if (isMention) {
              openMention(context, name);
            } else {
              openHashtag(context, name);
            }
          },
      ));
      last = m.end;
    }
    if (last < text.length) {
      out.add(TextSpan(text: text.substring(last), style: style));
    }
    return out;
  }

  /// Looks up the username and opens that profile. Unknown names do nothing.
  static Future<void> openMention(BuildContext context, String username) async {
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('username', username)
          .maybeSingle();
      final id = row?['id']?.toString();
      if (id == null || !context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => UserProfileScreen(userId: id)),
      );
    } catch (_) {
      // Offline or a lookup error: the text stays as it was, nothing breaks.
    }
  }

  static void openHashtag(BuildContext context, String tag) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HashtagScreen(tag: tag.toLowerCase())),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: spans(context, text, style: style)),
      style: style,
    );
  }
}
