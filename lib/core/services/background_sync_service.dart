import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import '../models/email_account.dart';
import '../models/email_message.dart';
import 'email_service.dart';
import 'whitelist_service.dart';

/// 后台邮件同步服务 - 使用 Isolate 实现多线程同步
class BackgroundSyncService {
  static final BackgroundSyncService _instance = BackgroundSyncService._internal();
  factory BackgroundSyncService() => _instance;
  BackgroundSyncService._internal();

  Isolate? _syncIsolate;
  ReceivePort? _receivePort;
  SendPort? _sendPort;
  bool _isInitialized = false;
  bool _isSyncing = false;

  /// 同步进度回调
  Function(int current, int total, String accountName)? onProgress;
  
  /// 同步完成回调
  Function(List<EmailMessage> emails)? onComplete;
  
  /// 同步错误回调
  Function(String error)? onError;

  /// 初始化后台同步服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    _receivePort = ReceivePort();
    
    _receivePort!.listen((message) {
      if (message is SendPort) {
        _sendPort = message;
        _isInitialized = true;
      } else if (message is Map) {
        _handleMessage(message);
      }
    });

    _syncIsolate = await Isolate.spawn(
      _syncIsolateEntry,
      _receivePort!.sendPort,
    );
  }

  /// Isolate 入口函数
  static void _syncIsolateEntry(SendPort mainSendPort) {
    final receivePort = ReceivePort();
    mainSendPort.send(receivePort.sendPort);

    receivePort.listen((message) async {
      if (message is Map && message['action'] == 'sync') {
        try {
          final accounts = message['accounts'] as List<EmailAccount>;
          final syncQuantity = message['syncQuantity'] as int;
          final syncTimeRange = message['syncTimeRange'] as int;
          
          await _performSync(
            accounts,
            syncQuantity,
            syncTimeRange,
            mainSendPort,
          );
        } catch (e) {
          mainSendPort.send({
            'type': 'error',
            'error': e.toString(),
          });
        }
      }
    });
  }

  /// 执行同步操作
  static Future<void> _performSync(
    List<EmailAccount> accounts,
    int syncQuantity,
    int syncTimeRange,
    SendPort mainSendPort,
  ) async {
    final emailService = EmailService();
    final whitelistService = WhitelistService();
    final allEmails = <EmailMessage>[];

    for (int i = 0; i < accounts.length; i++) {
      final account = accounts[i];
      
      // 发送进度更新
      mainSendPort.send({
        'type': 'progress',
        'current': i,
        'total': accounts.length,
        'accountName': account.displayName ?? account.email,
      });

      try {
        // 获取邮件
        final fetchCount = syncQuantity == 0 ? 2000 : syncQuantity;
        final serverEmails = await emailService.fetchRecentEmails(
          account,
          count: fetchCount,
        );

        // 时间筛选
        List<EmailMessage> timeFilteredEmails = serverEmails;
        if (syncTimeRange > 0) {
          final cutoffDate = DateTime.now().subtract(Duration(days: syncTimeRange));
          timeFilteredEmails = serverEmails.where((email) => 
            email.receivedDate.isAfter(cutoffDate)
          ).toList();
        }

        // 白名单筛选
        final filteredEmails = await whitelistService.filterEmails(timeFilteredEmails);
        allEmails.addAll(filteredEmails);
      } catch (e) {
        mainSendPort.send({
          'type': 'account_error',
          'accountName': account.displayName ?? account.email,
          'error': e.toString(),
        });
      }
    }

    // 发送完成消息
    mainSendPort.send({
      'type': 'complete',
      'emails': allEmails.map((e) => e.toJson()).toList(),
    });
  }

  /// 处理来自 Isolate 的消息
  void _handleMessage(Map message) {
    final type = message['type'];
    
    switch (type) {
      case 'progress':
        if (onProgress != null) {
          onProgress!(
            message['current'] as int,
            message['total'] as int,
            message['accountName'] as String,
          );
        }
        break;
        
      case 'complete':
        _isSyncing = false;
        if (onComplete != null) {
          final emailsJson = message['emails'] as List;
          final emails = emailsJson
              .map((json) => EmailMessage.fromJson(Map<String, dynamic>.from(json)))
              .toList();
          onComplete!(emails);
        }
        break;
        
      case 'error':
      case 'account_error':
        if (onError != null) {
          final error = message['error'] as String;
          final accountName = message['accountName'] as String?;
          onError!(accountName != null ? '$accountName: $error' : error);
        }
        break;
    }
  }

  /// 开始同步
  Future<void> startSync(
    List<EmailAccount> accounts,
    int syncQuantity,
    int syncTimeRange,
  ) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_isSyncing) {
      debugPrint('同步已在进行中');
      return;
    }

    _isSyncing = true;
    _sendPort?.send({
      'action': 'sync',
      'accounts': accounts,
      'syncQuantity': syncQuantity,
      'syncTimeRange': syncTimeRange,
    });
  }

  /// 是否正在同步
  bool get isSyncing => _isSyncing;

  /// 清理资源
  void dispose() {
    _syncIsolate?.kill(priority: Isolate.immediate);
    _receivePort?.close();
    _isInitialized = false;
    _isSyncing = false;
  }
}
