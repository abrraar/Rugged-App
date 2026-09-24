import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class EliteSnackbar extends StatefulWidget {
  final String message;
  final VoidCallback? onUndo;
  final VoidCallback onDismissed;
  final bool isError;

  const EliteSnackbar({
    super.key,
    required this.message,
    this.onUndo,
    required this.onDismissed,
    this.isError = false,
  });

  static void show(
    BuildContext context, 
    String message, {
    VoidCallback? onUndo,
    bool isError = false,
  }) {
    final overlay = Overlay.of(context);

    late OverlayEntry overlayEntry;
    bool removed = false;

    overlayEntry = OverlayEntry(
      builder: (context) => EliteSnackbar(
        message: message,
        onUndo: onUndo,
        isError: isError,
        onDismissed: () {
          if (!removed) {
            removed = true;
            // CRITICAL: Ensure removal happens AFTER the current frame
            SchedulerBinding.instance.addPostFrameCallback((_) {
              if (overlayEntry.mounted) {
                overlayEntry.remove();
              }
            });
          }
        },
      ),
    );

    overlay.insert(overlayEntry);
  }

  @override
  State<EliteSnackbar> createState() => _EliteSnackbarState();
}

class _EliteSnackbarState extends State<EliteSnackbar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  double _dragOffset = 0.0;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, 2.0), 
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _controller.forward();

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) _dismiss();
    });
  }

  void _dismiss() async {
    if (!mounted || _isDismissing) return;
    _isDismissing = true;
    
    // Smoothly animate out before removal
    await _controller.reverse();
    if (mounted) {
      widget.onDismissed();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final Size screenSize = mediaQuery.size;
    final bool isCompact = screenSize.width < 600;
    
    // ELITE DYNAMIC INSETS:
    // viewInsets.bottom = Keyboard height
    // padding.bottom = System Navigation Bar height
    final double keyboardHeight = mediaQuery.viewInsets.bottom;
    final double systemNavBarHeight = mediaQuery.padding.bottom;
    
    final double effectiveMaxWidth = isCompact ? (screenSize.width - 40.0) : 460.0;
    
    // Add a base margin plus the dynamic system insets
    final double baseMargin = isCompact ? 24.0 : 30.0;
    final double finalBottomPadding = baseMargin + systemNavBarHeight + keyboardHeight;

    return Positioned(
      bottom: finalBottomPadding + _dragOffset,
      left: 0,
      right: 0,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: effectiveMaxWidth.clamp(0.0, double.infinity)),
          child: GestureDetector(
            onVerticalDragUpdate: (details) {
              final delta = details.primaryDelta ?? 0;
              if (delta > 0) {
                setState(() {
                  _dragOffset -= delta;
                });
              }
            },
            onVerticalDragEnd: (details) {
              // Dismiss if dragged down sufficiently
              if (_dragOffset < -20.0) {
                _dismiss();
              } else {
                setState(() {
                  _dragOffset = 0.0;
                });
              }
            },
            child: SlideTransition(
              position: _offsetAnimation,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  decoration: BoxDecoration(
                    color: widget.isError ? AppColors.error.withValues(alpha: 0.9) : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        widget.isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                        color: widget.isError ? Colors.white : AppColors.success,
                        size: 20.0,
                      ),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: Text(
                          widget.message.toUpperCase(),
                          style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      if (widget.onUndo != null)
                        GestureDetector(
                          onTap: () {
                            widget.onUndo!();
                            _dismiss();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                            decoration: BoxDecoration(
                              color: AppColors.crimson.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6.0),
                            ),
                            child: Text(
                              "UNDO",
                              style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                color: AppColors.crimson,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                    ],
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
