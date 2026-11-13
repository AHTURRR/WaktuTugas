import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef WhatsAppSettings = ({
  String? phone,
  bool verified,
  bool enabled,
  bool awaitingCode,
});

class WhatsAppApi {
  final SupabaseClient _client;
  const WhatsAppApi(this._client);

  Future<WhatsAppSettings> update(
    String action, {
    String? phone,
    String? code,
    bool? enabled,
  }) async {
    try {
      final response = await _client.functions
          .invoke(
            'whatsapp-settings',
            body: {
              'action': action,
              'phone': ?phone,
              'code': ?code,
              'enabled': ?enabled,
            },
          )
          .timeout(const Duration(seconds: 30));
      return _parse(response.data);
    } on FunctionException catch (error) {
      final details = error.details;
      throw WhatsAppApiException(
        error.status == 401
            ? 'unauthenticated'
            : details is Map && details['error'] is String
            ? details['error'] as String
            : null,
        details is Map && details['verified'] is bool ? _parse(details) : null,
      );
    }
  }

  WhatsAppSettings _parse(dynamic value) => (
    phone: value['phone'] as String?,
    verified: value['verified'] as bool,
    enabled: value['enabled'] as bool,
    awaitingCode: value['awaiting_code'] as bool,
  );
}

class WhatsAppApiException implements Exception {
  final String? code;
  final WhatsAppSettings? settings;
  const WhatsAppApiException(this.code, this.settings);
}
