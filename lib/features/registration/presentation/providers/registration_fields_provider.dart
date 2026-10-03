import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/user_registration_config_models.dart';

class RegistrationFieldsNotifier extends StateNotifier<List<UserRegistrationFieldDefinition>> {
  RegistrationFieldsNotifier() : super(sampleDefaultRegistrationFields);

  void toggleFieldEnabled(String keyOrId, bool isEnabled) {
    state = [
      for (final f in state)
        if (f.id == keyOrId || f.key == keyOrId)
          f.copyWith(isEnabled: isEnabled)
        else
          f,
    ];
  }

  void toggleFieldRequired(String keyOrId) {
    state = [
      for (final f in state)
        if (f.id == keyOrId || f.key == keyOrId)
          f.copyWith(required: !f.required)
        else
          f,
    ];
  }

  void setFieldRequired(String keyOrId, bool required) {
    state = [
      for (final f in state)
        if (f.id == keyOrId || f.key == keyOrId)
          f.copyWith(required: required)
        else
          f,
    ];
  }

  void saveField(UserRegistrationFieldDefinition field) {
    final index = state.indexWhere((f) => f.id == field.id || f.key == field.key);
    if (index >= 0) {
      final list = [...state];
      list[index] = field;
      list.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      state = list;
    } else {
      final list = [...state, field];
      list.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      state = list;
    }
  }

  void deleteField(String fieldId) {
    state = state.where((f) => !(f.id == fieldId && !f.isSystemStandard)).toList();
  }

  void resetToDefaults() {
    state = List<UserRegistrationFieldDefinition>.from(sampleDefaultRegistrationFields);
  }

  bool importFromJson(String rawJson) {
    try {
      final decoded = json.decode(rawJson);
      if (decoded is List) {
        state = decoded
            .map((item) => UserRegistrationFieldDefinition.fromJson(item as Map<String, dynamic>))
            .toList();
        return true;
      }
    } catch (_) {}
    return false;
  }

  String exportToJson() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(state.map((f) => f.toJson()).toList());
  }

  List<UserRegistrationFieldDefinition> getFieldsForModule(RegistrationTargetModule module) {
    return state.where((f) {
      if (!f.isEnabled) return false;
      return f.targetModule == RegistrationTargetModule.all || f.targetModule == module;
    }).toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  }
}

final registrationFieldsProvider =
    StateNotifierProvider<RegistrationFieldsNotifier, List<UserRegistrationFieldDefinition>>((ref) {
  return RegistrationFieldsNotifier();
});
