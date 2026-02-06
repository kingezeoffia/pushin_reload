import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A widget that embeds a native iOS DeviceActivityReport view.
/// 
/// This view acts as a trigger for the DeviceActivityMonitorExtension.
/// Even if the view is 1x1 pixel, the presence of the DeviceActivityReport
/// in the view hierarchy causes the extension's `makeConfiguration` method to run,
/// which in turn collects the screen time data.
class ScreenTimeReportTrigger extends StatelessWidget {
  const ScreenTimeReportTrigger({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!Platform.isIOS) {
      return const SizedBox.shrink();
    }

    // Use a very small size, effectively invisible but still rendered
    return SizedBox(
      width: 1,
      height: 1,
      child: UiKitView(
        viewType: 'com.pushin.screentime_report',
        creationParams: const {},
        creationParamsCodec: const StandardMessageCodec(),
      ),
    );
  }
}
