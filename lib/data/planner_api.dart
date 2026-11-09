import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../planner/models.dart';

class PlannerApiException implements Exception {
  final String code;
  final String message;
  final dynamic details;

  const PlannerApiException({
    required this.code,
    required this.message,
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

  Never _handleError(dynamic error) {
    if (error is PostgrestException) {
      final msg = error.message;
      if (msg.contains('UNAUTHENTICATED') || error.code == 'P0001') {
        throw PlannerApiException(
          code: 'UNAUTHENTICATED',
          message: 'Sesi kedaluwarsa. Silakan masuk kembali.',
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
        throw PlannerApiException(
          code: 'VALIDATION_ERROR',
          message: msg,
          details: error,
        );
      }
      if (msg.contains('NOT_FOUND') || error.code == 'P0004') {
        throw PlannerApiException(
          code: 'NOT_FOUND',
          message: msg,
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
        message: msg,
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
    throw PlannerApiException(
      code: 'UNKNOWN_ERROR',
      message: error.toString(),
      details: error,
    );
  }

  Future<PlannerSnapshot> fetchSnapshot() async {
    try {
      final res = await _client
          .rpc('get_planner_snapshot')
          .timeout(const Duration(seconds: 15));
      return PlannerSnapshot.fromJson(res as Map<String, dynamic>);
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
      return (res as num).toInt();
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
      return (res as num).toInt();
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
      return (res as num).toInt();
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
      return (res as num).toInt();
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
      return (res as num).toInt();
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
      return (res as num).toInt();
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
      return (res as num).toInt();
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
      return (res as num).toInt();
    } catch (e) {
      _handleError(e);
    }
  }
}
