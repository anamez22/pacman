import 'dart:math';

import 'package:flutter/material.dart';

import 'game_map.dart';

class Ghost {
  static const Map<String, Offset> vectors = {
    'right': Offset(1, 0),
    'left': Offset(-1, 0),
    'up': Offset(0, -1),
    'down': Offset(0, 1),
  };

  static const Map<String, String> opposite = {
    'right': 'left',
    'left': 'right',
    'up': 'down',
    'down': 'up',
  };

  static const double _eps = 1e-6;

  final Color color;

  /// Probabilidad (0..1) de perseguir a Pac-Man en cada intersección.
  /// El resto del tiempo elige un camino al azar.
  final double chase;
  final int homeX;
  final int homeY;

  double x;
  double y;
  String direction;
  bool scared = false;

  Ghost({
    required this.color,
    required this.chase,
    required this.homeX,
    required this.homeY,
  }) : x = homeX.toDouble(),
       y = homeY.toDouble(),
       direction = 'left';

  void reset() {
    x = homeX.toDouble();
    y = homeY.toDouble();
    direction = 'left';
    scared = false;
  }

  void reverse() {
    direction = opposite[direction]!;
  }

  bool get _atCenter =>
      (x - x.roundToDouble()).abs() < _eps &&
      (y - y.roundToDouble()).abs() < _eps;

  double _distanceToNextCenter(Offset v) {
    final coord = v.dx != 0 ? x : y;
    if (v.dx + v.dy > 0) {
      final target = (coord + _eps).floorToDouble() + 1;
      return target - coord;
    } else {
      final target = (coord - _eps).ceilToDouble() - 1;
      return coord - target;
    }
  }

  void update({
    required double speed,
    required int targetX,
    required int targetY,
    required Random rng,
  }) {
    double remaining = scared ? speed * 0.6 : speed;

    while (remaining > _eps) {
      if (_atCenter) {
        x = x.roundToDouble();
        y = y.roundToDouble();
        x = GameMap.wrapX(x, direction);
        _chooseDirection(x.toInt(), y.toInt(), targetX, targetY, rng);
      }

      final v = vectors[direction]!;
      final step = min(remaining, _distanceToNextCenter(v));
      x += v.dx * step;
      y += v.dy * step;
      remaining -= step;
    }
  }

  void _chooseDirection(int cx, int cy, int tx, int ty, Random rng) {
    final options = <String>[];
    for (final d in vectors.keys) {
      if (d == opposite[direction]) continue; // no da media vuelta
      final v = vectors[d]!;
      if (!GameMap.isWall(cx + v.dx.toInt(), cy + v.dy.toInt())) {
        options.add(d);
      }
    }

    if (options.isEmpty) {
      direction = opposite[direction]!; // callejón sin salida
      return;
    }
    if (options.length == 1) {
      direction = options.first;
      return;
    }

    double dist(String d) {
      final v = vectors[d]!;
      final nx = cx + v.dx - tx;
      final ny = cy + v.dy - ty;
      return nx * nx + ny * ny;
    }

    final bool pursue = scared
        ? rng.nextDouble() < 0.7
        : rng.nextDouble() < chase;
    if (pursue) {
      // Asustado: huye (el más lejano). Normal: persigue (el más cercano).
      options.sort(
        (a, b) =>
            scared ? dist(b).compareTo(dist(a)) : dist(a).compareTo(dist(b)),
      );
      direction = options.first;
    } else {
      direction = options[rng.nextInt(options.length)];
    }
  }
}
