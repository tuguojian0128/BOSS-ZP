import '../../../core/network/api_client.dart';
import '../domain/platform_account_repository.dart';

class RestPlatformAccountRepository implements PlatformAccountRepository {
  RestPlatformAccountRepository(this.api);
  final ApiClient api;

  @override
  Future<List<PlatformAccount>> getAccounts() async {
    final json = await api.getJson('/api/v1/platform-accounts');
    final list = json['items'] is List ? json['items'] as List : const [];
    return list
        .map((item) => _fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  @override
  Future<String> beginAuthorization(String platform) async {
    final json = await api.postJson(
        '/api/v1/platform-accounts/${Uri.encodeComponent(platform)}/authorize');
    return json['authorizationUrl'].toString();
  }

  @override
  Future<PlatformAccount> completeAuthorization(String authorizationId) async {
    final json = await api.getJson('/api/v1/platform-accounts/callback',
        query: {'state': authorizationId});
    return _fromJson(json);
  }

  @override
  Future<void> disconnect(String platform) async {
    await api.postJson(
        '/api/v1/platform-accounts/${Uri.encodeComponent(platform)}/disconnect');
  }

  PlatformAccount _fromJson(Map<String, dynamic> json) => PlatformAccount(
      platform: json['platform'].toString(),
      status: PlatformConnectionStatus.values.firstWhere(
          (item) => item.name == json['status'],
          orElse: () => PlatformConnectionStatus.error),
      displayName: json['displayName']?.toString(),
      lastSyncedAt: DateTime.tryParse(json['lastSyncedAt']?.toString() ?? ''),
      message: json['message']?.toString());
}
