import 'package:workmanager/workmanager.dart';

/// Cleans up old local background tasks.
/// Firebase Functions handles all notification schedules.
class BackgroundService {
  /// Cancels local Workmanager tasks left from older app versions.
  static Future<void> cancelAll() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );

    await Workmanager().cancelAll();
  }
}

/// Empty callback required only to initialize Workmanager before cancellation.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('Background task ignored: $task');
    return Future.value(true);
  });
}
