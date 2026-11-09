import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chargi/widgets/BottomNavigationBar.dart';
import 'package:chargi/screens/auth/login_screen.dart';

import 'notifications_page.dart';
import 'charging_complete_page.dart';
import 'edit_profile_page.dart';
import 'my_reservations_page.dart';
import 'rewards_page.dart';
import 'package:chargi/services/station_availability_service.dart';
import 'package:chargi/services/reward_service.dart';

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
  static const Color goldAccent = Color(0xFFD97706);

  int _reportsSent = 0;
  int _reportsResolved = 0;
  int _userPoints = 0;
  int _totalReservations = 0;
  bool _metricsLoaded = false;
  String _userName = '';

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _reportsSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _reservationsSub;

  @override
  void initState() {
    super.initState();
    _initListeners();
  }

  @override
  void dispose() {
    _reportsSub?.cancel();
    _userSub?.cancel();
    _reservationsSub?.cancel();
    super.dispose();
  }

  Future<void> _refreshUserPoints() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final pts = await RewardService.instance.getUserPoints(user.uid);
      if (mounted) {
        setState(() {
          _userPoints = pts;
        });
      }
    } catch (_) {}
  }

  void _initListeners() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _metricsLoaded = true);
      return;
    }

    // 1. Listen to user document for real-time name & points changes
    _userSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((doc) {
      if (!mounted) return;
      if (doc.exists) {
        final data = doc.data();
        final docPoints = (data?['rewardPoints'] as num?)?.toInt() ?? 0;
        setState(() {
          _userName = (data?['name'] as String?) ?? user.displayName ?? '';
          _userPoints = docPoints;
        });
      }
    }, onError: (e) {
      debugPrint('Error listening to user document: $e');
    });

    // 2. Listen to reservations subcollection for real-time points updates after each reservation
    _reservationsSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('reservations')
        .snapshots()
        .listen((resSnap) async {
      int count = resSnap.docs.length;
      List<Map<String, dynamic>> resList = resSnap.docs.map((d) => d.data()).toList();

      // Fallback check on top-level collection if user subcollection is empty
      if (count == 0) {
        try {
          final topSnap = await FirebaseFirestore.instance
              .collection('reservations')
              .where('userId', isEqualTo: user.uid)
              .get();
          if (topSnap.docs.isNotEmpty) {
            count = topSnap.docs.length;
            resList = topSnap.docs.map((d) => d.data()).toList();
          }
        } catch (_) {}
      }

      final pointsFromReservations = RewardService.instance.calculatePointsFromReservations(resList);

      if (!mounted) return;
      setState(() {
        _totalReservations = count;
        _userPoints = pointsFromReservations;
      });

      // Synchronize points to user document so it is persisted
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'rewardPoints': pointsFromReservations,
          'totalReservations': count,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }, onError: (e) {
      debugPrint('Error listening to user reservations: $e');
    });

    // 3. Listen to reports subcollection for real-time metric counts
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
    final hasUnlockedPromo = _userPoints >= 100;

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

              const SizedBox(height: 20),

              // 2. Loyalty Rewards Banner
              InkWell(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RewardsPage(),
                    ),
                  );
                  if (mounted) {
                    setState(() {});
                  }
                },
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF086B5B), Color(0xFF0F8A76)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: primaryGreen.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.stars_rounded,
                          color: Colors.amberAccent,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '$_userPoints Points',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '+10 pts / résa ($_totalReservations résa)',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              hasUnlockedPromo
                                  ? '🎉 Code promo 30% débloqué (PROMO30 · Usage unique) !'
                                  : 'Plus que ${(100 - _userPoints).clamp(0, 100)} pts pour débloquer le code 30% (Usage unique)',
                              style: TextStyle(
                                fontSize: 12,
                                color: hasUnlockedPromo
                                    ? Colors.amberAccent
                                    : Colors.white70,
                                fontWeight: hasUnlockedPromo
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: Colors.white70,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 3. Metric Cards (real data from Firestore)
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
                    count: '$_userPoints pts',
                    label: 'Points fidélité',
                    highlightColor: primaryGreen,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 4. Settings / Options List
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
                      icon: Icons.person_outline,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EditProfilePage(),
                          ),
                        );
                        if (mounted) {
                          _refreshUserPoints();
                        }
                      },
                    ),

                    _buildDivider(),

                    // Loyalty & Rewards Option
                    _buildMenuItem(
                      title: 'Fidélité & Récompenses',
                      icon: Icons.card_giftcard,
                      trailingWidget: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: hasUnlockedPromo
                              ? const Color(0xFFFAF5E9)
                              : const Color(0xFFE2EFEA),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          hasUnlockedPromo ? '-30% dispo' : '$_userPoints pts',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: hasUnlockedPromo ? goldAccent : primaryGreen,
                          ),
                        ),
                      ),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RewardsPage(),
                          ),
                        );
                        if (mounted) {
                          _refreshUserPoints();
                        }
                      },
                    ),

                    _buildDivider(),

                    _buildMenuItem(
                      title: 'Charging history',
                      icon: Icons.history,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ChargingCompletePage(),
                          ),
                        );
                      },
                    ),

                    _buildDivider(),

                    _buildMenuItem(
                      title: 'Notifications',
                      icon: Icons.notifications_none,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationsPage(),
                          ),
                        );
                      },
                    ),

                    _buildDivider(),

                    _buildMenuItem(
                      title: 'My Reservations',
                      icon: Icons.confirmation_number_outlined,
                      trailingWidget: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2EFEA),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$_totalReservations',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: primaryGreen,
                          ),
                        ),
                      ),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MyReservationsPage(
                              onNavigateToMap: widget.onNavigateToMap,
                            ),
                          ),
                        );
                        if (mounted) {
                          _refreshUserPoints();
                        }
                      },
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

                    // Reset / Free Stations (Demo utility)
                    _buildMenuItem(
                      title: 'Libérer les bornes (Mode Test)',
                      icon: Icons.lock_open_rounded,
                      textColor: const Color(0xFF0284C7),
                      onTap: () async {
                        final released = await StationAvailabilityService.instance
                            .forceReleaseAllBusyStations();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              released > 0
                                  ? '$released connecteur(s) libéré(s) avec succès !'
                                  : 'Toutes les bornes sont déjà libres et disponibles.',
                            ),
                            backgroundColor: primaryGreen,
                          ),
                        );
                      },
                    ),

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
                } else if (index == 1 && widget.onNavigateToReport != null) {
                  widget.onNavigateToReport!();
                } else if (index == 2 && widget.onNavigateToMyReports != null) {
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
    Color? highlightColor,
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
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: highlightColor ?? const Color(0xFF1E2926),
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
    Widget? trailingWidget,
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
            if (trailingWidget != null) ...[
              trailingWidget,
              const SizedBox(width: 8),
            ],
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
      await FirebaseAuth.instance.signOut();

      if (!context.mounted) return;

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
