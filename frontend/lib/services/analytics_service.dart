import '../config/api_config.dart';
import 'http_client.dart';

// Data models 

class AnalyticsSummary {
  final int totalProjects;
  final double averageDefectRate;
  final double maxDefectRate;

  const AnalyticsSummary({
    required this.totalProjects,
    required this.averageDefectRate,
    required this.maxDefectRate,
  });

  factory AnalyticsSummary.fromJson(Map<String, dynamic> j) => AnalyticsSummary(
    totalProjects: (j['totalProjects'] as num?)?.toInt() ?? 0,
    averageDefectRate: (j['averageDefectRate'] as num?)?.toDouble() ?? 0.0,
    maxDefectRate: (j['maxDefectRate'] as num?)?.toDouble() ?? 0.0,
  );

  static const empty = AnalyticsSummary(
    totalProjects: 0,
    averageDefectRate: 0,
    maxDefectRate: 0,
  );
}

class CategoryCount {
  final String category;
  final int count;
  const CategoryCount({required this.category, required this.count});

  factory CategoryCount.fromJson(Map<String, dynamic> j) => CategoryCount(
    category: j['category']?.toString() ?? '',
    count: (j['count'] as num?)?.toInt() ?? 0,
  );
}

class SeverityCount {
  final String severity;
  final int count;
  const SeverityCount({required this.severity, required this.count});

  factory SeverityCount.fromJson(Map<String, dynamic> j) => SeverityCount(
    severity: j['severity']?.toString() ?? '',
    count: (j['count'] as num?)?.toInt() ?? 0,
  );
}

class ProjectDR {
  final String project;
  final double defectRate;
  const ProjectDR({required this.project, required this.defectRate});

  factory ProjectDR.fromJson(Map<String, dynamic> j) => ProjectDR(
    project: j['project']?.toString() ?? '',
    defectRate: (j['defectRate'] as num?)?.toDouble() ?? 0.0,
  );
}

class TeamLeaderDR {
  final String teamLeader;
  final double avgDR;
  final int projectCount;
  const TeamLeaderDR({
    required this.teamLeader,
    required this.avgDR,
    required this.projectCount,
  });

  factory TeamLeaderDR.fromJson(Map<String, dynamic> j) => TeamLeaderDR(
    teamLeader: j['teamLeader']?.toString() ?? '',
    avgDR: (j['avgDR'] as num?)?.toDouble() ?? 0.0,
    projectCount: (j['projectCount'] as num?)?.toInt() ?? 0,
  );
}

class DefectDetail {
  final String projectNumber;
  final String projectName;
  final String teamLeader;
  final String executor;
  final String defectCategory;
  final String defectSeverity;
  final String reviewerRemark;

  const DefectDetail({
    required this.projectNumber,
    required this.projectName,
    required this.teamLeader,
    required this.executor,
    required this.defectCategory,
    required this.defectSeverity,
    required this.reviewerRemark,
  });

  factory DefectDetail.fromJson(Map<String, dynamic> j) => DefectDetail(
    projectNumber: j['project_number']?.toString() ?? '',
    projectName: j['project_name']?.toString() ?? '',
    teamLeader: j['team_leader']?.toString() ?? '',
    executor: j['executor']?.toString() ?? '',
    defectCategory: j['defect_category']?.toString() ?? '',
    defectSeverity: j['defect_severity']?.toString() ?? '',
    reviewerRemark: j['reviewer_remark']?.toString() ?? '',
  );
}

class AnalyticsProjectItem {
  final String id;
  final String name;
  final String no;
  const AnalyticsProjectItem({
    required this.id,
    required this.name,
    required this.no,
  });

  factory AnalyticsProjectItem.fromJson(Map<String, dynamic> j) =>
      AnalyticsProjectItem(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        no: j['no']?.toString() ?? '',
      );

  String get displayName => name.isNotEmpty ? name : no;
}

// Service 

class AnalyticsService {
  final SimpleHttp _http;

  AnalyticsService(this._http);

  // Build query parameters map (omit null/empty values)
  Map<String, String> _q({
    String? teamLeader,
    String? project,
    String? defectCategory,
    String? executor,
    String? page,
    String? limit,
    String? search,
  }) {
    final p = <String, String>{};
    if (teamLeader != null && teamLeader.isNotEmpty)
      p['teamLeader'] = teamLeader;
    if (project != null && project.isNotEmpty) p['project'] = project;
    if (defectCategory != null && defectCategory.isNotEmpty) {
      p['defectCategory'] = defectCategory;
    }
    if (executor != null && executor.isNotEmpty) p['executor'] = executor;
    if (page != null) p['page'] = page;
    if (limit != null) p['limit'] = limit;
    if (search != null && search.isNotEmpty) p['search'] = search;
    return p;
  }

  Future<AnalyticsSummary> getSummary({
    String? teamLeader,
    String? project,
    String? defectCategory,
    String? executor,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/analytics/summary').replace(
      queryParameters: _q(
        teamLeader: teamLeader,
        project: project,
        defectCategory: defectCategory,
        executor: executor,
      ),
    );
    final res = await _http.getJson(uri);
    final data = res['data'];
    if (data is Map<String, dynamic>) return AnalyticsSummary.fromJson(data);
    return AnalyticsSummary.empty;
  }

  Future<List<CategoryCount>> getTopDefectCategories({
    String? teamLeader,
    String? project,
    String? defectCategory,
    String? executor,
  }) async {
    final uri =
        Uri.parse(
          '${ApiConfig.baseUrl}/analytics/top-defect-categories',
        ).replace(
          queryParameters: _q(
            teamLeader: teamLeader,
            project: project,
            defectCategory: defectCategory,
            executor: executor,
          ),
        );
    final res = await _http.getJson(uri);
    final list = res['data'] as List? ?? [];
    return list
        .cast<Map<String, dynamic>>()
        .map(CategoryCount.fromJson)
        .toList();
  }

  Future<List<CategoryCount>> getAllDefectCategories({
    String? teamLeader,
    String? project,
    String? defectCategory,
    String? executor,
  }) async {
    final uri =
        Uri.parse(
          '${ApiConfig.baseUrl}/analytics/all-defect-categories',
        ).replace(
          queryParameters: _q(
            teamLeader: teamLeader,
            project: project,
            defectCategory: defectCategory,
            executor: executor,
          ),
        );
    final res = await _http.getJson(uri);
    final list = res['data'] as List? ?? [];
    return list
        .cast<Map<String, dynamic>>()
        .map(CategoryCount.fromJson)
        .toList();
  }

  Future<List<SeverityCount>> getDefectSeverityDistribution({
    String? teamLeader,
    String? project,
    String? defectCategory,
    String? executor,
  }) async {
    final uri =
        Uri.parse(
          '${ApiConfig.baseUrl}/analytics/defect-severity-distribution',
        ).replace(
          queryParameters: _q(
            teamLeader: teamLeader,
            project: project,
            defectCategory: defectCategory,
            executor: executor,
          ),
        );
    final res = await _http.getJson(uri);
    final list = res['data'] as List? ?? [];
    return list
        .cast<Map<String, dynamic>>()
        .map(SeverityCount.fromJson)
        .toList();
  }

  Future<({List<DefectDetail> data, int total, int page, int limit})>
  getDefectDetails({
    String? teamLeader,
    String? project,
    String? defectCategory,
    String? executor,
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/analytics/defect-details')
        .replace(
          queryParameters: _q(
            teamLeader: teamLeader,
            project: project,
            defectCategory: defectCategory,
            executor: executor,
            page: page.toString(),
            limit: limit.toString(),
            search: search,
          ),
        );
    final res = await _http.getJson(uri);
    final d = res['data'] as Map<String, dynamic>? ?? {};
    final list = (d['data'] as List? ?? []).cast<Map<String, dynamic>>();
    return (
      data: list.map(DefectDetail.fromJson).toList(),
      total: (d['total'] as num?)?.toInt() ?? 0,
      page: (d['page'] as num?)?.toInt() ?? 1,
      limit: (d['limit'] as num?)?.toInt() ?? 20,
    );
  }

  Future<List<String>> getTeamLeaders() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/analytics/team-leaders');
    final res = await _http.getJson(uri);
    return ((res['data'] as List?) ?? []).cast<String>();
  }

  Future<List<String>> getDefectCategories() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/analytics/defect-categories');
    final res = await _http.getJson(uri);
    return ((res['data'] as List?) ?? []).cast<String>();
  }

  Future<List<String>> getExecutors() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/analytics/executors');
    final res = await _http.getJson(uri);
    return ((res['data'] as List?) ?? []).cast<String>();
  }

  Future<List<ProjectDR>> getDrByProject({
    String? teamLeader,
    String? executor,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/analytics/dr-by-project')
        .replace(
          queryParameters: _q(teamLeader: teamLeader, executor: executor),
        );
    final res = await _http.getJson(uri);
    final list = res['data'] as List? ?? [];
    return list.cast<Map<String, dynamic>>().map(ProjectDR.fromJson).toList();
  }

  Future<List<TeamLeaderDR>> getDrByTeamLeader({String? executor}) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/analytics/dr-by-team-leader',
    ).replace(queryParameters: executor != null ? _q(executor: executor) : {});
    final res = await _http.getJson(uri);
    final list = res['data'] as List? ?? [];
    return list
        .cast<Map<String, dynamic>>()
        .map(TeamLeaderDR.fromJson)
        .toList();
  }

  Future<List<AnalyticsProjectItem>> getProjects() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/analytics/projects');
    final res = await _http.getJson(uri);
    final list = res['data'] as List? ?? [];
    return list
        .cast<Map<String, dynamic>>()
        .map(AnalyticsProjectItem.fromJson)
        .toList();
  }
}
