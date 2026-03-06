class Role {
  String id;
  String roleName;
  String? description;
  DateTime? createdAt;
  DateTime? updatedAt;

  Role({
    required this.id,
    required this.roleName,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      id: (json['_id'] ?? json['id']).toString(),
      roleName: (json['role_name'] ?? '').toString(),
      description: json['description']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role_name': roleName,
      if (description != null) 'description': description,
    };
  }

  Role copyWith({
    String? id,
    String? roleName,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Role(
      id: id ?? this.id,
      roleName: roleName ?? this.roleName,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
