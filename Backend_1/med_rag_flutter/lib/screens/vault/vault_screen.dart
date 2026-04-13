import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme.dart';
import '../../core/api_service.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});
  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  List<dynamic> _folders = [];
  List<dynamic> _files = [];
  String? _selectedFolderId;
  bool _loading = true;
  String _search = '';
  bool _gridView = true;
  // AI summary panel
  Map<String, dynamic>? _summaryFile;
  bool _summaryVisible = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final folders = await ApiService.getFolders();
      final files = await ApiService.getFiles(folderId: _selectedFolderId);
      if (mounted) setState(() { _folders = folders; _files = files; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _upload() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true);
    if (result == null) return;
    for (final file in result.files) {
      if (file.bytes == null) continue;
      await ApiService.uploadFile(
        file.bytes!,
        file.name,
        folderId: _selectedFolderId,
        mimeType: _guessMime(file.extension ?? ''),
      );
    }
    _load();
  }

  String _guessMime(String ext) {
    const map = {'pdf': 'application/pdf', 'png': 'image/png', 'jpg': 'image/jpeg',
        'jpeg': 'image/jpeg', 'webp': 'image/webp'};
    return map[ext.toLowerCase()] ?? 'application/octet-stream';
  }

  List _filteredFiles() => _files.where((f) {
    if (_search.isEmpty) return true;
    final name = (f['ai_name'] ?? f['original_name'] ?? '').toString().toLowerCase();
    return name.contains(_search.toLowerCase());
  }).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(40, 40, _summaryVisible ? 430 : 40, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PERSONAL ARCHIVES',
                            style: AppTextStyles.label(10, AppColors.primary)
                                .copyWith(letterSpacing: 2, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text('Clinical Vault',
                            style: AppTextStyles.headline(32, FontWeight.w700)),
                      ],
                    ),
                    const Spacer(),
                    // Search
                    Container(
                      width: 260,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search, size: 18, color: AppColors.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration.collapsed(hintText: 'Search documents...'),
                              style: AppTextStyles.body(13),
                              onChanged: (v) => setState(() => _search = v),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _upload,
                      icon: const Icon(Icons.upload_file_outlined, size: 18),
                      label: const Text('Upload Record'),
                    ),
                  ],
                ),
                const SizedBox(height: 36),

                // Folders
                _FolderSection(
                  folders: _folders,
                  selected: _selectedFolderId,
                  onSelect: (id) { setState(() { _selectedFolderId = id; }); _load(); },
                  onNewFolder: _newFolder,
                ),
                const SizedBox(height: 36),

                // Files
                Row(
                  children: [
                    Text('RECENT ADDITIONS',
                        style: AppTextStyles.label(10, AppColors.onSurfaceVariant)
                            .copyWith(letterSpacing: 1.5, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.grid_view_outlined,
                          color: _gridView ? AppColors.primary : AppColors.onSurfaceVariant),
                      onPressed: () => setState(() => _gridView = true),
                    ),
                    IconButton(
                      icon: Icon(Icons.list_outlined,
                          color: !_gridView ? AppColors.primary : AppColors.onSurfaceVariant),
                      onPressed: () => setState(() => _gridView = false),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_filteredFiles().isEmpty)
                  _EmptyVault(onUpload: _upload)
                else
                  _gridView
                      ? _FileGrid(
                          files: _filteredFiles(),
                          onDelete: _deleteFile,
                          onDetails: (f) => setState(() {
                            _summaryFile = f; _summaryVisible = true;
                          }),
                        )
                      : _FileList(
                          files: _filteredFiles(),
                          onDelete: _deleteFile,
                          onDetails: (f) => setState(() {
                            _summaryFile = f; _summaryVisible = true;
                          }),
                        ),
              ],
            ),
          ),

          // AI Summary Panel
          if (_summaryVisible && _summaryFile != null)
            Positioned(
              right: 0, top: 0, bottom: 0,
              child: _AiSummaryPanel(
                file: _summaryFile!,
                onClose: () => setState(() => _summaryVisible = false),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _deleteFile(String id) async {
    await ApiService.deleteFile(id);
    _load();
  }

  Future<void> _newFolder() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: AppRadius.asymmetric,
        title: Text('New Folder', style: AppTextStyles.headline(18, FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Folder name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await ApiService.createFolder(name);
      _load();
    }
  }
}

// ─── Folder Section ────────────────────────────────────────────────────────────
class _FolderSection extends StatelessWidget {
  final List folders;
  final String? selected;
  final ValueChanged<String?> onSelect;
  final VoidCallback onNewFolder;
  const _FolderSection({required this.folders, required this.selected,
      required this.onSelect, required this.onNewFolder});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text('CATEGORIZED REPOSITORIES',
              style: AppTextStyles.label(10, AppColors.onSurfaceVariant)
                  .copyWith(letterSpacing: 1.5, fontWeight: FontWeight.w700)),
          const Spacer(),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.outlineVariant),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: onNewFolder,
            icon: const Icon(Icons.create_new_folder_outlined, size: 16),
            label: Text('New Folder', style: AppTextStyles.body(12, FontWeight.w600)),
          ),
        ],
      ),
      const SizedBox(height: 16),
      if (folders.isEmpty)
        Text('No folders yet', style: AppTextStyles.body(13, FontWeight.w400, AppColors.onSurfaceVariant))
      else
        Wrap(
          spacing: 16, runSpacing: 16,
          children: [
            _FolderChip(
              name: 'All',
              icon: Icons.folder_outlined,
              count: null,
              isSelected: selected == null,
              onTap: () => onSelect(null),
            ),
            ...folders.map((f) => _FolderChip(
              name: f['name'],
              icon: _folderIcon(f['icon'] ?? 'folder'),
              count: f['file_count'] as int?,
              isSelected: selected == f['id'],
              onTap: () => onSelect(f['id']),
            )),
          ],
        ),
    ],
  );

  IconData _folderIcon(String name) {
    switch (name) {
      case 'prescriptions': return Icons.medication_outlined;
      case 'radiology':     return Icons.medical_information_outlined;
      case 'biotech':       return Icons.biotech_outlined;
      case 'photo_camera':  return Icons.photo_camera_outlined;
      default:              return Icons.folder_outlined;
    }
  }
}

class _FolderChip extends StatelessWidget {
  final String name;
  final IconData icon;
  final int? count;
  final bool isSelected;
  final VoidCallback onTap;
  const _FolderChip({required this.name, required this.icon, required this.count,
      required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.surfaceContainerLowest : AppColors.surfaceContainerLow,
        borderRadius: AppRadius.asymmetricBR,
        boxShadow: isSelected
            ? [BoxShadow(color: AppColors.primary.withOpacity(0.08), blurRadius: 12)]
            : [],
        border: isSelected ? Border.all(color: AppColors.primary.withOpacity(0.15)) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20,
              color: isSelected ? AppColors.primaryContainer : AppColors.onSurfaceVariant),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: AppTextStyles.headline(14,
                  FontWeight.w600,
                  isSelected ? AppColors.primaryContainer : AppColors.onSurface)),
              if (count != null)
                Text('$count files',
                    style: AppTextStyles.label(11, AppColors.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    ),
  );
}

// ─── File Grid ─────────────────────────────────────────────────────────────────
class _FileGrid extends StatelessWidget {
  final List files;
  final ValueChanged<String> onDelete;
  final ValueChanged<Map<String, dynamic>> onDetails;
  const _FileGrid({required this.files, required this.onDelete, required this.onDetails});

  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2, crossAxisSpacing: 24, mainAxisSpacing: 24,
      childAspectRatio: 1.55,
    ),
    itemCount: files.length,
    itemBuilder: (_, i) => FileCard(
      file: files[i] as Map<String, dynamic>,
      onDelete: () => onDelete(files[i]['id']),
      onDetails: () => onDetails(files[i] as Map<String, dynamic>),
    ),
  );
}

class _FileList extends StatelessWidget {
  final List files;
  final ValueChanged<String> onDelete;
  final ValueChanged<Map<String, dynamic>> onDetails;
  const _FileList({required this.files, required this.onDelete, required this.onDetails});

  @override
  Widget build(BuildContext context) => ListView.separated(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: files.length,
    separatorBuilder: (_, __) => const SizedBox(height: 12),
    itemBuilder: (_, i) => FileCard(
      file: files[i] as Map<String, dynamic>,
      onDelete: () => onDelete(files[i]['id']),
      onDetails: () => onDetails(files[i] as Map<String, dynamic>),
    ),
  );
}

// ─── File Card ─────────────────────────────────────────────────────────────────
class FileCard extends StatefulWidget {
  final Map<String, dynamic> file;
  final VoidCallback onDelete;
  final VoidCallback onDetails;
  const FileCard({super.key, required this.file, required this.onDelete, required this.onDetails});

  @override
  State<FileCard> createState() => _FileCardState();
}

class _FileCardState extends State<FileCard> with SingleTickerProviderStateMixin {
  bool _previewExpanded = false;
  late AnimationController _anim;
  late Animation<double> _heightAnim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 300))
      ..addListener(() => setState(() {}));
    _heightAnim = Tween<double>(begin: 0, end: 120).animate(
        CurvedAnimation(parent: _anim, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  void _togglePreview() {
    setState(() => _previewExpanded = !_previewExpanded);
    _previewExpanded ? _anim.forward() : _anim.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.file;
    final isImage = f['file_type'] == 'image';
    final aiName = f['ai_name'] ?? f['original_name'] ?? 'Unknown';
    final size = (f['size_bytes'] as int?) ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.asymmetricBR,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // File icon
                Container(
                  width: 56, height: 70,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.outlineVariant.withOpacity(0.15)),
                  ),
                  child: Icon(
                    isImage ? Icons.image_outlined : Icons.description_outlined,
                    size: 28,
                    color: isImage ? AppColors.tertiary : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(AppRadius.full),
                            ),
                            child: Text('AI SUGGESTED',
                                style: AppTextStyles.label(9, AppColors.primary)
                                    .copyWith(fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 8),
                          Text(_formatSize(size),
                              style: AppTextStyles.label(9, AppColors.onSurfaceVariant)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(aiName,
                          style: AppTextStyles.headline(16, FontWeight.w700),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(f['uploaded_at']?.substring(0, 10) ?? '',
                          style: AppTextStyles.label(11, AppColors.onSurfaceVariant)),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20, color: AppColors.onSurfaceVariant),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  onSelected: (v) { if (v == 'delete') widget.onDelete(); },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'delete', child: Row(children: [
                      Icon(Icons.delete_outline, size: 16), SizedBox(width: 8), Text('Delete'),
                    ])),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: AppColors.outlineVariant.withOpacity(0.08), height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide.none,
                      backgroundColor: AppColors.surfaceContainerHigh,
                      foregroundColor: AppColors.onSurface,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: _togglePreview,
                    icon: Icon(_previewExpanded ? Icons.expand_less : Icons.visibility_outlined, size: 16),
                    label: Text('Preview', style: AppTextStyles.body(12, FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.primary.withOpacity(0.2)),
                      foregroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: widget.onDetails,
                    icon: const Icon(Icons.auto_awesome_outlined, size: 16),
                    label: Text('AI Details', style: AppTextStyles.body(12, FontWeight.w600, AppColors.primary)),
                  ),
                ),
              ],
            ),
            // Collapsible preview
            SizedBox(
              height: _heightAnim.value,
              child: ClipRect(
                child: Opacity(
                  opacity: _anim.value,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 60, height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isImage ? Icons.image_outlined : Icons.article_outlined,
                              size: 28, color: AppColors.onSurfaceVariant.withOpacity(0.4),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('AI SNAPSHOT',
                                    style: AppTextStyles.label(9, AppColors.onSurfaceVariant)
                                        .copyWith(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Text(
                                  f['ai_summary'] ?? 'No summary available. Click "AI Details" to generate one.',
                                  style: AppTextStyles.body(12, FontWeight.w400, AppColors.onSurfaceVariant)
                                      .copyWith(fontStyle: FontStyle.italic),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

// ─── AI Summary Panel ──────────────────────────────────────────────────────────
class _AiSummaryPanel extends StatelessWidget {
  final Map<String, dynamic> file;
  final VoidCallback onClose;
  const _AiSummaryPanel({required this.file, required this.onClose});

  @override
  Widget build(BuildContext context) => Container(
    width: 380,
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLowest.withOpacity(0.95),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 32, offset: const Offset(-4, 0))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 16, 0),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome_outlined, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AI Summary Insight',
                        style: AppTextStyles.headline(16, FontWeight.w700)),
                    Text('Synthesizing clinical data...',
                        style: AppTextStyles.label(11, AppColors.onSurfaceVariant)),
                  ],
                ),
              ),
              IconButton(onPressed: onClose, icon: const Icon(Icons.close, size: 18)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(file['ai_name'] ?? file['original_name'] ?? '',
                    style: AppTextStyles.headline(15, FontWeight.w700)),
                const SizedBox(height: 6),
                Text('${file['file_type']?.toUpperCase()} • Uploaded ${file['uploaded_at']?.substring(0, 10) ?? ''}',
                    style: AppTextStyles.label(11, AppColors.onSurfaceVariant)),
                const SizedBox(height: 20),
                _InsightBlock(
                  icon: Icons.trending_up,
                  color: AppColors.primary,
                  label: 'KEY TREND',
                  text: file['ai_summary'] ??
                      'No AI summary generated yet. This record has been indexed for chat queries.',
                ),
                const SizedBox(height: 12),
                _InsightBlock(
                  icon: Icons.warning_amber_outlined,
                  color: AppColors.tertiary,
                  label: 'CLINICAL NOTE',
                  text: 'File successfully processed and available for AI-assisted analysis in the Chat screen.',
                  bgColor: AppColors.tertiaryFixed.withOpacity(0.3),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _InsightBlock extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label, text;
  final Color? bgColor;
  const _InsightBlock({required this.icon, required this.color,
      required this.label, required this.text, this.bgColor});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: bgColor ?? AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.lg),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label, style: AppTextStyles.label(10, color).copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 8),
        Text(text, style: AppTextStyles.body(13, FontWeight.w400, AppColors.onSurface)),
      ],
    ),
  );
}

class _EmptyVault extends StatelessWidget {
  final VoidCallback onUpload;
  const _EmptyVault({required this.onUpload});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppColors.primaryFixed.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.folder_open_outlined, size: 36, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text('No records found', style: AppTextStyles.headline(18, FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Upload your first medical document to get started.',
              style: AppTextStyles.body(14, FontWeight.w400, AppColors.onSurfaceVariant)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onUpload,
            icon: const Icon(Icons.upload_file_outlined, size: 18),
            label: const Text('Upload Record'),
          ),
        ],
      ),
    ),
  );
}
