import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ide_providers.dart';

class VerticalSplitView extends ConsumerStatefulWidget {
  final Widget top;
  final Widget bottom;
  final double initialRatio;

  const VerticalSplitView({
    super.key,
    required this.top,
    required this.bottom,
    this.initialRatio = 0.6, // 60% top, 40% bottom default
  });

  @override
  ConsumerState<VerticalSplitView> createState() => _VerticalSplitViewState();
}

class _VerticalSplitViewState extends ConsumerState<VerticalSplitView> {
  late double _ratio;
  final double _dividerHeight = 12.0;

  @override
  void initState() {
    super.initState();
    _ratio = widget.initialRatio;
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.fromType(ref.watch(themeProvider));

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight - _dividerHeight;

        return Column(
          children: [
            // ── Top View ──
            SizedBox(
              height: maxHeight * _ratio,
              child: widget.top,
            ),
            
            // ── Draggable Divider ──
            MouseRegion(
              cursor: SystemMouseCursors.resizeUpDown,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanUpdate: (details) {
                  setState(() {
                    _ratio += details.delta.dy / maxHeight;
                    // Clamp the ratio so neither view disappears completely
                    if (_ratio > 0.85) _ratio = 0.85;
                    if (_ratio < 0.15) _ratio = 0.15;
                  });
                },
                child: Container(
                  height: _dividerHeight,
                  width: double.infinity,
                  color: Colors.transparent, // Invisible hit area
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.panelBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Bottom View ──
            SizedBox(
              height: maxHeight * (1 - _ratio),
              child: widget.bottom,
            ),
          ],
        );
      },
    );
  }
}
