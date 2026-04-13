import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/api_service.dart';

class NotebookScreen extends StatefulWidget {
  const NotebookScreen({super.key});
  @override
  State<NotebookScreen> createState() => _NotebookScreenState();
}

class _NotebookScreenState extends State<NotebookScreen> {
  List<Map<String, dynamic>> _notes = [];
  Map<String, dynamic>? _activeNote;
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    try {
      final notes = await ApiService.getNotes();
      if (mounted) setState(() {
        _notes = notes.cast<Map<String, dynamic>>();
        _loading = false;
        if (_notes.isNotEmpty && _activeNote == null) _selectNote(_notes.first);
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectNote(Map<String, dynamic> note) {
    setState(() {
      _activeNote = note;
      _titleCtrl.text = note['title'] ?? '';
      _contentCtrl.text = note['content'] ?? '';
    });
  }

  Future<void> _newNote() async {
    final note = await ApiService.createNote(title: 'New Entry', content: '');
    setState(() => _notes.insert(0, note));
    _selectNote(note);
  }

  Future<void> _saveNote() async {
    if (_activeNote == null) return;
    setState(() => _saving = true);
    final updated = await ApiService.updateNote(
      _activeNote!['id'],
      title: _titleCtrl.text,
      content: _contentCtrl.text,
    );
    final idx = _notes.indexWhere((n) => n['id'] == updated['id']);
    if (idx >= 0) _notes[idx] = updated;
    setState(() { _activeNote = updated; _saving = false; });
  }

  Future<void> _deleteNote(String id) async {
    await ApiService.deleteNote(id);
    setState(() {
      _notes.removeWhere((n) => n['id'] == id);
      if (_activeNote?['id'] == id) {
        _activeNote = _notes.isNotEmpty ? _notes.first : null;
        _titleCtrl.text = _activeNote?['title'] ?? '';
        _contentCtrl.text = _activeNote?['content'] ?? '';
      }
    });
  }

  Future<void> _togglePin(Map<String, dynamic> note) async {
    final pinned = !(note['is_pinned'] == true || note['is_pinned'] == 1);
    final updated = await ApiService.updateNote(note['id'], isPinned: pinned);
    final idx = _notes.indexWhere((n) => n['id'] == updated['id']);
    if (idx >= 0) setState(() => _notes[idx] = updated);
  }

  @override
  Widget build(BuildContext context) {
    final pinnedNotes = _notes.where((n) => n['is_pinned'] == true || n['is_pinned'] == 1).toList();
    final recentNotes = _notes.where((n) => n['is_pinned'] != true && n['is_pinned'] != 1).toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // ── Editor (left) ──
                Expanded(
                  flex: 7,
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('CLINICAL DOCUMENTATION',
                                    style: AppTextStyles.label(10, AppColors.onSurfaceVariant)
                                        .copyWith(letterSpacing: 2, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Text('Notebook',
                                    style: AppTextStyles.headline(40, FontWeight.w700)),
                              ],
                            ),
                            const Spacer(),
                            ElevatedButton.icon(
                              onPressed: _newNote,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('New Entry'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // Editor card
                        if (_activeNote != null)
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(40),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLowest,
                                borderRadius: AppRadius.asymmetricBR,
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.04),
                                      blurRadius: 24, offset: const Offset(0, 4))
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Title
                                  TextField(
                                    controller: _titleCtrl,
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      filled: false,
                                      hintText: 'Entry title...',
                                      hintStyle: AppTextStyles.headline(28, FontWeight.w700,
                                          AppColors.outlineVariant),
                                    ),
                                    style: AppTextStyles.headline(28, FontWeight.w700),
                                  ),
                                  const SizedBox(height: 8),
                                  // Date/author meta
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today_outlined,
                                          size: 14, color: AppColors.onSurfaceVariant),
                                      const SizedBox(width: 6),
                                      Text(
                                        (_activeNote!['updated_at'] ?? '').toString().substring(0, 10),
                                        style: AppTextStyles.label(12, AppColors.onSurfaceVariant),
                                      ),
                                      const SizedBox(width: 20),
                                      const Icon(Icons.person_outline,
                                          size: 14, color: AppColors.onSurfaceVariant),
                                      const SizedBox(width: 6),
                                      Text('Julian Thorne',
                                          style: AppTextStyles.label(12, AppColors.onSurfaceVariant)),
                                    ],
                                  ),
                                  Divider(
                                      color: AppColors.outlineVariant.withOpacity(0.15),
                                      height: 32),
                                  // Body
                                  Expanded(
                                    child: TextField(
                                      controller: _contentCtrl,
                                      maxLines: null,
                                      expands: true,
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        filled: false,
                                        hintText: 'Begin writing your clinical notes here...',
                                        hintStyle: AppTextStyles.body(16, FontWeight.w400,
                                            AppColors.outlineVariant),
                                      ),
                                      style: AppTextStyles.body(16, FontWeight.w400,
                                          AppColors.onSurface.withOpacity(0.85)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.edit_note_outlined,
                                      size: 48, color: AppColors.onSurfaceVariant),
                                  const SizedBox(height: 12),
                                  Text('Select or create a note to start writing.',
                                      style: AppTextStyles.body(15, FontWeight.w400,
                                          AppColors.onSurfaceVariant)),
                                ],
                              ),
                            ),
                          ),

                        if (_activeNote != null) ...[
                          const SizedBox(height: 12),
                          // Formatting toolbar
                          _FormattingToolbar(
                            onSave: _saveNote,
                            saving: _saving,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // ── AI Insights Sidebar (right) ──
                Container(
                  width: 340,
                  color: AppColors.surface,
                  padding: const EdgeInsets.fromLTRB(0, 40, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: AppColors.primary, size: 22),
                          const SizedBox(width: 8),
                          Text('AI Insights',
                              style: AppTextStyles.headline(20, FontWeight.w700)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryFixed.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(AppRadius.full),
                            ),
                            child: Text('${_notes.length} SAVED',
                                style: AppTextStyles.label(9, AppColors.primary)
                                    .copyWith(fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: _notes.isEmpty
                            ? Center(
                                child: Text('No notes yet. Notes saved from chat will appear here.',
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.body(13, FontWeight.w400,
                                        AppColors.onSurfaceVariant)),
                              )
                            : ListView(
                                children: [
                                  if (pinnedNotes.isNotEmpty) ...[
                                    _SectionLabel(icon: Icons.push_pin_outlined, label: 'Pinned'),
                                    ...pinnedNotes.map((n) => _InsightCard(
                                          note: n,
                                          isActive: _activeNote?['id'] == n['id'],
                                          onTap: () => _selectNote(n),
                                          onPin: () => _togglePin(n),
                                          onDelete: () => _deleteNote(n['id']),
                                          onInsert: () => setState(() {
                                            _contentCtrl.text += '\n\n${n['content']}';
                                          }),
                                        )),
                                    const SizedBox(height: 16),
                                  ],
                                  if (recentNotes.isNotEmpty) ...[
                                    _SectionLabel(icon: Icons.schedule_outlined, label: 'Recent'),
                                    ...recentNotes.map((n) => _InsightCard(
                                          note: n,
                                          isActive: _activeNote?['id'] == n['id'],
                                          onTap: () => _selectNote(n),
                                          onPin: () => _togglePin(n),
                                          onDelete: () => _deleteNote(n['id']),
                                          onInsert: () => setState(() {
                                            _contentCtrl.text += '\n\n${n['content']}';
                                          }),
                                        )),
                                  ],
                                  // Drop zone
                                  const SizedBox(height: 16),
                                  DottedDropZone(),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _FormattingToolbar extends StatelessWidget {
  final VoidCallback onSave;
  final bool saving;
  const _FormattingToolbar({required this.onSave, required this.saving});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerHighest.withOpacity(0.9),
      borderRadius: BorderRadius.circular(AppRadius.xl),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20)],
    ),
    child: Row(
      children: [
        _ToolBtn(icon: Icons.format_bold),
        _ToolBtn(icon: Icons.format_italic),
        _ToolBtn(icon: Icons.format_underlined),
        const _Divider(),
        _ToolBtn(icon: Icons.format_align_left),
        _ToolBtn(icon: Icons.format_align_center),
        const _Divider(),
        _ToolBtn(icon: Icons.format_list_bulleted),
        _ToolBtn(icon: Icons.format_list_numbered),
        _ToolBtn(icon: Icons.link),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: onSave,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          icon: saving
              ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.save_outlined, size: 16),
          label: Text(saving ? 'Saving...' : 'Save Changes',
              style: AppTextStyles.body(13, FontWeight.w600, Colors.white)),
        ),
      ],
    ),
  );
}

class _ToolBtn extends StatelessWidget {
  final IconData icon;
  const _ToolBtn({required this.icon});

  @override
  Widget build(BuildContext context) => IconButton(
    icon: Icon(icon, size: 18, color: AppColors.onSurfaceVariant),
    onPressed: () {},
    splashRadius: 18,
    tooltip: '',
  );
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => Container(
    width: 1, height: 22, margin: const EdgeInsets.symmetric(horizontal: 6),
    color: AppColors.outlineVariant.withOpacity(0.4),
  );
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Icon(icon, size: 13, color: AppColors.onSurfaceVariant.withOpacity(0.5)),
        const SizedBox(width: 6),
        Text(label.toUpperCase(),
            style: AppTextStyles.label(9, AppColors.onSurfaceVariant.withOpacity(0.5))
                .copyWith(letterSpacing: 1.5, fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

class _InsightCard extends StatelessWidget {
  final Map<String, dynamic> note;
  final bool isActive;
  final VoidCallback onTap, onPin, onDelete, onInsert;
  const _InsightCard({
    required this.note, required this.isActive,
    required this.onTap, required this.onPin,
    required this.onDelete, required this.onInsert,
  });

  @override
  Widget build(BuildContext context) {
    final source = note['source'] ?? 'manual';
    final isPinned = note['is_pinned'] == true || note['is_pinned'] == 1;
    final sourceColor = source == 'chat' ? AppColors.primary : AppColors.tertiary;
    final sourceBg = source == 'chat'
        ? AppColors.primaryFixed.withOpacity(0.4)
        : AppColors.tertiaryFixed.withOpacity(0.4);
    final sourceLabel = source == 'chat' ? 'FROM CHAT' : 'MANUAL';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
              color: isActive ? AppColors.primary.withOpacity(0.2) : AppColors.outlineVariant.withOpacity(0.15),
              width: isActive ? 2 : 1,
            ),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(note['title'] ?? 'Untitled',
                            style: AppTextStyles.body(12, FontWeight.w700),
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: sourceBg,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(sourceLabel,
                                  style: AppTextStyles.label(8, sourceColor)
                                      .copyWith(fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              (note['created_at'] ?? '').toString().substring(0, 10),
                              style: AppTextStyles.label(9, AppColors.onSurfaceVariant.withOpacity(0.5)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Insert button
                  Material(
                    color: AppColors.primary.withOpacity(0.06),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onInsert,
                      child: const SizedBox(width: 32, height: 32,
                          child: Icon(Icons.add, size: 16, color: AppColors.primary)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                note['content'] ?? '',
                style: AppTextStyles.body(12, FontWeight.w400, AppColors.onSurfaceVariant)
                    .copyWith(fontStyle: FontStyle.italic),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              Divider(color: AppColors.outlineVariant.withOpacity(0.1), height: 20),
              Row(
                children: [
                  GestureDetector(
                    onTap: onPin,
                    child: Row(
                      children: [
                        Icon(
                          isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                          size: 14,
                          color: isPinned ? AppColors.primary : AppColors.onSurfaceVariant.withOpacity(0.3),
                        ),
                        const SizedBox(width: 4),
                        Text('Pin',
                            style: AppTextStyles.label(10, AppColors.onSurfaceVariant.withOpacity(0.4))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: onDelete,
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline, size: 14, color: AppColors.error),
                        const SizedBox(width: 4),
                        Text('Delete', style: AppTextStyles.label(10, AppColors.error)),
                      ],
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
}

class DottedDropZone extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerHigh.withOpacity(0.3),
      borderRadius: BorderRadius.circular(AppRadius.xl),
      border: Border.all(
        color: AppColors.outlineVariant.withOpacity(0.3),
        style: BorderStyle.solid,
        width: 2,
      ),
    ),
    child: Column(
      children: [
        Icon(Icons.archive_outlined, size: 32,
            color: AppColors.outlineVariant.withOpacity(0.5)),
        const SizedBox(height: 8),
        Text('Drop items here to archive from Chat or Vault',
            textAlign: TextAlign.center,
            style: AppTextStyles.body(11, FontWeight.w600,
                AppColors.onSurfaceVariant.withOpacity(0.4))),
      ],
    ),
  );
}
