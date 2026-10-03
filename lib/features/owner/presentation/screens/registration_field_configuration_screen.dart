import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../registration/domain/user_registration_config_models.dart';
import '../../../registration/presentation/providers/registration_fields_provider.dart';

class RegistrationFieldConfigurationScreen extends ConsumerStatefulWidget {
  const RegistrationFieldConfigurationScreen({super.key});

  @override
  ConsumerState<RegistrationFieldConfigurationScreen> createState() =>
      _RegistrationFieldConfigurationScreenState();
}

class _RegistrationFieldConfigurationScreenState
    extends ConsumerState<RegistrationFieldConfigurationScreen> {
  final TextEditingController _searchController = TextEditingController();
  RegistrationTargetModule _selectedModule = RegistrationTargetModule.customer;
  RegistrationFieldCategory? _selectedCategory;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allFields = ref.watch(registrationFieldsProvider);
    final notifier = ref.read(registrationFieldsProvider.notifier);

    // Filter fields according to module, category, and search query
    final filteredFields = allFields.where((field) {
      if (_selectedModule != RegistrationTargetModule.all) {
        if (field.targetModule != RegistrationTargetModule.all &&
            field.targetModule != _selectedModule) {
          return false;
        }
      }
      if (_selectedCategory != null && field.category != _selectedCategory) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final matchesKey = field.key.toLowerCase().contains(_searchQuery);
        final matchesLabel = field.label.toLowerCase().contains(_searchQuery);
        final matchesHelp = field.helpText.toLowerCase().contains(_searchQuery);
        final matchesType = field.fieldType.displayName.toLowerCase().contains(_searchQuery);
        if (!matchesKey && !matchesLabel && !matchesHelp && !matchesType) {
          return false;
        }
      }
      return true;
    }).toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    // Stats calculations
    final totalMandatory = allFields.where((f) => f.required).length;
    final totalActive = allFields.where((f) => f.isEnabled).length;

    // Quick toggle field references
    final aadhaarField = allFields.firstWhere(
      (f) => f.key == 'aadhaar_number',
      orElse: () => allFields.first,
    );
    final dobField = allFields.firstWhere(
      (f) => f.key == 'dob',
      orElse: () => allFields.first,
    );
    final orgField = allFields.firstWhere(
      (f) => f.key == 'organization_name',
      orElse: () => allFields.first,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Registration Schema & KYC',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'JSON-Configurable Field Rules',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'JSON Schema Configuration',
            icon: const Icon(Icons.data_object, color: Color(0xFF818CF8)),
            onPressed: () => _showJsonConfigDialog(context, allFields, notifier),
          ),
          IconButton(
            tooltip: 'Live Form Preview',
            icon: const Icon(Icons.visibility, color: Color(0xFF818CF8)),
            onPressed: () => context.push(AppRoutes.unifiedRegistration),
          ),
          IconButton(
            tooltip: 'Reset Defaults',
            icon: const Icon(Icons.restart_alt, color: Color(0xFF94A3B8)),
            onPressed: () => _showResetDialog(context, notifier),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Target Module Filter Tabs
          SliverToBoxAdapter(
            child: Container(
              color: const Color(0xFF0F172A),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildModuleTab(
                      RegistrationTargetModule.customer,
                      'Customer / Member',
                      allFields.where((f) => f.targetModule == RegistrationTargetModule.all || f.targetModule == RegistrationTargetModule.customer).length,
                    ),
                    const SizedBox(width: 8),
                    _buildModuleTab(
                      RegistrationTargetModule.venueOwner,
                      'Venue & Space Owner',
                      allFields.where((f) => f.targetModule == RegistrationTargetModule.all || f.targetModule == RegistrationTargetModule.venueOwner).length,
                    ),
                    const SizedBox(width: 8),
                    _buildModuleTab(
                      RegistrationTargetModule.instituteStudent,
                      'Institute Student / Coach',
                      allFields.where((f) => f.targetModule == RegistrationTargetModule.all || f.targetModule == RegistrationTargetModule.instituteStudent).length,
                    ),
                    const SizedBox(width: 8),
                    _buildModuleTab(
                      RegistrationTargetModule.eventAttendee,
                      'Event / Tournament Attendee',
                      allFields.where((f) => f.targetModule == RegistrationTargetModule.all || f.targetModule == RegistrationTargetModule.eventAttendee).length,
                    ),
                    const SizedBox(width: 8),
                    _buildModuleTab(
                      RegistrationTargetModule.all,
                      'All User Types',
                      allFields.length,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Main body cards
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Dynamic JSON Configuration System card
                _buildSystemConfigCard(
                  context,
                  notifier,
                  aadhaarField,
                  dobField,
                  orgField,
                  allFields,
                ),
                const SizedBox(height: 16),

                // Search fields bar
                _buildSearchBar(),
                const SizedBox(height: 12),

                // Category filter chips
                _buildCategoryChips(allFields),
                const SizedBox(height: 16),

                // Status row: Fields count + Live Form Preview button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Fields: ${allFields.length} ($totalMandatory mandatory, $totalActive active)',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => context.push(AppRoutes.unifiedRegistration),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF312E81),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.visibility, size: 14, color: Color(0xFFA5B4FC)),
                            SizedBox(width: 6),
                            Text(
                              '+ Live Form Preview',
                              style: TextStyle(
                                color: Color(0xFFA5B4FC),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Field list cards
                if (filteredFields.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    alignment: Alignment.center,
                    child: const Text(
                      'No matching registration fields found',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                    ),
                  )
                else
                  ...filteredFields.map(
                    (field) => _buildFieldCard(context, field, notifier),
                  ),

                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'add_field_fab',
            onPressed: () => _showAddEditFieldDialog(context, null, notifier),
            backgroundColor: const Color(0xFF2563EB),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Add Field',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'ai_help_fab',
            onPressed: () => _showAiHelpDialog(context, allFields),
            backgroundColor: const Color(0xFF4F46E5),
            icon: const Icon(Icons.smart_toy, color: Colors.white, size: 18),
            label: const Text(
              'AI Help',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleTab(RegistrationTargetModule module, String label, int count) {
    final isSelected = _selectedModule == module;
    return InkWell(
      onTap: () => setState(() => _selectedModule = module),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF312E81) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF334155),
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemConfigCard(
    BuildContext context,
    RegistrationFieldsNotifier notifier,
    UserRegistrationFieldDefinition aadhaarField,
    UserRegistrationFieldDefinition dobField,
    UserRegistrationFieldDefinition orgField,
    List<UserRegistrationFieldDefinition> allFields,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF172554)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4338CA).withValues(alpha: 0.6)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.account_tree, color: Color(0xFF818CF8), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Dynamic JSON Configuration System',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              InkWell(
                onTap: () => _showJsonConfigDialog(context, allFields, notifier),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF831843),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.code, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'Edit',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Toggle mandatory fields instantly without hardcoding. Changes take effect across user registration, checkout KYC, and host onboarding in real time.',
            style: TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'QUICK MANDATORY TOGGLES',
            style: TextStyle(
              color: Color(0xFF818CF8),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickToggle(
                  label: 'Identity Proof',
                  isMandatory: aadhaarField.required,
                  onTap: () => notifier.toggleFieldRequired(aadhaarField.key),
                ),
                const SizedBox(width: 8),
                _buildQuickToggle(
                  label: 'Date of Birth',
                  isMandatory: dobField.required,
                  onTap: () => notifier.toggleFieldRequired(dobField.key),
                ),
                const SizedBox(width: 8),
                _buildQuickToggle(
                  label: 'Company Name',
                  isMandatory: orgField.required,
                  onTap: () => notifier.toggleFieldRequired(orgField.key),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickToggle({
    required String label,
    required bool isMandatory,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMandatory ? const Color(0xFF312E81) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMandatory ? const Color(0xFF6366F1) : const Color(0xFF334155),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isMandatory ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 16,
              color: isMandatory ? const Color(0xFFA5B4FC) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                Text(
                  isMandatory ? 'MANDATORY' : 'OPTIONAL',
                  style: TextStyle(
                    color: isMandatory ? const Color(0xFF818CF8) : const Color(0xFF94A3B8),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search fields (e.g. photo, aadhaar, dob, company, phone)...',
          hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8), size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Color(0xFF94A3B8), size: 18),
                  onPressed: () => _searchController.clear(),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildCategoryChips(List<UserRegistrationFieldDefinition> allFields) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildCategoryFilterChip(
            null,
            'All Categories',
            allFields.length,
          ),
          const SizedBox(width: 8),
          _buildCategoryFilterChip(
            RegistrationFieldCategory.personal,
            'Personal Information',
            allFields.where((f) => f.category == RegistrationFieldCategory.personal).length,
          ),
          const SizedBox(width: 8),
          _buildCategoryFilterChip(
            RegistrationFieldCategory.identityKyc,
            'Government ID & KYC',
            allFields.where((f) => f.category == RegistrationFieldCategory.identityKyc).length,
          ),
          const SizedBox(width: 8),
          _buildCategoryFilterChip(
            RegistrationFieldCategory.address,
            'Address & Location',
            allFields.where((f) => f.category == RegistrationFieldCategory.address).length,
          ),
          const SizedBox(width: 8),
          _buildCategoryFilterChip(
            RegistrationFieldCategory.professionalBusiness,
            'Business & Academy Details',
            allFields.where((f) => f.category == RegistrationFieldCategory.professionalBusiness).length,
          ),
          const SizedBox(width: 8),
          _buildCategoryFilterChip(
            RegistrationFieldCategory.custom,
            'Custom & Additional Fields',
            allFields.where((f) => f.category == RegistrationFieldCategory.custom).length,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterChip(RegistrationFieldCategory? category, String label, int count) {
    final isSelected = _selectedCategory == category;
    return InkWell(
      onTap: () => setState(() => _selectedCategory = isSelected ? null : category),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF312E81) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF334155),
          ),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildFieldCard(
    BuildContext context,
    UserRegistrationFieldDefinition field,
    RegistrationFieldsNotifier notifier,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161F30),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: field.required
              ? const Color(0xFF6366F1).withValues(alpha: 0.3)
              : const Color(0xFF334155).withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tags row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _buildBadge(field.category.displayName, const Color(0xFF1E293B), const Color(0xFF94A3B8)),
                    _buildBadge(field.targetModule.displayName, const Color(0xFF1E3A8A), const Color(0xFF93C5FD)),
                    _buildBadge(
                      field.isSystemStandard ? 'Standard' : 'Custom',
                      const Color(0xFF0F172A),
                      const Color(0xFF94A3B8),
                    ),
                    _buildBadge(
                      field.required ? 'Required' : 'Optional',
                      field.required ? const Color(0xFF881337) : const Color(0xFF1E293B),
                      field.required ? const Color(0xFFFDA4AF) : const Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.edit, size: 16, color: Color(0xFF94A3B8)),
                onPressed: () => _showAddEditFieldDialog(context, field, notifier),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Main row with icon, title, switch
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Icon(_getIconForField(field), size: 18, color: const Color(0xFF818CF8)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: field.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    children: [
                      if (field.required)
                        const TextSpan(
                          text: ' *Mandatory',
                          style: TextStyle(
                            color: Color(0xFFF43F5E),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Switch(
                value: field.isEnabled,
                activeColor: const Color(0xFF6366F1),
                onChanged: (val) => notifier.toggleFieldEnabled(field.id, val),
              ),
            ],
          ),

          const SizedBox(height: 4),
          // Subtitle
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Text(
              'Key: ${field.key} • Type: ${field.fieldType.displayName}',
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
            ),
          ),

          if (field.helpText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: Text(
                field.helpText,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(color: textCol, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }

  IconData _getIconForField(UserRegistrationFieldDefinition field) {
    switch (field.fieldType) {
      case RegistrationFieldType.phone:
        return Icons.phone;
      case RegistrationFieldType.email:
        return Icons.email;
      case RegistrationFieldType.photo:
        return Icons.camera_alt;
      case RegistrationFieldType.aadhaar:
        return Icons.shield;
      case RegistrationFieldType.govtId:
        return Icons.credit_card;
      case RegistrationFieldType.addressLine:
        return Icons.home;
      case RegistrationFieldType.locationHierarchy:
        return Icons.location_on;
      case RegistrationFieldType.pincode:
        return Icons.pin_drop;
      case RegistrationFieldType.dateOfBirth:
        return Icons.calendar_today;
      case RegistrationFieldType.dropdown:
        return Icons.arrow_drop_down_circle;
      case RegistrationFieldType.radioGroup:
        return Icons.radio_button_checked;
      case RegistrationFieldType.checkbox:
        return Icons.check_box;
      case RegistrationFieldType.number:
        return Icons.tag;
      case RegistrationFieldType.textarea:
        return Icons.notes;
      case RegistrationFieldType.text:
        return Icons.person;
    }
  }

  void _showAddEditFieldDialog(
    BuildContext context,
    UserRegistrationFieldDefinition? existing,
    RegistrationFieldsNotifier notifier,
  ) {
    final keyController = TextEditingController(text: existing?.key ?? '');
    final labelController = TextEditingController(text: existing?.label ?? '');
    final placeholderController = TextEditingController(text: existing?.placeholder ?? '');
    final helpTextController = TextEditingController(text: existing?.helpText ?? '');
    final optionsController = TextEditingController(text: existing?.options.join(', ') ?? '');

    RegistrationFieldType selectedType = existing?.fieldType ?? RegistrationFieldType.text;
    RegistrationFieldCategory selectedCategory = existing?.category ?? RegistrationFieldCategory.personal;
    RegistrationTargetModule selectedModule = existing?.targetModule ?? RegistrationTargetModule.all;
    bool isRequired = existing?.required ?? false;
    bool isEnabled = existing?.isEnabled ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text(
            existing == null ? 'Add Registration Field' : 'Edit Registration Field',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: labelController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Display Label *',
                      labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF475569))),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: keyController,
                    enabled: existing == null,
                    style: TextStyle(color: existing == null ? Colors.white : const Color(0xFF64748B)),
                    decoration: const InputDecoration(
                      labelText: 'Field Key (Internal Identifier) *',
                      labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF475569))),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<RegistrationFieldType>(
                    value: selectedType,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Field Type',
                      labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                    items: RegistrationFieldType.values.map((t) {
                      return DropdownMenuItem(value: t, child: Text(t.displayName));
                    }).toList(),
                    onChanged: (val) => setDlgState(() => selectedType = val!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<RegistrationFieldCategory>(
                    value: selectedCategory,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                    items: RegistrationFieldCategory.values.map((c) {
                      return DropdownMenuItem(value: c, child: Text(c.displayName));
                    }).toList(),
                    onChanged: (val) => setDlgState(() => selectedCategory = val!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<RegistrationTargetModule>(
                    value: selectedModule,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Audience / Target Module',
                      labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                    items: RegistrationTargetModule.values.map((m) {
                      return DropdownMenuItem(value: m, child: Text(m.displayName));
                    }).toList(),
                    onChanged: (val) => setDlgState(() => selectedModule = val!),
                  ),
                  const SizedBox(height: 12),
                  if (selectedType.hasOptions) ...[
                    TextField(
                      controller: optionsController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Options (comma-separated)',
                        labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                        hintText: 'e.g. Option 1, Option 2, Option 3',
                        hintStyle: TextStyle(color: Color(0xFF475569)),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: placeholderController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Placeholder text',
                      labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: helpTextController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Help text / description',
                      labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Mandatory (Required)', style: TextStyle(color: Colors.white, fontSize: 14)),
                    value: isRequired,
                    activeColor: const Color(0xFF6366F1),
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setDlgState(() => isRequired = val),
                  ),
                  SwitchListTile(
                    title: const Text('Active (Enabled in Form)', style: TextStyle(color: Colors.white, fontSize: 14)),
                    value: isEnabled,
                    activeColor: const Color(0xFF6366F1),
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setDlgState(() => isEnabled = val),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (existing != null && !existing.isSystemStandard)
              TextButton(
                onPressed: () {
                  notifier.deleteField(existing.id);
                  Navigator.of(ctx).pop();
                },
                child: const Text('Delete Field', style: TextStyle(color: Color(0xFFF43F5E))),
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
              onPressed: () {
                final label = labelController.text.trim();
                final key = keyController.text.trim();
                if (label.isEmpty || key.isEmpty) return;

                final rawOptions = optionsController.text
                    .split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();

                final updated = UserRegistrationFieldDefinition(
                  id: existing?.id ?? 'field_${DateTime.now().millisecondsSinceEpoch}',
                  key: key,
                  label: label,
                  fieldType: selectedType,
                  category: selectedCategory,
                  targetModule: selectedModule,
                  required: isRequired,
                  isEnabled: isEnabled,
                  placeholder: placeholderController.text.trim(),
                  helpText: helpTextController.text.trim(),
                  options: rawOptions,
                  displayOrder: existing?.displayOrder ?? 99,
                  isSystemStandard: existing?.isSystemStandard ?? false,
                );

                notifier.saveField(updated);
                Navigator.of(ctx).pop();
              },
              child: Text(existing == null ? 'Create Field' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showJsonConfigDialog(
    BuildContext context,
    List<UserRegistrationFieldDefinition> allFields,
    RegistrationFieldsNotifier notifier,
  ) {
    final jsonController = TextEditingController(text: notifier.exportToJson());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Row(
          children: const [
            Icon(Icons.data_object, color: Color(0xFF818CF8)),
            SizedBox(width: 8),
            Text(
              'Dynamic JSON Schema Configuration',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: 540,
          height: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Live JSON Schema representation of registration rules. You can edit this directly or copy to version control.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: TextField(
                    controller: jsonController,
                    maxLines: null,
                    expands: true,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Color(0xFFA5B4FC),
                    ),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.all(12),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 16, color: Color(0xFF818CF8)),
            label: const Text('Copy JSON', style: TextStyle(color: Color(0xFF818CF8))),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonController.text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('JSON copied to clipboard')),
              );
            },
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
            onPressed: () {
              final ok = notifier.importFromJson(jsonController.text);
              if (ok) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Registration schema updated successfully!')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid JSON schema format')),
                );
              }
            },
            child: const Text('Apply JSON Schema'),
          ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context, RegistrationFieldsNotifier notifier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Reset Defaults?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'This will restore the 17 default system fields (including Aadhaar, Location Hierarchy, Mobile, and Owner GSTIN rules). Any custom fields will be reset.',
          style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48)),
            onPressed: () {
              notifier.resetToDefaults();
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reset to standard 17 fields')),
              );
            },
            child: const Text('Reset to Defaults'),
          ),
        ],
      ),
    );
  }

  void _showAiHelpDialog(BuildContext context, List<UserRegistrationFieldDefinition> allFields) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Row(
          children: const [
            Icon(Icons.smart_toy, color: Color(0xFF818CF8)),
            SizedBox(width: 8),
            Text('BookMySpace AI Schema Advisor', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Dynamic Schema Compliance Rules:',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            SizedBox(height: 8),
            Text(
              '• Indian Telecom Act: 10-digit mobile number must remain mandatory for OTP instant validation.\n'
              '• UIDAI Circular: Aadhaar numbers are securely encrypted with only the last 4 digits stored for audit trails.\n'
              '• Tax Invoicing: GSTIN is required exclusively for Venue & Space Owners claiming input tax credit.\n'
              '• Multi-Module Profile: Fields configured as "All User Types" automatically sync across customer bookings and owner payouts.',
              style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, height: 1.5),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
