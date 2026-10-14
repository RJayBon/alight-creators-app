class ContactMessage {
  ContactMessage({
    this.messageId,
    required this.name,
    required this.email,
    required this.message,
    this.createdAt,
  });

  int? messageId;
  String name;
  String email;
  String message;
  String? createdAt;

  factory ContactMessage.fromMap(Map<String, dynamic> m) => ContactMessage(
        messageId: m['message_id'] as int?,
        name: (m['name'] as String?) ?? '',
        email: (m['email'] as String?) ?? '',
        message: (m['message'] as String?) ?? '',
        createdAt: m['created_at'] as String?,
      );
}