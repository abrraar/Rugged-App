import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';

class ExpandableAboutText extends StatefulWidget {
  final String text;
  const ExpandableAboutText({super.key, required this.text});

  @override
  State<ExpandableAboutText> createState() => _ExpandableAboutTextState();
}

class _ExpandableAboutTextState extends State<ExpandableAboutText> {
  bool _isExpanded = false;
  bool _needsExpansion = false;

  @override
  Widget build(BuildContext context) {
    final bool isCompact = MediaQuery.sizeOf(context).width < 600;

    return LayoutBuilder(
      builder: (context, constraints) {
        final style = AppTextStyles.bodySmall.adaptive(context).copyWith(
          color: AppColors.textSecondary, 
          height: 1.5,
        );
        final span = TextSpan(
          text: widget.text,
          style: style,
        );
        final tp = TextPainter(
          text: span,
          maxLines: 4,
          textDirection: TextDirection.ltr,
        );
        tp.layout(maxWidth: constraints.maxWidth);
        
        _needsExpansion = tp.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: Text(
                widget.text,
                maxLines: _isExpanded ? null : 4,
                overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                style: style,
              ),
            ),
            if (_needsExpansion)
              GestureDetector(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                child: Padding(
                  padding: EdgeInsets.only(top: isCompact ? 8.h : 6.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isExpanded ? "SHOW LESS" : "SHOW MORE",
                        style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                          color: AppColors.crimson,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Icon(
                        _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        color: AppColors.crimson,
                        size: isCompact ? 16.r : 14.0,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
