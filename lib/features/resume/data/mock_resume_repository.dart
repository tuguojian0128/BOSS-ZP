import '../domain/resume_repository.dart';

/// 开发阶段使用的本地仓库。
///
/// 它模拟“创建导入任务 → 上传 → 解析 → 读取结构化简历”的后端链路，
/// 让前端在真实 API 完成前就可以验证完整交互。
class MockResumeRepository implements ResumeRepository {
  MockResumeRepository()
      : _profile = ResumeProfile(
          id: 'resume_demo_001',
          fileName: '张三-简历.pdf',
          basic: const ResumeBasicInfo(
            name: '张三',
            phone: '138****8000',
            email: 'zhangsan@example.com',
            city: '上海',
          ),
          workExperiences: const [
            ResumeWorkExperience(
              company: '星河科技',
              title: '高级 Java 开发工程师',
              startDate: '2021.06',
              endDate: '至今',
              description: '负责交易系统与微服务架构建设。',
            ),
            ResumeWorkExperience(
              company: '云杉网络',
              title: '后端开发工程师',
              startDate: '2018.07',
              endDate: '2021.05',
              description: '参与订单中心、数据平台研发。',
            ),
          ],
          education: const [
            ResumeEducation(
              school: '上海大学',
              major: '计算机科学与技术',
              degree: '本科',
              startDate: '2014',
              endDate: '2018',
            ),
          ],
          projects: const [
            ResumeProject(
                name: '交易系统重构',
                role: '技术负责人',
                description: '拆分核心交易链路，提升系统稳定性。'),
            ResumeProject(
                name: '订单中心', role: '后端开发', description: '建设统一订单状态与履约服务。'),
            ResumeProject(
                name: '数据平台', role: '后端开发', description: '搭建数据采集和指标服务。'),
          ],
          skills: const [
            'Java',
            'Spring Boot',
            '微服务',
            'MySQL',
            'Redis',
            'Docker'
          ],
          completeness: 98,
          updatedAt: _demoUpdatedAt,
        );

  static final DateTime _demoUpdatedAt = DateTime(2026, 8, 30, 9, 42);
  ResumeProfile _profile;
  final Map<String, ResumeParseTask> _tasks = {};

  @override
  Future<ResumeImportTicket> createImport(
      String fileName, String contentType) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final ticket = ResumeImportTicket(
      resumeId: 'resume_$stamp',
      uploadUrl: 'mock://resume-upload/$stamp',
      taskId: 'parse_$stamp',
    );
    _tasks[ticket.taskId] = ResumeParseTask(
      taskId: ticket.taskId,
      status: ResumeParseStatus.uploading,
      progress: 8,
      message: '等待文件上传',
    );
    _profile = _profile.copyWith(id: ticket.resumeId, fileName: fileName);
    return ticket;
  }

  @override
  Future<void> uploadImport(ResumeImportTicket ticket, List<int> bytes) async {
    _tasks[ticket.taskId] = ResumeParseTask(
      taskId: ticket.taskId,
      status: ResumeParseStatus.parsing,
      progress: 28,
      message: '文件已上传，正在识别内容',
    );
    await Future<void>.delayed(const Duration(milliseconds: 700));
    _tasks[ticket.taskId] = ResumeParseTask(
      taskId: ticket.taskId,
      status: ResumeParseStatus.parsing,
      progress: 74,
      message: '正在提取工作经历、教育背景和技能',
    );
    await Future<void>.delayed(const Duration(milliseconds: 700));
    _tasks[ticket.taskId] = ResumeParseTask(
      taskId: ticket.taskId,
      status: ResumeParseStatus.needsReview,
      progress: _profile.completeness,
      message: '识别完成，请校对标记字段',
    );
  }

  @override
  Future<ResumeParseTask> getParseTask(String taskId) async {
    return _tasks[taskId] ??
        ResumeParseTask(
            taskId: taskId, status: ResumeParseStatus.failed, message: '任务不存在');
  }

  @override
  Future<ResumeProfile> getProfile(String resumeId) async => _profile;

  @override
  Future<ResumeProfile> updateProfile(ResumeProfile profile) async {
    _profile = profile.copyWith(updatedAt: DateTime.now());
    return _profile;
  }

  @override
  Future<void> deleteResume(String resumeId) async {
    if (_profile.id == resumeId) {
      _profile = _profile.copyWith(fileName: '');
    }
  }
}
