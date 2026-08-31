import '../../../core/network/api_client.dart';
import '../domain/job_repository.dart';

class RestJobRepository implements JobRepository {
  RestJobRepository(this.api);
  final ApiClient api;

  @override
  Future<JobSearchResult<Map<String, dynamic>>> search(JobQuery query) async {
    final json = await api.getJson('/api/v1/jobs', query: {
      'keyword': query.keywords.join(','),
      'city': query.cities.join(','),
      'platforms': query.platforms.join(','),
      'page': '${query.page}',
      'pageSize': '${query.pageSize}'
    });
    final items = (json['items'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    return JobSearchResult(
        items: items,
        total: (json['total'] as num?)?.toInt() ?? items.length,
        page: (json['page'] as num?)?.toInt() ?? query.page,
        pageSize: (json['pageSize'] as num?)?.toInt() ?? query.pageSize);
  }

  @override
  Future<Map<String, dynamic>> getDetail(String jobId) =>
      api.getJson('/api/v1/jobs/$jobId');
}
