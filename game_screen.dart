import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'constants.dart';
import 'game_map.dart';
import 'game_painter.dart';
import 'ghost.dart';
import 'score_display.dart';
import 'win_dialog.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  static const Map<String, Offset> _vectors = Ghost.vectors;
  static const Map<String, String> _opposite = Ghost.opposite;

  static const Duration _frameTime = Duration(milliseconds: 16); // ~60 FPS
  static const double _speed = 0.09; // celdas por frame de Pac-Man
  static const double _ghostSpeed = 0.075; // un poco más lentos que Pac-Man
  static const double _eps = 1e-6;

  static const int _readyFrames = 90; // pausa al empezar / tras perder vida
  static const int _scaredFrames = 375; // ~6 segundos asustados

  final Random _rng = Random();

  double pacmanX = 1.0;
  double pacmanY = 1.0;

  int score = 0;
  int lives = kInitialLives;
  String direction = 'right';
  String? nextDirection;
  double mouthPhase = 0;

  late List<Ghost> ghosts;
  int _frameCount = 0;
  int _freezeFrames = _readyFrames;
  int _scaredLeft = 0;

  bool gameRunning = true;
  bool gameWon = false;
  bool gameOver = false;

  late Timer gameTimer;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    GameMap.resetMap();
    ghosts = _createGhosts();
    gameTimer = Timer.periodic(_frameTime, (_) => _update());
  }

  @override
  void dispose() {
    gameTimer.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  List<Ghost> _createGhosts() => [
    Ghost(color: kBlinkyColor, chase: 0.85, homeX: 13, homeY: 1),
    Ghost(color: kPinkyColor, chase: 0.60, homeX: 7, homeY: 3),
    Ghost(color: kInkyColor, chase: 0.35, homeX: 13, homeY: 5),
  ];

  void resetGame() {
    setState(() {
      score = 0;
      lives = kInitialLives;
      gameRunning = true;
      gameWon = false;
      gameOver = false;
      GameMap.resetMap();
      _resetPositions();
    });
    _focusNode.requestFocus();
  }

  void _resetPositions() {
    pacmanX = 1.0;
    pacmanY = 1.0;
    direction = 'right';
    nextDirection = null;
    mouthPhase = 0;
    _scaredLeft = 0;
    _freezeFrames = _readyFrames;
    for (final g in ghosts) {
      g.reset();
    }
  }

  // ---------------------------------------------------------------------------
  // Lógica de Pac-Man
  // ---------------------------------------------------------------------------

  bool get _atCenter =>
      (pacmanX - pacmanX.roundToDouble()).abs() < _eps &&
      (pacmanY - pacmanY.roundToDouble()).abs() < _eps;

  bool _canMove(int cx, int cy, String dir) {
    final v = _vectors[dir]!;
    return !GameMap.isWall(cx + v.dx.toInt(), cy + v.dy.toInt());
  }

  double _distanceToNextCenter(Offset v) {
    final coord = v.dx != 0 ? pacmanX : pacmanY;
    if (v.dx + v.dy > 0) {
      final target = (coord + _eps).floorToDouble() + 1;
      return target - coord;
    } else {
      final target = (coord - _eps).ceilToDouble() - 1;
      return coord - target;
    }
  }

  void _eat(int cx, int cy) {
    if (cx < 0 || cx >= kMapWidth) return; // celdas fuera del mapa (túnel)
    final cell = GameMap.layout[cy][cx];
    if (cell == 2) {
      GameMap.layout[cy][cx] = 0;
      score += kNormalDotPoints;
    } else if (cell == 3) {
      GameMap.layout[cy][cx] = 0;
      score += kPowerDotPoints;
      _scareGhosts();
    }
  }

  void _scareGhosts() {
    _scaredLeft = _scaredFrames;
    for (final g in ghosts) {
      if (!g.scared) g.reverse();
      g.scared = true;
    }
  }

  bool _allDotsEaten() {
    for (final row in GameMap.layout) {
      for (final cell in row) {
        if (cell == 2 || cell == 3) return false;
      }
    }
    return true;
  }

  void _update() {
    if (!gameRunning || !mounted) return;
    _frameCount++;

    // Cuenta regresiva de "listo" al empezar o después de perder una vida.
    if (_freezeFrames > 0) {
      _freezeFrames--;
      setState(() {});
      return;
    }

    bool won = false;
    double moved = 0;
    double remaining = _speed;

    while (remaining > _eps) {
      if (_atCenter) {
        pacmanX = pacmanX.roundToDouble();
        pacmanY = pacmanY.roundToDouble();
        pacmanX = GameMap.wrapX(pacmanX, direction); // túnel
        final cx = pacmanX.toInt();
        final cy = pacmanY.toInt();

        _eat(cx, cy);
        if (_allDotsEaten()) {
          won = true;
          break;
        }

        final next = nextDirection;
        if (next != null && _canMove(cx, cy, next)) {
          direction = next;
          nextDirection = null;
        }

        if (!_canMove(cx, cy, direction)) break;
      }

      final v = _vectors[direction]!;
      final step = min(remaining, _distanceToNextCenter(v));
      pacmanX += v.dx * step;
      pacmanY += v.dy * step;
      remaining -= step;
      moved += step;
    }

    if (!won) _updateGhosts();

    setState(() {
      mouthPhase += moved;
      if (won) {
        gameRunning = false;
        gameWon = true;
      }
    });

    if (won) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showWinDialog(context, score, resetGame);
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Fantasmas y colisiones
  // ---------------------------------------------------------------------------

  void _updateGhosts() {
    final px = pacmanX.round();
    final py = pacmanY.round();

    for (final g in ghosts) {
      g.update(speed: _ghostSpeed, targetX: px, targetY: py, rng: _rng);
    }

    if (_scaredLeft > 0) {
      _scaredLeft--;
      if (_scaredLeft == 0) {
        for (final g in ghosts) {
          g.scared = false;
        }
      }
    }

    for (final g in ghosts) {
      final dx = g.x - pacmanX;
      final dy = g.y - pacmanY;
      if (dx * dx + dy * dy < 0.5 * 0.5) {
        if (g.scared) {
          score += kGhostPoints;
          g.reset(); // vuelve a su punto de inicio
        } else {
          _loseLife();
          return;
        }
      }
    }
  }

  void _loseLife() {
    lives--;
    if (lives <= 0) {
      lives = 0;
      gameRunning = false;
      gameOver = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showGameOverDialog();
      });
    } else {
      _resetPositions();
    }
  }

  void _showGameOverDialog() {
    showGameOverDialog(context, score, resetGame);
  }

  // ---------------------------------------------------------------------------
  // Entrada del usuario
  // ---------------------------------------------------------------------------

  void changeDirection(String newDirection) {
    if (!gameRunning) return;
    if (newDirection == _opposite[direction]) {
      direction = newDirection;
      nextDirection = null;
    } else {
      nextDirection = newDirection;
    }
  }

  void _togglePause() {
    if (gameWon || gameOver) return;
    setState(() => gameRunning = !gameRunning);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    String? dir;
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyD) {
      dir = 'right';
    } else if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.keyA) {
      dir = 'left';
    } else if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.keyW) {
      dir = 'up';
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.keyS) {
      dir = 'down';
    }

    if (dir != null) {
      changeDirection(dir);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.space && event is KeyDownEvent) {
      _togglePause();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final mouthAngle = 0.05 + 0.40 * cos(mouthPhase * pi).abs();
    final flash =
        _scaredLeft > 0 && _scaredLeft < 90 && (_frameCount ~/ 10).isEven;
    final pulse = 0.5 + 0.5 * sin(_frameCount * 0.12);
    final showReady = gameRunning && _freezeFrames > 0;

    final String status;
    final Color statusColor;
    if (gameWon) {
      status = '🏆 ¡Ganaste!';
      statusColor = Colors.amber;
    } else if (gameOver) {
      status = '💀 Game Over';
      statusColor = Colors.redAccent;
    } else if (!gameRunning) {
      status = '⏸️ Pausado (presiona espacio para continuar)';
      statusColor = Colors.orangeAccent;
    } else if (_freezeFrames > 0) {
      status = 'Listo para empezar';
      statusColor = kNeonYellow;
    } else if (_scaredLeft > 0) {
      status = '👻 ¡Cómete a los fantasmas!';
      statusColor = Colors.lightBlueAccent;
    } else {
      status = '🎮 Jugando...';
      statusColor = Colors.greenAccent;
    }

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        backgroundColor: kBgEdge,
        body: Stack(
          children: [
            const Positioned.fill(child: NeonBackground()),
            Positioned.fill(
              child: SafeArea(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragEnd: (d) {
                    final vx = d.primaryVelocity ?? 0;
                    if (vx > 0) changeDirection('right');
                    if (vx < 0) changeDirection('left');
                  },
                  onVerticalDragEnd: (d) {
                    final vy = d.primaryVelocity ?? 0;
                    if (vy > 0) changeDirection('down');
                    if (vy < 0) changeDirection('up');
                  },
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      const NeonTitle(),
                      ScoreDisplay(
                        score: score,
                        lives: lives,
                        onReset: resetGame,
                      ),
                      Expanded(
                        child: Center(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              // Tablero 15:9 lo más grande posible (máx. 760 px).
                              final maxW = min(
                                constraints.maxWidth - 32,
                                760.0,
                              );
                              final maxH = constraints.maxHeight - 16;
                              double w = maxW;
                              double h = w * kMapHeight / kMapWidth;
                              if (h > maxH) {
                                h = maxH;
                                w = h * kMapWidth / kMapHeight;
                              }
                              if (w <= 0 || h <= 0) return const SizedBox();
                              return _buildBoard(
                                w,
                                h,
                                mouthAngle,
                                flash,
                                pulse,
                                showReady,
                              );
                            },
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const ControlsHint(),
                            const SizedBox(height: 12),
                            Text(
                              status,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.orbitron(
                                color: statusColor,
                                fontSize: 12,
                                letterSpacing: 1,
                                shadows: [
                                  Shadow(
                                    color: statusColor.withAlpha(140),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Positioned.fill(child: ScanlinesOverlay()),
          ],
        ),
      ),
    );
  }

  Widget _buildBoard(
    double w,
    double h,
    double mouthAngle,
    bool flash,
    double pulse,
    bool showReady,
  ) {
    return Container(
      width: w,
      height: h,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: kBoardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kNeonCyan.withAlpha(210), width: 2),
        boxShadow: [
          BoxShadow(
            color: kNeonBlue.withAlpha(150),
            blurRadius: 28,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: kNeonCyan.withAlpha(50),
            blurRadius: 64,
            spreadRadius: 6,
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Capa estática (paredes con glow): se cachea, no se repinta.
          const RepaintBoundary(child: CustomPaint(painter: MazePainter())),
          // Capa dinámica: puntos, Pac-Man y fantasmas.
          CustomPaint(
            painter: GamePainter(
              pacmanX: pacmanX,
              pacmanY: pacmanY,
              direction: direction,
              mouthAngle: mouthAngle,
              ghosts: ghosts,
              ghostFrame: (_frameCount ~/ 8) % 2,
              ghostsFlash: flash,
              pulse: pulse,
            ),
          ),
          if (showReady) const Positioned.fill(child: ReadyOverlay()),
        ],
      ),
    );
  }
}
