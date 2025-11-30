class Project {
  String id;
  String? projectNo;
  String? internalOrderNo;
  String title;
  String? description;
  DateTime started;
  String priority; // Low, Medium, High
  String status; // Pending, In Progress, Completed
  String? executor;
  List<String>? assignedEmployees;

  Project({
    required this.id,
    this.projectNo,
    this.internalOrderNo,
    required this.title,
    this.description,
    required this.started,
    required this.priority,
    required this.status,
    this.executor,
    this.assignedEmployees,
  });

  Project copyWith({
    String? id,
    String? projectNo,
    String? internalOrderNo,
    String? title,
    String? description,
    DateTime? started,
    String? priority,
    String? status,
    String? executor,
    List<String>? assignedEmployees,
  }) {
    return Project(
      id: id ?? this.id,
      projectNo: projectNo ?? this.projectNo,
      internalOrderNo: internalOrderNo ?? this.internalOrderNo,
      title: title ?? this.title,
      description: description ?? this.description,
      started: started ?? this.started,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      executor: executor ?? this.executor,
      assignedEmployees: assignedEmployees ?? this.assignedEmployees,
    );
  }
}
