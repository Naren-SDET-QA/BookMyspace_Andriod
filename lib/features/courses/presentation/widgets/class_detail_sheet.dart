import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_network_image.dart';
import '../../domain/course.dart';
import '../../domain/education_category.dart';
import '../course_providers.dart';
import 'academic_sheet.dart';
import 'class_enrollment_sheet.dart';
import 'external_link.dart';
import 'faculty_credentials_sheet.dart';
import 'waitlist_alert_sheet.dart';

const _sheetBg = Color(0xFF070B14);

String _durationLabel(int weeks) {
  if (weeks <= 0) return '';
  if (weeks % 4 == 0) {
    final months = weeks ~/ 4;
    return months == 1 ? '1 Month' : '$months Months';
  }
  return weeks == 1 ? '1 Week' : '$weeks Weeks';
}

Color _seatColor(int seatsLeft) {
  if (seatsLeft <= 0) return const Color(0xFFEF4444);
  if (seatsLeft <= 5) return const Color(0xFFF59E0B);
  return const Color(0xFF34D399);
}

Future<void> showClassDetailSheet(
  BuildContext context, {
  required Course course,
  required CourseBatch batch,
}) {
  final opener = context;
  return showAcademicSheet<void>(
    context,
    backgroundColor: _sheetBg,
    child: Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _sheetBg,
        colorScheme: const ColorScheme.dark(
          surface: _sheetBg,
          onSurface: Colors.white,
          primary: Color(0xFF8B5CF6),
        ),
      ),
      child: ClassDetailSheet(
        course: course,
        batch: batch,
        opener: opener,
      ),
    ),
  );
}

class ClassDetailSheet extends ConsumerWidget {
  const ClassDetailSheet({
    super.key,
    required this.course,
    required this.batch,
    this.opener,
  });

  final Course course;
  final CourseBatch batch;

  /// Context that opened this sheet. Follow-up sheets use it so Enroll stays
  /// on a navigator after this sheet closes.
  final BuildContext? opener;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final institute = ref
        .watch(instituteDetailProvider(course.instituteId))
        .valueOrNull;
    final mode = batch.mode ?? course.mode;
    final category = EducationCategory.fromSlug(
      batch.categorySlug.isNotEmpty ? batch.categorySlug : course.categoryId,
    );
    final faculty = course.faculty.where((item) => item.isActive).firstOrNull;
    final facultyName = faculty?.name.isNotEmpty == true
        ? faculty!.name
        : course.instructorName;
    final role = faculty == null
        ? ''
        : (faculty.designation.isNotEmpty ? faculty.designation : faculty.role);
    final facultyValue = [
      if (facultyName.isNotEmpty) facultyName,
      if (role.isNotEmpty) '($role)',
    ].join(' ');
    final qualification = [
      if (faculty != null && faculty.qualification.isNotEmpty)
        faculty.qualification,
      if (faculty != null && faculty.experienceText.isNotEmpty)
        faculty.experienceText,
      for (final item in faculty?.certifications.take(2) ?? const <String>[])
        item,
    ].join(' • ');
    final timing = [
      if (batch.timing.isNotEmpty) batch.timing,
      if (batch.daysLabel.isNotEmpty) '(${batch.daysLabel})',
    ].join(' ');
    final place = [
      if (institute != null && institute.address.isNotEmpty) institute.address,
      if (course.instituteCity.isNotEmpty) course.instituteCity,
    ].join(', ');
    final phone = course.contactPhone.isNotEmpty
        ? course.contactPhone
        : (institute?.phone ?? '');
    final whatsapp = institute?.whatsapp.isNotEmpty == true
        ? institute!.whatsapp
        : phone;
    final seatsLeft = batch.seatsLeft;
    final highlight = batch.highlightOn(DateTime.now());
    final showNotify = batch.isFull ||
        batch.waitlistEnabled ||
        highlight == BatchHighlight.upcoming;
    final duration = _durationLabel(course.durationWeeks);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Text(
          course.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            height: 1.15,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (course.instituteName.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.apartment_rounded,
                size: 16,
                color: Color(0xFFC4B5FD),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  course.instituteName,
                  style: const TextStyle(
                    color: Color(0xFFC4B5FD),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (course.description.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            course.description,
            style: const TextStyle(color: Color(0xFFCBD5E1), height: 1.35),
          ),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF12182C),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF243049)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'FACULTY & BATCH SPECIFICATIONS',
                style: TextStyle(
                  color: Color(0xFF818CF8),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 12),
              if (facultyValue.isNotEmpty)
                _spec(Icons.person_rounded, 'Faculty Name', facultyValue),
              if (qualification.isNotEmpty)
                _spec(
                  Icons.workspace_premium_outlined,
                  'Qualification & Exp',
                  qualification,
                ),
              if (timing.isNotEmpty)
                _spec(Icons.schedule_rounded, 'Class Timings', timing),
              if (duration.isNotEmpty)
                _spec(Icons.hourglass_bottom_rounded, 'Course Duration', duration),
              if (place.isNotEmpty)
                _spec(Icons.location_on_outlined, 'Campus Location', place),
              _spec(
                Icons.groups_rounded,
                'Batch Seats Available',
                seatsLeft <= 0
                    ? 'Batch full (Total: ${batch.capacity})'
                    : '$seatsLeft seats left (Total: ${batch.capacity})',
                valueColor: _seatColor(seatsLeft),
              ),
              if (category != EducationCategory.all || mode.discoveryLabel.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    [
                      if (category != EducationCategory.all) category.label,
                      mode.discoveryLabel,
                    ].join(' • '),
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        if (facultyName.isNotEmpty) ...[
          const SizedBox(height: 12),
          Material(
            color: const Color(0xFF3B2A78),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              key: Key('class-card-faculty-${batch.id}'),
              borderRadius: BorderRadius.circular(16),
              onTap: () => showFacultyCredentialsSheet(
                context,
                course: course,
                faculty: faculty,
                batch: batch,
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFF1E1B4B),
                      backgroundImage: faculty != null &&
                              faculty.photoUrl.isNotEmpty
                          ? NetworkImage(faculty.photoUrl)
                          : null,
                      child: faculty != null && faculty.photoUrl.isNotEmpty
                          ? null
                          : Text(
                              facultyName[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Instructor Portfolio & Bio',
                            style: TextStyle(
                              color: Color(0xFFDDD6FE),
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            "View $facultyName's Certifications, Bio & All Batches →",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        if (showNotify) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF3F1224),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF9F1239)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.notifications_active_rounded,
                        color: Color(0xFFFB7185), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Batch Full / Upcoming - Waitlist',
                        style: TextStyle(
                          color: Color(0xFFFECDD3),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  'Subscribe to get alerted via push notification when seats become available.',
                  style: TextStyle(color: Color(0xFFFDA4AF), height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('waitlist-notify'),
              onPressed: () => showWaitlistAlertSheet(
                context,
                course: course,
                batch: batch,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE11D48),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_rounded, size: 18),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Notify Me When Spots Open (Push Alert)',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (!batch.isFull) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('class-detail-enroll'),
              onPressed: () => _openNext(
                context,
                (host) => showClassEnrollmentSheet(
                  host,
                  course: course,
                  batch: batch,
                  isTrial: false,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6D28D9),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.event_available_rounded),
              label: const Text('1-Tap Book'),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (whatsapp.isNotEmpty)
              OutlinedButton.icon(
                key: const Key('class-detail-whatsapp'),
                onPressed: () => _contact(
                  context,
                  () => openWhatsApp(whatsapp),
                  'WhatsApp is not available on this device.',
                ),
                icon: const Icon(Icons.chat_rounded),
                label: const Text('WhatsApp'),
              ),
            if (phone.isNotEmpty)
              OutlinedButton.icon(
                key: const Key('class-detail-call'),
                onPressed: () => _contact(
                  context,
                  () => openContactLink(phone),
                  'Calls are not available here. Number: $phone',
                ),
                icon: const Icon(Icons.call_rounded),
                label: const Text('Call'),
              ),
            if (course.hasDemo)
              OutlinedButton(
                key: const Key('class-detail-demo'),
                onPressed: () => _openNext(
                  context,
                  (host) => showClassEnrollmentSheet(
                    host,
                    course: course,
                    batch: batch,
                    isTrial: true,
                  ),
                ),
                child: const Text('Request free demo'),
              ),
          ],
        ),
        if (course.syllabusPoints.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Syllabus',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          for (var i = 0; i < course.syllabusPoints.length; i++)
            ExpansionTile(
              key: Key('syllabus-$i'),
              tilePadding: EdgeInsets.zero,
              title: Text(
                'Module ${i + 1}',
                style: const TextStyle(color: Colors.white),
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      course.syllabusPoints[i],
                      style: const TextStyle(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                ),
              ],
            ),
        ],
        if (institute != null && institute.amenities.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'Amenities',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final amenity in institute.amenities) _tag(amenity),
            ],
          ),
        ],
        if (course.coverImage.isNotEmpty) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AppNetworkImage(
              url: course.coverImage,
              height: 160,
              width: double.infinity,
            ),
          ),
        ],
      ],
    );
  }

  void _openNext(BuildContext context, void Function(BuildContext host) open) {
    final opener = this.opener;
    if (opener == null || !opener.mounted) {
      open(context);
      return;
    }
    showAfterAcademicSheet(context, opener, open);
  }

  Future<void> _contact(
    BuildContext context,
    Future<bool> Function() open,
    String failure,
  ) async {
    final ok = await open();
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure)));
    }
  }
}

Widget _spec(
  IconData icon,
  String label,
  String value, {
  Color valueColor = Colors.white,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _tag(String text) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
  );
}
