import 'package:intl/intl.dart';

class Formatters {
  static String relativeDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    if (diff.inDays    < 7)  return '${diff.inDays}d ago';
    return DateFormat('MMM d, y').format(dt);
  }

  static String fullDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return DateFormat('MMM d, y · h:mm a').format(dt);
  }

  static String views(int n) => n == 1 ? '1 view' : '$n views';

  static String ratings(int n) => n == 1 ? '1 rating' : '$n ratings';
}