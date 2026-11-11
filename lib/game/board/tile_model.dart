import 'game_symbol.dart';

enum TileState { hidden, revealed, matched }

/// One tile on the board. Mutable state is owned by the BoardController.
class TileModel {
  TileModel({
    required this.index,
    required this.symbol,
    this.state = TileState.hidden,
  });

  final int index;
  final GameSymbol symbol;
  TileState state;

  bool get isHidden => state == TileState.hidden;
  bool get isRevealed => state == TileState.revealed;
  bool get isMatched => state == TileState.matched;
  bool get isFaceUp => state != TileState.hidden;

  @override
  String toString() => 'Tile($index, ${symbol.name}, ${state.name})';
}
