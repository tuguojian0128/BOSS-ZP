/// 简历模块的前后端数据契约。
///
/// 文件导入后由后端完成文档解析、OCR 和字段识别；Flutter 只负责展示
/// 解析状态、让用户校对，并保存用户确认后的结构化结果。
abstract interface class ResumeRepository {
  Future<ResumeImportTicket> createImport(String fileName, String contentType);

  /// 将文件字节上传到 [ResumeImportTicket.uploadUrl]。
  /// Web 端只调用后端返回的短时上传地址，不把密钥放进 Flutter 客户端。
  Future<void> uploadImport(ResumeImportTicket ticket, List<int> bytes);

  Future<ResumeParseTask> getParseTask(String taskId);

  Future<ResumeProfile> getProfile(String resumeId);

  Future<ResumeProfile> updateProfile(ResumeProfile profile);

  Future<void> deleteResume(String resumeId);
}

enum ResumeParseStatus { uploading, parsing, recognized, needsReview, failed }

class ResumeImportTicket {
  const ResumeImportTicket(
      {required this.resumeId, required this.uploadUrl, required this.taskId});

  final String resumeId;
  final String uploadUrl;
  final String taskId;
}

class ResumeParseTask {
  const ResumeParseTask(
      {required this.taskId,
      required this.status,
      this.progress = 0,
      this.message});

  final String taskId;
  final ResumeParseStatus status;
  final int progress;
  final String? message;
}

class ResumeProfile {
  const ResumeProfile({
    required this.id,
    required this.fileName,
    required this.basic,
    required this.workExperiences,
    required this.education,
    required this.projects,
    required this.skills,
    required this.completeness,
    required this.updatedAt,
  });

  final String id;
  final String fileName;
  final ResumeBasicInfo basic;
  final List<ResumeWorkExperience> workExperiences;
  final List<ResumeEducation> education;
  final List<ResumeProject> projects;
  final List<String> skills;
  final int completeness;
  final DateTime updatedAt;

  ResumeProfile copyWith({
    String? id,
    String? fileName,
    ResumeBasicInfo? basic,
    List<ResumeWorkExperience>? workExperiences,
    List<ResumeEducation>? education,
    List<ResumeProject>? projects,
    List<String>? skills,
    int? completeness,
    DateTime? updatedAt,
  }) {
    return ResumeProfile(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      basic: basic ?? this.basic,
      workExperiences: workExperiences ?? this.workExperiences,
      education: education ?? this.education,
      projects: projects ?? this.projects,
      skills: skills ?? this.skills,
      completeness: completeness ?? this.completeness,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ResumeBasicInfo {
  const ResumeBasicInfo({this.name, this.phone, this.email, this.city});

  final String? name;
  final String? phone;
  final String? email;
  final String? city;

  ResumeBasicInfo copyWith(
      {String? name, String? phone, String? email, String? city}) {
    return ResumeBasicInfo(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      city: city ?? this.city,
    );
  }
}

class ResumeWorkExperience {
  const ResumeWorkExperience(
      {required this.company,
      required this.title,
      required this.startDate,
      this.endDate,
      this.description});

  final String company;
  final String title;
  final String startDate;
  final String? endDate;
  final String? description;
}

class ResumeEducation {
  const ResumeEducation(
      {required this.school,
      required this.major,
      required this.degree,
      required this.startDate,
      this.endDate});

  final String school;
  final String major;
  final String degree;
  final String startDate;
  final String? endDate;
}

class ResumeProject {
  const ResumeProject({required this.name, this.role, this.description});

  final String name;
  final String? role;
  final String? description;
}
