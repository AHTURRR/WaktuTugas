import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../planner/models.dart';

class PlannerApiException implements Exception {
  final String code;
  final String message;
  final String? field;
  final dynamic details;

  const PlannerApiException({
    required this.code,
    required this.message,
    this.field,
    this.details,
  });

  @override
  String toString() => 'PlannerApiException($code): $message';
}

/// Implementasi klien API Supabase untuk WaktuTugas
/// Memetakan seluruh panggilan mutasi ke RPC transaksional ber-revisi sesuai docs/API.md
class PlannerApi {
  final SupabaseClient _client;

  const PlannerApi(this._client);

  static String _stripPrefix(String message, String prefix) {
    final trimmed = message.trim();
    if (trimmed.startsWith('$prefix:')) {
      return trimmed.substring(prefix.length + 1).trim();
    }
    return trimmed;
  }

  static String? _inferField(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('judul')) return 'title';
    if (lower.contains('mata kuliah')) return 'course';
    if (lower.contains('tenggat')) return 'deadline_at';
    if (lower.contains('sisa')) return 'remaining_minutes';
    if (lower.contains('weekday') ||
        lower.contains('date') ||
        lower.contains('tanggal')) {
      return 'date';
    }
    if (lower.contains('waktu') || lower.contains('rentang')) {
      return 'time_window';
    }
    if (lower.contains('kegiatan') || lower.contains('label')) {
      return 'activity';
    }
    return null;
  }

  int _parseRevision(dynamic res) {
    if (res is int && res >= 0) return res;
    if (res is num && res >= 0 && res == res.roundToDouble()) {
      return res.toInt();
    }
    throw const FormatException('Revisi server tidak valid.');
  }

  Never _handleError(dynamic error) {
    if (error is PlannerApiException) {
      throw error;
    }
    if (error is AuthException) {
      throw PlannerApiException(
        code: 'UNAUTHENTICATED',
        message: 'Sesi kedaluwarsa. Silakan masuk kembali.',
        details: error,
      );
    }
    if (error is PostgrestException) {
      final msg = error.message;
      if (msg.contains('UNAUTHENTICATED') ||
          error.code == 'P0001' ||
          error.code == '401' ||
          error.code == 'PGRST301') {
        throw PlannerApiException(
          code: 'UNAUTHENTICATED',
          message: 'Sesi kedaluwarsa. Silakan masuk kembali.',
          details: error,
        );
      }
      if (msg.contains('FORBIDDEN') ||
          error.code == '42501' ||
          error.code == '403' ||
          msg.toLowerCase().contains('permission denied')) {
        throw PlannerApiException(
          code: 'FORBIDDEN',
          message: 'Akses ditolak untuk operasi ini.',
          details: error,
        );
      }
      if (msg.contains('STALE_REVISION') || error.code == 'P0002') {
        throw PlannerApiException(
          code: 'STALE_REVISION',
          message: 'Data telah diperbarui di tempat lain. Silakan muat ulang.',
          details: error,
        );
      }
      if (msg.contains('VALIDATION_ERROR') || error.code == 'P0003') {
        final clean = _stripPrefix(msg, 'VALIDATION_ERROR');
        throw PlannerApiException(
          code: 'VALIDATION_ERROR',
          message: clean.isEmpty ? 'Data isian tidak valid.' : clean,
          field: _inferField(clean),
          details: error,
        );
      }
      if (msg.contains('NOT_FOUND') || error.code == 'P0004') {
        throw PlannerApiException(
          code: 'NOT_FOUND',
          message: 'Data tidak ditemukan atau telah dihapus.',
          details: error,
        );
      }
      if (msg.contains('SESSION_ALREADY_CLOSED') || error.code == 'P0005') {
        throw PlannerApiException(
          code: 'SESSION_ALREADY_CLOSED',
          message: 'Sesi belajar ini sudah ditutup sebelumnya.',
          details: error,
        );
      }
      throw PlannerApiException(
        code: error.code ?? 'DATABASE_ERROR',
        message: 'Operasi belum berhasil diproses server.',
        details: error,
      );
    }
    if (error is TimeoutException) {
      throw PlannerApiException(
        code: 'TIMEOUT',
        message: 'Permintaan ke server melebihi batas waktu (15 detik).',
        details: error,
      );
    }
    if (error is FormatException || error is TypeError) {
      throw PlannerApiException(
        code: 'INVALID_RESPONSE',
        message: 'Respons layanan tidak sesuai format yang diharapkan.',
        details: error,
      );
    }
    throw PlannerApiException(
      code: 'UNKNOWN_ERROR',
      message: 'Tidak dapat terhubung ke layanan. Periksa jaringan Anda.',
      details: error,
    );
  }

  Future<PlannerSnapshot> fetchSnapshot() async {
    try {
      final res = await _client
          .rpc('get_planner_snapshot')
          .timeout(const Duration(seconds: 15));
      if (res is! Map) {
        throw const FormatException('Snapshot bukan objek JSON.');
      }
      return PlannerSnapshot.fromJson(Map<String, dynamic>.from(res));
    } catch (e) {
      _handleError(e);
    }
  }

  Future<int> saveTask({
    String? taskId,
    required String title,
    String? course,
    required DateTime deadlineAt,
    required int remainingMinutes,
    required int expectedRevision,
  }) async {
    try {
      final res = await _client
          .rpc(
            'save_task',
            params: {
              'p_task_id': taskId,
              'p_title': title,
              'p_course': course,
              'p_deadline_at': deadlineAt.toUtc().toIso8601String(),
              'p_remaining_minutes': remainingMinutes,
              'p_expected_revision': expectedRevision,
            },
          )
          .timeout(const Duration(seconds: 15));
      return _parseRevision(res);
    } catch (e) {
      _handleError(e);
    }
  }

  Future<int> deleteTask({
    required String taskId,
    required int expectedRevision,
  }) async {
    try {
      final res = await _client
          .rpc(
            'delete_task',
            params: {
              'p_task_id': taskId,
              'p_confirm_delete': true,
              'p_expected_revision': expectedRevision,
            },
          )
          .timeout(const Duration(seconds: 15));
      return _parseRevision(res);
    } catch (e) {
      _handleError(e);
    }
  }

  Future<int> saveTimeWindow({
    String? id,
    int? weekday,
    String? date,
    required int startMinute,
    required int endMinute,
    required int expectedRevision,
  }) async {
    try {
      final res = await _client
          .rpc(
            'save_time_window',
            params: {
              'p_id': id,
              'p_weekday': weekday,
              'p_date': date,
              'p_start_minute': startMinute,
              'p_end_minute': endMinute,
              'p_expected_revision': expectedRevision,
            },
          )
          .timeout(const Duration(seconds: 15));
      return _parseRevision(res);
    } catch (e) {
      _handleError(e);
    }
  }

  Future<int> deleteTimeWindow({
    required String id,
    required int expectedRevision,
  }) async {
    try {
      final res = await _client
          .rpc(
            'delete_time_window',
            params: {'p_id': id, 'p_expected_revision': expectedRevision},
          )
          .timeout(const Duration(seconds: 15));
      return _parseRevision(res);
    } catch (e) {
      _handleError(e);
    }
  }

  Future<int> saveActivity({
    String? id,
    required String kind,
    required String label,
    int? weekday,
    String? date,
    required int startMinute,
    required int endMinute,
    required int expectedRevision,
  }) async {
    try {
      final res = await _client
          .rpc(
            'save_activity',
            params: {
              'p_id': id,
              'p_kind': kind,
              'p_label': label,
              'p_weekday': weekday,
              'p_date': date,
              'p_start_minute': startMinute,
              'p_end_minute': endMinute,
              'p_expected_revision': expectedRevision,
            },
          )
          .timeout(const Duration(seconds: 15));
      return _parseRevision(res);
    } catch (e) {
      _handleError(e);
    }
  }

  Future<int> deleteActivity({
    required String id,
    required int expectedRevision,
  }) async {
    try {
      final res = await _client
          .rpc(
            'delete_activity',
            params: {'p_id': id, 'p_expected_revision': expectedRevision},
          )
          .timeout(const Duration(seconds: 15));
      return _parseRevision(res);
    } catch (e) {
      _handleError(e);
    }
  }

  Future<int> recordProgress({
    required String sessionId,
    required SessionStatus status,
    int? remainingAfter,
    required int expectedRevision,
  }) async {
    try {
      final res = await _client
          .rpc(
            'record_progress',
            params: {
              'p_session_id': sessionId,
              'p_status': status.name,
              'p_remaining_after': remainingAfter,
              'p_expected_revision': expectedRevision,
            },
          )
          .timeout(const Duration(seconds: 15));
      return _parseRevision(res);
    } catch (e) {
      _handleError(e);
    }
  }

  Future<int> confirmSchedule({required SchedulePreview preview}) async {
    try {
      final sessionsJson = preview.sessions
          .map(
            (s) => {
              'task_id': s.taskId,
              'starts_at': s.startsAt.toIso8601String(),
              'ends_at': s.endsAt.toIso8601String(),
            },
          )
          .toList();

      final res = await _client
          .rpc(
            'confirm_schedule',
            params: {
              'input_revision': preview.inputRevision,
              'window_start': preview.windowStart.toIso8601String(),
              'window_end': preview.windowEnd.toIso8601String(),
              'sessions': sessionsJson,
            },
          )
          .timeout(const Duration(seconds: 15));
      return _parseRevision(res);
    } catch (e) {
      _handleError(e);
    }
  }
}
