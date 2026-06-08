// lib/widgets/ocr_result_list.dart

import 'package:flutter/material.dart';
import '../models/ocr_result.dart';

class OcrResultList extends StatelessWidget {
  final OcrResult? ocrResult;
  final bool enabled;
  final void Function(int index, bool selected)? onBoxSelectionChanged;
  final VoidCallback? onSelectAll;
  final VoidCallback? onSelectNone;
  final VoidCallback? onCopySelected;

  const OcrResultList({
    super.key,
    this.ocrResult,
    this.enabled = true,
    this.onBoxSelectionChanged,
    this.onSelectAll,
    this.onSelectNone,
    this.onCopySelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasItems = ocrResult != null && ocrResult!.boxes.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Row(
            children: [
              _ToolbarButton(
                label: '全选',
                icon: Icons.select_all,
                enabled: enabled && hasItems,
                onPressed: onSelectAll,
              ),
              const SizedBox(width: 6),
              _ToolbarButton(
                label: '全不选',
                icon: Icons.deselect,
                enabled: enabled && hasItems,
                onPressed: onSelectNone,
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // ── Result list ──────────────────────────────────────────────────────
        Expanded(
          child: hasItems
              ? ListView.builder(
                  itemCount: ocrResult!.boxes.length,
                  itemBuilder: (context, idx) {
                    final box = ocrResult!.boxes[idx];
                    return _OcrListTile(
                      box: box,
                      enabled: enabled,
                      onTap: enabled
                          ? () => onBoxSelectionChanged?.call(idx, !box.selected)
                          : null,
                    );
                  },
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.text_fields,
                          size: 48,
                          color: cs.onSurface.withValues(alpha: 0.2)),
                      const SizedBox(height: 12),
                      Text(
                        '暂无识别结果',
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.4),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
        ),

        const Divider(height: 1),

        // ── Bottom ────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(10),
          child: FilledButton.icon(
            onPressed: enabled && hasItems ? onCopySelected : null,
            icon: const Icon(Icons.copy, size: 18),
            label: const Text(
              '复制选中文本',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── List tile ─────────────────────────────────────────────────────────────────

class _OcrListTile extends StatelessWidget {
  final OcrBox box;
  final bool enabled;
  final VoidCallback? onTap;

  const _OcrListTile({
    required this.box,
    required this.enabled,
    this.onTap,
  });

  Color _scoreColor(double score) {
    if (score >= 0.85) return Colors.green;
    if (score >= 0.65) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = box.selected;

    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: 0.13)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Index badge
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${box.index}',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Text
            Expanded(
              child: Text(
                box.text,
                style: TextStyle(
                  fontSize: 13,
                  color: enabled
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Score chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: _scoreColor(box.score).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: _scoreColor(box.score).withValues(alpha: 0.45),
                  width: 0.8,
                ),
              ),
              child: Text(
                box.score.toStringAsFixed(2),
                style: TextStyle(
                  fontSize: 10,
                  color: _scoreColor(box.score),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // Checkbox indicator
            const SizedBox(width: 8),
            Icon(
              isSelected ? Icons.check_box : Icons.check_box_outline_blank,
              size: 18,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.28),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Toolbar button ────────────────────────────────────────────────────────────

class _ToolbarButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onPressed;

  const _ToolbarButton({
    required this.label,
    required this.icon,
    required this.enabled,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
