import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/email_message.dart';
import '../../../../core/repositories/email_repository.dart';
import '../../../../core/repositories/account_repository.dart';
import '../../../../core/services/ai_service.dart';
import '../../../../core/services/translation_service.dart';
import '../../../../core/constants/app_version.dart';

import '../../../reader/presentation/pages/email_reader_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../notes/presentation/pages/notes_page.dart';
import '../../../search/presentation/pages/search_page.dart';
import '../../../favorites/presentation/pages/favorites_page.dart';
import '../../../help/presentation/pages/help_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> with TickerProviderStateMixin {
  int _selectedTabIndex = 0;
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _hasPerformedInitialSync = false;
  List<EmailMessage> _emails = [];
  final EmailRepository _emailRepository = EmailRepository();
  final AccountRepository _accountRepository = AccountRepository();
  
  // 同步进度相关
  late AnimationController _syncAnimationController;
  late Animation<double> _syncAnimation;
  int _totalAccounts = 0;
  int _currentAccountIndex = 0;
  String _currentAccountName = '';


  final List<String> _filterTabs = [
    '全部',
    '今日',
    '本周',
  ];

  @override
  void initState() {
    super.initState();
    
    // 初始化同步动画
    _syncAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _syncAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _syncAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _loadEmails();
    // 应用启动时自动同步一次
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performInitialSync();
    });
  }
  
  @override
  void dispose() {
    _syncAnimationController.dispose();
    super.dispose();
  }

  /// 应用启动时的初始同步
  Future<void> _performInitialSync() async {
    if (_hasPerformedInitialSync) return;
    
    _hasPerformedInitialSync = true;
    await _refreshEmails();
  }

  Future<void> _loadEmails() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {

      await _applyCurrentFilter();
    } catch (e) {
      if (mounted) {
        _showErrorDialog('加载邮件失败', e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _syncAllActiveAccounts() async {
    final activeAccounts = await _accountRepository.getActiveAccounts();

    if (activeAccounts.isEmpty) {
      if (mounted) {
        setState(() {
          _emails = [];
        });
        _showErrorDialog('未发现邮件账户', '请前往设置添加并启用至少一个邮箱账户。');
      }
      return;
    }

    // 显示同步进度对话框
    if (mounted && !_isRefreshing) {
      _showSyncProgressDialog(activeAccounts.length);
    }

    List<EmailMessage> allSyncedEmails = [];
    bool hasError = false;
    int accountsWithNoNewMail = 0;
    int currentAccountIndex = 0;

    for (final account in activeAccounts) {
      try {
        // 更新同步进度
        if (mounted && !_isRefreshing) {
          _updateSyncProgress(currentAccountIndex, account.displayName ?? account.email);
        }
        
        final synced = await _emailRepository.syncEmails(account, forceRefresh: _isRefreshing);
        if (synced.isEmpty) {
          accountsWithNoNewMail++;
        }
        allSyncedEmails.addAll(synced);
        currentAccountIndex++;
      } on MailException {
        hasError = true;
        if (mounted) {
          _showErrorDialog(
            '授权或连接失败',
            '账户 ${account.displayName} (${account.email}) 无法同步。请检查授权码是否正确以及网络连接是否正常。',
          );
        }
      } catch (e) {
        hasError = true;
        if (mounted) {
          _showErrorDialog(
            '同步失败',
            '账户 ${account.displayName} (${account.email}) 发生未知错误: ${e.toString()}',
          );
        }
      }
    }

    // 刷新邮件列表
    final localEmails = await _emailRepository.getLocalEmails();
    final allEmailsMap = {for (var e in localEmails) e.messageId: e};
    for (var e in allSyncedEmails) {
      allEmailsMap[e.messageId] = e;
    }
    
    final finalEmails = allEmailsMap.values.toList();
    finalEmails.sort((a, b) => b.receivedDate.compareTo(a.receivedDate));

    if (mounted) {
      setState(() {
        _emails = finalEmails;
      });
    }

    // 关闭同步进度对话框
    if (mounted && !_isRefreshing) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    // 在所有操作完成后，根据最终状态显示提示
    if (!hasError && finalEmails.isEmpty) {
        _showErrorDialog(
            '邮箱为空',
            '未从任何账户获取到邮件。请检查邮箱内是否有内容，或确认白名单规则是否过于严格。',
        );
    } else if (!hasError && accountsWithNoNewMail == activeAccounts.length && allSyncedEmails.isEmpty) {
        // 如果所有账户都同步成功但都没有新邮件
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('所有账户均无新邮件。')),
            );
        }
    }
  }
  
  void _showSyncProgressDialog(int totalAccounts) {
    _totalAccounts = totalAccounts;
    _currentAccountIndex = 0;
    _syncAnimationController.repeat();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _syncAnimation,
                builder: (context, child) => CircularProgressIndicator(
                  value: _totalAccounts > 0 ? _currentAccountIndex / _totalAccounts : null,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '正在同步邮件...',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _currentAccountName.isNotEmpty 
                    ? '当前账户: $_currentAccountName'
                    : '准备同步...',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '${_currentAccountIndex}/$_totalAccounts',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _updateSyncProgress(int currentIndex, String accountName) {
    _currentAccountIndex = currentIndex;
    _currentAccountName = accountName;
    // 触发对话框重建
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _applyCurrentFilter() async {
    // 从 repository 重新获取数据以应用筛选
    List<EmailMessage> list;
    final now = DateTime.now();

    switch (_selectedTabIndex) {
      case 1: // 今日
        final start = DateTime(now.year, now.month, now.day);
        list = await _emailRepository.getLocalEmails(startDate: start);
        break;
      case 2: // 本周
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        list = await _emailRepository.getLocalEmails(startDate: start);
        break;
      default: // 全部
        list = await _emailRepository.getLocalEmails();
        break;
    }
    
    list.sort((a, b) => b.receivedDate.compareTo(a.receivedDate));

    if (mounted) {
      setState(() {
        _emails = list;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      drawer: _buildDrawer(),
      body: Column(
        children: [
          _buildFilterTabs(),
          Expanded(
            child: _buildEmailList(),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          const Text('新闻邮件'),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_emails.length}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            Scaffold.of(context).openDrawer();
          },
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SearchPage(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filterTabs.length,
        itemBuilder: (context, index) {
          final isSelected = index == _selectedTabIndex;
          return GestureDetector(
            onTap: () {
              if (_selectedTabIndex != index) {
                setState(() {
                  _selectedTabIndex = index;
                });
                _applyCurrentFilter();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor : AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textSecondaryColor,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                ),
                child: Text(_filterTabs[index]),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmailList() {
    if (_isLoading && _emails.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_emails.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: AppTheme.textSecondaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无邮件',
              style: TextStyle(
                fontSize: 18,
                color: AppTheme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '下拉刷新或检查账户设置',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshEmails,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _emails.length,
        itemBuilder: (context, index) {
          final email = _emails[index];
          return _buildEmailCard(email);
        },
      ),
    );
  }

  Widget _buildEmailCard(EmailMessage email) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onLongPress: () => _showEmailOptions(email),
        child: InkWell(
          onTap: () => _openEmailReader(email),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: email.isRead ? null : Theme.of(context).primaryColor.withValues(alpha: 0.05),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppTheme.primaryColor,
                      child: Text(
                        (email.senderName?.isNotEmpty == true) ? email.senderName![0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            email.senderName ?? '未知发件人',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            email.senderEmail,
                            style: TextStyle(
                              color: AppTheme.textSecondaryColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatTime(email.receivedDate),
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (email.isStarred)
                      const Icon(
                        Icons.star,
                        color: AppTheme.secondaryColor,
                        size: 16,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        email.subject,
                        style: TextStyle(
                          fontWeight: email.isRead ? FontWeight.normal : FontWeight.w500,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (email.aiSummary != null && email.aiSummary!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.auto_awesome,
                        size: 16,
                        color: AppTheme.secondaryColor,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  email.contentText ?? '无内容',
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '新闻',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: _isRefreshing ? null : _refreshEmails,
      backgroundColor: _isRefreshing ? Colors.grey : AppTheme.primaryColor,
      child: AnimatedBuilder(
        animation: _syncAnimationController,
        builder: (context, child) {
          return Transform.rotate(
            angle: _isRefreshing ? _syncAnimation.value * 2 * 3.14159 : 0,
            child: Icon(
              Icons.refresh,
              color: Colors.white,
              size: _isRefreshing ? 28 : 24,
            ),
          );
        },
      ),
    );
  }

  Future<void> _refreshEmails() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      await _syncAllActiveAccounts();
      await _applyCurrentFilter();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text('邮件已刷新'),
                const Spacer(),
                Text('${_emails.length}封', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('刷新失败', e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
        _syncAnimationController.stop();
      }
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}小时前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return '${dateTime.month}/${dateTime.day}';
    }
  }

  void _openEmailReader(EmailMessage email) async {
    // 标记为已读
    if (!email.isRead) {
      final updatedEmail = email.copyWith(isRead: true);
      await _emailRepository.updateEmail(updatedEmail);
      if (mounted) {
        setState(() {
          final index = _emails.indexWhere((e) => e.messageId == email.messageId);
          if (index != -1) {
            _emails[index] = updatedEmail;
          }
        });
      }
    }

    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EmailReaderPage(email: email),
        ),
      );
      
      // 从阅读器返回后，可能需要刷新状态（例如收藏、笔记）
      _refreshSingleEmail(email.messageId);
    }
  }
  
  Future<void> _refreshSingleEmail(String messageId) async {
    final updatedEmail = await _emailRepository.getEmailContent(messageId);
    if (updatedEmail != null && mounted) {
      setState(() {
        final index = _emails.indexWhere((e) => e.messageId == messageId);
        if (index != -1) {
          _emails[index] = updatedEmail;
        }
      });
    }
  }

  Future<void> _toggleStar(EmailMessage email) async {
    try {
      await _emailRepository.updateEmailStatus(
        email.messageId,
        isStarred: !email.isStarred,
      );
      await _refreshSingleEmail(email.messageId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              !email.isStarred ? '已收藏邮件' : '已取消收藏',
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      _showErrorSnack('操作失败: $e');
    }
  }

  void _showEmailOptions(EmailMessage emailData) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textSecondaryColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.mark_email_read),
              title: Text(emailData.isRead ? '标记为未读' : '标记为已读'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await _emailRepository.updateEmailStatus(
                    emailData.messageId,
                    isRead: !emailData.isRead,
                  );
                  await _refreshSingleEmail(emailData.messageId);
                } catch (e) {
                  _showErrorSnack('操作失败: $e');
                }
              },
            ),
            ListTile(
              leading: Icon(emailData.isStarred ? Icons.star_border : Icons.star),
              title: Text(emailData.isStarred ? '取消收藏' : '收藏'),
              onTap: () {
                Navigator.pop(context);
                _toggleStar(emailData);
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('AI总结'),
              onTap: () {
                Navigator.pop(context);
                _generateAISummary(emailData);
              },
            ),
            ListTile(
              leading: const Icon(Icons.translate),
              title: const Text('翻译'),
              onTap: () {
                Navigator.pop(context);
                _translateEmail(emailData);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('分享'),
              onTap: () {
                Navigator.pop(context);
                _shareEmail(emailData);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteEmail(emailData);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _generateAISummary(EmailMessage emailData) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在生成AI总结...')),
    );

    try {
      final aiService = AIService();
      final content = emailData.contentText ?? emailData.contentHtml ?? '';
      final summary = await aiService.generateSummary(emailData.subject, content);
      await _emailRepository.updateEmailStatus(emailData.messageId, aiSummary: summary);
      await _refreshSingleEmail(emailData.messageId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI总结已生成')),
        );
      }
    } catch (e) {
      _showErrorSnack('生成总结失败: $e');
    }
  }

  void _translateEmail(EmailMessage emailData) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('正在翻译...'), duration: Duration(milliseconds: 800)));
    try {
      final service = TranslationService();
      final originalText = emailData.contentText ??
          (emailData.contentHtml != null ? _htmlToPlainEmailText(emailData.contentHtml!) : '');
      final res = await service.translateEmail(
        subject: emailData.subject,
        content: originalText,
        targetLanguage: 'zh',
        sourceLanguage: 'auto',
      );
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('翻译结果（→ 中文）', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Text(res['subject'] ?? '', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Text(res['content'] ?? '', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('翻译失败: $e'), backgroundColor: Colors.red));
    }
  }

  String _htmlToPlainEmailText(String html) {
    var text = html.replaceAll(RegExp(r'<script[^>]*>.*?</script>', dotAll: true), '')
                   .replaceAll(RegExp(r'<style[^>]*>.*?</style>', dotAll: true), '');
    text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n');
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');
    text = text.replaceAll('&nbsp;', ' ')
               .replaceAll('&amp;', '&')
               .replaceAll('&lt;', '<')
               .replaceAll('&gt;', '>');
    return text.trim();
  }

  void _shareEmail(EmailMessage emailData) {
    Share.share(
        '主题: ${emailData.subject}\n发件人: ${emailData.senderEmail}\n\n${emailData.contentText ?? ''}');
  }

  Future<void> _deleteEmail(EmailMessage emailData) async {
    try {
      await _emailRepository.deleteEmail(emailData.messageId);
      if (mounted) {
        setState(() {
          _emails.removeWhere((e) => e.messageId == emailData.messageId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已删除邮件: ${emailData.subject}'),
          ),
        );
      }
    } catch (e) {
      _showErrorSnack('删除失败: $e');
    }
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.email,
                    size: 30,
                    color: AppTheme.primaryColor,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  '新闻邮件阅读器',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  AppVersion.versionName,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.inbox),
            title: const Text('邮件列表'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.note),
            title: const Text('我的笔记'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotesPage(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.star),
            title: const Text('收藏邮件'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FavoritesPage(),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('设置'),
            onTap: () async {
              Navigator.pop(context);
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsPage(),
                ),
              );
              // 从设置页返回后刷新
              _refreshEmails();
            },
          ),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('帮助'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HelpPage(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('关于'),
            onTap: () {
              Navigator.pop(context);
              _showAboutDialog();
            },
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: '新闻邮件阅读器',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.email,
          color: Colors.white,
          size: 32,
        ),
      ),
      children: const [
        Text('专为极客用户设计的新闻邮件阅读应用'),
        SizedBox(height: 16),
        Text('功能特性：'),
        Text('• 多协议邮件支持'),
        Text('• 智能白名单筛选'),
        Text('• AI邮件总结'),
        Text('• 纯净阅读体验'),
        Text('• 笔记功能'),
      ],
    );
  }

  void _showErrorSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _showErrorDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(message)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('确定')),
        ],
      ),
    );
  }
}