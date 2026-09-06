import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/course.dart';
import '../domain/course_repository.dart';

final courseRepositoryProvider = Provider<CourseRepository>((ref) {
  throw UnimplementedError('Initialize courseRepositoryProvider in ProviderScope');
});

final coursesProvider = FutureProvider<List<Course>>((ref) {
  return ref.watch(courseRepositoryProvider).courses();
});
