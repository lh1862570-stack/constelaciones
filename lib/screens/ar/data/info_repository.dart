import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class ConstellationInfo {
  const ConstellationInfo({required this.title, required this.paragraphs});

  final String title;
  final List<String> paragraphs;
}

class InfoRepository {
  static const String dataAssetPath = 'assets/data/constellations_info.es.json';

  Future<Map<String, ConstellationInfo>> loadInfo() async {
    final String jsonStr = await rootBundle.loadString(dataAssetPath);
    final Map<String, dynamic> raw = json.decode(jsonStr) as Map<String, dynamic>;
    final Map<String, ConstellationInfo> result = <String, ConstellationInfo>{};
    for (final MapEntry<String, dynamic> e in raw.entries) {
      final Map<String, dynamic> v = e.value as Map<String, dynamic>;
      final String title = (v['title'] as String?) ?? e.key;
      final List<dynamic> parasDyn = (v['paragraphs'] as List<dynamic>? ?? <dynamic>[]);
      final List<String> paragraphs = parasDyn.map((dynamic p) => p.toString()).toList();
      result[e.key.trim().toLowerCase()] = ConstellationInfo(title: title, paragraphs: paragraphs);
    }
    return result;
  }
}


