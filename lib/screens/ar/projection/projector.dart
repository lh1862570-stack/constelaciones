import 'package:flutter/widgets.dart';

class Projector {
  const Projector({this.horizontalFovDegrees = 60.0, this.verticalFovDegrees = 45.0});

  final double horizontalFovDegrees;
  final double verticalFovDegrees;

  // Returns screen offset or null if outside FOV
  Offset? projectToScreen({
    required Size screenSize,
    required double headingDegrees,
    required double pitchDegrees,
    required double targetAzimuthDegrees,
    required double targetAltitudeDegrees,
  }) {
    final double deltaAz = _wrapDegrees(targetAzimuthDegrees - headingDegrees);
    final double deltaAlt = targetAltitudeDegrees - pitchDegrees;

    final double halfH = horizontalFovDegrees / 2.0;
    final double halfV = verticalFovDegrees / 2.0;

    if (deltaAz.abs() > halfH || deltaAlt.abs() > halfV) {
      return null; // off-screen
    }

    final double nx = (deltaAz / horizontalFovDegrees) + 0.5; // 0..1
    final double ny = 0.5 - (deltaAlt / verticalFovDegrees); // 0..1 (top-left origin)

    final double x = nx * screenSize.width;
    final double y = ny * screenSize.height;

    return Offset(x, y);
  }

  double _wrapDegrees(double d) {
    double v = d % 360.0;
    if (v > 180.0) v -= 360.0;
    if (v < -180.0) v += 360.0;
    return v;
  }
}


