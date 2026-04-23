import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/theme.dart';
import '../../core/api_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  List<String> _contextFileIds = [];
  List<String> _contextFolderIds = [];
  List<Map<String, dynamic>> _contextFiles = [];
  List<Map<String, dynamic>> _contextFolders = [];
  List<Map<String, dynamic>> _sessions = [];
  String? _sessionId;
  bool _sending = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    await _loadSessions();
    if (_sessions.isNotEmpty) {
      _switchSession(_sessions.first['id']);
    } else {
      await _createNewChat();
    }
  }

  Future<void> _loadSessions() async {
    try {
      final sessions = await ApiService.getChatSessions();
      if (mounted) setState(() => _sessions = sessions.map((e) {
        final m = e as Map<String, dynamic>;
        return <String, dynamic>{
          'id': (m['id'] ?? m['session_id'] ?? '').toString(),
          'title': (m['title'] ?? m['name'] ?? 'New Consultation').toString(),
        };
      }).toList());
    } catch (_) {}
  }

  Future<void> _createNewChat() async {
    try {
      final res = await ApiService.createChatSession("New Consultation");
      final newId = res['session_id'];
      await _loadSessions();
      if (mounted) _switchSession(newId);
    } catch (_) {}
  }

  Future<void> _deleteSession(String sid) async {
    try {
      await ApiService.deleteChatSession(sid);
      await _loadSessions();
      if (_sessionId == sid) {
        if (_sessions.isNotEmpty) {
          _switchSession(_sessions.first['id']);
        } else {
          await _createNewChat();
        }
      }
    } catch (_) {}
  }

  Future<void> _renameSession(String sid, String currentTitle) async {
    final ctrl = TextEditingController(text: currentTitle);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Rename chat', style: AppTextStyles.headline(16, FontWeight.w600, AppColors.onSurface)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: AppTextStyles.body(14, FontWeight.w400, AppColors.onSurface),
          decoration: InputDecoration(
            hintText: 'Chat name',
            hintStyle: TextStyle(color: AppColors.onSurfaceVariant),
            filled: true,
            fillColor: AppColors.surfaceContainerHigh,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: AppColors.onSurfaceVariant))),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: Text('Rename', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (newTitle != null && newTitle.isNotEmpty && newTitle != currentTitle) {
      // Optimistic UI update
      setState(() {
        final idx = _sessions.indexWhere((s) => s['id'] == sid);
        if (idx != -1) _sessions[idx] = {..._sessions[idx], 'title': newTitle};
      });
      // Persist to backend
      try {
        await ApiService.updateChatSession(sid, title: newTitle);
      } catch (_) {}
    }
  }

  Future<void> _togglePin(String sid) async {
    final idx = _sessions.indexWhere((s) => s['id'] == sid);
    if (idx == -1) return;
    final currentlyPinned = (_sessions[idx]['is_pinned'] as int? ?? 0) == 1;
    final newPinned = !currentlyPinned;
    // Optimistic update
    setState(() => _sessions[idx] = {..._sessions[idx], 'is_pinned': newPinned ? 1 : 0});
    // Sort pinned first
    _sessions.sort((a, b) {
      final pa = (a['is_pinned'] as int? ?? 0);
      final pb = (b['is_pinned'] as int? ?? 0);
      return pb.compareTo(pa);
    });
    if (mounted) setState(() {});
    try {
      await ApiService.updateChatSession(sid, isPinned: newPinned);
    } catch (_) {}
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(newPinned ? 'Chat pinned' : 'Chat unpinned'), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _archiveSession(String sid) async {
    try {
      await ApiService.updateChatSession(sid, isArchived: true);
    } catch (_) {}
    // Remove from visible list
    setState(() => _sessions.removeWhere((s) => s['id'] == sid));
    if (_sessionId == sid) {
      if (_sessions.isNotEmpty) {
        _switchSession(_sessions.first['id'] as String);
      } else {
        await _createNewChat();
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat archived'), duration: Duration(seconds: 2)),
      );
    }
  }

  Future<void> _shareSession(String sid, String title) async {
    try {
      final transcript = await ApiService.exportChatSession(sid);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.surfaceContainerLowest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              Icon(Icons.ios_share_outlined, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('Export: $title', style: AppTextStyles.headline(14, FontWeight.w600), overflow: TextOverflow.ellipsis)),
            ],
          ),
          content: SizedBox(
            width: 500,
            height: 400,
            child: SingleChildScrollView(
              child: SelectableText(
                transcript,
                style: AppTextStyles.body(12, FontWeight.w400, AppColors.onSurfaceVariant),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close', style: TextStyle(color: AppColors.onSurfaceVariant)),
            ),
          ],
        ),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to export chat'), duration: Duration(seconds: 2)),
      );
    }
  }

  Future<void> _startGroupChat(String sid) async {
    try {
      final res = await ApiService.createChatSession("Group Discussion");
      final newId = res['session_id'];
      await _loadSessions();
      if (mounted) _switchSession(newId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New group discussion created'), duration: Duration(seconds: 2)),
      );
    } catch (_) {}
  }

  void _switchSession(String sid) {
    if (mounted) setState(() {
      _sessionId = sid;
      _messages = [];
    });
    _loadHistory(sid);
  }

  Future<void> _loadHistory(String sid) async {
    try {
      final hist = await ApiService.getChatHistory(sid);
      if (mounted && _sessionId == sid) setState(() {
        _messages = hist.map((e) => e as Map<String, dynamic>).toList();
      });
      _scrollToBottom();
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    _msgCtrl.clear();
    setState(() {
      _messages.add({'role': 'user', 'content': text, 'created_at': DateTime.now().toIso8601String()});
      _sending = true;
    });
    _scrollToBottom();

    try {
      final res = await ApiService.sendChat(
        text,
        _sessionId ?? '',
        fileIds: _contextFileIds,
        folderIds: _contextFolderIds,
      );
      if (mounted) setState(() {
        _messages.add({
          'role': 'assistant',
          'content': res['response'] ?? '',
          'created_at': DateTime.now().toIso8601String(),
        });
        _sending = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) setState(() {
        _messages.add({
          'role': 'assistant',
          'content': 'Error: Could not reach the server. Please check the backend is running.',
          'created_at': DateTime.now().toIso8601String(),
        });
        _sending = false;
      });
    }
  }

  Future<void> _attachFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    final uploaded = await ApiService.uploadFile(
      file.bytes!, file.name,
      mimeType: 'application/octet-stream',
    );
    setState(() {
      _contextFileIds.add(uploaded['file_id']);
      _contextFiles.add({'id': uploaded['file_id'], 'ai_name': file.name});
    });
  }

  Future<void> _showVaultPicker() async {
    final files = await ApiService.getFiles();
    final folders = await ApiService.getFolders();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
          child: _VaultPickerSheet(
            files: files.map((e) => e as Map<String, dynamic>).toList(),
            folders: folders.map((e) => e as Map<String, dynamic>).toList(),
            selectedFileIds: _contextFileIds,
            selectedFolderIds: _contextFolderIds,
            onDone: (fids, folids, fObjs, folObjs) {
              setState(() {
                _contextFileIds = fids;
                _contextFolderIds = folids;
                _contextFiles = fObjs;
                _contextFolders = folObjs;
              });
            },
          ),
        ),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Row(
        children: [
          // ── Consultations Sidebar (Left — Light Style) ──
          Container(
            width: 280,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              border: Border(right: BorderSide(color: AppColors.outlineVariant.withOpacity(0.4))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top actions
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // New Chat Button
                      Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: _createNewChat,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, color: AppColors.primary, size: 18),
                                const SizedBox(width: 12),
                                Text('New chat',
                                    style: AppTextStyles.body(14, FontWeight.w600, AppColors.primary)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Search Chats Row
                      Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {},
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Icon(Icons.search, color: AppColors.onSurfaceVariant, size: 18),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _searchCtrl,
                                    onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                                    style: AppTextStyles.body(14, FontWeight.w400, AppColors.onSurface),
                                    decoration: InputDecoration(
                                      hintText: 'Search chats',
                                      hintStyle: TextStyle(color: AppColors.onSurfaceVariant.withOpacity(0.6), fontSize: 14),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      filled: false,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
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
                ),

                const SizedBox(height: 8),

                // Recents Label
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
                  child: Text(
                    'Recents',
                    style: AppTextStyles.label(12, AppColors.onSurfaceVariant).copyWith(letterSpacing: 0.2),
                  ),
                ),

                // Session List
                Expanded(
                  child: _sessions.isEmpty
                      ? Center(
                          child: Text('No conversations yet.',
                              style: AppTextStyles.body(13, FontWeight.w400, AppColors.onSurfaceVariant)),
                        )
                      : Builder(
                          builder: (context) {
                            final query = _searchQuery;
                            final filtered = query.isEmpty
                                ? _sessions
                                : _sessions.where((s) {
                                    final title = (s['title'] as String?) ?? '';
                                    return title.toLowerCase().contains(query);
                                  }).toList();
                            return ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final s = filtered[index];
                                final sid = s['id']?.toString() ?? '';
                                final isActive = sid == _sessionId;
                                return _SessionTile(
                                  title: (s['title'] as String?) ?? 'New Consultation',
                                  isActive: isActive,
                                  isPinned: (s['is_pinned'] as int? ?? 0) == 1,
                                  onTap: () => _switchSession(sid),
                                  onRename: () => _renameSession(sid, (s['title'] as String?) ?? ''),
                                  onDelete: () => _deleteSession(sid),
                                  onPin: () => _togglePin(sid),
                                  onArchive: () => _archiveSession(sid),
                                  onShare: () => _shareSession(sid, (s['title'] as String?) ?? 'Chat'),
                                  onStartGroup: () => _startGroupChat(sid),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),

          // ── Main Chat Area ──
          Expanded(
            child: Column(
              children: [
                // ── Sleek Header ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.outlineVariant.withOpacity(0.3))),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.blur_on, color: AppColors.primary, size: 24),
                      const SizedBox(width: 12),
                      Text('Clinical Assistant',
                          style: AppTextStyles.headline(16, FontWeight.w600)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.clear_all, color: AppColors.onSurfaceVariant, size: 22),
                        tooltip: 'Clear Screen',
                        onPressed: () {
                          setState(() => _messages.clear());
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Chat screen cleared.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // ── Messages ──
                Expanded(
                  child: ((_messages as dynamic) == null || _messages.isEmpty)
                      ? _EmptyChatState()
                      : ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(40, 8, 40, 8),
                          itemCount: _messages.length + (_sending ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (_sending && i == _messages.length) {
                              return const _TypingIndicator();
                            }
                            return _ChatBubble(message: _messages[i]);
                          },
                        ),
                ),

                // ── Input Area ──
                _ChatInput(
                  controller: _msgCtrl,
                  contextFiles: _contextFiles,
                  contextFolders: _contextFolders,
                  onSend: _send,
                  onAttach: _attachFile,
                  onVaultPick: _showVaultPicker,
                  onRemoveFile: (id) => setState(() {
                    _contextFileIds.remove(id);
                    _contextFiles.removeWhere((f) => f['id'] == id);
                  }),
                  onRemoveFolder: (id) => setState(() {
                    _contextFolderIds.remove(id);
                    _contextFolders.removeWhere((f) => f['id'] == id);
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sleek Chat Bubble ────────────────────────────────────────────────────────
class _ChatBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message['role'] == 'user';
    final content = message['content'] ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: isUser ? AppColors.surfaceContainerHigh : AppColors.primaryContainer.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  isUser ? Icons.person_outline : Icons.blur_on,
                  size: 16,
                  color: isUser ? AppColors.onSurface : AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                isUser ? 'You' : 'Clinical Assistant',
                style: AppTextStyles.body(14, FontWeight.w600, AppColors.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: isUser
                ? Text(
                    content,
                    style: AppTextStyles.body(15, FontWeight.w400, AppColors.onSurface).copyWith(height: 1.6),
                  )
                : MarkdownBody(
                    data: content,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: AppTextStyles.body(15, FontWeight.w400, AppColors.onSurface).copyWith(height: 1.6),
                      h1: AppTextStyles.headline(22, FontWeight.w700, AppColors.onSurface),
                      h2: AppTextStyles.headline(18, FontWeight.w700, AppColors.onSurface),
                      h3: AppTextStyles.headline(16, FontWeight.w600, AppColors.onSurface),
                      listBullet: AppTextStyles.body(15, FontWeight.w700, AppColors.onSurfaceVariant),
                      strong: AppTextStyles.body(15, FontWeight.w700, AppColors.onSurface),
                      code: AppTextStyles.body(14, FontWeight.w400, AppColors.onSurfaceVariant),
                      codeblockDecoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      blockquote: AppTextStyles.body(15, FontWeight.w400, AppColors.onSurfaceVariant),
                      blockquoteDecoration: BoxDecoration(
                        border: Border(left: BorderSide(color: AppColors.outlineVariant, width: 4)),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: AppColors.primaryFixed,
              borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppRadius.xl),
              topRight: Radius.circular(AppRadius.xl),
              bottomRight: Radius.circular(AppRadius.xl),
              bottomLeft: Radius.circular(4),
            ),
          ),
          child: const Row(
            children: [
              _Dot(delay: 0), SizedBox(width: 4),
              _Dot(delay: 200), SizedBox(width: 4),
              _Dot(delay: 400),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});
  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _a = Tween<double>(begin: 1, end: 0.3)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _a,
    builder: (_, __) => Opacity(
      opacity: _a.value,
      child: Container(width: 7, height: 7, decoration: const BoxDecoration(
          color: AppColors.onSurfaceVariant, shape: BoxShape.circle)),
    ),
  );
}

// ─── Input Area ────────────────────────────────────────────────────────────────
class _ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final List<Map<String, dynamic>> contextFiles;
  final List<Map<String, dynamic>> contextFolders;
  final VoidCallback onSend, onAttach, onVaultPick;
  final ValueChanged<String> onRemoveFile, onRemoveFolder;

  const _ChatInput({
    required this.controller,
    required this.contextFiles,
    required this.contextFolders,
    required this.onSend,
    required this.onAttach,
    required this.onVaultPick,
    required this.onRemoveFile,
    required this.onRemoveFolder,
  });

  @override
  Widget build(BuildContext context) {
    final hasContext = contextFiles.isNotEmpty || contextFolders.isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(40, 16, 40, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Context tags
              if (hasContext)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12, left: 16),
                  child: Wrap(
                    spacing: 8, runSpacing: 6,
                    children: [
                      ...contextFiles.map((f) => _ContextTag(
                        label: f['ai_name'] ?? 'File',
                        icon: Icons.description_outlined,
                        color: AppColors.primary,
                        onRemove: () => onRemoveFile(f['id']),
                      )),
                      ...contextFolders.map((f) => _ContextTag(
                        label: f['name'] ?? 'Folder',
                        icon: Icons.folder_outlined,
                        color: AppColors.tertiary,
                        onRemove: () => onRemoveFolder(f['id']),
                      )),
                    ],
                  ),
                ),
              // Input box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.outlineVariant.withOpacity(0.5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Vault picker
                    _MinimalBtn(icon: Icons.folder_open_outlined, onTap: onVaultPick),
                    const SizedBox(width: 4),
                    // Attach
                    _MinimalBtn(icon: Icons.attach_file, onTap: onAttach),
                    const SizedBox(width: 16),
                    // Text input
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8.0, top: 2.0),
                        child: TextField(
                          controller: controller,
                          maxLines: 8,
                          minLines: 1,
                          decoration: const InputDecoration(
                              hintText: 'Ask the clinical assistant...',
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                          ),
                          style: AppTextStyles.body(15),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Send
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: GestureDetector(
                        onTap: onSend,
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.onSurface,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.arrow_upward, color: AppColors.surface, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text('AI responses may vary. Verify medical details independently.',
                    style: AppTextStyles.label(11, AppColors.onSurfaceVariant.withOpacity(0.5))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MinimalBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MinimalBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    customBorder: const CircleBorder(),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(8.0),
      child: Icon(icon, size: 20, color: AppColors.onSurfaceVariant.withOpacity(0.8)),
    ),
  );
}

class _ContextTag extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onRemove;
  const _ContextTag({required this.label, required this.icon,
      required this.color, required this.onRemove});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerHigh.withOpacity(0.7),
      borderRadius: BorderRadius.circular(AppRadius.full),
      border: Border.all(color: AppColors.outlineVariant.withOpacity(0.2)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Text(label.toUpperCase(),
            style: AppTextStyles.label(9, AppColors.onSurfaceVariant)
                .copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: onRemove,
          child: const Icon(Icons.close, size: 13, color: AppColors.outline),
        ),
      ],
    ),
  );
}

// ─── Vault Picker Sheet ────────────────────────────────────────────────────────
class _VaultPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> files, folders;
  final List<String> selectedFileIds, selectedFolderIds;
  final Function(List<String>, List<String>, List<Map<String, dynamic>>, List<Map<String, dynamic>>) onDone;
  const _VaultPickerSheet({
    required this.files, required this.folders,
    required this.selectedFileIds, required this.selectedFolderIds,
    required this.onDone,
  });

  @override
  State<_VaultPickerSheet> createState() => _VaultPickerSheetState();
}

class _VaultPickerSheetState extends State<_VaultPickerSheet> {
  late Set<String> _fileIds;
  late Set<String> _folderIds;

  @override
  void initState() {
    super.initState();
    _fileIds = Set.from(widget.selectedFileIds);
    _folderIds = Set.from(widget.selectedFolderIds);
  }

  @override
  Widget build(BuildContext context) => Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Row(
            children: [
              Text('Select Context', style: AppTextStyles.headline(18, FontWeight.w700)),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  widget.onDone(
                    _fileIds.toList(), _folderIds.toList(),
                    widget.files.where((f) => _fileIds.contains(f['id'])).toList(),
                    widget.folders.where((f) => _folderIds.contains(f['id'])).toList(),
                  );
                  Navigator.pop(context);
                },
                child: const Text('Done'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              if (widget.folders.isNotEmpty) ...[
                Text('FOLDERS', style: AppTextStyles.label(10).copyWith(
                    letterSpacing: 1.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ...widget.folders.map((f) => CheckboxListTile(
                  title: Text(f['name'], style: AppTextStyles.body(14, FontWeight.w600)),
                  secondary: const Icon(Icons.folder_outlined, color: AppColors.tertiary),
                  value: _folderIds.contains(f['id']),
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() =>
                      v! ? _folderIds.add(f['id']) : _folderIds.remove(f['id'])),
                )),
                const SizedBox(height: 16),
              ],
              if (widget.files.isNotEmpty) ...[
                Text('FILES', style: AppTextStyles.label(10).copyWith(
                    letterSpacing: 1.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ...widget.files.map((f) => CheckboxListTile(
                  title: Text(f['ai_name'] ?? f['original_name'] ?? 'File',
                      style: AppTextStyles.body(13, FontWeight.w500),
                      overflow: TextOverflow.ellipsis),
                  subtitle: Text(f['file_type'] ?? '',
                      style: AppTextStyles.label(11, AppColors.onSurfaceVariant)),
                  secondary: const Icon(Icons.description_outlined, color: AppColors.primary),
                  value: _fileIds.contains(f['id']),
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() =>
                      v! ? _fileIds.add(f['id']) : _fileIds.remove(f['id'])),
                )),
              ],
              if (widget.files.isEmpty && widget.folders.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text('No files in Vault yet.',
                        style: AppTextStyles.body(14, FontWeight.w400, AppColors.onSurfaceVariant)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
}

class _EmptyChatState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: AppColors.tertiaryFixed.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.smart_toy_outlined,
              size: 36, color: AppColors.onTertiaryFixedVar),
        ),
        const SizedBox(height: 20),
        Text('Ask your AI Clinical Assistant',
            style: AppTextStyles.headline(20, FontWeight.w700)),
        const SizedBox(height: 8),
        Text('Select files from the Vault or start typing a question.',
            style: AppTextStyles.body(14, FontWeight.w400, AppColors.onSurfaceVariant)),
      ],
    ),
  );
}

// ─── Session Tile with Context Menu ──────────────────────────────────────────
class _SessionTile extends StatefulWidget {
  final String title;
  final bool isActive;
  final bool isPinned;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onPin;
  final VoidCallback onArchive;
  final VoidCallback onShare;
  final VoidCallback onStartGroup;

  const _SessionTile({
    required this.title,
    required this.isActive,
    this.isPinned = false,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
    required this.onPin,
    required this.onArchive,
    required this.onShare,
    required this.onStartGroup,
  });

  @override
  State<_SessionTile> createState() => _SessionTileState();
}

class _SessionTileState extends State<_SessionTile> {
  bool _hovered = false;

  void _showMenu(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(Offset(box.size.width, 0), ancestor: overlay),
        box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final result = await showMenu<String>(
      context: context,
      position: position,
      color: AppColors.surfaceContainerLowest,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.outlineVariant.withOpacity(0.3)),
      ),
      items: [
        _menuItem('share', Icons.ios_share_outlined, 'Share'),
        _menuItem('group', Icons.group_add_outlined, 'Start a group chat'),
        _menuItem('rename', Icons.edit_outlined, 'Rename'),
        const PopupMenuDivider(height: 1),
        _menuItem('pin', Icons.push_pin_outlined, 'Pin chat'),
        _menuItem('archive', Icons.inventory_2_outlined, 'Archive'),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete_outline, size: 18, color: Colors.red),
              const SizedBox(width: 12),
              Text('Delete', style: AppTextStyles.body(14, FontWeight.w500, Colors.red)),
            ],
          ),
        ),
      ],
    );

    if (result == null) return;
    switch (result) {
      case 'share':   widget.onShare(); break;
      case 'group':   widget.onStartGroup(); break;
      case 'rename':  widget.onRename(); break;
      case 'pin':     widget.onPin(); break;
      case 'archive': widget.onArchive(); break;
      case 'delete':  widget.onDelete(); break;
    }
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label) =>
      PopupMenuItem<String>(
        value: value,
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.onSurfaceVariant),
            const SizedBox(width: 12),
            Text(label, style: AppTextStyles.body(14, FontWeight.w400, AppColors.onSurface)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.only(left: 14, right: 6, top: 8, bottom: 8),
          decoration: BoxDecoration(
            color: (widget.isActive || _hovered)
                ? AppColors.primaryContainer.withOpacity(0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w400,
                    color: widget.isActive ? AppColors.primary : AppColors.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.isPinned && !_hovered && !widget.isActive)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.push_pin, size: 12, color: AppColors.primary),
                ),
              if (_hovered || widget.isActive)
                Builder(
                  builder: (menuContext) => GestureDetector(
                    onTap: () => _showMenu(menuContext),
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(Icons.more_horiz, size: 16, color: AppColors.onSurfaceVariant),
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
