class Contact {
  final String id;
  final String phoneNumber;
  final String? displayName;
  final String? profileImageUrl;
  final String? notes;
  final String? company;
  final String? email;
  final String? address;
  final List<String>? tags;

  const Contact({
    required this.id,
    required this.phoneNumber,
    this.displayName,
    this.profileImageUrl,
    this.notes,
    this.company,
    this.email,
    this.address,
    this.tags,
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'].toString(),
      phoneNumber: json['phoneNumber'] as String? ?? json['phone_number'] as String? ?? '',
      displayName: json['displayName'] as String? ?? json['display_name'] as String?,
      profileImageUrl: json['profileImageUrl'] as String? ?? json['profile_image_url'] as String?,
      notes: json['notes'] as String?,
      company: json['company'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'phoneNumber': phoneNumber,
        'displayName': displayName,
        'profileImageUrl': profileImageUrl,
        'notes': notes,
        'company': company,
        'email': email,
        'address': address,
        'tags': tags,
      };

  String get nameOrPhone => displayName ?? phoneNumber;
}
