import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Hashes passwords with PBKDF2-HMAC-SHA256 and a random per-user salt.
///
/// This keeps raw passwords out of local storage. It is still demo-grade:
/// 20,000 iterations is lighter than production recommendations, and
/// shared_preferences itself is neither encrypted nor a real auth backend.
/// A production app should authenticate against a server that uses a
/// dedicated password-hashing algorithm such as Argon2id or bcrypt.
class PasswordHasher {
  PasswordHasher._();

  static const int _iterations = 20000;
  static const int _saltLengthInBytes = 16;
  static const int _keyLengthInBytes = 32;
  static const int _blockSizeInBytes = 32;

  static String hash(String password) {
    final Uint8List salt = _generateSalt();
    final Uint8List derivedKey = _pbkdf2(
      password: password,
      salt: salt,
      iterations: _iterations,
      keyLength: _keyLengthInBytes,
    );

    return '${base64Encode(salt)}:${base64Encode(derivedKey)}';
  }

  static bool verify(String password, String storedHash) {
    final List<String> parts = storedHash.split(':');
    if (parts.length != 2) {
      return false;
    }

    try {
      final Uint8List salt = base64Decode(parts[0]);
      final Uint8List expectedKey = base64Decode(parts[1]);
      final Uint8List actualKey = _pbkdf2(
        password: password,
        salt: salt,
        iterations: _iterations,
        keyLength: expectedKey.length,
      );

      return _constantTimeEquals(actualKey, expectedKey);
    } on FormatException {
      return false;
    }
  }

  static Uint8List _generateSalt() {
    final Random random = Random.secure();
    final Uint8List salt = Uint8List(_saltLengthInBytes);
    for (int i = 0; i < salt.length; i++) {
      salt[i] = random.nextInt(256);
    }
    return salt;
  }

  static Uint8List _pbkdf2({
    required String password,
    required Uint8List salt,
    required int iterations,
    required int keyLength,
  }) {
    final Hmac hmac = Hmac(sha256, utf8.encode(password));
    final int blockCount = (keyLength / _blockSizeInBytes).ceil();
    final BytesBuilder derivedKey = BytesBuilder();

    for (int block = 1; block <= blockCount; block++) {
      final Uint8List blockIndex = Uint8List(4)
        ..buffer.asByteData().setUint32(0, block, Endian.big);

      List<int> u = hmac.convert(<int>[...salt, ...blockIndex]).bytes;
      final List<int> blockKey = List<int>.from(u);

      for (int iteration = 1; iteration < iterations; iteration++) {
        u = hmac.convert(u).bytes;
        for (int i = 0; i < blockKey.length; i++) {
          blockKey[i] ^= u[i];
        }
      }

      derivedKey.add(blockKey);
    }

    return Uint8List.fromList(
      derivedKey.toBytes().sublist(0, keyLength),
    );
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) {
      return false;
    }

    int difference = 0;
    for (int i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }
}
