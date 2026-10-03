import 'package:flutter/material.dart';

const int kMapWidth = 15;
const int kMapHeight = 9;

const Color kWallColor = Color(0xFF1565C0);
const Color kWallBorderColor = Color(0xFF42A5F5);
const Color kDotColor = Colors.yellow;
const Color kPowerDotColor = Colors.orange;
const Color kPacmanColor = Colors.yellow;
const Color kEyeColor = Colors.black;

const double kGameSpeedMs = 200.0;
const int kNormalDotPoints = 10;
const int kPowerDotPoints = 50;

// --- Fantasmas y vidas ---
const int kGhostPoints = 200;
const int kInitialLives = 3;
const Color kFrightenedColor = Color(0xFF2121DE);
const Color kBlinkyColor = Color(0xFFFF0000);
const Color kPinkyColor = Color(0xFFFFB8FF);
const Color kInkyColor = Color(0xFF00E5FF);

// --- Tema neón arcade ---
const Color kBgCenter = Color(0xFF0B1026); // centro del fondo
const Color kBgEdge = Color(0xFF020309); // bordes (viñeta)
const Color kBoardBg = Color(0xFF060A1C); // fondo del tablero
const Color kNeonBlue = Color(0xFF2979FF); // azul eléctrico
const Color kNeonCyan = Color(0xFF18FFFF); // borde cian
const Color kNeonYellow = Color(0xFFFFE600);
const Color kNeonPink = Color(0xFFFF4FD8);
const Color kWallFill = Color(0xFF0A1650); // relleno oscuro de las paredes
