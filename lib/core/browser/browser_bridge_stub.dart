class BrowserBridge {
  bool get isAvailable => false;
  Future<Map<String, dynamic>?> request(String action,
      [Map<String, dynamic> payload = const {}]) async => null;
}
