import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'constants.dart';

class ScoreDisplay extends StatelessWidget {
  final int score;
  final int lives;
  final VoidCallback onReset;

  const ScoreDisplay({
    super.key,
    required this.score,
    required this.lives,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 18,
        runSpacing: 12,
        children: [
          _ScoreCard(score: score),
          _LivesCard(lives: lives),
          NeonButton(
            label: 'Reiniciar',
            icon: Icons.refresh_rounded,
            onPressed: onReset,
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Puntaje: el número cuenta hacia arriba y la tarjeta hace un "pop" al subir.
// -----------------------------------------------------------------------------

class _ScoreCard extends StatefulWidget {
  final int score;
  const _ScoreCard({required this.score});

  @override
  State<_ScoreCard> createState() => _ScoreCardState();
}

class _ScoreCardState extends State<_ScoreCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );

  @override
  void didUpdateWidget(covariant _ScoreCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.score > oldWidget.score) _pop.forward(from: 0);
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pop,
      builder: (context, child) =>
          Transform.scale(scale: 1 + 0.10 * sin(pi * _pop.value), child: child),
      child: GlassCard(
        borderColor: kNeonYellow.withAlpha(150),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Puntaje',
              style: GoogleFonts.orbitron(
                fontSize: 11,
                letterSpacing: 2,
                color: kNeonCyan,
              ),
            ),
            const SizedBox(height: 6),
            TweenAnimationBuilder<int>(
              tween: IntTween(end: widget.score),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              builder: (context, value, _) => Text(
                value.toString().padLeft(5, '0'),
                style: GoogleFonts.pressStart2p(
                  fontSize: 20,
                  color: kNeonYellow,
                  shadows: [
                    Shadow(color: kNeonYellow.withAlpha(200), blurRadius: 10),
                    Shadow(color: Colors.orange.withAlpha(140), blurRadius: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Vidas con mini Pac-Man (las perdidas quedan atenuadas)
// -----------------------------------------------------------------------------

class _LivesCard extends StatelessWidget {
  final int lives;
  const _LivesCard({required this.lives});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderColor: kNeonCyan.withAlpha(90),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Vidas',
            style: GoogleFonts.orbitron(
              fontSize: 11,
              letterSpacing: 2,
              color: kNeonCyan,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(kInitialLives, (i) {
              final alive = i < lives;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: alive ? 1.0 : 0.18,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 300),
                    scale: alive ? 1.0 : 0.8,
                    child: const MiniPacman(size: 24),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class MiniPacman extends StatelessWidget {
  final double size;
  const MiniPacman({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CustomPaint(painter: _MiniPacmanPainter()),
    );
  }
}

class _MiniPacmanPainter extends CustomPainter {
  const _MiniPacmanPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;

    canvas.drawCircle(
      c,
      r * 0.9,
      Paint()
        ..color = kPacmanColor.withAlpha(110)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.85),
      0.6,
      2 * pi - 1.2,
      true,
      Paint()..color = kPacmanColor,
    );
    canvas.drawCircle(
      c + Offset(r * 0.05, -r * 0.45),
      r * 0.11,
      Paint()..color = kEyeColor,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniPacmanPainter old) => false;
}

// -----------------------------------------------------------------------------
// Widgets neón compartidos (título, tarjeta glass, botón, teclas, overlay)
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// Título "PAC-MAN" con brillo
// -----------------------------------------------------------------------------

class NeonTitle extends StatelessWidget {
  const NeonTitle({super.key});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 520;
    return Text(
      'PAC-MAN',
      style: GoogleFonts.pressStart2p(
        fontSize: compact ? 20 : 28,
        letterSpacing: 4,
        color: kNeonYellow,
        shadows: [
          Shadow(color: kNeonYellow.withAlpha(235), blurRadius: 6),
          Shadow(color: Colors.orange.withAlpha(200), blurRadius: 18),
          Shadow(color: Colors.deepOrange.withAlpha(140), blurRadius: 36),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Tarjeta glassmorphism
// -----------------------------------------------------------------------------

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final double radius;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
    this.borderColor,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: shape,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: shape,
            border: Border.all(
              color: borderColor ?? Colors.white.withAlpha(56),
              width: 1,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white.withAlpha(38), Colors.white.withAlpha(10)],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Botón neón
// -----------------------------------------------------------------------------

class NeonButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final Color color;

  const NeonButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = kNeonCyan,
  });

  @override
  State<NeonButton> createState() => _NeonButtonState();
}

class _NeonButtonState extends State<NeonButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    final active = _hover || _down;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _down ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 90),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                c.withAlpha(active ? 70 : 34),
                const Color(0xFF070B22),
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c, width: 1.6),
              boxShadow: [
                BoxShadow(
                  color: c.withAlpha(active ? 170 : 90),
                  blurRadius: active ? 26 : 14,
                  spreadRadius: active ? 1 : 0,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, color: c, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(
                  widget.label,
                  style: GoogleFonts.orbitron(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: Colors.white,
                    shadows: [Shadow(color: c.withAlpha(200), blurRadius: 8)],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Teclas (keycaps) para las instrucciones
// -----------------------------------------------------------------------------

class KeyCap extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final bool wide;

  const KeyCap({super.key, this.label, this.icon, this.wide = false});

  @override
  Widget build(BuildContext context) {
    final color = Colors.white.withAlpha(225);
    return Container(
      constraints: BoxConstraints(minWidth: wide ? 92 : 30, minHeight: 30),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF131A3A),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: kNeonCyan.withAlpha(120)),
        boxShadow: [
          BoxShadow(color: kNeonCyan.withAlpha(80), offset: const Offset(0, 3)),
        ],
      ),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: icon != null
            ? Icon(icon, size: 16, color: color)
            : Text(
                label ?? '',
                style: GoogleFonts.orbitron(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
      ),
    );
  }
}

class ControlsHint extends StatelessWidget {
  const ControlsHint({super.key});

  @override
  Widget build(BuildContext context) {
    final textStyle = GoogleFonts.orbitron(fontSize: 11, color: Colors.white60);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 10,
      children: [
        const KeyCap(icon: Icons.keyboard_arrow_up_rounded),
        const KeyCap(icon: Icons.keyboard_arrow_left_rounded),
        const KeyCap(icon: Icons.keyboard_arrow_down_rounded),
        const KeyCap(icon: Icons.keyboard_arrow_right_rounded),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('o', style: textStyle),
        ),
        const KeyCap(label: 'W'),
        const KeyCap(label: 'A'),
        const KeyCap(label: 'S'),
        const KeyCap(label: 'D'),
        const SizedBox(width: 12),
        const KeyCap(label: 'Espacio', wide: true),
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Text('pausa', style: textStyle),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Overlay "¡Prepárate!" (escala + parpadeo)
// -----------------------------------------------------------------------------

class ReadyOverlay extends StatefulWidget {
  const ReadyOverlay({super.key});

  @override
  State<ReadyOverlay> createState() => _ReadyOverlayState();
}

class _ReadyOverlayState extends State<ReadyOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withAlpha(90),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.3, end: 1.0),
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutBack,
              builder: (context, entry, child) =>
                  Transform.scale(scale: entry, child: child),
              child: AnimatedBuilder(
                animation: _blink,
                builder: (context, _) {
                  final e = Curves.easeInOut.transform(_blink.value);
                  return Opacity(
                    opacity: 0.65 + 0.35 * e,
                    child: Transform.scale(
                      scale: 0.94 + 0.12 * e,
                      child: Text(
                        '¡PREPÁRATE!',
                        style: GoogleFonts.pressStart2p(
                          fontSize: 28,
                          color: kNeonYellow,
                          shadows: [
                            Shadow(
                              color: kNeonYellow.withAlpha(230),
                              blurRadius: 8,
                            ),
                            Shadow(
                              color: Colors.orange.withAlpha(180),
                              blurRadius: 24,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
