import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quality_review/pages/employee_pages/employee_dashboard.dart';
import 'package:quality_review/pages/login.dart';

import 'pages/admin_pages/team_page.dart';
import 'components/admin_sidebar.dart';
import 'pages/admin_pages/admin_dashboard_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Quality Review Dashboard  ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.grey[50],
        useMaterial3: false,
      ),
      home: LoginPage(),
    );
  }
}
