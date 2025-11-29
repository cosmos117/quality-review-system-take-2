import 'dart:async';
import '../config/api_config.dart';
import '../models/project.dart';
import 'http_client.dart';

class ProjectService {
  final SimpleHttp http;
  Timer? _pollTimer;
  final _projectsController = StreamController<List<Project>>.broadcast();

  ProjectService(this.http);

  Project _fromApi(Map<String, dynamic> j) {
    final id = (j['_id'] ?? j['id']).toString();
    final title = (j['project_name'] ?? '').toString();
    final statusRaw = (j['status'] ?? '').toString();
    final status = switch (statusRaw) {
      'pending' => 'Not Started',
      'in_progress' => 'In Progress',
      'completed' => 'Completed',
      _ => 'Not Started',
    };
    final startedStr = (j['start_date'] ?? j['started']).toString();
    final started = DateTime.tryParse(startedStr) ?? DateTime.now();

    // Handle populated created_by field
    String? creatorId;
    String? creatorName;
    final createdBy = j['created_by'];
    if (createdBy is Map<String, dynamic>) {
      creatorId = (createdBy['_id'] ?? createdBy['id']).toString();
      creatorName = createdBy['name']?.toString();
    } else if (createdBy != null) {
      creatorId = createdBy.toString();
    }

    return Project(
      id: id,
      title: title.isEmpty ? 'Untitled' : title,
      description: null, // Can add if needed
      started: started,
      priority: 'Medium', // not in backend model; default
      status: status,
      executor: creatorName ?? creatorId, // Use creator name or ID
      assignedEmployees: null, // Fetched separately via ProjectMembership
    );
  }

  Map<String, dynamic> _toApi(Project p, {String? userId}) {
    String status = switch (p.status) {
      'In Progress' => 'in_progress',
      'Completed' => 'completed',
      _ => 'pending',
    };
    return {
      'project_name': p.title,
      'status': status,
      'start_date': p.started.toIso8601String(),
      if (userId != null) 'created_by': userId,
    };
  }

  Future<List<Project>> getAll() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/projects');
    final json = await http.getJson(uri);
    final data = (json['data'] as List).cast<dynamic>();
    return data.map((e) => _fromApi(e as Map<String, dynamic>)).toList();
  }

  Future<Project> create(Project p, {required String userId}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/projects');
    final json = await http.postJson(uri, _toApi(p, userId: userId));
    return _fromApi(json['data'] as Map<String, dynamic>);
  }

  Future<Project> update(Project p) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/projects/${p.id}');
    final json = await http.putJson(uri, _toApi(p));
    return _fromApi(json['data'] as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    final uri = Uri.parse('\${ApiConfig.baseUrl}/projects/\$id');
    await http.delete(uri);
  }

  Stream<List<Project>> getProjectsStream({
    Duration interval = const Duration(seconds: 3),
  }) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(interval, (_) async {
      try {
        final projects = await getAll();
        if (!_projectsController.isClosed) {
          _projectsController.add(projects);
        }
      } catch (e) {
        if (!_projectsController.isClosed) {
          _projectsController.addError(e);
        }
      }
    });
    // Immediately fetch initial data
    getAll()
        .then((projects) {
          if (!_projectsController.isClosed) {
            _projectsController.add(projects);
          }
        })
        .catchError((e) {
          if (!_projectsController.isClosed) {
            _projectsController.addError(e);
          }
        });
    return _projectsController.stream;
  }

  void dispose() {
    _pollTimer?.cancel();
    _projectsController.close();
  }
}
