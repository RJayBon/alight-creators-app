/// Session-scoped rate limiter. Mirrors `rate_limit.php`.
///
/// FIXES vs. the previous version:
///  1. `_buckets` grew forever — every distinct key allocated a bucket that
///     was never reclaimed. Keys are cheap today, but this is a genuine
///     unbounded map on a long-lived singleton. Expired buckets are now
///     reclaimed inside `allow()` (see `_pruneExpired`), so the map settles at
///     roughly "keys touched within the last few windows".
///  2. `allow()` counted the *rejected* attempts too, so a locked-out user
///     kept pushing the window forward. Rejected attempts now still count
///     (that is the point) but the window restarts from the first attempt in
///     the current window instead of drifting.
///  3. Added `retryAfter()` and `remaining()`. The old API could only answer
///     "yes/no", so every screen that wanted to say "try again in N minutes"
///     had to guess — and the login/forgot screens previously printed a fixed
///     cooldown that was frequently wrong (the lock could already be gone, or
///     could last four times longer than stated).
class RateLimitService {
  RateLimitService._();
  static final RateLimitService instance = RateLimitService._();

  final Map<String, _Bucket> _buckets = {};

  /// Returns true when the caller is within the limit.
  bool allow(String key, {required int max, required int windowSec}) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    _pruneExpired(now, windowSec);

    final b = _buckets.putIfAbsent(key, () => _Bucket(now));
    if (now - b.start > windowSec) {
      b.start = now;
      b.count = 0;
    }
    b.count++;
    b.lastTouched = now;
    return b.count <= max;
  }

  /// Attempts remaining in the current window (0 once locked out).
  int remaining(String key, {required int max, required int windowSec}) {
    final b = _buckets[key];
    if (b == null) return max;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (now - b.start > windowSec) return max;
    final left = max - b.count;
    return left < 0 ? 0 : left;
  }

  /// Seconds until the window for [key] resets; 0 when not limited.
  int retryAfter(String key, {required int max, required int windowSec}) {
    final b = _buckets[key];
    if (b == null) return 0;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final left = windowSec - (now - b.start);
    if (left <= 0) return 0;
    return b.count >= max ? left : 0;
  }

  void reset(String key) => _buckets.remove(key);

  void resetAll() => _buckets.clear();

  void _pruneExpired(int now, int windowSec) {
    if (_buckets.length < 32) return;
    _buckets.removeWhere(
      (_, b) => now - b.lastTouched > windowSec * 4,
    );
  }
}

class _Bucket {
  int start;
  int count = 0;
  int lastTouched;
  _Bucket(this.start) : lastTouched = start;
}