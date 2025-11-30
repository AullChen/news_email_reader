import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'permission_service.dart';

/// 图片保存服务
class ImageSaveService {
  static final ImageSaveService _instance = ImageSaveService._internal();
  factory ImageSaveService() => _instance;
  ImageSaveService._internal();

  final Dio _dio = Dio();
  final PermissionService _permissionService = PermissionService();

  /// 保存网络图片到相册
  Future<bool> saveImageFromUrl(String imageUrl) async {
    try {
      // 请求存储权限
      if (!await _permissionService.requestStoragePermission()) {
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
      if (!await _permissionService.requestStoragePermission()) {
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
      if (!await _permissionService.requestStoragePermission()) {
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

  /// 检查是否有存储权限
  Future<bool> hasPermission() async {
    return await _permissionService.hasStoragePermission();
  }

  /// 打开应用设置页面
  Future<void> openAppSettings() async {
    await _permissionService.openSettings();
  }
}
