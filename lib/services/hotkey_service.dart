// lib/services/hotkey_service.dart

import 'package:hotkey_manager/hotkey_manager.dart';
import '../models/app_settings.dart';

class HotkeyService {
  HotKey? _registeredHotKey;

  Future<void> updateHotkey(
      HotkeyConfig config, Future<void> Function() callback) async {
    await _unregister();
    final hotKey = config.toHotKey();
    if (hotKey == null) return;

    await hotKeyManager.register(
      hotKey,
      keyDownHandler: (_) => callback(),
    );
    _registeredHotKey = hotKey;
  }

  Future<void> _unregister() async {
    if (_registeredHotKey != null) {
      await hotKeyManager.unregister(_registeredHotKey!);
      _registeredHotKey = null;
    }
  }

  Future<void> dispose() async {
    await _unregister();
  }
}
