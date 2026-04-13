import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
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
  List<Map<String, dynamic>> _messages = [];
  List<String> _contextFileIds = [];
  List<String> _contextFolderIds = [];
  List<Map<String, dynamic>> _contextFiles = [];
  List<Map<String, dynamic>> _contextFolders = [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final hist = await ApiService.getChatHistory();
      if (mounted) setState(() {
        _messages = hist.cast<Map<String, dynamic>>();
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
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _VaultPickerSheet(
        files: files.cast<Map<String, dynamic>>(),
        folders: folders.cast<Map<String, dynamic>>(),
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
      body: Column(
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.tertiaryFixed,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: const Icon(Icons.smart_toy_outlined,
                      color: AppColors.onTertiaryFixedVar, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AI Clinical Assistant',
                        style: AppTextStyles.headline(18, FontWeight.w700)),
                    Row(
                      children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(
                          color: Colors.green, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text('Neural Engine Active',
                            style: AppTextStyles.label(11, AppColors.onSurfaceVariant)),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.onSurfaceVariant),
                  tooltip: 'Clear chat',
                  onPressed: () => setState(() => _messages.clear()),
                ),
              ],
            ),
          ),

          // ── Messages ──
          Expanded(
            child: _messages.isEmpty
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
    );
  }
}

// ─── Chat Bubble ───────────────────────────────────────────────────────────────
class _ChatBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message['role'] == 'user';
    final content = message['content'] ?? '';
    final time = (message['created_at'] ?? '').toString();
    final timeStr = time.length >= 16 ? time.substring(11, 16) : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppColors.primaryFixed,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
          ],
          Column(
            crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.5),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isUser ? AppColors.primary : AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(AppRadius.xl),
                      topRight: const Radius.circular(AppRadius.xl),
                      bottomLeft: Radius.circular(isUser ? AppRadius.xl : 4),
                      bottomRight: Radius.circular(isUser ? 4 : AppRadius.xl),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isUser ? AppColors.primary : Colors.black).withOpacity(0.08),
                        blurRadius: 12, offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Text(
                    content,
                    style: AppTextStyles.body(14, FontWeight.w400,
                        isUser ? Colors.white : AppColors.onSurface),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(timeStr, style: AppTextStyles.label(10, AppColors.outline)),
            ],
          ),
          if (isUser) ...[
            const SizedBox(width: 10),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primaryFixed,
              child: Text('JT', style: AppTextStyles.body(10, FontWeight.w700, AppColors.primary)),
            ),
          ],
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
      padding: const EdgeInsets.fromLTRB(40, 8, 40, 28),
      child: Column(
        children: [
          // Context tags
          if (hasContext)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppRadius.xl + 8),
              border: Border.all(color: AppColors.outlineVariant.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 24, offset: const Offset(0, 8))
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Vault picker
                _RoundBtn(icon: Icons.folder_open_outlined, onTap: onVaultPick),
                const SizedBox(width: 6),
                // Text input
                Expanded(
                  child: TextField(
                    controller: controller,
                    maxLines: 4,
                    minLines: 1,
                    decoration: const InputDecoration.collapsed(
                        hintText: 'Ask anything or refer to a Vault file...'),
                    style: AppTextStyles.body(14),
                    onSubmitted: (_) => onSend(),
                    textInputAction: TextInputAction.newline,
                  ),
                ),
                // Attach + Send
                _RoundBtn(icon: Icons.attach_file, onTap: onAttach),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onSend,
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryContainer],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      boxShadow: [
                        BoxShadow(color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 12, offset: const Offset(0, 4))
                      ],
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
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

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surfaceContainerHigh,
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox(width: 44, height: 44,
          child: Icon(icon, size: 20, color: AppColors.onSurfaceVariant)),
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
  Widget build(BuildContext context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.6,
    maxChildSize: 0.9,
    builder: (_, ctrl) => Column(
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
            controller: ctrl,
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
    ),
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
