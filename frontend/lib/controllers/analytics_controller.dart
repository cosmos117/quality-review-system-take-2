import 'package:get/get.dart';
import '../services/analytics_service.dart';

class AnalyticsController extends GetxController {
  final AnalyticsService _service;

  AnalyticsController(this._service);

  // Filter state 
  final selectedTeamLeader = RxnString();
  final selectedProject = RxnString(); // project name (display key)
  final selectedDefectCategory = RxnString();
  final selectedExecutor = RxnString();

  // Dropdown options 
  final teamLeaders = RxList<String>();
  final projects = RxList<AnalyticsProjectItem>();
  final defectCategories = RxList<String>();
  final executors = RxList<String>();

  // Analytics data 
  final summary = Rx<AnalyticsSummary>(AnalyticsSummary.empty);
  final allDefectCategories = RxList<CategoryCount>();
  final topDefectCategories = RxList<CategoryCount>();
  final defectSeverityDist = RxList<SeverityCount>();
  final drByProject = RxList<ProjectDR>();
  final drByTeamLeader = RxList<TeamLeaderDR>();
  final defectDetails = RxList<DefectDetail>();

  // Pagination 
  final currentPage = 1.obs;
  final totalRecords = 0.obs;
  static const pageSize = 10;
  final searchQuery = ''.obs;

  // Loading flags 
  final isSummaryLoading = false.obs;
  final isChartsLoading = false.obs;
  final isTableLoading = false.obs;
  final isOptionsLoading = false.obs;

  // Error messages 
  final summaryError = RxnString();
  final chartsError = RxnString();
  final tableError = RxnString();

  @override
  void onInit() {
    super.onInit();
    _loadFilterOptions();
    loadAll();
  }

  // Helpers 

  String? get _tl => selectedTeamLeader.value;
  String? get _proj => selectedProject.value;
  String? get _cat => selectedDefectCategory.value;
  String? get _exc => selectedExecutor.value;

  // Filter options loading 

  Future<void> _loadFilterOptions() async {
    isOptionsLoading.value = true;
    try {
      final results = await Future.wait([
        _service.getTeamLeaders(),
        _service.getDefectCategories(),
        _service.getProjects(),
        _service.getExecutors(),
      ]);
      teamLeaders.value = results[0] as List<String>;
      defectCategories.value = results[1] as List<String>;
      projects.value = results[2] as List<AnalyticsProjectItem>;
      executors.value = results[3] as List<String>;

      // Reset selected values if they no longer exist
      if (selectedTeamLeader.value != null &&
          !teamLeaders.contains(selectedTeamLeader.value)) {
        selectedTeamLeader.value = null;
      }
      if (selectedProject.value != null &&
          !projects.any((p) => p.name == selectedProject.value)) {
        selectedProject.value = null;
      }
      if (selectedDefectCategory.value != null &&
          !defectCategories.contains(selectedDefectCategory.value)) {
        selectedDefectCategory.value = null;
      }
      if (selectedExecutor.value != null &&
          !executors.contains(selectedExecutor.value)) {
        selectedExecutor.value = null;
      }
    } catch (_) {
      // Non-critical  keep empty lists
    } finally {
      isOptionsLoading.value = false;
    }
  }

  // Data loading 

  Future<void> loadAll() async {
    await Future.wait([
      loadSummary(),
      loadCharts(),
      loadTable(),
      _loadFilterOptions(),
    ]);
  }

  Future<void> loadSummary() async {
    isSummaryLoading.value = true;
    summaryError.value = null;
    try {
      summary.value = await _service.getSummary(
        teamLeader: _tl,
        project: _proj,
        defectCategory: _cat,
        executor: _exc,
      );
    } catch (e) {
      summaryError.value = e.toString();
    } finally {
      isSummaryLoading.value = false;
    }
  }

  Future<void> loadCharts() async {
    isChartsLoading.value = true;
    chartsError.value = null;
    try {
      final results = await Future.wait([
        _service.getAllDefectCategories(
          teamLeader: _tl,
          project: _proj,
          defectCategory: _cat,
          executor: _exc,
        ),
        _service.getTopDefectCategories(
          teamLeader: _tl,
          project: _proj,
          defectCategory: _cat,
          executor: _exc,
        ),
        _service.getDefectSeverityDistribution(
          teamLeader: _tl,
          project: _proj,
          defectCategory: _cat,
          executor: _exc,
        ),
        _service.getDrByProject(teamLeader: _tl, executor: _exc),
        _service.getDrByTeamLeader(executor: _exc),
      ]);
      allDefectCategories.value = results[0] as List<CategoryCount>;
      topDefectCategories.value = results[1] as List<CategoryCount>;
      defectSeverityDist.value = results[2] as List<SeverityCount>;
      drByProject.value = results[3] as List<ProjectDR>;
      drByTeamLeader.value = results[4] as List<TeamLeaderDR>;
    } catch (e) {
      chartsError.value = e.toString();
    } finally {
      isChartsLoading.value = false;
    }
  }

  Future<void> loadTable({bool resetPage = true}) async {
    isTableLoading.value = true;
    tableError.value = null;
    if (resetPage) currentPage.value = 1;
    try {
      final result = await _service.getDefectDetails(
        teamLeader: _tl,
        project: _proj,
        defectCategory: _cat,
        executor: _exc,
        page: currentPage.value,
        limit: pageSize,
        search: searchQuery.value.isNotEmpty ? searchQuery.value : null,
      );
      defectDetails.value = result.data;
      totalRecords.value = result.total;
    } catch (e) {
      tableError.value = e.toString();
    } finally {
      isTableLoading.value = false;
    }
  }

  // Filter actions 

  void applyTeamLeader(String? value) {
    selectedTeamLeader.value = value;
    loadAll();
  }

  void applyProject(String? value) {
    selectedProject.value = value;
    loadAll();
  }

  void applyDefectCategory(String? value) {
    selectedDefectCategory.value = value;
    loadAll();
  }

  void applyExecutor(String? value) {
    selectedExecutor.value = value;
    loadAll();
  }

  void applySearch(String value) {
    searchQuery.value = value;
    loadTable();
  }

  // Pagination 

  int get totalPages => (totalRecords.value / pageSize).ceil().clamp(1, 9999);

  void goToPage(int page) {
    if (page < 1 || page > totalPages) return;
    currentPage.value = page;
    loadTable(resetPage: false);
  }
}
