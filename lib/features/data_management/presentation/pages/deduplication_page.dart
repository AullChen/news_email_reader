import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/repositories/email_repository.dart';
import '../../../../core/models/email_message.dart';

class DeduplicationPage extends StatefulWidget {
  const DeduplicationPage({super.key});

  @override
  State<DeduplicationPage> createState() => _DeduplicationPageState();
}

class _DeduplicationPageState extends State<DeduplicationPage> {
  final EmailRepository _emailRepository = EmailRepository();
  bool _isScanning = false;
  List<DuplicateGroup> _duplicateGroups = [];
  final Set<String> _selectedForDeletion = {};

  @override
  void initState() {
    super.initState();
    _scanDuplicates();
  }

  Future<void> _scanDuplicates() async {
    setState(() => _isScanning = true);
    
    try {
      final emails = await _emailRepository.getLocalEmails(limit: 10000);
      final duplicates = <String, List<EmailMessage>>{};

      // 按主题和发件人分组
      for (final email in emails) {
        final key = '${email.subject}_${email.senderEmail}';
        duplicates.putIfAbsent(key, () => []).add(email);
      }

      // 过滤出真正的重复项并排序
      final groups = duplicates.entries
          .where((entry) => entry.value.length > 1)
          .map((entry) {
            final emails = entry.value..sort((a, b) => b.receivedDate.compareTo(a.receivedDate));
            return DuplicateGroup(
              subject: emails.first.subject,
              senderEmail: emails.first.senderEmail,
              emails: emails,
            );
          })
          .toList()
        ..sort((a, b) => b.emails.length.compareTo(a.emails.length));

      setState(() {
        _duplicateGroups = groups;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('扫描失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isScanning = false);
    }
  }

  Future<void> _deleteDuplicates() async {
    if (_selectedForDeletion.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择要删除的邮件')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 ${_selectedForDeletion.length} 封重复邮件吗？\n\n此操作不可撤销！'),
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
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      for (final messageId in _selectedForDeletion) {
        await _emailRepository.deleteEmail(messageId);
      }

      if (mounted) {
        Navigator.pop(context);
        _selectedForDeletion.clear();
        await _scanDuplicates();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('删除成功！')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('邮件去重'),
        actions: [
          if (_selectedForDeletion.isNotEmpty)
            TextButton.icon(
              onPressed: _deleteDuplicates,
              icon: const Icon(Icons.delete, color: Colors.white),
              label: Text(
                '删除 (${_selectedForDeletion.length})',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _scanDuplicates,
          ),
        ],
      ),
      body: _isScanning
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在扫描重复邮件...'),
                ],
              ),
            )
          : _duplicateGroups.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, size: 64, color: Colors.green),
                      SizedBox(height: 16),
                      Text('未发现重复邮件', style: TextStyle(fontSize: 18)),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: AppTheme.surfaceColor,
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: AppTheme.primaryColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '发现 ${_duplicateGroups.length} 组重复邮件，共 ${_duplicateGroups.fold(0, (sum, g) => sum + g.emails.length)} 封',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _duplicateGroups.length,
                        itemBuilder: (context, index) {
                          return _buildDuplicateGroup(_duplicateGroups[index]);
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildDuplicateGroup(DuplicateGroup group) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryColor,
          child: Text(
            '${group.emails.length}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          group.subject,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          group.senderEmail,
          style: const TextStyle(fontSize: 12),
        ),
        children: [
          const Divider(height: 1),
          ...group.emails.asMap().entries.map((entry) {
            final index = entry.key;
            final email = entry.value;
            final isSelected = _selectedForDeletion.contains(email.messageId);
            final isNewest = index == 0;

            return ListTile(
              leading: Checkbox(
                value: isSelected,
                onChanged: isNewest
                    ? null // 最新的不能删除
                    : (value) {
                        setState(() {
                          if (value == true) {
                            _selectedForDeletion.add(email.messageId);
                          } else {
                            _selectedForDeletion.remove(email.messageId);
                          }
                        });
                      },
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatDate(email.receivedDate),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  if (isNewest)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '保留',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ID: ${email.messageId.substring(0, 20)}...', style: const TextStyle(fontSize: 10)),
                  if (email.notes != null && email.notes!.isNotEmpty)
                    const Row(
                      children: [
                        Icon(Icons.note, size: 12, color: Colors.orange),
                        SizedBox(width: 4),
                        Text('有笔记', style: TextStyle(fontSize: 10, color: Colors.orange)),
                      ],
                    ),
                ],
              ),
              dense: true,
            );
          }),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    // 自动选择除最新外的所有邮件
                    setState(() {
                      for (int i = 1; i < group.emails.length; i++) {
                        _selectedForDeletion.add(group.emails[i].messageId);
                      }
                    });
                  },
                  child: const Text('选择旧邮件'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class DuplicateGroup {
  final String subject;
  final String senderEmail;
  final List<EmailMessage> emails;

  DuplicateGroup({
    required this.subject,
    required this.senderEmail,
    required this.emails,
  });
}
