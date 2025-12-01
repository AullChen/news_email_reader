import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class MarkdownHelpCard extends StatelessWidget {
  const MarkdownHelpCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              children: [
                Icon(Icons.help_outline, color: AppTheme.primaryColor),
                SizedBox(width: 8),
                Text(
                  'Markdown 快速参考',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildHelpRow('**粗体**', '粗体文字'),
            _buildHelpRow('*斜体*', '斜体文字'),
            _buildHelpRow('# 标题', '一级标题'),
            _buildHelpRow('## 标题', '二级标题'),
            _buildHelpRow('- 项目', '无序列表'),
            _buildHelpRow('1. 项目', '有序列表'),
            _buildHelpRow('`代码`', '行内代码'),
            _buildHelpRow('[文字](链接)', '超链接'),
            _buildHelpRow('> 引用', '引用块'),
            _buildHelpRow('---', '分隔线'),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpRow(String syntax, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                syntax,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              description,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
