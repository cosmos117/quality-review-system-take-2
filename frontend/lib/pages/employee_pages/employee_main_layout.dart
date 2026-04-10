import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quality_review/components/app_sidebar.dart';
import 'package:quality_review/pages/employee_pages/employee_dashboard.dart';
import 'package:quality_review/pages/employee_pages/myproject.dart';
import 'package:quality_review/pages/employee_pages/leader_performance.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/notification_controller.dart';
import '../login.dart';

class EmployeeMainLayout extends StatefulWidget {
  const EmployeeMainLayout({super.key});

  @override
  State<EmployeeMainLayout> createState() => _EmployeeMainLayoutState();
}

class _EmployeeMainLayoutState extends State<EmployeeMainLayout> {
  final RxInt _selectedIndex = 0.obs;
  final RxBool _isCollapsed = false.obs;

  final pages = [EmployeeDashboard(), Myproject(), LeaderPerformance()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Collapsible Sidebar
          Obx(() {
            final notifCtrl = Get.find<NotificationController>();
            final myProjectsCount = notifCtrl.executorNotificationCount.value;

            return AppSidebar(
              isCollapsed: _isCollapsed.value,
              selectedIndex: _selectedIndex.value,
              onToggle: () => _isCollapsed.value = !_isCollapsed.value,
              onLogout: () async {
                await Get.find<AuthController>().logout();
                Get.offAll(() => LoginPage());
              },
              items: [
                SidebarNavItem(
                  icon: Icons.grid_view_rounded,
                  label: "Dashboard",
                  onTap: () => _selectedIndex.value = 0,
                ),
                SidebarNavItem(
                  icon: Icons.assignment_rounded,
                  label: "My Projects",
                  badgeCount: myProjectsCount,
                  onTap: () => _selectedIndex.value = 1,
                ),
                SidebarNavItem(
                  icon: Icons.trending_up_rounded,
                  label: "Performance",
                  onTap: () => _selectedIndex.value = 2,
                ),
              ],
            );
          }),

          // Main Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 24), // Compensate for removed top bar
              child: Obx(() => pages[_selectedIndex.value]),
            ),
          ),
        ],
      ),
    );
  }
}
