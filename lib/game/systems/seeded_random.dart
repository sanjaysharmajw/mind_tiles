import 'dart:math';

/// A small, fully deterministic PRNG (mulberry32).
///
/// `dart:math`'s [Random] does not guarantee an identical sequence across
/// platforms and SDK versions, which would break the Daily Challenge promise
/// that every player sees the same board on the same day. This generator is
/// pure 32-bit integer arithmetic and therefore stable everywhere.
class SeededRandom implements Random {
  SeededRandom(int seed) : _state = seed & 0xFFFFFFFF;

  int _state;

  int _next32() {
    _state = (_state + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _state;
    t = _imul(t ^ (t >> 15), t | 1);
    t ^= (t + _imul(t ^ (t >> 7), t | 61)) & 0xFFFFFFFF;
    return (t ^ (t >> 14)) & 0xFFFFFFFF;
  }

  static int _imul(int a, int b) => (a * b) & 0xFFFFFFFF;

  @override
  int nextInt(int max) {
    if (max <= 0 || max > 0x100000000) {
      throw RangeError.range(max, 1, 0x100000000, 'max');
    }
    // Rejection sampling avoids modulo bias.
    final limit = 0x100000000 - (0x100000000 % max);
    while (true) {
      final v = _next32();
      if (v < limit) return v % max;
    }
  }

  @override
  double nextDouble() => _next32() / 0x100000000;

  @override
  bool nextBool() => (_next32() & 1) == 1;

  /// Seed derived from a calendar date, e.g. 2026-11-11 -> 20261111.
  static int seedForDate(DateTime date) =>
      date.year * 10000 + date.month * 100 + date.day;
}
