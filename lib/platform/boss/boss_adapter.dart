/// BOSS 直聘授权接入边界。
///
/// 这里故意不写具体 URL、密钥或网页抓取逻辑。只有在取得 BOSS
/// 官方接口文档和书面授权后，才在本文件对应的实现类中接入真实服务。
abstract interface class BossJobsGateway {
  Future<List<BossJobDto>> search(BossJobQuery query);

  Future<BossJobDto> detail(String externalJobId);
}

abstract interface class BossApplicationGateway {
  Future<BossApplicationPreview> preview(BossApplicationRequest request);

  /// 仅用于已取得正式授权的投递接口。
  Future<BossApplicationResult> submit(BossApplicationRequest request);

  Future<BossApplicationStatus> status(String externalApplicationId);
}

class BossApiConfig {
  const BossApiConfig({
    required this.baseUrl,
    required this.clientId,
    this.timeout = const Duration(seconds: 20),
  });

  final String baseUrl;
  final String clientId;
  final Duration timeout;
}

class BossJobQuery {
  const BossJobQuery({
    required this.keyword,
    required this.city,
    this.minSalary,
    this.maxSalary,
    this.page = 1,
    this.pageSize = 20,
  });

  final String keyword;
  final String city;
  final int? minSalary;
  final int? maxSalary;
  final int page;
  final int pageSize;
}

class BossJobDto {
  const BossJobDto({
    required this.externalId,
    required this.title,
    required this.company,
    required this.city,
    required this.salaryText,
    required this.description,
  });

  final String externalId;
  final String title;
  final String company;
  final String city;
  final String salaryText;
  final String description;
}

class BossApplicationRequest {
  const BossApplicationRequest({
    required this.externalJobId,
    required this.resumeVersionId,
    required this.message,
  });

  final String externalJobId;
  final String resumeVersionId;
  final String message;
}

class BossApplicationPreview {
  const BossApplicationPreview({
    required this.externalJobId,
    required this.fields,
    required this.requiresUserConfirmation,
  });

  final String externalJobId;
  final Map<String, String> fields;
  final bool requiresUserConfirmation;
}

class BossApplicationResult {
  const BossApplicationResult({
    required this.externalApplicationId,
    required this.submittedAt,
  });

  final String externalApplicationId;
  final DateTime submittedAt;
}

enum BossApplicationStatus { queued, applying, submitted, failed, paused }
