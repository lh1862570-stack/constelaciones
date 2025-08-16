import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/constellation.dart';

class IauRepository {
  static const String dataAssetPath = 'assets/data/iau_constellations.json';

  Future<List<Constellation>> loadConstellations() async {
    final String jsonStr = await rootBundle.loadString(dataAssetPath);
    final Map<String, dynamic> raw = json.decode(jsonStr) as Map<String, dynamic>;
    final List<Constellation> list = <Constellation>[];

    for (final MapEntry<String, dynamic> entry in raw.entries) {
      final String iauName = entry.key;
      final List<dynamic> rectangles = entry.value as List<dynamic>;
      final List<ConstellationRegion> regions = <ConstellationRegion>[];

      for (final dynamic rectDyn in rectangles) {
        // Each rectangle is [[az,alt], [az,alt], [az,alt], [az,alt]]
        final List<dynamic> corners = rectDyn as List<dynamic>;
        final List<double> azList = <double>[];
        final List<double> altList = <double>[];
        for (final dynamic pairDyn in corners) {
          final List<dynamic> pair = pairDyn as List<dynamic>;
          azList.add((pair[0] as num).toDouble());
          altList.add((pair[1] as num).toDouble());
        }
        final double centerAz = _averageAzimuthDegrees(azList);
        final double centerAlt = _averageDouble(altList);
        regions.add(ConstellationRegion(centerAzimuthDeg: centerAz, centerAltitudeDeg: centerAlt));
      }

      final String assetPath = _mapIauToAssetPath(iauName);
      list.add(Constellation(iauName: iauName, assetPath: assetPath, regions: regions));
    }

    return list;
  }

  double _averageDouble(List<double> values) {
    if (values.isEmpty) return 0;
    final double sum = values.reduce((double a, double b) => a + b);
    return sum / values.length;
  }

  // Average around 0..360 handling wrap-around (e.g., 350, 10 => 0)
  double _averageAzimuthDegrees(List<double> degrees) {
    if (degrees.isEmpty) return 0;
    // Detect wrap: if max-min > 180, shift small values by +360 before averaging
    final double minVal = degrees.reduce((double a, double b) => a < b ? a : b);
    final double maxVal = degrees.reduce((double a, double b) => a > b ? a : b);
    final bool wraps = (maxVal - minVal) > 180.0;
    final List<double> adjusted = degrees
        .map((double d) => wraps && (d - minVal) < 0 ? d + 360.0 : (wraps && d < 90.0 ? d + 360.0 : d))
        .toList();
    final double avg = _averageDouble(adjusted);
    double normalized = avg % 360.0;
    if (normalized < 0) normalized += 360.0;
    return normalized;
  }

  String _mapIauToAssetPath(String iauName) {
    final String normalized = iauName.trim().toLowerCase();
    // Explicit mapping per spec, handling synonyms/diacritics
    switch (normalized) {
      case 'ursa major':
        return 'assets/constellations/ursamajor.png';
      case 'ursa minor':
        return 'assets/constellations/ursaminor.png';
      case 'draco':
        return 'assets/constellations/draco.png';
      case 'cepheus':
        return 'assets/constellations/cepheus.png';
      case 'cassiopeia':
      case 'casiopea':
        return 'assets/constellations/casiopea.png';
      case 'leo':
        return 'assets/constellations/leo.png';
      case 'virgo':
        return 'assets/constellations/virgo.png';
      case 'boötes':
      case 'bootes':
        return 'assets/constellations/bootes.png';
      case 'scorpius':
      case 'scorpio':
        return 'assets/constellations/escorpio.png';
      case 'sagittarius':
        return 'assets/constellations/sagitario.png';
      case 'lyra':
        return 'assets/constellations/lyra.png';
      case 'cygnus':
        return 'assets/constellations/cygnus.png';
      case 'aquila':
        return 'assets/constellations/aguila.png';
      case 'pegasus':
        return 'assets/constellations/pegaso.png';
      case 'andromeda':
        return 'assets/constellations/andromeda.png';
      case 'cetus':
        return 'assets/constellations/cetus.png';
      case 'orion':
        return 'assets/constellations/orion.png';
      case 'taurus':
        return 'assets/constellations/tauro.png';
      case 'canis major':
        return 'assets/constellations/canmayor.png';
      case 'gemini':
        return 'assets/constellations/geminis.png';
      case 'eridanus':
        return 'assets/constellations/eridanus.png';
      default:
        // Fallback: try to sanitize and guess
        final String guess = normalized
            .replaceAll('ö', 'o')
            .replaceAll('ó', 'o')
            .replaceAll('á', 'a')
            .replaceAll('é', 'e')
            .replaceAll('í', 'i')
            .replaceAll('ú', 'u')
            .replaceAll(RegExp(r"[^a-z0-9]+"), '');
        return 'assets/constellations/$guess.png';
    }
  }
}


