class EmailMessage {
  final int? id;
  final int accountId;
  final String messageId;
  final String subject;
  final String? senderName;
  final String senderEmail;
  final String? recipientEmail;
  final String? contentText;
  final String? contentHtml;
  final DateTime receivedDate;
  final bool isRead;
  final bool isStarred;
  final bool isCached;
  final bool isArchived;
  final String? aiSummary;
  final String? notes;
  final double? readingProgress;
  final DateTime createdAt;

  EmailMessage({
    this.id,
    required this.accountId,
    required this.messageId,
    required this.subject,
    this.senderName,
    required this.senderEmail,
    this.recipientEmail,
    this.contentText,
    this.contentHtml,
    required this.receivedDate,
    this.isRead = false,
    this.isStarred = false,
    this.isCached = false,
    this.isArchived = false,
    this.aiSummary,
    this.notes,
    this.readingProgress,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'account_id': accountId,
      'message_id': messageId,
      'subject': subject,
      'sender_name': senderName,
      'sender_email': senderEmail,
      'recipient_email': recipientEmail,
      'content_text': contentText,
      'content_html': contentHtml,
      'received_date': receivedDate.toIso8601String(),
      'is_read': isRead ? 1 : 0,
      'is_starred': isStarred ? 1 : 0,
      'is_cached': isCached ? 1 : 0,
      'is_archived': isArchived ? 1 : 0,
      'ai_summary': aiSummary,
      'notes': notes,
      'reading_progress': readingProgress,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory EmailMessage.fromMap(Map<String, dynamic> map) {
    return EmailMessage(
      id: map['id'],
      accountId: map['account_id'],
      messageId: map['message_id'],
      subject: map['subject'],
      senderName: map['sender_name'],
      senderEmail: map['sender_email'],
      recipientEmail: map['recipient_email'],
      contentText: map['content_text'],
      contentHtml: map['content_html'],
      receivedDate: DateTime.parse(map['received_date']),
      isRead: map['is_read'] == 1,
      isStarred: map['is_starred'] == 1,
      isCached: map['is_cached'] == 1,
      isArchived: map['is_archived'] == 1,
      aiSummary: map['ai_summary'],
      notes: map['notes'],
      readingProgress: map['reading_progress'] != null ? (map['reading_progress'] as num).toDouble() : null,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  // JSON序列化支持
  Map<String, dynamic> toJson() {
    return {
      'id': id?.toString(),
      'accountId': accountId,
      'messageId': messageId,
      'subject': subject,
      'senderName': senderName,
      'senderEmail': senderEmail,
      'recipientEmail': recipientEmail,
      'contentText': contentText,
      'contentHtml': contentHtml,
      'receivedDate': receivedDate.toIso8601String(),
      'isRead': isRead,
      'isStarred': isStarred,
      'isCached': isCached,
      'isArchived': isArchived,
      'aiSummary': aiSummary,
      'notes': notes,
      'readingProgress': readingProgress,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory EmailMessage.fromJson(Map<String, dynamic> json) {
    return EmailMessage(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      accountId: json['accountId'] ?? 0,
      messageId: json['messageId'] ?? '',
      subject: json['subject'] ?? '',
      senderName: json['senderName'],
      senderEmail: json['senderEmail'] ?? '',
      recipientEmail: json['recipientEmail'],
      contentText: json['contentText'],
      contentHtml: json['contentHtml'],
      receivedDate: DateTime.parse(json['receivedDate']),
      isRead: json['isRead'] ?? false,
      isStarred: json['isStarred'] ?? false,
      isCached: json['isCached'] ?? false,
      isArchived: json['isArchived'] ?? false,
      aiSummary: json['aiSummary'],
      notes: json['notes'],
      readingProgress: json['readingProgress'] != null ? (json['readingProgress'] as num).toDouble() : null,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  EmailMessage copyWith({
    int? id,
    int? accountId,
    String? messageId,
    String? subject,
    String? senderName,
    String? senderEmail,
    String? recipientEmail,
    String? contentText,
    String? contentHtml,
    DateTime? receivedDate,
    bool? isRead,
    bool? isStarred,
    bool? isCached,
    bool? isArchived,
    String? aiSummary,
    String? notes,
    double? readingProgress,
    DateTime? createdAt,
  }) {
    return EmailMessage(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      messageId: messageId ?? this.messageId,
      subject: subject ?? this.subject,
      senderName: senderName ?? this.senderName,
      senderEmail: senderEmail ?? this.senderEmail,
      recipientEmail: recipientEmail ?? this.recipientEmail,
      contentText: contentText ?? this.contentText,
      contentHtml: contentHtml ?? this.contentHtml,
      receivedDate: receivedDate ?? this.receivedDate,
      isRead: isRead ?? this.isRead,
      isStarred: isStarred ?? this.isStarred,
      isCached: isCached ?? this.isCached,
      isArchived: isArchived ?? this.isArchived,
      aiSummary: aiSummary ?? this.aiSummary,
      notes: notes ?? this.notes,
      readingProgress: readingProgress ?? this.readingProgress,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get displaySender => senderName ?? senderEmail;
  
  String get previewContent {
    if (contentText != null && contentText!.isNotEmpty) {
      return contentText!.length > 100 
          ? '${contentText!.substring(0, 100)}...'
          : contentText!;
    }
    if (contentHtml != null && contentHtml!.isNotEmpty) {
      // 简单的HTML标签移除
      String text = contentHtml!.replaceAll(RegExp(r'<[^>]*>'), '');
      return text.length > 100 ? '${text.substring(0, 100)}...' : text;
    }
    return '无内容预览';
  }
}