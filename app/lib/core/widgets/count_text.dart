/// Formats counts the way the feed shows them: 67, 1,298, 20.6K, 1.2M.
String compactCount(num value) {
  final n = value.toInt();
  if (n < 10000) return _withCommas(n);
  if (n < 1000000) return '${_oneDecimal(n / 1000)}K';
  return '${_oneDecimal(n / 1000000)}M';
}

String _oneDecimal(double v) {
  final s = v.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

String _withCommas(int n) {
  final s = n.toString();
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
    out.write(s[i]);
  }
  return out.toString();
}
