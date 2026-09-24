import 'package:flutter/material.dart';
import 'package:rugged/core/constants/dimensions.dart';

enum DeviceScreenType { mobile, tablet, desktop }

class ResponsiveLayout extends StatelessWidget {
  final Widget mobileBody;
  final Widget? tabletBody;
  final Widget desktopBody;

  const ResponsiveLayout({
    super.key,
    required this.mobileBody,
    this.tabletBody,
    required this.desktopBody,
  });

  static DeviceScreenType getDeviceType(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    if (width < kMobileBreakpoint) return DeviceScreenType.mobile;
    if (width < kDesktopBreakpoint) return DeviceScreenType.tablet;
    return DeviceScreenType.desktop;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < kMobileBreakpoint) {
          return mobileBody;
        } else if (constraints.maxWidth < kDesktopBreakpoint) {
          return tabletBody ?? desktopBody;
        } else {
          return desktopBody;
        }
      },
    );
  }
}
