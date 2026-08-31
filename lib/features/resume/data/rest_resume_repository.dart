import '../../../core/network/api_client.dart';
import '../domain/resume_repository.dart';

class RestResumeRepository implements ResumeRepository {
  RestResumeRepository(this.api);
  final ApiClient api;

  @override
  Future<ResumeImportTicket> createImport(String fileName, String contentType) async {
    final json = await api.postJson('/api/v1/resumes/import', {
      'fileName': fileName,
      'contentType': contentType,
    });
    return ResumeImportTicket(
      resumeId: json['resumeId'].toString(),
      taskId: json['taskId'].toString(),
      uploadUrl: json['uploadUrl'].toString(),
    );
  }

  @override
  Future<void> uploadImport(ResumeImportTicket ticket, List<int> bytes) async {
    final path = ticket.uploadUrl.startsWith('http')
        ? Uri.parse(ticket.uploadUrl).path
        : ticket.uploadUrl;
    await api.putBytes(path, bytes);
  }

  @override
  Future<ResumeParseTask> getParseTask(String taskId) async {
    final json = await api.getJson('/api/v1/resumes/$taskId/parse-task');
    return ResumeParseTask(
      taskId: json['taskId']?.toString() ?? taskId,
      status: _parseStatus(json['status']),
      progress: (json['progress'] as num?)?.toInt() ?? 0,
      message: json['message']?.toString(),
    );
  }

  @override
  Future<ResumeProfile> getProfile(String resumeId) async {
    final json = await api.getJson('/api/v1/resumes/$resumeId/profile');
    return _profile(json, resumeId);
  }

  @override
  Future<ResumeProfile> updateProfile(ResumeProfile profile) async {
    final json = await api.patchJson('/api/v1/resumes/${profile.id}/profile', _profileJson(profile));
    return _profile(json, profile.id);
  }

  @override
  Future<void> deleteResume(String resumeId) => api.delete('/api/v1/resumes/$resumeId');

  ResumeParseStatus _parseStatus(Object? value) {
    final name = value?.toString() ?? 'failed';
    if (name == 'needsReview') return ResumeParseStatus.needsReview;
    return ResumeParseStatus.values.firstWhere((item) => item.name == name, orElse: () => ResumeParseStatus.failed);
  }

  ResumeProfile _profile(Map<String, dynamic> json, String fallbackId) {
    final basic = Map<String, dynamic>.from(json['basic'] as Map? ?? const {});
    return ResumeProfile(
      id: json['id']?.toString() ?? fallbackId,
      fileName: json['fileName']?.toString() ?? '',
      basic: ResumeBasicInfo(name: basic['name']?.toString(), phone: basic['phone']?.toString(), email: basic['email']?.toString(), city: basic['city']?.toString()),
      workExperiences: _work(json['workExperiences']),
      education: _education(json['education']),
      projects: _projects(json['projects']),
      skills: (json['skills'] as List? ?? const []).map((item) => item.toString()).toList(),
      completeness: (json['completeness'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> _profileJson(ResumeProfile profile) => {
    'basic': {'name': profile.basic.name, 'phone': profile.basic.phone, 'email': profile.basic.email, 'city': profile.basic.city},
    'workExperiences': profile.workExperiences.map((item) => {'company': item.company, 'title': item.title, 'startDate': item.startDate, 'endDate': item.endDate, 'description': item.description}).toList(),
    'education': profile.education.map((item) => {'school': item.school, 'major': item.major, 'degree': item.degree, 'startDate': item.startDate, 'endDate': item.endDate}).toList(),
    'projects': profile.projects.map((item) => {'name': item.name, 'role': item.role, 'description': item.description}).toList(),
    'skills': profile.skills,
    'completeness': profile.completeness,
  };

  List<ResumeWorkExperience> _work(Object? value) => (value as List? ?? const []).map((item) { final m = Map<String, dynamic>.from(item as Map); return ResumeWorkExperience(company: m['company']?.toString() ?? '', title: m['title']?.toString() ?? '', startDate: m['startDate']?.toString() ?? '', endDate: m['endDate']?.toString(), description: m['description']?.toString()); }).toList();
  List<ResumeEducation> _education(Object? value) => (value as List? ?? const []).map((item) { final m = Map<String, dynamic>.from(item as Map); return ResumeEducation(school: m['school']?.toString() ?? '', major: m['major']?.toString() ?? '', degree: m['degree']?.toString() ?? '', startDate: m['startDate']?.toString() ?? '', endDate: m['endDate']?.toString()); }).toList();
  List<ResumeProject> _projects(Object? value) => (value as List? ?? const []).map((item) { final m = Map<String, dynamic>.from(item as Map); return ResumeProject(name: m['name']?.toString() ?? '', role: m['role']?.toString(), description: m['description']?.toString()); }).toList();
}
