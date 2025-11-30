import 'package:flutter/material.dart';
import '../models/email_message.dart';
import '../theme/app_theme.dart';

/// 可左滑的邮件卡片组件
class SwipeableEmailCard extends StatefulWidget {
  final EmailMessage email;
  final VoidCallback onTap;
  final VoidCallback? onStar;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;
  final VoidCallback? onMarkRead;

  const SwipeableEmailCard({
    super.key,
    required this.email,
    required this.onTap,
    this.onStar,
    this.onArchive,
    this.onDelete,
    this.onMarkRead,
  });

  @override
  State<SwipeableEmailCard> createState() => _SwipeableEmailCardState();
}

class _SwipeableEmailCardState extends State<SwipeableEmailCard> {
  bool _showActions = false;

  void _toggleActions() {
    setState(() {
      _showActions = !_showActions;
    });
  }

  void _closeActions() {
    if (_showActions) {
      setState(() {
        _showActions = false;
      });
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: InkWell(
        onTap: () {
          if (_showActions) {
            _closeActions();
          } else {
            widget.onTap();
          }
        },
        onLongPress: _toggleActions,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: widget.email.isRead
                ? null
                : theme.primaryColor.withOpacity(0.05),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.primaryColor,
                    child: Text(
                      (widget.email.senderName?.isNotEmpty == true)
                          ? widget.email.senderName![0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.email.senderName ?? '未知发件人',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          widget.email.senderEmail,
                          style: TextStyle(
                            color: AppTheme.textSecondaryColor,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatTime(widget.email.receivedDate),
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.email.isStarred)
                            const Icon(
                              Icons.star,
                              color: AppTheme.secondaryColor,
                              size: 14,
                            ),
                          if (widget.email.isArchived)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.archive,
                                color: Colors.green,
                                size: 14,
                              ),
                            ),
                          if (widget.email.aiSummary != null &&
                              widget.email.aiSummary!.isNotEmpty)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.auto_awesome,
                                size: 14,
                                color: Colors.purple,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.email.subject,
                style: TextStyle(
                  fontWeight: widget.email.isRead
                      ? FontWeight.normal
                      : FontWeight.w600,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                widget.email.contentText ?? '无内容',
                style: TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 12,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              // 显示操作按钮
              if (_showActions) ...[
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (widget.onMarkRead != null)
                      _buildQuickAction(
                        icon: widget.email.isRead ? Icons.mark_email_unread : Icons.mark_email_read,
                        label: widget.email.isRead ? '未读' : '已读',
                        color: Colors.blue,
                        onTap: () {
                          _closeActions();
                          widget.onMarkRead?.call();
                        },
                      ),
                    if (widget.onStar != null)
                      _buildQuickAction(
                        icon: widget.email.isStarred ? Icons.star_border : Icons.star,
                        label: widget.email.isStarred ? '取消' : '收藏',
                        color: Colors.amber,
                        onTap: () {
                          _closeActions();
                          widget.onStar?.call();
                        },
                      ),
                    if (widget.onArchive != null)
                      _buildQuickAction(
                        icon: Icons.archive,
                        label: '归档',
                        color: Colors.green,
                        onTap: () {
                          _closeActions();
                          widget.onArchive?.call();
                        },
                      ),
                    if (widget.onDelete != null)
                      _buildQuickAction(
                        icon: Icons.delete,
                        label: '删除',
                        color: Colors.red,
                        onTap: () {
                          _closeActions();
                          widget.onDelete?.call();
                        },
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

}
