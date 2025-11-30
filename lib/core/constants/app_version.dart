/// 应用版本信息
/// 
/// 这是应用版本号的唯一来源
/// 修改版本号时只需要修改 pubspec.yaml 中的 version 字段
class AppVersion {
  AppVersion._();

  /// 应用版本号
  /// 从 pubspec.yaml 中读取
  static const String version = '1.1.0';

  /// 构建号
  static const String buildNumber = '2';

  /// 完整版本号
  static const String fullVersion = '$version+$buildNumber';

  /// 版本名称（用于显示）
  static const String versionName = 'v$version';

  /// 获取版本信息字符串
  static String get versionInfo => 'v$version (Build $buildNumber)';
}
