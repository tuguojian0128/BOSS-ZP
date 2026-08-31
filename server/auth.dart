import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

/// Authentication primitives shared by the HTTP service.
///
/// Access tokens are short-lived JWTs. Refresh tokens are opaque values and
/// must only be persisted as hashes by the caller.
class AuthService {
  AuthService({String? secret})
      : _secret = utf8.encode(secret ??
            Platform.environment['JWT_SECRET'] ??
            'development-only-change-this-jwt-secret');

  final List<int> _secret;
  static const accessTokenLifetime = Duration(minutes: 15);
  static const refreshTokenLifetime = Duration(days: 30);
  static const _passwordIterations = 120000;
  static const _saltBytes = 16;

  PasswordDigest hashPassword(String password, {String? salt}) {
    if (password.length < 8) {
      throw const FormatException('password_too_short');
    }
    final saltValue = salt ?? _randomBytes(_saltBytes);
    List<int> block = utf8.encode('$saltValue:$password');
    for (var i = 0; i < _passwordIterations; i++) {
      block = crypto.sha256.convert(block).bytes;
    }
    return PasswordDigest(salt: saltValue, hash: _hex(block));
  }

  bool verifyPassword(String password, String salt, String expectedHash) {
    final actual = hashPassword(password, salt: salt).hash;
    return _constantTimeEquals(actual, expectedHash);
  }

  IssuedTokens issueTokens(String userId, {DateTime? now}) {
    final issuedAt = now ?? DateTime.now().toUtc();
    final accessExpires = issuedAt.add(accessTokenLifetime);
    final refreshExpires = issuedAt.add(refreshTokenLifetime);
    final access = _encodeJwt({
      'sub': userId,
      'iat': issuedAt.millisecondsSinceEpoch ~/ 1000,
      'exp': accessExpires.millisecondsSinceEpoch ~/ 1000,
      'type': 'access',
    });
    final refresh = _randomToken(48);
    return IssuedTokens(
      accessToken: access,
      refreshToken: refresh,
      accessExpiresAt: accessExpires,
      refreshExpiresAt: refreshExpires,
    );
  }

  AuthClaims? verifyAccessToken(String token, {DateTime? now}) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final signingInput = '${parts[0]}.${parts[1]}';
      final expected = _base64Url(crypto.Hmac(crypto.sha256, _secret)
          .convert(utf8.encode(signingInput))
          .bytes);
      if (!_constantTimeEquals(expected, parts[2])) return null;
      final payload = jsonDecode(utf8.decode(_decodeBase64(parts[1])));
      if (payload is! Map) return null;
      if (payload['type'] != 'access') return null;
      final userId = payload['sub']?.toString() ?? '';
      final exp = int.tryParse(payload['exp']?.toString() ?? '') ?? 0;
      final iat = int.tryParse(payload['iat']?.toString() ?? '') ?? 0;
      final current = (now ?? DateTime.now().toUtc()).millisecondsSinceEpoch ~/ 1000;
      if (userId.isEmpty || exp <= current || iat > current + 60) return null;
      return AuthClaims(userId: userId, issuedAt: iat, expiresAt: exp);
    } catch (_) {
      return null;
    }
  }

  String hashRefreshToken(String token) =>
      _hex(crypto.sha256.convert(utf8.encode(token)).bytes);

  String _encodeJwt(Map<String, dynamic> payload) {
    const header = {'alg': 'HS256', 'typ': 'JWT'};
    final encodedHeader = _base64Url(utf8.encode(jsonEncode(header)));
    final encodedPayload = _base64Url(utf8.encode(jsonEncode(payload)));
    final input = '$encodedHeader.$encodedPayload';
    final signature = crypto.Hmac(crypto.sha256, _secret)
        .convert(utf8.encode(input))
        .bytes;
    return '$input.${_base64Url(signature)}';
  }
}

class PasswordDigest {
  const PasswordDigest({required this.salt, required this.hash});
  final String salt;
  final String hash;
}

class IssuedTokens {
  const IssuedTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.accessExpiresAt,
    required this.refreshExpiresAt,
  });
  final String accessToken;
  final String refreshToken;
  final DateTime accessExpiresAt;
  final DateTime refreshExpiresAt;
}

class AuthClaims {
  const AuthClaims({
    required this.userId,
    required this.issuedAt,
    required this.expiresAt,
  });
  final String userId;
  final int issuedAt;
  final int expiresAt;
}

String _base64Url(List<int> bytes) => base64UrlEncode(bytes).replaceAll('=', '');

List<int> _decodeBase64(String value) {
  final padded = value.padRight((value.length + 3) ~/ 4 * 4, '=');
  return base64Url.decode(padded);
}

String _hex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

bool _constantTimeEquals(String a, String b) {
  final aBytes = Uint8List.fromList(utf8.encode(a));
  final bBytes = Uint8List.fromList(utf8.encode(b));
  var diff = aBytes.length ^ bBytes.length;
  final length = min(aBytes.length, bBytes.length);
  for (var i = 0; i < length; i++) {
    diff |= aBytes[i] ^ bBytes[i];
  }
  return diff == 0;
}

String _randomToken(int length) {
  const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_';
  final random = Random.secure();
  return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
}

String _randomBytes(int length) {
  final random = Random.secure();
  return List.generate(length, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}
