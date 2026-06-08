// lib/models/ocr_result.dart

import 'dart:ui';

class OcrBox {
  final int index;
  final String text;
  final List<Offset> dtBoxes; // [topLeft, topRight, bottomRight, bottomLeft]
  final double score;
  bool selected;

  OcrBox({
    required this.index,
    required this.text,
    required this.dtBoxes,
    required this.score,
    this.selected = false,
  });

  factory OcrBox.fromJson(int index, Map<String, dynamic> json) {
    final rawBoxes = json['dt_boxes'] as List<dynamic>;
    final boxes = rawBoxes
        .map((pt) => Offset(
              (pt[0] as num).toDouble(),
              (pt[1] as num).toDouble(),
            ))
        .toList();
    return OcrBox(
      index: index,
      text: json['rec_txt'] as String,
      dtBoxes: boxes,
      score: double.tryParse(json['score'].toString()) ?? 0.0,
    );
  }

  Rect get boundingRect {
    if (dtBoxes.isEmpty) return Rect.zero;
    double minX = dtBoxes[0].dx;
    double maxX = dtBoxes[0].dx;
    double minY = dtBoxes[0].dy;
    double maxY = dtBoxes[0].dy;
    for (final pt in dtBoxes) {
      if (pt.dx < minX) minX = pt.dx;
      if (pt.dx > maxX) maxX = pt.dx;
      if (pt.dy < minY) minY = pt.dy;
      if (pt.dy > maxY) maxY = pt.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}

class OcrResult {
  final List<OcrBox> boxes;

  OcrResult(this.boxes);

  factory OcrResult.fromJson(Map<String, dynamic> json) {
    final boxes = <OcrBox>[];
    final keys = json.keys.toList()
      ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
    for (final key in keys) {
      boxes.add(OcrBox.fromJson(int.parse(key), json[key] as Map<String, dynamic>));
    }
    return OcrResult(boxes);
  }

  bool get isEmpty => boxes.isEmpty;

  List<OcrBox> get selectedBoxes =>
      boxes.where((b) => b.selected).toList()
        ..sort((a, b) => a.index.compareTo(b.index));
}
