import 'package:flutter/material.dart';

/// A desktop split-pane handle with a generous hit target and hover feedback.
class WorkspaceResizeHandle extends StatefulWidget {
  const WorkspaceResizeHandle({
    required this.onDrag,
    required this.onDragEnd,
    required this.onDragCancel,
    required this.onDoubleTap,
    required this.tooltip,
    this.height = double.infinity,
    super.key,
  });

  final ValueChanged<double> onDrag;
  final VoidCallback onDragEnd;
  final VoidCallback onDragCancel;
  final VoidCallback onDoubleTap;
  final String tooltip;
  final double height;

  @override
  State<WorkspaceResizeHandle> createState() => _WorkspaceResizeHandleState();
}

class _WorkspaceResizeHandleState extends State<WorkspaceResizeHandle> {
  bool _hovered = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = _hovered || _dragging;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) => setState(() => _dragging = true),
          onHorizontalDragUpdate: (details) => widget.onDrag(details.delta.dx),
          onHorizontalDragEnd: (_) {
            setState(() => _dragging = false);
            widget.onDragEnd();
          },
          onHorizontalDragCancel: () {
            setState(() => _dragging = false);
            widget.onDragCancel();
          },
          onDoubleTap: widget.onDoubleTap,
          child: Semantics(
            label: '调整栏宽',
            hint: widget.tooltip,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 10,
              height: widget.height,
              decoration: BoxDecoration(
                color: active ? scheme.primary.withValues(alpha: 0.06) : null,
                border: Border(
                  left: BorderSide(
                    color: active ? scheme.primary : scheme.outlineVariant,
                    width: active ? 2 : 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
