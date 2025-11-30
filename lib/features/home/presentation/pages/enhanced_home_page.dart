import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/email_message.dart';
import '../../../../core/repositories/email_repository.dart';
import '../../../../core/repositories/account_repository.dart';
import '../../../../core/services/ai_service.dart';
import '../../../../core/services/translation_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/utils/email_sort_utils.dart';
import '../../../../core/widgets/swipeable_email_card.dart';
import '../../../../core/constants/app_version.dart';

import '../../../reader/presentation/pages/email_reader_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../notes/presentation/pages/notes_page.dart';
import '../../../search/presentation/pages/search_page.dart';
import '../../../favorites/presentation/pages/favorites_page.dart';
import '../../../help/presentation/pages/help_page.dart';

class EnhancedHomePage extends ConsumerStatefulWidget {
  const EnhancedHomePage({super.key});

  @override
  ConsumerState<EnhancedHomePage> createState() => _EnhancedHomePageState();
}

class _EnhancedHomePageState extends ConsumerState<EnhancedHomePage>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  bool _hasPerformedInitialSync = false;
  bool _hasMoreData = true;
  
  List<EmailMessage> _allEmails = [];
  List<EmailMessage> _displayedEmails = [];
  
  final EmailRepository _emailRepository = EmailRepository();
  final AccountRepository _accountRepository = AccountRepository();
  final ScrollController _scrollController = ScrollController();

  // 分页参数
  static const int _pageSize = 20;
  int _currentPage = 0;

  // 排序和筛选
  EmailSortType _sortType = EmailSortType.dateDesc;
  EmailFilterType _filterType = EmailFilterType.all;

  // 同步进度相关
  late AnimationController _syncAnimationController;
  int _totalAccounts = 0;
  int _currentAccountIndex = 0;
  String _currentAccountName = '';

  @override
  void initState() {
    super.initState();

    // 初始化同步动画
    _syncAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // 监听滚动以实现上拉加载
    _scrollController.addListener(_onScroll);

    _loadEmails();
    
    // 应用启动时请求权限并自动同步
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestPermissionsAndSync();
    });
  }

  /// 请求权限并执行初始同步
  Future<void> _requestPermissionsAndSync() async {
    // 请求必要的权限（静默请求，不影响用户体验）
    try {
      final permissionService = PermissionService();
      await permissionService.requestStoragePermission();
    } catch (e) {
      debugPrint('权限请求失败: $e');
    }
    
    // 执行初始同步
    await _performInitialSync();
  }

  @override
  void dispose() {
    _syncAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 滚动监听 - 上拉加载更多
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData) {
        _loadMoreEmails();
      }
    }
  }

  /// 应用启动时的初始同步
  Future<void> _performInitialSync() async {
    if (_hasPerformedInitialSync) return;
    _hasPerformedInitialSync = true;
    await _refreshEmails();
  }

  /// 加载邮件
  Future<void> _loadEmails() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 从本地加载所有邮件
      final emails = await _emailRepository.getUnarchivedEmails();
      
      setState(() {
        _allEmails = emails;
        _currentPage = 0;
        _hasMoreData = true;
      });

      _applyFilterAndSort();
      _loadPage();
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

  /// 应用筛选和排序
  void _applyFilterAndSort() {
    final filtered = EmailSortUtils.filterEmails(_allEmails, _filterType);
    final sorted = EmailSortUtils.sortEmails(filtered, _sortType);
    
    setState(() {
      _allEmails = sorted;
      _currentPage = 0;
      _displayedEmails.clear();
      _hasMoreData = true;
    });
  }

  /// 加载一页数据
  void _loadPage() {
    final startIndex = _currentPage * _pageSize;
    final endIndex = startIndex + _pageSize;

    if (startIndex >= _allEmails.length) {
      setState(() {
        _hasMoreData = false;
      });
      return;
    }

    final pageEmails = _allEmails.sublist(
      startIndex,
      endIndex > _allEmails.length ? _allEmails.length : endIndex,
    );

    setState(() {
      _displayedEmails.addAll(pageEmails);
      _currentPage++;
      _hasMoreData = endIndex < _allEmails.length;
    });
  }

  /// 加载更多邮件
  Future<void> _loadMoreEmails() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 500));

    _loadPage();

    setState(() {
      _isLoadingMore = false;
    });
  }

  /// 同步所有活跃账户
  Future<void> _syncAllActiveAccounts() async {
    final activeAccounts = await _accountRepository.getActiveAccounts();

    if (activeAccounts.isEmpty) {
      if (mounted) {
        setState(() {
          _allEmails = [];
          _displayedEmails = [];
        });
        _showErrorDialog('未发现邮件账户', '请前往设置添加并启用至少一个邮箱账户。');
      }
      return;
    }

    // 显示同步进度对话框
    if (mounted && !_isRefreshing) {
      _showSyncProgressDialog(activeAccounts.length);
    }

    bool hasError = false;

    for (int i = 0; i < activeAccounts.length; i++) {
      final account = activeAccounts[i];
      
      try {
        // 更新同步进度
        if (mounted && !_isRefreshing) {
          _updateSyncProgress(i, account.displayName ?? account.email);
        }

        await _emailRepository.syncEmails(account, forceRefresh: _isRefreshing);
      } catch (e) {
        hasError = true;
        if (mounted) {
          _showErrorDialog(
            '同步失败',
            '账户 ${account.displayName ?? account.email} 同步失败: ${e.toString()}',
          );
        }
      }
    }

    // 重新加载邮件
    await _loadEmails();

    // 关闭同步进度对话框
    if (mounted && !_isRefreshing) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    if (!hasError && _allEmails.isEmpty && mounted) {
      _showErrorDialog(
        '邮箱为空',
        '未从任何账户获取到邮件。请检查邮箱内是否有内容，或确认白名单规则是否过于严格。',
      );
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
              CircularProgressIndicator(
                value: _totalAccounts > 0
                    ? _currentAccountIndex / _totalAccounts
                    : null,
                strokeWidth: 3,
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
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      drawer: _buildDrawer(),
      body: Column(
        children: [
          _buildFilterBar(),
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
              '${_allEmails.length}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.sort),
          onPressed: _showSortOptions,
        ),
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

  Widget _buildFilterBar() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: EmailFilterType.values.length,
        itemBuilder: (context, index) {
          final filter = EmailFilterType.values[index];
          final isSelected = filter == _filterType;
          
          return GestureDetector(
            onTap: () {
              if (_filterType != filter) {
                setState(() {
                  _filterType = filter;
                });
                _applyFilterAndSort();
                _loadPage();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.surfaceColor,
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
              child: Text(
                filter.displayName,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textSecondaryColor,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmailList() {
    if (_isLoading && _displayedEmails.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_displayedEmails.isEmpty && !_isLoading) {
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
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _displayedEmails.length + (_hasMoreData ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _displayedEmails.length) {
            // 加载更多指示器
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _isLoadingMore
                    ? const CircularProgressIndicator()
                    : const SizedBox.shrink(),
              ),
            );
          }

          final email = _displayedEmails[index];
          return SwipeableEmailCard(
            email: email,
            onTap: () => _openEmailReader(email),
            onStar: () => _toggleStar(email),
            onArchive: () => _archiveEmail(email),
            onDelete: () => _deleteEmail(email),
            onMarkRead: () => _toggleRead(email),
          );
        },
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
            angle: _isRefreshing ? _syncAnimationController.value * 2 * 3.14159 : 0,
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text('邮件已刷新'),
                const Spacer(),
                Text('${_allEmails.length}封',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
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

  void _openEmailReader(EmailMessage email) async {
    // 标记为已读
    if (!email.isRead) {
      final updatedEmail = email.copyWith(isRead: true);
      await _emailRepository.updateEmail(updatedEmail);
      _refreshSingleEmail(email.messageId);
    }

    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EmailReaderPage(email: email),
        ),
      );

      // 从阅读器返回后刷新状态
      _refreshSingleEmail(email.messageId);
    }
  }

  Future<void> _refreshSingleEmail(String messageId) async {
    final updatedEmail = await _emailRepository.getEmailContent(messageId);
    if (updatedEmail != null && mounted) {
      setState(() {
        final allIndex = _allEmails.indexWhere((e) => e.messageId == messageId);
        if (allIndex != -1) {
          _allEmails[allIndex] = updatedEmail;
        }
        
        final displayIndex = _displayedEmails.indexWhere((e) => e.messageId == messageId);
        if (displayIndex != -1) {
          _displayedEmails[displayIndex] = updatedEmail;
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
            content: Text(!email.isStarred ? '已收藏邮件' : '已取消收藏'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      _showErrorSnack('操作失败: $e');
    }
  }

  Future<void> _toggleRead(EmailMessage email) async {
    try {
      await _emailRepository.updateEmailStatus(
        email.messageId,
        isRead: !email.isRead,
      );
      await _refreshSingleEmail(email.messageId);
    } catch (e) {
      _showErrorSnack('操作失败: $e');
    }
  }

  Future<void> _archiveEmail(EmailMessage email) async {
    try {
      await _emailRepository.archiveEmail(email.messageId);
      
      setState(() {
        _allEmails.removeWhere((e) => e.messageId == email.messageId);
        _displayedEmails.removeWhere((e) => e.messageId == email.messageId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('已归档邮件'),
            action: SnackBarAction(
              label: '撤销',
              onPressed: () async {
                await _emailRepository.unarchiveEmail(email.messageId);
                await _loadEmails();
              },
            ),
          ),
        );
      }
    } catch (e) {
      _showErrorSnack('归档失败: $e');
    }
  }

  Future<void> _deleteEmail(EmailMessage email) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除邮件"${email.subject}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _emailRepository.deleteEmail(email.messageId);
        
        setState(() {
          _allEmails.removeWhere((e) => e.messageId == email.messageId);
          _displayedEmails.removeWhere((e) => e.messageId == email.messageId);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已删除邮件: ${email.subject}')),
          );
        }
      } catch (e) {
        _showErrorSnack('删除失败: $e');
      }
    }
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '排序方式',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...EmailSortType.values.map((sortType) {
              final isSelected = sortType == _sortType;
              return ListTile(
                leading: Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: isSelected ? AppTheme.primaryColor : null,
                ),
                title: Text(sortType.displayName),
                subtitle: Text(sortType.description),
                onTap: () {
                  Navigator.pop(context);
                  if (_sortType != sortType) {
                    setState(() {
                      _sortType = sortType;
                    });
                    _applyFilterAndSort();
                    _loadPage();
                  }
                },
              );
            }),
          ],
        ),
      ),
    );
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
          ListTile(
            leading: const Icon(Icons.archive),
            title: const Text('已归档'),
            onTap: () {
              Navigator.pop(context);
              _showArchivedEmails();
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

  void _showArchivedEmails() async {
    final archivedEmails = await _emailRepository.getArchivedEmails();
    
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.archive, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    '已归档 (${archivedEmails.length})',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: archivedEmails.isEmpty
                  ? const Center(child: Text('暂无归档邮件'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: archivedEmails.length,
                      itemBuilder: (context, index) {
                        final email = archivedEmails[index];
                        return SwipeableEmailCard(
                          email: email,
                          onTap: () {
                            Navigator.pop(context);
                            _openEmailReader(email);
                          },
                          onArchive: () async {
                            await _emailRepository.unarchiveEmail(email.messageId);
                            Navigator.pop(context);
                            _loadEmails();
                          },
                          onDelete: () async {
                            await _emailRepository.deleteEmail(email.messageId);
                            Navigator.pop(context);
                            _loadEmails();
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
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
        Text('• 左滑快捷操作'),
        Text('• 邮件归档'),
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
