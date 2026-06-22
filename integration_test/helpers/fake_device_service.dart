import 'package:retrometer/services/device_service.dart';

/// No-op [DeviceService] for integration tests — keeps wakelock/vibration off
/// the platform channels so the suite runs headlessly.
class FakeDeviceService implements DeviceService {
  int enableCalls = 0;
  int disableCalls = 0;
  int hapticCalls = 0;

  @override
  Future<void> enableWakelock() async => enableCalls++;

  @override
  Future<void> disableWakelock() async => disableCalls++;

  @override
  Future<void> haptic({int durationMs = 30}) async => hapticCalls++;
}