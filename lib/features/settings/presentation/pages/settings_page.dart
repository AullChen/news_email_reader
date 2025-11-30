import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'privacy_policy_page.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/services/cache_service.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/constants/app_version.dart';
import '../widgets/account_management_section.dart';
import '../widgets/whitelist_management_section.dart';
import '../widgets/ai_settings_section.dart';
import '../widgets/email_sync_config_section.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: TabBarView(
        controller: _tabController,
        children: const [
          AccountManagementSection(),
          WhitelistManagementSection(),
          AISettingsSection(),
          EmailSyncConfigSection(),
          AppSettingsSection(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('设置'),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: AppTheme.primaryColor,
        labelColor: AppTheme.primaryColor,
        unselectedLabelColor: AppTheme.textSecondaryColor,
        tabs: const [
          Tab(
            icon: Icon(Icons.email),
            text: '账户',
          ),
          Tab(
            icon: Icon(Icons.filter_list),
            text: '白名单',
          ),
          Tab(
            icon: Icon(Icons.auto_awesome),
            text: 'AI与翻译',
          ),
          Tab(
            icon: Icon(Icons.sync),
            text: '同步',
          ),
          Tab(
            icon: Icon(Icons.settings),
            text: '应用',
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

class AppSettingsSection extends ConsumerStatefulWidget {
  const AppSettingsSection({super.key});

  @override
  ConsumerState<AppSettingsSection> createState() => _AppSettingsSectionState();
}

class _AppSettingsSectionState extends ConsumerState<AppSettingsSection> {
  final SettingsService _settingsService = SettingsService();
  final StorageService _storageService = StorageService.instance;
  
  bool _notifications = true;
  String _cacheSize = '计算中...';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadCacheSize();
  }

  Future<void> _loadSettings() async {
    final notifications = await _settingsService.getNotifications();

    setState(() {
      _notifications = notifications;
    });
  }

  Future<void> _loadCacheSize() async {
    final size = await _storageService.getCacheSize();
    setState(() {
      _cacheSize = size;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSettingsGroup(
          title: '通用设置',
          children: [
            Consumer(
              builder: (context, ref, child) {
                final themeMode = ref.watch(themeProvider);
                final isDarkMode = themeMode == ThemeMode.dark;
                
                return _buildSettingsTile(
                  icon: Icons.dark_mode,
                  title: '深色模式',
                  subtitle: '使用深色主题',
                  trailing: Switch(
                    value: isDarkMode,
                    onChanged: (value) {
                      ref.read(themeProvider.notifier).setTheme(
                        value ? ThemeMode.dark : ThemeMode.light,
                      );
                    },
                    activeColor: AppTheme.primaryColor,
                  ),
                );
              },
            ),
            _buildSettingsTile(
              icon: Icons.notifications,
              title: '推送通知',
              subtitle: '接收新邮件通知',
              trailing: Switch(
                value: _notifications,
                onChanged: (value) async {
                  await _settingsService.setNotifications(value);
                  setState(() {
                    _notifications = value;
                  });
                },
                activeColor: AppTheme.primaryColor,
              ),
            ),

          ],
        ),
        const SizedBox(height: 24),
        _buildSettingsGroup(
          title: '缓存设置',
          children: [
            _buildSettingsTile(
              icon: Icons.storage,
              title: '缓存大小',
              subtitle: '当前缓存: $_cacheSize',
              onTap: () {
                _loadCacheSize(); // 刷新缓存大小
              },
            ),
            _buildSettingsTile(
              icon: Icons.clear_all,
              title: '清理缓存',
              subtitle: '清除所有缓存数据',
              onTap: () {
                _showClearCacheDialog(context);
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildSettingsGroup(
          title: '关于',
          children: [
            _buildSettingsTile(
              icon: Icons.info,
              title: '版本信息',
              subtitle: '极客新闻邮件阅读器 ${AppVersion.versionName}',
              onTap: () {
                _showAboutDialog(context);
              },
            ),
            _buildSettingsTile(
              icon: Icons.help,
              title: '反馈',
              subtitle: '使用中出现的的问题反馈',
              onTap: () async {
                final url = Uri.parse('https://github.com/AullChen/news_email_reader/issues/new');
                if (!await launchUrl(url)) {
                  throw Exception('Could not launch $url');
                }
              },
            ),
            _buildSettingsTile(
              icon: Icons.privacy_tip,
              title: '隐私政策',
              subtitle: '查看隐私政策',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PrivacyPolicyPage(),
                  ),
                );
              },
            ),
            _buildSettingsTile(
              icon: Icons.telegram,
              title: '联系作者',
              subtitle: '通过直接访问本项目的仓库',
              onTap: () async {
                final url = Uri.parse('https://github.com/AullChen/news_email_reader/');
                if (!await launchUrl(url)) {
                  throw Exception('Could not launch $url');
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSettingsGroup({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
        Card(
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: AppTheme.textPrimaryColor,
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppTheme.textSecondaryColor,
        ),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清理缓存'),
        content: const Text('将清除正文内容、图片等缓存，但会保留已收藏或含笔记的邮件及其标记。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                // 仅清正文/图片等缓存，并保留用户操作数据
                await CacheService().clearAllCache();
                await _storageService.clearCachePreservingUserData();
                await _loadCacheSize(); // 刷新缓存大小显示
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('缓存已清理（已保留收藏/笔记数据）')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('清理缓存失败: $e')),
                );
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: '极客新闻邮件阅读器',
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
      ],
    );
  }
}