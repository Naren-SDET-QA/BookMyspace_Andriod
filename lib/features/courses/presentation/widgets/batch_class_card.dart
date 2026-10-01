import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../venues/presentation/widgets/venue_badges.dart' show formatInr;
import '../../domain/course.dart';
import '../../domain/education_category.dart';
import 'batch_enroll_button.dart';
import 'class_detail_sheet.dart';
import 'external_link.dart';
import 'faculty_credentials_sheet.dart';

/// Seat meter color: green above 5 seats, amber at 1–5, red when full.
Color classSeatMeterColor(int seatsLeft) {
  if (seatsLeft <= 0) return const Color(0xFFEF4444);
  if (seatsLeft <= 5) return const Color(0xFFF59E0B);
  return const Color(0xFF10B981);
}

/// Weeks from the course record, shown as months when they divide evenly.
String classDurationLabel(int weeks) {
  if (weeks <= 0) return '';
  if (weeks % 4 == 0) {
    final months = weeks ~/ 4;
    return months == 1 ? '1 Month' : '$months Months';
  }
  return weeks == 1 ? '1 Week' : '$weeks Weeks';
}

class BatchClassCard extends StatelessWidget {
  const BatchClassCard({
    super.key,
    required this.course,
    required this.batch,
  });

  final Course course;
  final CourseBatch batch;

  @override
  Widget build(BuildContext context) {
    final mode = batch.mode ?? course.mode;
    final seatsLeft = batch.seatsLeft;
    final category = EducationCategory.fromSlug(
      batch.categorySlug.isNotEmpty ? batch.categorySlug : course.categoryId,
    );
    final highlight = batch.highlightOn(DateTime.now());
    final live = highlight == BatchHighlight.liveToday;
    final upcoming = highlight == BatchHighlight.upcoming;
    final faculty = course.faculty.where((item) => item.isActive).firstOrNull;
    final facultyName = faculty?.name.isNotEmpty == true
        ? faculty!.name
        : course.instructorName;
    final facultyRole = faculty == null
        ? ''
        : (faculty.designation.isNotEmpty ? faculty.designation : faculty.role);
    final credentialLine = [
      if (facultyRole.isNotEmpty) facultyRole,
      if (faculty != null)
        for (final item in faculty.certifications.take(2)) item,
      if (faculty != null && faculty.qualification.isNotEmpty)
        faculty.qualification,
    ].join(' • ');
    final shown = batch.feeAmount > 0 ? batch.feeAmount : course.payableAmount;
    final fullCourse = course.feeAmount;
    final showFull = fullCourse > shown && fullCourse > 0;
    final monthly = batch.feeAmount > 0 && fullCourse > batch.feeAmount;
    final offPercent = course.feeAmount > 0 && course.discountAmount > 0
        ? ((course.discountAmount / course.feeAmount) * 100).round()
        : 0;
    final duration = classDurationLabel(course.durationWeeks);
    final place = course.instituteCity;
    final phone = course.contactPhone;

    return Container(
      key: Key('class-card-${batch.id}'),
      decoration: BoxDecoration(
        color: const Color(0xFF101628),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF243049)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Cover(
            batchId: batch.id,
            course: course,
            mode: mode,
            category: category,
            live: live,
            upcoming: upcoming,
            timing: batch.timing,
            seatColor: classSeatMeterColor(seatsLeft),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  key: Key('class-card-details-${batch.id}'),
                  onTap: () => showClassDetailSheet(
                    context,
                    course: course,
                    batch: batch,
                  ),
                  child: Text(
                    course.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (course.instituteName.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E2366),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.apartment_rounded,
                          size: 16,
                          color: Color(0xFFC4B5FD),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            course.instituteName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFE9D5FF),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (course.instituteVerified)
                          const Icon(
                            Icons.verified_rounded,
                            size: 16,
                            color: Color(0xFF34D399),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                _TimingPanel(
                  timing: batch.timing,
                  duration: duration,
                ),
                if (facultyName.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _FacultyPanel(
                    batchId: batch.id,
                    name: facultyName,
                    photoUrl: faculty?.photoUrl ?? '',
                    experience: faculty?.experienceText ?? '',
                    credentialLine: credentialLine,
                    onTap: () => showFacultyCredentialsSheet(
                      context,
                      course: course,
                      faculty: faculty,
                      batch: batch,
                    ),
                  ),
                ],
                if (place.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          place,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFCBD5E1),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.near_me_outlined,
                        size: 16,
                        color: Color(0xFF64748B),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: formatInr(shown),
                            style: const TextStyle(
                              color: Color(0xFFC4B5FD),
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          if (monthly)
                            const TextSpan(
                              text: '/month',
                              style: TextStyle(
                                color: Color(0xFFA78BFA),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (offPercent > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF9F1239),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$offPercent% OFF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    _RoundAction(
                      icon: Icons.call_rounded,
                      color: const Color(0xFF4C1D95),
                      iconColor: const Color(0xFFE9D5FF),
                      onTap: () => _reach(
                        context,
                        phone,
                        () => openContactLink(phone),
                        'Calls are not available here.',
                      ),
                    ),
                    _RoundAction(
                      icon: Icons.chat_rounded,
                      color: const Color(0xFF14532D),
                      iconColor: const Color(0xFF86EFAC),
                      onTap: () => _reach(
                        context,
                        phone,
                        () => openWhatsApp(phone),
                        'WhatsApp is not available on this device.',
                      ),
                    ),
                    BatchEnrollButton(course: course, batch: batch),
                    TextButton.icon(
                      onPressed: () => context.push(AppRoutes.assistant),
                      icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                      label: const Text('AI Help'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFDDD6FE),
                        backgroundColor: const Color(0xFF3B2A78),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
                if (showFull)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Full Course: ${formatInr(fullCourse)}',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _reach(
    BuildContext context,
    String phone,
    Future<bool> Function() open,
    String failure,
  ) async {
    if (phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This institute has no phone number yet.')),
      );
      return;
    }
    final ok = await open();
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$failure Number: $phone')),
      );
    }
  }
}

class _TimingPanel extends StatelessWidget {
  const _TimingPanel({required this.timing, required this.duration});

  final String timing;
  final String duration;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF3B1848), Color(0xFF1A1230)],
        ),
        border: Border.all(color: const Color(0xFF6B2148)),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded, color: Color(0xFFF9A8D4), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TIMING',
                  style: TextStyle(
                    color: Color(0xFFF9A8D4),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                Text(
                  timing.isEmpty ? 'Timing not set' : timing,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          if (duration.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF120C22),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF3B2A55)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.person_rounded,
                    size: 14,
                    color: Color(0xFFE9D5FF),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    duration,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FacultyPanel extends StatelessWidget {
  const _FacultyPanel({
    required this.batchId,
    required this.name,
    required this.photoUrl,
    required this.experience,
    required this.credentialLine,
    required this.onTap,
  });

  final String batchId;
  final String name;
  final String photoUrl;
  final String experience;
  final String credentialLine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF161B30),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: Key('class-card-faculty-$batchId'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF312E81),
                    backgroundImage:
                        photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                    child: photoUrl.isNotEmpty
                        ? null
                        : Text(
                            name[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (experience.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3F2E12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '★ $experience',
                        style: const TextStyle(
                          color: Color(0xFFFBBF24),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              if (credentialLine.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  credentialLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              const Text(
                'View Biography, Certifications & All Batches →',
                style: TextStyle(
                  color: Color(0xFFC4B5FD),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 18, color: iconColor),
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({
    required this.batchId,
    required this.course,
    required this.mode,
    required this.category,
    required this.live,
    required this.upcoming,
    required this.timing,
    required this.seatColor,
  });

  final String batchId;
  final Course course;
  final CourseMode mode;
  final EducationCategory category;
  final bool live;
  final bool upcoming;
  final String timing;
  final Color seatColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: Key('class-card-seats-$batchId'),
      height: 168,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (course.coverImage.isEmpty)
            const ColoredBox(color: Color(0xFF0F172A))
          else
            AppNetworkImage(url: course.coverImage, fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x33000000), Color(0xCC070B14)],
              ),
            ),
          ),
          Positioned(
            left: 10,
            top: 10,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (category != EducationCategory.all)
                  _badge(category.label, const Color(0xFF4C1D95)),
                if (upcoming)
                  _badge('UPCOMING BATCH', const Color(0xFFDB2777)),
              ],
            ),
          ),
          Positioned(
            right: 10,
            top: 10,
            child: live
                ? const _LiveNowBadge()
                : _badge(
                    mode.discoveryLabel,
                    Colors.black.withValues(alpha: 0.35),
                    outlined: true,
                  ),
          ),
          if (timing.isNotEmpty && upcoming)
            Positioned(
              right: 10,
              bottom: 10,
              child: Container(
                key: const Key('batch-todays-topic'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF166534),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  live ? 'TODAY $timing' : timing,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          if (!live && !upcoming)
            Positioned(
              left: 10,
              bottom: 10,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: seatColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color, {bool outlined = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: outlined ? const Color(0x660B0F19) : color,
        borderRadius: BorderRadius.circular(8),
        border: outlined ? Border.all(color: Colors.white70) : null,
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _LiveNowBadge extends StatefulWidget {
  const _LiveNowBadge();

  @override
  State<_LiveNowBadge> createState() => _LiveNowBadgeState();
}

class _LiveNowBadgeState extends State<_LiveNowBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('batch-todays-topic'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF16A34A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: Tween<double>(begin: 0.4, end: 1).animate(_pulse),
            child: const Icon(
              Icons.bolt_rounded,
              size: 14,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 2),
          const Text(
            'LIVE NOW',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
