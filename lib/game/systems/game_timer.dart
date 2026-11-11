/// A countdown advanced manually with [tick]. Using explicit ticks (driven by
/// the Flame game loop) instead of `Timer`/`Future.delayed` means:
/// * nothing fires after the owner is disposed,
/// * pausing is just "stop ticking",
/// * tests can advance time deterministically.
class PhaseTimer {
  double _remaining = 0;
  bool _active = false;

  bool get isActive => _active;
  double get remaining => _active ? _remaining : 0;

  void start(double seconds) {
    _remaining = seconds;
    _active = true;
  }

  void cancel() {
    _active = false;
    _remaining = 0;
  }

  /// Advances the timer. Returns true exactly once, on the tick it expires.
  bool tick(double dt) {
    if (!_active) return false;
    _remaining -= dt;
    if (_remaining <= 0) {
      _active = false;
      _remaining = 0;
      return true;
    }
    return false;
  }
}
