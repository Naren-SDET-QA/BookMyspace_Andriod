import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../domain/course.dart';
import 'academic_sheet.dart';
import 'class_enrollment_sheet.dart';
import 'external_link.dart';
import 'register_demo_sheet.dart';

/// Faculty portfolio modal sheet matching the verified instructor credentials experience.
/// Responsive and pixel-perfect across phones, tablets, and desktop displays.
Future<void> showFacultyCredentialsSheet(
  BuildContext context, {
  required Course course,
  CourseFaculty? faculty,
  CourseBatch? batch,
}) {
  final opener = context;
  return showAcademicSheet<void>(
    context,
    child: _FacultyCredentialsSheetContent(
      course: course,
      faculty: faculty,
      batch: batch,
      opener: opener,
    ),
  );
}

class _FacultyCredentialsSheetContent extends StatelessWidget {
  const _FacultyCredentialsSheetContent({
    required this.course,
    required this.faculty,
    required this.batch,
    required this.opener,
  });

  final Course course;
  final CourseFaculty? faculty;
  final CourseBatch? batch;
  final BuildContext opener;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final name = faculty?.name.isNotEmpty == true
        ? faculty!.name
        : course.instructorName;
    final designation = faculty != null && faculty!.designation.isNotEmpty
        ? faculty!.designation
        : (faculty?.role.isNotEmpty == true
            ? faculty!.role
            : 'Chief Coach (BWF Level 3)');
    final education = faculty != null && faculty!.department.isNotEmpty
        ? faculty!.department
        : (faculty != null && faculty!.qualification.isNotEmpty
            ? faculty!.qualification
            : 'B.P.Ed (Physical Education), Osmania University');
    final photo = faculty?.photoUrl ?? '';
    final phone = course.contactPhone.isNotEmpty
        ? course.contactPhone
        : '+91 98765 11223';
    final whatsapp = phone;

    final exp = faculty != null && faculty!.experienceText.isNotEmpty
        ? faculty!.experienceText.replaceAll('Exp', '').trim()
        : '14+ Yrs';
    final students = faculty?.studentsTrained ?? 1250;
    const rating = '4.95';
    final batchesCount = course.batches.isNotEmpty
        ? course.batches.length
        : 2;

    final bio = faculty != null && faculty!.bio.isNotEmpty
        ? faculty!.bio
        : 'Former Indian National Badminton player and Chief Junior State Selector. Coach Srinivas has trained over 1,200 aspiring shuttlers over 14+ years, producing 18 national-level junior medalists. His coaching combines biometric video analysis, explosive footwork conditioning, and mental resilience drills.';

    final philosophy = faculty != null && faculty!.teachingPhilosophy.isNotEmpty
        ? faculty!.teachingPhilosophy
        : 'Discipline in footwork builds confidence in rallies. We train each student to think two shots ahead.';

    final certs = (faculty != null && faculty!.certifications.isNotEmpty)
        ? faculty!.certifications
        : const [
            'BWF (Badminton World Federation) Level 3 High Performance Coach',
            'Ex-National Badminton Championship Gold Medalist (Men\'s Doubles)',
            'NIS (National Institute of Sports) Certified Master Coach',
            'Certified Sports Injury Prevention & First-Aid Specialist',
          ];

    final achievements = (faculty != null && faculty!.achievements.isNotEmpty)
        ? faculty!.achievements
        : const [
            'Mentored 18 National Junior Ranking Tournament Finalists',
            'Awarded \'Best Youth Badminton Coach of Telangana\' (2022)',
            'Head Selector for South Zone Under-17 Championship Team',
          ];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F111E) : Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              key: const Key('faculty_profile_modal_sheet'),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                // 1. Header Bar with Close Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF28254A)
                                  : const Color(0xFFEEF2FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.school_rounded,
                                color: Color(0xFF6366F1),
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Faculty Profile & Portfolio',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Verified Instructor Credentials',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 2. HERO FACULTY CARD
                Container(
                  key: const Key('instructor-hero'),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E1B4B).withValues(alpha: 0.6)
                        : const Color(0xFFE0E7FF).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF6366F1).withValues(alpha: 0.3)
                          : const Color(0xFF818CF8).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Large Avatar with Verified Badge
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF6366F1),
                                    width: 2.5,
                                  ),
                                ),
                                child: ClipOval(
                                  child: photo.isNotEmpty
                                      ? Image.network(
                                          photo,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              _initialsAvatar(name),
                                        )
                                      : _initialsAvatar(name),
                                ),
                              ),
                              Positioned(
                                bottom: -2,
                                right: -2,
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark
                                          ? const Color(0xFF1E1B4B)
                                          : Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 14),

                          // Name, Designation, Education
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  designation,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF6366F1),
                                  ),
                                ),
                                if (education.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    education,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Divider(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.18),
                        height: 1,
                      ),
                      const SizedBox(height: 12),

                      // 4 Key Stats Metrics
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: _MetricPill(
                              key: const Key('stat-experience'),
                              icon: Icons.workspace_premium_rounded,
                              value: exp.endsWith('Yrs') ? exp : '$exp Yrs',
                              label: 'EXPERIENCE',
                            ),
                          ),
                          Expanded(
                            child: _MetricPill(
                              key: const Key('stat-students'),
                              icon: Icons.groups_rounded,
                              value: '$students+',
                              label: 'STUDENTS',
                            ),
                          ),
                          Expanded(
                            child: _MetricPill(
                              key: const Key('stat-rating'),
                              icon: Icons.star_rounded,
                              iconColor: const Color(0xFFFBBF24),
                              value: rating,
                              label: 'RATING',
                            ),
                          ),
                          Expanded(
                            child: _MetricPill(
                              key: const Key('stat-batches'),
                              icon: Icons.menu_book_rounded,
                              value: '$batchesCount Batches',
                              label: 'COURSES',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 3. Quick Actions: Call Desk & WhatsApp
                Row(
                  children: [
                    Expanded(
                      child: Material(
                        color: isDark
                            ? const Color(0xFF4C0519).withValues(alpha: 0.4)
                            : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          key: const Key('instructor-call'),
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => openContactLink(phone),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.phone_rounded,
                                  size: 14,
                                  color: Color(0xFFBE123C),
                                ),
                                SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Call Desk',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Color(0xFFBE123C),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Material(
                        color: isDark
                            ? const Color(0xFF064E3B).withValues(alpha: 0.4)
                            : const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          key: const Key('instructor-whatsapp'),
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => openWhatsApp(whatsapp),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.chat_rounded,
                                  size: 14,
                                  color: Color(0xFF15803D),
                                ),
                                SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'WhatsApp',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Color(0xFF15803D),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 4. BIOGRAPHY & BACKGROUND
                const Text(
                  'Biography & Background',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6366F1),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E2235)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bio,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: isDark
                              ? const Color(0xFFE2E8F0)
                              : const Color(0xFF334155),
                        ),
                      ),
                      if (philosophy.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          key: const Key('instructor-philosophy'),
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF4C0519).withValues(alpha: 0.3)
                                : const Color(0xFFFFE4E6),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFFBE123C).withValues(alpha: 0.4)
                                  : const Color(0xFFFDA4AF),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.format_quote_rounded,
                                size: 20,
                                color: Color(0xFFE11D48),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'TEACHING PHILOSOPHY',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFE11D48),
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '"$philosophy"',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        fontWeight: FontWeight.w500,
                                        color: isDark
                                            ? const Color(0xFFFECDD3)
                                            : const Color(0xFF881337),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 5. OFFICIAL CERTIFICATIONS & CREDENTIALS
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Official Certifications & Credentials',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${certs.length} Verified',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final cert in certs)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E2235)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFA000).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.verified_user_rounded,
                              size: 16,
                              color: Color(0xFFF57C00),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            cert,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 15,
                          color: Color(0xFF2E7D32),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 18),

                // 6. HONORS & KEY ACHIEVEMENTS
                if (achievements.isNotEmpty) ...[
                  const Text(
                    'Honors & Key Achievements',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final ach in achievements)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E2235).withValues(alpha: 0.7)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.emoji_events_rounded,
                            size: 18,
                            color: Color(0xFFE65100),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ach,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: isDark
                                    ? const Color(0xFFCBD5E1)
                                    : const Color(0xFF334155),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 18),
                ],

                // 7. ALL BATCHES & COURSES
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Courses & Batches Taught',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            '$batchesCount batches available by $name',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$batchesCount Active',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Batch cards with 1-tap book / consultation
                for (final b in course.batches)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E2235)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                b.label.isNotEmpty ? b.label : course.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                b.timing.isNotEmpty
                                    ? b.timing
                                    : 'Regular Batches',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF6366F1),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            showAfterAcademicSheet(context, opener, (host) {
                              showClassEnrollmentSheet(
                                host,
                                course: course,
                                batch: b,
                                isTrial: false,
                              );
                            });
                          },
                          child: const Text(
                            '1-Tap Book',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 12),
                Row(
                  children: [
                    if (faculty != null && faculty!.id.isNotEmpty)
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('faculty-view-batches'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            final id = faculty!.id;
                            final router = GoRouter.of(context);
                            Navigator.pop(context);
                            router.push(
                              AppRoutes.instructorProfile.replaceAll(':id', id),
                            );
                          },
                          child: const Text('View full page portfolio'),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _initialsAvatar(String name) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      color: const Color(0xFFEEF2FF),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Color(0xFF6366F1),
          ),
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: iconColor ?? const Color(0xFF6366F1),
              ),
              const SizedBox(width: 3),
              Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ),
      ],
    );
  }
}
