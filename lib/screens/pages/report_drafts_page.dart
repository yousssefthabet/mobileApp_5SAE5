import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chargi/data/local/report_draft.dart';
import 'package:chargi/data/local/report_draft_db.dart';

/// Lists the report drafts saved on this device (SQLite).
/// Tapping a draft pops this page with the draft's id so the form can load it.
class ReportDraftsPage extends StatefulWidget {
  const ReportDraftsPage({super.key});

  @override
  State<ReportDraftsPage> createState() => _ReportDraftsPageState();
}

class _ReportDraftsPageState extends State<ReportDraftsPage> {
  static const Color primaryGreen = Color(0xFF086B5B);
  static const Color backgroundColor = Color(0xFFF7F9F8);
  static const Color textDark = Color(0xFF1E2926);
  static const Color textMuted = Color(0xFF7A8B86);
  static const Color cardBorder = Color(0xFFE8ECEB);

  final TextEditingController _searchCtrl = TextEditingController();
  late Future<List<ReportDraft>> _draftsFuture;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? 'local';

  @override
  void initState() {
    super.initState();
    _draftsFuture = ReportDraftDb.instance.getDrafts(_uid);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _draftsFuture = ReportDraftDb.instance.getDrafts(_uid, search: _searchCtrl.text);
    });
  }

  Future<void> _delete(ReportDraft draft) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this draft?'),
        content: Text('"${draft.displayTitle}" will be removed from this phone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ReportDraftDb.instance.deleteDraft(draft.id!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Draft deleted'), backgroundColor: primaryGreen),
    );
    _reload();
  }

  String _formatDate(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My drafts',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textDark),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => _reload(),
              decoration: InputDecoration(
                hintText: 'Search drafts',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: cardBorder),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Icon(Icons.phone_android, size: 14, color: textMuted),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Drafts are saved only on this phone and work offline.',
                    style: TextStyle(fontSize: 12, color: textMuted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<ReportDraft>>(
              future: _draftsFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Could not read drafts: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: primaryGreen));
                }
                final drafts = snapshot.data!;
                if (drafts.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.drafts_outlined, size: 48, color: textMuted),
                          const SizedBox(height: 10),
                          Text(
                            _searchCtrl.text.isEmpty ? 'No drafts yet' : 'No matching drafts',
                            style: const TextStyle(fontWeight: FontWeight.w700, color: textDark),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Use "Save as draft" on the report form to finish a report later.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: textMuted),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  itemCount: drafts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _buildDraftTile(drafts[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftTile(ReportDraft d) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.pop(context, d.id),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(color: Color(0xFFE2EFEA), shape: BoxShape.circle),
                child: const Icon(Icons.edit_note, color: primaryGreen),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, color: textDark),
                    ),
                    if (d.description.trim().isNotEmpty)
                      Text(
                        d.description.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: textMuted),
                      ),
                    const SizedBox(height: 3),
                    Text(
                      '${d.photoCount} photo(s) · '
                      '${d.locationChosen ? 'location set' : 'no location'} · '
                      '${_formatDate(d.updatedAt)}',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF9AA7A3)),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Delete draft',
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => _delete(d),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
