import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../../core/models/email_message.dart';
import '../../../../core/repositories/email_repository.dart';
import '../../../../core/theme/app_theme.dart';

class MarkdownNoteEditorPage extends StatefulWidget {
  final EmailMessage email;

  const MarkdownNoteEditorPage({super.key, required this.email});

  @override
  State<MarkdownNoteEditorPage> createState() => _MarkdownNoteEditorPageState();
}

class _MarkdownNoteEditorPageState extends State<MarkdownNoteEditorPage> with SingleTickerProviderStateMixin {
  late final TextEditingController _noteController;
  late final TabController _tabController;
  final EmailRepository _emailRepository = EmailRepository();
  bool _isSaving = false;
  final ScrollController _previewScrollController = ScrollController();
  String _previewText = ''; // 用于实时预览

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.email.notes);
    _previewText = widget.email.notes ?? '';
    _tabController = TabController(length: 2, vsync: this);
    
    // 监听文本变化，实时更新预览
    _noteController.addListener(() {
      setState(() {
        _previewText = _noteController.text;
      });
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    _tabController.dispose();
    _previewScrollController.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final updatedEmail = widget.email.copyWith(notes: _noteController.text);
      await _emailRepository.updateEmail(updatedEmail);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('笔记已保存'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('保存失败: $e')),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _insertMarkdown(String markdown) {
    final text = _noteController.text;
    final selection = _noteController.selection;
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      markdown,
    );
    _noteController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + markdown.length,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑笔记'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.edit), text: '编辑'),
            Tab(icon: Icon(Icons.visibility), text: '预览'),
          ],
        ),
        actions: [
          if (_tabController.index == 0)
            PopupMenuButton<String>(
              icon: const Icon(Icons.text_format),
              tooltip: 'Markdown 格式',
              onSelected: (value) {
                switch (value) {
                  case 'bold':
                    _insertMarkdown('**粗体文字**');
                    break;
                  case 'italic':
                    _insertMarkdown('*斜体文字*');
                    break;
                  case 'heading':
                    _insertMarkdown('## 标题');
                    break;
                  case 'list':
                    _insertMarkdown('- 列表项');
                    break;
                  case 'code':
                    _insertMarkdown('`代码`');
                    break;
                  case 'codeblock':
                    _insertMarkdown('```\n代码块\n```');
                    break;
                  case 'link':
                    _insertMarkdown('[链接文字](https://example.com)');
                    break;
                  case 'image':
                    _showImageDialog();
                    break;
                  case 'quote':
                    _insertMarkdown('> 引用文字');
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'bold',
                  child: Row(
                    children: [
                      Icon(Icons.format_bold),
                      SizedBox(width: 8),
                      Text('粗体'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'italic',
                  child: Row(
                    children: [
                      Icon(Icons.format_italic),
                      SizedBox(width: 8),
                      Text('斜体'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'heading',
                  child: Row(
                    children: [
                      Icon(Icons.title),
                      SizedBox(width: 8),
                      Text('标题'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'list',
                  child: Row(
                    children: [
                      Icon(Icons.format_list_bulleted),
                      SizedBox(width: 8),
                      Text('列表'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'code',
                  child: Row(
                    children: [
                      Icon(Icons.code),
                      SizedBox(width: 8),
                      Text('行内代码'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'codeblock',
                  child: Row(
                    children: [
                      Icon(Icons.code_outlined),
                      SizedBox(width: 8),
                      Text('代码块'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'link',
                  child: Row(
                    children: [
                      Icon(Icons.link),
                      SizedBox(width: 8),
                      Text('链接'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'image',
                  child: Row(
                    children: [
                      Icon(Icons.image),
                      SizedBox(width: 8),
                      Text('图片'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'quote',
                  child: Row(
                    children: [
                      Icon(Icons.format_quote),
                      SizedBox(width: 8),
                      Text('引用'),
                    ],
                  ),
                ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Markdown 帮助',
            onPressed: _showMarkdownHelp,
          ),
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.only(right: 16.0),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.save),
                  tooltip: '保存',
                  onPressed: _saveNote,
                ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEditorTab(),
          _buildPreviewTab(),
        ],
      ),
    );
  }

  Widget _buildEditorTab() {
    return Column(
      children: [
        // 邮件信息
        Container(
          padding: const EdgeInsets.all(16.0),
          color: AppTheme.surfaceColor,
          child: Row(
            children: [
              const Icon(Icons.email, size: 20, color: AppTheme.textSecondaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.email.subject,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondaryColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        // 编辑器
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _noteController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
                fontFamily: 'monospace',
              ),
              decoration: const InputDecoration(
                hintText: '在这里输入你的笔记...\n\n支持 Markdown 格式：\n- **粗体** 或 *斜体*\n- # 标题\n- - 列表\n- `代码`\n- [链接](url)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewTab() {
    return Column(
      children: [
        // 邮件信息
        Container(
          padding: const EdgeInsets.all(16.0),
          color: AppTheme.surfaceColor,
          child: Row(
            children: [
              const Icon(Icons.email, size: 20, color: AppTheme.textSecondaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.email.subject,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondaryColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        // 预览 - 使用实时更新的文本
        Expanded(
          child: _previewText.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.visibility_off,
                        size: 64,
                        color: AppTheme.textSecondaryColor,
                      ),
                      SizedBox(height: 16),
                      Text(
                        '暂无内容',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : Markdown(
                  controller: _previewScrollController,
                  data: _previewText,
                  selectable: true,
                  // 改进的样式表
                  styleSheet: MarkdownStyleSheet(
                    // 段落样式 - 支持换行
                    p: const TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: AppTheme.textPrimaryColor,
                    ),
                    // 标题样式
                    h1: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor,
                      height: 1.3,
                    ),
                    h2: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor,
                      height: 1.3,
                    ),
                    h3: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor,
                      height: 1.3,
                    ),
                    h4: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor,
                    ),
                    // 行内代码样式 - 改进
                    code: TextStyle(
                      backgroundColor: const Color(0xFFF5F5F5),
                      color: const Color(0xFFD73A49),
                      fontFamily: 'Consolas, Monaco, monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    // 代码块样式 - 改进
                    codeblockPadding: const EdgeInsets.all(16),
                    codeblockDecoration: BoxDecoration(
                      color: const Color(0xFF2D2D2D),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF404040)),
                    ),
                    codeblockAlign: WrapAlignment.start,
                    // 列表样式
                    listBullet: const TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: AppTheme.textPrimaryColor,
                    ),
                    listIndent: 24,
                    // 引用样式
                    blockquote: const TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: AppTheme.textSecondaryColor,
                      fontStyle: FontStyle.italic,
                    ),
                    blockquoteDecoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      border: const Border(
                        left: BorderSide(
                          color: AppTheme.primaryColor,
                          width: 4,
                        ),
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    blockquotePadding: const EdgeInsets.all(12),
                    // 链接样式
                    a: const TextStyle(
                      color: AppTheme.primaryColor,
                      decoration: TextDecoration.underline,
                    ),
                    // 分隔线样式
                    horizontalRuleDecoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                    ),
                    // 段落间距
                    pPadding: const EdgeInsets.only(bottom: 12),
                    h1Padding: const EdgeInsets.only(top: 16, bottom: 8),
                    h2Padding: const EdgeInsets.only(top: 14, bottom: 6),
                    h3Padding: const EdgeInsets.only(top: 12, bottom: 4),
                  ),
                  // 支持软换行
                  softLineBreak: true,
                ),
        ),
      ],
    );
  }

  void _showImageDialog() {
    final urlController = TextEditingController();
    final altController = TextEditingController(text: '图片描述');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.image, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('插入图片'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: '图片链接',
                hintText: 'https://example.com/image.jpg',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: altController,
              decoration: const InputDecoration(
                labelText: '图片描述（可选）',
                hintText: '图片的替代文字',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '请使用图片的完整 URL 地址',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final url = urlController.text.trim();
              final alt = altController.text.trim();
              if (url.isNotEmpty) {
                _insertMarkdown('![$alt]($url)');
              }
              Navigator.pop(context);
            },
            child: const Text('插入'),
          ),
        ],
      ),
    );
  }

  void _showMarkdownHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('Markdown 语法帮助'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpItem('标题', '# 一级标题\n## 二级标题\n### 三级标题'),
              _buildHelpItem('粗体', '**粗体文字**'),
              _buildHelpItem('斜体', '*斜体文字*'),
              _buildHelpItem('列表', '- 列表项 1\n- 列表项 2\n- 列表项 3'),
              _buildHelpItem('有序列表', '1. 第一项\n2. 第二项\n3. 第三项'),
              _buildHelpItem('行内代码', '`行内代码`'),
              _buildHelpItem('代码块', '```\n代码块内容\n```'),
              _buildHelpItem('链接', '[链接文字](https://example.com)'),
              _buildHelpItem('图片', '![图片描述](图片URL)'),
              _buildHelpItem('引用', '> 引用的文字'),
              _buildHelpItem('分隔线', '---'),
              _buildHelpItem('删除线', '~~删除的文字~~'),
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

  Widget _buildHelpItem(String title, String example) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              example,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
