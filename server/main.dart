import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'database.dart';
import 'auth.dart';

const int maxResumeBytes = 10 * 1024 * 1024;
const allowedExtensions = {'pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg'};
const supportedPlatforms = ['BOSS 直聘', '智联招聘', '猎聘', '前程无忧', '鱼泡直聘', '国聘'];
final demoJobs = [
  {
    'id': 'boss-001',
    'title': '高级 Java 开发工程师',
    'company': '星河科技',
    'platform': 'BOSS 直聘',
    'location': '上海 · 浦东新区',
    'salary': '20-35K',
    'matchScore': 96,
    'tags': ['Java', 'Spring Boot']
  },
  {
    'id': 'zhipin-001',
    'title': 'Java 后端工程师',
    'company': '智联云科',
    'platform': '智联招聘',
    'location': '北京 · 海淀区',
    'salary': '18-30K',
    'matchScore': 89,
    'tags': ['Java', 'MySQL']
  },
  {
    'id': 'liepin-001',
    'title': '资深后端开发工程师',
    'company': '猎头科技',
    'platform': '猎聘',
    'location': '杭州 · 滨江区',
    'salary': '25-40K',
    'matchScore': 93,
    'tags': ['Java', '分布式']
  },
  {
    'id': 'job51-001',
    'title': '后端研发工程师',
    'company': '五一人才科技',
    'platform': '前程无忧',
    'location': '广州 · 天河区',
    'salary': '15-26K',
    'matchScore': 86,
    'tags': ['Java', 'Docker']
  },
  {
    'id': 'yupao-001',
    'title': '技术负责人',
    'company': '鱼泡数字化',
    'platform': '鱼泡直聘',
    'location': '成都 · 高新区',
    'salary': '22-35K',
    'matchScore': 82,
    'tags': ['Java', '架构设计']
  },
  {
    'id': 'guopin-001',
    'title': '软件开发工程师',
    'company': '国聘数字服务中心',
    'platform': '国聘',
    'location': '深圳 · 南山区',
    'salary': '16-24K',
    'matchScore': 80,
    'tags': ['Java', '微服务']
  },
];

Future<void> main() async {
  final service = ResumeService();
  final port = int.tryParse(Platform.environment['APP_API_PORT'] ?? '') ?? 8090;
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  stdout.writeln(
      'Resume API listening on http://${server.address.address}:${server.port}');
  await for (final request in server) {
    unawaited(service.handle(request));
  }
}

class ResumeService {
  ResumeService() {
    _initializeDatabase();
    _restorePersistedState();
  }

  final AppDatabase database = AppDatabase();
  final Map<String, ResumeRecord> resumes = {};
  final Map<String, ParseTaskRecord> tasks = {};
  final Map<String, DeliveryTaskRecord> deliveryTasks = {};
  final Map<String, String> uploadTokens = {};
  final Random random = Random.secure();
  final AuthService auth = AuthService();

  static const demoUserId = 'user_demo_001';

  void _initializeDatabase() {
    final now = DateTime.now().toIso8601String();
    final demoPassword = auth.hashPassword('demo-password');
    database.db.execute(
        '''INSERT OR IGNORE INTO users(
          id, phone, display_name, password_hash, password_salt, status, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, 'active', ?, ?)''',
        [demoUserId, '13800138000', '演示用户', demoPassword.hash, demoPassword.salt, now, now]);
    database.db.execute(
        'UPDATE users SET phone = COALESCE(phone, ?), password_hash = COALESCE(password_hash, ?), password_salt = COALESCE(password_salt, ?) WHERE id = ?',
        ['13800138000', demoPassword.hash, demoPassword.salt, demoUserId]);
    for (final platform in supportedPlatforms) {
      database.db.execute(
          'INSERT OR IGNORE INTO platform_accounts(id, user_id, platform, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)',
          [
            'account_${platform.hashCode}',
            demoUserId,
            platform,
            'disconnected',
            now,
            now
          ]);
      platformAccounts.putIfAbsent(
          _accountKey(demoUserId, platform), () => PlatformAccountRecord(platform: platform));
    }
    final rows = database.db.select(
        'SELECT platform, status, display_name, last_synced_at FROM platform_accounts WHERE user_id = ?',
        [demoUserId]);
    for (final row in rows) {
      final platform = row['platform']?.toString() ?? '';
      final account = platformAccounts[_accountKey(demoUserId, platform)];
      if (account == null) continue;
      account.status = row['status']?.toString() ?? 'disconnected';
      account.displayName = row['display_name']?.toString();
      final lastSyncedAt = row['last_synced_at']?.toString();
      account.lastSyncedAt =
          lastSyncedAt == null ? null : DateTime.tryParse(lastSyncedAt);
    }
  }

  void _restorePersistedState() {
    final resumeRows = database.db.select('SELECT id, user_id, file_name, content_type, parse_status, completeness FROM resumes');
    for (final row in resumeRows) {
      final record = ResumeRecord(
        id: row['id'].toString(),
        userId: row['user_id'].toString(),
        fileName: row['file_name'].toString(),
        contentType: row['content_type']?.toString() ?? 'application/octet-stream',
      )..parseStatus = row['parse_status']?.toString() ?? 'uploading';
      final profiles = database.db.select(
          'SELECT payload_json FROM resume_profiles WHERE resume_id = ?', [record.id]);
      if (profiles.isNotEmpty) {
        try {
          record.profile = ResumeProfile.fromJson(
              Map<String, dynamic>.from(jsonDecode(profiles.first['payload_json'].toString()) as Map));
        } catch (_) {
          record.profile = null;
        }
      }
      resumes[record.id] = record;
    }
    final taskRows = database.db.select('SELECT id, user_id, resume_id, status, total, completed, failed, message, jobs_json, created_at FROM application_tasks');
    for (final row in taskRows) {
      List<Map<String, dynamic>> jobs = const [];
      try {
        jobs = (jsonDecode(row['jobs_json']?.toString() ?? '[]') as List)
            .map((item) => Map<String, dynamic>.from(item as Map)).toList();
      } catch (_) {}
      deliveryTasks[row['id'].toString()] = DeliveryTaskRecord(
        id: row['id'].toString(),
        userId: row['user_id'].toString(),
        resumeId: row['resume_id'].toString(),
        total: (row['total'] as num?)?.toInt() ?? jobs.length,
        jobs: jobs,
      )
        ..status = row['status']?.toString() ?? 'queued'
        ..completed = (row['completed'] as num?)?.toInt() ?? 0
        ..failed = (row['failed'] as num?)?.toInt() ?? 0
        ..message = row['message']?.toString() ?? '任务已恢复';
    }
  }

  final Map<String, PlatformAccountRecord> platformAccounts = {};
  final Map<String, AuthorizationSession> authorizationSessions = {};

  Future<void> handle(HttpRequest request) async {
    try {
      _cors(request.response);
      if (request.method == 'OPTIONS') {
        request.response.statusCode = HttpStatus.noContent;
        await request.response.close();
        return;
      }
      final path = request.uri.pathSegments;
      // Authentication endpoints are intentionally the only public API.
      if (path.join('/') == 'api/v1/auth/register' && request.method == 'POST') {
        await _register(request);
        return;
      }
      if (path.join('/') == 'api/v1/auth/login' && request.method == 'POST') {
        await _login(request);
        return;
      }
      if (path.join('/') == 'api/v1/auth/refresh' && request.method == 'POST') {
        await _refresh(request);
        return;
      }
      if (path.join('/') == 'api/v1/platform-accounts/callback' &&
          request.method == 'GET') {
        await _completeAuthorization(request);
        return;
      }
      final userId = _authenticate(request);
      if (userId == null) return;
      if (path.join('/') == 'api/v1/auth/me' && request.method == 'GET') {
        await _me(request, userId);
        return;
      }
      if (path.join('/') == 'api/v1/auth/logout' && request.method == 'POST') {
        await _logout(request, userId);
        return;
      }
      if (path.join('/') == 'api/v1/platform-accounts' &&
          request.method == 'GET') {
        _json(request.response, HttpStatus.ok, {'items': _accountsFor(userId)});
        return;
      }
      if (path.length == 5 &&
          path[0] == 'api' &&
          path[1] == 'v1' &&
          path[2] == 'platform-accounts' &&
          path[4] == 'authorize' &&
          request.method == 'POST') {
        await _beginAuthorization(request, userId, path[3]);
        return;
      }
      if (path.length == 5 &&
          path[0] == 'api' &&
          path[1] == 'v1' &&
          path[2] == 'platform-accounts' &&
          path[4] == 'disconnect' &&
          request.method == 'POST') {
        final account = _platformAccount(userId, path[3]);
        if (account == null) {
          _json(request.response, HttpStatus.notFound,
              {'error': 'platform_not_supported'});
          return;
        }
        account.status = 'disconnected';
        account.message = '已解除授权';
        _persistPlatformAccount(userId, account);
        _json(request.response, HttpStatus.ok, account.toJson());
        return;
      }
      if (path.join('/') == 'api/v1/jobs' && request.method == 'GET') {
        await _searchJobs(request, userId);
        return;
      }
      if (path.length == 4 &&
          path[0] == 'api' &&
          path[1] == 'v1' &&
          path[2] == 'jobs' &&
          request.method == 'GET') {
        Map<String, dynamic>? job;
        for (final item in demoJobs) {
          if (item['id'] == path[3]) {
            job = item;
            break;
          }
        }
        if (job == null) {
          _json(request.response, HttpStatus.notFound,
              {'error': 'job_not_found'});
        } else {
          _json(request.response, HttpStatus.ok, job);
        }
        return;
      }
      if (request.method == 'GET' &&
          path.join('/') == 'api/v1/applications/dashboard') {
        await _applicationDashboard(request, userId);
        return;
      }
      if (request.method == 'POST' && path.join('/') == 'api/v1/applications') {
        await _createApplication(request, userId);
        return;
      }
      if (request.method == 'POST' &&
          path.join('/') == 'api/v1/applications/batch') {
        await _createDeliveryTask(request, userId);
        return;
      }
      if (path.length == 6 &&
          path[0] == 'api' &&
          path[1] == 'v1' &&
          path[2] == 'applications' &&
          path[3] == 'tasks' &&
          request.method == 'POST') {
        final task = deliveryTasks[path[4]];
        if (task != null && task.userId != userId) {
          _json(request.response, HttpStatus.notFound,
              {'error': 'delivery_task_not_found'});
          return;
        }
        if (task == null) {
          _json(request.response, HttpStatus.notFound,
              {'error': 'delivery_task_not_found'});
          return;
        }
        if (path[5] == 'pause') task.status = 'paused';
        if (path[5] == 'resume') {
          task.status = 'running';
          unawaited(_runDeliveryTask(task));
        }
        _persistDeliveryTask(task);
        _json(request.response, HttpStatus.ok, task.toJson());
        return;
      }
      if (path.length == 5 &&
          path[0] == 'api' &&
          path[1] == 'v1' &&
          path[2] == 'applications' &&
          path[3] == 'tasks') {
        if (request.method == 'GET') {
          await _getDeliveryTask(request, userId, path[4]);
          return;
        }
        if (request.method == 'POST' && path[4].isNotEmpty) {
          return;
        }
      }
      if (request.method == 'POST' &&
          path.join('/') == 'api/v1/resumes/import') {
        await _createImport(request, userId);
      } else if (request.method == 'PUT' &&
          path.length == 2 &&
          path.first == 'uploads') {
        await _upload(request, userId, path[1]);
      } else if (path.length == 5 &&
          path[0] == 'api' &&
          path[1] == 'v1' &&
          path[2] == 'resumes' &&
          path[4] == 'parse-task' &&
          request.method == 'GET') {
        await _getTask(request, userId, path[3]);
      } else if (path.length == 5 &&
          path[0] == 'api' &&
          path[1] == 'v1' &&
          path[2] == 'resumes' &&
          path[4] == 'profile') {
        if (request.method == 'GET') {
          await _getProfile(request, userId, path[3]);
        } else if (request.method == 'PATCH') {
          await _updateProfile(request, userId, path[3]);
        } else {
          _json(request.response, HttpStatus.methodNotAllowed,
              {'error': 'method_not_allowed'});
        }
      } else if (path.length == 4 &&
          path[0] == 'api' &&
          path[1] == 'v1' &&
          path[2] == 'resumes' &&
          request.method == 'DELETE') {
        await _deleteResume(request, userId, path[3]);
      } else {
        _json(request.response, HttpStatus.notFound, {'error': 'not_found'});
      }
    } catch (error) {
      stderr.writeln('Request failed: $error');
      _json(request.response, HttpStatus.internalServerError,
          {'error': 'internal_server_error'});
    }
  }

  String? _authenticate(HttpRequest request) {
    final authorization = request.headers.value(HttpHeaders.authorizationHeader);
    String? token;
    if (authorization != null && authorization.startsWith('Bearer ')) {
      token = authorization.substring(7).trim();
    }
    final claims = token == null ? null : auth.verifyAccessToken(token);
    if (claims != null && _userExists(claims.userId)) return claims.userId;

    // A deliberately explicit development-only escape hatch keeps local UI
    // smoke tests possible without weakening production authentication.
    final environment = Platform.environment['APP_ENV'] ?? 'development';
    final testUser = request.headers.value('x-user-id');
    if (environment != 'production' && testUser != null && _userExists(testUser)) {
      return testUser;
    }
    _json(request.response, HttpStatus.unauthorized, {
      'error': 'unauthorized',
      'message': '请先登录后再访问此接口',
    });
    return null;
  }

  bool _userExists(String userId) {
    final rows = database.db.select(
        "SELECT id FROM users WHERE id = ? AND status = 'active'", [userId]);
    return rows.isNotEmpty;
  }

  Future<void> _register(HttpRequest request) async {
    final body = await _readJson(request);
    final phone = _string(body['phone']).trim();
    final email = _string(body['email']).trim().toLowerCase();
    final displayName = _string(body['displayName']).trim();
    final password = _string(body['password']);
    if (phone.isEmpty && email.isEmpty) {
      _json(request.response, HttpStatus.badRequest, {'error': 'phone_or_email_required'});
      return;
    }
    if (displayName.isEmpty || password.length < 8) {
      _json(request.response, HttpStatus.badRequest,
          {'error': password.length < 8 ? 'password_too_short' : 'display_name_required'});
      return;
    }
    final duplicate = database.db.select(
        'SELECT id FROM users WHERE (? <> "" AND phone = ?) OR (? <> "" AND email = ?) LIMIT 1',
        [phone, phone, email, email]);
    if (duplicate.isNotEmpty) {
      _json(request.response, HttpStatus.conflict, {'error': 'account_already_exists'});
      return;
    }
    final userId = 'user_${DateTime.now().millisecondsSinceEpoch}_${random.nextInt(999999)}';
    final digest = auth.hashPassword(password);
    final now = DateTime.now().toUtc().toIso8601String();
    database.db.execute(
        '''INSERT INTO users(id, phone, email, display_name, password_hash, password_salt, status, created_at, updated_at)
           VALUES (?, NULLIF(?, ''), NULLIF(?, ''), ?, ?, ?, 'active', ?, ?)''',
        [userId, phone, email, displayName, digest.hash, digest.salt, now, now]);
    for (final platform in supportedPlatforms) {
      database.db.execute(
          'INSERT INTO platform_accounts(id, user_id, platform, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)',
          ['account_${userId}_$platform', userId, platform, 'disconnected', now, now]);
      platformAccounts[_accountKey(userId, platform)] = PlatformAccountRecord(platform: platform);
    }
    final tokens = _issueAndStoreTokens(userId);
    _json(request.response, HttpStatus.created, _authResponse(userId, tokens));
  }

  Future<void> _login(HttpRequest request) async {
    final body = await _readJson(request);
    final identifier = _string(body['phone']).trim().isNotEmpty
        ? _string(body['phone']).trim()
        : _string(body['email']).trim().toLowerCase();
    final password = _string(body['password']);
    if (identifier.isEmpty || password.isEmpty) {
      _json(request.response, HttpStatus.badRequest, {'error': 'credentials_required'});
      return;
    }
    final rows = database.db.select(
        "SELECT * FROM users WHERE (phone = ? OR email = ?) AND status = 'active' LIMIT 1",
        [identifier, identifier]);
    if (rows.isEmpty || !_verifyUserPassword(rows.first, password)) {
      _json(request.response, HttpStatus.unauthorized, {'error': 'invalid_credentials'});
      return;
    }
    final userId = rows.first['id'].toString();
    final now = DateTime.now().toUtc().toIso8601String();
    database.db.execute('UPDATE users SET last_login_at = ?, updated_at = ? WHERE id = ?', [now, now, userId]);
    final tokens = _issueAndStoreTokens(userId);
    _json(request.response, HttpStatus.ok, _authResponse(userId, tokens));
  }

  bool _verifyUserPassword(Map<String, Object?> row, String password) {
    final hash = row['password_hash']?.toString();
    final salt = row['password_salt']?.toString();
    return hash != null && salt != null && hash.isNotEmpty && salt.isNotEmpty &&
        auth.verifyPassword(password, salt, hash);
  }

  IssuedTokens _issueAndStoreTokens(String userId) {
    final tokens = auth.issueTokens(userId);
    final now = DateTime.now().toUtc().toIso8601String();
    database.db.execute(
        'INSERT INTO refresh_tokens(id, user_id, token_hash, expires_at, created_at) VALUES (?, ?, ?, ?, ?)',
        ['rt_${DateTime.now().microsecondsSinceEpoch}_${random.nextInt(9999)}', userId,
          auth.hashRefreshToken(tokens.refreshToken), tokens.refreshExpiresAt.toIso8601String(), now]);
    return tokens;
  }

  Map<String, dynamic> _authResponse(String userId, IssuedTokens tokens) {
    final row = database.db.select('SELECT id, phone, email, display_name FROM users WHERE id = ?', [userId]).first;
    return {
      'accessToken': tokens.accessToken,
      'refreshToken': tokens.refreshToken,
      'expiresIn': AuthService.accessTokenLifetime.inSeconds,
      'user': {
        'id': row['id'],
        'phone': row['phone'],
        'email': row['email'],
        'displayName': row['display_name'],
      }
    };
  }

  Future<void> _refresh(HttpRequest request) async {
    final body = await _readJson(request);
    final refreshToken = _string(body['refreshToken']);
    if (refreshToken.isEmpty) {
      _json(request.response, HttpStatus.badRequest, {'error': 'refresh_token_required'});
      return;
    }
    final rows = database.db.select(
        '''SELECT id, user_id, expires_at FROM refresh_tokens
           WHERE token_hash = ? AND revoked_at IS NULL LIMIT 1''',
        [auth.hashRefreshToken(refreshToken)]);
    if (rows.isEmpty) {
      _json(request.response, HttpStatus.unauthorized, {'error': 'invalid_refresh_token'});
      return;
    }
    final row = rows.first;
    final expires = DateTime.tryParse(row['expires_at'].toString());
    final userId = row['user_id'].toString();
    if (expires == null || expires.isBefore(DateTime.now().toUtc()) || !_userExists(userId)) {
      _json(request.response, HttpStatus.unauthorized, {'error': 'refresh_token_expired'});
      return;
    }
    database.db.execute('UPDATE refresh_tokens SET revoked_at = ? WHERE id = ?', [DateTime.now().toUtc().toIso8601String(), row['id']]);
    final tokens = _issueAndStoreTokens(userId);
    _json(request.response, HttpStatus.ok, _authResponse(userId, tokens));
  }

  Future<void> _logout(HttpRequest request, String userId) async {
    final body = await _readJson(request);
    final refreshToken = _string(body['refreshToken']);
    if (refreshToken.isNotEmpty) {
      database.db.execute('UPDATE refresh_tokens SET revoked_at = ? WHERE user_id = ? AND token_hash = ?',
          [DateTime.now().toUtc().toIso8601String(), userId, auth.hashRefreshToken(refreshToken)]);
    } else {
      database.db.execute('UPDATE refresh_tokens SET revoked_at = ? WHERE user_id = ? AND revoked_at IS NULL',
          [DateTime.now().toUtc().toIso8601String(), userId]);
    }
    _json(request.response, HttpStatus.ok, {'ok': true});
  }

  Future<void> _me(HttpRequest request, String userId) async {
    final rows = database.db.select('SELECT id, phone, email, display_name, created_at, last_login_at FROM users WHERE id = ?', [userId]);
    if (rows.isEmpty) {
      _json(request.response, HttpStatus.unauthorized, {'error': 'user_not_found'});
      return;
    }
    final row = rows.first;
    _json(request.response, HttpStatus.ok, {'id': row['id'], 'phone': row['phone'], 'email': row['email'], 'displayName': row['display_name'], 'createdAt': row['created_at'], 'lastLoginAt': row['last_login_at']});
  }

  Future<void> _beginAuthorization(HttpRequest request, String userId, String platform) async {
    final account = _platformAccount(userId, platform);
    if (account == null) {
      _json(request.response, HttpStatus.notFound,
          {'error': 'platform_not_supported'});
      return;
    }
    final id =
        'auth_${DateTime.now().millisecondsSinceEpoch}_${random.nextInt(9999)}';
    authorizationSessions[id] = AuthorizationSession(userId: userId, platform: platform);
    account.status = 'authorizing';
    _json(request.response, HttpStatus.ok, {
      'authorizationId': id,
      'platform': platform,
      'authorizationUrl': 'https://auth.example.com/$platform?state=$id',
      'expiresIn': 600
    });
  }

  Future<void> _completeAuthorization(HttpRequest request) async {
    final id = request.uri.queryParameters['state'] ?? '';
    final session = authorizationSessions.remove(id);
    final account = session == null ? null : _platformAccount(session.userId, session.platform);
    if (account == null) {
      _json(request.response, HttpStatus.badRequest,
          {'error': 'authorization_state_invalid'});
      return;
    }
    account.status = 'connected';
    account.displayName = '已授权账号';
    account.lastSyncedAt = DateTime.now();
    account.message = '官方授权成功';
    _persistPlatformAccount(session!.userId, account);
    _json(request.response, HttpStatus.ok, account.toJson());
  }

  void _persistPlatformAccount(String userId, PlatformAccountRecord account) {
    final now = DateTime.now().toIso8601String();
    database.db.execute(
        'UPDATE platform_accounts SET status = ?, display_name = ?, last_synced_at = ?, updated_at = ? WHERE user_id = ? AND platform = ?',
        [
          account.status,
          account.displayName,
          account.lastSyncedAt?.toIso8601String(),
          now,
          userId,
          account.platform
        ]);
  }

  PlatformAccountRecord? _platformAccount(String userId, String platform) {
    if (!supportedPlatforms.contains(platform)) return null;
    final key = _accountKey(userId, platform);
    final existing = platformAccounts[key];
    if (existing != null) return existing;
    final rows = database.db.select(
        'SELECT status, display_name, last_synced_at FROM platform_accounts WHERE user_id = ? AND platform = ?',
        [userId, platform]);
    if (rows.isEmpty) return null;
    final row = rows.first;
    final account = PlatformAccountRecord(platform: platform)
      ..status = row['status']?.toString() ?? 'disconnected'
      ..displayName = row['display_name']?.toString();
    account.lastSyncedAt = DateTime.tryParse(row['last_synced_at']?.toString() ?? '');
    platformAccounts[key] = account;
    return account;
  }

  List<Map<String, dynamic>> _accountsFor(String userId) => supportedPlatforms
      .map((platform) => _platformAccount(userId, platform))
      .whereType<PlatformAccountRecord>()
      .map((account) => account.toJson())
      .toList();

  Future<void> _searchJobs(HttpRequest request, String userId) async {
    final keywords = (request.uri.queryParameters['keyword'] ?? '')
        .split(',').map((value) => value.trim().toLowerCase()).where((value) => value.isNotEmpty).toList();
    final platforms = (request.uri.queryParameters['platforms'] ?? '')
        .split(',').map((value) => value.trim()).where((value) => value.isNotEmpty).toList();
    final cities = (request.uri.queryParameters['city'] ?? '')
        .split(',').map((value) => value.trim()).where((value) => value.isNotEmpty).toList();
    final minSalary = int.tryParse(request.uri.queryParameters['minSalary'] ?? '');
    final maxSalary = int.tryParse(request.uri.queryParameters['maxSalary'] ?? '');
    final onlyHighMatch = request.uri.queryParameters['onlyHighMatch'] == 'true';
    final authorizedPlatforms = supportedPlatforms
        .where((platform) => _platformAccount(userId, platform)?.status == 'connected')
        .toSet();
    final all = demoJobs;
    final filtered = all.where((job) {
      final searchable = '${job['title']} ${job['company']} ${job['tags']}'.toLowerCase();
      final keywordMatched = keywords.isEmpty || keywords.any(searchable.contains);
      final platformMatched = platforms.isEmpty
          ? authorizedPlatforms.contains(job['platform'])
          : platforms.contains(job['platform']) &&
              authorizedPlatforms.contains(job['platform']);
      final cityMatched =
          cities.isEmpty || cities.any((value) => _string(job['location']).contains(value));
      final scoreMatched = !onlyHighMatch || ((job['matchScore'] as num?)?.toInt() ?? 0) >= 80;
      return keywordMatched && platformMatched && cityMatched && scoreMatched &&
          (minSalary == null || maxSalary == null || _salaryOverlaps(_string(job['salary']), minSalary, maxSalary));
    }).toList();
    _json(request.response, HttpStatus.ok, {
      'items': filtered,
      'total': filtered.length,
      'page': int.tryParse(request.uri.queryParameters['page'] ?? '1') ?? 1,
      'pageSize':
          int.tryParse(request.uri.queryParameters['pageSize'] ?? '20') ?? 20
    });
  }

  Future<void> _applicationDashboard(HttpRequest request, String userId) async {
    final platforms = ['BOSS 直聘', '智联招聘', '猎聘', '前程无忧', '鱼泡直聘', '国聘'];
    final now = DateTime.now().toUtc();
    final start = DateTime.utc(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final startText = start.toIso8601String();
    final channels = <Map<String, dynamic>>[];
    for (final platform in platforms) {
      final rows = database.db.select(
          '''SELECT
               COUNT(*) AS submitted,
               SUM(CASE WHEN status = 'viewed' THEN 1 ELSE 0 END) AS viewed,
               SUM(CASE WHEN status = 'replied' THEN 1 ELSE 0 END) AS replied
             FROM application_records
             WHERE user_id = ? AND platform = ? AND submitted_at >= ?''',
          [userId, platform, startText]);
      final row = rows.first;
      channels.add({
        'platform': platform,
        'available': 0,
        'submitted': (row['submitted'] as num?)?.toInt() ?? 0,
        'viewed': (row['viewed'] as num?)?.toInt() ?? 0,
        'replied': (row['replied'] as num?)?.toInt() ?? 0,
      });
    }
    final daily = <Map<String, dynamic>>[];
    for (var day = 0; day < 7; day++) {
      for (var index = 0; index < platforms.length; index++) {
        final date = start.add(Duration(days: day));
        final dateText = date.toIso8601String().substring(0, 10);
        final rows = database.db.select(
            'SELECT submitted_count FROM daily_application_stats WHERE user_id = ? AND stat_date = ? AND platform = ?',
            [userId, dateText, platforms[index]]);
        daily.add({
          'date': date.toIso8601String(),
          'platform': platforms[index],
          'available': 0,
          'submitted': rows.isEmpty ? 0 : (rows.first['submitted_count'] as num).toInt(),
        });
      }
    }
    final recentRows = database.db.select(
        '''SELECT ar.id, ar.job_id AS jobId, ar.platform, j.title, j.company,
                  ar.status, ar.submitted_at AS submittedAt
           FROM application_records ar LEFT JOIN jobs j ON j.id = ar.job_id
           WHERE ar.user_id = ? ORDER BY ar.submitted_at DESC LIMIT 20''', [userId]);
    final recent = recentRows.map((row) => <String, dynamic>{
      'id': row['id'], 'jobId': row['jobId'], 'platform': row['platform'],
      'title': row['title'] ?? '', 'company': row['company'] ?? '',
      'status': row['status'], 'submittedAt': row['submittedAt'],
    }).toList();
    final total =
        channels.fold<int>(0, (sum, item) => sum + (item['submitted'] as int));
    final available =
        channels.fold<int>(0, (sum, item) => sum + (item['available'] as int));
    final viewed =
        channels.fold<int>(0, (sum, item) => sum + (item['viewed'] as int));
    final replied =
        channels.fold<int>(0, (sum, item) => sum + (item['replied'] as int));
    _json(request.response, HttpStatus.ok, {
      'weekStart': start.toIso8601String(),
      'weekEnd': start.add(const Duration(days: 6)).toIso8601String(),
      'weekTotal': total,
      'totalAvailable': available,
      'viewed': viewed,
      'replied': replied,
      'interviews': 0,
      'channels': channels,
      'daily': daily,
      'recent': recent
    });
  }

  Future<void> _createApplication(HttpRequest request, String userId) async {
    final body = await _readJson(request);
    for (final key in ['jobId', 'platform', 'title', 'company']) {
      if (_string(body[key]).isEmpty) {
        _json(
            request.response, HttpStatus.badRequest, {'error': 'missing_$key'});
        return;
      }
    }
    _json(request.response, HttpStatus.created, {
      'id': 'app_${DateTime.now().millisecondsSinceEpoch}',
      'jobId': body['jobId'],
      'platform': body['platform'],
      'title': body['title'],
      'company': body['company'],
      'status': 'queued',
      'submittedAt': DateTime.now().toIso8601String()
    });
  }

  Future<void> _createDeliveryTask(HttpRequest request, String userId) async {
    final body = await _readJson(request);
    var resumeId = _string(body['resumeId']);
    final jobs = (body['jobs'] as List? ?? const []);
    if (jobs.isEmpty || jobs.length > 200) {
      _json(request.response, HttpStatus.badRequest,
          {'error': jobs.isEmpty ? 'jobs_required' : 'invalid_delivery_batch'});
      return;
    }
    if (resumeId.isEmpty) {
      final rows = database.db.select(
          'SELECT id FROM resumes WHERE user_id = ? ORDER BY updated_at DESC LIMIT 1',
          [userId]);
      if (rows.isNotEmpty) resumeId = rows.first['id'].toString();
    }
    final resume = resumes[resumeId];
    if (resume == null || resume.userId != userId) {
      _json(request.response, HttpStatus.notFound, {'error': 'resume_not_found'});
      return;
    }
    final platforms = jobs
        .map((item) => _string((item as Map)['platform']))
        .where((item) => item.isNotEmpty)
        .toSet();
    if (platforms.isEmpty) {
      _json(request.response, HttpStatus.badRequest,
          {'error': 'platform_required'});
      return;
    }
    final id = 'delivery_${DateTime.now().millisecondsSinceEpoch}';
    final task = DeliveryTaskRecord(
        id: id,
        userId: userId,
        resumeId: resumeId,
        total: jobs.length,
        jobs: jobs.map((item) => Map<String, dynamic>.from(item as Map)).toList());
    deliveryTasks[id] = task;
    final createdAt = DateTime.now().toUtc().toIso8601String();
    database.db.execute(
        '''INSERT INTO application_tasks(id, user_id, resume_id, status, total, jobs_json, created_at, updated_at)
           VALUES (?, ?, ?, 'queued', ?, ?, ?, ?)''',
        [id, userId, resumeId, jobs.length, jsonEncode(task.jobs), createdAt, createdAt]);
    _json(request.response, HttpStatus.accepted, task.toJson());
    unawaited(_runDeliveryTask(task));
  }

  Future<void> _getDeliveryTask(HttpRequest request, String userId, String id) async {
    final task = deliveryTasks[id];
    if (task == null || task.userId != userId) {
      _json(request.response, HttpStatus.notFound,
          {'error': 'delivery_task_not_found'});
      return;
    }
    _json(request.response, HttpStatus.ok, task.toJson());
  }

  Future<void> _runDeliveryTask(DeliveryTaskRecord task) async {
    task.status = 'running';
    _persistDeliveryTask(task);
    for (var index = 0; index < task.total; index++) {
      while (task.status == 'paused') {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      if (task.status == 'cancelled') return;
      await Future<void>.delayed(const Duration(milliseconds: 180));
      final job = task.jobs[index];
      final jobId = _string(job['jobId'] ?? job['id']);
      final platform = _string(job['platform']);
      final title = _string(job['title']);
      final company = _string(job['company']);
      if (jobId.isNotEmpty && platform.isNotEmpty) {
        _ensureJob(jobId, platform, title, company);
        final now = DateTime.now().toUtc().toIso8601String();
        database.db.execute(
            '''INSERT INTO application_records(
              id, task_id, user_id, job_id, resume_id, platform, status,
              submitted_at, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, 'submitted', ?, ?, ?)''',
            ['app_${DateTime.now().microsecondsSinceEpoch}_$index', task.id,
              task.userId, jobId, task.resumeId, platform, now, now, now]);
        database.db.execute(
            '''INSERT INTO daily_application_stats(user_id, stat_date, platform, submitted_count, created_at, updated_at)
               VALUES (?, ?, ?, 1, ?, ?)
               ON CONFLICT(user_id, stat_date, platform) DO UPDATE SET
                 submitted_count = submitted_count + 1, updated_at = excluded.updated_at''',
            [task.userId, now.substring(0, 10), platform, now, now]);
      }
      task.completed = index + 1;
      _persistDeliveryTask(task);
    }
    task.status = 'completed';
    task.message = '全部投递任务已完成';
    _persistDeliveryTask(task);
  }

  void _persistDeliveryTask(DeliveryTaskRecord task) {
    final now = DateTime.now().toUtc().toIso8601String();
    database.db.execute(
        'UPDATE application_tasks SET status = ?, completed = ?, failed = ?, message = ?, updated_at = ? WHERE id = ? AND user_id = ?',
        [task.status, task.completed, task.failed, task.message, now, task.id, task.userId]);
  }

  void _ensureJob(String id, String platform, String title, String company) {
    final now = DateTime.now().toUtc().toIso8601String();
    database.db.execute(
        '''INSERT OR IGNORE INTO jobs(
          id, platform, external_job_id, title, company, payload_json, first_seen_at, last_seen_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
        [id, platform, id, title.isEmpty ? '未知职位' : title,
          company.isEmpty ? '未知公司' : company, '{}', now, now]);
  }

  Future<void> _createImport(HttpRequest request, String userId) async {
    final body = await _readJson(request);
    final fileName = (body['fileName'] ?? '').toString().trim();
    final contentType =
        (body['contentType'] ?? 'application/octet-stream').toString();
    final validation = _validateFileName(fileName);
    if (validation != null) {
      _json(request.response, HttpStatus.badRequest, {'error': validation});
      return;
    }
    final suffix =
        '${DateTime.now().millisecondsSinceEpoch}_${random.nextInt(1 << 32)}';
    final resumeId = 'resume_$suffix';
    final taskId = 'task_$suffix';
    final token = _randomToken();
    resumes[resumeId] = ResumeRecord(
        id: resumeId, userId: userId, fileName: fileName, contentType: contentType);
    database.db.execute(
        '''INSERT INTO resumes(id, user_id, file_name, content_type, parse_status, created_at, updated_at)
           VALUES (?, ?, ?, ?, 'uploading', ?, ?)''',
        [resumeId, userId, fileName, contentType, DateTime.now().toUtc().toIso8601String(), DateTime.now().toUtc().toIso8601String()]);
    tasks[taskId] = ParseTaskRecord(taskId: taskId, userId: userId, resumeId: resumeId);
    uploadTokens[token] = resumeId;
    _json(request.response, HttpStatus.created, {
      'resumeId': resumeId,
      'taskId': taskId,
      'uploadUrl': '/uploads/$token',
      'expiresIn': 900,
    });
  }

  Future<void> _upload(HttpRequest request, String userId, String token) async {
    final resumeId = uploadTokens[token];
    if (resumeId == null) {
      _json(request.response, HttpStatus.notFound,
          {'error': 'upload_url_invalid'});
      return;
    }
    final bytes = await _readBytesWithLimit(request, maxResumeBytes);
    if (bytes.isEmpty) {
      _json(request.response, HttpStatus.badRequest, {'error': 'empty_file'});
      return;
    }
    final resume = resumes[resumeId];
    if (resume == null || resume.userId != userId) {
      _json(request.response, HttpStatus.notFound, {'error': 'resume_not_found'});
      return;
    }
    resume.bytes = bytes;
    final task = tasks.values.firstWhere((item) => item.resumeId == resumeId);
    task.status = 'parsing';
    resume.parseStatus = 'parsing';
    database.db.execute('UPDATE resumes SET parse_status = ?, updated_at = ? WHERE id = ? AND user_id = ?',
        ['parsing', DateTime.now().toUtc().toIso8601String(), resumeId, userId]);
    task.progress = 20;
    task.message = '文件已上传，正在识别内容';
    uploadTokens.remove(token);
    _json(request.response, HttpStatus.accepted,
        {'resumeId': resumeId, 'taskId': task.taskId});
    unawaited(_parse(task, resume));
  }

  Future<void> _parse(ParseTaskRecord task, ResumeRecord resume) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    task.progress = 62;
    task.message = '正在提取工作经历、教育背景和技能';
    await Future<void>.delayed(const Duration(milliseconds: 700));
    resume.profile = demoProfile(resume.id, resume.fileName);
    resume.parseStatus = 'needsReview';
    final now = DateTime.now().toUtc().toIso8601String();
    database.db.execute('UPDATE resumes SET parse_status = ?, completeness = ?, updated_at = ? WHERE id = ? AND user_id = ?',
        [resume.parseStatus, resume.profile!.completeness, now, resume.id, resume.userId]);
    database.db.execute(
        '''INSERT INTO resume_profiles(resume_id, payload_json, version, created_at, updated_at)
           VALUES (?, ?, 1, ?, ?)
           ON CONFLICT(resume_id) DO UPDATE SET payload_json = excluded.payload_json, version = version + 1, updated_at = excluded.updated_at''',
        [resume.id, jsonEncode(resume.profile!.toJson()), now, now]);
    task.progress = resume.profile!.completeness;
    task.status = 'needsReview';
    task.message = '识别完成，请校对标记字段';
  }

  Future<void> _getTask(HttpRequest request, String userId, String taskId) async {
    // 客户端可以传 taskId；REST 路径也允许使用 resumeId，二者都兼容。
    final task = tasks[taskId] ??
        tasks.values
            .cast<ParseTaskRecord?>()
            .firstWhere((item) => item!.resumeId == taskId, orElse: () => null);
    if (task == null || task.userId != userId) {
      _json(request.response, HttpStatus.notFound, {'error': 'task_not_found'});
      return;
    }
    _json(request.response, HttpStatus.ok, task.toJson());
  }

  Future<void> _getProfile(HttpRequest request, String userId, String resumeId) async {
    final resume = resumes[resumeId];
    if (resume == null || resume.userId != userId) {
      _json(request.response, HttpStatus.notFound, {'error': 'resume_not_found'});
      return;
    }
    final profile = resume.profile;
    if (profile == null) {
      _json(request.response, HttpStatus.accepted, {'status': 'parsing'});
      return;
    }
    _json(request.response, HttpStatus.ok, profile.toJson());
  }

  Future<void> _updateProfile(HttpRequest request, String userId, String resumeId) async {
    final resume = resumes[resumeId];
    if (resume == null || resume.userId != userId || resume.profile == null) {
      _json(request.response, HttpStatus.notFound,
          {'error': 'profile_not_found'});
      return;
    }
    final body = await _readJson(request);
    try {
      resume.profile = ResumeProfile.fromJson({
        ...resume.profile!.toJson(),
        ...body,
        'id': resumeId,
        'fileName': resume.fileName
      });
      final now = DateTime.now().toUtc().toIso8601String();
      database.db.execute(
          '''INSERT INTO resume_profiles(resume_id, payload_json, version, created_at, updated_at)
             VALUES (?, ?, 1, ?, ?)
             ON CONFLICT(resume_id) DO UPDATE SET payload_json = excluded.payload_json, version = version + 1, updated_at = excluded.updated_at''',
          [resumeId, jsonEncode(resume.profile!.toJson()), now, now]);
      database.db.execute('UPDATE resumes SET completeness = ?, updated_at = ? WHERE id = ? AND user_id = ?',
          [resume.profile!.completeness, now, resumeId, userId]);
      _json(request.response, HttpStatus.ok, resume.profile!.toJson());
    } on FormatException catch (error) {
      _json(request.response, HttpStatus.badRequest,
          {'error': 'invalid_profile', 'message': error.message});
    }
  }

  Future<void> _deleteResume(HttpRequest request, String userId, String resumeId) async {
    final resume = resumes[resumeId];
    if (resume == null || resume.userId != userId) {
      _json(
          request.response, HttpStatus.notFound, {'error': 'resume_not_found'});
      return;
    }
    resumes.remove(resumeId);
    database.db.execute('DELETE FROM resumes WHERE id = ? AND user_id = ?', [resumeId, userId]);
    tasks.removeWhere((_, task) => task.resumeId == resumeId && task.userId == userId);
    uploadTokens.removeWhere((_, id) => id == resumeId);
    request.response.statusCode = HttpStatus.noContent;
    await request.response.close();
  }
}

class ResumeRecord {
  ResumeRecord(
      {required this.id, required this.userId, required this.fileName, required this.contentType});
  final String id;
  final String userId;
  final String fileName;
  final String contentType;
  List<int> bytes = const [];
  ResumeProfile? profile;
  String parseStatus = 'uploading';
}

class PlatformAccountRecord {
  PlatformAccountRecord({required this.platform});
  final String platform;
  String status = 'disconnected';
  String? displayName;
  DateTime? lastSyncedAt;
  String? message;
  Map<String, dynamic> toJson() => {
        'platform': platform,
        'status': status,
        'displayName': displayName,
        'lastSyncedAt': lastSyncedAt?.toIso8601String(),
        'message': message
      };
}

class AuthorizationSession {
  const AuthorizationSession({required this.userId, required this.platform});
  final String userId;
  final String platform;
}

class ParseTaskRecord {
  ParseTaskRecord({required this.taskId, required this.userId, required this.resumeId});
  final String taskId;
  final String userId;
  final String resumeId;
  String status = 'uploading';
  int progress = 8;
  String message = '等待文件上传';

  Map<String, dynamic> toJson() => {
        'taskId': taskId,
        'resumeId': resumeId,
        'status': status,
        'progress': progress,
        'message': message
      };
}

class DeliveryTaskRecord {
  DeliveryTaskRecord(
      {required this.id,
      required this.userId,
      required this.resumeId,
      required this.total,
      required this.jobs});
  final String id;
  final String userId;
  final String resumeId;
  final int total;
  final List<Map<String, dynamic>> jobs;
  String status = 'queued';
  int completed = 0;
  int failed = 0;
  String message = '任务已创建，等待执行';
  Map<String, dynamic> toJson() => {
        'id': id,
        'resumeId': resumeId,
        'status': status,
        'total': total,
        'completed': completed,
        'failed': failed,
        'message': message,
        'createdAt': DateTime.now().toIso8601String()
      };
}

class ResumeProfile {
  ResumeProfile(
      {required this.id,
      required this.fileName,
      required this.basic,
      required this.workExperiences,
      required this.education,
      required this.projects,
      required this.skills,
      required this.completeness,
      required this.updatedAt});
  final String id;
  final String fileName;
  final Map<String, dynamic> basic;
  final List<Map<String, dynamic>> workExperiences;
  final List<Map<String, dynamic>> education;
  final List<Map<String, dynamic>> projects;
  final List<String> skills;
  final int completeness;
  final DateTime updatedAt;

  factory ResumeProfile.fromJson(Map<String, dynamic> json) {
    return ResumeProfile(
        id: _string(json['id']),
        fileName: _string(json['fileName']),
        basic: Map<String, dynamic>.from(json['basic'] as Map? ?? const {}),
        workExperiences: _maps(json['workExperiences']),
        education: _maps(json['education']),
        projects: _maps(json['projects']),
        skills: (json['skills'] as List? ?? const [])
            .map((item) => item.toString())
            .toList(),
        completeness: (json['completeness'] as num?)?.toInt() ?? 0,
        updatedAt:
            DateTime.tryParse(_string(json['updatedAt'])) ?? DateTime.now());
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'basic': basic,
        'workExperiences': workExperiences,
        'education': education,
        'projects': projects,
        'skills': skills,
        'completeness': completeness,
        'updatedAt': updatedAt.toIso8601String()
      };
}

ResumeProfile demoProfile(String id, String fileName) => ResumeProfile(
    id: id,
    fileName: fileName,
    basic: {
      'name': '张三',
      'phone': '138****8000',
      'email': 'zhangsan@example.com',
      'city': '上海'
    },
    workExperiences: [
      {
        'company': '星河科技',
        'title': '高级 Java 开发工程师',
        'startDate': '2021.06',
        'endDate': '至今'
      },
      {
        'company': '云杉网络',
        'title': '后端开发工程师',
        'startDate': '2018.07',
        'endDate': '2021.05'
      }
    ],
    education: [
      {
        'school': '上海大学',
        'major': '计算机科学与技术',
        'degree': '本科',
        'startDate': '2014',
        'endDate': '2018'
      }
    ],
    projects: [
      {'name': '交易系统重构', 'role': '技术负责人'},
      {'name': '订单中心', 'role': '后端开发'}
    ],
    skills: ['Java', 'Spring Boot', '微服务', 'MySQL', 'Redis', 'Docker'],
    completeness: 98,
    updatedAt: DateTime.now());

String? _validateFileName(String name) {
  if (name.isEmpty || name.length > 180) return 'invalid_file_name';
  final extension =
      name.contains('.') ? name.split('.').last.toLowerCase() : '';
  if (!allowedExtensions.contains(extension)) return 'unsupported_file_type';
  if (name.contains('..') || name.contains('/') || name.contains('\\')) {
    return 'invalid_file_name';
  }
  return null;
}

String _randomToken() => List.generate(
        32,
        (_) =>
            randomTokenChars[Random.secure().nextInt(randomTokenChars.length)])
    .join();
const randomTokenChars =
    'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
String _string(Object? value) => value?.toString() ?? '';
List<Map<String, dynamic>> _maps(Object? value) => (value as List? ?? const [])
    .map((item) => Map<String, dynamic>.from(item as Map))
    .toList();

String _accountKey(String userId, String platform) => '$userId::$platform';

bool _salaryOverlaps(String value, int min, int max) {
  final match = RegExp(r'(\d+)[-~](\d+)').firstMatch(value);
  if (match == null) return true;
  final low = int.tryParse(match.group(1)!) ?? 0;
  final high = int.tryParse(match.group(2)!) ?? 999;
  return high >= min && low <= max;
}

Future<Map<String, dynamic>> _readJson(HttpRequest request) async {
  final raw = await utf8.decoder.bind(request).join();
  if (raw.isEmpty) return {};
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('JSON object required');
  }
  return decoded;
}

Future<List<int>> _readBytesWithLimit(HttpRequest request, int limit) async {
  final output = <int>[];
  await for (final chunk in request) {
    output.addAll(chunk);
    if (output.length > limit) throw const FormatException('file_too_large');
  }
  return output;
}

void _cors(HttpResponse response) {
  response.headers
    ..set('access-control-allow-origin', '*')
    ..set('access-control-allow-methods', 'GET,POST,PUT,PATCH,DELETE,OPTIONS')
    ..set('access-control-allow-headers', 'Content-Type,Authorization,X-User-Id');
}

void _json(HttpResponse response, int status, Object body) {
  response.statusCode = status;
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(body));
  response.close();
}
