import 'package:flutter/material.dart';

import '../models/constellation.dart';
import '../projection/projector.dart';

typedef OnConstellationTap = void Function(Constellation constellation);
typedef OnBackgroundTap = void Function();

class ConstellationOverlay extends StatelessWidget {
  const ConstellationOverlay({
    super.key,
    required this.constellations,
    required this.headingDegrees,
    required this.pitchDegrees,
    this.horizontalFovDegrees = 60.0,
    this.verticalFovDegrees = 45.0,
    required this.previousPositions,
    required this.onTapConstellation,
    this.focused,
    this.scale = 1.0,
    required this.onTapBackground,
  });

  final List<Constellation> constellations;
  final double headingDegrees;
  final double pitchDegrees;
  final double horizontalFovDegrees;
  final double verticalFovDegrees;
  final Map<String, Offset> previousPositions; // snapping state by iauName
  final OnConstellationTap onTapConstellation;
  final Constellation? focused;
  final double scale;
  final OnBackgroundTap onTapBackground;

  static const double snapThresholdPx = 12.0;

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final Projector projector = Projector(
      horizontalFovDegrees: horizontalFovDegrees,
      verticalFovDegrees: verticalFovDegrees,
    );

    final List<Widget> stackChildren = <Widget>[
      // Captura taps en espacios vacíos
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: onTapBackground,
        ),
      ),
    ];
    const double spriteSize = 128.0; // tamaño base un poco más grande
    const double halfSprite = spriteSize / 2.0;

    for (final Constellation c in constellations) {
      for (final ConstellationRegion r in c.regions) {
        final Offset? projected = projector.projectToScreen(
          screenSize: size,
          headingDegrees: headingDegrees,
          pitchDegrees: pitchDegrees,
          targetAzimuthDegrees: r.centerAzimuthDeg,
          targetAltitudeDegrees: r.centerAltitudeDeg,
        );
        if (projected == null) continue;

        final Offset snapped = _applySnapping(c.iauName, projected);
        stackChildren.add(Positioned(
          left: snapped.dx - halfSprite,
          top: snapped.dy - halfSprite,
          width: spriteSize,
          height: spriteSize,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTapConstellation(c),
            child: _ConstellationSprite(
              iauName: c.iauName,
              assetPath: c.assetPath,
            ),
          ),
        ));
      }
    }

    // Overlay centrado si hay enfoque
    if (focused != null) {
      stackChildren.add(Center(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onTapConstellation(focused!),
          child: SizedBox(
            width: 144 * scale,
            height: 144 * scale,
            child: _ConstellationSprite(
              iauName: focused!.iauName,
              assetPath: focused!.assetPath,
            ),
          ),
        ),
      ));
    }

    return Stack(children: stackChildren);
  }

  Offset _applySnapping(String key, Offset current) {
    final Offset? prev = previousPositions[key];
    if (prev == null) {
      previousPositions[key] = current;
      return current;
    }
    final double dx = (current.dx - prev.dx).abs();
    final double dy = (current.dy - prev.dy).abs();
    if (dx <= snapThresholdPx && dy <= snapThresholdPx) {
      return prev;
    }
    previousPositions[key] = current;
    return current;
  }
}

class _ConstellationSprite extends StatelessWidget {
  const _ConstellationSprite({required this.iauName, required this.assetPath});

  final String iauName;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            border: Border.all(color: Colors.white24),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            '$iauName\n$assetPath',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        );
      },
    );
  }
}


