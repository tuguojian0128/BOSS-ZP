import '../domain/application_repository.dart';

class MockApplicationRepository implements ApplicationRepository {
  static const platforms = ['BOSS 直聘', '智联招聘', '猎聘', '前程无忧', '鱼泡直聘', '国聘'];
  final Map<String, DeliveryTask> _tasks = {};

  @override
  Future<ApplicationDashboard> getDashboard({DateTime? weekStart}) async {
    final now = DateTime.now();
    final start = weekStart ??
        DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
    final channels = <ChannelApplicationStat>[
      const ChannelApplicationStat(
          platform: 'BOSS 直聘',
          available: 1050,
          submitted: 386,
          viewed: 218,
          replied: 62),
      const ChannelApplicationStat(
          platform: '智联招聘',
          available: 720,
          submitted: 214,
          viewed: 124,
          replied: 31),
      const ChannelApplicationStat(
          platform: '猎聘',
          available: 460,
          submitted: 128,
          viewed: 86,
          replied: 25),
      const ChannelApplicationStat(
          platform: '前程无忧',
          available: 580,
          submitted: 176,
          viewed: 93,
          replied: 22),
      const ChannelApplicationStat(
          platform: '鱼泡直聘',
          available: 390,
          submitted: 96,
          viewed: 44,
          replied: 11),
      const ChannelApplicationStat(
          platform: '国聘',
          available: 280,
          submitted: 64,
          viewed: 28,
          replied: 7),
    ];
    final daily = <DailyApplicationStat>[];
    for (var day = 0; day < 7; day++) {
      for (var index = 0; index < platforms.length; index++) {
        final available =
            [150, 105, 66, 82, 56, 40][index] + ((day * 7 + index * 3) % 15);
        final submitted = [54, 31, 19, 25, 14, 9][index] + ((day + index) % 6);
        daily.add(DailyApplicationStat(
            date: start.add(Duration(days: day)),
            platform: platforms[index],
            available: available,
            submitted: submitted));
      }
    }
    final recent = <ApplicationRecord>[
      ApplicationRecord(
          id: 'app-001',
          jobId: 'boss-001',
          platform: 'BOSS 直聘',
          title: '高级 Java 开发工程师',
          company: '星河科技',
          status: ApplicationDeliveryStatus.viewed,
          submittedAt: now.subtract(const Duration(hours: 2))),
      ApplicationRecord(
          id: 'app-002',
          jobId: 'zhipin-001',
          platform: '智联招聘',
          title: 'Java 后端工程师',
          company: '智联云科',
          status: ApplicationDeliveryStatus.submitted,
          submittedAt: now.subtract(const Duration(hours: 4))),
      ApplicationRecord(
          id: 'app-003',
          jobId: 'liepin-001',
          platform: '猎聘',
          title: '资深后端开发工程师',
          company: '猎头科技',
          status: ApplicationDeliveryStatus.replied,
          submittedAt: now.subtract(const Duration(days: 1))),
      ApplicationRecord(
          id: 'app-004',
          jobId: 'job51-001',
          platform: '前程无忧',
          title: '后端研发工程师',
          company: '五一人才科技',
          status: ApplicationDeliveryStatus.submitted,
          submittedAt: now.subtract(const Duration(days: 1, hours: 3))),
    ];
    return ApplicationDashboard(
        weekStart: start,
        weekEnd: start.add(const Duration(days: 6)),
        weekTotal: channels.fold(0, (sum, item) => sum + item.submitted),
        totalAvailable: channels.fold(0, (sum, item) => sum + item.available),
        viewed: channels.fold(0, (sum, item) => sum + item.viewed),
        replied: channels.fold(0, (sum, item) => sum + item.replied),
        interviews: 18,
        channels: channels,
        daily: daily,
        recent: recent);
  }

  @override
  Future<ApplicationRecord> createApplication(
          {required String jobId,
          required String platform,
          required String title,
          required String company}) async =>
      ApplicationRecord(
          id: 'app-${DateTime.now().millisecondsSinceEpoch}',
          jobId: jobId,
          platform: platform,
          title: title,
          company: company,
          status: ApplicationDeliveryStatus.queued,
          submittedAt: DateTime.now());
  @override
  Future<DeliveryTask> createDeliveryTask(
      {required List<DeliveryJob> jobs, required String resumeId}) async {
    final task = DeliveryTask(
        id: 'delivery-${DateTime.now().millisecondsSinceEpoch}',
        status: DeliveryTaskStatus.running,
        total: jobs.length,
        completed: 0,
        failed: 0,
        createdAt: DateTime.now(),
        message: '已通过简历和授权校验，开始投递');
    _tasks[task.id] = task;
    return task;
  }

  @override
  Future<DeliveryTask> getDeliveryTask(String taskId) async =>
      _tasks[taskId] ??
      DeliveryTask(
          id: 'missing',
          status: DeliveryTaskStatus.failed,
          total: 0,
          completed: 0,
          failed: 0,
          createdAt: DateTime.now(),
          message: '任务不存在');

  @override
  Future<DeliveryTask> pauseDeliveryTask(String taskId) async =>
      _replaceTask(taskId, DeliveryTaskStatus.paused);

  @override
  Future<DeliveryTask> resumeDeliveryTask(String taskId) async =>
      _replaceTask(taskId, DeliveryTaskStatus.running);

  DeliveryTask _replaceTask(String id, DeliveryTaskStatus status) {
    final old = _tasks[id];
    if (old == null) {
      return DeliveryTask(
          id: 'missing',
          status: DeliveryTaskStatus.failed,
          total: 0,
          completed: 0,
          failed: 0,
          createdAt: DateTime.now(),
          message: '任务不存在');
    }
    final next = DeliveryTask(
        id: old.id,
        status: status,
        total: old.total,
        completed: old.completed,
        failed: old.failed,
        createdAt: old.createdAt,
        message:
            status == DeliveryTaskStatus.paused ? '任务已暂停，可随时继续' : '任务继续执行');
    _tasks[id] = next;
    return next;
  }
}
