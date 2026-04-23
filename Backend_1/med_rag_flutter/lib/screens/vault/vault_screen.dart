import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import '../../core/theme.dart';
import '../../core/api_service.dart';
import 'file_viewer_screen.dart';

// ─── Main Screen ──────────────────────────────────────────────────────────────
class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});
  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  List<dynamic> _folders = [];
  List<dynamic> _files = [];
  String? _selectedFolderId;
  String? _selectedFolderName;
  bool _loading = true;
  String _search = '';
  final Set<String> _selectedIds = {};
  
  Map<String, dynamic>? _previewItem;
  bool _previewIsFolder = false;

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
      if (mounted) setState(() {
        _folders = folders;
        _files = files;
        _loading = false;
      });
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
        file.bytes!, file.name,
        folderId: _selectedFolderId,
        mimeType: _guessMime(file.extension ?? ''),
      );
    }
    _load();
  }

  String _guessMime(String ext) {
    const map = {
      'pdf': 'application/pdf', 'png': 'image/png',
      'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'webp': 'image/webp',
    };
    return map[ext.toLowerCase()] ?? 'application/octet-stream';
  }

  void _toggleSelect(String id) => setState(() {
    if (_selectedIds.contains(id)) _selectedIds.remove(id);
    else _selectedIds.add(id);
  });

  List<Map<String, dynamic>> _filteredFolders() {
    if (_selectedFolderId != null) return [];
    return _folders
        .where((f) => _search.isEmpty ||
            (f['name'] ?? '').toString().toLowerCase().contains(_search.toLowerCase()))
        .map((f) => Map<String, dynamic>.from(f as Map))
        .toList();
  }

  List<Map<String, dynamic>> _filteredFiles() => _files
      .where((f) => _search.isEmpty ||
          (f['ai_name'] ?? f['original_name'] ?? '').toString().toLowerCase()
              .contains(_search.toLowerCase()))
      .map((f) => Map<String, dynamic>.from(f as Map))
      .toList();

  Future<void> _deleteFile(String id) async {
    await ApiService.deleteFile(id);
    setState(() => _selectedIds.remove(id));
    _load();
  }

  Future<void> _deleteSelected() async {
    final toDeleteFiles = _selectedIds
        .where((id) => _files.any((f) => f['id'] == id))
        .toList();
    final toDeleteFolders = _selectedIds
        .where((id) => _folders.any((f) => f['id'] == id))
        .toList();

    for (final id in toDeleteFiles) await ApiService.deleteFile(id);
    for (final id in toDeleteFolders) {
      await ApiService.deleteFolder(id);
      if (_selectedFolderId == id) {
        if (mounted) {
          setState(() {
            _selectedFolderId = null;
            _selectedFolderName = null;
          });
        }
      }
    }

    setState(() => _selectedIds.clear());
    _load();
  }

  Future<void> _deleteFolder(String id) async {
    await ApiService.deleteFolder(id);
    if (_selectedFolderId == id) {
      if (mounted) setState(() {
        _selectedFolderId = null;
        _selectedFolderName = null;
      });
    }
    setState(() => _selectedIds.remove(id));
    _load();
  }

  Future<void> _renameFolder(String id, String currentName) async {
    final ctrl = TextEditingController(text: currentName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Rename Folder', style: AppTextStyles.headline(18, FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Folder name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && name != currentName) {
      try { await ApiService.updateFolder(id, name: name); } catch (_) {}
      if (_selectedFolderId == id) {
        if (mounted) setState(() => _selectedFolderName = name);
      }
      _load();
    }
  }

  Future<void> _summarizeFolder(String folderId) async {
    setState(() => _loading = true);
    try {
      final updated = await ApiService.summarizeFolder(folderId);
      if (!mounted) return;
      setState(() {
        _previewItem = updated;
        _previewIsFolder = true;
      });
      _load();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _summarizeFile(String fileId) async {
    setState(() => _loading = true);
    try {
      final updated = await ApiService.summarizeFile(fileId);
      if (!mounted) return;
      setState(() {
        _previewItem = updated;
        _previewIsFolder = false;
      });
      _load();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openFile(Map<String, dynamic> file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FileViewerScreen(file: file),
      ),
    );
  }

  Future<void> _newFolder() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      try { await ApiService.createFolder(name); } catch (_) {}
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final folders = _filteredFolders();
    final files = _filteredFiles();
    final hasContent = folders.isNotEmpty || files.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top Bar ──
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: _selectedIds.isNotEmpty
                ? _SelectionBar(
                    key: const ValueKey('selection'),
                    count: _selectedIds.length,
                    onClear: () => setState(() => _selectedIds.clear()),
                    onDelete: _deleteSelected,
                  )
                : _VaultHeader(
                    key: const ValueKey('header'),
                    selectedFolderName: _selectedFolderName,
                    search: _search,
                    onSearchChanged: (v) => setState(() => _search = v),
                    onUpload: _upload,
                    onNewFolder: _newFolder,
                    onBack: _selectedFolderId != null ? () {
                      setState(() {
                        _selectedFolderId = null;
                        _selectedFolderName = null;
                      });
                      _load();
                    } : null,
                  ),
          ),

          // ── Content ──
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : !hasContent
                        ? _EmptyVault(onUpload: _upload)
                        : SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(40, 8, 40, 40),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── Folders ──
                                if (folders.isNotEmpty) ...[
                                  _SectionLabel(label: 'Folders'),
                                  const SizedBox(height: 8),
                                  ...folders.map((f) => _FolderRow(
                                    folder: f,
                                    isSelected: _selectedIds.contains(f['id'] as String? ?? ''),
                                    anySelected: _selectedIds.isNotEmpty,
                                    onOpen: () {
                                      if (_selectedIds.isNotEmpty) {
                                        _toggleSelect(f['id'] as String? ?? '');
                                      } else {
                                        setState(() {
                                          _selectedFolderId = f['id'] as String?;
                                          _selectedFolderName = f['name'] as String?;
                                        });
                                        _load();
                                      }
                                    },
                                    onSelect: () => _toggleSelect(f['id'] as String? ?? ''),
                                    onDelete: () => _deleteFolder(f['id'] as String? ?? ''),
                                    onInfo: () => setState(() {
                                      _previewItem = Map<String, dynamic>.from(f as Map);
                                      _previewIsFolder = true;
                                    }),
                                    onRename: () => _renameFolder(f['id'] as String? ?? '', f['name'] as String? ?? ''),
                                    onSummarize: () => _summarizeFolder(f['id'] as String? ?? ''),
                                  )),
                                  const SizedBox(height: 28),
                                ],

                                // ── Files Grid ──
                                if (files.isNotEmpty) ...[
                                  _SectionLabel(label: 'Files'),
                                  const SizedBox(height: 12),
                                  GridView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 220,
                                      crossAxisSpacing: 14,
                                      mainAxisSpacing: 14,
                                      childAspectRatio: 0.72,
                                    ),
                                    itemCount: files.length,
                                    itemBuilder: (_, i) {
                                      final f = files[i];
                                      return _DriveFileCard(
                                        file: f,
                                        isSelected: _selectedIds.contains(f['id'] as String? ?? ''),
                                        anySelected: _selectedIds.isNotEmpty,
                                        onTap: () {
                                          if (_selectedIds.isNotEmpty) {
                                            _toggleSelect(f['id'] as String? ?? '');
                                          } else {
                                            setState(() {
                                              _previewItem = Map<String, dynamic>.from(f as Map);
                                              _previewIsFolder = false;
                                            });
                                          }
                                        },
                                        onSelect: () => _toggleSelect(f['id'] as String? ?? ''),
                                        onDelete: () => _deleteFile(f['id'] as String? ?? ''),
                                        onInfo: () => setState(() {
                                          _previewItem = Map<String, dynamic>.from(f as Map);
                                          _previewIsFolder = false;
                                        }),
                                        onSummarize: () => _summarizeFile(f['id'] as String? ?? ''),
                                        onPreview: () => _openFile(Map<String, dynamic>.from(f as Map)),
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                ),
                if (_previewItem != null)
                  _DetailsPanel(
                    item: _previewItem!,
                    isFolder: _previewIsFolder,
                    onClose: () => setState(() => _previewItem = null),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Selection Bar ─────────────────────────────────────────────────────────────
class _SelectionBar extends StatelessWidget {
  final int count;
  final VoidCallback onClear;
  final VoidCallback onDelete;
  const _SelectionBar({super.key, required this.count, required this.onClear, required this.onDelete});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerHigh,
      border: Border(
        bottom: BorderSide(color: AppColors.outlineVariant.withOpacity(0.25)),
      ),
    ),
    child: Row(
      children: [
        IconButton(
          icon: const Icon(Icons.close, size: 20),
          onPressed: onClear,
          color: AppColors.onSurface,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        const SizedBox(width: 16),
        Text('$count selected',
            style: AppTextStyles.body(15, FontWeight.w600)),
        const SizedBox(width: 20),
        OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.auto_awesome_outlined, size: 15),
          label: const Text('Summarize this folder'),
          style: OutlinedButton.styleFrom(
            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            side: BorderSide(color: AppColors.outlineVariant),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            foregroundColor: AppColors.onSurface,
          ),
        ),
        const Spacer(),
        _SelBtn(icon: Icons.person_add_outlined, tooltip: 'Share'),
        _SelBtn(icon: Icons.download_outlined, tooltip: 'Download'),
        _SelBtn(icon: Icons.drive_file_move_outlined, tooltip: 'Move'),
        _SelBtn(icon: Icons.link_outlined, tooltip: 'Copy link'),
        _SelBtn(icon: Icons.delete_outline, tooltip: 'Move to trash', onTap: onDelete),
        _SelBtn(icon: Icons.more_vert, tooltip: 'More options'),
      ],
    ),
  );
}

class _SelBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  const _SelBtn({required this.icon, required this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) => IconButton(
    icon: Icon(icon, size: 20, color: AppColors.onSurface),
    tooltip: tooltip,
    onPressed: onTap,
    padding: const EdgeInsets.all(8),
    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
  );
}

// ─── Vault Header ──────────────────────────────────────────────────────────────
class _VaultHeader extends StatelessWidget {
  final String? selectedFolderName;
  final String search;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onUpload;
  final VoidCallback onNewFolder;
  final VoidCallback? onBack;
  const _VaultHeader({
    super.key,
    required this.selectedFolderName,
    required this.search,
    required this.onSearchChanged,
    required this.onUpload,
    required this.onNewFolder,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(40, 28, 40, 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (onBack != null) ...[
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 20, color: AppColors.onSurfaceVariant),
            onPressed: onBack,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
          ),
          const SizedBox(width: 8),
        ],
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PERSONAL ARCHIVES',
                style: AppTextStyles.label(10, AppColors.primary)
                    .copyWith(letterSpacing: 2, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(selectedFolderName ?? 'Clinical Vault',
                style: AppTextStyles.headline(28, FontWeight.w700)),
          ],
        ),
        const Spacer(),
        // Search box
        Container(
          width: 240,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, size: 17, color: AppColors.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration.collapsed(hintText: 'Search...'),
                  style: AppTextStyles.body(13),
                  onChanged: onSearchChanged,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.outlineVariant),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          ),
          onPressed: onNewFolder,
          icon: const Icon(Icons.create_new_folder_outlined, size: 17),
          label: Text('New Folder', style: AppTextStyles.body(13, FontWeight.w500)),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
          onPressed: onUpload,
          icon: const Icon(Icons.upload_file_outlined, size: 17),
          label: const Text('Upload'),
        ),
      ],
    ),
  );
}

// ─── Section label ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(label,
        style: AppTextStyles.label(11, AppColors.onSurfaceVariant)
            .copyWith(letterSpacing: 1.4, fontWeight: FontWeight.w700)),
  );
}

// ─── Folder Row ────────────────────────────────────────────────────────────────
class _FolderRow extends StatefulWidget {
  final Map<String, dynamic> folder;
  final bool isSelected;
  final bool anySelected;
  final VoidCallback onOpen;
  final VoidCallback onSelect;
  final VoidCallback onDelete;
  final VoidCallback? onRename;
  final VoidCallback? onInfo;
  final VoidCallback? onSummarize;
  const _FolderRow({
    required this.folder,
    required this.isSelected,
    required this.anySelected,
    required this.onOpen,
    required this.onSelect,
    required this.onDelete,
    this.onRename,
    this.onInfo,
    this.onSummarize,
  });

  @override
  State<_FolderRow> createState() => _FolderRowState();
}

class _FolderRowState extends State<_FolderRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final name = widget.folder['name'] ?? 'Folder';
    final count = widget.folder['file_count'] ?? 0;
    final isSelected = widget.isSelected;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onOpen,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withOpacity(0.12)
                : _hovered
                    ? AppColors.surfaceContainerHigh
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary.withOpacity(0.35)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              // Checkbox / folder icon
              GestureDetector(
                onTap: widget.onSelect,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : (_hovered || widget.anySelected)
                            ? AppColors.surfaceContainerLowest
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: (_hovered || isSelected || widget.anySelected)
                        ? Border.all(
                            color: isSelected ? AppColors.primary : AppColors.outlineVariant,
                            width: 1.5)
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : Icon(Icons.folder, size: 20,
                            color: (_hovered || widget.anySelected)
                                ? AppColors.onSurface
                                : const Color(0xFF5F6368)),
                ),
              ),
              const SizedBox(width: 12),
              // Name & count
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: AppTextStyles.body(14, FontWeight.w500),
                        overflow: TextOverflow.ellipsis),
                    if (count > 0)
                      Text('$count ${count == 1 ? 'item' : 'items'}',
                          style: AppTextStyles.label(11, AppColors.onSurfaceVariant)),
                  ],
                ),
              ),
              // Three-dot menu
              if (_hovered || isSelected)
                _DriveContextMenu(
                  isFolder: true,
                  itemName: name,
                  onDelete: widget.onDelete,
                  onRename: widget.onRename,
                  onInfo: widget.onInfo,
                  onSummarize: widget.onSummarize,
                  buttonBuilder: (onTap) => InkWell(
                    onTap: onTap,
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(Icons.more_vert, size: 18,
                          color: AppColors.onSurfaceVariant),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Drive File Card ───────────────────────────────────────────────────────────
class _DriveFileCard extends StatefulWidget {
  final Map<String, dynamic> file;
  final bool isSelected;
  final bool anySelected;
  final VoidCallback onTap;
  final VoidCallback onSelect;
  final VoidCallback onDelete;
  final VoidCallback? onInfo;
  final VoidCallback? onSummarize;
  final VoidCallback? onPreview;
  const _DriveFileCard({
    required this.file,
    required this.isSelected,
    required this.anySelected,
    required this.onTap,
    required this.onSelect,
    required this.onDelete,
    this.onInfo,
    this.onSummarize,
    this.onPreview,
  });

  @override
  State<_DriveFileCard> createState() => _DriveFileCardState();
}

class _DriveFileCardState extends State<_DriveFileCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.file;
    final name = (f['ai_name'] ?? f['original_name'] ?? 'Untitled') as String;
    final fileType = (f['file_type'] ?? 'pdf') as String;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onPreview,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.primary.withOpacity(0.08)
                : AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isSelected
                  ? AppColors.primary.withOpacity(0.45)
                  : _hovered
                      ? AppColors.outlineVariant.withOpacity(0.5)
                      : AppColors.outlineVariant.withOpacity(0.2),
              width: widget.isSelected ? 2 : 1,
            ),
            boxShadow: _hovered && !widget.isSelected ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8, offset: const Offset(0, 2),
              )
            ] : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Thumbnail ──
              Expanded(
                child: Stack(
                  children: [
                    // Document preview fills the thumbnail area
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                      child: SizedBox.expand(
                        child: _DocumentThumbnail(
                          fileId: f['id'] as String?,
                          fileType: fileType,
                          fileName: name,
                        ),
                      ),
                    ),

                    // Checkbox (top-left)
                    if (_hovered || widget.isSelected || widget.anySelected)
                      Positioned(
                        top: 8, left: 8,
                        child: GestureDetector(
                          onTap: widget.onSelect,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 22, height: 22,
                            decoration: BoxDecoration(
                              color: widget.isSelected ? AppColors.primary : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: widget.isSelected
                                    ? AppColors.primary
                                    : Colors.grey.shade400,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 4,
                                )
                              ],
                            ),
                            child: widget.isSelected
                                ? const Icon(Icons.check, size: 14, color: Colors.white)
                                : null,
                          ),
                        ),
                      ),

                    // Three-dot menu (top-right)
                    if (_hovered || widget.isSelected)
                      Positioned(
                        top: 6, right: 6,
                        child: _DriveContextMenu(
                          isFolder: false,
                          itemName: name,
                          onDelete: widget.onDelete,
                          onInfo: widget.onInfo,
                          onSummarize: widget.onSummarize,
                          onOpen: widget.onPreview,
                          buttonBuilder: (onTap) => GestureDetector(
                            onTap: onTap,
                            child: Container(
                              width: 28, height: 28,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.92),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.12),
                                    blurRadius: 4,
                                  )
                                ],
                              ),
                              child: const Icon(Icons.more_vert, size: 16,
                                  color: Color(0xFF5F6368)),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Name Bar ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  color: _hovered
                      ? AppColors.surfaceContainerLow
                      : AppColors.surfaceContainerLowest,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(7)),
                  border: Border(
                    top: BorderSide(
                        color: AppColors.outlineVariant.withOpacity(0.18)),
                  ),
                ),
                child: Row(
                  children: [
                    _FileTypeBadge(fileType: fileType),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        style: AppTextStyles.body(12, FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Document Thumbnail ────────────────────────────────────────────────────────
class _DocumentThumbnail extends StatefulWidget {
  final String? fileId;
  final String fileType;
  final String fileName;
  const _DocumentThumbnail({this.fileId, required this.fileType, required this.fileName});

  @override
  State<_DocumentThumbnail> createState() => _DocumentThumbnailState();
}

class _DocumentThumbnailState extends State<_DocumentThumbnail> {
  String? _viewId;

  @override
  void initState() {
    super.initState();
    if (widget.fileType != 'image' && widget.fileId != null) {
      _viewId = 'thumb-pdf-${widget.fileId}-${DateTime.now().microsecondsSinceEpoch}';
      final url = ApiService.getFilePreviewUrl(widget.fileId!) + '#view=Fit&toolbar=0&navpanes=0&scrollbar=0';
      
      ui_web.platformViewRegistry.registerViewFactory(
        _viewId!,
        (int viewId) => html.IFrameElement()
          ..src = url
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.pointerEvents = 'none'
          ..style.overflow = 'hidden'
          ..setAttribute('scrolling', 'no'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fileType == 'image' && widget.fileId != null) {
      return Image.network(
        ApiService.getFilePreviewUrl(widget.fileId!),
        fit: BoxFit.cover,
        errorBuilder: (ctx, _, __) => Container(
          color: const Color(0xFFF3F4F6),
          child: const Center(
            child: Icon(Icons.broken_image_outlined, size: 40, color: Color(0xFF9CA3AF)),
          ),
        ),
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return Container(
            color: const Color(0xFFF3F4F6),
            child: Center(
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                      : null,
                ),
              ),
            ),
          );
        },
      );
    }

    if (_viewId != null) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        clipBehavior: Clip.hardEdge,
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: IgnorePointer(
          child: LayoutBuilder(
            builder: (ctx, constraints) => OverflowBox(
              // Add ~24 pixels to right to push the scrollbar completely off-screen
              maxWidth: constraints.maxWidth + 24,
              maxHeight: constraints.maxHeight + 2, // Slight height tweak to hide 1px native borders
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: constraints.maxWidth + 24,
                height: constraints.maxHeight + 2,
                child: HtmlElementView(viewType: _viewId!),
              ),
            ),
          ),
        ),
      );
    }

    // PDF / document preview fallback
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Simulated document header
          Container(
            height: 36,
            color: const Color(0xFFF8F9FA),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                _shimmerLine(56, 7),
                const SizedBox(width: 6),
                _shimmerLine(36, 7),
                const Spacer(),
                _shimmerLine(20, 7),
              ],
            ),
          ),
          // Content area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _docLine(1.0, thick: true),
                  const SizedBox(height: 5),
                  _docLine(0.85),
                  const SizedBox(height: 4),
                  _docLine(0.92),
                  const SizedBox(height: 4),
                  _docLine(0.68),
                  const SizedBox(height: 9),
                  _docLine(0.78),
                  const SizedBox(height: 4),
                  _docLine(0.95),
                  const SizedBox(height: 4),
                  _docLine(0.82),
                  const SizedBox(height: 4),
                  _docLine(0.56),
                  const SizedBox(height: 9),
                  _docLine(0.88),
                  const SizedBox(height: 4),
                  _docLine(0.73),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shimmerLine(double width, double height) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: const Color(0xFFDADCE0),
      borderRadius: BorderRadius.circular(3),
    ),
  );

  Widget _docLine(double fraction, {bool thick = false}) => LayoutBuilder(
    builder: (_, c) => Container(
      width: c.maxWidth * fraction,
      height: thick ? 8 : 5.5,
      decoration: BoxDecoration(
        color: thick ? const Color(0xFF5F6368) : const Color(0xFFDADCE0),
        borderRadius: BorderRadius.circular(3),
      ),
    ),
  );
}

// ─── File Type Badge ───────────────────────────────────────────────────────────
class _FileTypeBadge extends StatelessWidget {
  final String fileType;
  const _FileTypeBadge({required this.fileType});

  @override
  Widget build(BuildContext context) {
    final isPdf = fileType == 'pdf' || fileType == 'document';
    final isImg = fileType == 'image';
    final label = isImg ? 'IMG' : isPdf ? 'PDF' : 'DOC';
    final color = isImg ? const Color(0xFF34A853) : const Color(0xFFEA4335);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color, borderRadius: BorderRadius.circular(3)),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800,
              letterSpacing: 0.5)),
    );
  }
}

// ─── Drive-style Context Menu ──────────────────────────────────────────────────
typedef _MenuButtonBuilder = Widget Function(VoidCallback onTap);

class _DriveContextMenu extends StatelessWidget {
  final bool isFolder;
  final String itemName;
  final VoidCallback onDelete;
  final VoidCallback? onRename;
  final VoidCallback? onInfo;
  final VoidCallback? onSummarize;
  final VoidCallback? onOpen;
  final _MenuButtonBuilder buttonBuilder;

  const _DriveContextMenu({
    required this.isFolder,
    required this.itemName,
    required this.onDelete,
    this.onRename,
    this.onInfo,
    this.onSummarize,
    this.onOpen,
    required this.buttonBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (ctx) => buttonBuilder(() => _showMenu(ctx)),
    );
  }

  void _showMenu(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final position = box.localToGlobal(Offset.zero);
    final size = box.size;

    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy + size.height,
        position.dx + 260,
        position.dy + size.height + 400,
      ),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      items: [
        if (!isFolder) _item('open', Icons.open_in_new_outlined, 'Open'),
        _item('download', Icons.download_outlined, 'Download'),
        _item('rename', Icons.edit_outlined, 'Rename', shortcut: 'Ctrl+Alt+E'),
        _item('summarize', Icons.auto_awesome_outlined,
            isFolder ? 'Summarize this folder' : 'Summarize file'),
        const PopupMenuDivider(height: 1),
        _item('share', Icons.person_add_outlined, 'Share', hasArrow: true),
        _item('organize', Icons.folder_outlined, 'Organize', hasArrow: true),
        _item('info', Icons.info_outline,
            isFolder ? 'Folder information' : 'File information', hasArrow: true),
        const PopupMenuDivider(height: 1),
        _item('trash', Icons.delete_outline, 'Move to trash',
            shortcut: 'Delete', isDestructive: true),
      ],
    );

    if (result == 'trash') {
      onDelete();
    } else if (result == 'rename' && onRename != null) {
      onRename!();
    } else if (result == 'info' && onInfo != null) {
      onInfo!();
    } else if (result == 'summarize' && onSummarize != null) {
      onSummarize!();
    } else if ((result == 'open' || result == 'download') && onOpen != null) {
      onOpen!();
    }
  }

  PopupMenuItem<String> _item(
    String value,
    IconData icon,
    String label, {
    String? shortcut,
    bool hasArrow = false,
    bool isDestructive = false,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(icon, size: 18,
              color: isDestructive ? const Color(0xFFD93025) : const Color(0xFF3C4043)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: TextStyle(
                  fontSize: 13.5,
                  color: isDestructive ? const Color(0xFFD93025) : const Color(0xFF3C4043),
                  fontWeight: FontWeight.w400,
                )),
          ),
          if (shortcut != null) ...[
            const SizedBox(width: 12),
            Text(shortcut,
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF9AA0A6))),
          ],
          if (hasArrow)
            const Icon(Icons.chevron_right, size: 16, color: Color(0xFF9AA0A6)),
        ],
      ),
    );
  }
}

// ─── Empty State ───────────────────────────────────────────────────────────────
class _EmptyVault extends StatelessWidget {
  final VoidCallback onUpload;
  const _EmptyVault({required this.onUpload});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
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
  );
}

// Public re-exports used by other screens (FolderCard / FileCard)
class FolderCard extends StatelessWidget {
  final Map<String, dynamic> folder;
  final VoidCallback onTap;
  const FolderCard({super.key, required this.folder, required this.onTap});

  @override
  Widget build(BuildContext context) => _FolderRow(
    folder: folder,
    isSelected: false,
    anySelected: false,
    onOpen: onTap,
    onSelect: () {},
    onDelete: () {},
  );
}

class FileCard extends StatelessWidget {
  final Map<String, dynamic> file;
  final VoidCallback onDelete;
  final VoidCallback onDetails;
  const FileCard({super.key, required this.file, required this.onDelete, required this.onDetails});

  @override
  Widget build(BuildContext context) => _DriveFileCard(
    file: file,
    isSelected: false,
    anySelected: false,
    onTap: onDetails,
    onSelect: () {},
    onDelete: onDelete,
  );
}

// ─── Details Panel ─────────────────────────────────────────────────────────────
class _DetailsPanel extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isFolder;
  final VoidCallback onClose;

  const _DetailsPanel({
    super.key,
    required this.item,
    required this.isFolder,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final name = isFolder
        ? (item['name'] ?? 'Folder')
        : (item['ai_name'] ?? item['original_name'] ?? 'Untitled');
    final aiSummary = item['ai_summary'] as String?;
    final date = isFolder ? item['created_at'] : item['uploaded_at'];
    final parsedDate = date != null ? DateTime.tryParse(date.toString()) : null;
    final dateStr = parsedDate != null ? '${parsedDate.month}/${parsedDate.day}/${parsedDate.year}' : 'Unknown date';

    return Container(
      width: 320,
      margin: const EdgeInsets.only(left: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: AppColors.outlineVariant.withOpacity(0.3))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(isFolder ? 'Folder Details' : 'File Details',
                      style: AppTextStyles.headline(16, FontWeight.w600)),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // THUMBNAIL
                  Container(
                    width: double.infinity,
                    height: 160,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
                    ),
                    child: Center(
                      child: isFolder
                          ? const Icon(Icons.folder, size: 64, color: AppColors.primary)
                          : Stack(
                              children: [
                                _DocumentThumbnail(
                                  fileId: item['id'] as String?,
                                  fileType: item['file_type'] ?? 'pdf',
                                  fileName: name.toString(),
                                ),
                                if (!isFolder)
                                  Positioned(
                                    bottom: 8, right: 8,
                                    child: FloatingActionButton.small(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => FileViewerScreen(file: item)),
                                        );
                                      },
                                      backgroundColor: Colors.white.withOpacity(0.9),
                                      child: const Icon(Icons.open_in_new, size: 18, color: AppColors.primary),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(name.toString(), style: AppTextStyles.body(16, FontWeight.w600)),
                  const SizedBox(height: 24),
                  
                  // AI OVERVIEW
                  if (aiSummary != null && aiSummary.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text('AI Overview', style: AppTextStyles.label(12, AppColors.primary).copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.4)),
                      ),
                      child: MarkdownBody(
                        data: aiSummary,
                        styleSheet: MarkdownStyleSheet(
                          p: AppTextStyles.body(13, FontWeight.w400, AppColors.onSurface.withOpacity(0.85)),
                          h1: AppTextStyles.headline(18, FontWeight.w700, AppColors.primary),
                          h2: AppTextStyles.headline(15, FontWeight.w600, AppColors.onSurface),
                          h3: AppTextStyles.headline(14, FontWeight.w600, AppColors.onSurfaceVariant),
                          listBullet: AppTextStyles.body(14, FontWeight.w700, AppColors.primary),
                          strong: AppTextStyles.body(13, FontWeight.w700, AppColors.onSurface),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // PROPS
                  Text('Information', style: AppTextStyles.label(12, AppColors.onSurfaceVariant).copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  _PropRow('Type', isFolder ? 'Folder' : (item['file_type'] ?? 'File')),
                  _PropRow(isFolder ? 'Created' : 'Uploaded', dateStr),
                  if (item['size_bytes'] != null)
                    _PropRow('Size', '${((item['size_bytes'] as int) / 1024).toStringAsFixed(1)} KB'),
                  if (isFolder && item['file_count'] != null)
                    _PropRow('Items', '${item['file_count']}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PropRow extends StatelessWidget {
  final String label;
  final String value;
  const _PropRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: AppTextStyles.body(13, FontWeight.w500, AppColors.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value, style: AppTextStyles.body(13, FontWeight.w400, AppColors.onSurface)),
          ),
        ],
      ),
    );
  }
}
