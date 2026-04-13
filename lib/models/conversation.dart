import 'contact.dart';
import '../utils/time_formatter.dart';

class Conversation {
  final String id;
  final Contact contact;
  final String? assignedTo;
  final String? lastMessageText;
  final String? lastMessageDirection;
  final String? lastMessageStatus;
  final String? lastMessageSenderName;
  final DateTime? lastMessageAt;
  final DateTime? lastInboundAt;
  final int unreadCount;
  final bool isArchived;
  final bool isStarred;

  const Conversation({
    required this.id,
    required this.contact,
    this.assignedTo,
    this.lastMessageText,
    this.lastMessageDirection,
    this.lastMessageStatus,
    this.lastMessageSenderName,
    this.lastMessageAt,
    this.lastInboundAt,
    this.unreadCount = 0,
    this.isArchived = false,
    this.isStarred = false,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    // Backend may return contact as nested object or as flat fields
    final Contact contact;
    if (json['contact'] is Map<String, dynamic>) {
      contact = Contact.fromJson(json['contact'] as Map<String, dynamic>);
    } else {
      contact = Contact.fromJson({
        'id': json['contact_id'] ?? json['contactId'] ?? '',
        'phoneNumber': json['phone_number'] ?? json['phoneNumber'] ?? '',
        'displayName': json['display_name'] ?? json['displayName'],
        'profileImageUrl': json['profile_image_url'] ?? json['profileImageUrl'],
        'notes': json['notes'],
      });
    }

    return Conversation(
      id: json['id'].toString(),
      contact: contact,
      assignedTo: json['assignedTo']?.toString() ?? json['assigned_to']?.toString(),
      lastMessageText: json['lastMessageText'] as String? ?? json['last_message_text'] as String?,
      lastMessageDirection: json['lastMessageDirection'] as String? ?? json['last_message_direction'] as String?,
      lastMessageStatus: json['lastMessageStatus'] as String? ?? json['last_message_status'] as String?,
      lastMessageSenderName: json['lastMessageSenderName'] as String? ?? json['last_message_sender_name'] as String?,
      lastMessageAt: _parseNullableUtc(json['lastMessageAt'] ?? json['last_message_at']),
      lastInboundAt: _parseNullableUtc(json['lastInboundAt'] ?? json['last_inbound_at']),
      unreadCount: (json['unreadCount'] ?? json['unread_count'] ?? 0) as int,
      isArchived: (json['isArchived'] ?? json['is_archived'] ?? false) as bool,
      isStarred: (json['isStarred'] ?? json['is_starred'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'contact': contact.toJson(),
        'assignedTo': assignedTo,
        'lastMessageText': lastMessageText,
        'lastMessageDirection': lastMessageDirection,
        'lastMessageStatus': lastMessageStatus,
        'lastMessageSenderName': lastMessageSenderName,
        'lastMessageAt': lastMessageAt?.toIso8601String(),
        'lastInboundAt': lastInboundAt?.toIso8601String(),
        'unreadCount': unreadCount,
        'isArchived': isArchived,
        'isStarred': isStarred,
      };

  bool get isLastMessageOutgoing => lastMessageDirection == 'outbound';

  Conversation copyWith({
    String? lastMessageText,
    String? lastMessageDirection,
    String? lastMessageStatus,
    String? lastMessageSenderName,
    DateTime? lastMessageAt,
    DateTime? lastInboundAt,
    int? unreadCount,
    bool? isArchived,
    bool? isStarred,
    String? assignedTo,
  }) {
    return Conversation(
      id: id,
      contact: contact,
      assignedTo: assignedTo ?? this.assignedTo,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      lastMessageDirection: lastMessageDirection ?? this.lastMessageDirection,
      lastMessageStatus: lastMessageStatus ?? this.lastMessageStatus,
      lastMessageSenderName: lastMessageSenderName ?? this.lastMessageSenderName,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastInboundAt: lastInboundAt ?? this.lastInboundAt,
      unreadCount: unreadCount ?? this.unreadCount,
      isArchived: isArchived ?? this.isArchived,
      isStarred: isStarred ?? this.isStarred,
    );
  }

  static DateTime? _parseNullableUtc(dynamic value) {
    if (value == null) return null;
    return TimeFormatter.parseUtc(value);
  }
}
