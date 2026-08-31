import '../../../core/network/api_client.dart';
import '../domain/application_repository.dart';

class RestApplicationRepository implements ApplicationRepository {
  RestApplicationRepository(this.api);
  final ApiClient api;

  @override
  Future<ApplicationDashboard> getDashboard({DateTime? weekStart}) async {
    final json = await api.getJson('/api/v1/applications/dashboard');
    return ApplicationDashboard(
        weekStart: DateTime.parse(json['weekStart'].toString()),
        weekEnd: DateTime.parse(json['weekEnd'].toString()),
        weekTotal: _int(json['weekTotal']),
        totalAvailable: _int(json['totalAvailable']),
        viewed: _int(json['viewed']),
        replied: _int(json['replied']),
        interviews: _int(json['interviews']),
        channels: (json['channels'] as List? ?? const []).map((item) {
          final value = Map<String, dynamic>.from(item as Map);
          return ChannelApplicationStat(
              platform: value['platform'].toString(),
              available: _int(value['available']),
              submitted: _int(value['submitted']),
              viewed: _int(value['viewed']),
              replied: _int(value['replied']));
        }).toList(),
        daily: (json['daily'] as List? ?? const []).map((item) {
          final value = Map<String, dynamic>.from(item as Map);
          return DailyApplicationStat(
              date: DateTime.parse(value['date'].toString()),
              platform: value['platform'].toString(),
              available: _int(value['available']),
              submitted: _int(value['submitted']));
        }).toList(),
        recent: const []);
  }

  @override
  Future<ApplicationRecord> createApplication(
      {required String jobId,
      required String platform,
      required String title,
      required String company}) async {
    final json = await api.postJson('/api/v1/applications', {
      'jobId': jobId,
      'platform': platform,
      'title': title,
      'company': company
    });
    return ApplicationRecord(
        id: json['id'].toString(),
        jobId: jobId,
        platform: platform,
        title: title,
        company: company,
        status: ApplicationDeliveryStatus.queued,
        submittedAt: DateTime.parse(json['submittedAt'].toString()));
  }

  @override
  Future<DeliveryTask> createDeliveryTask(
          {required List<DeliveryJob> jobs, required String resumeId}) async =>
      _task(await api.postJson('/api/v1/applications/batch', {
        'resumeId': resumeId,
        'jobs': jobs
            .map((job) => {
                  'id': job.id,
                  'platform': job.platform,
                  'title': job.title,
                  'company': job.company
                })
            .toList()
      }));

  @override
  Future<DeliveryTask> getDeliveryTask(String taskId) async =>
      _task(await api.getJson('/api/v1/applications/tasks/$taskId'));

  @override
  Future<DeliveryTask> pauseDeliveryTask(String taskId) async =>
      _task(await api.postJson('/api/v1/applications/tasks/$taskId/pause'));

  @override
  Future<DeliveryTask> resumeDeliveryTask(String taskId) async =>
      _task(await api.postJson('/api/v1/applications/tasks/$taskId/resume'));

  DeliveryTask _task(Map<String, dynamic> json) => DeliveryTask(
      id: json['id'].toString(),
      status: DeliveryTaskStatus.values.firstWhere(
          (item) => item.name == json['status'],
          orElse: () => DeliveryTaskStatus.failed),
      total: _int(json['total']),
      completed: _int(json['completed']),
      failed: _int(json['failed']),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      message: json['message']?.toString());
}

int _int(Object? value) => (value as num?)?.toInt() ?? 0;
