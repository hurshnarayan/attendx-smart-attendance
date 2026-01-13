import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceService {
  static final DeviceService _instance = DeviceService._internal();
  factory DeviceService() => _instance;
  DeviceService._internal();

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  String? _cachedDeviceHash;

  Future<String> getDeviceHash() async {
    if (_cachedDeviceHash != null) return _cachedDeviceHash!;

    try {
      String deviceId = '';
      
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        deviceId = '${androidInfo.id}-${androidInfo.fingerprint}-${androidInfo.hardware}';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        deviceId = '${iosInfo.identifierForVendor}-${iosInfo.model}-${iosInfo.systemVersion}';
      } else {
        // Fallback for other platforms
        deviceId = DateTime.now().millisecondsSinceEpoch.toString();
      }

      // Create SHA256 hash
      final bytes = utf8.encode(deviceId);
      final hash = sha256.convert(bytes);
      _cachedDeviceHash = hash.toString();
      
      return _cachedDeviceHash!;
    } catch (e) {
      // Fallback: use stored hash or generate new one
      final prefs = await SharedPreferences.getInstance();
      String? storedHash = prefs.getString('device_hash');
      
      if (storedHash == null) {
        final bytes = utf8.encode('fallback-${DateTime.now().millisecondsSinceEpoch}');
        storedHash = sha256.convert(bytes).toString();
        await prefs.setString('device_hash', storedHash);
      }
      
      _cachedDeviceHash = storedHash;
      return _cachedDeviceHash!;
    }
  }

  Future<Map<String, String>> getDeviceInfo() async {
    try {
      if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        return {
          'platform': 'Android',
          'model': info.model,
          'manufacturer': info.manufacturer,
          'version': info.version.release,
        };
      } else if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        return {
          'platform': 'iOS',
          'model': info.model,
          'name': info.name,
          'version': info.systemVersion,
        };
      }
    } catch (e) {
      // Ignore
    }
    return {'platform': 'Unknown'};
  }
}
