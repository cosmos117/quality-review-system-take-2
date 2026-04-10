import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';

class SidebarNavItem {
  final IconData icon;
  final String label;
  final int? badgeCount;
  final VoidCallback? onTap;

  SidebarNavItem({
    required this.icon,
    required this.label,
    this.badgeCount,
    this.onTap,
  });
}

class AppSidebar extends StatelessWidget {
  final List<SidebarNavItem> items;
  final int selectedIndex;
  final bool isCollapsed;
  final VoidCallback onToggle;
  final VoidCallback? onLogout;
  final String title;

  const AppSidebar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.isCollapsed,
    required this.onToggle,
    this.onLogout,
    this.title = "Atlas Copco",
  });

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF135BEC);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: isCollapsed ? 80 : 270,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Colors.grey.shade200, width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // INCREASED THRESHOLD: 200px is safer for the header Row + Text
          final isWidthSufficient = constraints.maxWidth > 200;

          return Column(
            children: [
              // Header Section
              _buildHeader(primaryColor, isWidthSufficient),

              const SizedBox(height: 24),

              // Menu Items
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    return _buildNavItem(
                      items[index],
                      index == selectedIndex,
                      primaryColor,
                      isWidthSufficient,
                    );
                  },
                ),
              ),

              // Footer / Profile
              _buildFooter(isWidthSufficient),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(Color primaryColor, bool showExpanded) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Icon only (for collapsed state or when width is low)
          AnimatedOpacity(
            opacity: isCollapsed ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !isCollapsed,
              child: Center(
                child: InkWell(
                  onTap: onToggle,
                  child: Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryColor, primaryColor.withOpacity(0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.insights, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ),
          ),

          // Full Header (only rendered when width is sufficient)
          if (showExpanded && !isCollapsed)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [primaryColor, primaryColor.withOpacity(0.8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.insights, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Flexible(
                        child: Text(
                          "Atlas Copco",
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            letterSpacing: -0.5,
                            color: Color(0xFF1A1D1E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onToggle,
                  icon: const Icon(Icons.chevron_left, color: Colors.grey),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    SidebarNavItem item,
    bool isActive,
    Color primaryColor,
    bool showExpanded,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(12),
          hoverColor: Colors.grey.shade50,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: isActive ? primaryColor.withOpacity(0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Icon only
                if (isCollapsed || !showExpanded)
                  Center(
                    child: Icon(
                      item.icon,
                      size: 22,
                      color: isActive ? primaryColor : Colors.grey.shade500,
                    ),
                  ),

                // Expanded Item View
                if (showExpanded && !isCollapsed)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Icon(
                          item.icon,
                          size: 22,
                          color: isActive ? primaryColor : Colors.grey.shade500,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                              color: isActive ? primaryColor : const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                          ),
                        ),
                        if (item.badgeCount != null && item.badgeCount! > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2F3E5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "${item.badgeCount}",
                              style: const TextStyle(
                                color: Color(0xFF2E7D32),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(bool showExpanded) {
    return Obx(() {
      final authCtrl = Get.find<AuthController>();
      final user = authCtrl.currentUser.value;
      final name = user?.name ?? 'User';
      final role = user?.role ?? 'Employee';

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey.shade100)),
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isCollapsed || !showExpanded)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.blue.shade50,
                      child: const Icon(Icons.person, size: 20, color: Color(0xFF135BEC)),
                    ),
                    if (onLogout != null) ...[
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: onLogout,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.red.shade50,
                          child: const Icon(Icons.logout, size: 18, color: Colors.red),
                        ),
                      ),
                    ],
                  ],
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.blue.shade50,
                            child: const Icon(Icons.person, size: 18, color: Color(0xFF135BEC)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1D1E),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  role.capitalizeFirst!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
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
                      if (onLogout != null) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 32,
                          child: ElevatedButton(
                            onPressed: onLogout,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade50,
                              foregroundColor: Colors.red,
                              elevation: 0,
                              padding: EdgeInsets.all(0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(color: Colors.red.withOpacity(0.1)),
                              ),
                            ),
                            child: const Text(
                              "Logout",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}
