import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr/qr.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../cms/domain/configurable_form.dart';
import '../../../cms/presentation/widgets/configurable_form_fields.dart';
import '../../domain/course.dart';
import '../course_providers.dart';

Future<void> showClassEnrollmentSheet(
  BuildContext context, {
  required Course course,
  required CourseBatch batch,
  required bool isTrial,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _EnrollmentForm(
        course: course,
        batch: batch,
        isTrial: isTrial,
      ),
    ),
  );
}

class _EnrollmentForm extends ConsumerStatefulWidget {
  const _EnrollmentForm({
    required this.course,
    required this.batch,
    required this.isTrial,
  });

  final Course course;
  final CourseBatch batch;
  final bool isTrial;

  @override
  ConsumerState<_EnrollmentForm> createState() => _EnrollmentFormState();
}

class _EnrollmentFormState extends ConsumerState<_EnrollmentForm> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _answers = {};
  DateTime _start = DateTime.now();
  bool _busy = false;
  String? _error;

  Future<void> _submit(ConfigurableFormSchema schema) async {
    final errors = schema.validateAnswers(_answers);
    if (errors.isNotEmpty || !(_formKey.currentState?.validate() ?? false)) {
      setState(() => _error =
          errors.values.isEmpty ? 'Check the form.' : errors.values.first);
      return;
    }
    if (ref.read(currentUserProvider) == null) {
      Navigator.pop(context);
      if (!context.mounted) return;
      context.push(AppRoutes.login);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final record = await ref.read(courseEnrollmentControllerProvider).enroll(
            courseId: widget.course.id,
            batchId: widget.batch.id,
            isTrial: widget.isTrial,
            studentName: (_answers['full_name'] ?? '').toString(),
            contactPhone: (_answers['mobile'] ?? '').toString(),
            preferredStart: _start,
            formAnswers: Map<String, dynamic>.from(_answers),
          );
      if (!mounted) return;
      Navigator.pop(context);
      await showEnrollmentVoucherDialog(
        context,
        course: widget.course,
        batch: widget.batch,
        record: record,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isTrial ? 'Book Free Trial' : 'Enroll Now';
    final theme = Theme.of(context);
    final seatsLeft = widget.batch.seatsLeft;
    final total = widget.batch.capacity;
    final isLow = seatsLeft <= 5 && !widget.isTrial;
    final instituteAsync =
        ref.watch(instituteDetailProvider(widget.course.instituteId));
    final institute = instituteAsync.valueOrNull;
    final schema = institute?.publishedRegistrationForm ??
        ConfigurableFormSchema.defaults();
    final showSeats = widget.course.instituteModules.enabled('seats') &&
        (institute?.modules.enabled('seats') ?? true);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  '${widget.course.title} · ${widget.batch.label}',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                // ── Seat availability indicator ──
                if (!widget.isTrial && showSeats)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isLow
                          ? const Color(0xFFEF4444).withValues(alpha: 0.08)
                          : const Color(0xFF10B981).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isLow
                            ? const Color(0xFFEF4444).withValues(alpha: 0.25)
                            : const Color(0xFF10B981).withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isLow
                              ? Icons.warning_amber_rounded
                              : Icons.event_available_rounded,
                          size: 18,
                          color: isLow
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF10B981),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isLow
                                    ? 'Only $seatsLeft seats remaining!'
                                    : '$seatsLeft of $total seats available',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: isLow
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xFF10B981),
                                ),
                              ),
                              if (isLow)
                                Text(
                                  'Enroll now to secure your seat',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFFEF4444)
                                        .withValues(alpha: 0.8),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!widget.isTrial && showSeats) const SizedBox(height: 12),
                ConfigurableFormFields(
                  schema: schema,
                  values: _answers,
                  onChanged: (key, value) =>
                      setState(() => _answers[key] = value),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Preferred batch start'),
                  subtitle: Text(DateFormat.yMMMd().format(_start)),
                  trailing: const Icon(Icons.event_rounded),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _start,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => _start = picked);
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : () => _submit(schema),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.violet,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _busy
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Securing your seat...',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        )
                      : Text(title),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showEnrollmentVoucherDialog(
  BuildContext context, {
  required Course course,
  required CourseBatch batch,
  required CourseEnrollmentRecord record,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      final code =
          record.admissionCode.isEmpty ? record.id : record.admissionCode;
      final theme = Theme.of(context);
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: record.isTrial
                    ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
                    : const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                record.isTrial
                    ? Icons.play_circle_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: record.isTrial
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                record.isTrial ? 'Trial Booked!' : 'Admission Confirmed!',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Admission ID ──
              Text('Admission ID',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.violet.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.violet.withValues(alpha: 0.15),
                  ),
                ),
                child: SelectableText(
                  code,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: 0.8,
                    color: AppTheme.violet,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // ── QR Code ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.violetSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _QrCodeWidget(data: code),
                    const SizedBox(height: 8),
                    Text(
                      'Batch Pass · $code',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${batch.label} · ${batch.timing.isNotEmpty ? batch.timing : batch.startsOn.toString().substring(0, 10)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // ── Institute details ──
              if (course.instituteName.isNotEmpty)
                _detailRow(Icons.school_outlined, course.instituteName),
              if (course.instituteCity.isNotEmpty)
                _detailRow(Icons.location_on_outlined, course.instituteCity),
              if (course.contactPhone.isNotEmpty)
                _detailRow(
                    Icons.phone_outlined, 'Faculty: ${course.contactPhone}'),
              if (course.instructorName.isNotEmpty)
                _detailRow(Icons.person_outline_rounded, course.instructorName),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Admission ID copied')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy ID'),
          ),
          TextButton.icon(
            onPressed: () {
              final start = batch.startsOn.toUtc();
              final end = start.add(const Duration(hours: 2));
              final uri = Uri.parse(
                'https://calendar.google.com/calendar/render?action=TEMPLATE'
                '&text=${Uri.encodeComponent(course.title)}'
                '&dates=${_cal(start)}/${_cal(end)}'
                '&details=${Uri.encodeComponent('Admission ID: $code\n${course.instituteName}')}',
              );
              launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            icon: const Icon(Icons.calendar_today_rounded, size: 16),
            label: const Text('Reminder'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.violet),
            child: const Text('Done'),
          ),
        ],
      );
    },
  );
}

Widget _detailRow(IconData icon, String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    ),
  );
}

/// Real QR code rendered via the `qr` package (ISO/IEC 18004).
class _QrCodeWidget extends StatelessWidget {
  const _QrCodeWidget({required this.data});

  final String data;

  static const int _errorCorrectLevel = QrErrorCorrectLevel.M;

  QrImage? _encode() {
    try {
      return QrImage(
        QrCode.fromData(
          data: data,
          errorCorrectLevel: _errorCorrectLevel,
        ),
      );
    } on InputTooLongException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = _encode();
    if (image == null) {
      return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(16),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_2, size: 32, color: Colors.black38),
            SizedBox(height: 4),
            Text(
              'QR unavailable',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Colors.black54),
            ),
          ],
        ),
      );
    }

    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(6),
      child: CustomPaint(
        painter: _QrMatrixPainter(image: image),
      ),
    );
  }
}

/// Renders the QR matrix from the `qr` package's [QrImage].
class _QrMatrixPainter extends CustomPainter {
  const _QrMatrixPainter({required this.image});

  final QrImage image;

  static const int _quietZone = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final totalModules = image.moduleCount + _quietZone * 2;
    final cell = size.shortestSide / totalModules;
    final originX = (size.width - cell * totalModules) / 2;
    final originY = (size.height - cell * totalModules) / 2;

    final modulePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.black;

    for (var row = 0; row < image.moduleCount; row++) {
      for (var col = 0; col < image.moduleCount; col++) {
        if (!image.isDark(row, col)) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            originX + (col + _quietZone) * cell,
            originY + (row + _quietZone) * cell,
            cell,
            cell,
          ),
          modulePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrMatrixPainter oldDelegate) =>
      oldDelegate.image != image;
}

String _cal(DateTime value) {
  final utc = value.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${utc.year}${two(utc.month)}${two(utc.day)}T${two(utc.hour)}${two(utc.minute)}00Z';
}
