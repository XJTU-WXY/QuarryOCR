// lib/main.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'models/app_settings.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'services/app_state.dart';
import 'services/hotkey_service.dart';
import 'utils/image_loader.dart';
import 'screens/main_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';

Future<String> getAppVersion() async {
  final PackageInfo packageInfo = await PackageInfo.fromPlatform();
  final String version = packageInfo.version;
  return 'v$version';
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await hotKeyManager.unregisterAll();

  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(1100, 700),
    minimumSize: Size(800, 500),
    center: true,
    title: 'QuarryOCR',
    skipTaskbar: false,
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  await windowManager.setPreventClose(true);

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const OcrApp(),
    ),
  );
}

class OcrApp extends StatelessWidget {
  const OcrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuarryOCR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1976D2),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: "Microsoft YaHei",
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1976D2),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: "Microsoft YaHei",
      ),
      themeMode: ThemeMode.system,
      home: const AppShell(),
      
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WindowListener, TrayListener {
  bool _shouldShowAfterRecognition = false;
  Uint8List? _pendingImageBytes;

  // Double-click detection on tray icon
  DateTime? _lastTrayClickTime;
  static const _doubleClickThreshold = Duration(milliseconds: 400);

  final _hotkeyService = HotkeyService();

  HotkeyConfig? _lastRegisteredHotkey;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    trayManager.addListener(this);
    _initAsync();
  }

  Future<void> _initAsync() async {
    final appState = context.read<AppState>();
    await appState.loadSettings();
    // Must init tray AFTER the widget tree is ready
    await _setupTray(recognizing: false);
    await _applyHotkey(appState);
    _lastRegisteredHotkey = appState.settings.clipboardHotkey;
    appState.trayBlinkPhase.addListener(_onBlinkPhaseChanged);
    appState.addListener(_onAppStateChanged);
  }

  Future<void> _applyHotkey(AppState appState) async {
    await _hotkeyService.updateHotkey(
      appState.settings.clipboardHotkey,
      _hotkeyTriggered,
    );
  }

  Future<void> _hotkeyTriggered() async {
    final appState = context.read<AppState>();
    if (appState.isRecognizing) return;
    _shouldShowAfterRecognition = true;
    final bytes = await ImageLoader.loadFromClipboard();
    if (bytes == null) {
      _shouldShowAfterRecognition = false;
      return;
    }
    await _recognizeImage(bytes);
  }

  Future<void> _setupTray({required bool recognizing}) async {
    // 1. Icon first
    await trayManager.setIcon('assets/tray_icon.ico');
    // 2. Tooltip
    await trayManager.setToolTip('QuarryOCR');
    String appVersion = await getAppVersion();
    // 3. Context menu last
    await trayManager.setContextMenu(Menu(
      items: [
        MenuItem(
          key: 'version',
          label: 'QuarryOCR $appVersion',
          disabled: true,
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'load_clipboard',
          label: '从剪贴板识别',
          disabled: recognizing,
        ),
        MenuItem(
          key: 'load_file',
          label: '从文件识别 ...',
          disabled: recognizing,
        ),
        MenuItem.separator(),
        MenuItem(key: 'exit', label: '退出'),
      ],
    ));
  }

  void _onBlinkPhaseChanged() {
    final phase = context.read<AppState>().trayBlinkPhase.value;
    trayManager.setIcon(
      phase ? 'assets/tray_icon_active.ico' : 'assets/tray_icon.ico',
    );
  }

  void _onAppStateChanged() async {
    final appState = context.read<AppState>();
    await _setupTray(recognizing: appState.isRecognizing);
    // Re-apply hotkey whenever settings change (saved from settings screen)
    final newHotkey = appState.settings.clipboardHotkey;
    if (_lastRegisteredHotkey == null ||
        _lastRegisteredHotkey!.keyId != newHotkey.keyId ||
        _lastRegisteredHotkey!.modifierBits != newHotkey.modifierBits) {
      await _applyHotkey(appState);
      _lastRegisteredHotkey = newHotkey;
    }
    
  }

  // ── Window ──────────────────────────────────────────────────────────────────

  Future<void> _showWindow() async {
    if (!await windowManager.isVisible()) await windowManager.show();
    await windowManager.focus();
  }

  @override
  void onWindowClose() async => windowManager.hide();

  @override
  void onWindowFocus() {}

  // ── TrayListener ────────────────────────────────────────────────────────────

  @override
  void onTrayIconMouseDown() {
    final now = DateTime.now();
    if (_lastTrayClickTime != null &&
        now.difference(_lastTrayClickTime!) < _doubleClickThreshold) {
      _lastTrayClickTime = null;
      _showWindow();
    } else {
      _lastTrayClickTime = now;
    }
  }

  @override
  void onTrayIconMouseUp() {}

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayIconRightMouseUp() {
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'load_clipboard':
        _trayLoadFromClipboard();
      case 'load_file':
        _trayLoadFromFile();
      case 'exit':
        _exit();
    }
  }

  // ── Image loading ───────────────────────────────────────────────────────────

  Future<void> _trayLoadFromClipboard() async {
    final appState = context.read<AppState>();
    if (appState.isRecognizing) return;
    _shouldShowAfterRecognition = true;
    final bytes = await ImageLoader.loadFromClipboard();
    if (bytes == null) {
      _shouldShowAfterRecognition = false;
      return;
    }
    await _recognizeImage(bytes);
  }

  Future<void> _trayLoadFromFile() async {
    final appState = context.read<AppState>();
    if (appState.isRecognizing) return;
    await _showWindow();
    _shouldShowAfterRecognition = false;
    final bytes = await ImageLoader.loadFromFile();
    if (bytes == null) return;
    await _recognizeImage(bytes);
  }

  Future<void> _recognizeImage(Uint8List bytes) async {
    final appState = context.read<AppState>();
    appState.setImage(bytes);
    setState(() => _pendingImageBytes = bytes);
    await appState.startRecognition();
    if (_shouldShowAfterRecognition) {
      _shouldShowAfterRecognition = false;
      await _showWindow();
    }
  }

  void _exit() async {
    await trayManager.destroy();
    await _hotkeyService.dispose();
    dispose();
    exit(0);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    final appState = context.read<AppState>();
    appState.trayBlinkPhase.removeListener(_onBlinkPhaseChanged);
    appState.removeListener(_onAppStateChanged);
    _hotkeyService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MainScreen(
      externalImageBytes: _pendingImageBytes,
      onExternalImageConsumed: () => setState(() => _pendingImageBytes = null),
      onLoadFromClipboard: () async {
        final appState = context.read<AppState>();
        if (appState.isRecognizing) return;
        final bytes = await ImageLoader.loadFromClipboard();
        if (!context.mounted) return;
        if (bytes == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('剪贴板中没有找到图片'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        _shouldShowAfterRecognition = false;
        await _recognizeImage(bytes);
      },
      onLoadFromFile: () async {
        final appState = context.read<AppState>();
        if (appState.isRecognizing) return;
        final bytes = await ImageLoader.loadFromFile();
        if (bytes == null) return;
        _shouldShowAfterRecognition = false;
        await _recognizeImage(bytes);
      },
      onDroppedImageBytes: (bytes) async {
        final appState = context.read<AppState>();
        if (appState.isRecognizing) return;
        _shouldShowAfterRecognition = false;
        await _recognizeImage(bytes);
      },
    );
  }
}
