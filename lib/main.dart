import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'features/resume/data/rest_resume_repository.dart';
import 'features/resume/domain/resume_repository.dart';
import 'features/applications/data/rest_application_repository.dart';
import 'features/applications/domain/application_repository.dart';
import 'core/network/api_client.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/auth/domain/auth_repository.dart';
import 'features/workbench/data/rest_job_repository.dart';
import 'features/workbench/domain/job_repository.dart';
import 'features/platform_accounts/data/rest_platform_account_repository.dart';
import 'features/platform_accounts/domain/platform_account_repository.dart';

void main() {
  runApp(const BossJobWorkbenchApp());
}

class BossJobWorkbenchApp extends StatelessWidget {
  const BossJobWorkbenchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BOSS 求职工作台',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF007AFF),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F5F7),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: Color(0xB8FFFFFF),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: const StadiumBorder(),
            side: const BorderSide(color: Color(0x332563EB)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
        ),
        chipTheme: ChipThemeData(
          shape: const StadiumBorder(),
          side: BorderSide.none,
          backgroundColor: const Color(0x0F0A84FF),
          selectedColor: const Color(0x1A0A84FF),
          labelStyle: const TextStyle(fontSize: 12),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xA8FFFFFF),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0x660A84FF), width: 1.2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      home: AuthGate(builder: (context) => WorkbenchPage(
            session: AuthSessionScope.of(context),
            onLogout: () => AuthSessionScope.logout(context),
          )),
    );
  }
}

enum ApplicationStatus {
  ready,
  queued,
  applying,
  submitted,
  failed,
}

extension ApplicationStatusLabel on ApplicationStatus {
  String get label {
    switch (this) {
      case ApplicationStatus.ready:
        return '待投递';
      case ApplicationStatus.queued:
        return '排队中';
      case ApplicationStatus.applying:
        return '投递中';
      case ApplicationStatus.submitted:
        return '已投递';
      case ApplicationStatus.failed:
        return '失败';
    }
  }

  Color get color {
    switch (this) {
      case ApplicationStatus.ready:
        return const Color(0xFF64748B);
      case ApplicationStatus.queued:
        return const Color(0xFF8B5CF6);
      case ApplicationStatus.applying:
        return const Color(0xFF2563EB);
      case ApplicationStatus.submitted:
        return const Color(0xFF059669);
      case ApplicationStatus.failed:
        return const Color(0xFFDC2626);
    }
  }
}

class Job {
  const Job({
    required this.id,
    required this.title,
    required this.company,
    required this.location,
    required this.salary,
    required this.experience,
    required this.education,
    required this.matchScore,
    required this.tags,
    required this.description,
    this.platform = 'BOSS 直聘',
    this.status = ApplicationStatus.ready,
  });

  final String id;
  final String title;
  final String company;
  final String location;
  final String salary;
  final String experience;
  final String education;
  final int matchScore;
  final List<String> tags;
  final String description;
  final String platform;
  final ApplicationStatus status;

  Job copyWith({ApplicationStatus? status}) {
    return Job(
      id: id,
      title: title,
      company: company,
      location: location,
      salary: salary,
      experience: experience,
      education: education,
      matchScore: matchScore,
      tags: tags,
      description: description,
      platform: platform,
      status: status ?? this.status,
    );
  }
}

class WorkbenchController extends ChangeNotifier {
  WorkbenchController()
      : _jobs = _sampleJobs,
        _jobRepository = RestJobRepository(ApiClient()),
        _platformRepository = RestPlatformAccountRepository(ApiClient()) {
    refreshPlatformAccounts();
  }
  final JobRepository _jobRepository;
  final PlatformAccountRepository _platformRepository;
  final ApplicationRepository _applicationRepository =
      RestApplicationRepository(ApiClient());
  DeliveryTask? activeDeliveryTask;
  String? deliveryError;
  String? searchError;

  static const List<Job> _sampleJobs = [
    Job(
      id: 'boss-001',
      title: '高级 Java 开发工程师',
      company: '星河科技',
      location: '上海 · 浦东新区',
      salary: '20-35K · 14薪',
      experience: '3-5年',
      education: '本科',
      matchScore: 96,
      tags: ['Java', 'Spring Boot', '微服务', '大厂经验'],
      description: '负责核心交易系统的设计、开发与性能优化，参与服务治理和技术方案评审。',
    ),
    Job(
      id: 'boss-002',
      title: '后端开发工程师',
      company: '云杉网络',
      location: '上海 · 徐汇区',
      salary: '18-28K · 13薪',
      experience: '3-5年',
      education: '本科',
      matchScore: 91,
      tags: ['Java', 'MySQL', 'Redis', 'Docker'],
      description: '参与 SaaS 平台后端服务建设，负责接口开发、测试和线上问题排查。',
    ),
    Job(
      id: 'boss-003',
      title: 'Java 技术负责人',
      company: '远景数据',
      location: '杭州 · 西湖区',
      salary: '30-45K · 15薪',
      experience: '5-10年',
      education: '本科',
      matchScore: 84,
      tags: ['Java', '架构设计', '团队管理'],
      description: '负责技术团队建设和核心业务架构演进，推动研发质量和交付效率提升。',
    ),
    Job(
      id: 'boss-004',
      title: '全栈开发工程师',
      company: '蓝鲸软件',
      location: '上海 · 闵行区',
      salary: '16-25K · 13薪',
      experience: '1-3年',
      education: '本科',
      matchScore: 78,
      tags: ['Java', 'Vue', 'TypeScript'],
      description: '负责内部管理平台的前后端功能开发，与产品和设计团队协作交付。',
    ),
    Job(
      id: 'zhipin-001',
      title: 'Java 后端工程师',
      company: '智联云科',
      location: '北京 · 海淀区',
      salary: '18-30K · 14薪',
      experience: '3-5年',
      education: '本科',
      matchScore: 89,
      tags: ['Java', 'Spring Cloud', 'MySQL'],
      description: '负责企业服务平台的后端研发与服务治理。',
      platform: '智联招聘',
    ),
    Job(
      id: 'liepin-001',
      title: '资深后端开发工程师',
      company: '猎头科技',
      location: '杭州 · 滨江区',
      salary: '25-40K · 15薪',
      experience: '5-10年',
      education: '本科',
      matchScore: 93,
      tags: ['Java', '分布式', 'Redis'],
      description: '参与核心业务架构设计，推动高并发服务演进。',
      platform: '猎聘',
    ),
    Job(
      id: 'job51-001',
      title: '后端研发工程师',
      company: '五一人才科技',
      location: '广州 · 天河区',
      salary: '15-26K · 13薪',
      experience: '3-5年',
      education: '本科',
      matchScore: 86,
      tags: ['Java', 'Spring Boot', 'Docker'],
      description: '负责业务服务开发、接口设计和线上稳定性建设。',
      platform: '前程无忧',
    ),
    Job(
      id: 'yupao-001',
      title: '技术负责人',
      company: '鱼泡数字化',
      location: '成都 · 高新区',
      salary: '22-35K · 14薪',
      experience: '5-10年',
      education: '本科',
      matchScore: 82,
      tags: ['Java', '架构设计', '团队管理'],
      description: '负责平台技术规划和研发团队协作交付。',
      platform: '鱼泡直聘',
    ),
    Job(
      id: 'guopin-001',
      title: '软件开发工程师',
      company: '国聘数字服务中心',
      location: '深圳 · 南山区',
      salary: '16-24K · 12薪',
      experience: '1-3年',
      education: '本科',
      matchScore: 80,
      tags: ['Java', 'MySQL', '微服务'],
      description: '参与公共服务数字化系统研发和维护。',
      platform: '国聘',
    ),
  ];

  List<Job> _jobs;
  List<String> keywords = ['Java'];
  final List<String> selectedCities = ['上海市'];
  int minSalaryK = 15;
  int maxSalaryK = 35;
  bool onlyHighMatch = false;
  final Set<String> selectedPlatforms = <String>{};
  final Map<String, bool> platformConnections = {
    'BOSS 直聘': false,
    '智联招聘': false,
    '猎聘': false,
    '前程无忧': false,
    '鱼泡直聘': false,
    '国聘': false,
  };
  bool isSearching = false;
  bool isApplying = false;
  DateTime? lastSearchedAt;
  int get selectedCount => visibleJobs
      .where((job) => job.status == ApplicationStatus.ready)
      .length;
  int get submittedCount => _jobs
      .where((job) => job.status == ApplicationStatus.submitted)
      .length;

  List<String> get unconnectedVisiblePlatforms => visibleJobs
      .map((job) => job.platform)
      .where((platform) => !isPlatformConnected(platform))
      .toSet()
      .toList();

  List<Job> get visibleJobs => _jobs.where((job) {
        final keywordMatched = keywords.isEmpty || keywords.any((keyword) {
          return job.title.toLowerCase().contains(keyword.toLowerCase()) ||
              job.tags.any((tag) => tag.toLowerCase().contains(keyword.toLowerCase()));
        });
        final cityMatched = selectedCities.isEmpty || selectedCities.any((city) {
          final normalizedCity = city
              .replaceAll('特别行政区', '')
              .replaceAll('自治区', '')
              .replaceAll('自治州', '')
              .replaceAll('省', '')
              .replaceAll('市', '')
              .replaceAll('地区', '');
          return job.location.contains(normalizedCity);
        });
        final platformMatched = selectedPlatforms.isEmpty || selectedPlatforms.contains(job.platform);
        final salaryMatched = _salaryMatches(job.salary);
        final scoreMatched = !onlyHighMatch || job.matchScore >= 80;
        return keywordMatched && cityMatched && platformMatched && salaryMatched && scoreMatched;
      }).toList();

  bool _salaryMatches(String salaryText) {
    final match = RegExp(r'(\d+)[-~](\d+)').firstMatch(salaryText);
    if (match == null) return true;
    final jobMin = int.tryParse(match.group(1)!) ?? 0;
    final jobMax = int.tryParse(match.group(2)!) ?? 999;
    return jobMax >= minSalaryK && jobMin <= maxSalaryK;
  }

  void addKeyword(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty || keywords.length >= 5 || keywords.contains(normalized)) return;
    keywords = [...keywords, normalized];
    notifyListeners();
  }

  void removeKeyword(String value) {
    if (keywords.length == 1) return;
    keywords = keywords.where((item) => item != value).toList();
    notifyListeners();
  }

  void updateCities(List<String> values) {
    selectedCities
      ..clear()
      ..addAll(values);
    notifyListeners();
  }

  void updateSalaryRange(int min, int max) {
    minSalaryK = min;
    maxSalaryK = max < min ? min : max;
    notifyListeners();
  }

  void updateHighMatch(bool value) {
    onlyHighMatch = value;
    notifyListeners();
  }

  void togglePlatform(String platform) {
    if (selectedPlatforms.contains(platform)) {
      selectedPlatforms.remove(platform);
    } else {
      selectedPlatforms.add(platform);
    }
    notifyListeners();
  }

  bool isPlatformConnected(String platform) => platformConnections[platform] ?? false;

  void setPlatformConnected(String platform, bool connected) {
    platformConnections[platform] = connected;
    if (!connected) selectedPlatforms.remove(platform);
    notifyListeners();
  }

  Future<void> refreshPlatformAccounts() async {
    try {
      final accounts = await _platformRepository.getAccounts();
      for (final account in accounts) {
        platformConnections[account.platform] = account.isConnected;
      }
      notifyListeners();
    } catch (_) {
      // The page remains usable while the API is starting; a later refresh
      // will reconcile the displayed state with the server.
    }
  }

  Future<void> search() async {
    isSearching = true;
    searchError = null;
    notifyListeners();
    try {
      final result = await _jobRepository.search(JobQuery(
        keywords: keywords,
        cities: selectedCities,
        platforms: selectedPlatforms.toList(),
        minSalaryK: minSalaryK,
        maxSalaryK: maxSalaryK,
        onlyHighMatch: onlyHighMatch,
      ));
      _jobs = result.items.map(_jobFromApi).toList();
      lastSearchedAt = DateTime.now();
    } catch (error) {
      searchError = '职位筛选失败，请检查后端服务和平台连接状态';
    }
    isSearching = false;
    notifyListeners();
  }

  Job _jobFromApi(Map<String, dynamic> item) => Job(
        id: item['id'].toString(),
        title: item['title']?.toString() ?? '未命名职位',
        company: item['company']?.toString() ?? '未知公司',
        location: item['location']?.toString() ?? '不限地区',
        salary: item['salary']?.toString() ?? '薪资面议',
        experience: item['experience']?.toString() ?? '经验不限',
        education: item['education']?.toString() ?? '学历不限',
        matchScore: (item['matchScore'] as num?)?.toInt() ?? 0,
        tags: (item['tags'] as List? ?? const []).map((value) => value.toString()).toList(),
        description: item['description']?.toString() ?? '职位详情以招聘平台展示为准。',
        platform: item['platform']?.toString() ?? 'BOSS 直聘',
      );

  Future<void> applyAll() async {
    if (isApplying || selectedCount == 0) return;
    isApplying = true;
    deliveryError = null;
    notifyListeners();
    final jobs = visibleJobs.where((job) => job.status == ApplicationStatus.ready).toList();
    for (final job in jobs) _replace(job.id, job.copyWith(status: ApplicationStatus.queued));
    notifyListeners();
    try {
      var task = await _applicationRepository.createDeliveryTask(
        resumeId: '',
        jobs: jobs.map((job) => DeliveryJob(id: job.id, platform: job.platform, title: job.title, company: job.company)).toList(),
      );
      activeDeliveryTask = task;
      notifyListeners();
      while (task.status != DeliveryTaskStatus.completed &&
          task.status != DeliveryTaskStatus.failed &&
          task.status != DeliveryTaskStatus.partiallyFailed) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        task = await _applicationRepository.getDeliveryTask(task.id);
        activeDeliveryTask = task;
        final completed = task.completed.clamp(0, jobs.length);
        for (var index = 0; index < completed; index++) {
          _replace(jobs[index].id, jobs[index].copyWith(status: ApplicationStatus.submitted));
        }
        if (task.status == DeliveryTaskStatus.running) {
          for (var index = completed; index < jobs.length; index++) {
            _replace(jobs[index].id, jobs[index].copyWith(status: ApplicationStatus.applying));
          }
        }
        notifyListeners();
      }
      if (task.status != DeliveryTaskStatus.completed) {
        deliveryError = task.message ?? '部分职位投递失败';
      }
    } catch (_) {
      deliveryError = '投递任务创建失败，请先导入简历并确认平台已授权';
      for (final job in jobs) _replace(job.id, job.copyWith(status: ApplicationStatus.failed));
    } finally {
      isApplying = false;
      notifyListeners();
    }
  }

  void _replace(String id, Job job) {
    final index = _jobs.indexWhere((item) => item.id == id);
    if (index != -1) {
      _jobs = [..._jobs]..[index] = job;
    }
  }
}

class WorkbenchPage extends StatefulWidget {
  const WorkbenchPage({super.key, required this.session, required this.onLogout});
  final AuthSession session;
  final VoidCallback onLogout;

  @override
  State<WorkbenchPage> createState() => _WorkbenchPageState();
}

class _WorkbenchPageState extends State<WorkbenchPage> {
  final WorkbenchController controller = WorkbenchController();
  int selectedNav = 0;

  @override
  void initState() {
    super.initState();
    // The controller is created before the login gate completes; refresh
    // platform state once the authenticated page is mounted.
    controller.refreshPlatformAccounts();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
      body: Stack(
            children: [
              const _AmbientBackground(),
              Row(
                children: [
                  _NavigationRail(
                    selectedIndex: selectedNav,
                    onSelected: (index) => setState(() => selectedNav = index),
                    onLogout: widget.onLogout,
                  ),
                  Expanded(
                    child: SafeArea(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 1050;
                          return _PageBody(
                            selectedIndex: selectedNav,
                            controller: controller,
                            compact: compact,
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5F5F7), Color(0xFFF0F6FF), Color(0xFFF7F4FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -170,
              right: -90,
              child: _BlurOrb(size: 420, color: Color(0x552E90FA)),
            ),
            Positioned(
              bottom: -210,
              left: 80,
              child: _BlurOrb(size: 500, color: Color(0x443F51B5)),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlurOrb extends StatelessWidget {
  const _BlurOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 65, sigmaY: 65),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.64),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.72)),
            boxShadow: const [
              BoxShadow(color: Color(0x120F172A), blurRadius: 28, offset: Offset(0, 10)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _PageBody extends StatelessWidget {
  const _PageBody({
    required this.selectedIndex,
    required this.controller,
    required this.compact,
  });

  final int selectedIndex;
  final WorkbenchController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = compact ? 20.0 : 42.0;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 28),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 1440,
          // 当内容较短时，整个页面上下居中；内容较长时自然从顶部滚动。
          minHeight: (viewportHeight - 56).clamp(0, double.infinity),
        ),
        // 页面内容始终从顶部开始向下排列；这里只做水平方向居中。
        child: Align(
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _TopBar(),
              const SizedBox(height: 30),
              if (selectedIndex == 0)
                _WorkbenchContent(controller: controller, compact: compact)
              else if (selectedIndex == 1)
                const _ResumePage()
              else if (selectedIndex == 2)
                const _ApplicationsPage()
              else if (selectedIndex == 3)
                const _InterviewsPage()
              else
                _PlatformAccountsPage(controller: controller),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkbenchContent extends StatelessWidget {
  const _WorkbenchContent({required this.controller, required this.compact});

  final WorkbenchController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeroHeader(controller: controller),
        const SizedBox(height: 22),
        _StatsRow(controller: controller),
        const SizedBox(height: 22),
        Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: _FilterPanel(controller: controller),
          ),
        ),
        const SizedBox(height: 22),
        _JobsSection(controller: controller, compact: compact),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle, this.action});

  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(subtitle, style: const TextStyle(color: Color(0xFF64748B))),
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

class _ResumePage extends StatefulWidget {
  const _ResumePage();

  @override
  State<_ResumePage> createState() => _ResumePageState();
}

class _ResumePageState extends State<_ResumePage> {
  final ResumeRepository repository = RestResumeRepository(ApiClient());
  ResumeProfile? profile;
  ResumeParseTask? parseTask;
  bool isImporting = false;
  bool isSaving = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDemoProfile();
  }

  Future<void> _loadDemoProfile() async {
    // There is no global demo profile: each user only sees their own records.
    // The page starts empty and is populated after the user imports a resume.
  }

  Future<void> importResume() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => errorMessage = '无法读取文件内容，请重新选择文件。');
      return;
    }
    setState(() {
      isImporting = true;
      errorMessage = null;
      profile = null;
      parseTask = null;
    });
    try {
      final extension = file.extension?.toLowerCase();
      final contentType = switch (extension) {
        'pdf' => 'application/pdf',
        'doc' => 'application/msword',
        'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        _ => 'application/octet-stream',
      };
      final ticket = await repository.createImport(file.name, contentType);
      if (mounted) {
        setState(() {
          parseTask = ResumeParseTask(taskId: ticket.taskId, status: ResumeParseStatus.uploading, progress: 8, message: '文件已选中，准备上传');
        });
      }
      Future<void>.delayed(const Duration(milliseconds: 450), () {
        if (mounted && isImporting) {
          setState(() => parseTask = ResumeParseTask(taskId: ticket.taskId, status: ResumeParseStatus.parsing, progress: 42, message: '正在识别简历内容'));
        }
      });
      await repository.uploadImport(ticket, bytes);
      var task = await repository.getParseTask(ticket.taskId);
      for (var attempt = 0;
          attempt < 30 &&
              task.status != ResumeParseStatus.needsReview &&
              task.status != ResumeParseStatus.failed;
          attempt++) {
        if (mounted) setState(() => parseTask = task);
        await Future<void>.delayed(const Duration(milliseconds: 450));
        task = await repository.getParseTask(ticket.taskId);
      }
      if (task.status == ResumeParseStatus.failed) {
        throw StateError('resume_parse_failed');
      }
      final parsed = await repository.getProfile(ticket.resumeId);
      if (!mounted) return;
      setState(() {
        parseTask = task;
        profile = parsed;
        isImporting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isImporting = false;
        parseTask = const ResumeParseTask(taskId: 'failed', status: ResumeParseStatus.failed, message: '识别失败，请重试');
        errorMessage = '简历识别失败，请检查文件格式后重试。';
      });
    }
  }

  Future<void> _editBasicInfo() async {
    final current = profile;
    if (current == null) return;
    final name = TextEditingController(text: current.basic.name);
    final phone = TextEditingController(text: current.basic.phone);
    final email = TextEditingController(text: current.basic.email);
    final city = TextEditingController(text: current.basic.city);
    final saved = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('编辑基本信息'),
      content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: '姓名 *')),
        const SizedBox(height: 10),
        TextField(controller: phone, decoration: const InputDecoration(labelText: '手机 *')),
        const SizedBox(height: 10),
        TextField(controller: email, decoration: const InputDecoration(labelText: '邮箱')),
        const SizedBox(height: 10),
        TextField(controller: city, decoration: const InputDecoration(labelText: '所在城市')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('保存'))],
    ));
    if (saved == true && mounted) {
      setState(() => profile = current.copyWith(basic: current.basic.copyWith(name: name.text, phone: phone.text, email: email.text, city: city.text)));
    }
  }

  Future<List<String>?> _editLines(String title, List<String> lines) async {
    final controller = TextEditingController(text: lines.join('\n'));
    return showDialog<List<String>>(context: context, builder: (context) => AlertDialog(
      title: Text('编辑$title'),
      content: SizedBox(width: 500, child: TextField(controller: controller, minLines: 4, maxLines: 9, decoration: const InputDecoration(hintText: '每行一条内容'))),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(context, controller.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()), child: const Text('保存'))],
    ));
  }

  Future<void> _editWork() async {
    final current = profile;
    if (current == null) return;
    final lines = current.workExperiences.map((e) => '${e.company} · ${e.title} · ${e.startDate} - ${e.endDate ?? '至今'}').toList();
    final edited = await _editLines('工作经历', lines);
    if (edited == null || !mounted) return;
    final values = edited.map((line) {
      final parts = line.split('·').map((e) => e.trim()).toList();
      final old = current.workExperiences.isNotEmpty ? current.workExperiences.first : const ResumeWorkExperience(company: '', title: '', startDate: '');
      return ResumeWorkExperience(company: parts.isNotEmpty ? parts[0] : old.company, title: parts.length > 1 ? parts[1] : old.title, startDate: parts.length > 2 ? parts[2].split('-').first.trim() : old.startDate, endDate: parts.length > 2 && parts[2].contains('-') ? parts[2].split('-').last.trim() : old.endDate, description: old.description);
    }).toList();
    setState(() => profile = current.copyWith(workExperiences: values));
  }

  Future<void> _editEducation() async {
    final current = profile;
    if (current == null) return;
    final lines = current.education.map((e) => '${e.school} · ${e.major} · ${e.degree} · ${e.startDate} - ${e.endDate ?? '至今'}').toList();
    final edited = await _editLines('教育背景', lines);
    if (edited == null || !mounted) return;
    final values = edited.map((line) {
      final parts = line.split('·').map((e) => e.trim()).toList();
      final old = current.education.isNotEmpty ? current.education.first : const ResumeEducation(school: '', major: '', degree: '', startDate: '');
      return ResumeEducation(school: parts.isNotEmpty ? parts[0] : old.school, major: parts.length > 1 ? parts[1] : old.major, degree: parts.length > 2 ? parts[2] : old.degree, startDate: parts.length > 3 ? parts[3].split('-').first.trim() : old.startDate, endDate: parts.length > 3 && parts[3].contains('-') ? parts[3].split('-').last.trim() : old.endDate);
    }).toList();
    setState(() => profile = current.copyWith(education: values));
  }

  Future<void> _editSkills() async {
    final current = profile;
    if (current == null) return;
    final edited = await _editLines('技能（每行一项）', current.skills);
    if (edited != null && mounted) setState(() => profile = current.copyWith(skills: edited));
  }

  Future<void> _saveProfile() async {
    final current = profile;
    if (current == null) return;
    setState(() => isSaving = true);
    final updated = await repository.updateProfile(current);
    if (!mounted) return;
    setState(() {
      profile = updated;
      isSaving = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('校对结果已保存')));
  }

  void _previewOriginal() {
    final current = profile;
    if (current == null) return;
    showDialog<void>(context: context, builder: (context) => AlertDialog(
      title: const Text('原文件预览'),
      content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.picture_as_pdf_rounded, size: 52, color: Color(0xFFFF3B30)),
        const SizedBox(height: 14),
        Text(current.fileName, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('真实接入后，这里会展示原始 PDF / Word / 图片文件。当前为前端演示预览。', style: TextStyle(color: Color(0xFF6E6E73))),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭'))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: '我的简历',
          subtitle: '导入后自动识别姓名、联系方式、经历、教育和技能等全部内容。',
          action: FilledButton.icon(onPressed: isImporting ? null : importResume, icon: const Icon(Icons.upload_file_rounded, size: 18), label: Text(isImporting ? '识别中…' : '导入简历')),
        ),
        const SizedBox(height: 24),
        if (isImporting)
          _ParsingResumeCard(task: parseTask)
        else if (profile == null)
          _EmptyResumeCard(onImport: importResume)
        else
          _RecognizedResumeContent(profile: profile!, onImport: importResume, onEditBasic: _editBasicInfo, onEditWork: _editWork, onEditEducation: _editEducation, onEditSkills: _editSkills, onPreview: _previewOriginal, onSave: _saveProfile, isSaving: isSaving),
        if (errorMessage != null) ...[
          const SizedBox(height: 12),
          _InlineNotice(text: errorMessage!, isError: true),
        ],
      ],
    );
  }
}

class _ParsingResumeCard extends StatelessWidget {
  const _ParsingResumeCard({this.task});

  final ResumeParseTask? task;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(42),
      child: Center(child: Column(children: [
        SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 3, value: task == null ? null : task!.progress / 100)),
        const SizedBox(height: 18),
        Text(task?.message ?? '正在识别简历内容', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(task == null ? '文件上传后将自动提取个人信息、工作经历、教育背景、项目和技能。' : '已完成 ${task!.progress}% · 请稍候', style: const TextStyle(color: Color(0xFF6E6E73))),
      ])),
    );
  }
}

class _EmptyResumeCard extends StatelessWidget {
  const _EmptyResumeCard({required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(48),
      child: Center(child: Column(children: [
        const Icon(Icons.description_outlined, size: 48, color: Color(0xFF007AFF)),
        const SizedBox(height: 16),
        const Text('导入一份简历开始识别', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('支持 PDF、Word 和图片格式，系统会自动识别全部内容。', style: TextStyle(color: Color(0xFF6E6E73))),
        const SizedBox(height: 20),
        FilledButton.icon(onPressed: onImport, icon: const Icon(Icons.upload_file_rounded), label: const Text('选择简历文件')),
      ])),
    );
  }
}

class _RecognizedResumeContent extends StatelessWidget {
  const _RecognizedResumeContent({required this.profile, required this.onImport, required this.onEditBasic, required this.onEditWork, required this.onEditEducation, required this.onEditSkills, required this.onPreview, required this.onSave, required this.isSaving});

  final ResumeProfile profile;
  final VoidCallback onImport;
  final VoidCallback onEditBasic;
  final VoidCallback onEditWork;
  final VoidCallback onEditEducation;
  final VoidCallback onEditSkills;
  final VoidCallback onPreview;
  final VoidCallback onSave;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 2, child: _GlassCard(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text('${profile.basic.name ?? '未命名'} · 通用版', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700))), _ResumeStatusBadge(text: '已完成识别', color: const Color(0xFF34C759))]),
            const SizedBox(height: 8),
            Text('${profile.fileName} · 最近识别：${_formatResumeDate(profile.updatedAt)}', style: const TextStyle(color: Color(0xFF6E6E73), fontSize: 13)),
            const SizedBox(height: 20),
            const Text('识别完整度', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: profile.completeness / 100, minHeight: 10, backgroundColor: const Color(0x1A007AFF), color: const Color(0xFF007AFF))),
            const SizedBox(height: 9),
            Text('${profile.completeness} 分 · 已识别 7 个内容模块，建议你校对带 * 的字段', style: const TextStyle(color: Color(0xFF6E6E73), fontSize: 12)),
            const SizedBox(height: 20),
            Wrap(spacing: 7, runSpacing: 7, children: profile.skills.map((tag) => Chip(label: Text(tag))).toList()),
            const SizedBox(height: 17),
            Row(children: [OutlinedButton.icon(onPressed: onImport, icon: const Icon(Icons.refresh_rounded, size: 17), label: const Text('重新导入')), const SizedBox(width: 10), TextButton.icon(onPressed: onPreview, icon: const Icon(Icons.visibility_outlined, size: 17), label: const Text('预览原文件'))]),
          ]))),
          const SizedBox(width: 16),
          Expanded(child: _GlassCard(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('识别摘要', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _ResumeSummaryRow(icon: Icons.person_outline_rounded, label: '基本信息', value: '姓名、电话、邮箱'),
            _ResumeSummaryRow(icon: Icons.work_outline_rounded, label: '工作经历', value: '${profile.workExperiences.length} 段经历'),
            _ResumeSummaryRow(icon: Icons.school_outlined, label: '教育背景', value: profile.education.isEmpty ? '未识别' : profile.education.first.degree),
            _ResumeSummaryRow(icon: Icons.folder_open_outlined, label: '项目经历', value: '${profile.projects.length} 个项目'),
            _ResumeSummaryRow(icon: Icons.workspace_premium_outlined, label: '证书技能', value: '${profile.skills.length} 项技能'),
          ]))),
        ]),
        const SizedBox(height: 16),
        _GlassCard(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Expanded(child: Text('识别后的内容', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))), OutlinedButton.icon(onPressed: isSaving ? null : onSave, icon: const Icon(Icons.save_outlined, size: 17), label: Text(isSaving ? '保存中…' : '保存校对结果'))]),
          const SizedBox(height: 10),
          const Text('以下内容来自导入文件，点击编辑即可校对或补充。系统不会自动改写你的经历。', style: TextStyle(color: Color(0xFF6E6E73), fontSize: 12)),
          const SizedBox(height: 18),
          _ResumeDataSection(title: '基本信息', icon: Icons.person_outline_rounded, children: ['姓名：${profile.basic.name ?? '待补充'} *', '手机：${profile.basic.phone ?? '待补充'} *', '邮箱：${profile.basic.email ?? '待补充'}', '所在城市：${profile.basic.city ?? '待补充'}'], onEdit: onEditBasic),
          _ResumeDataSection(title: '工作经历', icon: Icons.work_outline_rounded, children: profile.workExperiences.map((item) => '${item.company} · ${item.title} · ${item.startDate} - ${item.endDate ?? '至今'}').toList(), onEdit: onEditWork),
          _ResumeDataSection(title: '教育背景', icon: Icons.school_outlined, children: profile.education.map((item) => '${item.school} · ${item.major} · ${item.degree} · ${item.startDate} - ${item.endDate ?? '至今'}').toList(), onEdit: onEditEducation),
          _ResumeDataSection(title: '项目与技能', icon: Icons.code_rounded, children: [profile.projects.map((item) => item.name).join('、'), profile.skills.join('、')], onEdit: onEditSkills),
        ])),
      ],
    );
  }
}

class _ResumeStatusBadge extends StatelessWidget {
  const _ResumeStatusBadge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)), child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)));
}

class _ResumeSummaryRow extends StatelessWidget {
  const _ResumeSummaryRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 14), child: Row(children: [Icon(icon, size: 19, color: const Color(0xFF007AFF)), const SizedBox(width: 10), Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))), Text(value, style: const TextStyle(color: Color(0xFF6E6E73), fontSize: 12))]));
}

class _ResumeDataSection extends StatelessWidget {
  const _ResumeDataSection({required this.title, required this.icon, required this.children, this.onEdit});

  final String title;
  final IconData icon;
  final List<String> children;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0x66FFFFFF), borderRadius: BorderRadius.circular(17)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 19, color: const Color(0xFF007AFF)), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 7), ...children.map((item) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(item, style: const TextStyle(color: Color(0xFF6E6E73), fontSize: 13))))])), TextButton(onPressed: onEdit, child: const Text('编辑'))]));
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.text, this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: (isError ? const Color(0xFFFF3B30) : const Color(0xFF34C759)).withOpacity(0.1), borderRadius: BorderRadius.circular(14)), child: Row(children: [Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, size: 18, color: isError ? const Color(0xFFFF3B30) : const Color(0xFF34C759)), const SizedBox(width: 8), Expanded(child: Text(text, style: TextStyle(color: isError ? const Color(0xFFC62828) : const Color(0xFF237A3B), fontSize: 13)))]));
}

String _formatResumeDate(DateTime date) => '${date.month}月${date.day}日 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

class _ApplicationsPage extends StatefulWidget {
  const _ApplicationsPage();

  @override
  State<_ApplicationsPage> createState() => _ApplicationsPageState();
}

class _ApplicationsPageState extends State<_ApplicationsPage> {
  final ApplicationRepository repository = RestApplicationRepository(ApiClient());
  ApplicationDashboard? dashboard;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final result = await repository.getDashboard();
    if (!mounted) return;
    setState(() {
      dashboard = result;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = dashboard;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: '投递记录',
          subtitle: '按平台、按日期查看实际投递数量和转化表现。',
          action: Row(children: [OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('刷新统计')), const SizedBox(width: 10), OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.download_outlined, size: 18), label: const Text('导出记录'))]),
        ),
        const SizedBox(height: 24),
        if (loading || data == null)
          const _ApplicationLoadingCard()
        else ...[
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _ApplicationMetric(label: '每日投递', value: '按平台', caption: '下方查看每天各平台数量', color: const Color(0xFF0A84FF)),
            _ApplicationMetric(label: '本周可投职位', value: '${data.totalAvailable}', caption: '覆盖 6 个渠道', color: const Color(0xFF8B5CF6)),
            _ApplicationMetric(label: '招聘方查看', value: '${data.viewed}', caption: '${_percent(data.viewed, data.weekTotal)} 查看率', color: const Color(0xFF059669)),
            _ApplicationMetric(label: '收到回复', value: '${data.replied}', caption: '${_percent(data.replied, data.weekTotal)} 回复率', color: const Color(0xFFF59E0B)),
          ],
        ),
        const SizedBox(height: 18),
        _ApplicationChannelTable(channels: data.channels),
        const SizedBox(height: 18),
        _ApplicationDailyTable(daily: data.daily),
        const SizedBox(height: 18),
        _GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Padding(padding: EdgeInsets.fromLTRB(22, 16, 22, 8), child: Text('最近投递', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))), ...data.recent.map((item) => _ApplicationRow(record: item))]),
        ),
        ],
      ],
    );
  }
}

class _ApplicationLoadingCard extends StatelessWidget {
  const _ApplicationLoadingCard();
  @override
  Widget build(BuildContext context) => const _GlassCard(padding: EdgeInsets.all(36), child: Center(child: CircularProgressIndicator()));
}

class _ApplicationChannelTable extends StatelessWidget {
  const _ApplicationChannelTable({required this.channels});
  final List<ChannelApplicationStat> channels;
  @override
  Widget build(BuildContext context) => _GlassCard(padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('渠道累计统计', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)), const SizedBox(height: 6), const Text('各平台累计可投职位、已投数量和投递率；每日明细见下方', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)), const SizedBox(height: 16), ...channels.map((item) => Padding(padding: const EdgeInsets.only(bottom: 14), child: Row(children: [SizedBox(width: 92, child: Text(item.platform, style: const TextStyle(fontWeight: FontWeight.w600))), Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: item.rate, minHeight: 9, backgroundColor: const Color(0x12007AFF), color: const Color(0xFF007AFF)))), const SizedBox(width: 14), SizedBox(width: 120, child: Text('${item.submitted} / ${item.available}  ·  ${_percent(item.submitted, item.available)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))))])))]));
}

class _ApplicationDailyTable extends StatelessWidget {
  const _ApplicationDailyTable({required this.daily});
  final List<DailyApplicationStat> daily;
  @override
  Widget build(BuildContext context) {
    final dates = daily.map((item) => item.date).toSet().toList();
    final platforms = daily.map((item) => item.platform).toSet().toList();
    return _GlassCard(padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('每日投递（按平台）', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)), const SizedBox(height: 6), const Text('只记录每天每个平台实际投递了多少份，不汇总每日总量', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)), const SizedBox(height: 14), SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columnSpacing: 28, headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF475569)), columns: [const DataColumn(label: Text('日期')), ...platforms.map((platform) => DataColumn(label: Text(platform)))], rows: dates.map((date) => DataRow(cells: [DataCell(Text(_dateLabel(date))), ...platforms.map((platform) { final item = daily.firstWhere((entry) => entry.date == date && entry.platform == platform); return DataCell(Text('${item.submitted} 份', style: const TextStyle(fontSize: 12))); })])).toList()))]));
  }
}

String _percent(int value, int total) => total == 0 ? '0%' : '${(value / total * 100).toStringAsFixed(1)}%';
String _dateLabel(DateTime date) => '${date.month}/${date.day}';

class _ApplicationMetric extends StatelessWidget {
  const _ApplicationMetric({required this.label, required this.value, required this.caption, required this.color});

  final String label;
  final String value;
  final String caption;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: _GlassCard(
        padding: const EdgeInsets.all(19),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.w700)),
          Text(caption, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
        ]),
      ),
    );
  }
}

class _ApplicationRow extends StatelessWidget {
  const _ApplicationRow({required this.record});

  final ApplicationRecord record;

  String get statusLabel {
    switch (record.status) {
      case ApplicationDeliveryStatus.queued: return '排队中';
      case ApplicationDeliveryStatus.submitting: return '投递中';
      case ApplicationDeliveryStatus.submitted: return '已投递';
      case ApplicationDeliveryStatus.viewed: return '已查看';
      case ApplicationDeliveryStatus.replied: return '已回复';
      case ApplicationDeliveryStatus.failed: return '失败';
    }
  }

  Color get statusColor {
    switch (record.status) {
      case ApplicationDeliveryStatus.queued: return const Color(0xFF8B5CF6);
      case ApplicationDeliveryStatus.submitting: return const Color(0xFF2563EB);
      case ApplicationDeliveryStatus.submitted: return const Color(0xFF059669);
      case ApplicationDeliveryStatus.viewed: return const Color(0xFF2563EB);
      case ApplicationDeliveryStatus.replied: return const Color(0xFFD97706);
      case ApplicationDeliveryStatus.failed: return const Color(0xFFDC2626);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
      child: Row(
        children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: const Color(0x120A84FF), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.business_rounded, color: Color(0xFF0A84FF), size: 20)),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(record.title, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 3), Text('${record.company} · ${record.platform}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12))])),
          Text(_dateLabel(record.submittedAt), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
          const SizedBox(width: 18),
          Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
        ],
      ),
    );
  }
}

class _InterviewsPage extends StatelessWidget {
  const _InterviewsPage();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: '面试管理', subtitle: '记录面试安排、准备事项和后续跟进。', action: FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.add_rounded, size: 18), label: const Text('添加面试'))),
        const SizedBox(height: 24),
        _GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('即将到来的面试', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 18),
              _InterviewItem(day: '03', month: '九月', title: '高级 Java 开发工程师', company: '星河科技', time: '周四 14:00 · 视频面试', color: const Color(0xFF0A84FF)),
              const Divider(height: 28),
              _InterviewItem(day: '06', month: '九月', title: '后端开发工程师', company: '云杉网络', time: '周日 10:30 · 现场面试', color: const Color(0xFF8B5CF6)),
              const SizedBox(height: 10),
              const Text('提示：建议提前 15 分钟准备，系统会在面试前一天提醒你。', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

class _InterviewItem extends StatelessWidget {
  const _InterviewItem({required this.day, required this.month, required this.title, required this.company, required this.time, required this.color});

  final String day;
  final String month;
  final String title;
  final String company;
  final String time;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 54,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
          child: Column(children: [Text(month, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)), Text(day, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w700))]),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text(company, style: const TextStyle(color: Color(0xFF334155), fontSize: 13)), const SizedBox(height: 4), Text(time, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12))])),
        OutlinedButton(onPressed: () {}, child: const Text('准备')),
      ],
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.index});

  final int index;

  static const titles = ['工作台', '我的简历', '投递记录', '面试管理'];
  static const subtitles = [
    '',
    '统一管理你的简历版本，针对不同职位快速切换。',
    '集中查看所有投递任务、投递状态和招聘方反馈。',
    '记录面试安排、面试准备和后续跟进事项。',
  ];
  static const icons = [
    Icons.grid_view_rounded,
    Icons.description_outlined,
    Icons.send_outlined,
    Icons.calendar_month_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titles[index], style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(subtitles[index], style: const TextStyle(color: Color(0xFF64748B))),
        const SizedBox(height: 24),
        _GlassCard(
          padding: const EdgeInsets.all(42),
          child: Center(
              child: Column(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(icons[index], color: const Color(0xFF2563EB), size: 32),
                  ),
                  const SizedBox(height: 18),
                  Text('${titles[index]}模块', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  const Text('前端页面骨架已准备好，下一步接入后端数据和真实业务流程。', style: TextStyle(color: Color(0xFF64748B))),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.construction_outlined, size: 18),
                    label: const Text('即将完善'),
                  ),
                ],
              ),
          ),
        ),
      ],
    );
  }
}

class _PlatformAccountsPage extends StatefulWidget {
  const _PlatformAccountsPage({required this.controller});

  final WorkbenchController controller;

  @override
  State<_PlatformAccountsPage> createState() => _PlatformAccountsPageState();
}

class _PlatformAccountsPageState extends State<_PlatformAccountsPage> {
  late final PlatformAccountRepository repository =
      RestPlatformAccountRepository(ApiClient());
  bool loading = false;

  WorkbenchController get controller => widget.controller;

  static const platforms = [
    ('BOSS 直聘', 'https://www.zhipin.com/', Icons.work_outline_rounded),
    ('智联招聘', 'https://www.zhaopin.com/', Icons.business_center_outlined),
    ('猎聘', 'https://www.liepin.com/', Icons.radar_outlined),
    ('前程无忧', 'https://www.51job.com/', Icons.explore_outlined),
    ('鱼泡直聘', 'https://www.yupao.com/', Icons.water_drop_outlined),
    ('国聘', 'https://www.iguopin.com/', Icons.account_balance_outlined),
  ];

  Future<void> _connect(BuildContext context, String name, String url) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: Text('连接$name'),
      content: Text('将打开$name官方页面完成登录或授权。平台账号凭证不会交给本应用，连接状态由官方授权结果确认。'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('打开官方页面'))],
    ));
    if (confirmed != true) return;
    String authorizationUrl = url;
    try {
      setState(() => loading = true);
      authorizationUrl = await repository.beginAuthorization(name);
    } catch (_) {
      // Until an official OAuth adapter is configured, retain the safe
      // fallback to the platform's public login page.
    } finally {
      if (mounted) setState(() => loading = false);
    }
    final launched = await launchUrl(Uri.parse(authorizationUrl), mode: LaunchMode.externalApplication);
    if (!context.mounted) return;
    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('无法打开$name官方页面')));
      return;
    }
    final linked = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: Text('$name登录完成了吗？'),
      content: const Text('请在官方页面完成登录。完成后回到这里，点击“已完成登录”，后续将通过官方授权接口同步职位。'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('稍后再说')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('已完成登录'))],
    ));
    if (linked == true) {
      try {
        // The current demo callback accepts the authorization state returned
        // by the backend. Production adapters will redirect here directly.
        final state = Uri.tryParse(authorizationUrl)?.queryParameters['state'];
        if (state != null && state.isNotEmpty) {
          await repository.completeAuthorization(state);
        }
      } catch (_) {
        // Keep the account disconnected when the official callback has not
        // completed; never pretend a local click is a successful authorization.
      }
      await controller.refreshPlatformAccounts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionHeader(title: '平台账号', subtitle: '连接招聘平台后，工作台才会显示对应平台的职位筛选结果。'),
      const SizedBox(height: 24),
      _GlassCard(padding: const EdgeInsets.all(20), child: Row(children: [const Icon(Icons.lock_outline_rounded, color: Color(0xFF007AFF)), const SizedBox(width: 12), const Expanded(child: Text('安全提示：登录始终在招聘平台官方页面完成。本应用不读取、不复制第三方 Cookie，也不会保存你的密码。', style: TextStyle(color: Color(0xFF475569,)))), TextButton(onPressed: () {}, child: const Text('了解更多'))])),
      const SizedBox(height: 16),
      Wrap(spacing: 14, runSpacing: 14, children: platforms.map((item) {
        final connected = controller.isPlatformConnected(item.$1);
        return SizedBox(width: 310, child: _GlassCard(padding: const EdgeInsets.all(18), child: Row(children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: connected ? const Color(0x1A34C759) : const Color(0x12007AFF), borderRadius: BorderRadius.circular(14)), child: Icon(item.$3, color: connected ? const Color(0xFF34C759) : const Color(0xFF007AFF))), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.$1, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text(connected ? '已连接 · 可筛选职位' : '未连接', style: TextStyle(fontSize: 12, color: connected ? const Color(0xFF248A3D) : const Color(0xFF8E8E93)))])), connected ? IconButton(onPressed: loading ? null : () async { await repository.disconnect(item.$1); await controller.refreshPlatformAccounts(); }, icon: const Icon(Icons.link_off_rounded, size: 19)) : OutlinedButton(onPressed: loading ? null : () => _connect(context, item.$1, item.$2), child: const Text('登录连接'))])));
      }).toList()),
    ]);
  }
}

class _NavigationRail extends StatelessWidget {
  const _NavigationRail({required this.selectedIndex, required this.onSelected, required this.onLogout});

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.grid_view_rounded, '工作台'),
      (Icons.description_outlined, '我的简历'),
      (Icons.send_outlined, '投递记录'),
      (Icons.calendar_month_outlined, '面试管理'),
      (Icons.account_balance_wallet_outlined, '平台账号'),
    ];
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          width: 88,
          decoration: const BoxDecoration(
            color: Color(0xB8FFFFFF),
            border: Border(right: BorderSide(color: Color(0x22000000))),
          ),
          child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.bolt_rounded, color: Colors.white),
          ),
          const SizedBox(height: 42),
          ...items.asMap().entries.map((entry) {
            final active = entry.key == selectedIndex;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: InkWell(
                onTap: () => onSelected(entry.key),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 58,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: active ? const Color(0x14007AFF) : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Icon(entry.value.$1, color: active ? const Color(0xFF007AFF) : const Color(0xFF8E8E93)),
                      const SizedBox(height: 5),
                      Text(
                        entry.value.$2,
                        style: TextStyle(
                          color: active ? const Color(0xFF007AFF) : const Color(0xFF8E8E93),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          IconButton(
            tooltip: '退出登录',
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded, color: Color(0xFF8E8E93)),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF8E8E93)),
          ),
          const SizedBox(height: 20),
        ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('早上好，张三', style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
              SizedBox(height: 4),
              Text('找到更适合你的机会', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded)),
        const SizedBox(width: 8),
        CircleAvatar(
          radius: 19,
          backgroundColor: const Color(0xFFDBEAFE),
          child: Text('张', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.controller});

  final WorkbenchController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xE6FFFFFF), Color(0xD6EEF5FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.86)),
        boxShadow: const [BoxShadow(color: Color(0x16007AFF), blurRadius: 28, offset: Offset(0, 12))],
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('BOSS 直聘职位工作台', style: TextStyle(color: Color(0xFF1D1D1F), fontSize: 23, fontWeight: FontWeight.w700)),
                SizedBox(height: 9),
                Text('先筛选，再投递。让每一份简历都更匹配。', style: TextStyle(color: Color(0xFF6E6E73), fontSize: 14)),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: controller.isSearching ? null : controller.search,
            icon: controller.isSearching
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.search_rounded),
            label: Text(controller.isSearching ? '筛选中…' : '开始筛选'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF007AFF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.controller});

  final WorkbenchController controller;

  @override
  Widget build(BuildContext context) {
    final stats = [
      ('匹配职位', '${controller.visibleJobs.length}', Icons.track_changes_rounded, const Color(0xFF2563EB)),
      ('待投递', '${controller.selectedCount}', Icons.schedule_send_rounded, const Color(0xFF8B5CF6)),
      ('已投递', '${controller.submittedCount}', Icons.check_circle_outline_rounded, const Color(0xFF059669)),
      ('平均匹配度', '87%', Icons.auto_awesome_rounded, const Color(0xFFF59E0B)),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 36) / 4;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: stats.map((stat) {
            return SizedBox(
              width: width.clamp(190, 340).toDouble(),
              child: _StatCard(title: stat.$1, value: stat.$2, icon: stat.$3, color: stat.$4),
            );
          }).toList(),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(18),
      child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: color.withOpacity(0.11), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 13),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                const SizedBox(height: 3),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 21)),
              ],
            ),
          ],
      ),
    );
  }
}

class _FilterPanel extends StatefulWidget {
  const _FilterPanel({required this.controller});

  final WorkbenchController controller;

  @override
  State<_FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<_FilterPanel> {
  late final TextEditingController keywordController;
  late final TextEditingController minSalaryController;
  late final TextEditingController maxSalaryController;

  @override
  void initState() {
    super.initState();
    keywordController = TextEditingController();
    minSalaryController = TextEditingController(text: '${widget.controller.minSalaryK}');
    maxSalaryController = TextEditingController(text: '${widget.controller.maxSalaryK}');
  }

  @override
  void didUpdateWidget(covariant _FilterPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    keywordController.dispose();
    minSalaryController.dispose();
    maxSalaryController.dispose();
    super.dispose();
  }

  Future<void> _togglePlatform(String platform) async {
    final controller = widget.controller;
    if (controller.isPlatformConnected(platform)) {
      controller.togglePlatform(platform);
      return;
    }
    final links = {
      'BOSS 直聘': 'https://www.zhipin.com/',
      '智联招聘': 'https://www.zhaopin.com/',
      '猎聘': 'https://www.liepin.com/',
      '前程无忧': 'https://www.51job.com/',
      '鱼泡直聘': 'https://www.yupao.com/',
      '国聘': 'https://www.iguopin.com/',
    };
    final open = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: Text('先连接$platform'),
      content: Text('筛选$platform职位前，需要先在$platform官方页面登录或授权。我们不会读取或复制平台 Cookie。'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('打开官方页面'))],
    ));
    if (open != true) return;
    await launchUrl(Uri.parse(links[platform]!), mode: LaunchMode.externalApplication);
    if (!mounted) return;
    final done = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: Text('$platform登录完成了吗？'), content: const Text('完成官方登录后回到这里，点击“已完成登录”即可启用筛选。'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('稍后')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('已完成登录'))]));
    if (done == true) {
      controller.setPlatformConnected(platform, true);
      controller.togglePlatform(platform);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return _GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('筛选条件', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 300,
                child: TextField(
                  controller: keywordController,
                  onSubmitted: (value) {
                    controller.addKeyword(value);
                    keywordController.clear();
                  },
                  decoration: InputDecoration(
                    labelText: '添加职位关键词（最多 5 个）',
                    hintText: controller.keywords.length >= 5 ? '已达到 5 个关键词上限' : '输入后按回车添加',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(onPressed: () { controller.addKeyword(keywordController.text); keywordController.clear(); }, icon: const Icon(Icons.add_rounded)),
                    isDense: true,
                  ),
                ),
              ),
              _CitySelector(controller: controller),
              _SalarySelector(controller: controller),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: controller.keywords.map((keyword) => InputChip(label: Text(keyword), onDeleted: controller.keywords.length > 1 ? () => controller.removeKeyword(keyword) : null)).toList(),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
            FilterChip(
              label: const Text('只看高匹配'),
              selected: controller.onlyHighMatch,
              onSelected: controller.updateHighMatch,
              avatar: Icon(Icons.auto_awesome, size: 16, color: controller.onlyHighMatch ? Colors.white : const Color(0xFF8E8E93)),
              selectedColor: const Color(0xFF007AFF),
              backgroundColor: const Color(0xFFE5E5EA),
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(color: controller.onlyHighMatch ? Colors.white : const Color(0xFF6E6E73)),
            ),
            ...['BOSS 直聘', '智联招聘', '猎聘', '前程无忧', '鱼泡直聘', '国聘'].map((platform) {
              final active = controller.selectedPlatforms.contains(platform);
              return FilterChip(
                avatar: Icon(Icons.business_center_outlined, size: 16, color: active ? Colors.white : const Color(0xFF8E8E93)),
                label: Text(platform),
                selected: active,
                onSelected: (_) => _togglePlatform(platform),
                selectedColor: const Color(0xFF007AFF),
                backgroundColor: const Color(0xFFE5E5EA),
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(color: active ? Colors.white : const Color(0xFF6E6E73)),
              );
            }),
            ],
          ),
        ],
      ),
    );
  }
}

class _JobsSection extends StatelessWidget {
  const _JobsSection({required this.controller, required this.compact});

  final WorkbenchController controller;
  final bool compact;

  Future<void> _startDelivery(BuildContext context) async {
    final missing = controller.unconnectedVisiblePlatforms;
    if (missing.isNotEmpty) {
      await showDialog<void>(context: context, builder: (context) => AlertDialog(
        title: const Text('请先连接招聘平台'),
        content: Text('当前结果包含尚未连接的平台：${missing.join('、')}。请先在左侧“平台账号”完成官方登录授权，再开始一键投递。'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('知道了'))],
      ));
      return;
    }
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: Text('确认一键投递 ${controller.selectedCount} 份？'),
      content: const Text('系统将使用当前筛选结果和已确认的简历，按平台授权逐条提交。投递过程中可以暂停任务。'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('开始投递'))],
    ));
    if (confirmed == true) controller.applyAll();
  }

  @override
  Widget build(BuildContext context) {
    final jobs = controller.visibleJobs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('为你筛选的职位', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19)),
                  SizedBox(height: 4),
                  Text('已按简历匹配度、地区和薪资要求排序', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: controller.isApplying || controller.selectedCount == 0 ? null : () => _startDelivery(context),
              icon: controller.isApplying
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(controller.isApplying ? '一键投递中…' : '一键投递 ${controller.selectedCount} 份'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13)),
            ),
          ],
        ),
        const SizedBox(height: 15),
        if (controller.deliveryError != null) ...[
          _InlineNotice(text: controller.deliveryError!, isError: true),
          const SizedBox(height: 12),
        ],
        if (controller.activeDeliveryTask != null && controller.isApplying)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '任务进度：${controller.activeDeliveryTask!.completed}/${controller.activeDeliveryTask!.total}，${controller.activeDeliveryTask!.message ?? '正在处理'}',
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
          ),
        if (jobs.isEmpty)
          const _GlassCard(padding: EdgeInsets.all(30), child: Center(child: Text('没有符合当前条件的职位')))
        else if (compact)
          Column(children: jobs.map((job) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _JobCard(job: job))).toList())
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 520,
              mainAxisExtent: 248,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemCount: jobs.length,
            itemBuilder: (context, index) => _JobCard(job: jobs[index]),
          ),
      ],
    );
  }
}

class _CitySelector extends StatelessWidget {
  const _CitySelector({required this.controller});

  final WorkbenchController controller;

  static const Map<String, List<String>> regions = {
    '北京市': ['北京市'],
    '天津市': ['天津市'],
    '河北省': ['石家庄市', '唐山市', '秦皇岛市', '邯郸市', '邢台市', '保定市', '张家口市', '承德市', '沧州市', '廊坊市', '衡水市'],
    '山西省': ['太原市', '大同市', '阳泉市', '长治市', '晋城市', '朔州市', '晋中市', '运城市', '忻州市', '临汾市', '吕梁市'],
    '内蒙古自治区': ['呼和浩特市', '包头市', '乌海市', '赤峰市', '通辽市', '鄂尔多斯市', '呼伦贝尔市', '巴彦淖尔市', '乌兰察布市'],
    '辽宁省': ['沈阳市', '大连市', '鞍山市', '抚顺市', '本溪市', '丹东市', '锦州市', '营口市', '阜新市', '辽阳市', '盘锦市', '铁岭市', '朝阳市', '葫芦岛市'],
    '吉林省': ['长春市', '吉林市', '四平市', '辽源市', '通化市', '白山市', '松原市', '白城市', '延边朝鲜族自治州'],
    '黑龙江省': ['哈尔滨市', '齐齐哈尔市', '鸡西市', '鹤岗市', '双鸭山市', '大庆市', '伊春市', '佳木斯市', '七台河市', '牡丹江市', '黑河市', '绥化市', '大兴安岭地区'],
    '上海市': ['上海市'],
    '江苏省': ['南京市', '无锡市', '徐州市', '常州市', '苏州市', '南通市', '连云港市', '淮安市', '盐城市', '扬州市', '镇江市', '泰州市', '宿迁市'],
    '浙江省': ['杭州市', '宁波市', '温州市', '嘉兴市', '湖州市', '绍兴市', '金华市', '衢州市', '舟山市', '台州市', '丽水市'],
    '安徽省': ['合肥市', '芜湖市', '蚌埠市', '淮南市', '马鞍山市', '淮北市', '铜陵市', '安庆市', '黄山市', '滁州市', '阜阳市', '宿州市', '六安市', '亳州市', '池州市', '宣城市'],
    '福建省': ['福州市', '厦门市', '莆田市', '三明市', '泉州市', '漳州市', '南平市', '龙岩市', '宁德市'],
    '江西省': ['南昌市', '景德镇市', '萍乡市', '九江市', '新余市', '鹰潭市', '赣州市', '吉安市', '宜春市', '抚州市', '上饶市'],
    '山东省': ['济南市', '青岛市', '淄博市', '枣庄市', '东营市', '烟台市', '潍坊市', '济宁市', '泰安市', '威海市', '日照市', '临沂市', '德州市', '聊城市', '滨州市', '菏泽市'],
    '河南省': ['郑州市', '开封市', '洛阳市', '平顶山市', '安阳市', '鹤壁市', '新乡市', '焦作市', '濮阳市', '许昌市', '漯河市', '三门峡市', '南阳市', '商丘市', '信阳市', '周口市', '驻马店市'],
    '湖北省': ['武汉市', '黄石市', '十堰市', '宜昌市', '襄阳市', '鄂州市', '荆门市', '孝感市', '荆州市', '黄冈市', '咸宁市', '随州市', '恩施土家族苗族自治州'],
    '湖南省': ['长沙市', '株洲市', '湘潭市', '衡阳市', '邵阳市', '岳阳市', '常德市', '张家界市', '益阳市', '郴州市', '永州市', '怀化市', '娄底市', '湘西土家族苗族自治州'],
    '广东省': ['广州市', '深圳市', '珠海市', '汕头市', '佛山市', '韶关市', '湛江市', '肇庆市', '江门市', '茂名市', '惠州市', '梅州市', '汕尾市', '河源市', '阳江市', '清远市', '东莞市', '中山市', '潮州市', '揭阳市', '云浮市'],
    '广西壮族自治区': ['南宁市', '柳州市', '桂林市', '梧州市', '北海市', '防城港市', '钦州市', '贵港市', '玉林市', '百色市', '贺州市', '河池市', '来宾市', '崇左市'],
    '海南省': ['海口市', '三亚市', '三沙市', '儋州市'],
    '重庆市': ['重庆市'],
    '四川省': ['成都市', '自贡市', '攀枝花市', '泸州市', '德阳市', '绵阳市', '广元市', '遂宁市', '内江市', '乐山市', '南充市', '眉山市', '宜宾市', '广安市', '达州市', '雅安市', '巴中市', '资阳市', '阿坝藏族羌族自治州', '甘孜藏族自治州', '凉山彝族自治州'],
    '贵州省': ['贵阳市', '六盘水市', '遵义市', '安顺市', '毕节市', '铜仁市', '黔西南布依族苗族自治州', '黔东南苗族侗族自治州', '黔南布依族苗族自治州'],
    '云南省': ['昆明市', '曲靖市', '玉溪市', '保山市', '昭通市', '丽江市', '普洱市', '临沧市', '楚雄彝族自治州', '红河哈尼族彝族自治州', '文山壮族苗族自治州', '西双版纳傣族自治州', '大理白族自治州', '德宏傣族景颇族自治州', '怒江傈僳族自治州', '迪庆藏族自治州'],
    '西藏自治区': ['拉萨市', '日喀则市', '昌都市', '林芝市', '山南市', '那曲市', '阿里地区'],
    '陕西省': ['西安市', '铜川市', '宝鸡市', '咸阳市', '渭南市', '延安市', '汉中市', '榆林市', '安康市', '商洛市'],
    '甘肃省': ['兰州市', '嘉峪关市', '金昌市', '白银市', '天水市', '武威市', '张掖市', '平凉市', '酒泉市', '庆阳市', '定西市', '陇南市', '临夏回族自治州', '甘南藏族自治州'],
    '青海省': ['西宁市', '海东市', '海北藏族自治州', '黄南藏族自治州', '海南藏族自治州', '果洛藏族自治州', '玉树藏族自治州', '海西蒙古族藏族自治州'],
    '宁夏回族自治区': ['银川市', '石嘴山市', '吴忠市', '固原市', '中卫市'],
    '新疆维吾尔自治区': ['乌鲁木齐市', '克拉玛依市', '吐鲁番市', '哈密市', '昌吉回族自治州', '博尔塔拉蒙古自治州', '巴音郭楞蒙古自治州', '阿克苏地区', '克孜勒苏柯尔克孜自治州', '喀什地区', '和田地区', '伊犁哈萨克自治州', '塔城地区', '阿勒泰地区'],
    '香港特别行政区': ['香港特别行政区'],
    '澳门特别行政区': ['澳门特别行政区'],
    '台湾省': ['台北市', '新北市', '桃园市', '台中市', '台南市', '高雄市', '基隆市', '新竹市', '嘉义市'],
  };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showRegionDialog(context),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 260,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(color: const Color(0xA8FFFFFF), borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            const Icon(Icons.location_on_outlined, size: 19, color: Color(0xFF007AFF)),
            const SizedBox(width: 9),
            Expanded(child: Text(controller.selectedCities.isEmpty ? '选择省市（全国）' : controller.selectedCities.join('、'), overflow: TextOverflow.ellipsis)),
            const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF8E8E93)),
          ],
        ),
      ),
    );
  }

  void _showRegionDialog(BuildContext context) {
    var selectedProvince = regions.keys.firstWhere(
      (province) => controller.selectedCities.any((city) => regions[province]!.contains(city)),
      orElse: () => '北京市',
    );
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          final cities = regions[selectedProvince]!;
          return AlertDialog(
            title: const Text('选择工作城市'),
            content: SizedBox(
              width: 690,
              height: 470,
              child: Row(
                children: [
                  SizedBox(
                    width: 190,
                    child: ListView(
                      children: regions.keys.map((province) {
                        final active = province == selectedProvince;
                        return ListTile(
                          dense: true,
                          selected: active,
                          selectedTileColor: const Color(0x14007AFF),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          title: Text(province),
                          onTap: () => setState(() => selectedProvince = province),
                        );
                      }).toList(),
                    ),
                  ),
                  const VerticalDivider(width: 24),
                  Expanded(
                    child: ListView(
                      children: [
                        Text(selectedProvince, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 10),
                        ...cities.map((city) => CheckboxListTile(
                              dense: true,
                              controlAffinity: ListTileControlAffinity.leading,
                              value: controller.selectedCities.contains(city),
                              title: Text(city),
                              onChanged: (checked) {
                                final next = [...controller.selectedCities];
                                if (checked == true && !next.contains(city)) next.add(city);
                                if (checked == false) next.remove(city);
                                controller.updateCities(next);
                                setState(() {});
                              },
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () { controller.updateCities([]); Navigator.pop(dialogContext); }, child: const Text('不限地区')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('完成')),
            ],
          );
        },
      ),
    );
  }
}

class _SalarySelector extends StatefulWidget {
  const _SalarySelector({required this.controller});

  final WorkbenchController controller;

  @override
  State<_SalarySelector> createState() => _SalarySelectorState();
}

class _SalarySelectorState extends State<_SalarySelector> {
  late final MenuController menuController;
  late final FixedExtentScrollController minScroll;
  late final FixedExtentScrollController maxScroll;
  late int minValue;
  late int maxValue;

  @override
  void initState() {
    super.initState();
    menuController = MenuController();
    minValue = widget.controller.minSalaryK.clamp(0, 100).toInt();
    maxValue = widget.controller.maxSalaryK.clamp(minValue + 1, 100).toInt();
    minScroll = FixedExtentScrollController(initialItem: minValue);
    maxScroll = FixedExtentScrollController(initialItem: maxValue);
  }

  @override
  void dispose() {
    minScroll.dispose();
    maxScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return MenuAnchor(
      controller: menuController,
      alignmentOffset: const Offset(0, 8),
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(Color(0xFFF7F7F9)),
        elevation: const WidgetStatePropertyAll(12),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
      ),
      menuChildren: [
        SizedBox(
          width: 330,
          height: 315,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 15, 18, 5),
                child: Row(children: [Expanded(child: Text('期望薪资', style: TextStyle(fontWeight: FontWeight.w700))), Text('单位：K', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12))]),
              ),
              const Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [Text('最低薪资', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12)), Text('最高薪资', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12))]),
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: _SalaryWheel(controller: minScroll, onChanged: (value) { setState(() { minValue = value; if (maxValue <= minValue) { maxValue = (minValue + 1).clamp(1, 100).toInt(); maxScroll.jumpToItem(maxValue); } }); })),
                    const Text('—', style: TextStyle(fontSize: 18, color: Color(0xFF8E8E93))),
                    Expanded(child: _SalaryWheel(controller: maxScroll, onChanged: (value) { setState(() { maxValue = value <= minValue ? (minValue + 1).clamp(1, 100).toInt() : value; if (maxValue != value) maxScroll.jumpToItem(maxValue); }); })),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                child: Row(children: [Expanded(child: TextButton(onPressed: () => menuController.close(), child: const Text('取消'))), Expanded(child: FilledButton(onPressed: () { controller.updateSalaryRange(minValue, maxValue); menuController.close(); }, child: const Text('完成')))]),
              ),
            ],
          ),
        ),
      ],
      builder: (context, controller, child) => InkWell(
        onTap: () {
          if (controller.isOpen) controller.close(); else controller.open();
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 246,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(color: const Color(0xA8FFFFFF), borderRadius: BorderRadius.circular(18)),
          child: Row(children: [const Icon(Icons.payments_outlined, size: 19, color: Color(0xFF007AFF)), const SizedBox(width: 8), Text('${widget.controller.minSalaryK}', style: const TextStyle(fontWeight: FontWeight.w600)), const Text(' — ', style: TextStyle(color: Color(0xFF8E8E93))), Text('${widget.controller.maxSalaryK}', style: const TextStyle(fontWeight: FontWeight.w600)), const Text(' K', style: TextStyle(color: Color(0xFF6E6E73))), const Spacer(), const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF8E8E93))]),
        ),
      ),
    );
  }
}

class _SalaryWheel extends StatelessWidget {
  const _SalaryWheel({required this.controller, required this.onChanged});

  final FixedExtentScrollController controller;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: 38,
      diameterRatio: 1.8,
      perspective: 0.002,
      onSelectedItemChanged: onChanged,
      physics: const FixedExtentScrollPhysics(),
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: 101,
        builder: (context, index) => Center(child: Text('$index', style: const TextStyle(fontSize: 17))),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: InkWell(
        onTap: () => _showJobDetail(context, job),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(19),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(job.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                  _MatchBadge(score: job.matchScore),
                ],
              ),
              const SizedBox(height: 8),
              Text(job.company, style: const TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 5,
                children: [
                  _Meta(icon: Icons.location_on_outlined, text: job.location),
                  _Meta(icon: Icons.payments_outlined, text: job.salary),
                  _Meta(icon: Icons.work_outline, text: job.experience),
                ],
              ),
              const SizedBox(height: 12),
              Text(job.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF64748B), height: 1.35, fontSize: 12)),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 5,
                      children: job.tags.take(3).map((tag) => Chip(label: Text(tag), visualDensity: VisualDensity.compact, labelStyle: const TextStyle(fontSize: 11), padding: EdgeInsets.zero)).toList(),
                    ),
                  ),
                  _StatusLabel(status: job.status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showJobDetail(BuildContext context, Job job) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(job.title),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${job.company} · ${job.location}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Text(job.description),
              const SizedBox(height: 15),
              const Text('投递说明', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              const Text('本演示版本使用 BOSS 授权适配器的模拟数据。接入真实平台前，需要配置正式授权接口，并在最终投递前展示用户确认信息。'),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭'))],
      ),
    );
  }
}

class _MatchBadge extends StatelessWidget {
  const _MatchBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final color = score >= 90 ? const Color(0xFF059669) : const Color(0xFFD97706);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text('$score% 匹配', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 14, color: const Color(0xFF94A3B8)), const SizedBox(width: 3), Text(text, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11))],
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.status});

  final ApplicationStatus status;

  @override
  Widget build(BuildContext context) {
    return Text(status.label, style: TextStyle(color: status.color, fontWeight: FontWeight.w600, fontSize: 12));
  }
}
