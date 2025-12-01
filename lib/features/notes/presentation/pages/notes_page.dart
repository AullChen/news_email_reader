import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/email_message.dart';
import '../../../../core/repositories/email_repository.dart';
import '../../../reader/presentation/pages/email_reader_page.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final EmailRepository _emailRepository = EmailRepository();
  List<EmailMessage> _emailsWithNotes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEmailsWithNotes();
  }

  Future<void> _loadEmailsWithNotes() async {
    setState(() => _isLoading = true);
    try {
      final emails = await _emailRepository.getLocalEmails(limit: 1000);
      _emailsWithNotes = emails.where((email) => 
        email.notes != null && email.notes!.isNotEmpty).toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载笔记失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的笔记'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
              ),
            )
          : _emailsWithNotes.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.note_outlined,
                        size: 64,
                        color: AppTheme.textSecondaryColor,
                      ),
                      SizedBox(height: 16),
                      Text(
                        '暂无笔记',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '在邮件详情页添加笔记后，会在这里显示',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadEmailsWithNotes,
                  color: AppTheme.primaryColor,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _emailsWithNotes.length,
                    itemBuilder: (context, index) {
                      final email = _emailsWithNotes[index];
                      return _buildNoteCard(email);
                    },
                  ),
                ),
    );
  }

  Widget _buildNoteCard(EmailMessage email) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EmailReaderPage(email: email),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        color: AppTheme.cardColor,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 邮件标题
              Text(
                email.subject,
                style: const TextStyle(
                  color: AppTheme.textPrimaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              
              // 发件人和日期
              Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 16,
                    color: AppTheme.textSecondaryColor,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      email.displaySender,
                      style: const TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.access_time,
                    size: 16,
                    color: AppTheme.textSecondaryColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(email.receivedDate),
                    style: const TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              const Divider(color: AppTheme.textSecondaryColor),
              const SizedBox(height: 8),
              
              // 笔记图标和标题
              const Row(
                children: [
                  Icon(
                    Icons.note,
                    size: 18,
                    color: AppTheme.secondaryColor,
                  ),
                  SizedBox(width: 6),
                  Text(
                    '我的笔记',
                    style: TextStyle(
                      color: AppTheme.secondaryColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // 笔记内容 - 支持 Markdown
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.secondaryColor.withValues(alpha: 0.3),
                  ),
                ),
                child: MarkdownBody(
                  data: email.notes!,
                  selectable: true,
                  softLineBreak: true,
                  styleSheet: MarkdownStyleSheet(
                    // 段落样式 - 支持换行
                    p: const TextStyle(
                      color: AppTheme.textPrimaryColor,
                      fontSize: 14,
                      height: 1.6,
                    ),
                    // 标题样式
                    h1: const TextStyle(
                      color: AppTheme.textPrimaryColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                    h2: const TextStyle(
                      color: AppTheme.textPrimaryColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                    h3: const TextStyle(
                      color: AppTheme.textPrimaryColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                    // 行内代码样式 - 改进
                    code: TextStyle(
                      backgroundColor: const Color(0xFFF5F5F5),
                      color: const Color(0xFFD73A49),
                      fontFamily: 'Consolas, Monaco, monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    // 代码块样式 - 改进
                    codeblockPadding: const EdgeInsets.all(12),
                    codeblockDecoration: BoxDecoration(
                      color: const Color(0xFF2D2D2D),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF404040)),
                    ),
                    // 列表样式
                    listBullet: const TextStyle(
                      color: AppTheme.textPrimaryColor,
                      fontSize: 14,
                      height: 1.6,
                    ),
                    listIndent: 20,
                    // 引用样式
                    blockquote: const TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: AppTheme.textSecondaryColor,
                      fontStyle: FontStyle.italic,
                    ),
                    blockquoteDecoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      border: const Border(
                        left: BorderSide(
                          color: AppTheme.primaryColor,
                          width: 3,
                        ),
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    blockquotePadding: const EdgeInsets.all(10),
                    // 链接样式
                    a: const TextStyle(
                      color: AppTheme.primaryColor,
                      decoration: TextDecoration.underline,
                    ),
                    // 段落间距
                    pPadding: const EdgeInsets.only(bottom: 10),
                    h1Padding: const EdgeInsets.only(top: 12, bottom: 6),
                    h2Padding: const EdgeInsets.only(top: 10, bottom: 4),
                    h3Padding: const EdgeInsets.only(top: 8, bottom: 4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return '昨天';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return '${date.month}/${date.day}';
    }
  }
}