import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CustomDropdown<T> extends StatefulWidget {
  final T value;
  final List<CustomDropdownItem<T>> items;
  final ValueChanged<T?> onChanged;
  final AppTheme theme;

  const CustomDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.theme,
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
      duration: const Duration(milliseconds: 200),
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
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // Full screen gesture detector to close the dropdown when tapping outside
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closeDropdown,
                child: Container(color: Colors.transparent),
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(0, size.height), // flush below the button
              child: Material(
                color: Colors.transparent,
                child: SizedBox(
                  width: size.width,
                  child: SizeTransition(
                    sizeFactor: _expandAnimation,
                    axisAlignment: -1.0, // align to top
                    child: Container(
                      decoration: widget.theme.neumorphicOuter(radius: 8).copyWith(
                        color: widget.theme.surfaceVariant,
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
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
                            hoverColor: widget.theme.accent.withValues(alpha: 0.1),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: (_isOpen
                    ? widget.theme.neumorphicInner(radius: 8)
                    : widget.theme.neumorphicOuter(radius: 8))
                .copyWith(
              borderRadius: _isOpen
                  ? const BorderRadius.vertical(top: Radius.circular(8))
                  : BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                selectedItem.selectedChild ?? selectedItem.child,
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _isOpen ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.expand_more_rounded,
                    color: widget.theme.textSecondary,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
