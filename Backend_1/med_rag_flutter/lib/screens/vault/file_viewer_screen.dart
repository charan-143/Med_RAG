import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/api_service.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

class FileViewerScreen extends StatefulWidget {
  final Map<String, dynamic> file;
  const FileViewerScreen({super.key, required this.file});

  @override
  State<FileViewerScreen> createState() => _FileViewerScreenState();
}

class _FileViewerScreenState extends State<FileViewerScreen> {
  late String _viewId;
  late String _url;

  @override
  void initState() {
    super.initState();
    final fileId = widget.file['id'] as String;
    _url = ApiService.getFilePreviewUrl(fileId);
    _viewId = 'pdf-viewer-$fileId-${DateTime.now().millisecondsSinceEpoch}';

    final fileType = widget.file['file_type'] ?? 'pdf';
    if (fileType != 'image') {
      ui_web.platformViewRegistry.registerViewFactory(
        _viewId,
        (int viewId) => html.IFrameElement()
          ..src = _url
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.file['ai_name'] ?? widget.file['original_name'] ?? 'View File') as String;
    final fileType = widget.file['file_type'] ?? 'pdf';
    final isImg = fileType == 'image';

    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(name, style: AppTextStyles.headline(16, FontWeight.w600)),
        backgroundColor: AppColors.surface,
        elevation: 1,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withOpacity(0.1),
        iconTheme: const IconThemeData(color: AppColors.onSurfaceVariant),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outlineVariant.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              )
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: isImg
              ? InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(child: Image.network(_url, fit: BoxFit.contain)),
                )
              : SizedBox.expand(
                  child: HtmlElementView(viewType: _viewId),
                ),
        ),
      ),
    );
  }
}
