import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'ai_config_dialog.dart';

/// AI 配置引导卡片
class AISetupGuideCard extends StatelessWidget {
  final bool isUsingDefault;
  
  const AISetupGuideCard({super.key, this.isUsingDefault = true});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isUsingDefault ? Colors.blue.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isUsingDefault ? Icons.tips_and_updates : Icons.info_outline,
                  color: isUsingDefault ? Colors.blue.shade700 : Colors.orange.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  isUsingDefault ? '升级 AI 服务' : '首次使用提示',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isUsingDefault ? Colors.blue.shade700 : Colors.orange.shade700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              isUsingDefault
                  ? '当前使用免费 AI 服务（可能较慢或繁忙）\n配置自己的 AI 服务可获得更快更稳定的体验。'
                  : 'AI 总结功能需要配置 AI 服务才能使用。',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              '推荐配置：',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
            const SizedBox(height: 4),
            _buildRecommendation(
              '• 智谱AI（免费）',
              '国内访问快，有免费额度',
              Icons.star,
              Colors.amber,
            ),
            _buildRecommendation(
              '• DeepSeek（便宜）',
              '¥0.3/1M tokens，性价比最高',
              Icons.attach_money,
              Colors.green,
            ),
            _buildRecommendation(
              '• OpenAI（效果好）',
              'GPT-4o-mini，效果最佳',
              Icons.psychology,
              Colors.blue,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showConfigDialog(context),
                icon: Icon(isUsingDefault ? Icons.upgrade : Icons.settings),
                label: Text(isUsingDefault ? '升级配置' : '立即配置'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isUsingDefault ? Colors.blue : AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendation(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showConfigDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => const AIConfigDialog(),
    );
  }
}
