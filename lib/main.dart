import 'package:flutter/material.dart';
import 'package:quality_review/pages/projects_page.dart';
import 'package:quality_review/pages/reviews_page.dart' ;
import 'package:quality_review/pages/team_page.dart';
import 'components/sidebar.dart';
import 'pages/dashboard_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
 
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quality Review Dashboard',
      debugShowCheckedModeBanner: false,
      home: const MainLayout(),
    );
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int selectedIndex = 0;

  final pages = const [
    DashboardPage(),
    ProjectsPage(),
    ReviewsPage(),
    TeamPage(),
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(2, 0),
                ),
              ],
            ),
            child: Sidebar(
              selectedIndex: selectedIndex,
              onItemSelected: (index) {
                setState(() {
                  selectedIndex = index;
                });
              },
              onCreate: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Create New clicked dnf")),
                );
              },
            ),
          ),

          // Main Content (right) dndkf
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: pages[selectedIndex],
            ),
          ),
        ],
      ),
    );
  }
}
