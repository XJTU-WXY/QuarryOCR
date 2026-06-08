// lib/widgets/hotkey_recorder.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_settings.dart';

class HotkeyRecorder extends StatefulWidget {
  final HotkeyConfig value;
  final ValueChanged<HotkeyConfig> onChanged;

  const HotkeyRecorder({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<HotkeyRecorder> createState() => _HotkeyRecorderState();
}

class _HotkeyRecorderState extends State<HotkeyRecorder> {
  bool _recording = false;
  final FocusNode _focusNode = FocusNode();

  bool _ctrl = false;
  bool _alt = false;
  bool _shift = false;
  bool _meta = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _recording) {
        setState(() => _recording = false);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _startRecording() {
    setState(() {
      _recording = true;
      _ctrl = false;
      _alt = false;
      _shift = false;
      _meta = false;
    });
    _focusNode.requestFocus();
  }

  void _stopRecording() {
    setState(() => _recording = false);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (!_recording) return KeyEventResult.ignored;

    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final logical = event.logicalKey;

      // Track modifier keys for live display
      setState(() {
        _ctrl = HardwareKeyboard.instance.isControlPressed;
        _alt = HardwareKeyboard.instance.isAltPressed;
        _shift = HardwareKeyboard.instance.isShiftPressed;
        _meta = HardwareKeyboard.instance.isMetaPressed;
      });

      // Escape → cancel without changing
      if (logical == LogicalKeyboardKey.escape) {
        _stopRecording();
        return KeyEventResult.handled;
      }

      // Backspace / Delete → clear hotkey
      if (logical == LogicalKeyboardKey.backspace ||
          logical == LogicalKeyboardKey.delete) {
        widget.onChanged(const HotkeyConfig());
        _stopRecording();
        return KeyEventResult.handled;
      }

      // Build a candidate config from the current event
      final candidate = HotkeyConfig.fromKeyEvent(event);

      // Accept only when there is a non-modifier key AND at least one modifier
      if (candidate.keyId.isNotEmpty && candidate.modifierBits != 0) {
        widget.onChanged(candidate);
        _stopRecording();
        return KeyEventResult.handled;
      }
    }

    if (event is KeyUpEvent) {
      setState(() {
        _ctrl = HardwareKeyboard.instance.isControlPressed;
        _alt = HardwareKeyboard.instance.isAltPressed;
        _shift = HardwareKeyboard.instance.isShiftPressed;
        _meta = HardwareKeyboard.instance.isMetaPressed;
      });
    }

    return KeyEventResult.handled;
  }

  String get _liveLabel {
    final parts = <String>[
      if (_ctrl) 'Ctrl',
      if (_alt) 'Alt',
      if (_shift) 'Shift',
      if (_meta) 'Win',
    ];
    if (parts.isEmpty) return '请按下快捷键组合…';
    return '${parts.join('+')}+…';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKey,
      child: GestureDetector(
        onTap: _recording ? _stopRecording : _startRecording,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _recording ? cs.primary : cs.outline,
              width: _recording ? 2 : 1,
            ),
            color: _recording
                ? cs.primaryContainer.withValues(alpha: 0.35)
                : cs.surfaceContainerLowest,
          ),
          child: Row(
            children: [
              Icon(
                _recording ? Icons.keyboard : Icons.keyboard_outlined,
                size: 18,
                color: _recording ? cs.primary : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _recording ? _liveLabel : widget.value.displayLabel,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: _recording ? FontWeight.w500 : FontWeight.normal,
                    color: _recording ? cs.primary : cs.onSurface,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              if (!_recording && !widget.value.isEmpty)
                Tooltip(
                  message: '清除快捷键',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () => widget.onChanged(const HotkeyConfig()),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 16,
                          color: cs.onSurfaceVariant),
                    ),
                  ),
                ),
              if (_recording)
                Text(
                  'Esc 取消',
                  style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                      fontStyle: FontStyle.italic),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
