import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/repositories/email_repository.dart';
import '../../../../core/models/email_message.dart';
import '../../services/data_import_service.dart';
import 'statistics_page.dart';
import 'deduplication_page.dart';

class DataManagementPage extends StatefulWidget {
  const DataManagementPage({super.key});

  @override
  State<DataManagementPage> createState() => _DataManagementPageState();
}

class _DataManagementPageState extends State<DataManagementPage> {
  final EmailRepository _emailRepository = EmailRepository();
  
  // 统计数据
  int _totalEmails = 0;
  int _unreadEmails = 0;
  int _starredEmails = 0;
  int _emailsWithNotes = 0;
  int _archivedEmails = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() => _isLoading = true);
    
    try {
      final allEmails = await _emailRepository.getLocalEmails(limit: 10000);
      final archivedEmails = await _emailRepository.getArchivedEmails();
      
      setState(() {
        _totalEmails = allEmails.length;
        _unreadEmails = allEmails.where((e) => !e.isRead).length;
        _starredEmails = allEmails.where((e) => e.isStarred).length;
        _emailsWithNotes = allEmails.where((e) => e.notes != null && e.notes!.isNotEmpty).length;
        _archivedEmails = archivedEmails.length;
      });
    } catch (e) {
      debugPrint('加载统计数据失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('数据管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStatistics,
            tooltip: '刷新统计',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStatistics,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildStatisticsSection(),
                  const SizedBox(height: 24),
                  _buildQuickActionsSection(),
                  const SizedBox(height: 24),
                  _buildExportSection(),
                  const SizedBox(height: 24),
                  _buildImportSection(),
                  const SizedBox(height: 24),
                  _buildDeduplicationSection(),
                  const SizedBox(height: 24),
                  _buildCleanupSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatisticsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.bar_chart, color: AppTheme.primaryColor),
                SizedBox(width: 8),
                Text(
                  '数据统计',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatItem(Icons.email, '总邮件数', _totalEmails.toString()),
            _buildStatItem(Icons.mark_email_unread, '未读邮件', _unreadEmails.toString()),
            _buildStatItem(Icons.star, '收藏邮件', _starredEmails.toString()),
            _buildStatItem(Icons.note, '带笔记邮件', _emailsWithNotes.toString()),
            _buildStatItem(Icons.archive, '已归档邮件', _archivedEmails.toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.textSecondaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 15),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.dashboard, color: AppTheme.primaryColor),
                SizedBox(width: 8),
                Text(
                  '快捷功能',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionButton(
                    icon: Icons.bar_chart,
                    label: '数据统计',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StatisticsPage(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionButton(
                    icon: Icons.content_copy,
                    label: '邮件去重',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DeduplicationPage(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.file_download, color: AppTheme.primaryColor),
                SizedBox(width: 8),
                Text(
                  '数据导出',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('导出邮件数据'),
              subtitle: Text('导出 $_totalEmails 封邮件'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _exportEmails,
            ),
            ListTile(
              leading: const Icon(Icons.note_outlined),
              title: const Text('导出笔记数据'),
              subtitle: Text('导出 $_emailsWithNotes 条笔记'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _exportNotes,
            ),
            ListTile(
              leading: const Icon(Icons.folder_zip),
              title: const Text('导出完整数据包'),
              subtitle: const Text('包含所有邮件和笔记'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _exportAll,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.file_upload, color: AppTheme.primaryColor),
                SizedBox(width: 8),
                Text(
                  '数据导入',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('导入邮件数据'),
              subtitle: const Text('从 JSON 文件导入邮件'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _importEmails,
            ),
            ListTile(
              leading: const Icon(Icons.note_outlined),
              title: const Text('导入笔记数据'),
              subtitle: const Text('从 JSON 文件导入笔记'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _importNotes,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeduplicationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.content_copy, color: AppTheme.primaryColor),
                SizedBox(width: 8),
                Text(
                  '邮件去重',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('检测重复邮件'),
              subtitle: const Text('扫描并标记重复的邮件'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _detectDuplicates,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCleanupSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.cleaning_services, color: AppTheme.primaryColor),
                SizedBox(width: 8),
                Text(
                  '数据清理',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.delete_sweep),
              title: const Text('清理已归档邮件'),
              subtitle: Text('清理 $_archivedEmails 封已归档邮件'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _cleanupArchived,
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('清理旧邮件'),
              subtitle: const Text('删除超过指定天数的邮件'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _cleanupOldEmails,
            ),
          ],
        ),
      ),
    );
  }

  // 导出邮件数据
  Future<void> _exportEmails() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final emails = await _emailRepository.getLocalEmails(limit: 10000);
      final jsonData = emails.map((e) => {
        'messageId': e.messageId,
        'subject': e.subject,
        'senderName': e.senderName,
        'senderEmail': e.senderEmail,
        'receivedDate': e.receivedDate.toIso8601String(),
        'contentText': e.contentText,
        'contentHtml': e.contentHtml,
        'isRead': e.isRead,
        'isStarred': e.isStarred,
        'isArchived': e.isArchived,
        'notes': e.notes,
        'aiSummary': e.aiSummary,
      }).toList();

      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/emails_export_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonString);

      if (mounted) {
        Navigator.pop(context);
        await Share.shareXFiles([XFile(file.path)], text: '邮件数据导出');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('成功导出 ${emails.length} 封邮件')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // 导出笔记数据
  Future<void> _exportNotes() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final emails = await _emailRepository.getLocalEmails(limit: 10000);
      final emailsWithNotes = emails.where((e) => e.notes != null && e.notes!.isNotEmpty).toList();
      
      final jsonData = emailsWithNotes.map((e) => {
        'messageId': e.messageId,
        'subject': e.subject,
        'senderEmail': e.senderEmail,
        'receivedDate': e.receivedDate.toIso8601String(),
        'notes': e.notes,
      }).toList();

      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/notes_export_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonString);

      if (mounted) {
        Navigator.pop(context);
        await Share.shareXFiles([XFile(file.path)], text: '笔记数据导出');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('成功导出 ${emailsWithNotes.length} 条笔记')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // 导出完整数据
  Future<void> _exportAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导出完整数据'),
        content: const Text('这将导出所有邮件、笔记和设置数据。\n\n导出可能需要一些时间，确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在导出数据...'),
            ],
          ),
        ),
      );

      final emails = await _emailRepository.getLocalEmails(limit: 10000);
      final archivedEmails = await _emailRepository.getArchivedEmails();
      
      final exportData = {
        'exportDate': DateTime.now().toIso8601String(),
        'version': '1.0',
        'emails': emails.map((e) => {
          'messageId': e.messageId,
          'subject': e.subject,
          'senderName': e.senderName,
          'senderEmail': e.senderEmail,
          'receivedDate': e.receivedDate.toIso8601String(),
          'contentText': e.contentText,
          'contentHtml': e.contentHtml,
          'isRead': e.isRead,
          'isStarred': e.isStarred,
          'isArchived': e.isArchived,
          'notes': e.notes,
          'aiSummary': e.aiSummary,
        }).toList(),
        'archivedEmails': archivedEmails.map((e) => {
          'messageId': e.messageId,
          'subject': e.subject,
        }).toList(),
        'statistics': {
          'totalEmails': _totalEmails,
          'unreadEmails': _unreadEmails,
          'starredEmails': _starredEmails,
          'emailsWithNotes': _emailsWithNotes,
        },
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/complete_export_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonString);

      if (mounted) {
        Navigator.pop(context);
        await Share.shareXFiles([XFile(file.path)], text: '完整数据导出');
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('数据导出成功！')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // 导入邮件数据
  Future<void> _importEmails() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在导入邮件数据...'),
            ],
          ),
        ),
      );

      final file = File(result.files.single.path!);
      final importService = DataImportService();
      final importResult = await importService.importEmails(file);

      if (mounted) {
        Navigator.pop(context);
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(importResult.success ? '导入完成' : '导入失败'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(importResult.summary),
                if (importResult.errors.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('错误详情:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...importResult.errors.take(5).map((e) => Text('• $e', style: const TextStyle(fontSize: 12))),
                  if (importResult.errors.length > 5)
                    Text('... 还有 ${importResult.errors.length - 5} 个错误'),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _loadStatistics();
                },
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // 导入笔记数据
  Future<void> _importNotes() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在导入笔记数据...'),
            ],
          ),
        ),
      );

      final file = File(result.files.single.path!);
      final importService = DataImportService();
      final importResult = await importService.importNotes(file);

      if (mounted) {
        Navigator.pop(context);
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(importResult.success ? '导入完成' : '导入失败'),
            content: Text(importResult.summary),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _loadStatistics();
                },
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // 检测重复邮件 - 直接跳转到去重页面
  Future<void> _detectDuplicates() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DeduplicationPage(),
      ),
    ).then((_) => _loadStatistics()); // 返回后刷新统计
  }

  // 清理已归档邮件
  Future<void> _cleanupArchived() async {
    if (_archivedEmails == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有已归档的邮件')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清理已归档邮件'),
        content: Text('确定要删除 $_archivedEmails 封已归档的邮件吗？\n\n此操作不可撤销！'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final archivedEmails = await _emailRepository.getArchivedEmails();
      for (final email in archivedEmails) {
        await _emailRepository.deleteEmail(email.messageId);
      }

      if (mounted) {
        Navigator.pop(context);
        await _loadStatistics();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('成功删除 ${archivedEmails.length} 封邮件')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('清理失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // 清理旧邮件
  Future<void> _cleanupOldEmails() async {
    final daysController = TextEditingController(text: '30');
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清理旧邮件'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('删除超过指定天数的邮件：'),
            const SizedBox(height: 16),
            TextField(
              controller: daysController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '天数',
                hintText: '例如：30',
                border: OutlineInputBorder(),
                suffixText: '天',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '注意：此操作不可撤销！',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final days = int.tryParse(daysController.text) ?? 30;
      final cutoffDate = DateTime.now().subtract(Duration(days: days));

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在清理旧邮件...'),
            ],
          ),
        ),
      );

      final emails = await _emailRepository.getLocalEmails(limit: 10000);
      final oldEmails = emails.where((e) => e.receivedDate.isBefore(cutoffDate)).toList();

      for (final email in oldEmails) {
        await _emailRepository.deleteEmail(email.messageId);
      }

      if (mounted) {
        Navigator.pop(context);
        await _loadStatistics();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('成功删除 ${oldEmails.length} 封旧邮件')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('清理失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
