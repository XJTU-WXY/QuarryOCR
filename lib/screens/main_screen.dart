// lib/screens/main_screen.dart

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_settings.dart';
import '../services/app_state.dart';
import '../utils/image_loader.dart';
import '../widgets/image_viewer.dart';
import '../widgets/ocr_result_list.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  final Uint8List? externalImageBytes;
  final VoidCallback? onExternalImageConsumed;
  final Future<void> Function()? onLoadFromClipboard;
  final Future<void> Function()? onLoadFromFile;
  final Future<void> Function(Uint8List bytes)? onDroppedImageBytes;

  const MainScreen({
    super.key,
    this.externalImageBytes,
    this.onExternalImageConsumed,
    this.onLoadFromClipboard,
    this.onLoadFromFile,
    this.onDroppedImageBytes,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final _viewerController = ImageViewerController();
  ui.Image? _uiImage;
  bool _isDraggingOver = false;

  @override
  void didUpdateWidget(MainScreen old) {
    super.didUpdateWidget(old);
    if (widget.externalImageBytes != null &&
        widget.externalImageBytes != old.externalImageBytes) {
      _decodeAndDisplayImage(widget.externalImageBytes!).then((_) {
        widget.onExternalImageConsumed?.call();
      });
    }
  }

  Future<void> _decodeAndDisplayImage(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (mounted) setState(() => _uiImage = frame.image);
    } catch (_) {}
  }

  Future<void> _loadFromClipboard() async {
    if (widget.onLoadFromClipboard != null) {
      await widget.onLoadFromClipboard!();
    } else {
      final state = context.read<AppState>();
      if (state.isRecognizing) return;
      final bytes = await ImageLoader.loadFromClipboard();
      if (bytes == null) {
        if (mounted) _showSnack('剪贴板中没有找到图片');
        return;
      }
      await _localRecognize(state, bytes);
    }
  }

  Future<void> _loadFromFile() async {
    if (widget.onLoadFromFile != null) {
      await widget.onLoadFromFile!();
    } else {
      final state = context.read<AppState>();
      if (state.isRecognizing) return;
      final bytes = await ImageLoader.loadFromFile();
      if (bytes == null) return;
      await _localRecognize(state, bytes);
    }
  }

  Future<void> _localRecognize(AppState state, Uint8List bytes) async {
    state.setImage(bytes);
    await _decodeAndDisplayImage(bytes);
    await state.startRecognition();
  }

  // ── Drag-and-drop ──────────────────────────────────────────────────────────

  static const _imageExtensions = {
    '.png', '.jpg', '.jpeg', '.bmp', '.gif', '.webp', '.tiff', '.tif',
  };

  bool _isImageFile(String path) {
    final lower = path.toLowerCase();
    return _imageExtensions.any((ext) => lower.endsWith(ext));
  }

  Future<void> _handleDrop(DropDoneDetails details) async {
    setState(() => _isDraggingOver = false);
    final appState = context.read<AppState>();
    if (appState.isRecognizing) return;

    // Find first valid image file in the drop
    for (final item in details.files) {
      final path = item.path;
      if (_isImageFile(path)) {
        try {
          final bytes = await File(path).readAsBytes();
          if (widget.onDroppedImageBytes != null) {
            await widget.onDroppedImageBytes!(bytes);
          } else {
            await _localRecognize(appState, bytes);
          }
          await _decodeAndDisplayImage(bytes);
        } catch (e) {
          if (mounted) _showSnack('无法读取文件: $e');
        }
        return; // process only the first image
      }
    }
    if (mounted) _showSnack('没有识别到支持的图片文件');
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _copySelected(AppState state) async {
    final text = state.getSelectedText();
    if (text.isEmpty) {
      _showSnack('没有选中任何内容');
      return;
    }
    await ImageLoader.copyTextToClipboard(text);
    if (mounted) _showSnack('已复制到剪贴板');
  }

  Future<void> _openSettings(BuildContext ctx, AppState state) async {
    final result = await Navigator.of(ctx).push<AppSettings>(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(initialSettings: state.settings),
      ),
    );
    if (result != null) await state.saveSettings(result);
  }

  Future<void> _openAbout() async {
    final uri = Uri.parse('https://github.com/XJTU-WXY/QuarryOCR');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isRecognizing = state.isRecognizing;
    final hasResult = state.hasResult;
    final controlsEnabled = !isRecognizing;

    return Scaffold(
      body: Column(
        children: [
          _buildTopToolbar(state, controlsEnabled),
          const Divider(height: 1),
          Expanded(
            child: Row(
              children: [
                // ── Left: image viewer wrapped in drop target ──────────────
                Expanded(
                  flex: 6,
                  child: DropTarget(
                    onDragEntered: (_) =>
                        setState(() => _isDraggingOver = true),
                    onDragExited: (_) =>
                        setState(() => _isDraggingOver = false),
                    onDragDone: _handleDrop,
                    child: Stack(
                      children: [
                        ControlledImageViewer(
                          controller: _viewerController,
                          uiImage: _uiImage,
                          ocrResult: state.ocrResult,
                          isRecognizing: isRecognizing,
                          onBoxSelectionChanged: controlsEnabled && hasResult
                              ? (idx, selected) =>
                                  state.setBoxSelected(idx, selected)
                              : null,
                        ),
                        // Drag-over highlight overlay
                        if (_isDraggingOver)
                          Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.18),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 3,
                              ),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.file_download_outlined,
                                    size: 64,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    '松开以识别图片',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                // ── Right: result list ──────────────────────────────────────
                SizedBox(
                  width: 340,
                  child: OcrResultList(
                    ocrResult: state.ocrResult,
                    enabled: controlsEnabled && hasResult,
                    onBoxSelectionChanged: (idx, selected) =>
                        state.setBoxSelected(idx, selected),
                    onSelectAll: state.selectAll,
                    onSelectNone: state.selectNone,
                    onCopySelected: () => _copySelected(state),
                  ),
                ),
              ],
            ),
          ),
          if (state.status == AppStatus.error && state.errorMessage != null)
            _ErrorBar(message: state.errorMessage!),
        ],
      ),
    );
  }


  Widget _buildTopToolbar(AppState state, bool controlsEnabled) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Row(
        children: [
          // ── Left group: load actions ──
          _TBtn(
            label: '从剪贴板识别',
            icon: Icons.content_paste,
            enabled: !state.isRecognizing,
            onPressed: _loadFromClipboard,
          ),
          const SizedBox(width: 6),
          _TBtn(
            label: '从文件识别',
            icon: Icons.folder_open,
            enabled: !state.isRecognizing,
            onPressed: _loadFromFile,
          ),
          const SizedBox(width: 6),
          // ── Fit to window — stays close to the left group ──
          _TBtn(
            label: '适合窗口',
            icon: Icons.fit_screen,
            enabled: controlsEnabled && state.hasImage,
            onPressed: _viewerController.fitToWindow,
          ),

          // ── Spacer pushes settings/about to the right ──
          const Spacer(),

          // ── Right group: settings & about ──
          _TBtn(
            label: '设置',
            icon: Icons.settings_outlined,
            enabled: true,
            onPressed: () => _openSettings(context, state),
          ),
          const SizedBox(width: 6),
          _TBtn(
            label: '关于',
            icon: Icons.info_outline,
            enabled: true,
            onPressed: _openAbout,
          ),
        ],
      ),
    );
  }
}

// ── Shared toolbar button ─────────────────────────────────────────────────────

class _TBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onPressed;

  const _TBtn({
    required this.label,
    required this.icon,
    required this.enabled,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon, size: 15),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

// ── Error bar ─────────────────────────────────────────────────────────────────

class _ErrorBar extends StatelessWidget {
  final String message;
  const _ErrorBar({required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: cs.onErrorContainer, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: cs.onErrorContainer, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
