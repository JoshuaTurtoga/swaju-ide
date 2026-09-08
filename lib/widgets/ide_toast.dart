import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

void showIdeToast(BuildContext context, String message, AppTheme theme, {bool isError = true, IconData? icon}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  
  entry = OverlayEntry(
    builder: (context) {
      return _IdeToastWidget(
        message: message,
        theme: theme,
        isError: isError,
        icon: icon,
        onDismissed: () {
          if (entry.mounted) entry.remove();
        },
      );
    },
  );

  overlay.insert(entry);
}

class _IdeToastWidget extends StatefulWidget {
  final String message;
  final AppTheme theme;
  final bool isError;
  final IconData? icon;
  final VoidCallback onDismissed;

  const _IdeToastWidget({
    required this.message,
    required this.theme,
    required this.isError,
    this.icon,
    required this.onDismissed,
  });

  @override
  State<_IdeToastWidget> createState() => _IdeToastWidgetState();
}

class _IdeToastWidgetState extends State<_IdeToastWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _slideAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    
    _slideAnimation = Tween<double>(begin: -50.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();

    // Auto dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _controller.reverse().then((_) {
          widget.onDismissed();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isError ? widget.theme.error : widget.theme.success;
    final displayIcon = widget.icon ?? (widget.isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded);

    return Positioned(
      left: 16,
      bottom: 36,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(_slideAnimation.value, 0),
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: child,
            ),
          );
        },
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: bgColor.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
              ]
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(displayIcon, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  widget.message,
                  style: widget.theme.uiTextSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none, // Explicitly remove underline
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
