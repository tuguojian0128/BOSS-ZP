/// 工作台的数据访问抽象。
///
/// 页面和状态层只依赖这个接口，不直接依赖 BOSS 或 HTTP。
abstract interface class WorkbenchRepository {
  Future<List<WorkbenchJob>> searchJobs(WorkbenchSearchQuery query);

  Future<WorkbenchJob> getJobDetail(String jobId);

  Future<ApplicationPreview> previewApplication(
    String jobId,
    String resumeVersionId,
  );

  Future<ApplicationResult> submitApplication(ApplicationRequest request);
}

class WorkbenchSearchQuery {
  const WorkbenchSearchQuery({
    required this.keyword,
    required this.city,
    required this.salary,
    this.onlyHighMatch = true,
  });

  final String keyword;
  final String city;
  final String salary;
  final bool onlyHighMatch;
}

class WorkbenchJob {
  const WorkbenchJob({
    required this.id,
    required this.title,
    required this.company,
    required this.location,
    required this.salary,
    required this.matchScore,
  });

  final String id;
  final String title;
  final String company;
  final String location;
  final String salary;
  final int matchScore;
}

class ApplicationPreview {
  const ApplicationPreview({
    required this.jobId,
    required this.resumeVersionId,
    required this.fields,
  });

  final String jobId;
  final String resumeVersionId;
  final Map<String, String> fields;
}

class ApplicationRequest {
  const ApplicationRequest({
    required this.jobId,
    required this.resumeVersionId,
    required this.message,
  });

  final String jobId;
  final String resumeVersionId;
  final String message;
}

class ApplicationResult {
  const ApplicationResult({
    required this.applicationId,
    required this.status,
  });

  final String applicationId;
  final String status;
}
