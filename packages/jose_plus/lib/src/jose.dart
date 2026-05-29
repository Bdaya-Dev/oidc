/// [JSON Object Signing and Encryption](https://tools.ietf.org/html/rfc7515)
library;

import 'util.dart';
import 'jws.dart';
import 'jwe.dart';
import 'jwk.dart';
import 'dart:async';
import 'dart:convert' as convert;
import 'package:meta/meta.dart';

/// Contains the `JSON Object Signing and Encryption` header parameters for
/// [JsonWebSignature] and [JsonWebEncryption]
class JoseHeader extends JsonObject {
  /// Constructs a [JoseHeader] from a [json] map
  JoseHeader.fromJson(Map<String, dynamic> super.json) : super.from();

  /// Constructs a [JoseHeader] from a base64 [encodedString] representation of
  /// the json string
  JoseHeader.fromBase64EncodedString(super.encodedString) : super.decode();

  /// Identifies the cryptographic algorithm used to secure a [JsonWebSignature]
  /// or to encrypt or determine the value of a Content Encryption Key with
  /// [JsonWebEncryption].
  String? get algorithm => getTyped('alg');

  /// Refers to a resource for a set of JSON-encoded public keys, one of which
  /// corresponds to the key used to digitally sign the [JsonWebSignature] or
  /// encrypt the [JsonWebEncryption].
  Uri? get jwkSetUrl => getTyped('jku');

  /// The public key that corresponds to the key used to digitally sign the
  /// [JsonWebSignature] or encrypt the [JsonWebEncryption].
  JsonWebKey? get jsonWebKey =>
      getTyped<JsonWebKey?>('jwk', factory: (v) => JsonWebKey.fromJson(v));

  /// A hint indicating which key was used to secure the [JsonWebSignature] or
  /// encrypt the [JsonWebEncryption].
  String? get keyId => getTyped('kid');

/*
  TODO: implement X.509

  /// Refers to a resource for the X.509 public key certificate or certificate
  /// chain corresponding to the key used to digitally sign the
  /// [JsonWebSignature] or encrypt the [JsonWebEncryption].
  Uri get x509Url => this['x5u'] == null ? null : Uri.parse(this['x5u']);

  /// The X.509 public key certificate or certificate chain [RFC5280]
  /// corresponding to the key used to digitally sign the
  /// [JsonWebSignature] or encrypt the [JsonWebEncryption].
  dynamic get x509CertificateChain => this['x5c'];

  /// A base64url-encoded SHA-1 thumbprint (a.k.a. digest) of the DER
  /// encoding of the X.509 certificate corresponding to the key used to
  /// digitally sign the [JsonWebSignature] or encrypt the [JsonWebEncryption].
  String get x509CertificateSha1Thumbprint => this['x5t'];

  /// A base64url-encoded SHA-256 thumbprint (a.k.a. digest) of the DER
  /// encoding of the X.509 certificate corresponding to the key used to
  /// digitally sign the [JsonWebSignature] or encrypt the [JsonWebEncryption].
  String get x509CertificateSha256Thumbprint => this['x5t#S256'];
*/

  /// Declares the media type [IANA.MediaTypes](https://www.iana.org/assignments/media-types/media-types.xhtml)
  /// of the complete [JsonWebSignature] or [JsonWebEncryption].
  String? get type => getTyped('typ');

  /// Declares the media type [IANA.MediaTypes](https://www.iana.org/assignments/media-types/media-types.xhtml)
  /// the secured content (the payload) of the [JsonWebSignature] or
  /// [JsonWebEncryption].
  String? get contentType => getTyped('cty');

  /// Indicates that extensions to this specification and/or [JsonWebAlgorithm]
  /// are being used that MUST be understood and processed.
  List<String>? get critical => getTyped('crit');

  /// The content encryption algorithm used to perform authenticated encryption
  /// on the plaintext to produce the ciphertext and the Authentication Tag.
  ///
  /// Only for [JsonWebEncryption] objects
  String? get encryptionAlgorithm => getTyped('enc');

  /// Compression algorithm applied to the plaintext before encryption, if any.
  ///
  /// Only for [JsonWebEncryption] objects
  String? get compressionAlgorithm => getTyped('zip');

  /// The ephemeral public key for ECDH key agreement.
  ///
  /// Only for [JsonWebEncryption] objects using ECDH-ES algorithms.
  JsonWebKey? get ephemeralPublicKey =>
      getTyped<JsonWebKey?>('epk', factory: (v) => JsonWebKey.fromJson(v));

  /// Agreement PartyUInfo value for ECDH key agreement.
  ///
  /// Only for [JsonWebEncryption] objects using ECDH-ES algorithms.
  String? get agreementPartyUInfo => getTyped('apu');

  /// Agreement PartyVInfo value for ECDH key agreement.
  ///
  /// Only for [JsonWebEncryption] objects using ECDH-ES algorithms.
  String? get agreementPartyVInfo => getTyped('apv');
}

/// Base class for [JsonWebSignature] and [JsonWebEncryption].
abstract class JoseObject {
  /// The binary data contained in this object
  ///
  /// In case of a [JsonWebSignature], this is the plain content, in case of a
  /// [JsonWebEncryption], this is the ciphertext.
  final List<int> data;

  /// The per-recipient content of this object
  final List<JoseRecipient> recipients;

  /// Header parameters that are integrity protected and shared by all
  /// recipients
  ///
  /// [JsonWebSignature] objects do not have a shared protected header
  final JsonObject? sharedProtectedHeader;

  /// Header parameters that are not integrity protected and are shared by all
  /// recipients
  ///
  /// [JsonWebSignature] objects do not have a shared unprotected header
  final JsonObject? sharedUnprotectedHeader;

  JoseObject(this.data, this.recipients,
      {this.sharedUnprotectedHeader, this.sharedProtectedHeader});

  /// Constructs a [JsonWebSignature] or [JsonWebEncryption] from its json
  /// representation.
  factory JoseObject.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('payload')) return JsonWebSignature.fromJson(json);
    if (json.containsKey('ciphertext')) return JsonWebEncryption.fromJson(json);
    throw ArgumentError.value(
        json, 'json', 'Not a valid `JsonWebSignature` or `JsonWebEncryption`');
  }

  /// Constructs a [JsonWebSignature] or [JsonWebEncryption] from its compact
  /// serialization.
  factory JoseObject.fromCompactSerialization(String serialization) {
    var parts = serialization.split('.');
    switch (parts.length) {
      case 3:
        return JsonWebSignature.fromCompactSerialization(serialization);
      case 5:
        return JsonWebEncryption.fromCompactSerialization(serialization);
      default:
        throw ArgumentError.value(serialization, 'serialization',
            'Not a valid `JsonWebSignature` or `JsonWebEncryption`');
    }
  }

  /// Serializes the [JsonWebSignature] or [JsonWebEncryption] to a string.
  ///
  /// Throws an exception when object cannot be serialized to its compact form,
  /// i.e. when the [JsonWebSignature] has multiple signatures or the
  /// [JsonWebEncryption] has multiple recipients.
  String toCompactSerialization();

  /// Serializes the [JsonWebSignature] or [JsonWebEncryption] to a JSON
  /// representation.
  ///
  /// For [JsonWebSignature], returns a flattened JSON serialization when it
  /// contains only one signature and a general JSON serialization otherwise.
  Map<String, dynamic> toJson();

  /// The JOSE header
  ///
  /// In case of multiple recipients, this header is composed of the shared
  /// header parameters and the per-recipient header parameters that are common.
  /// In case of a single recipient, this contains all header parameters.
  JoseHeader get commonHeader {
    var sharedHeader = safeUnion(
        [sharedProtectedHeader?.toJson(), sharedUnprotectedHeader?.toJson()]);
    return JoseHeader.fromJson(commonUnion(recipients.map((r) => safeUnion([
          sharedHeader,
          r.protectedHeader?.toJson(),
          r.unprotectedHeader?.toJson()
        ]))));
  }

  /// The JOSE header parameters that are integrity protected
  ///
  /// In case of multiple recipients, this header is composed of the shared
  /// protected header parameters and the per-recipient protected header
  /// parameters that are common.
  /// In case of a single recipient, this contains all protected header
  /// parameters.
  JoseHeader get commonProtectedHeader {
    var sharedHeader = sharedProtectedHeader?.toJson();
    return JoseHeader.fromJson(commonUnion(recipients.map((r) => safeUnion([
          sharedHeader,
          r.protectedHeader?.toJson(),
        ]))));
  }

  Future<bool> verify(JsonWebKeyStore keyStore) async {
    try {
      await getPayload(keyStore);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Returns a future that resolves to the payload if the content of this
  /// object can be decrypted and verified. Otherwise the future fails with a
  /// [JoseException]
  ///
  /// This method will fail if none of the signatures or recipients use one of
  /// the algorithms listed in [allowedAlgorithms] for signing the payload or
  /// wrapping the key. By default, all algorithms are allowed except `none`.
  Future<JosePayload> getPayload(
    JsonWebKeyStore keyStore, {
    List<String>? allowedAlgorithms,
  }) async {
    for (var r in recipients) {
      var header = _headerFor(r);

      if (allowedAlgorithms != null &&
          !allowedAlgorithms.contains(header.algorithm)) {
        continue;
      }

      if (allowedAlgorithms == null && header.algorithm == 'none') {
        continue;
      }

      await for (var key in keyStore.findJsonWebKeys(
        header,
        this is JsonWebSignature
            ? 'verify'
            : header.algorithm == 'dir'
                ? 'decrypt'
                : 'unwrapKey',
      )) {
        try {
          var payload = getPayloadFor(key, header, r);

          if (payload != null) {
            return JosePayload(payload, _protectedHeaderFor(r));
          }
        } catch (e) {
          // ignore
        }
      }
    }

    throw JoseException('Could not decrypt/verify payload');
  }

  @protected
  List<int>? getPayloadFor(
    JsonWebKey? key,
    JoseHeader header,
    JoseRecipient recipient,
  );

  JoseHeader _headerFor(JoseRecipient recipient) {
    return JoseHeader.fromJson(safeUnion([
      sharedProtectedHeader?.toJson(),
      sharedUnprotectedHeader?.toJson(),
      recipient.header.toJson()
    ]));
  }

  JoseHeader _protectedHeaderFor(JoseRecipient recipient) {
    return JoseHeader.fromJson(safeUnion([
      sharedProtectedHeader?.toJson(),
      recipient.protectedHeader?.toJson()
    ]));
  }
}

/// Per-recipient content of a [JoseObject]
///
/// Contains a signature for [JsonWebSignature] objects or an encrypted Content
/// Encryption Key for [JsonWebEncryption]
abstract class JoseRecipient {
  /// Per-recipient protected header
  ///
  /// These Header Parameter values are integrity protected.
  ///
  /// [JsonWebEncryption] objects do not have a per-recipient protected header
  final JsonObject? protectedHeader;

  /// Per-recipient unprotected header
  ///
  /// These Header Parameter values are not integrity protected.
  final JsonObject? unprotectedHeader;

  /// Per-recipient combined protected and unprotected header
  final JoseHeader header;

  /// Per-recipient binary data
  ///
  /// For [JsonWebSignature] objects, this is the signature, for
  /// [JsonWebEncryption] objects, this is the encrypted Content Encryption Key
  ///
  /// For [JsonWebEncryption] with direct encryption, this will be an empty list.
  final List<int> data;

  JoseRecipient(
      {required this.data, this.protectedHeader, this.unprotectedHeader})
      : header = JoseHeader.fromJson(safeUnion(
            [protectedHeader?.toJson(), unprotectedHeader?.toJson()]));

  Map<String, dynamic> toJson();
}

/// The payload of a [JsonWebSignature] or [JsonWebEncryption]
///
/// Contains the data as well as protected header fields
class JosePayload {
  /// The binary data of the payload
  final List<int> data;

  /// The protected header parameters
  final JsonObject? protectedHeader;

  JosePayload(this.data, [this.protectedHeader]);

  /// Returns the data as string
  String get stringContent => convert.utf8.decode(data);

  /// Return the data as json
  dynamic get jsonContent => convert.json.decode(stringContent);

  /// The media type [IANA.MediaTypes](https://www.iana.org/assignments/media-types/media-types.xhtml)
  /// of the payload.
  ///
  /// This is the 'cty' header parameter
  String? get mediaType => protectedHeader!['cty'];
}

/// Base class for [JsonWebSignatureBuilder] and [JsonWebEncryptionBuilder]
abstract class JoseObjectBuilder<T extends JoseObject> {
  final Map<String, dynamic> _protectedHeaderParameters = {};

  /// The binary payload
  List<int>? data;

  @protected
  final List<Map<String, dynamic>> recipients = []; // TODO

  JoseObjectBuilder();

  /// Sets the payload from a string value
  set stringContent(String v) {
    data = convert.utf8.encode(v);
  }

  /// Sets the payload from a json value
  set jsonContent(dynamic v) {
    stringContent = convert.json.encode(v);
  }

  /// Sets the
  set content(dynamic v) {
    if (v is String) {
      stringContent = v;
    } else if (v is List<int>) {
      data = v;
    } else {
      jsonContent = v;
    }
  }

  /// Sets a shared protected header parameter
  ///
  /// Protected header parameters are integrity protected by the signing or
  /// authenticated encryption algorithm. In case of non json payload, protected
  /// header parameters can be used to integrity check additional claims.
  void setProtectedHeader(String key, dynamic value) {
    _protectedHeaderParameters[key] = value;
  }

  /// The media type [IANA.MediaTypes](https://www.iana.org/assignments/media-types/media-types.xhtml)
  /// of the payload.
  ///
  /// This is the 'cty' header parameter
  String? get mediaType => _protectedHeaderParameters['cty'];

  set mediaType(String? v) => _protectedHeaderParameters['cty'] = v;

  /// Returns the protected header parameters as a [JoseHeader] object
  JoseHeader get protectedHeader =>
      JoseHeader.fromJson(_protectedHeaderParameters);

  /// Returns the payload and protected headers as a [JosePayload] object
  JosePayload? get payload =>
      data == null ? null : JosePayload(data!, protectedHeader);

  /// Adds a [key] and [algorithm] to sign or encrypt this object
  ///
  /// [JsonWebSignature] and [JsonWebEncryption] can have multiple recipients
  /// that use different keys. The compact serialization as a string can only
  /// have one recipient however.
  void addRecipient(JsonWebKey? key, {String? algorithm}) {
    recipients.add({'_jwk': key, 'alg': algorithm});
  }

  /// Build the [JsonWebSignature] or [JsonWebEncryption]
  T build();
}

class JoseException implements Exception {
  final String message;
  JoseException(this.message);

  @override
  String toString() {
    return 'JoseException: $message';
  }
}
