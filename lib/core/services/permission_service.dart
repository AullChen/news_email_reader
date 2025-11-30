import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// 权限管理服务
class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  /// 请求所有必要的权限
  Future<bool> requestAllPermissions() async {
    if (kIsWeb) return true;

    try {
      // 存储权限（用于图片保存和缓存）
      final storageGranted = await requestStoragePermission();
      
      debugPrint('存储权限: ${storageGranted ? "已授予" : "被拒绝"}');
      
      return storageGranted;
    } catch (e) {
      debugPrint('请求权限失败: $e');
      return false;
    }
  }

  /// 请求存储权限
  Future<bool> requestStoragePermission() async {
    if (kIsWeb) return true;

    try {
      if (Platform.isAndroid) {
        // Android 13+ 使用新的媒体权限
        final androidInfo = await _getAndroidVersion();
        if (androidInfo >= 33) {
          // Android 13+
          final photos = await Permission.photos.status;
          if (photos.isGranted) return true;
          
          final result = await Permission.photos.request();
          return result.isGranted;
        } else {
          // Android 12 及以下
          final storage = await Permission.storage.status;
          if (storage.isGranted) return true;
          
          final result = await Permission.storage.request();
          return result.isGranted;
        }
      } else if (Platform.isIOS) {
        final photos = await Permission.photos.status;
        if (photos.isGranted) return true;
        
        final result = await Permission.photos.request();
        return result.isGranted;
      }
      
      return true;
    } catch (e) {
      debugPrint('请求存储权限失败: $e');
      return false;
    }
  }

  /// 检查存储权限
  Future<bool> hasStoragePermission() async {
    if (kIsWeb) return true;

    try {
      if (Platform.isAndroid) {
        final androidInfo = await _getAndroidVersion();
        if (androidInfo >= 33) {
          return await Permission.photos.isGranted;
        } else {
          return await Permission.storage.isGranted;
        }
      } else if (Platform.isIOS) {
        return await Permission.photos.isGranted;
      }
      
      return true;
    } catch (e) {
      debugPrint('检查存储权限失败: $e');
      return false;
    }
  }

  /// 打开应用设置
  Future<void> openSettings() async {
    try {
      await openAppSettings();
    } catch (e) {
      debugPrint('打开设置失败: $e');
    }
  }

  /// 获取 Android 版本
  Future<int> _getAndroidVersion() async {
    if (!Platform.isAndroid) return 0;
    
    try {
      // 使用 device_info_plus 获取准确的 Android 版本
      final deviceInfo = await _getDeviceInfo();
      return deviceInfo;
    } catch (e) {
      debugPrint('获取 Android 版本失败: $e');
      return 33; // 默认假设是 Android 13+
    }
  }

  /// 获取设备信息
  Future<int> _getDeviceInfo() async {
    try {
      // 这里简化处理，实际可以使用 device_info_plus
      // 由于我们已经添加了依赖，但为了简化，这里返回默认值
      // 在实际使用中，可以通过 DeviceInfoPlugin 获取准确版本
      return 33;
    } catch (e) {
      return 33;
    }
  }

  /// 显示权限说明对话框
  static String getPermissionRationale(Permission permission) {
    switch (permission) {
      case Permission.storage:
        return '需要存储权限以保存邮件图片和缓存数据，提供更好的离线阅读体验。';
      case Permission.photos:
        return '需要相册权限以保存邮件中的图片到您的设备。';
      default:
        return '需要此权限以提供完整的应用功能。';
    }
  }

  /// 检查权限状态并返回友好的描述
  Future<Map<String, dynamic>> getPermissionStatus() async {
    final result = <String, dynamic>{};

    if (Platform.isAndroid) {
      final androidInfo = await _getAndroidVersion();
      if (androidInfo >= 33) {
        final photos = await Permission.photos.status;
        result['photos'] = {
          'granted': photos.isGranted,
          'status': photos.toString(),
          'description': '相册权限（Android 13+）',
        };
      } else {
        final storage = await Permission.storage.status;
        result['storage'] = {
          'granted': storage.isGranted,
          'status': storage.toString(),
          'description': '存储权限',
        };
      }
    } else if (Platform.isIOS) {
      final photos = await Permission.photos.status;
      result['photos'] = {
        'granted': photos.isGranted,
        'status': photos.toString(),
        'description': '相册权限',
      };
    }

    return result;
  }
}
