enum PlatformConnectionStatus {
  disconnected,
  authorizing,
  connected,
  expired,
  error
}

class PlatformAccount {
  const PlatformAccount(
      {required this.platform,
      required this.status,
      this.displayName,
      this.lastSyncedAt,
      this.message});
  final String platform;
  final PlatformConnectionStatus status;
  final String? displayName;
  final DateTime? lastSyncedAt;
  final String? message;
  bool get isConnected => status == PlatformConnectionStatus.connected;
}

abstract interface class PlatformAccountRepository {
  Future<List<PlatformAccount>> getAccounts();
  Future<String> beginAuthorization(String platform);
  Future<PlatformAccount> completeAuthorization(String authorizationId);
  Future<void> disconnect(String platform);
}
