import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'constants.dart';
import 'score_display.dart';

void showWinDialog(BuildContext context, int score, VoidCallback onPlayAgain) {
  _showNeonDialog(
    context: context,
    emoji: '🏆',
    title: '¡FELICIDADES!',
    subtitle: 'Limpiaste todo el laberinto',
    score: score,
    accent: kNeonYellow,
    buttonLabel: 'Jugar de nuevo',
    onPressed: onPlayAgain,
  );
}

void showGameOverDialog(
  BuildContext context,
  int score,
  VoidCallback onPlayAgain,
) {
  _showNeonDialog(
    context: context,
    emoji: '💀',
    title: 'GAME OVER',
    subtitle: 'Los fantasmas te atraparon',
    score: score,
    accent: const Color(0xFFFF1744),
    buttonLabel: 'Jugar de nuevo',
    onPressed: onPlayAgain,
  );
}

void _showNeonDialog({
  required BuildContext context,
  required String emoji,
  required String title,
  required String subtitle,
  required int score,
  required Color accent,
  required String buttonLabel,
  required VoidCallback onPressed,
}) {
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: title,
    barrierColor: Colors.black.withAlpha(175),
    transitionDuration: const Duration(milliseconds: 500),
    pageBuilder: (ctx, anim1, anim2) => Center(
      child: Material(
        color: Colors.transparent,
        child: _NeonDialogBody(
          emoji: emoji,
          title: title,
          subtitle: subtitle,
          score: score,
          accent: accent,
          buttonLabel: buttonLabel,
          onPressed: () {
            Navigator.of(ctx).pop();
            onPressed();
          },
        ),
      ),
    ),
    transitionBuilder: (ctx, anim, anim2, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.6, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _NeonDialogBody extends StatefulWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final int score;
  final Color accent;
  final String buttonLabel;
  final VoidCallback onPressed;

  const _NeonDialogBody({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.score,
    required this.accent,
    required this.buttonLabel,
    required this.onPressed,
  });

  @override
  State<_NeonDialogBody> createState() => _NeonDialogBodyState();
}

class _NeonDialogBodyState extends State<_NeonDialogBody>
    with SingleTickerProviderStateMixin {
  // Pulso lento que hace "respirar" el brillo del borde y del título.
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    return AnimatedBuilder(
      animation: _glow,
      builder: (context, _) {
        final g = Curves.easeInOut.transform(_glow.value);
        return Container(
          margin: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.fromLTRB(28, 26, 28, 26),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: accent.withAlpha(215), width: 2),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF111A4A), Color(0xFF070B22)],
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withAlpha(70 + (g * 70).round()),
                blurRadius: 24 + g * 24,
                spreadRadius: 1 + g * 3,
              ),
              BoxShadow(
                color: kNeonBlue.withAlpha(60),
                blurRadius: 60,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: 1 + 0.08 * g,
                child: Text(widget.emoji, style: const TextStyle(fontSize: 54)),
              ),
              const SizedBox(height: 14),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.pressStart2p(
                  fontSize: 18,
                  height: 1.4,
                  color: accent,
                  shadows: [
                    Shadow(
                      color: accent.withAlpha(165 + (g * 90).round()),
                      blurRadius: 10 + g * 14,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.orbitron(
                  fontSize: 13,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Puntaje final',
                style: GoogleFonts.orbitron(
                  fontSize: 11,
                  letterSpacing: 2,
                  color: kNeonCyan,
                ),
              ),
              const SizedBox(height: 8),
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: widget.score),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeOut,
                builder: (context, value, _) => Text(
                  value.toString(),
                  style: GoogleFonts.pressStart2p(
                    fontSize: 30,
                    color: Colors.white,
                    shadows: [
                      Shadow(color: accent.withAlpha(200), blurRadius: 14),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 26),
              NeonButton(
                label: widget.buttonLabel,
                icon: Icons.replay_rounded,
                color: accent,
                onPressed: widget.onPressed,
              ),
            ],
          ),
        );
      },
    );
  }
}
