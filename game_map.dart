import 'constants.dart';

class GameMap {
  // 0 = vacío, 1 = pared, 2 = punto, 3 = punto grande.
  // La fila 7 es un túnel: sus dos extremos están abiertos y se conectan.
  static const List<List<int>> originalLayout = [
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
    [1, 2, 2, 2, 2, 2, 2, 1, 2, 2, 2, 2, 2, 2, 1],
    [1, 2, 1, 1, 2, 1, 2, 1, 2, 1, 2, 1, 1, 2, 1],
    [1, 3, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 3, 1],
    [1, 2, 1, 1, 2, 1, 1, 1, 1, 1, 2, 1, 1, 2, 1],
    [1, 2, 2, 2, 2, 2, 2, 1, 2, 2, 2, 2, 2, 2, 1],
    [1, 2, 1, 1, 2, 1, 2, 1, 2, 1, 2, 1, 1, 2, 1],
    [0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0],
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
  ];

  static late List<List<int>> layout;

  static void resetMap() {
    layout = originalLayout.map((row) => List<int>.from(row)).toList();
  }

  /// Fuera del mapa por los lados, una celda es pared solo si la celda del
  /// borde de esa fila lo es. Así el túnel (fila 7) queda abierto y el resto no.
  static bool isWall(int x, int y) {
    if (y < 0 || y >= kMapHeight) return true;
    if (x < 0) return layout[y][0] == 1;
    if (x >= kMapWidth) return layout[y][kMapWidth - 1] == 1;
    return layout[y][x] == 1;
  }

  /// Teletransporta al otro lado cuando algo sale completamente del mapa
  /// por el túnel. Se aplica solo cuando está centrado en una celda.
  static double wrapX(double x, String direction) {
    if (direction == 'right' && x >= kMapWidth) return -1.0;
    if (direction == 'left' && x <= -1) return kMapWidth.toDouble();
    return x;
  }
}
