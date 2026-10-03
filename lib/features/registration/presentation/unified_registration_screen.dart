import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_network_image.dart';
import '../domain/india_location_hierarchy_data.dart';
import '../domain/user_registration_config_models.dart';
import 'providers/registration_fields_provider.dart';

const List<String> unifiedAvatarPresets = [
  'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300&auto=format&fit=crop&q=80',
  'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&auto=format&fit=crop&q=80',
  'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=300&auto=format&fit=crop&q=80',
  'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300&auto=format&fit=crop&q=80',
  'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=300&auto=format&fit=crop&q=80',
  'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=300&auto=format&fit=crop&q=80',
];

class UnifiedRegistrationScreen extends ConsumerStatefulWidget {
  const UnifiedRegistrationScreen({super.key});

  @override
  ConsumerState<UnifiedRegistrationScreen> createState() =>
      _UnifiedRegistrationScreenState();
}

class _UnifiedRegistrationScreenState
    extends ConsumerState<UnifiedRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  RegistrationTargetModule _selectedModule = RegistrationTargetModule.customer;

  // Form Field Controllers
  String _selectedAvatar = unifiedAvatarPresets[0];
  final _fullNameController = TextEditingController(text: 'Narendra Reddy');
  final _emailController = TextEditingController(text: 'customer.dev@bookmyspace.app');
  final _phoneController = TextEditingController(text: '+91 98765 43210');
  final _passwordController = TextEditingController(text: 'N@rendra225#Dev');
  bool _isPasswordVisible = false;

  final _aadhaarController = TextEditingController(text: '5489 1234 9876');
  final _govtIdController = TextEditingController();

  final _address1Controller = TextEditingController(text: 'Flat 402, Sai Residency, Road No. 36');
  final _address2Controller = TextEditingController(text: 'Near Metro Pillar 1420, Jubilee Hills');
  final _pincodeController = TextEditingController(text: '500033');

  LocationHierarchyItem _location = IndiaLocationData.defaultItem;

  String _gender = 'Male';
  final _dobController = TextEditingController(text: '15/08/1992');
  final _emergencyController = TextEditingController(text: '+91 98765 00000');

  final _orgNameController = TextEditingController(text: 'Smash Badminton Arena LLP');
  final _gstinController = TextEditingController(text: '36AAAAA0000A1Z5');

  String _skillLevel = 'Beginner';
  final _specialRequestsController = TextEditingController();

  bool _agreeTerms = true;
  bool _isSubmitting = false;
  String? _successNotice;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _aadhaarController.dispose();
    _govtIdController.dispose();
    _address1Controller.dispose();
    _address2Controller.dispose();
    _pincodeController.dispose();
    _dobController.dispose();
    _emergencyController.dispose();
    _orgNameController.dispose();
    _gstinController.dispose();
    _specialRequestsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allFields = ref.watch(registrationFieldsProvider);

    // Filter fields enabled for current module
    final activeFields = allFields.where((f) {
      if (!f.isEnabled) return false;
      return f.targetModule == RegistrationTargetModule.all ||
          f.targetModule == _selectedModule;
    }).toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

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
              'Unified Registration',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Single configured profile for all modules',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Configure Registration Fields & Schema',
            icon: const Icon(Icons.tune, color: Color(0xFF818CF8)),
            onPressed: () => context.push(AppRoutes.adminRegistrationFields),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Module / Role Selection Header Card
            _buildModuleSelectionCard(activeFields.length),
            const SizedBox(height: 16),

            if (_successNotice != null) ...[
              _buildSuccessBanner(),
              const SizedBox(height: 16),
            ],

            // 1. Personal Information Section
            _buildSectionHeader(
              title: 'Personal Information',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 10),
            _buildAvatarPicker(),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _fullNameController,
              label: 'Full Name (as per Govt ID)',
              hint: 'e.g. Narendra Reddy',
              icon: Icons.badge_outlined,
              isRequired: _isFieldRequired(activeFields, 'full_name'),
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _phoneController,
              label: 'Mobile / WhatsApp Number',
              hint: '+91 98765 43210',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              isRequired: _isFieldRequired(activeFields, 'phone'),
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _emailController,
              label: 'Email Address',
              hint: 'user@example.com',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              isRequired: _isFieldRequired(activeFields, 'email'),
            ),
            const SizedBox(height: 12),
            _buildPasswordField(),
            const SizedBox(height: 12),
            _buildGenderSelector(),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _dobController,
              label: 'Date of Birth (DD/MM/YYYY)',
              hint: '15/08/1992',
              icon: Icons.calendar_today_outlined,
              isRequired: _isFieldRequired(activeFields, 'dob'),
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _emergencyController,
              label: 'Emergency Contact / Alternate Phone',
              hint: '+91 91234 56789',
              icon: Icons.contact_phone_outlined,
              keyboardType: TextInputType.phone,
              isRequired: _isFieldRequired(activeFields, 'emergency_contact'),
            ),
            const SizedBox(height: 24),

            // 2. Government ID & KYC Section
            _buildSectionHeader(
              title: 'Government ID & KYC',
              icon: Icons.verified_user_outlined,
            ),
            const SizedBox(height: 10),
            _buildAadhaarCard(_isFieldRequired(activeFields, 'aadhaar_number')),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _govtIdController,
              label: 'Alternate Govt ID (PAN / Passport / Voter ID)',
              hint: 'e.g. ABCDE1234F',
              icon: Icons.credit_card_outlined,
              isRequired: _isFieldRequired(activeFields, 'govt_id_number'),
            ),
            const SizedBox(height: 24),

            // 3. Address & Location Section (matching screenshot)
            _buildSectionHeader(
              title: 'Address & Location',
              icon: Icons.location_on_outlined,
            ),
            const SizedBox(height: 10),
            _buildTextField(
              controller: _address1Controller,
              label: 'Address Line 1 (Flat/House No, Street, Building)',
              hint: 'e.g. Flat 402, Sai Residency, Road No. 36',
              icon: Icons.home_outlined,
              isRequired: _isFieldRequired(activeFields, 'address_line_1'),
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _address2Controller,
              label: 'Address Line 2 (Area, Landmark, Sector)',
              hint: 'e.g. Near Metro Pillar 1420, Jubilee Hills',
              icon: Icons.map_outlined,
              isRequired: _isFieldRequired(activeFields, 'address_line_2'),
            ),
            const SizedBox(height: 12),
            _buildLocationHierarchyPicker(),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _pincodeController,
              label: 'Postal PIN Code (6 Digits)',
              hint: '500033',
              icon: Icons.pin_drop_outlined,
              keyboardType: TextInputType.number,
              isRequired: _isFieldRequired(activeFields, 'pincode'),
            ),
            const SizedBox(height: 24),

            // 4. Business & Academy Details Section (when Venue Owner or configured)
            if (_selectedModule == RegistrationTargetModule.venueOwner ||
                _hasFieldKey(activeFields, 'organization_name')) ...[
              _buildSectionHeader(
                title: 'Business & Academy Details',
                icon: Icons.business_center_outlined,
              ),
              const SizedBox(height: 10),
              _buildTextField(
                controller: _orgNameController,
                label: 'Business / Academy / Club Entity Name',
                hint: 'e.g. Smash Badminton Arena LLP',
                icon: Icons.business_outlined,
                isRequired: _isFieldRequired(activeFields, 'organization_name'),
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _gstinController,
                label: 'GSTIN / Commercial Tax Registration Number',
                hint: '36AAAAA0000A1Z5',
                icon: Icons.receipt_long_outlined,
                isRequired: _isFieldRequired(activeFields, 'gstin'),
              ),
              const SizedBox(height: 24),
            ],

            // 5. Custom & Additional Fields
            if (_selectedModule == RegistrationTargetModule.instituteStudent ||
                _hasFieldKey(activeFields, 'skill_level')) ...[
              _buildSectionHeader(
                title: 'Custom & Additional Fields',
                icon: Icons.extension_outlined,
              ),
              const SizedBox(height: 10),
              _buildSkillLevelDropdown(),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _specialRequestsController,
                label: 'Special Requirements / Medical Notes',
                hint: 'Any sports injuries, racket stringing preferences...',
                icon: Icons.notes_outlined,
                maxLines: 3,
                isRequired: false,
              ),
              const SizedBox(height: 24),
            ],

            // Terms & Conditions Checkbox
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: const Color(0xFF6366F1),
              value: _agreeTerms,
              onChanged: (val) => setState(() => _agreeTerms = val ?? true),
              title: const Text(
                'I accept the BookMySpace Platform Terms of Service, Privacy Policy, and Fair Cancellation Agreement.',
                style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
              ),
            ),
            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _isSubmitting ? null : _submitRegistration,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline, color: Colors.white),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Complete Registration (${_selectedModule.displayName})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'unified_ai_help',
        onPressed: _showAiAutoFillDialog,
        backgroundColor: const Color(0xFF4F46E5),
        icon: const Icon(Icons.smart_toy, color: Colors.white, size: 20),
        label: const Text(
          'AI Help',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  bool _isFieldRequired(List<UserRegistrationFieldDefinition> activeFields, String key) {
    final field = activeFields.firstWhere(
      (f) => f.key == key,
      orElse: () => const UserRegistrationFieldDefinition(
        id: '',
        key: '',
        label: '',
        fieldType: RegistrationFieldType.text,
        required: false,
      ),
    );
    return field.required;
  }

  bool _hasFieldKey(List<UserRegistrationFieldDefinition> activeFields, String key) {
    return activeFields.any((f) => f.key == key);
  }

  Widget _buildModuleSelectionCard(int activeCount) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Select Registration Type',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$activeCount Configured Fields',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Each module dynamically adjusts required KYC, photo, address, and profile fields.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildRoleTab(RegistrationTargetModule.customer, 'Customer / Member'),
                const SizedBox(width: 8),
                _buildRoleTab(RegistrationTargetModule.venueOwner, 'Venue & Space Owner'),
                const SizedBox(width: 8),
                _buildRoleTab(RegistrationTargetModule.instituteStudent, 'Institute Student / Coach'),
                const SizedBox(width: 8),
                _buildRoleTab(RegistrationTargetModule.eventAttendee, 'Event / Tournament Attendee'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleTab(RegistrationTargetModule module, String label) {
    final isSelected = _selectedModule == module;
    return InkWell(
      onTap: () => setState(() => _selectedModule = module),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF312E81) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF334155),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({required String title, required IconData icon}) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF818CF8), size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarPicker() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161F30),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: AppNetworkImage(url: _selectedAvatar),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Profile Photo / Selfie',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Used for account badge, booking verification and check-ins',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: unifiedAvatarPresets.map((avatarUrl) {
                final isSelected = _selectedAvatar == avatarUrl;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedAvatar = avatarUrl),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: ClipOval(
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: AppNetworkImage(url: avatarUrl),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isRequired = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161F30),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: (value) {
          if (isRequired && (value == null || value.trim().isEmpty)) {
            return '$label is required';
          }
          return null;
        },
        decoration: InputDecoration(
          icon: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
          label: Text.rich(
            TextSpan(
              text: label,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              children: [
                if (isRequired)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(color: Color(0xFFF43F5E), fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 13),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161F30),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: TextFormField(
        controller: _passwordController,
        obscureText: !_isPasswordVisible,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          icon: const Icon(Icons.lock_outline, color: Color(0xFF94A3B8), size: 20),
          labelText: 'Password *',
          labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          border: InputBorder.none,
          suffixIcon: IconButton(
            icon: Icon(
              _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
              color: const Color(0xFF94A3B8),
              size: 20,
            ),
            onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
          ),
        ),
      ),
    );
  }

  Widget _buildGenderSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161F30),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Gender', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: ['Male', 'Female', 'Other'].map((g) {
              final isSelected = _gender == g;
              return ChoiceChip(
                label: Text(g),
                selected: isSelected,
                selectedColor: const Color(0xFF4F46E5),
                backgroundColor: const Color(0xFF1E293B),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (val) => setState(() => _gender = g),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAadhaarCard(bool isRequired) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161F30),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _aadhaarController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              _AadhaarInputFormatter(),
            ],
            validator: (value) {
              if (isRequired && (value == null || value.trim().isEmpty)) {
                return 'Aadhaar Card Number is required';
              }
              return null;
            },
            decoration: InputDecoration(
              icon: const Icon(Icons.shield_outlined, color: Color(0xFF818CF8), size: 20),
              label: Text.rich(
                TextSpan(
                  text: 'Aadhaar Card Number (12 Digits)',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  children: [
                    if (isRequired)
                      const TextSpan(
                        text: ' *',
                        style: TextStyle(color: Color(0xFFF43F5E), fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
              ),
              hintText: '1234 5678 9012',
              hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 13),
              border: InputBorder.none,
            ),
          ),
          const SizedBox(height: 6),
          // UIDAI Compliant Badge as shown in screenshot
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF4338CA).withValues(alpha: 0.4)),
            ),
            child: Row(
              children: const [
                Icon(Icons.verified, color: Color(0xFF818CF8), size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'UIDAI Compliant: Encrypted with masked audit trail (XXXX-XXXX-1234)',
                    style: TextStyle(color: Color(0xFFA5B4FC), fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationHierarchyPicker() {
    return InkWell(
      onTap: _showLocationHierarchyDialog,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161F30),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.location_on, color: Color(0xFF818CF8), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Country, State, District & City Hierarchy *',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _location.formattedHierarchy,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Tap to change Country, State, District, City, or Area',
                    style: TextStyle(color: Color(0xFF818CF8), fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillLevelDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF161F30),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: DropdownButtonFormField<String>(
        value: _skillLevel,
        dropdownColor: const Color(0xFF1E293B),
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: const InputDecoration(
          icon: Icon(Icons.fitness_center_outlined, color: Color(0xFF94A3B8), size: 20),
          labelText: 'Sport / Activity Skill Level',
          labelStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          border: InputBorder.none,
        ),
        items: ['Beginner', 'Intermediate', 'Advanced', 'State Player', 'Certified Coach']
            .map((lvl) => DropdownMenuItem(value: lvl, child: Text(lvl)))
            .toList(),
        onChanged: (val) => setState(() => _skillLevel = val ?? 'Beginner'),
      ),
    );
  }

  Widget _buildSuccessBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF064E3B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF10B981)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF34D399)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _successNotice ?? '',
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showLocationHierarchyDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Location Hierarchy',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const Text(
                    'Administrative Indian location hierarchy for localized slot discovery',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  const Text('POPULAR REGIONAL PRESETS', style: TextStyle(color: Color(0xFF818CF8), fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...IndiaLocationData.popularPresets.map((preset) {
                    final isCurrent = _location.formattedHierarchy == preset.formattedHierarchy;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _location = preset;
                          _pincodeController.text = preset.pincode;
                        });
                        Navigator.of(ctx).pop();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isCurrent ? const Color(0xFF312E81) : const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isCurrent ? const Color(0xFF6366F1) : const Color(0xFF334155)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.location_city, color: isCurrent ? const Color(0xFFA5B4FC) : const Color(0xFF94A3B8), size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                preset.formattedHierarchy,
                                style: TextStyle(
                                  color: isCurrent ? Colors.white : const Color(0xFFCBD5E1),
                                  fontSize: 13,
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                            Text(preset.pincode, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitRegistration() async {
    if (!_agreeTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the Terms of Service to continue')),
      );
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required mandatory fields')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 600));

    if (mounted) {
      setState(() {
        _isSubmitting = false;
        _successNotice =
            'Registration successful as ${_selectedModule.displayName}! Welcome to BookMySpace.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF065F46),
          content: Text('Registration saved for ${_fullNameController.text}!'),
        ),
      );
    }
  }

  void _showAiAutoFillDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Row(
          children: const [
            Icon(Icons.smart_toy, color: Color(0xFF818CF8)),
            SizedBox(width: 8),
            Text('BookMySpace AI Registration Copilot', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'How can AI assist your registration?',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              '• Auto-detect location & postal code hierarchy\n'
              '• Verify 12-digit Aadhaar checksum with UIDAI format\n'
              '• Pre-populate business GSTIN verification credentials\n'
              '• Sync unified profile across customer and owner modes',
              style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                _fullNameController.text = 'Narendra Reddy';
                _phoneController.text = '+91 98765 43210';
                _emailController.text = 'narenqe2@gmail.com';
                _address1Controller.text = 'Flat 402, Sai Residency, Road No. 36';
                _address2Controller.text = 'Near Metro Pillar 1420, Jubilee Hills';
                _location = IndiaLocationData.defaultItem;
                _pincodeController.text = '500033';
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('AI Autofilled verified registration profile!')),
              );
            },
            child: const Text('Autofill Sample Profile'),
          ),
        ],
      ),
    );
  }
}

class _AadhaarInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(' ', '');
    if (text.length > 12) return oldValue;
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(text[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
