class ProjectMembership {
  String id;
  String projectId;
  String userId;
  String roleId;

  // Populated fields from backend
  String? userName;
  String? userEmail;
  String? roleName;
  String? roleDescription;
  DateTime? createdAt;

  ProjectMembership({
    required this.id,
    required this.projectId,
    required this.userId,
    required this.roleId,
    this.userName,
    this.userEmail,
    this.roleName,
    this.roleDescription,
    this.createdAt,
  });

  factory ProjectMembership.fromJson(Map<String, dynamic> json) {
    // Handle populated user_id
    final userData = json['user_id'];
    String userId;
    String? userName;
    String? userEmail;

    if (userData is Map<String, dynamic>) {
      userId = (userData['_id'] ?? userData['id']).toString();
      userName = userData['name']?.toString();
      userEmail = userData['email']?.toString();
    } else {
      userId = userData.toString();
    }

    // Handle populated role
    final roleData = json['role'];
    String roleId;
    String? roleName;
    String? roleDescription;

    if (roleData is Map<String, dynamic>) {
      roleId = (roleData['_id'] ?? roleData['id']).toString();
      roleName = roleData['role_name']?.toString();
      roleDescription = roleData['description']?.toString();
    } else {
      roleId = roleData.toString();
    }

    return ProjectMembership(
      id: (json['_id'] ?? json['id']).toString(),
      projectId: json['project_id'] is Map
          ? (json['project_id']['_id'] ?? json['project_id']['id']).toString()
          : json['project_id'].toString(),
      userId: userId,
      roleId: roleId,
      userName: userName,
      userEmail: userEmail,
      roleName: roleName,
      roleDescription: roleDescription,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {'project_id': projectId, 'user_id': userId, 'role_id': roleId};
  }
}
