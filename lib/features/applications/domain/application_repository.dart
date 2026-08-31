/// 投递中心的前后端数据契约。
abstract interface class ApplicationRepository {
  Future<ApplicationDashboard> getDashboard({DateTime? weekStart});

  Future<DeliveryTask> createDeliveryTask(
      {required List<DeliveryJob> jobs, required String resumeId});

  Future<DeliveryTask> getDeliveryTask(String taskId);

  Future<DeliveryTask> pauseDeliveryTask(String taskId);

  Future<DeliveryTask> resumeDeliveryTask(String taskId);

  Future<ApplicationRecord> createApplication({
    required String jobId,
    required String platform,
    required String title,
    required String company,
  });
}

enum DeliveryTaskStatus {
  validating,
  queued,
  running,
  paused,
  completed,
  partiallyFailed,
  failed
}

class DeliveryJob {
  const DeliveryJob(
      {required this.id,
      required this.platform,
      required this.title,
      required this.company});
  final String id;
  final String platform;
  final String title;
  final String company;
}

class DeliveryTask {
  const DeliveryTask(
      {required this.id,
      required this.status,
      required this.total,
      required this.completed,
      required this.failed,
      required this.createdAt,
      this.message});
  final String id;
  final DeliveryTaskStatus status;
  final int total;
  final int completed;
  final int failed;
  final DateTime createdAt;
  final String? message;
}

enum ApplicationDeliveryStatus {
  queued,
  submitting,
  submitted,
  viewed,
  replied,
  failed
}

class ApplicationRecord {
  const ApplicationRecord(
      {required this.id,
      required this.jobId,
      required this.platform,
      required this.title,
      required this.company,
      required this.status,
      required this.submittedAt});

  final String id;
  final String jobId;
  final String platform;
  final String title;
  final String company;
  final ApplicationDeliveryStatus status;
  final DateTime submittedAt;
}

class ChannelApplicationStat {
  const ChannelApplicationStat(
      {required this.platform,
      required this.available,
      required this.submitted,
      required this.viewed,
      required this.replied});

  final String platform;
  final int available;
  final int submitted;
  final int viewed;
  final int replied;

  double get rate => available == 0 ? 0 : submitted / available;
}

class DailyApplicationStat {
  const DailyApplicationStat(
      {required this.date,
      required this.platform,
      required this.available,
      required this.submitted});

  final DateTime date;
  final String platform;
  final int available;
  final int submitted;
}

class ApplicationDashboard {
  const ApplicationDashboard(
      {required this.weekStart,
      required this.weekEnd,
      required this.weekTotal,
      required this.totalAvailable,
      required this.viewed,
      required this.replied,
      required this.interviews,
      required this.channels,
      required this.daily,
      required this.recent});

  final DateTime weekStart;
  final DateTime weekEnd;
  final int weekTotal;
  final int totalAvailable;
  final int viewed;
  final int replied;
  final int interviews;
  final List<ChannelApplicationStat> channels;
  final List<DailyApplicationStat> daily;
  final List<ApplicationRecord> recent;
}
