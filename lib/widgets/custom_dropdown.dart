import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CustomDropdown<T> extends StatefulWidget {
  final T value;
  final List<CustomDropdownItem<T>> items;
  final ValueChanged<T?> onChanged;
  final AppTheme theme;
  /// Set to false to hide the chevron arrow on the button.
  final bool showArrow;
  /// Optional fixed width for the dropdown button.
  final double? width;

  const CustomDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.theme,
    this.showArrow = true,
    this.width,
  });

  @override
  State<CustomDropdown<T>> createState() => _CustomDropdownState<T>();
}

class CustomDropdownItem<T> {
  final T value;
  final Widget child;
  final Widget? selectedChild;

  const CustomDropdownItem({
    required this.value,
    required this.child,
    this.selectedChild,
  });
}

class _CustomDropdownState<T> extends State<CustomDropdown<T>>
    with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    if (_isOpen) {
      _overlayEntry?.remove();
    }
    super.dispose();
  }

  void _toggleDropdown() {
    if (_isOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  void _openDropdown() {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final buttonSize = renderBox.size;
    final globalOffset = renderBox.localToGlobal(Offset.zero);
    final screenWidth = MediaQuery.of(context).size.width;

    // Tray is at least as wide as the button, minimum 120px — no clamp needed.
    final trayWidth = buttonSize.width < 120.0 ? 120.0 : buttonSize.width;

    // If tray would overflow the right edge, shift it left so it aligns to the
    // right side of the button instead of the left.
    final rightEdge = globalOffset.dx + trayWidth;
    final horizontalOffset = rightEdge > screenWidth
        ? -(trayWidth - buttonSize.width) // right-align tray to button
        : 0.0;

    _overlayEntry = OverlayEntry(
      builder: (ctx) {
        return Stack(
          children: [
            // Tap-outside dismissal
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closeDropdown,
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(horizontalOffset, buttonSize.height),
              child: Material(
                color: Colors.transparent,
                child: SizeTransition(
                  sizeFactor: _expandAnimation,
                  axisAlignment: -1.0,
                  child: Container(
                    width: trayWidth,
                    // All 4 corners identically rounded — same radius as the button
                    decoration: BoxDecoration(
                      color: widget.theme.surfaceVariant,
                      borderRadius: BorderRadius.zero,
                      boxShadow: [
                        BoxShadow(
                          color: widget.theme.outerShadowDark.withValues(alpha: 0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: widget.theme.outerShadowLight.withValues(alpha: 0.6),
                          blurRadius: 4,
                          offset: const Offset(-2, -2),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: widget.items.map((item) {
                        final isSelected = item.value == widget.value;
                        return InkWell(
                          onTap: () {
                            widget.onChanged(item.value);
                            _closeDropdown();
                          },
                          hoverColor:
                              widget.theme.accent.withValues(alpha: 0.1),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            color: isSelected
                                ? widget.theme.accent.withValues(alpha: 0.15)
                                : Colors.transparent,
                            child: item.child,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);
    _animationController.forward();
  }

  void _closeDropdown() async {
    setState(() => _isOpen = false);
    await _animationController.reverse();
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final selectedItem = widget.items.firstWhere(
      (item) => item.value == widget.value,
      orElse: () => widget.items.first,
    );

    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _toggleDropdown,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            width: widget.width,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            // Button always keeps all 4 corners rounded regardless of open state.
            decoration: (_isOpen
                    ? widget.theme.neumorphicInner(radius: 8)
                    : widget.theme.neumorphicOuter(radius: 8))
                .copyWith(borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisSize: widget.width != null ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: widget.width != null ? MainAxisAlignment.spaceBetween : MainAxisAlignment.start,
              children: [
                selectedItem.selectedChild ?? selectedItem.child,
                if (widget.showArrow) ...[  
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _isOpen ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 220),
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: widget.theme.textSecondary,
                      size: 18,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
