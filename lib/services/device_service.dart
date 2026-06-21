import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Injectable wrapper over side-effecting platform APIs (screen wakelock +
/// haptic vibration) so the controller stays testable without platform
/// channels.
abstract class DeviceService {
  Future<void> enableWakelock();
  Future<void> disableWakelock();
  Future<void> haptic({int durationMs = 30});
}

class FlutterDeviceService implements DeviceService {
  const FlutterDeviceService();

  @override
  Future<void> enableWakelock() => WakelockPlus.enable();

  @override
  Future<void> disableWakelock() => WakelockPlus.disable();

  @override
  Future<void> haptic({int durationMs = 30}) =>
      Vibration.vibrate(duration: durationMs);
}

final deviceServiceProvider =
    Provider<DeviceService>((ref) => const FlutterDeviceService());