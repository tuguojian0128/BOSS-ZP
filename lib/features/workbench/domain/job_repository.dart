class JobQuery {
  const JobQuery(
      {this.keywords = const [],
      this.cities = const [],
      this.platforms = const [],
      this.minSalaryK,
      this.maxSalaryK,
      this.onlyHighMatch = false,
      this.page = 1,
      this.pageSize = 20});
  final List<String> keywords;
  final List<String> cities;
  final List<String> platforms;
  final int? minSalaryK;
  final int? maxSalaryK;
  final bool onlyHighMatch;
  final int page;
  final int pageSize;
}

class JobSearchResult<T> {
  const JobSearchResult(
      {required this.items,
      required this.total,
      required this.page,
      required this.pageSize});
  final List<T> items;
  final int total;
  final int page;
  final int pageSize;
}

abstract interface class JobRepository {
  Future<JobSearchResult<Map<String, dynamic>>> search(JobQuery query);
  Future<Map<String, dynamic>> getDetail(String jobId);
}
