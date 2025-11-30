/// 性能优化配置
class PerformanceConfig {
  PerformanceConfig._();

  // 列表性能配置
  static const int listPageSize = 20; // 每页加载数量
  static const double listCacheExtent = 2000; // 列表缓存范围（像素）
  static const int maxCachedItems = 100; // 最大缓存项目数

  // 图片缓存配置
  static const int imageCacheSize = 100; // 图片缓存数量
  static const int imageCacheSizeBytes = 50 * 1024 * 1024; // 50MB

  // 动画配置
  static const Duration shortAnimationDuration = Duration(milliseconds: 150);
  static const Duration mediumAnimationDuration = Duration(milliseconds: 250);
  static const Duration longAnimationDuration = Duration(milliseconds: 400);

  // 滚动配置
  static const double scrollLoadMoreThreshold = 300; // 距离底部多少像素触发加载
  static const Duration scrollDebounce = Duration(milliseconds: 100);

  // 数据库配置
  static const int databaseBatchSize = 50; // 批量操作大小
  static const Duration databaseCacheExpiration = Duration(minutes: 5);

  // 网络配置
  static const Duration networkTimeout = Duration(seconds: 30);
  static const int maxConcurrentRequests = 3;

  // UI 更新配置
  static const Duration uiUpdateDebounce = Duration(milliseconds: 200);
  static const int maxStateUpdatesPerSecond = 10;
}
