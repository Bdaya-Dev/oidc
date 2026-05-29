/// [JSON Web Encryption](https://tools.ietf.org/html/rfc7516)
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'ecdh.dart';
import 'jose.dart';
import 'jwk.dart';
import 'util.dart';

/// JSON Web Encryption (JWE) represents encrypted content using JSON-based data
/// structures
class JsonWebEncryption extends JoseObject {
  /// Initialization Vector value used when encrypting the plaintext.
  ///
  /// Note that some algorithms may not use an Initialization Vector, in which
  /// case this value is the empty octet sequence.
  final List<int> initializationVector;

  /// Additional value to be integrity protected by the authenticated encryption
  /// operation.
  ///
  /// This can only be present when using the JWE JSON Serialization.
  ///
  /// Note that this can also be achieved when using either the JWE Compact
  /// Serialization or the JWE JSON Serialization by including the AAD value as
  /// an integrity-protected Header Parameter value, but at the cost of the
  /// value being double base64url encoded.
  final List<int>? additionalAuthenticatedData;

  /// Authentication Tag value resulting from authenticated encryption of the
  /// plaintext with Additional Authenticated Data.
  final List<int> authenticationTag;

  JsonWebEncryption._(
    super.data,
    List<_JweRecipient> super.recipients, {
    JsonObject? protectedHeader,
    JsonObject? unprotectedHeader,
    this.initializationVector = const [],
    this.additionalAuthenticatedData,
    this.authenticationTag = const [],
  }) : super(
            sharedProtectedHeader: protectedHeader,
            sharedUnprotectedHeader: unprotectedHeader);

  /// Constructs a [JsonWebEncryption] from its compact serialization
  factory JsonWebEncryption.fromCompactSerialization(String serialization) {
    var parts = serialization.split('.');
    if (parts.length != 5) {
      throw ArgumentError.value(
          serialization, 'Compact serialization should have 5 parts.');
    }
    return JsonWebEncryption._(
        decodeBase64EncodedBytes(parts[3]),
        List.unmodifiable([
          _JweRecipient._(encryptedKey: decodeBase64EncodedBytes(parts[1]))
        ]),
        protectedHeader: JsonObject.decode(parts[0]),
        initializationVector: decodeBase64EncodedBytes(parts[2]),
        authenticationTag: decodeBase64EncodedBytes(parts[4]));
  }

  /// Constructs a [JsonWebEncryption] from its flattened or general JSON
  /// representation
  JsonWebEncryption.fromJson(Map<String, dynamic> json)
      : this._(
          decodeBase64EncodedBytes(json['ciphertext']),
          // Determine recipients according to RFC7516 general/flattened or
          // fallback when neither recipients nor header are present.
          List.unmodifiable(() {
            if (json.containsKey('recipients')) {
              // General JSON Serialization
              return (json['recipients'] as List).map(
                (v) => _JweRecipient._(
                  header:
                      v['header'] == null ? null : JsonObject.from(v['header']),
                  encryptedKey: decodeBase64EncodedBytes(v['encrypted_key']),
                ),
              );
            }
            var encryptedKey = json.containsKey('encrypted_key')
                ? decodeBase64EncodedBytes(json['encrypted_key'])
                : <int>[];

            if (json.containsKey('header')) {
              // Flattened JSON Serialization (header present)
              var hdr = json['header'];
              return [
                _JweRecipient._(
                  header: hdr == null ? null : JsonObject.from(hdr),
                  encryptedKey: encryptedKey,
                ),
              ];
            }
            // (Do not treat presence of only 'encrypted_key' as flattened; fall back to protected header derivation)
            // Fallback: No recipients array and no per-recipient header.
            // Try to derive necessary information from protected header.
            // This supports cases where all header parameters (alg, enc, kid, ...)
            // are only present in the protected header.
            var protectedHeader = json['protected'];
            if (protectedHeader == null) {
              throw ArgumentError('Missing protected header for JWE');
            }
            // We still build a single recipient to keep internal model consistent.
            // encrypted_key may be legitimately absent for direct encryption (alg == 'dir').
            JsonObject? derivedRecipientHeader;
            var phDecoded = JsonObject.decode(protectedHeader);
            var alg = phDecoded['alg'];
            var kid = phDecoded['kid'];
            if (alg != null) {
              // Populate derived recipient header so downstream logic finds per-recipient alg
              derivedRecipientHeader = JsonObject.from({
                'alg': alg,
                if (kid != null) 'kid': kid,
              });
            }

            // Encrypted key must be present unless alg == 'dir' or 'ECDH-ES'.
            if (encryptedKey.isEmpty &&
                alg != null &&
                alg != 'dir' &&
                alg != 'ECDH-ES') {
              throw ArgumentError('Missing encrypted_key for algorithm "$alg"');
            }

            return [
              _JweRecipient._(
                header: derivedRecipientHeader,
                encryptedKey: encryptedKey,
              ),
            ];
          }()),
          protectedHeader: JsonObject.decode(json['protected']),
          unprotectedHeader: json['unprotected'] == null
              ? null
              : JsonObject.from(json['unprotected']),
          initializationVector: decodeBase64EncodedBytes(json['iv']),
          additionalAuthenticatedData: json['aad'] == null
              ? null
              : decodeBase64EncodedBytes(json['aad']),
          authenticationTag: decodeBase64EncodedBytes(json['tag']),
        );

  @override
  String toCompactSerialization() {
    if (recipients.length != 1) {
      throw StateError(
          'Compact serialization does not support multiple recipients');
    }
    if (sharedUnprotectedHeader != null) {
      throw StateError(
          'Compact serialization does not support shared unprotected header');
    }
    var recipient = recipients.first;
    if (recipient.unprotectedHeader != null) {
      throw StateError(
          'Compact serialization does not support unprotected header parameters');
    }
    return '${sharedProtectedHeader!.toBase64EncodedString()}.'
        '${encodeBase64EncodedBytes(recipient.data)}.'
        '${encodeBase64EncodedBytes(initializationVector)}.'
        '${encodeBase64EncodedBytes(data)}.'
        '${encodeBase64EncodedBytes(authenticationTag)}';
  }

  @override
  Map<String, dynamic> toJson() {
    var aad = additionalAuthenticatedData;
    var v = {
      'protected': sharedProtectedHeader?.toBase64EncodedString(),
      'unprotected': sharedUnprotectedHeader?.toJson(),
      'iv': encodeBase64EncodedBytes(initializationVector),
      if (aad != null) 'aad': encodeBase64EncodedBytes(aad),
      'ciphertext': encodeBase64EncodedBytes(data),
      'tag': encodeBase64EncodedBytes(authenticationTag),
    };
    if (recipients.length == 1) {
      v.addAll(recipients.first.toJson());
    } else {
      v['recipients'] = recipients.map((r) => r.toJson()).toList();
    }
    return Map.fromEntries(v.entries.where((e) => e.value != null));
  }

  @override
  List<int>? getPayloadFor(
    JsonWebKey? key,
    JoseHeader header,
    JoseRecipient recipient,
  ) {
    if (key == null) {
      return null;
    }

    var aad = sharedProtectedHeader?.toBase64EncodedString() ?? '';
    if (additionalAuthenticatedData != null) {
      aad += '.${String.fromCharCodes(additionalAuthenticatedData!)}';
    }
    if (header.encryptionAlgorithm == 'none') {
      throw JoseException('Encryption algorithm cannot be `none`');
    }

    JsonWebKey cek;
    if (header.algorithm == 'dir') {
      cek = key;
    } else if (header.algorithm != null &&
        header.algorithm!.startsWith('ECDH-ES')) {
      // ECDH-ES key agreement
      final epk = header.ephemeralPublicKey;
      if (epk == null) {
        throw JoseException('Missing ephemeral public key (epk) in header');
      }
      final encAlgorithm = header.encryptionAlgorithm!;
      final algId = ecdhAlgorithmId(header.algorithm!, encAlgorithm);
      final keyLen = ecdhKeyDataLen(header.algorithm!, encAlgorithm);

      final apu = header.agreementPartyUInfo != null
          ? Uint8List.fromList(
              decodeBase64EncodedBytes(header.agreementPartyUInfo!))
          : null;
      final apv = header.agreementPartyVInfo != null
          ? Uint8List.fromList(
              decodeBase64EncodedBytes(header.agreementPartyVInfo!))
          : null;

      final derivedKey = ecdhEsDecrypt(
        recipientPrivateKey: key,
        ephemeralPublicKey: epk,
        algorithmId: algId,
        keyDataLen: keyLen,
        apu: apu,
        apv: apv,
      );

      if (header.algorithm == 'ECDH-ES') {
        // Direct key agreement — derived key IS the CEK
        cek = JsonWebKey.fromJson({
          'kty': 'oct',
          'k': encodeBase64EncodedBytes(derivedKey),
          'use': 'enc',
          'key_ops': ['encrypt', 'decrypt'],
        })!;
      } else {
        // ECDH-ES+A*KW — derived key unwraps the CEK
        final unwrappedCekBytes = ecdhEsUnwrapKey(derivedKey, recipient.data);
        cek = JsonWebKey.fromJson({
          'kty': 'oct',
          'k': encodeBase64EncodedBytes(unwrappedCekBytes),
          'use': 'enc',
          'key_ops': ['encrypt', 'decrypt'],
        })!;
      }
    } else {
      cek = key.unwrapKey(recipient.data, algorithm: header.algorithm);
    }

    var uncompressed = cek.decrypt(data,
        initializationVector: initializationVector,
        additionalAuthenticatedData: Uint8List.fromList(aad.codeUnits),
        authenticationTag: authenticationTag,
        algorithm: header.encryptionAlgorithm);
    switch (header.compressionAlgorithm) {
      case null:
        return uncompressed;
      case 'DEF':
        return Inflate(uncompressed).getBytes();
      default:
        throw JoseException(
            'Unsupported compression algorithm ${header.compressionAlgorithm}');
    }
  }
}

class _JweRecipient extends JoseRecipient {
  _JweRecipient._({JsonObject? header, required List<int> encryptedKey})
      : super(unprotectedHeader: header, data: encryptedKey);

  @override
  Map<String, dynamic> toJson() => {
        'header': unprotectedHeader?.toJson(),
        'encrypted_key': encodeBase64EncodedBytes(data)
      };
}

/// Builder for [JsonWebSignature]
class JsonWebEncryptionBuilder extends JoseObjectBuilder<JsonWebEncryption> {
  /// Additional value to be integrity protected by the authenticated encryption
  /// operation.
  List<int>? additionalAuthenticatedData;

  /// The content encryption algorithm to be used to perform authenticated
  /// encryption on the plaintext to produce the ciphertext and the
  /// Authentication Tag.
  String? encryptionAlgorithm = 'A128CBC-HS256';

  /// The compression algorithm to be used to compress the plaintext before
  /// encryption.
  String? compressionAlgorithm;

  @override
  JsonWebEncryption build() {
    if (encryptionAlgorithm == null) {
      throw StateError('No encryption algorithm set');
    }
    if (encryptionAlgorithm == 'none') {
      throw StateError('Encryption algorithm cannot be `none`');
    }
    if (recipients.isEmpty) {
      throw StateError('Need at least one recipient');
    }
    var payload = this.payload;
    if (payload == null) {
      throw StateError('No payload set');
    }

    var compact = recipients.length == 1 && additionalAuthenticatedData == null;

    var cek = JsonWebKey.generate(encryptionAlgorithm);
    var sharedUnprotectedHeaderParams = <String, dynamic>{
      'enc': encryptionAlgorithm,
      if (compressionAlgorithm != null) 'zip': compressionAlgorithm,
    };

    var recipientsMapped = recipients.map((r) {
      var key = r['_jwk'] as JsonWebKey;
      var algorithm = r['alg'] ?? key.algorithmForOperation('wrapKey') ?? 'dir';

      List<int> encryptedKey;
      var unprotectedHeaderParams = <String, dynamic>{'alg': algorithm};

      if (algorithm == 'dir') {
        if (recipients.length > 1) {
          throw StateError(
              'JWE can only have one recipient when using direct encryption with a shared symmetric key.');
        }
        final k = JsonWebKey.fromJson({
          'alg': encryptionAlgorithm,
          ...key.toJson(),
        });
        if (k == null) {
          throw UnimplementedError('Unkown key.');
        }
        cek = k;
        encryptedKey = const <int>[];
      } else if (algorithm.startsWith('ECDH-ES')) {
        // ECDH-ES key agreement
        final algId = ecdhAlgorithmId(algorithm, encryptionAlgorithm!);
        final keyLen = ecdhKeyDataLen(algorithm, encryptionAlgorithm!);

        final result = ecdhEsDerive(
          recipientPublicKey: key,
          algorithmId: algId,
          keyDataLen: keyLen,
        );

        // Add EPK to header
        unprotectedHeaderParams['epk'] = result.ephemeralPublicKey.toJson();

        if (algorithm == 'ECDH-ES') {
          // Direct key agreement — derived key IS the CEK
          if (recipients.length > 1) {
            throw StateError(
                'JWE can only have one recipient when using ECDH-ES direct key agreement.');
          }
          cek = JsonWebKey.fromJson({
            'kty': 'oct',
            'k': encodeBase64EncodedBytes(result.derivedKey),
            'use': 'enc',
            'alg': encryptionAlgorithm,
            'key_ops': ['encrypt', 'decrypt'],
          })!;
          encryptedKey = const <int>[];
        } else {
          // ECDH-ES+A*KW — derived key wraps the CEK
          encryptedKey = ecdhEsWrapKey(result.derivedKey, cek);
        }
      } else {
        encryptedKey = key.wrapKey(cek, algorithm: algorithm);
      }
      if (key.keyId != null) {
        unprotectedHeaderParams['kid'] = key.keyId;
      }
      if (compact) {
        sharedUnprotectedHeaderParams.addAll(unprotectedHeaderParams);
      }

      return _JweRecipient._(
          encryptedKey: encryptedKey,
          header: compact ? null : JsonObject.from(unprotectedHeaderParams));
    }).toList();

    var protectedHeader = payload.protectedHeader;
    if (compact) {
      protectedHeader = JsonObject.from(safeUnion(
          [protectedHeader?.toJson(), sharedUnprotectedHeaderParams]));
    }
    var aad = protectedHeader!.toBase64EncodedString();
    if (additionalAuthenticatedData != null) {
      aad += '.${String.fromCharCodes(additionalAuthenticatedData!)}';
    }

    // RFC 7518 requires that a 96 bit iv is used with AESGCM and cjose insists
    var iv = (encryptionAlgorithm != null &&
            encryptionAlgorithm!.contains(RegExp('A[0-9][0-9][0-9]GCM')))
        ? Uint8List.fromList(
            List.generate(12, (_) => Random.secure().nextInt(256)))
        : null;

    var data = this.data!;

    switch (compressionAlgorithm) {
      case null:
        break;
      case 'DEF':
        data = Deflate(data).getBytes();
        break;
      default:
        throw JoseException(
            'Unsupported compression algorithm $compressionAlgorithm');
    }

    var encryptedData = cek.encrypt(data,
        initializationVector: iv,
        additionalAuthenticatedData: Uint8List.fromList(aad.codeUnits));
    return JsonWebEncryption._(encryptedData.data, recipientsMapped,
        protectedHeader: protectedHeader,
        unprotectedHeader:
            compact ? null : JsonObject.from(sharedUnprotectedHeaderParams),
        initializationVector: encryptedData.initializationVector!,
        authenticationTag: encryptedData.authenticationTag!,
        additionalAuthenticatedData: additionalAuthenticatedData);
  }
}
