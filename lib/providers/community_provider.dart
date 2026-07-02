import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/community_report.dart';
import '../repositories/community_repository.dart';
import 'dio_provider.dart';

final communityRepositoryProvider = Provider<CommunityRepository>(
  (ref) => CommunityRepository(ref.watch(dioProvider)),
);

final communityReportsProvider = FutureProvider<List<CommunityReport>>(
  (ref) => ref.watch(communityRepositoryProvider).getReports(),
);
