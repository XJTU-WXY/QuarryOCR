// lib/services/app_state.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/ocr_result.dart';
import '../models/app_settings.dart';
import 'ocr_service.dart';

enum AppStatus { idle, recognizing, done, error }

class AppState extends ChangeNotifier {
  AppSettings settings = AppSettings();
  AppStatus status = AppStatus.idle;
  Uint8List? imageBytes;
  OcrResult? ocrResult;
  String? errorMessage;

  bool _trayIconPhase = false;
  Timer? _blinkTimer;
  final ValueNotifier<bool> trayBlinkPhase = ValueNotifier(false);

  bool get isRecognizing => status == AppStatus.recognizing;
  bool get hasResult => status == AppStatus.done && ocrResult != null;
  bool get hasImage => imageBytes != null;

  Future<void> loadSettings() async {
    settings = await AppSettings.load();
    notifyListeners();
  }

  Future<void> saveSettings(AppSettings newSettings) async {
    settings = newSettings;
    await settings.save();
    notifyListeners();
  }

  void setImage(Uint8List bytes) {
    imageBytes = bytes;
    ocrResult = null;
    status = AppStatus.idle;
    errorMessage = null;
    notifyListeners();
  }

  Future<void> startRecognition() async {
    if (imageBytes == null) return;
    status = AppStatus.recognizing;
    errorMessage = null;
    ocrResult = null;
    _startBlink();
    notifyListeners();

    try {
      final result = await OcrService.recognize(
        imageBytes: imageBytes!,
        settings: settings,
      );
      for (final box in result.boxes) {
        box.selected = true;
      }
      ocrResult = result;
      status = AppStatus.done;
    } catch (e) {
      errorMessage = e.toString();
      status = AppStatus.error;
    } finally {
      _stopBlink();
      notifyListeners();
    }
  }

  void _startBlink() {
    _blinkTimer?.cancel();
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _trayIconPhase = !_trayIconPhase;
      trayBlinkPhase.value = _trayIconPhase;
    });
  }

  void _stopBlink() {
    _blinkTimer?.cancel();
    _blinkTimer = null;
    _trayIconPhase = false;
    trayBlinkPhase.value = false;
  }

  void selectAll() {
    ocrResult?.boxes.forEach((b) => b.selected = true);
    notifyListeners();
  }

  void selectNone() {
    ocrResult?.boxes.forEach((b) => b.selected = false);
    notifyListeners();
  }

  void toggleBox(int index) {
    if (ocrResult == null) return;
    ocrResult!.boxes[index].selected = !ocrResult!.boxes[index].selected;
    notifyListeners();
  }

  void setBoxSelected(int index, bool value) {
    if (ocrResult == null) return;
    ocrResult!.boxes[index].selected = value;
    notifyListeners();
  }

  String getSelectedText() {
    if (ocrResult == null) return '';
    final selected = ocrResult!.selectedBoxes;
    return selected.map((b) => b.text).join(settings.resolvedSeparator);
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    trayBlinkPhase.dispose();
    super.dispose();
  }
}
