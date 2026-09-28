import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../domain/course_waitlist.dart';
import '../infrastructure/supabase_course_waitlist_repository.dart';
import 'course_providers.dart';

final courseWaitlistRepositoryProvider =
    Provider<CourseWaitlistRepository>((ref) {
  return SupabaseCourseWaitlistRepository(ref.watch(supabaseProvider));
});

/// The signed-in learner's waitlist entries keyed by batch id.
final myCourseWaitlistProvider =
    FutureProvider<Map<String, CourseWaitlistEntry>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const {};
  final entries = await ref.watch(courseWaitlistRepositoryProvider).mine();
  return {for (final e in entries) e.batchId: e};
});

/// Join/leave actions. Do not watch from build().
class CourseWaitlistController {
  CourseWaitlistController(this._ref);

  final Ref _ref;

  Future<int> join({required String courseId, required String batchId}) async {
    final position =
        await _ref.read(courseWaitlistRepositoryProvider).join(batchId);
    _refresh(courseId);
    return position;
  }

  Future<void> leave({required String courseId, required String batchId}) async {
    await _ref.read(courseWaitlistRepositoryProvider).leave(batchId);
    _refresh(courseId);
  }

  void _refresh(String courseId) {
    _ref.invalidate(myCourseWaitlistProvider);
    _ref.invalidate(publishedCoursesProvider);
    _ref.invalidate(courseDetailProvider(courseId));
    _ref.invalidate(instituteCoursesProvider);
  }
}

final courseWaitlistControllerProvider =
    Provider<CourseWaitlistController>((ref) => CourseWaitlistController(ref));
