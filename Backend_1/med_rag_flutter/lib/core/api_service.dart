import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ApiService {
  static const String _base = 'http://127.0.0.1:8000/api';

  // ─── Overview ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getOverviewStats() async {
    final res = await http.get(Uri.parse('$_base/overview/stats'));
    _check(res);
    return jsonDecode(res.body);
  }

  // ─── Folders ──────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getFolders() async {
    final res = await http.get(Uri.parse('$_base/folders'));
    _check(res);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> createFolder(String name, {String icon = 'folder'}) async {
    final res = await http.post(
      Uri.parse('$_base/folders'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'icon': icon}),
    );
    _check(res);
    return jsonDecode(res.body);
  }

  static Future<void> deleteFolder(String folderId) async {
    final res = await http.delete(Uri.parse('$_base/folders/$folderId'));
    _check(res);
  }

  // ─── Files ────────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getFiles({String? folderId}) async {
    final url = folderId != null
        ? '$_base/files?folder_id=$folderId'
        : '$_base/files';
    final res = await http.get(Uri.parse(url));
    _check(res);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getFileDetail(String fileId) async {
    final res = await http.get(Uri.parse('$_base/files/$fileId'));
    _check(res);
    return jsonDecode(res.body);
  }

  static String getFilePreviewUrl(String fileId) => '$_base/files/$fileId/preview';

  static Future<void> deleteFile(String fileId) async {
    final res = await http.delete(Uri.parse('$_base/files/$fileId'));
    _check(res);
  }

  static Future<Map<String, dynamic>> moveFile(String fileId, String? folderId) async {
    final res = await http.patch(
      Uri.parse('$_base/files/$fileId/move'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'folder_id': folderId}),
    );
    _check(res);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> uploadFile(
    Uint8List bytes,
    String filename, {
    String? folderId,
    String mimeType = 'application/octet-stream',
  }) async {
    final uri = Uri.parse('$_base/upload');
    final req = http.MultipartRequest('POST', uri);

    req.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
      contentType: MediaType.parse(mimeType),
    ));
    if (folderId != null) req.fields['folder_id'] = folderId;

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    _check(res);
    return jsonDecode(res.body);
  }

  // ─── Chat ─────────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getChatHistory({int limit = 50}) async {
    final res = await http.get(Uri.parse('$_base/chat/history?limit=$limit'));
    _check(res);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> sendChat(
    String message, {
    List<String> fileIds = const [],
    List<String> folderIds = const [],
    Uint8List? imageBytes,
    String? imageFilename,
  }) async {
    final uri = Uri.parse('$_base/chat');
    final req = http.MultipartRequest('POST', uri);
    req.fields['message'] = message;
    if (fileIds.isNotEmpty) req.fields['file_ids'] = fileIds.join(',');
    if (folderIds.isNotEmpty) req.fields['folder_ids'] = folderIds.join(',');
    if (imageBytes != null && imageFilename != null) {
      req.files.add(http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: imageFilename,
        contentType: MediaType.parse('image/jpeg'),
      ));
    }
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    _check(res);
    return jsonDecode(res.body);
  }

  // ─── Notes ────────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getNotes() async {
    final res = await http.get(Uri.parse('$_base/notes'));
    _check(res);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> createNote({
    required String title,
    String content = '',
    String tags = '',
    String source = 'manual',
  }) async {
    final res = await http.post(
      Uri.parse('$_base/notes'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'title': title, 'content': content, 'tags': tags, 'source': source}),
    );
    _check(res);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> updateNote(
    String noteId, {
    String? title,
    String? content,
    String? tags,
    bool? isPinned,
  }) async {
    final body = <String, dynamic>{};
    if (title != null)    body['title'] = title;
    if (content != null)  body['content'] = content;
    if (tags != null)     body['tags'] = tags;
    if (isPinned != null) body['is_pinned'] = isPinned;

    final res = await http.put(
      Uri.parse('$_base/notes/$noteId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    _check(res);
    return jsonDecode(res.body);
  }

  static Future<void> deleteNote(String noteId) async {
    final res = await http.delete(Uri.parse('$_base/notes/$noteId'));
    _check(res);
  }

  static Future<Map<String, dynamic>> saveInsight({
    required String title,
    required String content,
    String? chatMessageId,
  }) async {
    final res = await http.post(
      Uri.parse('$_base/notes/save-insight'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'title': title,
        'content': content,
        if (chatMessageId != null) 'chat_message_id': chatMessageId,
      }),
    );
    _check(res);
    return jsonDecode(res.body);
  }

  // ─── Profile ──────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getProfile() async {
    final res = await http.get(Uri.parse('$_base/profile'));
    _check(res);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final res = await http.put(
      Uri.parse('$_base/profile'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    _check(res);
    return jsonDecode(res.body);
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  static void _check(http.Response res) {
    if (res.statusCode >= 400) {
      throw Exception('API error ${res.statusCode}: ${res.body}');
    }
  }
}
