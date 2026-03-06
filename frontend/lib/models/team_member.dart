class TeamMember {
  String id;
  String name;
  String email;
  String role;
  String status;
  String dateAdded;
  String lastActive;
  String? password;

  TeamMember({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    required this.dateAdded,
    required this.lastActive,
  this.password,
  });

  TeamMember copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    String? status,
    String? dateAdded,
    String? lastActive,
    String? password,
  }) {
    return TeamMember(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      status: status ?? this.status,
      dateAdded: dateAdded ?? this.dateAdded,
      lastActive: lastActive ?? this.lastActive,
      password: password ?? this.password,
    );
  }
}
