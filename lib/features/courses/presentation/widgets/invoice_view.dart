import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../venues/presentation/widgets/venue_badges.dart' show formatInr;
import '../../domain/course.dart';

/// Composes a client-side [EducationInvoice] from an enrollment until a
/// server-side invoice entity exists. The number is derived from the batch id
/// so it is stable across views of the same enrollment.
EducationInvoice composeInvoice(
  MyEnrolledCourse enrollment, {
  required String studentName,
}) {
  final course = enrollment.course;
  final batch = enrollment.batch;
  final suffix = batch.id.length >= 6
      ? batch.id.substring(0, 6).toUpperCase()
      : batch.id.toUpperCase();
  return EducationInvoice(
    number: 'EDU-$suffix',
    courseTitle: course.title,
    instituteName: course.instituteName,
    batchLabel: batch.label,
    studentName: studentName,
    feeAmount: course.feeAmount,
    discountAmount: course.discountAmount,
    issuedAt: enrollment.enrolledAt ?? DateTime.now(),
    status: course.isFree ? 'issued' : 'paid',
  );
}

/// Shows the education invoice as a dialog with a clear fee breakdown.
Future<void> showInvoiceDialog(
  BuildContext context, {
  required EducationInvoice invoice,
}) {
  final l10n = AppLocalizations.of(context);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.receipt_long_rounded, color: AppTheme.violet),
          const SizedBox(width: 8),
          Expanded(child: Text(l10n.invoice)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Line(label: l10n.invoiceNumber, value: invoice.number),
          _Line(
            label: l10n.issuedOn,
            value: DateFormat.yMMMd().format(invoice.issuedAt),
          ),
          if (invoice.studentName.isNotEmpty)
            _Line(label: l10n.studentName, value: invoice.studentName),
          _Line(label: l10n.courses, value: invoice.courseTitle),
          if (invoice.instituteName.isNotEmpty)
            _Line(label: l10n.institutes, value: invoice.instituteName),
          if (invoice.batchLabel.isNotEmpty)
            _Line(label: l10n.preferredBatch, value: invoice.batchLabel),
          const Divider(height: 24),
          _Line(
            label: l10n.courseFee,
            value: invoice.feeAmount <= 0
                ? l10n.freeEvent
                : formatInr(invoice.feeAmount),
          ),
          if (invoice.discountAmount > 0)
            _Line(
              label: l10n.discount,
              value: '- ${formatInr(invoice.discountAmount)}',
            ),
          const Divider(height: 24),
          _Line(
            label: l10n.netAmount,
            value: invoice.netAmount <= 0
                ? l10n.freeEvent
                : formatInr(invoice.netAmount),
            bold: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(l10n.close),
        ),
      ],
    ),
  );
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: bold ? AppTheme.violet : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
