import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';

import 'board/board_layout.dart';
import 'board/tile_component.dart';
import 'board/tile_palette.dart';
import 'game_state.dart';

/// The Flame game that renders the board and turns taps into tile selections.
///
/// Flutter owns menus, HUD and dialogs; this class only draws tiles and
/// effects. It also drives the session clock from the Flame game loop, so the
/// clock automatically stops when Flame pauses (e.g. app backgrounded).
class SymbolMatchGame extends FlameGame {
  SymbolMatchGame({required GameSession session, required this.visuals})
    // ignore: prefer_initializing_formals
    : _session = session;

  GameSession _session;

  /// Theme and motion settings; may be replaced at any time.
  GameVisuals visuals;
  late final _BoardComponent _board;
  final math.Random _fx = math.Random();

  GameSession get session => _session;

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    _board = _BoardComponent(this);
    add(_board);
    _session.addEventListener(_onEvent);
    _board.build();
  }

  /// Swaps in a new session (restart / next level) without recreating the
  /// game widget.
  void attachSession(GameSession session) {
    if (identical(session, _session)) return;
    _session.removeEventListener(_onEvent);
    _session = session;
    _session.addEventListener(_onEvent);
    if (isLoaded) _board.build();
  }

  /// Longest game-clock step per frame; a stalled frame (GC, OS hiccup)
  /// must never cost the player a chunk of their countdown.
  static const double maxFrameStep = 0.1;

  @override
  void update(double dt) {
    super.update(dt);
    _session.tick(math.min(dt, maxFrameStep));
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) _board.relayout();
  }

  @override
  void onRemove() {
    _session.removeEventListener(_onEvent);
    super.onRemove();
  }

  void _onEvent(GameEvent e) {
    if (!isLoaded) return;
    switch (e.type) {
      case GameEventType.match:
        for (final i in e.tiles) {
          _board.tileAt(i)?.pulse();
          if (!visuals.reducedMotion) _burst(i, 14);
        }
      case GameEventType.mismatch:
        for (final i in e.tiles) {
          _board.tileAt(i)?.shake();
        }
      case GameEventType.won:
        _board.celebrate();
        if (!visuals.reducedMotion) {
          for (var i = 0; i < _session.board.tiles.length; i += 3) {
            _burst(i, 8);
          }
        }
      default:
        break;
    }
  }

  void _burst(int index, int count) {
    final rect = _board.tileRect(index);
    if (rect == null) return;
    final colors = [
      const Color(0xFFFFE066),
      const Color(0xFFFFFFFF),
      const Color(0xFFFF8FAB),
      const Color(0xFF7DD3FC),
    ];
    final paint = Paint();
    final scale = rect.width / 60;
    add(
      ParticleSystemComponent(
        position: Vector2(rect.center.dx, rect.center.dy),
        particle: Particle.generate(
          count: count,
          lifespan: 0.7,
          generator: (i) {
            final angle = _fx.nextDouble() * math.pi * 2;
            final speed = (60 + _fx.nextDouble() * 120) * scale;
            final color = colors[i % colors.length];
            final radius = (2 + _fx.nextDouble() * 3) * scale;
            return AcceleratedParticle(
              speed: Vector2(math.cos(angle), math.sin(angle)) * speed,
              acceleration: Vector2(0, 220 * scale),
              child: ComputedParticle(
                renderer: (canvas, particle) {
                  paint.color = color.withValues(
                    alpha: (1 - particle.progress).clamp(0, 1),
                  );
                  canvas.drawCircle(Offset.zero, radius, paint);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BoardComponent extends PositionComponent with TapCallbacks {
  _BoardComponent(this.game);

  final SymbolMatchGame game;
  final List<TileComponent> _tiles = [];
  BoardLayout? _layout;
  Offset _origin = Offset.zero;
  int? _pressedIndex;

  TileComponent? tileAt(int i) =>
      i >= 0 && i < _tiles.length ? _tiles[i] : null;

  Rect? tileRect(int i) => _layout?.tileRect(i, _origin);

  void build() {
    removeAll(_tiles);
    _tiles.clear();
    final session = game.session;
    for (final t in session.board.tiles) {
      _tiles.add(
        TileComponent(
          index: t.index,
          symbol: t.symbol,
          sessionGetter: () => game.session,
          visualsGetter: () => game.visuals,
        ),
      );
    }
    addAll(_tiles);
    relayout();
  }

  void relayout() {
    size = game.size.clone();
    final c = game.session.config;
    final canvas = Size(size.x, size.y);
    final layout = BoardLayout.forCanvas(
      columns: c.columns,
      rows: c.rows,
      canvas: canvas,
    );
    _layout = layout;
    _origin = layout.originIn(canvas);
    for (final t in _tiles) {
      final r = layout.tileRect(t.index, _origin);
      t
        ..position = Vector2(r.left, r.top)
        ..size = Vector2.all(r.width);
    }
  }

  void celebrate() {
    final cols = game.session.config.columns;
    for (final t in _tiles) {
      final row = t.index ~/ cols;
      final col = t.index % cols;
      t.celebrate((row + col) * 0.06);
    }
  }

  int? _indexAt(Vector2 local) =>
      _layout?.indexAt(Offset(local.x, local.y), _origin);

  @override
  void onTapDown(TapDownEvent event) {
    final i = _indexAt(event.localPosition);
    _pressedIndex = i;
    if (i != null && game.session.acceptsInput) tileAt(i)?.pressDown();
  }

  @override
  void onTapUp(TapUpEvent event) {
    _release();
    final i = _indexAt(event.localPosition);
    if (i != null) game.session.tapTile(i);
  }

  @override
  void onTapCancel(TapCancelEvent event) => _release();

  void _release() {
    final i = _pressedIndex;
    if (i != null) tileAt(i)?.pressUp();
    _pressedIndex = null;
  }
}
