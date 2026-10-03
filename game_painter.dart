import 'dart:math';

import 'package:flutter/material.dart';

import 'constants.dart';
import 'game_map.dart';
import 'ghost.dart';

/// Capa ESTÁTICA: fondo del tablero + paredes de contorno neón.
/// Se dibuja dentro de un RepaintBoundary, así el glow (caro) no se recalcula
/// en cada frame del juego.
class MazePainter extends CustomPainter {
  const MazePainter();

  static Path? _cachedPath;
  static double _cachedCell = -1;

  /// Une todas las celdas de pared en un solo contorno. Las esquinas
  /// convexas (las que no tienen pared vecina) se redondean.
  static Path _wallPath(double cell) {
    if (_cachedPath != null && _cachedCell == cell) return _cachedPath!;

    bool wall(int x, int y) {
      if (y < 0 || y >= kMapHeight || x < 0 || x >= kMapWidth) return true;
      return GameMap.layout[y][x] == 1;
    }

    final r = Radius.circular(cell * 0.38);
    Path? result;
    for (int y = 0; y < kMapHeight; y++) {
      for (int x = 0; x < kMapWidth; x++) {
        if (GameMap.layout[y][x] != 1) continue;
        final up = wall(x, y - 1);
        final down = wall(x, y + 1);
        final left = wall(x - 1, y);
        final right = wall(x + 1, y);
        final rrect = RRect.fromRectAndCorners(
          Rect.fromLTWH(x * cell, y * cell, cell, cell).inflate(0.5),
          topLeft: (!up && !left) ? r : Radius.zero,
          topRight: (!up && !right) ? r : Radius.zero,
          bottomLeft: (!down && !left) ? r : Radius.zero,
          bottomRight: (!down && !right) ? r : Radius.zero,
        );
        final p = Path()..addRRect(rrect);
        result = result == null
            ? p
            : Path.combine(PathOperation.union, result, p);
      }
    }
    _cachedCell = cell;
    return _cachedPath = result ?? Path();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cell = min(size.width / kMapWidth, size.height / kMapHeight);
    final mapW = cell * kMapWidth;
    final mapH = cell * kMapHeight;
    final offsetX = (size.width - mapW) / 2;
    final offsetY = (size.height - mapH) / 2;

    // Fondo del tablero: un poco más claro al centro para que "flote".
    final boardRect = Offset.zero & size;
    canvas.drawRect(
      boardRect,
      Paint()
        ..shader = const RadialGradient(
          radius: 0.85,
          colors: [Color(0xFF0D1638), kBoardBg],
        ).createShader(boardRect),
    );

    canvas.save();
    canvas.translate(offsetX, offsetY);
    canvas.clipRect(Rect.fromLTWH(0, 0, mapW, mapH));

    // Cuadrícula sutil por celdas.
    final gridPaint = Paint()
      ..color = kNeonBlue.withAlpha(14)
      ..strokeWidth = 1;
    for (int x = 1; x < kMapWidth; x++) {
      canvas.drawLine(Offset(x * cell, 0), Offset(x * cell, mapH), gridPaint);
    }
    for (int y = 1; y < kMapHeight; y++) {
      canvas.drawLine(Offset(0, y * cell), Offset(mapW, y * cell), gridPaint);
    }

    final path = _wallPath(cell);

    // Resplandor exterior (ancho y suave + fino e intenso).
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.24
        ..color = kNeonBlue.withAlpha(150)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.2),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.1
        ..color = kNeonBlue.withAlpha(210)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.06),
    );

    // Relleno oscuro de las paredes (con un leve degradado vertical).
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0E1E6B), kWallFill],
        ).createShader(Rect.fromLTWH(0, 0, mapW, mapH)),
    );

    // Borde: azul eléctrico + hilo cian por encima.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = cell * 0.09
        ..color = kNeonBlue,
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = cell * 0.035
        ..color = kNeonCyan.withAlpha(235),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MazePainter oldDelegate) => false;
}

/// Capa DINÁMICA: puntos, Pac-Man y fantasmas (sin fondo, va sobre MazePainter).
class GamePainter extends CustomPainter {
  final double pacmanX;
  final double pacmanY;
  final String direction;

  /// Semiapertura de la boca en radianes (la calcula GameScreen).
  final double mouthAngle;

  final List<Ghost> ghosts;

  /// 0 o 1: alterna para animar los "pies" de los fantasmas.
  final int ghostFrame;

  /// true durante el parpadeo final del modo asustado.
  final bool ghostsFlash;

  /// 0..1: pulso de los puntos grandes.
  final double pulse;

  GamePainter({
    required this.pacmanX,
    required this.pacmanY,
    required this.direction,
    required this.mouthAngle,
    this.ghosts = const [],
    this.ghostFrame = 0,
    this.ghostsFlash = false,
    this.pulse = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cell = min(size.width / kMapWidth, size.height / kMapHeight);
    final offsetX = (size.width - cell * kMapWidth) / 2;
    final offsetY = (size.height - cell * kMapHeight) / 2;

    canvas.save();
    canvas.translate(offsetX, offsetY);
    // Recorta al tablero: así quien cruza el túnel desaparece por el borde.
    canvas.clipRect(Rect.fromLTWH(0, 0, cell * kMapWidth, cell * kMapHeight));
    _drawDots(canvas, cell);
    for (final g in ghosts) {
      _drawGhost(canvas, cell, g);
    }
    _drawPacman(canvas, cell);
    canvas.restore();
  }

  void _drawDots(Canvas canvas, double cell) {
    final dotPaint = Paint()..color = kDotColor;
    final dotHalo = Paint()..color = kDotColor.withAlpha(40);
    final powerPaint = Paint()..color = kPowerDotColor;
    final powerGlow = Paint()
      ..color = kPowerDotColor.withAlpha(100 + (pulse * 100).round())
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.12);
    final powerScale = 1 + 0.25 * pulse;

    for (int y = 0; y < kMapHeight; y++) {
      for (int x = 0; x < kMapWidth; x++) {
        final center = Offset((x + 0.5) * cell, (y + 0.5) * cell);

        switch (GameMap.layout[y][x]) {
          case 2:
            canvas.drawCircle(center, cell * 0.2, dotHalo);
            canvas.drawCircle(center, cell * 0.1, dotPaint);
            break;
          case 3:
            canvas.drawCircle(center, cell * 0.3 * powerScale, powerGlow);
            canvas.drawCircle(center, cell * 0.2 * powerScale, powerPaint);
            break;
        }
      }
    }
  }

  void _drawPacman(Canvas canvas, double cell) {
    final center = Offset((pacmanX + 0.5) * cell, (pacmanY + 0.5) * cell);
    final radius = cell * 0.42;

    canvas.save();
    canvas.translate(center.dx, center.dy);

    switch (direction) {
      case 'left':
        canvas.scale(-1, 1);
        break;
      case 'up':
        canvas.rotate(-pi / 2);
        break;
      case 'down':
        canvas.rotate(pi / 2);
        break;
      default:
        break;
    }

    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: radius),
      mouthAngle,
      2 * pi - mouthAngle * 2,
      true,
      Paint()..color = kPacmanColor,
    );

    canvas.drawCircle(
      Offset(radius * 0.15, -radius * 0.5),
      radius * 0.13,
      Paint()..color = kEyeColor,
    );

    canvas.restore();
  }

  void _drawGhost(Canvas canvas, double cell, Ghost g) {
    final center = Offset((g.x + 0.5) * cell, (g.y + 0.5) * cell);
    final r = cell * 0.42;

    Color bodyColor = g.color;
    if (g.scared) {
      bodyColor = ghostsFlash ? Colors.white : kFrightenedColor;
    }

    canvas.save();
    canvas.translate(center.dx, center.dy);

    // Cuerpo: cabeza redonda + falda con picos.
    final path = Path()
      ..moveTo(-r, r)
      ..lineTo(-r, 0)
      ..arcTo(Rect.fromCircle(center: Offset.zero, radius: r), pi, pi, false)
      ..lineTo(r, r);
    const teeth = 6;
    final step = 2 * r / teeth;
    for (int i = 1; i <= teeth; i++) {
      final px = r - i * step;
      final py = ((i + ghostFrame) % 2 == 1) ? r * 0.72 : r;
      path.lineTo(px, py);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = bodyColor);

    if (g.scared) {
      final facePaint = Paint()
        ..color = ghostsFlash ? Colors.red : const Color(0xFFFFE0B2);
      canvas.drawCircle(Offset(-r * 0.3, -r * 0.2), r * 0.12, facePaint);
      canvas.drawCircle(Offset(r * 0.3, -r * 0.2), r * 0.12, facePaint);
      final mouth = Path()..moveTo(-r * 0.55, r * 0.35);
      for (int i = 1; i <= 4; i++) {
        mouth.lineTo(-r * 0.55 + i * r * 0.275, i.isOdd ? r * 0.2 : r * 0.35);
      }
      canvas.drawPath(
        mouth,
        Paint()
          ..color = facePaint.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    } else {
      // Ojos blancos cuyas pupilas miran hacia donde avanza el fantasma.
      final v = Ghost.vectors[g.direction]!;
      final eyeWhite = Paint()..color = Colors.white;
      final pupil = Paint()..color = const Color(0xFF1A237E);
      for (final sx in [-1.0, 1.0]) {
        final eye = Offset(sx * r * 0.35, -r * 0.2);
        canvas.drawCircle(eye, r * 0.3, eyeWhite);
        canvas.drawCircle(eye + Offset(v.dx, v.dy) * r * 0.12, r * 0.15, pupil);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => true;
}

// -----------------------------------------------------------------------------
// Fondo neón y scanlines (usados por GameScreen)
// -----------------------------------------------------------------------------

int _alpha(double v) => min(255, max(0, (v * 255).round()));

class _Star {
  final double x; // 0..1
  final double y; // 0..1
  final double radius;
  final double phase; // 0..1
  final int cycles; // parpadeos por ciclo de 60 s (entero => bucle sin saltos)
  final int drift; // vueltas de desplazamiento por ciclo (entero)
  final double brightness;
  final Color tint;

  const _Star({
    required this.x,
    required this.y,
    required this.radius,
    required this.phase,
    required this.cycles,
    required this.drift,
    required this.brightness,
    required this.tint,
  });
}

/// Fondo con profundidad: viñeta radial, rejilla en perspectiva y estrellas.
/// Va detrás de todo (úsalo dentro de un `Positioned.fill`).
class NeonBackground extends StatefulWidget {
  const NeonBackground({super.key});

  @override
  State<NeonBackground> createState() => _NeonBackgroundState();
}

class _NeonBackgroundState extends State<NeonBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  )..repeat();

  late final List<_Star> _stars = _makeStars();

  static List<_Star> _makeStars() {
    final rng = Random(7);
    const tints = [Colors.white, Color(0xFF9FD8FF), Color(0xFFFFB3F0)];
    return List.generate(80, (_) {
      return _Star(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        radius: 0.6 + rng.nextDouble() * 1.4,
        phase: rng.nextDouble(),
        cycles: 8 + rng.nextInt(20),
        drift: 1 + rng.nextInt(3),
        brightness: 0.4 + rng.nextDouble() * 0.6,
        tint: tints[rng.nextInt(tints.length)],
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _BackgroundPainter(_controller, _stars),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  final Animation<double> animation;
  final List<_Star> stars;

  _BackgroundPainter(this.animation, this.stars) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value; // 0..1 (ciclo de 60 s)
    final rect = Offset.zero & size;

    // 1) Degradado radial: azul marino al centro -> casi negro en los bordes.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.1),
          radius: 1.0,
          colors: [Color(0xFF0E1638), kBgCenter, kBgEdge],
          stops: [0.0, 0.4, 1.0],
        ).createShader(rect),
    );

    // 2) Manchas de color muy suaves para dar profundidad.
    _blob(
      canvas,
      Offset(size.width * 0.12, size.height * 0.18),
      size.shortestSide * 0.7,
      kNeonPink.withAlpha(26),
    );
    _blob(
      canvas,
      Offset(size.width * 0.9, size.height * 0.85),
      size.shortestSide * 0.8,
      kNeonCyan.withAlpha(20),
    );

    // 3) Estrellas que parpadean y suben despacio.
    for (final s in stars) {
      final twinkle = 0.5 + 0.5 * sin(2 * pi * (s.cycles * t + s.phase));
      final a = (0.25 + 0.75 * twinkle) * s.brightness;
      final y = (s.y - t * s.drift) % 1.0;
      final pos = Offset(s.x * size.width, y * size.height);
      if (s.radius > 1.2) {
        canvas.drawCircle(
          pos,
          s.radius * 3,
          Paint()..color = s.tint.withAlpha(_alpha(a * 0.15)),
        );
      }
      canvas.drawCircle(
        pos,
        s.radius,
        Paint()..color = s.tint.withAlpha(_alpha(a)),
      );
    }

    // 4) Rejilla en perspectiva (suelo) con baja opacidad.
    _drawGrid(canvas, size, t);

    // 5) Viñeta final sobre todo.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          colors: [Colors.transparent, Colors.black.withAlpha(175)],
          stops: const [0.55, 1.0],
        ).createShader(rect),
    );
  }

  void _blob(Canvas canvas, Offset center, double radius, Color color) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(colors: [color, color.withAlpha(0)])
            .createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  void _drawGrid(Canvas canvas, Size size, double t) {
    final horizon = size.height * 0.42;
    final floorH = size.height - horizon;
    final cx = size.width / 2;

    // Líneas verticales que convergen en el punto de fuga (se desvanecen
    // hacia el horizonte).
    final vPaint = Paint()
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [kNeonBlue.withAlpha(0), kNeonBlue.withAlpha(46)],
      ).createShader(Rect.fromLTWH(0, horizon, size.width, floorH));
    final spacing = size.width / 12;
    for (int k = -16; k <= 16; k++) {
      canvas.drawLine(
        Offset(cx, horizon),
        Offset(cx + k * spacing, size.height),
        vPaint,
      );
    }

    // Líneas horizontales que se acercan despacio (efecto "avance").
    const n = 14;
    final phase = (t * 12) % 1.0;
    for (int i = 0; i < n; i++) {
      final u = (i + phase) / n;
      final y = horizon + floorH * u * u;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..strokeWidth = 1
          ..color = kNeonBlue.withAlpha(_alpha(0.03 + u * 0.13)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BackgroundPainter old) => false;
}

/// Líneas de escaneo tipo CRT, muy suaves, encima de todo.
class ScanlinesOverlay extends StatelessWidget {
  const ScanlinesOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(painter: _ScanlinePainter(), size: Size.infinite),
      ),
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  const _ScanlinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withAlpha(30);
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScanlinePainter old) => false;
}
