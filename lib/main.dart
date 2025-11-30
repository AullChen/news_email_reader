import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'core/theme/app_theme.dart';
import 'core/services/storage_service.dart';
import 'core/providers/theme_provider.dart';
import 'features/home/presentation/pages/enhanced_home_page.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform, kDebugMode, debugPrint;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 性能优化：设置首选方向（如果需要）
  // await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  
  // 性能优化：优化图片缓存
  PaintingBinding.instance.imageCache.maximumSize = 100;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024; // 50MB
  
  // 禁用enough_mail库的调试输出
  if (kDebugMode) {
    // 启用分层日志记录
    hierarchicalLoggingEnabled = true;
    // 设置所有日志级别为SEVERE，只显示严重错误
    Logger.root.level = Level.SEVERE;
    // 禁用特定库的日志输出
    Logger('enough_mail').level = Level.OFF;
    Logger('imap').level = Level.OFF;
    Logger('pop3').level = Level.OFF;
    Logger('smtp').level = Level.OFF;
    Logger('mime').level = Level.OFF;
    Logger('html').level = Level.OFF;
    
    Logger.root.onRecord.listen((record) {
      // 只输出严重错误
      if (record.level >= Level.SEVERE) {
        debugPrint('${record.level.name}: ${record.message}');
      }
    });
  }
  
  final isDesktop = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
       defaultTargetPlatform == TargetPlatform.linux ||
       defaultTargetPlatform == TargetPlatform.macOS);
  if (isDesktop) {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
  }
  
  // Initialize Hive
  await Hive.initFlutter();
  
  // Initialize Storage Service
  await StorageService.instance.initialize();
  
  runApp(
    const ProviderScope(
      child: NewsEmailReaderApp(),
    ),
  );
}

class NewsEmailReaderApp extends ConsumerWidget {
  const NewsEmailReaderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    
    return MaterialApp(
      title: 'News Email Reader',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const EnhancedHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
