import 'dart:async';
import 'package:flutter/foundation.dart';

/// 性能优化工具类
class PerformanceOptimizer {
  PerformanceOptimizer._();

  /// 防抖动 - 延迟执行，多次调用只执行最后一次
  static Timer? _debounceTimer;
  
  static void debounce(
    Duration duration,
    VoidCallback action,
  ) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(duration, action);
  }

  /// 节流 - 限制执行频率
  static DateTime? _lastThrottleTime;
  
  static void throttle(
    Duration duration,
    VoidCallback action,
  ) {
    final now = DateTime.now();
    if (_lastThrottleTime == null ||
        now.difference(_lastThrottleTime!) >= duration) {
      _lastThrottleTime = now;
      action();
    }
  }

  /// 批量操作 - 将多个操作合并为一次执行
  static final Map<String, List<Function>> _batchOperations = {};
  static final Map<String, Timer> _batchTimers = {};

  static void batch(
    String key,
    Function operation, {
    Duration delay = const Duration(milliseconds: 300),
  }) {
    _batchOperations[key] ??= [];
    _batchOperations[key]!.add(operation);

    _batchTimers[key]?.cancel();
    _batchTimers[key] = Timer(delay, () {
      final operations = _batchOperations[key];
      if (operations != null && operations.isNotEmpty) {
        for (final op in operations) {
          try {
            op();
          } catch (e) {
            debugPrint('批量操作执行失败: $e');
          }
        }
        _batchOperations[key]?.clear();
      }
    });
  }

  /// 异步批量操作
  static Future<void> batchAsync(
    String key,
    Future<void> Function() operation, {
    Duration delay = const Duration(milliseconds: 300),
  }) async {
    _batchTimers[key]?.cancel();
    _batchTimers[key] = Timer(delay, () async {
      try {
        await operation();
      } catch (e) {
        debugPrint('异步批量操作执行失败: $e');
      }
    });
  }

  /// 清理资源
  static void dispose() {
    _debounceTimer?.cancel();
    _batchTimers.values.forEach((timer) => timer.cancel());
    _batchTimers.clear();
    _batchOperations.clear();
  }
}

/// 内存缓存管理
class MemoryCache<K, V> {
  final Map<K, _CacheEntry<V>> _cache = {};
  final int maxSize;
  final Duration expiration;

  MemoryCache({
    this.maxSize = 100,
    this.expiration = const Duration(minutes: 30),
  });

  /// 获取缓存
  V? get(K key) {
    final entry = _cache[key];
    if (entry == null) return null;

    if (DateTime.now().difference(entry.timestamp) > expiration) {
      _cache.remove(key);
      return null;
    }

    return entry.value;
  }

  /// 设置缓存
  void set(K key, V value) {
    if (_cache.length >= maxSize) {
      _evictOldest();
    }

    _cache[key] = _CacheEntry(value, DateTime.now());
  }

  /// 移除缓存
  void remove(K key) {
    _cache.remove(key);
  }

  /// 清空缓存
  void clear() {
    _cache.clear();
  }

  /// 驱逐最旧的条目
  void _evictOldest() {
    if (_cache.isEmpty) return;

    K? oldestKey;
    DateTime? oldestTime;

    _cache.forEach((key, entry) {
      if (oldestTime == null || entry.timestamp.isBefore(oldestTime!)) {
        oldestKey = key;
        oldestTime = entry.timestamp;
      }
    });

    if (oldestKey != null) {
      _cache.remove(oldestKey);
    }
  }

  /// 获取缓存大小
  int get size => _cache.length;

  /// 是否包含键
  bool containsKey(K key) => _cache.containsKey(key);
}

class _CacheEntry<V> {
  final V value;
  final DateTime timestamp;

  _CacheEntry(this.value, this.timestamp);
}

/// 图片缓存优化
class ImageCacheOptimizer {
  ImageCacheOptimizer._();

  /// 优化图片缓存大小
  static void optimizeImageCache() {
    // 图片缓存优化已在 main.dart 中实现
    // 这里保留接口以保持兼容性
  }

  /// 清理图片缓存
  static void clearImageCache() {
    // 图片缓存清理已在 main.dart 中实现
    // 这里保留接口以保持兼容性
  }
}
