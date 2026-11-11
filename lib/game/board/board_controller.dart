import 'deck_generator.dart';
import 'game_symbol.dart';
import 'tile_model.dart';

/// Outcome of a tile selection attempt.
enum SelectionResult {
  /// Index outside the board.
  ignoredInvalid,

  /// A mismatch is still being shown; input is locked.
  ignoredBusy,

  /// Tile is already matched.
  ignoredMatched,

  /// Tile is already face up (the current first pick).
  ignoredRevealed,

  /// First tile of a pair attempt was revealed.
  firstRevealed,

  /// Second tile matched the first.
  matched,

  /// Second tile matched and the board is now complete.
  completed,

  /// Second tile did not match; call [BoardController.resolveMismatch].
  mismatched,
}

extension SelectionResultX on SelectionResult {
  bool get accepted => index >= SelectionResult.firstRevealed.index;
  bool get isMoveEnd =>
      this == SelectionResult.matched ||
      this == SelectionResult.completed ||
      this == SelectionResult.mismatched;
}

/// Pure matching rules. No rendering, timers or Flutter dependencies, which
/// makes every rule unit-testable.
///
/// A *move* is counted each time a second tile is revealed (one pair attempt).
class BoardController {
  BoardController(List<GameSymbol> deck)
    : tiles = List<TileModel>.unmodifiable([
        for (var i = 0; i < deck.length; i++)
          TileModel(index: i, symbol: deck[i]),
      ]) {
    DeckGenerator.validate(deck);
  }

  final List<TileModel> tiles;

  int? _firstIndex;
  int? _pendingA;
  int? _pendingB;

  int moves = 0;
  int matchedPairs = 0;
  int mismatches = 0;
  int combo = 0;
  int bestCombo = 0;

  int get totalPairs => tiles.length ~/ 2;
  int? get firstIndex => _firstIndex;
  bool get isResolving => _pendingA != null;
  bool get isComplete => matchedPairs == totalPairs;
  List<int> get pendingMismatch =>
      _pendingA == null ? const [] : [_pendingA!, _pendingB!];

  SelectionResult select(int index) {
    if (index < 0 || index >= tiles.length) {
      return SelectionResult.ignoredInvalid;
    }
    if (isResolving) return SelectionResult.ignoredBusy;
    final tile = tiles[index];
    if (tile.isMatched) return SelectionResult.ignoredMatched;
    if (tile.isRevealed) return SelectionResult.ignoredRevealed;
    if (isComplete) return SelectionResult.ignoredMatched;

    tile.state = TileState.revealed;
    final first = _firstIndex;
    if (first == null) {
      _firstIndex = index;
      return SelectionResult.firstRevealed;
    }

    _firstIndex = null;
    moves++;
    final firstTile = tiles[first];
    if (firstTile.symbol == tile.symbol) {
      firstTile.state = TileState.matched;
      tile.state = TileState.matched;
      matchedPairs++;
      combo++;
      if (combo > bestCombo) bestCombo = combo;
      return isComplete ? SelectionResult.completed : SelectionResult.matched;
    }
    _pendingA = first;
    _pendingB = index;
    mismatches++;
    combo = 0;
    return SelectionResult.mismatched;
  }

  /// Flips the two mismatched tiles back face down and unlocks input.
  void resolveMismatch() {
    final a = _pendingA;
    final b = _pendingB;
    if (a == null || b == null) return;
    tiles[a].state = TileState.hidden;
    tiles[b].state = TileState.hidden;
    _pendingA = null;
    _pendingB = null;
  }

  /// Returns two hidden tiles that form a pair. If a first tile is already
  /// revealed, its partner is returned together with it.
  List<int>? findHintPair() {
    final first = _firstIndex;
    if (first != null) {
      final symbol = tiles[first].symbol;
      for (final t in tiles) {
        if (t.index != first && t.symbol == symbol && !t.isMatched) {
          return [first, t.index];
        }
      }
    }
    final seen = <GameSymbol, int>{};
    for (final t in tiles) {
      if (t.isMatched || isResolving && pendingMismatch.contains(t.index)) {
        continue;
      }
      final other = seen[t.symbol];
      if (other != null) return [other, t.index];
      seen[t.symbol] = t.index;
    }
    return null;
  }

  /// Restores matched tiles and counters from a saved snapshot.
  void restore({
    required Set<int> matchedIndices,
    required int moves,
    required int mismatches,
    required int combo,
    required int bestCombo,
  }) {
    for (final t in tiles) {
      t.state = matchedIndices.contains(t.index)
          ? TileState.matched
          : TileState.hidden;
    }
    // Only whole pairs count; drop any inconsistent singletons.
    final bySymbol = <GameSymbol, List<TileModel>>{};
    for (final t in tiles.where((t) => t.isMatched)) {
      bySymbol.putIfAbsent(t.symbol, () => []).add(t);
    }
    var pairs = 0;
    for (final group in bySymbol.values) {
      if (group.length == 2) {
        pairs++;
      } else {
        for (final t in group) {
          t.state = TileState.hidden;
        }
      }
    }
    matchedPairs = pairs;
    this.moves = moves < 0 ? 0 : moves;
    this.mismatches = mismatches < 0 ? 0 : mismatches;
    this.combo = combo < 0 ? 0 : combo;
    this.bestCombo = bestCombo < 0 ? 0 : bestCombo;
    _firstIndex = null;
    _pendingA = null;
    _pendingB = null;
  }
}
