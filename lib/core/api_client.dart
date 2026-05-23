import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:safetrace/core/theme.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConstants.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  final _storage = const FlutterSecureStorage();

  Future<String?> _getToken() async {
    return await _storage.read(key: AppConstants.tokenKey);
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _getToken();
    return token != null ? {'Authorization': 'Bearer $token'} : {};
  }

  // ─── Identity ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createAnonymousUser() async {
    final response = await _dio.post('/identity/create');
    return response.data;
  }

  Future<Map<String, dynamic>> recoverUser(String recoveryCode) async {
    final response = await _dio.post('/identity/recover', data: {
      'recovery_code': recoveryCode,
    });
    return response.data;
  }

  Future<void> attachIdentity({
    required String caseId,
    String? name,
    String? phone,
    String? cnic,
  }) async {
    final headers = await _authHeaders();
    await _dio.post(
      '/identity/attach',
      data: {'case_id': caseId, 'name': name, 'phone': phone, 'cnic': cnic},
      options: Options(headers: headers),
    );
  }

  Future<Map<String, dynamic>> getMe() async {
    final headers = await _authHeaders();
    final response = await _dio.get('/identity/me',
        options: Options(headers: headers));
    return response.data;
  }

  // ─── Cases ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createCase({
    required String title,
    required String category,
    String? notes,
  }) async {
    final headers = await _authHeaders();
    final response = await _dio.post(
      '/cases/',
      data: {'title': title, 'category': category, 'notes': notes},
      options: Options(headers: headers),
    );
    return response.data;
  }

  Future<List<dynamic>> getCases() async {
    final headers = await _authHeaders();
    final response =
        await _dio.get('/cases/', options: Options(headers: headers));
    return response.data['cases'];
  }

  Future<Map<String, dynamic>> getCase(String caseId) async {
    final headers = await _authHeaders();
    final response = await _dio.get('/cases/$caseId',
        options: Options(headers: headers));
    return response.data;
  }

  // ─── Incidents ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> addIncident({
    required String caseId,
    required String description,
    required DateTime incidentTime,
    String? location,
  }) async {
    final headers = await _authHeaders();
    final response = await _dio.post(
      '/incidents/',
      data: {
        'case_id': caseId,
        'description': description,
        'incident_time': incidentTime.toIso8601String(),
        'location': location,
      },
      options: Options(headers: headers),
    );
    return response.data;
  }

  // ─── Evidence ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> uploadEvidence({
    required String incidentId,
    required File file,
    required String mimeType,
  }) async {
    final token = await _getToken();
    final uri =
        Uri.parse('${AppConstants.baseUrl}/evidence/upload');
    final request = http.MultipartRequest('POST', uri);
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.fields['incident_id'] = incidentId;
    request.files.add(await http.MultipartFile.fromPath(
      'file',
      file.path,
      contentType: MediaType.parse(mimeType),
    ));
    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    return jsonDecode(body);
  }

  // ─── Timeline ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getTimeline(String caseId) async {
    final headers = await _authHeaders();
    final response = await _dio.get(
      '/timeline/$caseId',
      options: Options(headers: headers),
    );
    return response.data;
  }

  // ─── Chat ──────────────────────────────────────────────────────────────────

  Future<List<dynamic>> getChatHistory(
      String caseId, String chatType) async {
    final headers = await _authHeaders();
    final response = await _dio.get(
      '/chat/history/$caseId',
      queryParameters: {'chat_type': chatType},
      options: Options(headers: headers),
    );
    return response.data['messages'];
  }

  // ─── Actions ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getActionOptions(String caseId) async {
    final headers = await _authHeaders();
    final response = await _dio.get(
      '/actions/options/$caseId',
      options: Options(headers: headers),
    );
    return response.data;
  }

  Future<Map<String, dynamic>> generateDocument({
    required String caseId,
    required String destination,
    required bool consentConfirmed,
    bool includeIdentity = false,
  }) async {
    final headers = await _authHeaders();
    final response = await _dio.post(
      '/actions/generate',
      data: {
        'case_id': caseId,
        'destination': destination,
        'consent_confirmed': consentConfirmed,
        'include_identity': includeIdentity,
      },
      options: Options(headers: headers),
    );
    return response.data;
  }
}
