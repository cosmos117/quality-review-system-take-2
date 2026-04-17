import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/analytics_controller.dart';

// -- Colour palette ------------------------------------------------------------

const _kPrimary = Color(0xFF0F766E);
const _kSuccess = Color(0xFF166534);
const _kWarning = Color(0xFFF59E0B);
const _kDanger = Color(0xFFB91C1C);

const _kBlue = _kPrimary;
const _kOrange = _kWarning;
const _kGreen = _kSuccess;
const _kRed = _kDanger;

const _kGreenDarkest = Color(0xFF14532D);
const _kGreenDark = Color(0xFF166534);
const _kGreenMid = Color(0xFF15803D);
const _kGreenMedium = Color(0xFF16A34A);
const _kGreenLight = Color(0xFF4ADE80);

const _kDeepTeal = Color(0xFF0F766E);
const _kTealMid = Color(0xFF0D9488);
const _kGreenSoft = Color(0xFF166534);
const _kSlate = Color(0xFF64748B);
const _kStone = Color(0xFF94A3B8);

const List<Color> _kChartColors = [
  _kDeepTeal,
  _kTealMid,
  _kGreenSoft,
  _kSlate,
  _kStone,
];

const List<Color> _kDefectCategoryPalette = [
  _kDeepTeal,
  _kTealMid,
  _kGreenSoft,
  _kSlate,
  _kStone,
];

List<Color> _distinctCategoryColors(int count) {
  if (count <= 0) return const [];
  final seed = _kDefectCategoryPalette;
  return List.generate(count, (i) {
    if (i < seed.length) return seed[i];
    final hue = (i * 137.508) % 360;
    final saturation = (0.72 - (i % 3) * 0.08).clamp(0.45, 0.9).toDouble();
    final lightness = (0.48 + (i % 4) * 0.07).clamp(0.35, 0.75).toDouble();
    return HSLColor.fromAHSL(1, hue, saturation, lightness).toColor();
  });
}

Color _severityColor(String s) {
  switch (s.toLowerCase()) {
    case 'critical':
      return _kRed;
    case 'non-critical':
      return _kOrange;
    default:
      return _kBlue;
  }
}

// Color by defect rate risk level (for Project DR chart)
Color _riskLevelColor(double defectRate) {
  if (defectRate >= 15) {
    return _kRed; // High
  } else if (defectRate >= 8) {
    return _kOrange; // Medium
  } else {
    return _kGreen; // Low
  }
}

// Green shade by value intensity (for Team Leader chart)
Color _greenShadeByValue(double value, double maxValue) {
  if (maxValue == 0) return _kGreenLight;
  final ratio = value / maxValue;
  if (ratio >= 0.8) return _kGreenDarkest;
  if (ratio >= 0.6) return _kGreenDark;
  if (ratio >= 0.4) return _kGreenMid;
  if (ratio >= 0.2) return _kGreenMedium;
  return _kGreenLight;
}

// Page

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AnalyticsController>();
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            color: Colors.white,
            child: Row(
              children: [
                Text(
                  'Analytics Dashboard',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  onPressed: () => ctrl.loadAll(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Filter bar
          _FilterBar(ctrl),

          // Page content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Row 1: KPI cards
                  _KpiRow(ctrl),
                  const SizedBox(height: 24),

                  // Row 2: All defect categories + DR by team leader
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _CardWrapper(
                          title: 'All Defect Categories',
                          child: _AllDefectCategoriesChart(ctrl),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 2,
                        child: _CardWrapper(
                          title: 'Average Defect Rate by Team Leader',
                          child: _DrByTeamLeaderChart(ctrl),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Row 3: Top defect categories + Severity distribution
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _CardWrapper(
                          title: 'Top Defect Categories',
                          child: _TopDefectCategoriesChart(ctrl),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 2,
                        child: _CardWrapper(
                          title: 'Defect Severity Distribution',
                          child: _SeverityPieChart(ctrl),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Row 4: DR by project
                  _CardWrapper(
                    title: 'Overall Defect Rate by Project',
                    child: _DrByProjectChart(ctrl),
                  ),
                  const SizedBox(height: 24),

                  // Row 5: Defect details table
                  _CardWrapper(
                    title: 'Defect Details',
                    child: _DefectDetailsTable(ctrl),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Filter bar

class _FilterBar extends StatelessWidget {
  final AnalyticsController ctrl;
  const _FilterBar(this.ctrl);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Obx(
        () => Row(
          children: [
            const Text(
              'Filters:',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
            ),
            const SizedBox(width: 16),
            _FilterDropdown<String>(
              label: 'Team Leader',
              value: ctrl.selectedTeamLeader.value,
              items: ctrl.teamLeaders,
              onChanged: ctrl.applyTeamLeader,
            ),
            const SizedBox(width: 12),
            _FilterDropdown<String>(
              label: 'Executor',
              value: ctrl.selectedExecutor.value,
              items: ctrl.executors,
              onChanged: ctrl.applyExecutor,
            ),
            const SizedBox(width: 12),
            _FilterDropdown<String>(
              label: 'Project',
              value: ctrl.selectedProject.value,
              items: ctrl.projects.map((p) => p.displayName).toList(),
              onChanged: ctrl.applyProject,
            ),
            const SizedBox(width: 12),
            _FilterDropdown<String>(
              label: 'Defect Category',
              value: ctrl.selectedDefectCategory.value,
              items: ctrl.defectCategories,
              onChanged: ctrl.applyDefectCategory,
            ),
            const SizedBox(width: 16),
            // Reset button
            if (ctrl.selectedTeamLeader.value != null ||
                ctrl.selectedExecutor.value != null ||
                ctrl.selectedProject.value != null ||
                ctrl.selectedDefectCategory.value != null)
              TextButton.icon(
                onPressed: () {
                  ctrl.applyTeamLeader(null);
                  ctrl.applyExecutor(null);
                  ctrl.applyProject(null);
                  ctrl.applyDefectCategory(null);
                },
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('Clear'),
                style: TextButton.styleFrom(foregroundColor: _kDanger),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterDropdown<T extends String> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> items;
  final ValueChanged<T?> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[50],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          isDense: true,
          iconSize: 18,
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          items: [
            DropdownMenuItem<T>(
              value: null,
              child: Text('All $label', style: const TextStyle(fontSize: 13)),
            ),
            ...items.map(
              (v) => DropdownMenuItem<T>(
                value: v,
                child: Text(
                  v,
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// KPI Row

class _KpiRow extends StatelessWidget {
  final AnalyticsController ctrl;
  const _KpiRow(this.ctrl);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (ctrl.isSummaryLoading.value) {
        return const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        );
      }
      final s = ctrl.summary.value;
      return SizedBox(
        height: 140,
        child: Row(
          children: [
            Expanded(
              child: _KpiCard(
                label: 'Total Projects',
                value: s.totalProjects.toString(),
                icon: Icons.folder_open,
                color: _kBlue,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _KpiCard(
                label: 'Average DR',
                value: '${s.averageDefectRate.toStringAsFixed(2)}%',
                icon: Icons.bar_chart,
                color: _kOrange,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _KpiCard(
                label: 'Max DR',
                value: '${s.maxDefectRate.toStringAsFixed(2)}%',
                icon: Icons.trending_up,
                color: _kRed,
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Icon(icon, color: color, size: 26)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Chart row (two cards side by side)

// Card wrapper

class _CardWrapper extends StatelessWidget {
  final String title;
  final Widget child;

  const _CardWrapper({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

// All Defect Categories

class _AllDefectCategoriesChart extends StatelessWidget {
  final AnalyticsController ctrl;
  const _AllDefectCategoriesChart(this.ctrl);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (ctrl.isChartsLoading.value) return const _LoadingWidget();
      final data = ctrl.allDefectCategories;
      if (data.isEmpty) return const _EmptyWidget();

      final total = data.fold(0, (s, d) => s + d.count);
      final colors = _distinctCategoryColors(data.length);

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 200,
            height: 200,
            child: CustomPaint(
              painter: _PiePainter(
                values: data.map((d) => d.count.toDouble()).toList(),
                colors: colors,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: SizedBox(
              height: 220,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: data.asMap().entries.map((e) {
                    final pct = total > 0
                        ? (e.value.count / total * 100).toStringAsFixed(1)
                        : '0';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: colors[e.key],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Tooltip(
                              message: e.value.category,
                              child: Text(
                                e.value.category,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ),
                          Text(
                            '${e.value.count} ($pct%)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}

// Top Defect Categories  horizontal bar chart

class _TopDefectCategoriesChart extends StatelessWidget {
  final AnalyticsController ctrl;
  const _TopDefectCategoriesChart(this.ctrl);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (ctrl.isChartsLoading.value) {
        return const _LoadingWidget();
      }
      final data = ctrl.topDefectCategories;
      if (data.isEmpty) return const _EmptyWidget();

      final total = data.fold(0, (s, d) => s + d.count);
      final colors = _distinctCategoryColors(data.length);

      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Pie
          SizedBox(
            width: 180,
            height: 180,
            child: CustomPaint(
              painter: _PiePainter(
                values: data.map((d) => d.count.toDouble()).toList(),
                colors: colors,
              ),
            ),
          ),
          const SizedBox(width: 20),
          // Legend on right side
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: data.asMap().entries.map((e) {
                final pct = total > 0
                    ? (e.value.count / total * 100).toStringAsFixed(1)
                    : '0';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: colors[e.key],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Tooltip(
                          message: e.value.category,
                          child: Text(
                            e.value.category,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                      Text(
                        '${e.value.count} ($pct%)',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      );
    });
  }
}

// Severity Pie Chart

class _SeverityPieChart extends StatelessWidget {
  final AnalyticsController ctrl;
  const _SeverityPieChart(this.ctrl);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (ctrl.isChartsLoading.value) return const _LoadingWidget();
      final data = ctrl.defectSeverityDist;
      if (data.isEmpty) return const _EmptyWidget();

      final total = data.fold(0, (s, d) => s + d.count);
      final colors = data.asMap().map(
        (i, d) => MapEntry(i, _severityColor(d.severity)),
      );

      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Pie
          SizedBox(
            width: 180,
            height: 180,
            child: CustomPaint(
              painter: _PiePainter(
                values: data.map((d) => d.count.toDouble()).toList(),
                colors: List.generate(data.length, (i) => colors[i]!),
              ),
            ),
          ),
          const SizedBox(width: 20),
          // Legend
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: data.asMap().entries.map((e) {
                final pct = total > 0
                    ? (e.value.count / total * 100).toStringAsFixed(1)
                    : '0';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: colors[e.key],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          e.value.severity,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${e.value.count} ($pct%)',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      );
    });
  }
}

// DR by Project  horizontal bar chart

class _DrByProjectChart extends StatelessWidget {
  final AnalyticsController ctrl;
  const _DrByProjectChart(this.ctrl);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (ctrl.isChartsLoading.value) return const _LoadingWidget();
      final data = ctrl.drByProject;
      if (data.isEmpty) return const _EmptyWidget();
      return _RiskColoredHorizontalBarList(
        items: data
            .map((d) => (label: d.project, value: d.defectRate))
            .toList(),
        valueLabel: (v) => '${v.toStringAsFixed(1)}%',
      );
    });
  }
}

// DR by Team Leader  vertical bar chart

class _DrByTeamLeaderChart extends StatelessWidget {
  final AnalyticsController ctrl;
  const _DrByTeamLeaderChart(this.ctrl);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (ctrl.isChartsLoading.value) return const _LoadingWidget();
      final data = ctrl.drByTeamLeader;
      if (data.isEmpty) return const _EmptyWidget();
      return _GreenVerticalBarChart(
        items: data.map((d) => (label: d.teamLeader, value: d.avgDR)).toList(),
        valueLabel: (v) => '${v.toStringAsFixed(1)}%',
      );
    });
  }
}

// Reusable horizontal bar list

// Risk-colored horizontal bar list

class _RiskColoredHorizontalBarList extends StatelessWidget {
  final List<({String label, double value})> items;
  final String Function(double) valueLabel;

  const _RiskColoredHorizontalBarList({
    required this.items,
    required this.valueLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _EmptyWidget();
    final maxVal = items.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    const valueWidth = 72.0;
    const gap = 12.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final labelWidth = (available * 0.42).clamp(360.0, 520.0).toDouble();
        final barWidth = (available - labelWidth - valueWidth - (gap * 2))
            .clamp(140.0, 360.0)
            .toDouble();

        return Column(
          children: items.asMap().entries.map((entry) {
            final item = entry.value;
            final fraction = maxVal > 0
                ? (item.value / maxVal).clamp(0.03, 1.0).toDouble()
                : 0.0;
            final color = _riskLevelColor(item.value);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: labelWidth,
                    child: Tooltip(
                      message: item.label,
                      child: Text(
                        item.label,
                        style: const TextStyle(fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: gap),
                  SizedBox(
                    width: barWidth,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Container(
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: fraction,
                          child: Container(
                            height: 24,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: gap),
                  SizedBox(
                    width: valueWidth,
                    child: Text(
                      valueLabel(item.value),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// Green-colored horizontal bar list

// Reusable vertical bar chart

// Green-shaded vertical bar chart

class _GreenVerticalBarChart extends StatelessWidget {
  final List<({String label, double value})> items;
  final String Function(double) valueLabel;

  const _GreenVerticalBarChart({required this.items, required this.valueLabel});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _EmptyWidget();
    final maxVal = items.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    const chartHeight = 180.0;

    return SizedBox(
      height: chartHeight + 50,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: items.asMap().entries.map((entry) {
          final item = entry.value;
          final barH = maxVal > 0
              ? (item.value / maxVal * chartHeight).clamp(4.0, chartHeight)
              : 4.0;
          final color = _greenShadeByValue(item.value, maxVal);

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    valueLabel(item.value),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: barH,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Tooltip(
                    message: item.label,
                    child: Text(
                      item.label,
                      style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// Pie chart painter

class _PiePainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;

  const _PiePainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold(0.0, (s, v) => s + v);
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;
    final paint = Paint()..style = PaintingStyle.fill;

    double startAngle = -math.pi / 2;
    for (int i = 0; i < values.length; i++) {
      final sweep = values[i] / total * 2 * math.pi;
      paint.color = colors[i % colors.length];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        true,
        paint,
      );
      // Thin white divider between slices
      final divider = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        true,
        divider,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(_PiePainter old) =>
      old.values != values || old.colors != colors;
}

// Defect Details Table

class _DefectDetailsTable extends StatefulWidget {
  final AnalyticsController ctrl;
  const _DefectDetailsTable(this.ctrl);

  @override
  State<_DefectDetailsTable> createState() => _DefectDetailsTableState();
}

class _DefectDetailsTableState extends State<_DefectDetailsTable> {
  final _searchCtrl = TextEditingController();
  final _horizontalScrollController = ScrollController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) {
                  if (v.isEmpty) widget.ctrl.applySearch('');
                },
                onSubmitted: widget.ctrl.applySearch,
                decoration: InputDecoration(
                  hintText: 'Search by Project No., Project Name, Team Leader',
                  hintStyle: const TextStyle(fontSize: 13),
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            widget.ctrl.applySearch('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => widget.ctrl.applySearch(_searchCtrl.text),
              icon: const Icon(Icons.search, size: 16),
              label: const Text('Search'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Table
        Obx(() {
          if (widget.ctrl.isTableLoading.value) {
            return const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final rows = widget.ctrl.defectDetails;
          if (rows.isEmpty) return const _EmptyWidget(height: 120);

          return Column(
            children: [
              Scrollbar(
                controller: _horizontalScrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _horizontalScrollController,
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: const [
                            _FixedHeaderCell('Project No.', width: 160),
                            _FixedHeaderCell('Project Name', width: 320),
                            _FixedHeaderCell('Team Leader', width: 150),
                            _FixedHeaderCell('Executor', width: 150),
                            _FixedHeaderCell('Defect Category', width: 260),
                            _FixedHeaderCell('Severity', width: 130),
                            _FixedHeaderCell('Reviewer Remark', width: 320),
                          ],
                        ),
                      ),
                      // Data rows
                      ...rows.asMap().entries.map(
                        (e) => Container(
                          color: e.key.isEven
                              ? Colors.white
                              : Colors.grey.shade50,
                          child: Row(
                            children: [
                              _FixedDataCell(e.value.projectNumber, width: 160),
                              _TooltipDataCell(e.value.projectName, width: 320),
                              _FixedDataCell(e.value.teamLeader, width: 150),
                              _FixedDataCell(e.value.executor, width: 150),
                              _TooltipDataCell(
                                e.value.defectCategory,
                                width: 260,
                              ),
                              _FixedSeverityCell(
                                e.value.defectSeverity,
                                width: 130,
                              ),
                              _RemarkCell(e.value.reviewerRemark, width: 320),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(),
              // Pagination
              _Pagination(widget.ctrl),
            ],
          );
        }),
      ],
    );
  }
}

// Fixed-width cell widgets for horizontal scroll table

class _FixedHeaderCell extends StatelessWidget {
  final String label;
  final double width;
  const _FixedHeaderCell(this.label, {required this.width});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}

class _FixedDataCell extends StatelessWidget {
  final String text;
  final double width;
  const _FixedDataCell(this.text, {required this.width});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Text(
          text.isEmpty ? '-' : text,
          style: TextStyle(
            fontSize: 14,
            color: text.isEmpty ? Colors.grey : Colors.black87,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
    );
  }
}

class _TooltipDataCell extends StatelessWidget {
  final String text;
  final double width;
  const _TooltipDataCell(this.text, {required this.width});

  @override
  Widget build(BuildContext context) {
    final display = text.isEmpty ? '-' : text;
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Tooltip(
          message: display,
          waitDuration: const Duration(milliseconds: 300),
          child: Text(
            display,
            style: TextStyle(
              fontSize: 14,
              color: text.isEmpty ? Colors.grey : Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ),
    );
  }
}

class _FixedSeverityCell extends StatelessWidget {
  final String severity;
  final double width;
  const _FixedSeverityCell(this.severity, {required this.width});

  @override
  Widget build(BuildContext context) {
    if (severity.isEmpty) {
      return SizedBox(
        width: width,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Text('-', style: TextStyle(fontSize: 14, color: Colors.grey)),
        ),
      );
    }
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _severityColor(severity).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              severity,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _severityColor(severity),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}

class _RemarkCell extends StatelessWidget {
  final String text;
  final double width;
  const _RemarkCell(this.text, {required this.width});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Text(
            text.isEmpty ? '-' : text,
            style: TextStyle(
              fontSize: 14,
              color: text.isEmpty ? Colors.grey : Colors.black87,
              height: 1.4,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

// Pagination

class _Pagination extends StatelessWidget {
  final AnalyticsController ctrl;
  const _Pagination(this.ctrl);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final cur = ctrl.currentPage.value;
      final total = ctrl.totalPages;
      final count = ctrl.totalRecords.value;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Text(
              'Total: $count records',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.first_page),
              onPressed: cur > 1 ? () => ctrl.goToPage(1) : null,
              iconSize: 18,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: cur > 1 ? () => ctrl.goToPage(cur - 1) : null,
              iconSize: 18,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Page $cur of $total',
                style: const TextStyle(fontSize: 15),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: cur < total ? () => ctrl.goToPage(cur + 1) : null,
              iconSize: 18,
            ),
            IconButton(
              icon: const Icon(Icons.last_page),
              onPressed: cur < total ? () => ctrl.goToPage(total) : null,
              iconSize: 18,
            ),
          ],
        ),
      );
    });
  }
}

// Shared helpers

class _LoadingWidget extends StatelessWidget {
  const _LoadingWidget();
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 160,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _EmptyWidget extends StatelessWidget {
  final double height;
  const _EmptyWidget({this.height = 160});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart, size: 36, color: Colors.grey[300]),
            const SizedBox(height: 8),
            Text(
              'No data available',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}
