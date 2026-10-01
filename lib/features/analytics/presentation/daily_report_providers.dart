import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../infrastructure/supabase_daily_report_repository.dart';

final dailyReportRepositoryProvider = Provider<SupabaseDailyReportRepository>(
  (ref) => SupabaseDailyReportRepository(ref.watch(supabaseProvider)),
);

final dailyReportEnabledProvider = FutureProvider.autoDispose<bool>((ref) {
  return ref.watch(dailyReportRepositoryProvider).enabled();
});
