
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chargi/widgets/BottomNavigationBar.dart';
import 'package:chargi/screens/auth/login_screen.dart';

import 'notifications_page.dart';
import 'charging_complete_page.dart';
import 'payment_page.dart';
import 'edit_profile_page.dart';

class ProfilePage extends StatefulWidget {
  final VoidCallback? onNavigateToMap;
  final VoidCallback? onNavigateToReport;
  final VoidCallback? onNavigateToMyReports;
  final VoidCallback? onSwitchToWorkerMode;
  final bool showBottomNavBar;

  const ProfilePage({
    super.key,
    this.onNavigateToMap,
    this.onNavigateToReport,
    this.onNavigateToMyReports,
    this.onSwitchToWorkerMode,
    this.showBottomNavBar = true,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const Color primaryGreen = Color(0xFF086B5B);
  static const Color backgroundColor = Color(0xFFF7F9F8);
  static const Color cardBorderColor = Color(0xFFE8ECEB);

  int _reportsSent = 0;
  int _reportsResolved = 0;
  bool _metricsLoaded = false;
  String _userName = '';

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _reportsSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;

  @override
  void initState() {
    super.initState();
    _initListeners();
  }

  @override
  void dispose() {
    _reportsSub?.cancel();
    _userSub?.cancel();
    super.dispose();
  }

  void _initListeners() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _metricsLoaded = true);
      return;
    }

    // Listen to user document for real-time name changes
    _userSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((doc) {
      if (!mounted) return;
      if (doc.exists) {
        setState(() {
          _userName = (doc.data()?['name'] as String?) ?? user.displayName ?? '';
        });
      }
    }, onError: (e) {
      debugPrint('Error listening to user document: $e');
    });

    // Listen to reports subcollection for real-time metric counts
    _reportsSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('reports')
        .snapshots()
        .listen((reportsSnap) {
      int sent = reportsSnap.docs.length;
      int resolved = 0;

      for (final doc in reportsSnap.docs) {
        final status = (doc.data()['status'] as String? ?? '').toLowerCase();
        if (status == 'resolved') {
          resolved++;
        }
      }

      if (mounted) {
        setState(() {
          _reportsSent = sent;
          _reportsResolved = resolved;
          _metricsLoaded = true;
        });
      }
    }, onError: (e) {
      debugPrint('Error listening to reports: $e');
      if (mounted) {
        setState(() => _metricsLoaded = true);
      }
    });
  }

  /// Returns the first letter of the user's display name or email, uppercase.
  String _avatarInitial() {
    final name = _userName.isNotEmpty
        ? _userName
        : (FirebaseAuth.instance.currentUser?.displayName ?? '');
    if (name.trim().isNotEmpty) {
      return name.trim()[0].toUpperCase();
    }
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    if (email.trim().isNotEmpty) {
      return email.trim()[0].toUpperCase();
    }
    return 'U';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),

              // 1. User Profile Header
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      color: primaryGreen,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _avatarInitial(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName.isNotEmpty
                              ? _userName
                              : (FirebaseAuth.instance.currentUser
                                      ?.displayName ??
                                  'Your name'),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E2926),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          FirebaseAuth.instance.currentUser?.email ??
                              'email@example.com',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF7A8B86),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 2. Three Metric Cards (real data from Firestore)
              Row(
                children: [
                  _buildMetricCard(
                    count: _metricsLoaded ? '$_reportsSent' : '…',
                    label: 'Reports sent',
                  ),
                  const SizedBox(width: 12),
                  _buildMetricCard(
                    count: _metricsLoaded ? '$_reportsResolved' : '…',
                    label: 'Resolved',
                  ),
                  const SizedBox(width: 12),
                  _buildMetricCard(
                    count: '0',
                    label: 'Charges',
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 3. Settings / Options List
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: cardBorderColor,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildMenuItem(
                      title: 'Edit Profile',
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const EditProfilePage(),
                          ),
                        );
                        if (mounted) setState(() {});
                      },
                    ),

                    _buildDivider(),

                    _buildMenuItem(
                      title: 'Charging history',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const ChargingCompletePage(),
                          ),
                        );
                      },
                    ),

                    _buildDivider(),

                    _buildMenuItem(
                      title: 'Payment methods',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PaymentPage(),
                          ),
                        );
                      },
                    ),

                    _buildDivider(),

                    _buildMenuItem(
                      title: 'Notifications',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const NotificationsPage(),
                          ),
                        );
                      },
                    ),

                    _buildDivider(),

                    _buildMenuItem(
                      title: 'Language',
                      onTap: () {},
                    ),

                    if (widget.onSwitchToWorkerMode != null) ...[
                      _buildDivider(),
                      _buildMenuItem(
                        title: 'Worker portal (View Job Page)',
                        icon: Icons.badge_outlined,
                        textColor: primaryGreen,
                        onTap: widget.onSwitchToWorkerMode!,
                      ),
                    ],

                    _buildDivider(),

                    // Log out
                    _buildMenuItem(
                      title: 'Log out',
                      textColor: const Color(0xFFD32F2F),
                      icon: Icons.logout,
                      hideTrailing: true,
                      onTap: () {
                        _showLogoutConfirmation(context);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),

      // Bottom navigation
      bottomNavigationBar: widget.showBottomNavBar
          ? CustomBottomNavigationBar(
              currentIndex: 3,
              onTap: (index) {
                if (index == 0 && widget.onNavigateToMap != null) {
                  widget.onNavigateToMap!();
                } else if (index == 1 &&
                    widget.onNavigateToReport != null) {
                  widget.onNavigateToReport!();
                } else if (index == 2 &&
                    widget.onNavigateToMyReports != null) {
                  widget.onNavigateToMyReports!();
                }
              },
            )
          : null,
    );
  }


  // Metric card
  Widget _buildMetricCard({
    required String count,
    required String label,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 12,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: cardBorderColor,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              count,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E2926),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF7A8B86),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Menu item
  Widget _buildMenuItem({
    required String title,
    Color? textColor,
    IconData? icon,
    bool hideTrailing = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 20,
                color: textColor ?? const Color(0xFF1E2926),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textColor ?? const Color(0xFF1E2926),
                ),
              ),
            ),
            if (!hideTrailing)
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: Color(0xFF9EAFA9),
              ),
          ],
        ),
      ),
    );
  }

  // Divider
  Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      color: Color(0xFFF0F4F2),
    );
  }

  // Firebase logout confirmation
  Future<void> _showLogoutConfirmation(
    BuildContext context,
  ) async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Log out'),
          content: const Text(
            'Are you sure you want to log out of your Chargi account?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0xFF7A8B86),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text(
                'Log out',
                style: TextStyle(
                  color: Color(0xFFD32F2F),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) return;

    try {
      // Actually sign out of Firebase.
      await FirebaseAuth.instance.signOut();

      if (!context.mounted) return;

      // Clear the navigation stack and open the login screen.
      Navigator.of(context, rootNavigator: true)
          .pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const LoginScreen(),
        ),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Logout failed: ${e.message ?? "Please try again."}',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Something went wrong. Please try again.',
          ),
        ),
      );

      debugPrint('Logout error: $e');
    }
  }
}
