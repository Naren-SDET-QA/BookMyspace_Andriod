import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../domain/receipt.dart';
import '../domain/receipt_repository.dart';
import '../infrastructure/supabase_receipt_repository.dart';

/// Receipt repository instance.
final receiptRepositoryProvider = Provider<ReceiptRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  return SupabaseReceiptRepository(client);
});

/// The itemized receipt for a booking.
///
/// `autoDispose` so reopening the screen re-asks the server rather than serving
/// a stale in-memory copy. That is safe precisely because the server freezes
/// the document on first issue: a refetch returns the same bytes, so it cannot
/// silently change what a customer was already shown.
final receiptProvider =
    FutureProvider.autoDispose.family<ReceiptResult, String>((ref, bookingId) {
  return ref.watch(receiptRepositoryProvider).issueReceipt(bookingId);
});
