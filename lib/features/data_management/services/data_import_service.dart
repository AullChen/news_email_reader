import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../core/models/email_message.dart';
import '../../../core/repositories/email_repository.dart';

class DataImportService {
  final EmailRepository _emailRepository = EmailRepository();

  /// 导入邮件数据
  Future<ImportResult> importEmails(File file) async {
    try {
      final jsonString = await file.readAsString();
      final jsonData = jsonDecode(jsonString);

      int successCount = 0;
      int failCount = 0;
      final errors = <String>[];

      // 判断是完整数据包还是单独的邮件数据
      List<dynamic> emailsData;
      if (jsonData is Map && jsonData.containsKey('emails')) {
        // 完整数据包
        emailsData = jsonData['emails'] as List<dynamic>;
      } else if (jsonData is List) {
        // 单独的邮件数据
        emailsData = jsonData;
      } else {
        throw Exception('不支持的数据格式');
      }

      for (final emailData in emailsData) {
        try {
          final email = EmailMessage(
            messageId: emailData['messageId'] ?? '',
            subject: emailData['subject'] ?? '',
            senderName: emailData['senderName'],
            senderEmail: emailData['senderEmail'] ?? '',
            receivedDate: DateTime.parse(emailData['receivedDate']),
            contentText: emailData['contentText'],
            contentHtml: emailData['contentHtml'],
            isRead: emailData['isRead'] ?? false,
            isStarred: emailData['isStarred'] ?? false,
            isArchived: emailData['isArchived'] ?? false,
            notes: emailData['notes'],
            aiSummary: emailData['aiSummary'],
            accountId: 0, // 需要重新关联账户
            createdAt: emailData['createdAt'] != null 
                ? DateTime.parse(emailData['createdAt'])
                : DateTime.now(),
          );

          await _emailRepository.saveEmail(email);
          successCount++;
        } catch (e) {
          failCount++;
          errors.add('导入邮件失败: ${emailData['subject'] ?? 'Unknown'} - $e');
          debugPrint('导入邮件失败: $e');
        }
      }

      return ImportResult(
        success: true,
        totalCount: emailsData.length,
        successCount: successCount,
        failCount: failCount,
        errors: errors,
      );
    } catch (e) {
      return ImportResult(
        success: false,
        totalCount: 0,
        successCount: 0,
        failCount: 0,
        errors: ['导入失败: $e'],
      );
    }
  }

  /// 导入笔记数据
  Future<ImportResult> importNotes(File file) async {
    try {
      final jsonString = await file.readAsString();
      final jsonData = jsonDecode(jsonString) as List<dynamic>;

      int successCount = 0;
      int failCount = 0;
      final errors = <String>[];

      for (final noteData in jsonData) {
        try {
          final messageId = noteData['messageId'] as String;
          final notes = noteData['notes'] as String?;

          if (notes != null && notes.isNotEmpty) {
            // 查找邮件并更新笔记
            final email = await _emailRepository.getEmailContent(messageId);
            if (email != null) {
              final updatedEmail = email.copyWith(notes: notes);
              await _emailRepository.updateEmail(updatedEmail);
              successCount++;
            } else {
              failCount++;
              errors.add('邮件不存在: $messageId');
            }
          }
        } catch (e) {
          failCount++;
          errors.add('导入笔记失败: $e');
          debugPrint('导入笔记失败: $e');
        }
      }

      return ImportResult(
        success: true,
        totalCount: jsonData.length,
        successCount: successCount,
        failCount: failCount,
        errors: errors,
      );
    } catch (e) {
      return ImportResult(
        success: false,
        totalCount: 0,
        successCount: 0,
        failCount: 0,
        errors: ['导入失败: $e'],
      );
    }
  }
}

class ImportResult {
  final bool success;
  final int totalCount;
  final int successCount;
  final int failCount;
  final List<String> errors;

  ImportResult({
    required this.success,
    required this.totalCount,
    required this.successCount,
    required this.failCount,
    required this.errors,
  });

  String get summary {
    if (!success) {
      return '导入失败: ${errors.first}';
    }
    return '成功导入 $successCount/$totalCount 项${failCount > 0 ? '，失败 $failCount 项' : ''}';
  }
}
