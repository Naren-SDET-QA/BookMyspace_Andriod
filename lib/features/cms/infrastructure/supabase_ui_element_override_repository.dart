import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/ui_element_override.dart';

class SupabaseUiElementOverrideRepository {
  SupabaseUiElementOverrideRepository(this._client);

  final SupabaseClient _client;

  Future<Map<String, UiElementOverride>> resolved(String screenKey) async {
    final data = await _client.rpc(
      'get_ui_element_overrides',
      params: {'p_screen_key': screenKey, 'p_locale': 'en'},
    );
    if (data is! Map) return const {};
    return Map<String, UiElementOverride>.fromEntries(
      data.entries.whereType<MapEntry>().map((entry) {
        final value = entry.value is Map
            ? Map<String, dynamic>.from(entry.value as Map)
            : const <String, dynamic>{};
        return MapEntry(
          entry.key.toString(),
          UiElementOverride.fromResolvedJson(entry.key.toString(), value),
        );
      }),
    );
  }

  Future<List<UiElementOverride>> list(String screenKey) async {
    final rows = await _client
        .from('ui_element_overrides')
        .select()
        .eq('screen_key', screenKey)
        .order('element_key');
    return rows
        .whereType<Map>()
        .map(
          (row) => UiElementOverride.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList(growable: false);
  }

  Future<void> save({
    required String screenKey,
    required String elementKey,
    required String locale,
    String? text,
    String? placeholder,
    required bool hidden,
    required bool enabled,
    String? imageUrl,
    String? linkUrl,
    String? colorValue,
  }) async {
    try {
      await _client.rpc(
        'admin_save_ui_element_override',
        params: {
          'p_screen_key': screenKey,
          'p_element_key': elementKey,
          'p_locale': locale,
          'p_text_value': text,
          'p_placeholder_value': placeholder,
          'p_is_hidden': hidden,
          'p_enabled': enabled,
          'p_image_url': imageUrl,
          'p_link_url': linkUrl,
          'p_color_value': colorValue,
        },
      );
    } catch (_) {
      // Fallback for backends running the pre-image migration RPC (7 args).
      await _client.rpc(
        'admin_save_ui_element_override',
        params: {
          'p_screen_key': screenKey,
          'p_element_key': elementKey,
          'p_locale': locale,
          'p_text_value': text,
          'p_placeholder_value': placeholder,
          'p_is_hidden': hidden,
          'p_enabled': enabled,
        },
      );
      // Persist the extended columns directly when the RPC ignores them.
      await _client
          .from('ui_element_overrides')
          .update({
            'image_url': imageUrl?.trim().isEmpty == true ? null : imageUrl,
            'link_url': linkUrl?.trim().isEmpty == true ? null : linkUrl,
            'color_value':
                colorValue?.trim().isEmpty == true ? null : colorValue,
          })
          .eq('screen_key', screenKey)
          .eq('element_key', elementKey)
          .eq('locale', locale);
    }
  }

  Future<void> delete(String id) async {
    await _client.rpc(
      'admin_delete_ui_element_override',
      params: {'p_override_id': id},
    );
  }
}
