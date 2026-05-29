/// [JSON Web Signature](https://tools.ietf.org/html/rfc7515)
library;

import 'util.dart';
import 'jwk.dart';
import 'jose.dart';
import 'dart:convert' as convert;

/// JSON Web Signature (JWS) represents content secured with digital signatures
/// or Message Authentication Codes (MACs) using JSON-based data structures.
class JsonWebSignature extends JoseObject {
  JsonWebSignature._(super.data, List<_JwsRecipient> super.recipients);

  /// Constructs a [JsonWebSignature] from its compact serialization
  factory JsonWebSignature.fromCompactSerialization(String serialization) {
    var parts = serialization.split('.');
    if (parts.length != 3) {
      throw ArgumentError.value(
          serialization, 'Compact serialization should have 3 parts.');
    }
    return JsonWebSignature._(
        decodeBase64EncodedBytes(parts[1]),
        List.unmodifiable([
          _JwsRecipient(
              protectedHeader: JsonObject.decode(parts[0]),
              data: decodeBase64EncodedBytes(parts[2]))
        ]));
  }

  /// Constructs a [JsonWebSignature] from its flattened or general JSON
  /// representation
  factory JsonWebSignature.fromJson(Map<String, dynamic> json) {
    Iterable<_JwsRecipient> signatures;
    if (json.containsKey('signatures')) {
      signatures =
          (json['signatures'] as List).map((v) => _JwsRecipient.fromJson(v));
    } else {
      signatures = [_JwsRecipient.fromJson(json)];
    }
    return JsonWebSignature._(
      decodeBase64EncodedBytes(json['payload']),
      List.unmodifiable(signatures),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    var v = <String, dynamic>{'payload': encodeBase64EncodedBytes(data)};
    if (recipients.length == 1) {
      v.addAll(recipients.first.toJson());
    } else {
      v['signatures'] = recipients.map((v) => v.toJson()).toList();
    }
    return v;
  }

  @override
  String toCompactSerialization() {
    if (recipients.length != 1) {
      throw StateError(
          'Compact serialization does not support multiple signatures');
    }
    var signature = recipients.first;
    if (signature.unprotectedHeader != null) {
      throw StateError(
          'Compact serialization does not support unprotected header parameters');
    }
    return '${signature.protectedHeader!.toBase64EncodedString()}.${encodeBase64EncodedBytes(data)}.'
        '${encodeBase64EncodedBytes(signature.data)}';
  }

  /// Returns the unverified payload (with the protected header parameters from
  /// the first signature)
  JosePayload get unverifiedPayload => JosePayload(data, commonHeader);

  @override
  List<int>? getPayloadFor(
    JsonWebKey? key,
    JoseHeader header,
    JoseRecipient recipient,
  ) {
    if (header.algorithm == 'none') {
      return key == null && recipient.data.isEmpty ? this.data : null;
    }

    if (key == null) {
      return null;
    }

    // verify header
    var encodedHeader = recipient.protectedHeader!.toBase64EncodedString();
    var encodedPayload = encodeBase64EncodedBytes(this.data);
    var data = convert.utf8.encode('$encodedHeader.$encodedPayload');

    return key.verify(data, recipient.data, algorithm: header.algorithm)
        ? this.data
        : null;
  }
}

class _JwsRecipient extends JoseRecipient {
  _JwsRecipient(
      {super.protectedHeader, super.unprotectedHeader, required super.data});

  _JwsRecipient.fromJson(Map<String, dynamic> json)
      : this(
            protectedHeader: json['protected'] == null
                ? null
                : JsonObject.decode(json['protected']),
            unprotectedHeader:
                json['header'] == null ? null : JsonObject.from(json['header']),
            data: json['signature'] == null
                ? const []
                : decodeBase64EncodedBytes(json['signature']));

  factory _JwsRecipient._sign(
      List<int> payload, JsonObject protectedHeader, JsonWebKey? key,
      {String? algorithm, bool protectAll = false}) {
    // Compute the encoded payload value BASE64URL(JWS Payload)
    var encodedPayload = encodeBase64EncodedBytes(payload);

    // Assemble the unprotected header
    algorithm ??= key?.algorithmForOperation('sign') ?? 'none';
    var unprotectedHeaderParams = <String, dynamic>{'alg': algorithm};
    if (key?.keyId != null) {
      unprotectedHeaderParams['kid'] = key!.keyId;
    }
    var commonKeys = protectedHeader
        .toJson()
        .keys
        .toSet()
        .intersection(unprotectedHeaderParams.keys.toSet());
    for (var k in commonKeys) {
      if (unprotectedHeaderParams[k] != protectedHeader[k]) {
        throw ArgumentError(
            "Protected and unprotected have non-equal parameter '$k'");
      }
      unprotectedHeaderParams.remove(k);
    }

    // Compute the encoded header value BASE64URL(UTF8(JWS Protected Header))
    if (protectAll) {
      protectedHeader = JsonObject.from(
          unprotectedHeaderParams..addAll(protectedHeader.toJson()));
    }
    var unprotectedHeader =
        protectAll ? null : JsonObject.from(unprotectedHeaderParams);

    var encodedHeader = protectedHeader.toBase64EncodedString();

    var data = convert.utf8.encode('$encodedHeader.$encodedPayload');

    var signature = algorithm == 'none'
        ? const <int>[]
        : key!.sign(data, algorithm: algorithm);

    return _JwsRecipient(
        protectedHeader: protectedHeader,
        unprotectedHeader: unprotectedHeader,
        data: signature);
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (protectedHeader != null)
        'protected': protectedHeader!.toBase64EncodedString(),
      if (unprotectedHeader != null) 'header': unprotectedHeader!.toJson(),
      'signature': encodeBase64EncodedBytes(data)
    };
  }
}

/// Builder for [JsonWebSignature]
class JsonWebSignatureBuilder extends JoseObjectBuilder<JsonWebSignature> {
  @override
  JsonWebSignature build() {
    if (recipients.isEmpty) {
      throw StateError('Need at least one recipient');
    }
    var payload = this.payload;
    if (payload == null) {
      throw StateError('No payload set');
    }

    var signatures = recipients.map((r) {
      var key = r['_jwk'];
      var algorithm = r['alg'];
      return _JwsRecipient._sign(payload.data, payload.protectedHeader!, key,
          algorithm: algorithm, protectAll: recipients.length == 1);
    }).toList();

    return JsonWebSignature._(payload.data, signatures);
  }
}
