// Copyright (c) 2016, rbellens. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';
import 'package:asn1lib/asn1lib.dart';
import 'package:collection/collection.dart';
import 'package:crypto_keys_plus/crypto_keys.dart';

import 'util.dart';

export 'package:crypto_keys_plus/crypto_keys.dart';

part 'certificate.dart';
part 'extension.dart';
part 'objectidentifier.dart';
part 'request.dart';

class Name {
  final List<Map<ObjectIdentifier?, dynamic>> names;

  const Name(this.names);

  /// Name ::= CHOICE { -- only one possibility for now --
  ///   rdnSequence  RDNSequence }
  ///
  /// RDNSequence ::= SEQUENCE OF RelativeDistinguishedName
  ///
  /// RelativeDistinguishedName ::=
  ///   SET SIZE (1..MAX) OF AttributeTypeAndValue
  ///
  /// AttributeTypeAndValue ::= SEQUENCE {
  ///   type     AttributeType,
  ///   value    AttributeValue }
  ///
  /// AttributeType ::= OBJECT IDENTIFIER
  ///
  /// AttributeValue ::= ANY -- DEFINED BY AttributeType
  factory Name.fromAsn1(ASN1Sequence sequence) {
    return Name(sequence.elements.map((ASN1Object set) {
      return <ObjectIdentifier?, dynamic>{
        for (var p in (set as ASN1Set).elements)
          toDart((p as ASN1Sequence).elements[0]): toDart(p.elements[1])
      };
    }).toList());
  }

  ASN1Sequence toAsn1() {
    var seq = ASN1Sequence();
    for (var n in names) {
      var set = ASN1Set();
      n.forEach((k, v) {
        set.add(ASN1Sequence()
          ..add(fromDart(k))
          ..add(fromDart(v)));
      });
      seq.add(set);
    }
    return seq;
  }

  @override
  String toString() =>
      names.map((m) => m.keys.map((k) => '$k=${m[k]}').join(', ')).join(', ');
}

class Validity {
  final DateTime notBefore;
  final DateTime notAfter;

  Validity({required this.notBefore, required this.notAfter});

  factory Validity.fromAsn1(ASN1Sequence sequence) => Validity(
        notBefore: toDart(sequence.elements[0]),
        notAfter: toDart(sequence.elements[1]),
      );

  ASN1Sequence toAsn1() {
    return ASN1Sequence()
      ..add(fromDart(notBefore))
      ..add(fromDart(notAfter));
  }

  @override
  String toString([String prefix = '']) {
    var buffer = StringBuffer();
    buffer.writeln('${prefix}Not Before: $notBefore');
    buffer.writeln('${prefix}Not After: $notAfter');
    return buffer.toString();
  }
}

class SubjectPublicKeyInfo {
  final AlgorithmIdentifier algorithm;
  final PublicKey subjectPublicKey;

  SubjectPublicKeyInfo(this.algorithm, this.subjectPublicKey);

  factory SubjectPublicKeyInfo.fromAsn1(ASN1Sequence sequence) {
    final algorithm =
        AlgorithmIdentifier.fromAsn1(sequence.elements[0] as ASN1Sequence);
    return SubjectPublicKeyInfo(algorithm,
        publicKeyFromAsn1(sequence.elements[1] as ASN1BitString, algorithm));
  }

  @override
  String toString([String prefix = '']) {
    var buffer = StringBuffer();
    buffer.writeln('${prefix}Public Key Algorithm: $algorithm');
    buffer.writeln('${prefix}RSA Public Key:');
    buffer.writeln(keyToString(subjectPublicKey, '$prefix\t'));
    return buffer.toString();
  }

  ASN1Sequence toAsn1() {
    return ASN1Sequence()
      ..add(algorithm.toAsn1())
      ..add(keyToAsn1(subjectPublicKey));
  }
}

class AlgorithmIdentifier {
  final ObjectIdentifier algorithm;
  final dynamic parameters;

  AlgorithmIdentifier(this.algorithm, this.parameters);

  /// AlgorithmIdentifier  ::=  SEQUENCE  {
  ///   algorithm               OBJECT IDENTIFIER,
  ///   parameters              ANY DEFINED BY algorithm OPTIONAL  }
  ///                             -- contains a value of the type
  ///                             -- registered for use with the
  ///                             -- algorithm object identifier value
  factory AlgorithmIdentifier.fromAsn1(ASN1Sequence sequence) {
    var algorithm = toDart(sequence.elements[0]);
    var parameters =
        sequence.elements.length > 1 ? toDart(sequence.elements[1]) : null;
    return AlgorithmIdentifier(algorithm, parameters);
  }

  ASN1Sequence toAsn1() {
    var seq = ASN1Sequence()..add(fromDart(algorithm));
    seq.add(fromDart(parameters));
    return seq;
  }

  @override
  String toString() => "$algorithm${parameters == null ? "" : "($parameters)"}";
}

class PrivateKeyInfo {
  final int version;
  final AlgorithmIdentifier algorithm;
  final KeyPair keyPair;

  PrivateKeyInfo(this.version, this.algorithm, this.keyPair);

  /// PrivateKeyInfo ::= SEQUENCE {
  ///   version         Version,
  ///   algorithm       AlgorithmIdentifier,
  ///   PrivateKey      OCTET STRING
  /// }
  factory PrivateKeyInfo.fromAsn1(ASN1Sequence sequence) {
    final algorithm =
        AlgorithmIdentifier.fromAsn1(sequence.elements[1] as ASN1Sequence);
    var v = toDart(sequence.elements[0]) as BigInt;
    return PrivateKeyInfo(
        v.toInt() + 1,
        algorithm,
        keyPairFromAsn1(
            ASN1BitString(
                (sequence.elements[2] as ASN1OctetString).contentBytes()),
            algorithm.algorithm));
  }
}

class EncryptedPrivateKeyInfo {
  final AlgorithmIdentifier encryptionAlgorithm;
  final Uint8List encryptedData;

  EncryptedPrivateKeyInfo(this.encryptionAlgorithm, this.encryptedData);

  /// EncryptedPrivateKeyInfo ::= SEQUENCE {
  ///   encryptionAlgorithm  AlgorithmIdentifier,
  ///   encryptedData        OCTET STRING
  /// }
  factory EncryptedPrivateKeyInfo.fromAsn1(ASN1Sequence sequence) {
    final algorithm =
        AlgorithmIdentifier.fromAsn1(sequence.elements[0] as ASN1Sequence);
    return EncryptedPrivateKeyInfo(
        algorithm, (sequence.elements[1] as ASN1OctetString).contentBytes());
  }
}

String _getPEMFromBytes(List<int> bytes, String type) {
  var buffer = StringBuffer();
  buffer.writeln('-----BEGIN $type-----');
  for (var i = 0; i < bytes.length; i += 48) {
    buffer.writeln(base64.encode(bytes.skip(i).take(48).toList()));
  }
  buffer.writeln('-----END $type-----');
  return buffer.toString();
}

String toPem(SubjectPublicKeyInfo key) {
  return _getPEMFromBytes(key.toAsn1().encodedBytes, 'PUBLIC KEY');
}

Object _parseDer(List<int> bytes, String? type) {
  var p = ASN1Parser(bytes as Uint8List);
  var o = p.nextObject();
  if (o is! ASN1Sequence) {
    throw FormatException('Expected SEQUENCE, got ${o.runtimeType}');
  }
  var s = o;

  switch (type) {
    case 'RSA PUBLIC KEY':
      // RSA Public Key file (PKCS#1)
      return rsaPublicKeyFromAsn1(s);
    case 'PUBLIC KEY':
      // Public Key file (PKCS#8)
      return SubjectPublicKeyInfo.fromAsn1(s);
    case 'RSA PRIVATE KEY':
      // RSA Private Key file (PKCS#1)
      return rsaKeyPairFromAsn1(s);
    case 'PRIVATE KEY':
      // Private Key file (PKCS#8)
      return PrivateKeyInfo.fromAsn1(s);
    case 'EC PRIVATE KEY':
      // EC Private Key file
      return ecKeyPairFromAsn1(s);
    case 'ENCRYPTED PRIVATE KEY':
      // Encrypted Private Key file (PKCS#8)
      return EncryptedPrivateKeyInfo.fromAsn1(s);
    case '':
    case 'CERTIFICATE':
      return X509Certificate.fromAsn1(s);
    case 'CERTIFICATE REQUEST':
      return CertificationRequest.fromAsn1(s);
  }
  throw FormatException('Could not parse PEM');
}

Iterable parsePem(String pem) sync* {
  var lines = LineSplitter.split(pem)
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  final re = RegExp(r'^-----BEGIN (.+)-----$');
  for (var i = 0; i < lines.length; i++) {
    var l = lines[i];
    var match = re.firstMatch(l);
    if (match == null) {
      throw ArgumentError('The given string does not have the correct '
          'begin marker expected in a PEM file.');
    }
    var type = match.group(1);

    var startI = ++i;
    while (i < lines.length && lines[i] != '-----END $type-----') {
      i++;
    }
    if (i >= lines.length) {
      throw ArgumentError('The given string does not have the correct '
          'end marker expected in a PEM file.');
    }

    var b = lines.sublist(startI, i).join('');
    var bytes = base64.decode(b);
    yield _parseDer(bytes, type);
  }
}
