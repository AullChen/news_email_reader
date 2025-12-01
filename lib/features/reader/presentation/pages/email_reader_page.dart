import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart' as windows_webview;
import 'package:flutter_markdown/flutter_markdown.dart';

import 'package:share_plus/share_plus.dart';
import 'package:html/parser.dart' show parse;
import 'web_viewer_page.dart';
import 'package:html/dom.dart' as dom;

import '../../../../core/models/email_message.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/repositories/email_repository.dart';
import '../../../../core/services/ai_service.dart';
import '../../../../core/services/translation_service.dart';
import '../../../../core/services/cache_service.dart';
import '../../../notes/presentation/pages/markdown_note_editor_page.dart';

class EmailReaderPage extends StatefulWidget {
  final EmailMessage email;

  const EmailReaderPage({super.key, required this.email});

  @override
  State<EmailReaderPage> createState() => _EmailReaderPageState();
}

class _EmailReaderPageState extends State<EmailReaderPage> {
  // For Android/iOS
  late final WebViewController _webViewController;

  // For Windows
  final _windowsController = windows_webview.WebviewController();

  bool _isWebViewLoading = true;
  bool _plainTextMode = false;
  late EmailMessage _currentEmail;
  final EmailRepository _emailRepository = EmailRepository();
  final ScrollController _scrollController = ScrollController();
  
  // 阅读进度
  double _readingProgress = 0.0;
  bool _hasRestoredProgress = false;

  @override
  void initState() {
    super.initState();
    _currentEmail = widget.email;
    _readingProgress = _currentEmail.readingProgress ?? 0.0;
    _initializeWebView();
    _scrollController.addListener(_onScroll);
  }
  
  void _onScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      
      if (maxScroll > 0) {
        final progress = (currentScroll / maxScroll).clamp(0.0, 1.0);
        if ((progress - _readingProgress).abs() > 0.05) {
          _readingProgress = progress;
          _saveReadingProgress();
        }
      }
    }
  }
  
  Future<void> _saveReadingProgress() async {
    try {
      await _emailRepository.updateReadingProgress(
        _currentEmail.messageId,
        _readingProgress,
      );
    } catch (e) {
      // 静默失败
    }
  }
  
  void _restoreReadingProgress() {
    if (_hasRestoredProgress || _readingProgress == 0.0) return;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final targetScroll = maxScroll * _readingProgress;
        _scrollController.jumpTo(targetScroll.clamp(0.0, maxScroll));
        _hasRestoredProgress = true;
      }
    });
  }

  Future<void> _initializeWebView() async {
    final html = _composeHtml(_currentEmail.contentHtml, _currentEmail.contentText);

    if (Platform.isWindows) {
      await _windowsController.initialize();
      await _windowsController.loadStringContent(html);
      _windowsController.url.listen((url) {
        if (url.startsWith('http')) {
          // 重新加载原始邮件以“阻止”导航
          _windowsController.loadStringContent(html);
          // 在应用内打开链接
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => WebViewerPage(url: url)),
          );
        }
      });
    } else {
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (String url) {
              if (mounted) setState(() => _isWebViewLoading = false);
            },
            onNavigationRequest: (NavigationRequest request) {
              if (request.url.startsWith('http')) {
                // 在应用内打开链接
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => WebViewerPage(url: request.url)),
                );
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadHtmlString(html);
    }

    if (mounted) {
      setState(() {
        _isWebViewLoading = false;
      });
    }
  }

  Future<void> _reloadWebViewContent() async {
    if (!mounted) return;
    final html = _composeHtml(_currentEmail.contentHtml, _currentEmail.contentText);

    if (Platform.isWindows) {
      try {
        if (mounted) setState(() => _isWebViewLoading = true);
        await _windowsController.loadStringContent(html);
      } finally {
        if (mounted) setState(() => _isWebViewLoading = false);
      }
    } else {
      if (mounted) setState(() => _isWebViewLoading = true);
      await _webViewController.loadHtmlString(html);
      // onPageFinished will set _isWebViewLoading to false
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    if (Platform.isWindows) {
      _windowsController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: _buildAppBar(),
        body: _buildTabBody(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        _currentEmail.subject,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        IconButton(
          icon: Icon(_currentEmail.isStarred ? Icons.star : Icons.star_border),
          onPressed: _toggleStar,
        ),
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: _showEmailOptions,
        ),
      ],
      bottom: const TabBar(
        tabs: [
          Tab(text: '内容'),
          Tab(text: '笔记'),
          Tab(text: '总结'),
        ],
      ),
    );
  }

  Widget _buildTabBody() {
    return TabBarView(
      children: [
        _buildContentTab(),
        _buildNotesTab(),
        _buildSummaryTab(),
      ],
    );
  }

  Widget _buildContentTab() {
    if (_isWebViewLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasContent = (_currentEmail.contentHtml?.trim().isNotEmpty ?? false) ||
                       (_currentEmail.contentText?.trim().isNotEmpty ?? false);

    if (!hasContent) {
      return const Center(
        child: Text('邮件内容为空', style: TextStyle(color: Colors.grey)),
      );
    }

    if (_plainTextMode) {
      final text = _currentEmail.contentText ??
          (_currentEmail.contentHtml != null ? _htmlToPlainText(_currentEmail.contentHtml!) : '');
      
      // 恢复阅读进度
      _restoreReadingProgress();
      
      return SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (_readingProgress > 0.05)
                  Text(
                    '阅读进度: ${(_readingProgress * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _plainTextMode = false;
                    });
                    _reloadWebViewContent();
                  },
                  icon: const Icon(Icons.web),
                  label: const Text('富文本模式'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SelectableText(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    final webView = Platform.isWindows
        ? windows_webview.Webview(
            _windowsController,
            permissionRequested: (url, permission, isUserInitiated) async {
              return windows_webview.WebviewPermissionDecision.allow;
            },
          )
        : WebViewWidget(controller: _webViewController);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              if (_readingProgress > 0.05)
                Text(
                  '阅读进度: ${(_readingProgress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _plainTextMode = true;
                  });
                },
                icon: const Icon(Icons.text_fields),
                label: const Text('纯文本模式'),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: webView,
          ),
        ),
      ],
    );
  }

  String _htmlToPlainText(String html) {
    try {
      final document = parse(html);
      final String parsedString = parse(document.body?.text).documentElement!.text;
      return parsedString;
    } catch (e) {
      // Fallback for malformed HTML
      return html.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    }
  }

  Widget _buildNotesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.note_alt, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text('我的笔记', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MarkdownNoteEditorPage(email: _currentEmail),
                    ),
                  );
                  if (result == true) {
                    _refreshEmailState();
                  }
                },
                icon: const Icon(Icons.edit),
                label: const Text('编辑'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.secondaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, size: 14, color: AppTheme.secondaryColor),
                SizedBox(width: 4),
                Text(
                  '支持 Markdown 格式',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.secondaryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_currentEmail.notes != null && _currentEmail.notes!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
              ),
              child: MarkdownBody(
                data: _currentEmail.notes!,
                selectable: true,
                softLineBreak: true,
                styleSheet: MarkdownStyleSheet(
                  // 段落样式 - 支持换行
                  p: const TextStyle(fontSize: 15, height: 1.6),
                  // 标题样式
                  h1: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.3),
                  h2: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, height: 1.3),
                  h3: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.3),
                  // 行内代码样式 - 改进
                  code: TextStyle(
                    backgroundColor: const Color(0xFFF5F5F5),
                    color: const Color(0xFFD73A49),
                    fontFamily: 'Consolas, Monaco, monospace',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  // 代码块样式 - 改进
                  codeblockPadding: const EdgeInsets.all(14),
                  codeblockDecoration: BoxDecoration(
                    color: const Color(0xFF2D2D2D),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF404040)),
                  ),
                  // 列表样式
                  listBullet: const TextStyle(fontSize: 15, height: 1.6),
                  listIndent: 22,
                  // 引用样式
                  blockquote: const TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    fontStyle: FontStyle.italic,
                  ),
                  blockquoteDecoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    border: const Border(
                      left: BorderSide(color: AppTheme.primaryColor, width: 4),
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  blockquotePadding: const EdgeInsets.all(12),
                  // 链接样式
                  a: const TextStyle(
                    color: AppTheme.primaryColor,
                    decoration: TextDecoration.underline,
                  ),
                  // 段落间距
                  pPadding: const EdgeInsets.only(bottom: 12),
                  h1Padding: const EdgeInsets.only(top: 14, bottom: 6),
                  h2Padding: const EdgeInsets.only(top: 12, bottom: 5),
                  h3Padding: const EdgeInsets.only(top: 10, bottom: 4),
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: const Column(
                children: [
                  Icon(Icons.note_add, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text(
                    '暂无笔记',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '点击右上角"编辑"按钮添加笔记',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppTheme.secondaryColor),
              const SizedBox(width: 8),
              Text('AI 总结', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              TextButton.icon(
                onPressed: _generateAISummary,
                icon: const Icon(Icons.build),
                label: const Text('生成/更新'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_currentEmail.aiSummary != null && _currentEmail.aiSummary!.isNotEmpty)
            Text(_currentEmail.aiSummary!, style: Theme.of(context).textTheme.bodyMedium)
          else
            const Text('暂无总结，点击右上角生成。', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  void _showEmailOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(_currentEmail.isStarred ? Icons.star_border : Icons.star),
              title: Text(_currentEmail.isStarred ? '取消收藏' : '收藏'),
              onTap: () {
                Navigator.pop(context);
                _toggleStar();
              },
            ),
            ListTile(
              leading: const Icon(Icons.note_add),
              title: const Text('笔记'),
              onTap: () async {
                Navigator.pop(context);
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MarkdownNoteEditorPage(email: _currentEmail),
                  ),
                );
                if (result == true) {
                  _refreshEmailState();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('AI总结'),
              onTap: () {
                Navigator.pop(context);
                _generateAISummary();
              },
            ),
            ListTile(
              leading: const Icon(Icons.translate),
              title: const Text('翻译'),
              onTap: () {
                Navigator.pop(context);
                _translateEmail();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('分享'),
              onTap: () {
                Navigator.pop(context);
                _shareEmail();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteEmail();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleStar() async {
    try {
      await _emailRepository.updateEmailStatus(
        _currentEmail.messageId,
        isStarred: !_currentEmail.isStarred,
      );
      _refreshEmailState();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(!_currentEmail.isStarred ? '已收藏邮件' : '已取消收藏'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      _showErrorSnack('操作失败: $e');
    }
  }

  void _generateAISummary() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在生成AI总结...')),
    );

    try {
      final aiService = AIService();
      final content = _currentEmail.contentText ?? _currentEmail.contentHtml ?? '';
      final summary = await aiService.generateSummary(_currentEmail.subject, content);
      await _emailRepository.updateEmailStatus(_currentEmail.messageId, aiSummary: summary);
      _refreshEmailState();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI总结已生成')),
        );
      }
    } catch (e) {
      _showErrorSnack('生成总结失败: $e');
    }
  }

  void _translateEmail() async {
    final selectedLang = await showDialog<String>(
      context: context,
      builder: (context) {
        final langs = [
          {'code': 'zh', 'name': '中文'},
          {'code': 'en', 'name': 'English'},
          {'code': 'ja', 'name': '日本語'},
          {'code': 'ko', 'name': '한국어'},
          {'code': 'fr', 'name': 'Français'},
          {'code': 'de', 'name': 'Deutsch'},
          {'code': 'es', 'name': 'Español'},
          {'code': 'ru', 'name': 'Русский'},
        ];
        return SimpleDialog(
          title: const Text('选择目标语言'),
          children: langs.map((e) {
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(context, e['code']!),
              child: Text('${e['name']} (${e['code']})'),
            );
          }).toList(),
        );
      },
    );
    if (selectedLang == null) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('正在翻译...'), duration: Duration(milliseconds: 800)));

    try {
      final cache = CacheService();
      final cached = await cache.getCachedTranslation(_currentEmail.messageId, selectedLang);
      String subjectTr;
      String contentTr;

      if (cached != null) {
        subjectTr = cached['subject'] ?? '';
        contentTr = cached['content'] ?? '';
      } else {
        final service = TranslationService();
        final originalText = _currentEmail.contentText ??
            (_currentEmail.contentHtml != null ? _htmlToPlainText(_currentEmail.contentHtml!) : '');

        subjectTr = await service.translateText(
          text: _currentEmail.subject,
          targetLanguage: selectedLang,
          sourceLanguage: 'auto',
        );
        contentTr = await service.translateText(
          text: originalText,
          targetLanguage: selectedLang,
          sourceLanguage: 'auto',
        );

        await cache.cacheTranslation(
          _currentEmail.messageId,
          selectedLang,
          subject: subjectTr,
          content: contentTr,
        );
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('翻译结果 ($selectedLang)'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('标题:', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  SelectableText(subjectTr),
                  const SizedBox(height: 16),
                  Text('内容:', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  SelectableText(contentTr),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      _showErrorSnack('翻译失败: $e');
    }
  }

  void _shareEmail() async {
    final content = '''
标题: ${_currentEmail.subject}
发件人: ${_currentEmail.displaySender}
时间: ${_currentEmail.receivedDate}

${_currentEmail.contentText ?? _htmlToPlainText(_currentEmail.contentHtml ?? '')}
''';

    try {
      await Share.share(content, subject: _currentEmail.subject);
    } catch (e) {
      _showErrorSnack('分享失败: $e');
    }
  }

  void _deleteEmail() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这封邮件吗？此操作不可撤销。'),
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
        await _emailRepository.deleteEmail(_currentEmail.messageId);
        if (mounted) {
          Navigator.pop(context, true); // 返回上一页并标记已删除
        }
      } catch (e) {
        _showErrorSnack('删除失败: $e');
      }
    }
  }

  Future<void> _refreshEmailState() async {
    final updatedEmail = await _emailRepository.getEmailContent(_currentEmail.messageId);
    if (updatedEmail != null && mounted) {
      setState(() {
        _currentEmail = updatedEmail;
      });
      if (!_plainTextMode) {
        _reloadWebViewContent();
      }
    }
  }

  String _composeHtml(String? html, String? text) {
    final h = html?.trim() ?? '';
    if (h.isNotEmpty) {
      try {
        final doc = parse(h);
        final isFullDoc = doc.querySelector('html') != null || doc.querySelector('body') != null;
        if (isFullDoc) {
          return _injectHeadMeta(doc).outerHtml;
        } else {
          return _buildHtmlTemplate(h);
        }
      } catch (e) {
        return _buildHtmlTemplate(h);
      }
    }

    final t = text?.trim() ?? '';
    if (t.isNotEmpty) {
      final escaped = t
          .replaceAll('&', '&')
          .replaceAll('<', '<')
          .replaceAll('>', '>')
          .replaceAll('\r\n', '<br>')
          .replaceAll('\n', '<br>');
      return _buildHtmlTemplate('<div style="white-space: pre-wrap; word-wrap: break-word;">$escaped</div>');
    }

    return _buildHtmlTemplate('<div style="color:#888;">邮件内容为空</div>');
  }

  dom.Document _injectHeadMeta(dom.Document doc) {
    var head = doc.querySelector('head');
    if (head == null) {
      head = dom.Element.tag('head');
      doc.documentElement?.nodes.insert(0, head);
    }

    if (doc.querySelector('meta[name="viewport"]') == null) {
      final viewport = dom.Element.tag('meta')
        ..attributes['name'] = 'viewport'
        ..attributes['content'] = 'width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no';
      head.append(viewport);
    }

    final style = dom.Element.tag('style')
      ..text = '''
        html, body { margin:0; padding:16px; }
        img { max-width:100% !important; height:auto !important; }
        body, table, td, th { word-wrap:break-word; overflow-wrap:anywhere; }
      ''';
    head.append(style);

    return doc;
  }

  String _buildHtmlTemplate(String bodyContent) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
  <style>
    html, body { margin:0; padding:16px; color:#222; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; }
    img { max-width:100% !important; height:auto !important; display:block; border-radius: 8px; }
    a { color:#0a84ff; text-decoration:none; }
    a:hover { text-decoration:underline; }
    table { max-width: 100%; border-collapse: collapse; margin: 16px 0; }
    th, td { padding: 8px; text-align: left; }
    body, table, td, th { word-wrap:break-word; overflow-wrap:anywhere; }
    pre { background:#f6f7f8; padding:12px; border-radius:6px; overflow:auto; }
    blockquote { margin:12px 0; padding-left:12px; border-left:3px solid #0a84ff33; color:#555; }
  </style>
</head>
<body>
$bodyContent
</body>
</html>
''';
  }

  void _showErrorSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }
}