import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quality_review/components/admin_sidebar.dart';
import 'package:quality_review/pages/admin_pages/admin_dashboard_page.dart';
import 'package:quality_review/pages/admin_pages/employee_page.dart';
import 'package:quality_review/pages/admin_pages/admin_checklist_template_page.dart';

class AdminMainLayout extends StatelessWidget {
  AdminMainLayout({super.key});

  final RxInt _selectedIndex = 0.obs;
  final pages = const [
    AdminDashboardPage(),
    EmployeePage(),
    AdminChecklistTemplatePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar (left)
          Container(
            width: 250,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border.fromBorderSide(BorderSide(color: Colors.black12)),
            ),
            child: Obx(
              () => AdminSidebar(
                selectedIndex: _selectedIndex.value,
                onItemSelected: (index) => _selectedIndex.value = index,
                onCreate: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Create New clicked")),
                  );
                },
              ),
            ),
          ),

          // Main Content (right)
          Expanded(
            child: Obx(
              () => AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: pages[_selectedIndex.value],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
