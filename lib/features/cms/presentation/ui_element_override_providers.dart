import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../infrastructure/supabase_ui_element_override_repository.dart';
import '../domain/ui_element_override.dart';

final uiElementOverrideRepositoryProvider =
    Provider<SupabaseUiElementOverrideRepository>((ref) {
      return SupabaseUiElementOverrideRepository(ref.watch(supabaseProvider));
    });

final resolvedUiElementOverridesProvider = FutureProvider.autoDispose
    .family<Map<String, UiElementOverride>, String>((ref, screenKey) {
      return ref.watch(uiElementOverrideRepositoryProvider).resolved(screenKey);
    });

final adminUiElementOverridesProvider = FutureProvider.autoDispose
    .family<List<UiElementOverride>, String>((ref, screenKey) {
      return ref.watch(uiElementOverrideRepositoryProvider).list(screenKey);
    });
