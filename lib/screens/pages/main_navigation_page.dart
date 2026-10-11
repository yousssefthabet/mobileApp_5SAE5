import 'package:flutter/material.dart';
import 'package:chargi/widgets/BottomNavigationBar.dart';
import 'home_page.dart';
import 'report_trash_page.dart';
import 'my_reports_page.dart';
import 'profile_page.dart';
import 'worker_job_page.dart';

class MainNavigationPage extends StatefulWidget {
  final int initialIndex;

  const MainNavigationPage({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  late int _currentIndex;
  bool _isWorkerMode = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _setIndex(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isWorkerMode) {
      return WorkerJobPage(
        onNavigateToHome: () {
          setState(() {
            _isWorkerMode = false;
            _currentIndex = 0;
          });
        },
        onNavigateToProfile: () {
          setState(() {
            _isWorkerMode = false;
            _currentIndex = 3;
          });
        },
      );
    }

    final pages = [
      HomePage(
        showBottomNavBar: false,
        onNavigateToProfile: () => _setIndex(3),
        onNavigateToReport: () => _setIndex(1),
        onNavigateToMyReports: () => _setIndex(2),
      ),
      ReportTrashPage(
        showBottomNavBar: false,
        onNavigateToMap: () => _setIndex(0),
        onNavigateToMyReports: () => _setIndex(2),
        onNavigateToProfile: () => _setIndex(3),
      ),
      MyReportsPage(
        showBottomNavBar: false,
        onNavigateToMap: () => _setIndex(0),
        onNavigateToReport: () => _setIndex(1),
        onNavigateToProfile: () => _setIndex(3),
      ),
      ProfilePage(
        showBottomNavBar: false,
        onNavigateToMap: () => _setIndex(0),
        onNavigateToReport: () => _setIndex(1),
        onNavigateToMyReports: () => _setIndex(2),
        onSwitchToWorkerMode: () {
          setState(() {
            _isWorkerMode = true;
          });
        },
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
