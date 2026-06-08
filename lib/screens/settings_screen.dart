// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../widgets/hotkey_recorder.dart';

class SettingsScreen extends StatefulWidget {
  final AppSettings initialSettings;

  const SettingsScreen({super.key, required this.initialSettings});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _urlController;
  late final TextEditingController _separatorController;
  late bool _useDet;
  late bool _useCls;
  late HotkeyConfig _clipboardHotkey;

  @override
  void initState() {
    super.initState();
    _urlController =
        TextEditingController(text: widget.initialSettings.apiUrl);
    _separatorController =
        TextEditingController(text: widget.initialSettings.separator);
    _useDet = widget.initialSettings.useDet;
    _useCls = widget.initialSettings.useCls;
    _clipboardHotkey = widget.initialSettings.clipboardHotkey;
  }

  @override
  void dispose() {
    _urlController.dispose();
    _separatorController.dispose();
    super.dispose();
  }

  void _save() {
    final newSettings = widget.initialSettings.copyWith(
      apiUrl: _urlController.text.trim(),
      separator: _separatorController.text,
      useDet: _useDet,
      useCls: _useCls,
      clipboardHotkey: _clipboardHotkey,
    );
    Navigator.of(context).pop(newSettings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('保存'),
          ),
          const SizedBox(width: 8),
          ],
        ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // ── API ────────────────────────────────────────────────────────────
          const _SectionHeader(title: 'API 配置'),
          const SizedBox(height: 12),
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'API URL',
              hintText: 'http://localhost:9003/ocr',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.link),
              helperText: '支持符合 RapidOCR API 规范的服务端，具体参阅其文档。',
            ),
          ),

          // ── Recognition ───────────────────────────────────────────────────
          const SizedBox(height: 24),
          const _SectionHeader(title: '识别选项'),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            title: const Text('使用检测模型 (use_det)'),
            subtitle: const Text('检测文字的位置区域，当文本较为分散时建议开启'),
            value: _useDet,
            onChanged: (v) => setState(() => _useDet = v),
          ),
          SwitchListTile.adaptive(
            title: const Text('使用方向分类模型 (use_cls)'),
            subtitle: const Text('自动校正文字方向，存在竖排文本时建议开启'),
            value: _useCls,
            onChanged: (v) => setState(() => _useCls = v),
          ),

          // ── Copy ──────────────────────────────────────────────────────────
          const SizedBox(height: 24),
          const _SectionHeader(title: '复制选项'),
          const SizedBox(height: 12),
          TextField(
            controller: _separatorController,
            decoration: const InputDecoration(
              labelText: '块间分隔符',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.format_line_spacing),
              helperText: r'支持转义（如 \n 换行 \t 制表符）',
            ),
          ),

          // ── Hotkey ────────────────────────────────────────────────────────
          const SizedBox(height: 24),
          const _SectionHeader(title: '全局快捷键'),
          const SizedBox(height: 12),


          // Label
          const Text('从剪贴板识别',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),

          // Recorder widget
          HotkeyRecorder(
            value: _clipboardHotkey,
            onChanged: (cfg) => setState(() => _clipboardHotkey = cfg),
          ),

          // Hint below recorder
          const SizedBox(height: 6),
          Text(
            '点击开始录制，需同时按住至少一个修饰键（Ctrl / Alt / Shift）',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),

          // // ── Save ──────────────────────────────────────────────────────────
          // const SizedBox(height: 32),
          // FilledButton.icon(
          //   onPressed: _save,
          //   icon: const Icon(Icons.save),
          //   label: const Text('保存设置'),
          //   style: FilledButton.styleFrom(
          //     padding: const EdgeInsets.symmetric(vertical: 14),
          //     shape: RoundedRectangleBorder(
          //         borderRadius: BorderRadius.circular(8)),
          //   ),
          // ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Divider(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }
}
