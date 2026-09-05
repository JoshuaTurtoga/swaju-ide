import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class HoleClipper extends CustomClipper<Path> {
  final double progress;
  final Offset origin;

  HoleClipper({required this.progress, required this.origin});

  @override
  Path getClip(Size size) {
    final Path path = Path();
    path.addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final corners = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ];
    final maxRadius = corners
        .map((c) => (c - origin).distance)
        .reduce((a, b) => a > b ? a : b);

    final holePath = Path()
      ..addOval(Rect.fromCircle(center: origin, radius: maxRadius * progress));

    return Path.combine(PathOperation.difference, path, holePath);
  }

  @override
  bool shouldReclip(HoleClipper oldClipper) {
    return oldClipper.progress != progress || oldClipper.origin != origin;
  }
}
