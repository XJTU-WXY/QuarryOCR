// lib/models/app_settings.dart

import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';


class HotkeyConfig {
  final String keyId;

  final int modifierBits;

  const HotkeyConfig({this.keyId = '', this.modifierBits = 0});

  bool get isEmpty => keyId.isEmpty;

  bool get hasCtrl => (modifierBits & 1) != 0;
  bool get hasAlt => (modifierBits & 2) != 0;
  bool get hasShift => (modifierBits & 4) != 0;
  bool get hasMeta => (modifierBits & 8) != 0;

  HotKey? toHotKey() {
    if (isEmpty) return null;
    final key = _keyIdToLogicalKey(keyId);
    if (key == null) return null;
    final mods = <HotKeyModifier>[
      if (hasCtrl) HotKeyModifier.control,
      if (hasAlt) HotKeyModifier.alt,
      if (hasShift) HotKeyModifier.shift,
      if (hasMeta) HotKeyModifier.meta,
    ];
    return HotKey(
      key: key,
      modifiers: mods,
      scope: HotKeyScope.system,
    );
  }

  String get displayLabel {
    if (isEmpty) return '未设置';
    final parts = <String>[
      if (hasCtrl) 'Ctrl',
      if (hasAlt) 'Alt',
      if (hasShift) 'Shift',
      if (hasMeta) 'Win',
      _keyIdToLabel(keyId),
    ];
    return parts.join('+');
  }

  HotkeyConfig copyWith({String? keyId, int? modifierBits}) => HotkeyConfig(
        keyId: keyId ?? this.keyId,
        modifierBits: modifierBits ?? this.modifierBits,
      );

  static HotkeyConfig fromPrefs(SharedPreferences prefs, String prefix) {
    return HotkeyConfig(
      keyId: prefs.getString('${prefix}_key') ?? '',
      modifierBits: prefs.getInt('${prefix}_mods') ?? 0,
    );
  }

  Future<void> toPrefs(SharedPreferences prefs, String prefix) async {
    await prefs.setString('${prefix}_key', keyId);
    await prefs.setInt('${prefix}_mods', modifierBits);
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  static LogicalKeyboardKey? _keyIdToLogicalKey(String id) {
    if (id.isEmpty) return null;
    // Single printable character
    if (id.length == 1) {
      return LogicalKeyboardKey.findKeyByKeyId(
          LogicalKeyboardKey.unicodePlane | id.codeUnitAt(0));
    }

    const map = <String, LogicalKeyboardKey>{
      'F1': LogicalKeyboardKey.f1,
      'F2': LogicalKeyboardKey.f2,
      'F3': LogicalKeyboardKey.f3,
      'F4': LogicalKeyboardKey.f4,
      'F5': LogicalKeyboardKey.f5,
      'F6': LogicalKeyboardKey.f6,
      'F7': LogicalKeyboardKey.f7,
      'F8': LogicalKeyboardKey.f8,
      'F9': LogicalKeyboardKey.f9,
      'F10': LogicalKeyboardKey.f10,
      'F11': LogicalKeyboardKey.f11,
      'F12': LogicalKeyboardKey.f12,
      'Space': LogicalKeyboardKey.space,
      'Tab': LogicalKeyboardKey.tab,
      'Enter': LogicalKeyboardKey.enter,
      'Backspace': LogicalKeyboardKey.backspace,
      'Delete': LogicalKeyboardKey.delete,
      'Insert': LogicalKeyboardKey.insert,
      'Home': LogicalKeyboardKey.home,
      'End': LogicalKeyboardKey.end,
      'PageUp': LogicalKeyboardKey.pageUp,
      'PageDown': LogicalKeyboardKey.pageDown,
      'ArrowUp': LogicalKeyboardKey.arrowUp,
      'ArrowDown': LogicalKeyboardKey.arrowDown,
      'ArrowLeft': LogicalKeyboardKey.arrowLeft,
      'ArrowRight': LogicalKeyboardKey.arrowRight,
    };
    return map[id];
  }

  static String _keyIdToLabel(String id) {
    const labels = <String, String>{
      'Space': '空格',
      'Tab': 'Tab',
      'Enter': 'Enter',
      'Backspace': '←',
      'Delete': 'Del',
      'Insert': 'Ins',
      'Home': 'Home',
      'End': 'End',
      'PageUp': 'PgUp',
      'PageDown': 'PgDn',
      'ArrowUp': '↑',
      'ArrowDown': '↓',
      'ArrowLeft': '←',
      'ArrowRight': '→',
    };
    return labels[id] ?? id.toUpperCase();
  }


  static HotkeyConfig fromKeyEvent(KeyEvent event) {
    final logical = event.logicalKey;

    String keyId = '';
    final label = logical.keyLabel;
    if (label.length == 1) {
      keyId = label.toLowerCase();
    } else {

      final namedKeys = {
        LogicalKeyboardKey.f1: 'F1',
        LogicalKeyboardKey.f2: 'F2',
        LogicalKeyboardKey.f3: 'F3',
        LogicalKeyboardKey.f4: 'F4',
        LogicalKeyboardKey.f5: 'F5',
        LogicalKeyboardKey.f6: 'F6',
        LogicalKeyboardKey.f7: 'F7',
        LogicalKeyboardKey.f8: 'F8',
        LogicalKeyboardKey.f9: 'F9',
        LogicalKeyboardKey.f10: 'F10',
        LogicalKeyboardKey.f11: 'F11',
        LogicalKeyboardKey.f12: 'F12',
        LogicalKeyboardKey.space: 'Space',
        LogicalKeyboardKey.tab: 'Tab',
        LogicalKeyboardKey.enter: 'Enter',
        LogicalKeyboardKey.backspace: 'Backspace',
        LogicalKeyboardKey.delete: 'Delete',
        LogicalKeyboardKey.insert: 'Insert',
        LogicalKeyboardKey.home: 'Home',
        LogicalKeyboardKey.end: 'End',
        LogicalKeyboardKey.pageUp: 'PageUp',
        LogicalKeyboardKey.pageDown: 'PageDown',
        LogicalKeyboardKey.arrowUp: 'ArrowUp',
        LogicalKeyboardKey.arrowDown: 'ArrowDown',
        LogicalKeyboardKey.arrowLeft: 'ArrowLeft',
        LogicalKeyboardKey.arrowRight: 'ArrowRight',
      };
      keyId = namedKeys[logical] ?? '';
    }

    final isModifier = {
      LogicalKeyboardKey.control,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.controlRight,
      LogicalKeyboardKey.alt,
      LogicalKeyboardKey.altLeft,
      LogicalKeyboardKey.altRight,
      LogicalKeyboardKey.shift,
      LogicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.shiftRight,
      LogicalKeyboardKey.meta,
      LogicalKeyboardKey.metaLeft,
      LogicalKeyboardKey.metaRight,
    }.contains(logical);

    if (isModifier) keyId = '';

    final hw = HardwareKeyboard.instance;
    int bits = 0;
    if (hw.isControlPressed) bits |= 1;
    if (hw.isAltPressed) bits |= 2;
    if (hw.isShiftPressed) bits |= 4;
    if (hw.isMetaPressed) bits |= 8;

    return HotkeyConfig(keyId: keyId, modifierBits: bits);
  }
}

// ─── AppSettings ──────────────────────────────────────────────────────────────

class AppSettings {
  String apiUrl;
  String separator;
  bool useDet;
  bool useCls;
  HotkeyConfig clipboardHotkey;

  AppSettings({
    this.apiUrl = 'http://localhost:9003/ocr',
    this.separator = r'\n',
    this.useDet = true,
    this.useCls = true,
    HotkeyConfig? clipboardHotkey,
  }) : clipboardHotkey = clipboardHotkey ?? const HotkeyConfig();

  static const _keyApiUrl = 'api_url';
  static const _keySeparator = 'separator';
  static const _keyUseDet = 'use_det';
  static const _keyUseCls = 'use_cls';
  static const _prefixClipboardHotkey = 'clipboard_hotkey';

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      apiUrl: prefs.getString(_keyApiUrl) ?? 'http://localhost:9003/ocr',
      separator: prefs.getString(_keySeparator) ?? r'\n',
      useDet: prefs.getBool(_keyUseDet) ?? true,
      useCls: prefs.getBool(_keyUseCls) ?? true,
      clipboardHotkey:
          HotkeyConfig.fromPrefs(prefs, _prefixClipboardHotkey),
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyApiUrl, apiUrl);
    await prefs.setString(_keySeparator, separator);
    await prefs.setBool(_keyUseDet, useDet);
    await prefs.setBool(_keyUseCls, useCls);
    await clipboardHotkey.toPrefs(prefs, _prefixClipboardHotkey);
  }

  String get resolvedSeparator => separator
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\t', '\t')
      .replaceAll(r'\r', '\r');

  AppSettings copyWith({
    String? apiUrl,
    String? separator,
    bool? useDet,
    bool? useCls,
    HotkeyConfig? clipboardHotkey,
  }) =>
      AppSettings(
        apiUrl: apiUrl ?? this.apiUrl,
        separator: separator ?? this.separator,
        useDet: useDet ?? this.useDet,
        useCls: useCls ?? this.useCls,
        clipboardHotkey: clipboardHotkey ?? this.clipboardHotkey,
      );
}
