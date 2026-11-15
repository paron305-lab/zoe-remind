import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Impormasyon ng phone para sa Zoe's Brain (channel: zoe/device).
/// Ginagamit para malaman kung kaya ng phone ang Zoe Plus.
/// null = hindi nalaman (hal. hindi Android) → hindi natin iba-block.
class DeviceMemory {
  DeviceMemory._();

  static const _channel = MethodChannel('zoe/device');

  static int? _totalRamMb;

  /// Kabuuang RAM ng phone sa MB. Hindi nagbabago, kaya isang beses lang kinukuha.
  /// Ang phone na "6 GB" ay mga 5400–5800 MB dito.
  static Future<int?> totalRamMb() async {
    final cached = _totalRamMb;
    if (cached != null) return cached;
    final value = await _read('totalRamMb');
    if (value != null) _totalRamMb = value;
    return value;
  }

  /// Free space sa app storage sa MB (nagbabago, kaya laging bagong basa).
  static Future<int?> freeStorageMb() => _read('freeStorageMb');

  static Future<int?> _read(String method) async {
    try {
      final value = await _channel.invokeMethod<int>(method);
      return (value == null || value <= 0) ? null : value;
    } catch (e) {
      debugPrint('[Device] $method failed: $e');
      return null;
    }
  }
}