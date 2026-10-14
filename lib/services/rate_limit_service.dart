/// Session-scoped rate limiter. Mirrors `rate_limit.php`.
class RateLimitService {
  RateLimitService._();
  static final RateLimitService instance = RateLimitService._();

  final Map<String, _Bucket> _buckets = {};

  bool allow(String key, {required int max, required int windowSec}) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final b = _buckets.putIfAbsent(key, () => _Bucket(now));
    if (now - b.start > windowSec) {
      b.start = now;
      b.count = 0;
    }
    b.count++;
    return b.count <= max;
  }

  void reset(String key) => _buckets.remove(key);
}

class _Bucket {
  int start;
  int count = 0;
  _Bucket(this.start);
}