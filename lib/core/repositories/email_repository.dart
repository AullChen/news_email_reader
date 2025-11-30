import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../models/email_message.dart';
import '../models/email_account.dart';
import '../services/storage_service.dart';
import '../services/email_service.dart';
import '../services/whitelist_service.dart';
import '../services/settings_service.dart';

class EmailRepository {
  static final EmailRepository _instance = EmailRepository._internal();
  factory EmailRepository() => _instance;
  EmailRepository._internal();

  final StorageService _storage = StorageService.instance;
  final EmailService _emailService = EmailService();
  final WhitelistService _whitelistService = WhitelistService();
  final SettingsService _settingsService = SettingsService();

  /// 保存邮件到本地存储
  Future<void> saveEmail(EmailMessage email) async {
    await _storage.saveEmail(email);
  }

  /// 批量保存邮件
  Future<void> saveEmails(List<EmailMessage> emails) async {
    for (final email in emails) {
      await _storage.saveEmail(email);
    }
  }

  /// 从本地存储获取邮件列表
  Future<List<EmailMessage>> getLocalEmails({
    int? accountId,
    int? limit,
    int offset = 0,
    bool? isRead,
    bool? isStarred,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    List<EmailMessage> emails = await _storage.getAllEmails();
    
    // 应用筛选条件
    if (accountId != null) {
      emails = emails.where((email) => email.accountId == accountId).toList();
    }
    
    if (isRead != null) {
      emails = emails.where((email) => email.isRead == isRead).toList();
    }
    
    if (isStarred != null) {
      emails = emails.where((email) => email.isStarred == isStarred).toList();
    }
    
    if (startDate != null) {
      emails = emails.where((email) => email.receivedDate.isAfter(startDate) || email.receivedDate.isAtSameMomentAs(startDate)).toList();
    }
    
    if (endDate != null) {
      emails = emails.where((email) => email.receivedDate.isBefore(endDate) || email.receivedDate.isAtSameMomentAs(endDate)).toList();
    }
    
    // 按接收时间降序排序
    emails.sort((a, b) => b.receivedDate.compareTo(a.receivedDate));
    
    // 应用分页
    if (offset > 0) {
      emails = emails.skip(offset).toList();
    }
    if (limit != null && limit > 0 && emails.length > limit) {
      emails = emails.take(limit).toList();
    }
    
    return emails;
  }

  /// 同步邮件（从服务器获取并筛选）
  Future<List<EmailMessage>> syncEmails(EmailAccount account, {bool forceRefresh = false}) async {
    try {
      debugPrint('开始同步邮件...');
      
      // 获取本地已有邮件，建立用户数据映射（收藏、笔记、已读状态等）
      final existingEmails = await _storage.getAllEmails();
      final userDataMap = <String, EmailMessage>{};
      
      // 只保留有用户操作的邮件数据
      for (final email in existingEmails) {
        if (email.isStarred || 
            (email.notes != null && email.notes!.isNotEmpty) || 
            email.isRead ||
            (email.aiSummary != null && email.aiSummary!.isNotEmpty)) {
          userDataMap[email.messageId] = email;
        }
      }
      
      debugPrint('保留 ${userDataMap.length} 封邮件的用户数据');
      
      // 根据设置获取同步配置
      final syncQuantity = await _settingsService.getSyncQuantity();
      final syncTimeRange = await _settingsService.getSyncTimeRange();
      
      // 从邮件服务器获取邮件（按账户协议与配置）
      final fetchCount = syncQuantity == 0 ? 2000 : syncQuantity; // 0表示全部，设置一个较大的数值
      final serverEmails = await _emailService.fetchRecentEmails(account, count: fetchCount);
      debugPrint('从服务器获取到 ${serverEmails.length} 封邮件');
      
      // 根据时间范围筛选邮件
      List<EmailMessage> timeFilteredEmails = serverEmails;
      if (syncTimeRange > 0) {
        final cutoffDate = DateTime.now().subtract(Duration(days: syncTimeRange));
        timeFilteredEmails = serverEmails.where((email) => 
          email.receivedDate.isAfter(cutoffDate)
        ).toList();
        debugPrint('时间筛选后剩余 ${timeFilteredEmails.length} 封邮件');
      }

      // 先通过白名单筛选
      final whitelistFilteredEmails = await _whitelistService.filterEmails(timeFilteredEmails);
      debugPrint('白名单筛选后剩余 ${whitelistFilteredEmails.length} 封邮件');

      // 找出被白名单过滤掉但有用户操作的邮件
      final filteredOutEmails = timeFilteredEmails.where((email) => 
        !whitelistFilteredEmails.any((filtered) => filtered.messageId == email.messageId)
      ).toList();
      
      final importantFilteredOutEmails = filteredOutEmails.where((email) {
        final userData = userDataMap[email.messageId];
        return userData != null && (userData.isStarred || 
               (userData.notes != null && userData.notes!.isNotEmpty));
      }).toList();
      
      debugPrint('找到 ${importantFilteredOutEmails.length} 封被过滤但有用户操作的重要邮件');

      // 合并白名单通过的邮件和重要的被过滤邮件
      final allValidEmails = [...whitelistFilteredEmails, ...importantFilteredOutEmails];
      debugPrint('最终处理 ${allValidEmails.length} 封邮件');

      // 合并服务器邮件和用户数据
      final finalEmails = <EmailMessage>[];
      for (final serverEmail in allValidEmails) {
        final userData = userDataMap[serverEmail.messageId];
        if (userData != null) {
          // 合并：服务器内容 + 用户数据
          final mergedEmail = serverEmail.copyWith(
            isRead: userData.isRead,
            isStarred: userData.isStarred,
            aiSummary: userData.aiSummary,
            notes: userData.notes,
            createdAt: userData.createdAt, // 保留原创建时间
          );
          finalEmails.add(mergedEmail);
        } else {
          // 新邮件，使用服务器数据
          finalEmails.add(serverEmail);
        }
      }
      
      // 清空本地存储，重新保存所有邮件
      await _storage.clearEmailCache();
      await _storage.saveEmails(finalEmails);
      
      debugPrint('同步完成，共保存 ${finalEmails.length} 封邮件');
      return finalEmails;
    } catch (e) {
      debugPrint('同步邮件失败: $e');
      rethrow;
    }
  }

  /// 获取邮件详细内容
  Future<EmailMessage?> getEmailContent(String emailId) async {
    return await _storage.getEmailById(emailId);
  }

  /// 更新邮件状态
  Future<void> updateEmailStatus(
    String emailId, {
    bool? isRead,
    bool? isStarred,
    bool? isArchived,
    String? aiSummary,
    double? readingProgress,
  }) async {
    final email = await _storage.getEmailById(emailId);
    if (email == null) return;
    
    final updatedEmail = email.copyWith(
      isRead: isRead ?? email.isRead,
      isStarred: isStarred ?? email.isStarred,
      isArchived: isArchived ?? email.isArchived,
      aiSummary: aiSummary ?? email.aiSummary,
      readingProgress: readingProgress ?? email.readingProgress,
    );
    
    await _storage.updateEmail(updatedEmail);
  }

  /// 归档邮件
  Future<void> archiveEmail(String emailId) async {
    await updateEmailStatus(emailId, isArchived: true);
  }

  /// 取消归档邮件
  Future<void> unarchiveEmail(String emailId) async {
    await updateEmailStatus(emailId, isArchived: false);
  }

  /// 更新阅读进度
  Future<void> updateReadingProgress(String emailId, double progress) async {
    await updateEmailStatus(emailId, readingProgress: progress);
  }

  /// 获取已归档的邮件
  Future<List<EmailMessage>> getArchivedEmails() async {
    final emails = await _storage.getAllEmails();
    return emails.where((e) => e.isArchived).toList()
      ..sort((a, b) => b.receivedDate.compareTo(a.receivedDate));
  }

  /// 获取未归档的邮件
  Future<List<EmailMessage>> getUnarchivedEmails() async {
    final emails = await _storage.getAllEmails();
    return emails.where((e) => !e.isArchived).toList()
      ..sort((a, b) => b.receivedDate.compareTo(a.receivedDate));
  }

  /// 更新邮件
  Future<void> updateEmail(EmailMessage email) async {
    await _storage.updateEmail(email);
  }

  /// 搜索邮件
  Future<List<EmailMessage>> searchEmails(
    String query, {
    int? accountId,
    int? limit,
  }) async {
    List<EmailMessage> emails = await _storage.getAllEmails();
    
    // 应用账户筛选
    if (accountId != null) {
      emails = emails.where((email) => email.accountId == accountId).toList();
    }
    
    // 搜索匹配
    final lowerQuery = query.toLowerCase();
    emails = emails.where((email) {
      return email.subject.toLowerCase().contains(lowerQuery) ||
             (email.senderName?.toLowerCase().contains(lowerQuery) ?? false) ||
             email.senderEmail.toLowerCase().contains(lowerQuery) ||
             (email.contentText?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
    
    // 按接收时间降序排序
    emails.sort((a, b) => b.receivedDate.compareTo(a.receivedDate));
    
    // 应用限制
    if (limit != null && limit > 0 && emails.length > limit) {
      emails = emails.take(limit).toList();
    }
    
    return emails;
  }

  /// 获取今日邮件
  Future<List<EmailMessage>> getTodayEmails({int? accountId}) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    return await getLocalEmails(
      accountId: accountId,
      startDate: startOfDay,
      endDate: endOfDay,
    );
  }

  /// 获取本周邮件
  Future<List<EmailMessage>> getWeekEmails({int? accountId}) async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeekDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    
    return await getLocalEmails(
      accountId: accountId,
      startDate: startOfWeekDay,
    );
  }

  /// 获取已总结的邮件
  Future<List<EmailMessage>> getSummarizedEmails({int? accountId}) async {
    List<EmailMessage> emails = await _storage.getAllEmails();
    
    // 筛选有AI总结的邮件
    emails = emails.where((email) => 
      email.aiSummary != null && email.aiSummary!.isNotEmpty
    ).toList();
    
    // 应用账户筛选
    if (accountId != null) {
      emails = emails.where((email) => email.accountId == accountId).toList();
    }
    
    // 按接收时间降序排序
    emails.sort((a, b) => b.receivedDate.compareTo(a.receivedDate));
    
    return emails;
  }

  /// 删除邮件
  Future<void> deleteEmail(String emailId) async {
    await _storage.deleteEmail(emailId);
  }

  /// 清理过期邮件（保留最近30天）
  Future<int> cleanupOldEmails() async {
    final emails = await _storage.getAllEmails();
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    
    int deletedCount = 0;
    for (final email in emails) {
      if (email.receivedDate.isBefore(thirtyDaysAgo) && !email.isStarred) {
        await _storage.deleteEmail(email.messageId);
        deletedCount++;
      }
    }
    
    return deletedCount;
  }

  /// 获取收藏的邮件
  Future<List<EmailMessage>> getStarredEmails() async {
    return await _storage.getFavoriteEmails();
  }

  /// 获取收藏的邮件（别名方法）
  Future<List<EmailMessage>> getFavoriteEmails() async {
    return await getStarredEmails();
  }

  /// 获取有笔记的邮件
  Future<List<EmailMessage>> getEmailsWithNotes() async {
    return await _storage.getEmailsWithNotes();
  }
}

// Provider for EmailRepository
final emailRepositoryProvider = Provider<EmailRepository>((ref) {
  return EmailRepository();
});