// lib/utils/image_loader.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:super_clipboard/super_clipboard.dart';

class ImageLoader {
  /// Pick an image file via system dialog.
  static Future<Uint8List?> loadFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final f = result.files.first;
    if (f.path != null) return File(f.path!).readAsBytes();
    return f.bytes;
  }

  /// Read an image from the system clipboard.
  static Future<Uint8List?> loadFromClipboard() async {
    final reader = await SystemClipboard.instance?.read();
    if (reader == null) return null;

    final formats = [
      Formats.png,
      Formats.jpeg,
      Formats.gif,
      Formats.webp,
      Formats.bmp,
    ];

    for (final fmt in formats) {
      if (reader.canProvide(fmt)) {
        final result = await _readFileFormat(reader, fmt);
        if (result != null) return result;
      }
    }
    return null;
  }

  static Future<Uint8List?> _readFileFormat(
      DataReader reader, FileFormat fmt) async {
    final completer = _Completer<Uint8List?>();
    reader.getFile(fmt, (file) async {
      try {
        final bytes = await file.readAll();
        completer.complete(bytes);
      } catch (_) {
        completer.complete(null);
      }
    }, onError: (_) => completer.complete(null));
    return completer.future;
  }

  /// Copy plain text to clipboard.
  static Future<void> copyTextToClipboard(String text) async {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) return;
    final item = DataWriterItem();
    item.add(Formats.plainText(text));
    await clipboard.write([item]);
  }
}

// ── Minimal async completer ────────────────────────────────────────────────

class _Completer<T> {
  T? _value;
  Object? _error;
  bool _done = false;

  Future<T> get future async {
    while (!_done) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    if (_error != null) throw _error!;
    return _value as T;
  }

  void complete(T value) {
    _value = value;
    _done = true;
  }

  void completeError(Object error) {
    _error = error;
    _done = true;
  }
}
