import 'package:flutter/material.dart';

enum SpendingNotificationType {
  dailyReport,
  budgetWarning,
  budgetExceeded,
  reminder,
  milestone,
  categoryUpdate,
  recurringReminder,
}

class SpendingNotification {
  final String id;
  final SpendingNotificationType type;
  final String title;
  final String message;
  final DateTime timestamp;
  final DateTime expiresAt;
  final bool isRead;
  final DateTime? reportDate;
  final String? parentId;

  const SpendingNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.expiresAt,
    this.isRead = false,
    this.reportDate,
    this.parentId,
  });

  SpendingNotification copyWith({
    String? id,
    SpendingNotificationType? type,
    String? title,
    String? message,
    DateTime? timestamp,
    DateTime? expiresAt,
    bool? isRead,
    DateTime? reportDate,
    String? parentId,
  }) {
    return SpendingNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      expiresAt: expiresAt ?? this.expiresAt,
      isRead: isRead ?? this.isRead,
      reportDate: reportDate ?? this.reportDate,
      parentId: parentId ?? this.parentId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'message': message,
    'timestamp': timestamp.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
    'isRead': isRead,
    'reportDate': reportDate?.toIso8601String(),
    'parentId': parentId,
  };

  factory SpendingNotification.fromJson(Map<String, dynamic> json) {
    final typeName =
        json['type'] as String? ?? SpendingNotificationType.reminder.name;
    final type = SpendingNotificationType.values.firstWhere(
      (candidate) => candidate.name == typeName,
      orElse: () => SpendingNotificationType.reminder,
    );

    return SpendingNotification(
      id: json['id'] as String,
      type: type,
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      timestamp: DateTime.parse(json['timestamp'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      isRead: (json['isRead'] as bool?) ?? false,
      reportDate: json['reportDate'] != null
          ? DateTime.parse(json['reportDate'] as String)
          : null,
      parentId: json['parentId'] as String?,
    );
  }
}

IconData iconForNotificationType(SpendingNotificationType type) {
  switch (type) {
    case SpendingNotificationType.dailyReport:
      return Icons.picture_as_pdf_rounded;
    case SpendingNotificationType.budgetWarning:
      return Icons.warning_amber_rounded;
    case SpendingNotificationType.budgetExceeded:
      return Icons.error_rounded;
    case SpendingNotificationType.reminder:
      return Icons.notifications_active_rounded;
    case SpendingNotificationType.milestone:
      return Icons.emoji_events_rounded;
    case SpendingNotificationType.categoryUpdate:
      return Icons.category_rounded;
    case SpendingNotificationType.recurringReminder:
      return Icons.event_repeat_rounded;
  }
}
