import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../data/rest_auth_repository.dart';
import '../domain/auth_repository.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.builder});
  final WidgetBuilder builder;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final api = ApiClient();
  late final RestAuthRepository repository = RestAuthRepository(api);
  AuthSession? session;

  @override
  Widget build(BuildContext context) {
    final current = session;
    if (current != null) return widget.builder(context);
    return LoginPage(
      repository: repository,
      onAuthenticated: (value) => setState(() => session = value),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.repository, required this.onAuthenticated});
  final AuthRepository repository;
  final ValueChanged<AuthSession> onAuthenticated;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final identifier = TextEditingController(text: '13800138000');
  final password = TextEditingController(text: 'demo-password');
  final displayName = TextEditingController();
  bool registering = false;
  bool loading = false;
  String? error;

  @override
  void dispose() {
    identifier.dispose();
    password.dispose();
    displayName.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (loading) return;
    setState(() { loading = true; error = null; });
    try {
      final result = registering
          ? await widget.repository.register(
              identifier: identifier.text.trim(),
              password: password.text,
              displayName: displayName.text.trim(),
            )
          : await widget.repository.login(
              identifier: identifier.text.trim(), password: password.text);
      if (mounted) widget.onAuthenticated(result);
    } catch (exception) {
      if (mounted) setState(() => error = _message(exception));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.auto_awesome, size: 42, color: Color(0xFF007AFF)),
                  const SizedBox(height: 14),
                  Text(registering ? '创建求职工作台账号' : '登录求职工作台', textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(registering ? '注册后，你的简历、平台账号和投递记录将独立保存' : '登录后继续管理简历与自动投递任务', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF64748B))),
                  const SizedBox(height: 24),
                  TextField(controller: identifier, decoration: const InputDecoration(labelText: '手机号或邮箱')),
                  if (registering) ...[
                    const SizedBox(height: 12),
                    TextField(controller: displayName, decoration: const InputDecoration(labelText: '显示名称')),
                  ],
                  const SizedBox(height: 12),
                  TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: '密码（至少 8 位）')),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(error!, style: const TextStyle(color: Color(0xFFDC2626))),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(onPressed: loading ? null : submit, child: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(registering ? '注册并登录' : '登录')),
                  TextButton(onPressed: loading ? null : () => setState(() { registering = !registering; error = null; }), child: Text(registering ? '已有账号，返回登录' : '创建新账号')),
                  if (!registering) const Text('开发演示账号：13800138000 / demo-password', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _message(Object exception) {
    final text = exception.toString();
    if (text.contains('invalid_credentials')) return '手机号/邮箱或密码不正确';
    if (text.contains('account_already_exists')) return '账号已存在，请直接登录';
    if (text.contains('password_too_short')) return '密码至少需要 8 位';
    if (text.contains('display_name_required')) return '请输入显示名称';
    return '操作失败，请检查后端服务是否已启动';
  }
}
