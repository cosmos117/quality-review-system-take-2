import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quality_review/components/app_sidebar.dart';
import 'package:quality_review/pages/admin_pages/admin_checklist_template_page.dart';
import 'package:quality_review/pages/admin_pages/admin_dashboard_page.dart';
import 'package:quality_review/pages/admin_pages/analytics_page.dart';
import 'package:quality_review/pages/admin_pages/employee_page.dart';
import 'package:quality_review/pages/admin_pages/employee_performance_page.dart';
import '../../controllers/auth_controller.dart';
import '../login.dart';

class AdminMainLayout extends StatelessWidget {
  AdminMainLayout({super.key});

  final RxInt _selectedIndex = 0.obs;
  final RxBool _isCollapsed = false.obs;

  final pages = [
    const AdminDashboardPage(),
    const EmployeePage(),
    const EmployeePerformancePage(),
    const AnalyticsPage(),
    const AdminChecklistTemplatePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Collapsible Sidebar
          Obx(() => AppSidebar(
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
                icon: Icons.people_alt_rounded,
                label: "Employees",
                onTap: () => _selectedIndex.value = 1,
              ),
              SidebarNavItem(
                icon: Icons.trending_up_rounded,
                label: "Performance",
                onTap: () => _selectedIndex.value = 2,
              ),
              SidebarNavItem(
                icon: Icons.analytics_rounded,
                label: "Analytics",
                onTap: () => _selectedIndex.value = 3,
              ),
              SidebarNavItem(
                icon: Icons.rule_folder_rounded,
                label: "Templates",
                onTap: () => _selectedIndex.value = 4,
              ),
            ],
          )),

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
