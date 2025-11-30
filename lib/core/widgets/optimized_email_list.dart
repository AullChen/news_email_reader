import 'package:flutter/material.dart';
import '../models/email_message.dart';

/// 高性能邮件列表组件 - 使用 ListView.builder 的原生优化
class OptimizedEmailList extends StatefulWidget {
  final List<EmailMessage> emails;
  final Function(EmailMessage) onEmailTap;
  final Function(EmailMessage)? onStar;
  final Function(EmailMessage)? onArchive;
  final Function(EmailMessage)? onDelete;
  final Function(EmailMessage)? onMarkRead;
  final VoidCallback? onLoadMore;
  final bool hasMore;
  final bool isLoading;
  final ScrollController? scrollController;

  const OptimizedEmailList({
    super.key,
    required this.emails,
    required this.onEmailTap,
    this.onStar,
    this.onArchive,
    this.onDelete,
    this.onMarkRead,
    this.onLoadMore,
    this.hasMore = false,
    this.isLoading = false,
    this.scrollController,
  });

  @override
  State<OptimizedEmailList> createState() => _OptimizedEmailListState();
}

class _OptimizedEmailListState extends State<OptimizedEmailList> {
  late ScrollController _scrollController;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    if (widget.scrollController == null) {
      _scrollController.dispose();
    } else {
      _scrollController.removeListener(_onScroll);
    }
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore || !widget.hasMore || widget.onLoadMore == null) {
      return;
    }

    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    
    // 当滚动到距离底部 300px 时触发加载更多
    if (maxScroll - currentScroll <= 300) {
      _isLoadingMore = true;
      widget.onLoadMore!();
      Future.delayed(const Duration(milliseconds: 500), () {
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.emails.isEmpty) {
      return const Center(
        child: Text('暂无邮件'),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      // 关键优化：增加缓存范围，减少重建
      cacheExtent: 2000,
      // 关键优化：添加 itemExtent 提示，提升滚动性能
      // itemExtent: 140, // 如果所有项目高度一致，取消注释此行
      itemCount: widget.emails.length + (widget.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        // 加载更多指示器
        if (index == widget.emails.length) {
          return _buildLoadMoreIndicator();
        }

        final email = widget.emails[index];
        
        // 使用 RepaintBoundary 隔离重绘
        return RepaintBoundary(
          child: LightweightEmailCard(
            key: ValueKey(email.messageId),
            email: email,
            onTap: () => widget.onEmailTap(email),
            onStar: widget.onStar != null ? () => widget.onStar!(email) : null,
            onArchive: widget.onArchive != null ? () => widget.onArchive!(email) : null,
            onDelete: widget.onDelete != null ? () => widget.onDelete!(email) : null,
            onMarkRead: widget.onMarkRead != null ? () => widget.onMarkRead!(email) : null,
          ),
        );
      },
    );
  }

  Widget _buildLoadMoreIndicator() {
    if (!widget.hasMore) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: widget.isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const SizedBox.shrink(),
    );
  }
}

/// 轻量级邮件卡片 - 移除复杂动画和手势
class LightweightEmailCard extends StatelessWidget {
  final EmailMessage email;
  final VoidCallback onTap;
  final VoidCallback? onStar;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;
  final VoidCallback? onMarkRead;

  const LightweightEmailCard({
    super.key,
    required this.email,
    required this.onTap,
    this.onStar,
    this.onArchive,
    this.onDelete,
    this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        onLongPress: _showActions,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: email.isRead ? null : theme.primaryColor.withOpacity(0.05),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头部：发件人和时间
              Row(
                children: [
                  // 头像
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: theme.primaryColor,
                    child: Text(
                      _getInitial(email.senderName ?? email.senderEmail),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // 发件人信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          email.senderName ?? '未知发件人',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          email.senderEmail,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // 时间和状态图标
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatTime(email.receivedDate),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (email.isStarred)
                            const Icon(Icons.star, color: Colors.amber, size: 14),
                          if (email.isArchived)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(Icons.archive, color: Colors.green, size: 14),
                            ),
                          if (email.aiSummary != null && email.aiSummary!.isNotEmpty)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(Icons.auto_awesome, color: Colors.purple, size: 14),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 主题
              Text(
                email.subject,
                style: TextStyle(
                  fontWeight: email.isRead ? FontWeight.normal : FontWeight.w600,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // 内容预览
              Text(
                email.contentText ?? '无内容',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showActions() {
    // 长按显示操作菜单（简化版）
    // 这里可以实现一个简单的底部菜单
  }

  String _getInitial(String name) {
    if (name.isEmpty) return '?';
    return name[0].toUpperCase();
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
}
