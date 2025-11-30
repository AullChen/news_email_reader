import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';

/// 图片保存服务
class ImageSaveService {
  static final ImageSaveService _instance = ImageSaveService._internal();
  factory ImageSaveService() => _instance;
  ImageSaveService._internal();

  final Dio _dio = Dio();

  /// 保存网络图片到相册
  Future<bool> saveImageFromUrl(String imageUrl) async {
    try {
      // 请求存储权限
      if (!await _requestPermission()) {
        debugPrint('存储权限被拒绝');
        return false;
      }

      // 下载图片
      final response = await _dio.get(
        imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode == 200) {
        final Uint8List bytes = Uint8List.fromList(response.data);
        
        // 保存到相册
        final result = await ImageGallerySaver.saveImage(
          bytes,
          quality: 100,
          name: 'email_image_${DateTime.now().millisecondsSinceEpoch}',
        );

        return result['isSuccess'] == true;
      }

      return false;
    } catch (e) {
      debugPrint('保存图片失败: $e');
      return false;
    }
  }

  /// 保存本地图片到相册
  Future<bool> saveImageFromFile(File imageFile) async {
    try {
      // 请求存储权限
      if (!await _requestPermission()) {
        debugPrint('存储权限被拒绝');
        return false;
      }

      final bytes = await imageFile.readAsBytes();
      
      // 保存到相册
      final result = await ImageGallerySaver.saveImage(
        bytes,
        quality: 100,
        name: 'email_image_${DateTime.now().millisecondsSinceEpoch}',
      );

      return result['isSuccess'] == true;
    } catch (e) {
      debugPrint('保存图片失败: $e');
      return false;
    }
  }

  /// 保存图片字节数据到相册
  Future<bool> saveImageFromBytes(Uint8List bytes) async {
    try {
      // 请求存储权限
      if (!await _requestPermission()) {
        debugPrint('存储权限被拒绝');
        return false;
      }

      // 保存到相册
      final result = await ImageGallerySaver.saveImage(
        bytes,
        quality: 100,
        name: 'email_image_${DateTime.now().millisecondsSinceEpoch}',
      );

      return result['isSuccess'] == true;
    } catch (e) {
      debugPrint('保存图片失败: $e');
      return false;
    }
  }

  /// 下载图片到应用目录
  Future<String?> downloadImageToAppDir(String imageUrl) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'email_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '${appDir.path}/$fileName';

      await _dio.download(imageUrl, filePath);

      return filePath;
    } catch (e) {
      debugPrint('下载图片失败: $e');
      return null;
    }
  }

  /// 请求存储权限
  Future<bool> _requestPermission() async {
    if (Platform.isAndroid) {
      // Android 13+ 使用新的权限模型
      if (await Permission.photos.isGranted) {
        return true;
      }
      
      final status = await Permission.photos.request();
      if (status.isGranted) {
        return true;
      }

      // 尝试旧的存储权限（Android 12 及以下）
      if (await Permission.storage.isGranted) {
        return true;
      }
      
      final storageStatus = await Permission.storage.request();
      return storageStatus.isGranted;
    } else if (Platform.isIOS) {
      if (await Permission.photos.isGranted) {
        return true;
      }
      
      final status = await Permission.photos.request();
      return status.isGranted;
    }

    // 其他平台默认允许
    return true;
  }

  /// 检查是否有存储权限
  Future<bool> hasPermission() async {
    if (Platform.isAndroid) {
      return await Permission.photos.isGranted || 
             await Permission.storage.isGranted;
    } else if (Platform.isIOS) {
      return await Permission.photos.isGranted;
    }
    return true;
  }

  /// 打开应用设置页面
  Future<void> openAppSettings() async {
    await openAppSettings();
  }
}
