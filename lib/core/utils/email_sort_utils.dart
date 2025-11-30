import '../models/email_message.dart';

/// 邮件排序方式
enum EmailSortType {
  dateDesc('时间降序', '最新的在前'),
  dateAsc('时间升序', '最旧的在前'),
  senderAsc('发件人升序', 'A-Z'),
  senderDesc('发件人降序', 'Z-A'),
  subjectAsc('主题升序', 'A-Z'),
  subjectDesc('主题降序', 'Z-A'),
  unreadFirst('未读优先', '未读邮件在前'),
  starredFirst('收藏优先', '收藏邮件在前');

  const EmailSortType(this.displayName, this.description);
  final String displayName;
  final String description;
}

/// 邮件筛选类型
enum EmailFilterType {
  all('全部'),
  unread('未读'),
  starred('收藏'),
  archived('已归档'),
  today('今日'),
  week('本周'),
  month('本月');

  const EmailFilterType(this.displayName);
  final String displayName;
}

/// 邮件排序和筛选工具类
class EmailSortUtils {
  /// 对邮件列表进行排序
  static List<EmailMessage> sortEmails(
    List<EmailMessage> emails,
    EmailSortType sortType,
  ) {
    final sorted = List<EmailMessage>.from(emails);

    switch (sortType) {
      case EmailSortType.dateDesc:
        sorted.sort((a, b) => b.receivedDate.compareTo(a.receivedDate));
        break;
      case EmailSortType.dateAsc:
        sorted.sort((a, b) => a.receivedDate.compareTo(b.receivedDate));
        break;
      case EmailSortType.senderAsc:
        sorted.sort((a, b) => a.senderEmail.compareTo(b.senderEmail));
        break;
      case EmailSortType.senderDesc:
        sorted.sort((a, b) => b.senderEmail.compareTo(a.senderEmail));
        break;
      case EmailSortType.subjectAsc:
        sorted.sort((a, b) => a.subject.compareTo(b.subject));
        break;
      case EmailSortType.subjectDesc:
        sorted.sort((a, b) => b.subject.compareTo(a.subject));
        break;
      case EmailSortType.unreadFirst:
        sorted.sort((a, b) {
          if (a.isRead == b.isRead) {
            return b.receivedDate.compareTo(a.receivedDate);
          }
          return a.isRead ? 1 : -1;
        });
        break;
      case EmailSortType.starredFirst:
        sorted.sort((a, b) {
          if (a.isStarred == b.isStarred) {
            return b.receivedDate.compareTo(a.receivedDate);
          }
          return a.isStarred ? -1 : 1;
        });
        break;
    }

    return sorted;
  }

  /// 对邮件列表进行筛选
  static List<EmailMessage> filterEmails(
    List<EmailMessage> emails,
    EmailFilterType filterType,
  ) {
    final now = DateTime.now();

    switch (filterType) {
      case EmailFilterType.all:
        return emails;
      case EmailFilterType.unread:
        return emails.where((e) => !e.isRead).toList();
      case EmailFilterType.starred:
        return emails.where((e) => e.isStarred).toList();
      case EmailFilterType.archived:
        return emails.where((e) => e.isArchived).toList();
      case EmailFilterType.today:
        final startOfDay = DateTime(now.year, now.month, now.day);
        return emails.where((e) => e.receivedDate.isAfter(startOfDay)).toList();
      case EmailFilterType.week:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final startOfWeekDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        return emails.where((e) => e.receivedDate.isAfter(startOfWeekDay)).toList();
      case EmailFilterType.month:
        final startOfMonth = DateTime(now.year, now.month, 1);
        return emails.where((e) => e.receivedDate.isAfter(startOfMonth)).toList();
    }
  }

  /// 组合排序和筛选
  static List<EmailMessage> sortAndFilter(
    List<EmailMessage> emails,
    EmailSortType sortType,
    EmailFilterType filterType,
  ) {
    final filtered = filterEmails(emails, filterType);
    return sortEmails(filtered, sortType);
  }
}
