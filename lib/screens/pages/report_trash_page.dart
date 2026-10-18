import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chargi/widgets/BottomNavigationBar.dart';
import 'report_sent_page.dart';
import 'map_location_picker_page.dart';

class ReportTrashPage extends StatefulWidget {
  final VoidCallback? onNavigateToMap;
  final VoidCallback? onNavigateToMyReports;
  final VoidCallback? onNavigateToProfile;
  final void Function(MapLocationResult location, {bool navigateToHome})? onLocationSelected;
  final bool showBottomNavBar;

  const ReportTrashPage({
    super.key,
    this.onNavigateToMap,
    this.onNavigateToMyReports,
    this.onNavigateToProfile,
    this.onLocationSelected,
    this.showBottomNavBar = true,
  });

  @override
  State<ReportTrashPage> createState() => _ReportTrashPageState();
}

class _ReportTrashPageState extends State<ReportTrashPage> {
  int _selectedProblemIndex = 0; // 0: Overflowing bin, 1: Illegal dumping, 2: Broken bin, 3: Other

  // Photo State
  Uint8List? _imageBytes;
  bool _isPickingPhoto = false;
  bool _isSubmitting = false;

  // Location State
  MapLocationResult _selectedLocation = const MapLocationResult(
    address: 'Rue de la Liberté, near Central Square',
    landmark: 'Central Square Hub',
    latitude: 36.8065,
    longitude: 10.1815,
    mapOffsetRatio: Offset(0.48, 0.44),
  );
  bool _isLocationChangedFromMap = false;

  static const Color primaryGreen = Color(0xFF086B5B);
  static const Color lightMintBackground = Color(0xFFE2EFEA);
  static const Color backgroundColor = Color(0xFFF7F9F8);
  static const Color textDark = Color(0xFF1E2926);
  static const Color textMuted = Color(0xFF7A8B86);

  final ImagePicker _picker = ImagePicker();

  final List<Map<String, dynamic>> _problemOptions = [
    {
      'title': 'Overflowing bin',
      'icon': Icons.delete_outline,
    },
    {
      'title': 'Illegal dumping',
      'icon': Icons.delete_outline,
    },
    {
      'title': 'Broken bin',
      'icon': Icons.build_outlined,
    },
    {
      'title': 'Other',
      'icon': Icons.menu,
    },
  ];

  // ---------------------------------------------------------------------------
  // Photo Handling Methods
  // ---------------------------------------------------------------------------

  Future<void> _pickPhoto(ImageSource source) async {
    setState(() {
      _isPickingPhoto = true;
    });

    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (photo != null) {
        final bytes = await photo.readAsBytes();
        setState(() {
          _imageBytes = bytes;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                source == ImageSource.camera
                    ? 'Photo captured successfully! 📸'
                    : 'Photo attached from gallery! 🖼️',
              ),
              backgroundColor: primaryGreen,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not access camera or gallery: $e'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPickingPhoto = false;
        });
      }
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD6DFDC),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Attach Photo of Issue',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Add a clear photo to help municipal workers locate and resolve the trash problem faster.',
                  style: TextStyle(
                    fontSize: 13,
                    color: textMuted,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: lightMintBackground,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_outlined, color: primaryGreen),
                  ),
                  title: const Text(
                    'Take a Photo',
                    style: TextStyle(fontWeight: FontWeight.w600, color: textDark),
                  ),
                  subtitle: const Text('Use your device camera'),
                  contentPadding: EdgeInsets.zero,
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickPhoto(ImageSource.camera);
                  },
                ),
                const Divider(height: 12),
                ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: lightMintBackground,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_library_outlined, color: primaryGreen),
                  ),
                  title: const Text(
                    'Choose from Gallery',
                    style: TextStyle(fontWeight: FontWeight.w600, color: textDark),
                  ),
                  subtitle: const Text('Pick an existing photo from storage'),
                  contentPadding: EdgeInsets.zero,
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickPhoto(ImageSource.gallery);
                  },
                ),
                if (_imageBytes != null) ...[
                  const Divider(height: 12),
                  ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    ),
                    title: const Text(
                      'Remove Photo',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.redAccent),
                    ),
                    subtitle: const Text('Delete currently selected photo'),
                    contentPadding: EdgeInsets.zero,
                    onTap: () {
                      Navigator.pop(ctx);
                      _removePhoto();
                    },
                  ),
                ],
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  void _removePhoto() {
    setState(() {
      _imageBytes = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Photo removed'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _previewFullPhoto() {
    if (_imageBytes == null) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(
                _imageBytes!,
                fit: BoxFit.contain,
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Location Map Handling Methods
  // ---------------------------------------------------------------------------

  Future<void> _openMapLocationPicker() async {
    final result = await Navigator.push<MapLocationResult>(
      context,
      MaterialPageRoute(
        builder: (_) => MapLocationPickerPage(
          initialLocation: _selectedLocation,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedLocation = result;
        _isLocationChangedFromMap = true;
      });

      widget.onLocationSelected?.call(result, navigateToHome: result.viewOnHomeMap);

      if (mounted) {
        if (result.viewOnHomeMap && widget.onNavigateToMap != null) {
          widget.onNavigateToMap!();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location selected: ${result.landmark}'),
              backgroundColor: primaryGreen,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  Future<void> _submitReport() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in before submitting a report.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final problemTitle =
          _problemOptions[_selectedProblemIndex]['title'] as String;

      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('reports')
          .doc();

      final displayRef = '#${docRef.id.substring(0, 6).toUpperCase()}';

      await docRef.set({
        'id': docRef.id,
        'reference': displayRef,
        'problemTitle': problemTitle,
        'location': _selectedLocation.address,
        'landmark': _selectedLocation.landmark,
        'latitude': _selectedLocation.latitude,
        'longitude': _selectedLocation.longitude,
        'mapOffsetX': _selectedLocation.mapOffsetRatio.dx,
        'mapOffsetY': _selectedLocation.mapOffsetRatio.dy,
        'status': 'sent',
        'workerName': 'Unassigned',
        'estimatedArrival': 'Reviewing report',
        'hasPhoto': _imageBytes != null,
        if (_imageBytes != null) 'photoBase64': base64Encode(_imageBytes!),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReportSentPage(
            reportId: displayRef,
            reportDocId: docRef.id,
            location: _selectedLocation.address,
            problemTitle: problemTitle,
          ),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      debugPrint('Firestore submit error: ${e.code} - ${e.message}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit report: ${e.message ?? e.code}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      debugPrint('Unexpected submit error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not submit report: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Build Methods
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'NEW REPORT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: Color(0xFF7E8F8B),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Report trash',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: textDark,
                ),
              ),

              const SizedBox(height: 20),

              // 1. Photo Upload / Camera Card
              _buildPhotoSection(),

              const SizedBox(height: 18),

              // 2. Location from Map Card & Mini-Map Preview
              _buildLocationSection(),

              const SizedBox(height: 24),

              // 3. Problem Options Header
              const Text(
                'WHAT IS THE PROBLEM?',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: Color(0xFF7E8F8B),
                ),
              ),

              const SizedBox(height: 14),

              // 4. 2x2 Grid of Problem Options
              Row(
                children: [
                  Expanded(child: _buildProblemCard(0)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildProblemCard(1)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildProblemCard(2)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildProblemCard(3)),
                ],
              ),

              const SizedBox(height: 28),

              // 5. Submit Report Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: primaryGreen.withValues(alpha: 0.6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Submit report',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: widget.showBottomNavBar
          ? CustomBottomNavigationBar(
              currentIndex: 1,
              onTap: (index) {
                if (index == 0 && widget.onNavigateToMap != null) {
                  widget.onNavigateToMap!();
                } else if (index == 2 && widget.onNavigateToMyReports != null) {
                  widget.onNavigateToMyReports!();
                } else if (index == 3 && widget.onNavigateToProfile != null) {
                  widget.onNavigateToProfile!();
                }
              },
            )
          : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Widget: Photo Section
  // ---------------------------------------------------------------------------

  Widget _buildPhotoSection() {
    if (_imageBytes != null) {
      // Photo is captured / selected: Display preview with controls
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFDFE6E3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            // Preview Image Container
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  child: GestureDetector(
                    onTap: _previewFullPhoto,
                    child: SizedBox(
                      width: double.infinity,
                      height: 190,
                      child: Image.memory(
                        _imageBytes!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),

                // Top "Photo Attached" Badge
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: primaryGreen,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.white, size: 14),
                        SizedBox(width: 5),
                        Text(
                          'Photo attached',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Tap to view full size icon
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: _previewFullPhoto,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.fullscreen,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Bottom action strip: Retake / Change / Remove
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _pickPhoto(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined, size: 18, color: primaryGreen),
                      label: const Text(
                        'Retake',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: primaryGreen,
                        ),
                      ),
                    ),
                  ),
                  Container(width: 1, height: 24, color: const Color(0xFFE5EDE9)),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _showPhotoOptions,
                      icon: const Icon(Icons.swap_horiz, size: 18, color: Color(0xFF4A5C57)),
                      label: const Text(
                        'Change',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4A5C57),
                        ),
                      ),
                    ),
                  ),
                  Container(width: 1, height: 24, color: const Color(0xFFE5EDE9)),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _removePhoto,
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                      label: const Text(
                        'Remove',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // No photo yet: Show clickable dashed box
    return GestureDetector(
      onTap: _showPhotoOptions,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: const Color(0xFFCCD7D3),
          strokeWidth: 1.5,
          dashWidth: 6,
          dashSpace: 4,
          radius: 18,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: lightMintBackground,
                  shape: BoxShape.circle,
                ),
                child: _isPickingPhoto
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(primaryGreen),
                        ),
                      )
                    : const Icon(
                        Icons.camera_alt_outlined,
                        color: primaryGreen,
                        size: 28,
                      ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Take a photo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textDark,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'or choose from gallery',
                style: TextStyle(
                  fontSize: 13,
                  color: textMuted,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _pickPhoto(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt, size: 16, color: primaryGreen),
                    label: const Text('Camera'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryGreen,
                      side: const BorderSide(color: Color(0xFFCCD7D3)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () => _pickPhoto(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library, size: 16, color: primaryGreen),
                    label: const Text('Gallery'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryGreen,
                      side: const BorderSide(color: Color(0xFFCCD7D3)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Widget: Location Section (Card + Mini-Map)
  // ---------------------------------------------------------------------------

  Widget _buildLocationSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8ECEB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. Text Details Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: lightMintBackground,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: primaryGreen,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _isLocationChangedFromMap
                                ? 'Location from map'
                                : 'Location detected',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: textDark,
                            ),
                          ),
                          if (_isLocationChangedFromMap) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: lightMintBackground,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'MAP',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: primaryGreen,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _selectedLocation.address,
                        style: const TextStyle(
                          fontSize: 13,
                          color: textMuted,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Button to launch map picker
                ElevatedButton.icon(
                  onPressed: _openMapLocationPicker,
                  icon: const Icon(Icons.edit_location_alt_outlined, size: 16),
                  label: const Text(
                    'Map',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: lightMintBackground,
                    foregroundColor: primaryGreen,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Interactive Mini-Map Preview
          GestureDetector(
            onTap: _openMapLocationPicker,
            child: Container(
              height: 125,
              width: double.infinity,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Stylized mini map vector canvas
                    CustomPaint(
                      painter: _MiniMapPreviewPainter(
                        pinRatio: _selectedLocation.mapOffsetRatio,
                      ),
                    ),

                    // Tap to pick on map overlay banner
                    Positioned(
                      bottom: 8,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFCCD7D3)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.touch_app, size: 13, color: primaryGreen),
                            SizedBox(width: 4),
                            Text(
                              'Tap map to change location',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Widget: Problem Card
  // ---------------------------------------------------------------------------

  Widget _buildProblemCard(int index) {
    final isSelected = _selectedProblemIndex == index;
    final item = _problemOptions[index];

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedProblemIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 94,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primaryGreen : const Color(0xFFE5EDE9),
            width: isSelected ? 2 : 1,
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              item['icon'] as IconData,
              color: isSelected ? primaryGreen : const Color(0xFF70857D),
              size: 26,
            ),
            const SizedBox(height: 8),
            Text(
              item['title'] as String,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? const Color(0xFF1E2926) : const Color(0xFF3C4D48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Custom Painter: Mini-Map Preview with Pin
// -----------------------------------------------------------------------------

class _MiniMapPreviewPainter extends CustomPainter {
  final Offset pinRatio;

  _MiniMapPreviewPainter({required this.pinRatio});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Background
    final backgroundPaint = Paint()..color = const Color(0xFFEEF2F0);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    // 2. Parks
    final parkPaint = Paint()..color = const Color(0xFFE1EAE4);

    final p1 = Path()
      ..moveTo(0, size.height * 0.1)
      ..lineTo(size.width * 0.35, size.height * 0.25)
      ..lineTo(size.width * 0.3, size.height * 0.8)
      ..lineTo(0, size.height * 0.7)
      ..close();
    canvas.drawPath(p1, parkPaint);

    final p2 = Path()
      ..moveTo(size.width * 0.65, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.7)
      ..lineTo(size.width * 0.72, size.height * 0.6)
      ..close();
    canvas.drawPath(p2, parkPaint);

    // 3. Roads
    final roadBorder = Paint()
      ..color = const Color(0xFFDFE6E3)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 24;

    final roadSurface = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 18;

    final roadA = Path()
      ..moveTo(-20, size.height * 0.35)
      ..cubicTo(
        size.width * 0.3,
        size.height * 0.45,
        size.width * 0.7,
        size.height * 0.25,
        size.width + 20,
        size.height * 0.35,
      );

    final roadB = Path()
      ..moveTo(size.width * 0.5, -20)
      ..lineTo(size.width * 0.45, size.height + 20);

    canvas.drawPath(roadA, roadBorder);
    canvas.drawPath(roadB, roadBorder);

    canvas.drawPath(roadA, roadSurface);
    canvas.drawPath(roadB, roadSurface);

    // 4. Pin at selected ratio
    final pinX = pinRatio.dx * size.width;
    final pinY = pinRatio.dy * size.height;

    // Pulse Ring
    final pulsePaint = Paint()
      ..color = const Color(0xFF086B5B).withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(pinX, pinY), 16, pulsePaint);

    // Pin shadow
    canvas.drawOval(
      Rect.fromCenter(center: Offset(pinX, pinY + 3), width: 14, height: 6),
      Paint()..color = Colors.black.withValues(alpha: 0.2),
    );

    // Pin marker
    final pinPaint = Paint()..color = const Color(0xFF086B5B);
    canvas.drawCircle(Offset(pinX, pinY), 8, pinPaint);

    final pinInnerPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(pinX, pinY), 3.5, pinInnerPaint);
  }

  @override
  bool shouldRepaint(covariant _MiniMapPreviewPainter oldDelegate) {
    return oldDelegate.pinRatio != pinRatio;
  }
}

// -----------------------------------------------------------------------------
// Custom Painter: Dashed Border
// -----------------------------------------------------------------------------

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double radius;

  _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashSpace,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final length = (distance + dashWidth < metric.length) ? dashWidth : metric.length - distance;
        final extractPath = metric.extractPath(distance, distance + length);
        canvas.drawPath(extractPath, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
