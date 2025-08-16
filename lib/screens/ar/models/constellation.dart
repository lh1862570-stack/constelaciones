class ConstellationRegion {
  const ConstellationRegion({required this.centerAzimuthDeg, required this.centerAltitudeDeg});

  final double centerAzimuthDeg; // 0..360
  final double centerAltitudeDeg; // approx range -90..+90
}

class Constellation {
  const Constellation({
    required this.iauName,
    required this.assetPath,
    required this.regions,
  });

  final String iauName;
  final String assetPath;
  final List<ConstellationRegion> regions;
}


