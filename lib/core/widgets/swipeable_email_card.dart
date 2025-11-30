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

class _SwipeableEmailCardState extends State<SwipeableEmailCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  double _dragExtent = 0;
  bool _dragUnderway = false;

  static const double _kSwipeThreshold = 80.0;
  static const double _kMaxSlide = 200.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.3, 0),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details) {
    _dragUnderway = true;
    _controller.stop();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_dragUnderway) return;

    final delta = details.primaryDelta ?? 0;
    _dragExtent += delta;

    // 限制滑动范围
    if (_dragExtent > 0) {
      _dragExtent = 0;
    } else if (_dragExtent < -_kMaxSlide) {
      _dragExtent = -_kMaxSlide;
    }

    setState(() {
      _controller.value = -_dragExtent / _kMaxSlide;
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!_dragUnderway) return;
    _dragUnderway = false;

    final velocity = details.primaryVelocity ?? 0;
    
    // 根据滑动距离和速度决定是否展开
    if (_dragExtent < -_kSwipeThreshold || velocity < -300) {
      _controller.forward();
    } else {
      _controller.reverse();
      _dragExtent = 0;
    }
  }

  void _closeActions() {
    _controller.reverse();
    _dragExtent = 0;
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
    return GestureDetector(
      onHorizontalDragStart: _handleDragStart,
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      child: Stack(
        children: [
          // 背景操作按钮
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.onMarkRead != null)
                    _buildActionButton(
                      icon: widget.email.isRead ? Icons.mark_email_unread : Icons.mark_email_read,
                      color: Colors.blue,
                      onTap: () {
                        _closeActions();
                        widget.onMarkRead?.call();
                      },
                    ),
                  if (widget.onStar != null)
                    _buildActionButton(
                      icon: widget.email.isStarred ? Icons.star_border : Icons.star,
                      color: Colors.amber,
                      onTap: () {
                        _closeActions();
                        widget.onStar?.call();
                      },
                    ),
                  if (widget.onArchive != null)
                    _buildActionButton(
                      icon: Icons.archive,
                      color: Colors.green,
                      onTap: () {
                        _closeActions();
                        widget.onArchive?.call();
                      },
                    ),
                  if (widget.onDelete != null)
                    _buildActionButton(
                      icon: Icons.delete,
                      color: Colors.red,
                      onTap: () {
                        _closeActions();
                        widget.onDelete?.call();
                      },
                    ),
                ],
              ),
            ),
          ),
          // 邮件卡片
          SlideTransition(
            position: _slideAnimation,
            child: Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () {
                  if (_controller.value > 0) {
                    _closeActions();
                  } else {
                    widget.onTap();
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: widget.email.isRead
                        ? null
                        : Theme.of(context).primaryColor.withValues(alpha: 0.05),
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
                              (widget.email.senderName?.isNotEmpty == true)
                                  ? widget.email.senderName![0].toUpperCase()
                                  : '?',
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
                                  widget.email.senderName ?? '未知发件人',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  widget.email.senderEmail,
                                  style: TextStyle(
                                    color: AppTheme.textSecondaryColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _formatTime(widget.email.receivedDate),
                            style: TextStyle(
                              color: AppTheme.textSecondaryColor,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (widget.email.isStarred)
                            const Icon(
                              Icons.star,
                              color: AppTheme.secondaryColor,
                              size: 16,
                            ),
                          if (widget.email.isArchived)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.archive,
                                color: Colors.green,
                                size: 16,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.email.subject,
                              style: TextStyle(
                                fontWeight: widget.email.isRead
                                    ? FontWeight.normal
                                    : FontWeight.w500,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.email.aiSummary != null &&
                              widget.email.aiSummary!.isNotEmpty) ...[
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
                        widget.email.contentText ?? '无内容',
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
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
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}
