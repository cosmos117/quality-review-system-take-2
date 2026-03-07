import 'package:flutter/material.dart';

/// A sortable table header cell with sort indicator icon.
/// Used across admin and employee dashboard tables.
class SortableHeaderCell extends StatelessWidget {
  final String label;
  final bool active;
  final bool ascending;
  final VoidCallback? onTap;
  final double fontSize;
  final bool showIcon;
  final bool expandLabel;

  const SortableHeaderCell({
    super.key,
    required this.label,
    required this.active,
    required this.ascending,
    this.onTap,
    this.fontSize = 13,
    this.showIcon = true,
    this.expandLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final icon = active
        ? (ascending
              ? Icons.arrow_upward_rounded
              : Icons.arrow_downward_rounded)
        : Icons.unfold_more_rounded;
    final color = active ? Colors.blueGrey[800] : Colors.blueGrey[600];
    final textWidget = Text(
      label,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        color: color,
        fontSize: fontSize,
      ),
      overflow: TextOverflow.ellipsis,
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          expandLabel ? Expanded(child: textWidget) : textWidget,
          if (showIcon && onTap != null) ...[
            const SizedBox(width: 4),
            Icon(icon, size: fontSize + 3, color: color),
          ],
        ],
      ),
    );
  }
}
