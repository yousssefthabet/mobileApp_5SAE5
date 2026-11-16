import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:chargi/features/chatbot/presentation/pages/chatbot_page.dart';
import 'package:chargi/features/users/data/user_role_repository.dart';
import 'package:chargi/features/users/domain/user_role.dart';
import 'package:chargi/widgets/BottomNavigationBar.dart';
import 'home_page.dart';
import 'report_trash_page.dart';
import 'map_location_picker_page.dart';
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
  LatLng? _homeFocusCoord;
  Map<String, dynamic>? _pendingTrashReport;

  // Role of the signed-in user, read live from users/{uid}. Until it is known
  // (or if it cannot be read) it stays `user`: no worker access.
  UserRole _role = UserRole.user;
  StreamSubscription<UserRole>? _roleSub;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _listenToRole();
  }

  @override
  void dispose() {
    _roleSub?.cancel();
    super.dispose();
  }

  void _listenToRole() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _roleSub = UserRoleRepository().watchRole(uid).listen((role) {
      if (!mounted) return;
      setState(() {
        _role = role;
        // Demoted while in worker mode: leave it immediately.
        if (!role.canUseWorkerPortal) _isWorkerMode = false;
      });
    });
  }

  void _setIndex(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onTrashLocationSelected(MapLocationResult location, {bool navigateToHome = false}) {
    setState(() {
      _homeFocusCoord = LatLng(location.latitude, location.longitude);
      _pendingTrashReport = {
        'problemTitle': 'Picked Location (${location.landmark})',
        'location': location.address,
        'landmark': location.landmark,
        'latitude': location.latitude,
        'longitude': location.longitude,
        'status': 'pending',
      };
      if (navigateToHome) {
        _currentIndex = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Both conditions are required: the flag alone never opens the portal.
    if (_isWorkerMode && _role.canUseWorkerPortal) {
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
        key: ValueKey('home_${_homeFocusCoord?.latitude}_${_homeFocusCoord?.longitude}'),
        showBottomNavBar: false,
        focusCoord: _homeFocusCoord,
        initialFilterIndex: _homeFocusCoord != null ? 2 : 0,
        pendingTrashReport: _pendingTrashReport,
        onNavigateToProfile: () => _setIndex(3),
        onNavigateToReport: () => _setIndex(1),
        onNavigateToMyReports: () => _setIndex(2),
      ),
      ReportTrashPage(
        showBottomNavBar: false,
        onNavigateToMap: () => _setIndex(0),
        onNavigateToMyReports: () => _setIndex(2),
        onNavigateToProfile: () => _setIndex(3),
        onLocationSelected: _onTrashLocationSelected,
      ),
      MyReportsPage(
        showBottomNavBar: false,
        onNavigateToMap: () => _setIndex(0),
        onNavigateToReport: () => _setIndex(1),
        onNavigateToProfile: () => _setIndex(3),
      ),
      ProfilePage(
        role: _role,
        showBottomNavBar: false,
        onNavigateToMap: () => _setIndex(0),
        onNavigateToReport: () => _setIndex(1),
        onNavigateToMyReports: () => _setIndex(2),
        // null hides the "Worker portal" entry for non-workers.
        onSwitchToWorkerMode: _role.canUseWorkerPortal
            ? () {
                setState(() {
                  _isWorkerMode = true;
                });
              }
            : null,
      ),
      // Citizen-facing AI assistant (index 4). Worker mode renders its own
      // screen above, so workers never see this tab.
      ChatbotPage(isActive: _currentIndex == 4),
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
