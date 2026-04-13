import '../utils/time_formatter.dart';

class Message {
  final String id;
  final String conversationId;
  final String? twilioSid;
  final String direction;
  final String senderType;
  final String? senderId;
  final String? body;
  final String? mediaUrl;
  final String? mediaContentType;
  final String status;
  final DateTime createdAt;
  final bool isOptimistic;
  final String? replyToId;
  final String? replyBody;
  final String? replySenderType;
  final String? replySenderName;
  final String? senderName;
  final String? senderEmail;

  const Message({
    required this.id,
    required this.conversationId,
    this.twilioSid,
    required this.direction,
    required this.senderType,
    this.senderId,
    this.body,
    this.mediaUrl,
    this.mediaContentType,
    required this.status,
    required this.createdAt,
    this.isOptimistic = false,
    this.replyToId,
    this.replyBody,
    this.replySenderType,
    this.replySenderName,
    this.senderName,
    this.senderEmail,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'].toString(),
      conversationId: (json['conversationId'] ?? json['conversation_id']).toString(),
      twilioSid: json['twilioSid'] as String? ?? json['twilio_sid'] as String?,
      direction: json['direction'] as String,
      senderType: json['senderType'] as String? ?? json['sender_type'] as String? ?? 'staff',
      senderId: json['senderId']?.toString() ?? json['sender_id']?.toString(),
      body: json['body'] as String?,
      mediaUrl: json['mediaUrl'] as String? ?? json['media_url'] as String?,
      mediaContentType: json['mediaContentType'] as String? ?? json['media_content_type'] as String?,
      status: json['status'] as String? ?? 'sent',
      createdAt: TimeFormatter.parseUtc(json['createdAt'] ?? json['created_at']),
      replyToId: json['replyToId']?.toString() ?? json['reply_to_id']?.toString(),
      replyBody: json['replyBody'] as String? ?? json['reply_body'] as String?,
      replySenderType: json['replySenderType'] as String? ?? json['reply_sender_type'] as String?,
      replySenderName: json['replySenderName'] as String? ?? json['reply_sender_name'] as String?,
      senderName: json['senderName'] as String? ?? json['sender_name'] as String?,
      senderEmail: json['senderEmail'] as String? ?? json['sender_email'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversationId': conversationId,
        'twilioSid': twilioSid,
        'direction': direction,
        'senderType': senderType,
        'senderId': senderId,
        'body': body,
        'mediaUrl': mediaUrl,
        'mediaContentType': mediaContentType,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        'replyToId': replyToId,
      };

  bool get isOutgoing => direction == 'outbound';
  bool get isIncoming => direction == 'inbound';
  bool get isFailed => status == 'failed';
  bool get isUndelivered => status == 'undelivered';
  bool get hasMedia => mediaUrl != null && mediaUrl!.isNotEmpty;
  bool get hasReply => replyToId != null && replyBody != null;

  Message copyWith({String? id, String? status, bool? isOptimistic}) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId,
      twilioSid: twilioSid,
      direction: direction,
      senderType: senderType,
      senderId: senderId,
      body: body,
      mediaUrl: mediaUrl,
      mediaContentType: mediaContentType,
      status: status ?? this.status,
      createdAt: createdAt,
      isOptimistic: isOptimistic ?? this.isOptimistic,
      replyToId: replyToId,
      replyBody: replyBody,
      replySenderType: replySenderType,
      replySenderName: replySenderName,
      senderName: senderName,
      senderEmail: senderEmail,
    );
  }
}
