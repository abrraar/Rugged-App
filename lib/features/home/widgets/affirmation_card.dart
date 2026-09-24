import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/features/affirmation/affirmation_screen.dart';
import 'package:rugged/features/affirmation/provider/affirmation_provider.dart';
import 'package:provider/provider.dart';

class AffirmationCard extends StatefulWidget {
  final bool isCompact;
  const AffirmationCard({super.key, this.isCompact = false});

  @override
  State<AffirmationCard> createState() => _AffirmationCardState();
}

class _AffirmationCardState extends State<AffirmationCard> {
  int _lastIndex = -1;
  bool _isForward = true;

  @override
  Widget build(BuildContext context) {
    return Consumer<AffirmationProvider>(
      builder: (context, provider, _) {
        final allAffirmations = provider.affirmations;
        final current = provider.currentAffirmation;

        if (allAffirmations.isEmpty || current == null) {
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AffirmationScreen()),
              );
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                widget.isCompact ? 16.w : 16.0,
                widget.isCompact ? 4.h : 4.0, 
                widget.isCompact ? 16.w : 16.0, 
                widget.isCompact ? 4.h : 4.0
              ),
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: AppColors.crimson,
                    width: 3,
                  ),
                ),
              ),
              child: Text(
                '"Tap here to enter your first affirmation..."',
                style: AppTextStyles.bodySmall.adaptive(context).copyWith(
                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
              ),
            ),
          );
        }

        final int currentIndex = allAffirmations.indexWhere((a) => a.id == current.id);

        // Track direction for the slide animation
        if (_lastIndex == -1) {
          _lastIndex = currentIndex;
        } else if (_lastIndex != currentIndex) {
          // If we jumped from end to start, treat as forward
          if (_lastIndex == allAffirmations.length - 1 && currentIndex == 0) {
            _isForward = true;
          }
          // If we jumped from start to end, treat as backward
          else if (_lastIndex == 0 && currentIndex == allAffirmations.length - 1) {
            _isForward = false;
          }
          else {
            _isForward = currentIndex > _lastIndex;
          }
          _lastIndex = currentIndex;
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AffirmationScreen()),
            );
          },
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity == null) return;
            
            if (details.primaryVelocity! < -200) {
              // Swipe Left -> Next
              final nextIdx = (currentIndex + 1) % allAffirmations.length;
              provider.setManualAffirmation(allAffirmations[nextIdx]);
            } else if (details.primaryVelocity! > 200) {
              // Swipe Right -> Prev
              final prevIdx = (currentIndex - 1 + allAffirmations.length) % allAffirmations.length;
              provider.setManualAffirmation(allAffirmations[prevIdx]);
            }
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              widget.isCompact ? 16.w : 16.0,
              widget.isCompact ? 4.h : 4.0, 
              widget.isCompact ? 16.w : 16.0, 
              widget.isCompact ? 4.h : 4.0
            ),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: AppColors.crimson,
                  width: 3,
                ),
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    ...previousChildren,
                    ?currentChild,
                  ],
                );
              },
              transitionBuilder: (Widget child, Animation<double> animation) {
                // Create a cohesive horizontal slide transition
                final isIncoming = child.key == ValueKey(current.id);

                Offset beginOffset;
                if (isIncoming) {
                  beginOffset = _isForward ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0);
                } else {
                  beginOffset = _isForward ? const Offset(-1.0, 0.0) : const Offset(1.0, 0.0);
                }

                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(begin: beginOffset, end: Offset.zero).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Column(
                key: ValueKey(current.id),
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '"${current.text}"',
                    style: AppTextStyles.bodySmall.adaptive(context).copyWith(
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                  if (current.speaker != null && current.speaker!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      "— ${current.speaker}",
                      style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
