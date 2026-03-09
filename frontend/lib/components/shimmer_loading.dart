import 'package:flutter/material.dart';

/// A shimmer animation widget that creates a loading glow effect.
/// Wraps child skeleton placeholders with an animated gradient.
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  const ShimmerLoading({super.key, required this.child});

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                Color(0xFFE0E0E0),
                Color(0xFFF5F5F5),
                Color(0xFFE0E0E0),
              ],
              stops: [
                (_controller.value - 0.3).clamp(0.0, 1.0),
                _controller.value,
                (_controller.value + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: widget.child,
        );
      },
      child: widget.child,
    );
  }
}

/// A single skeleton rectangle placeholder.
class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE0E0E0),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Skeleton row for table-based list views (dashboards).
class SkeletonTableRow extends StatelessWidget {
  final int columns;
  final double rowHeight;
  const SkeletonTableRow({super.key, this.columns = 8, this.rowHeight = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: rowHeight,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: List.generate(columns, (i) {
          final widths = [120.0, 180.0, 100.0, 120.0, 120.0, 80.0, 80.0, 80.0];
          final w = i < widths.length ? widths[i] : 80.0;
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: SkeletonBox(width: w, height: 14),
          );
        }),
      ),
    );
  }
}

/// Full skeleton table for dashboard loading states.
class SkeletonTable extends StatelessWidget {
  final int rowCount;
  final int columns;
  const SkeletonTable({super.key, this.rowCount = 6, this.columns = 8});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Column(
        children: [
          // Header skeleton
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: List.generate(columns, (i) {
                final widths = [
                  120.0,
                  180.0,
                  100.0,
                  120.0,
                  120.0,
                  80.0,
                  80.0,
                  80.0,
                ];
                final w = i < widths.length ? widths[i] : 80.0;
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: SkeletonBox(width: w, height: 12),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          // Row skeletons
          ...List.generate(rowCount, (_) => SkeletonTableRow(columns: columns)),
        ],
      ),
    );
  }
}

/// Skeleton for statistics cards (3 stat items in a row).
class SkeletonStatisticsCard extends StatelessWidget {
  const SkeletonStatisticsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatSkeleton(),
            Container(height: 30, width: 1, color: Colors.grey[300]),
            _buildStatSkeleton(),
            Container(height: 30, width: 1, color: Colors.grey[300]),
            _buildStatSkeleton(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatSkeleton() {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          SkeletonBox(width: 36, height: 24, borderRadius: 4),
          SizedBox(width: 6),
          SkeletonBox(width: 70, height: 14),
        ],
      ),
    );
  }
}

/// Skeleton for phase overview cards.
class SkeletonPhaseOverview extends StatelessWidget {
  final int phaseCount;
  final bool compact;
  const SkeletonPhaseOverview({
    super.key,
    this.phaseCount = 4,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Wrap(
        spacing: compact ? 8 : 12,
        runSpacing: compact ? 8 : 12,
        children: List.generate(phaseCount, (_) {
          return Container(
            width: compact ? 180 : 220,
            padding: EdgeInsets.all(compact ? 8 : 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(compact ? 6 : 8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: compact ? 12 : 16,
                  backgroundColor: Colors.grey.shade200,
                ),
                SizedBox(width: compact ? 8 : 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 80, height: compact ? 12 : 14),
                      SizedBox(height: compact ? 2 : 4),
                      SkeletonBox(width: 50, height: compact ? 10 : 12),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

/// Skeleton for checklist groups (expansion tiles).
class SkeletonChecklistGroups extends StatelessWidget {
  final int groupCount;
  const SkeletonChecklistGroups({super.key, this.groupCount = 4});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Column(
        children: List.generate(groupCount, (_) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Expanded(
                    child: SkeletonBox(width: double.infinity, height: 16),
                  ),
                  const SizedBox(width: 12),
                  SkeletonBox(width: 90, height: 28, borderRadius: 12),
                  const SizedBox(width: 8),
                  const Icon(Icons.expand_more, color: Colors.grey),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Skeleton for assigned team member cards.
class SkeletonMemberCards extends StatelessWidget {
  const SkeletonMemberCards({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            List.generate(3, (_) {
                return Expanded(
                  child: Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              SkeletonBox(
                                width: 20,
                                height: 20,
                                borderRadius: 10,
                              ),
                              SizedBox(width: 8),
                              SkeletonBox(width: 80, height: 14),
                              Spacer(),
                              SkeletonBox(
                                width: 24,
                                height: 20,
                                borderRadius: 12,
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          ...List.generate(2, (_) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Row(
                                  children: const [
                                    SkeletonBox(
                                      width: 32,
                                      height: 32,
                                      borderRadius: 16,
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: SkeletonBox(
                                        width: 100,
                                        height: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                );
              }).expand((w) sync* {
                yield w;
                yield const SizedBox(width: 16);
              }).toList()
              ..removeLast(),
      ),
    );
  }
}

/// A small inline loading indicator for widget-level refreshes.
/// Shows a subtle progress bar at the top of a widget without blocking content.
class InlineLoadingIndicator extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  const InlineLoadingIndicator({
    super.key,
    required this.isLoading,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLoading)
          const LinearProgressIndicator(
            minHeight: 2,
            backgroundColor: Colors.transparent,
          ),
        Flexible(child: child),
      ],
    );
  }
}

/// Wraps a widget with a subtle refreshing overlay (no blocking).
class RefreshingOverlay extends StatelessWidget {
  final bool isRefreshing;
  final Widget child;
  const RefreshingOverlay({
    super.key,
    required this.isRefreshing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isRefreshing)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade300),
            ),
          ),
      ],
    );
  }
}
