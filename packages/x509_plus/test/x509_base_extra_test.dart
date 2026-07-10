import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:asn1lib/asn1lib.dart';
import 'package:test/test.dart';
import 'package:x509_plus/x509.dart';

/// Extracts the raw DER bytes from a single-block PEM file.
Uint8List _pemBody(String path) {
  final pem = File(path).readAsStringSync();
  final b64 = LineSplitter.split(pem)
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !l.startsWith('-----'))
      .join();
  return base64.decode(b64);
}

/// Wraps [der] bytes into a PEM block of the given [type].
String _der2pem(List<int> der, String type) {
  final b64 = base64.encode(der);
  final buf = StringBuffer()..writeln('-----BEGIN $type-----');
  for (var i = 0; i < b64.length; i += 64) {
    buf.writeln(b64.substring(i, i + 64 > b64.length ? b64.length : i + 64));
  }
  buf.writeln('-----END $type-----');
  return buf.toString();
}

ASN1Sequence _algId(List<int> arcs) => ASN1Sequence()
  ..add(ASN1ObjectIdentifier(arcs))
  ..add(ASN1Null());

void main() {
  group('parsePem - additional key formats', () {
    test('PKCS#8 RSA PRIVATE KEY yields a PrivateKeyInfo', () {
      final rsaPkcs1 = _pemBody('test/files/rsa.key');
      final pkcs8 = ASN1Sequence()
        ..add(ASN1Integer(BigInt.zero))
        ..add(_algId([1, 2, 840, 113549, 1, 1, 1])) // rsaEncryption
        ..add(ASN1OctetString(rsaPkcs1));
      final info = parsePem(_der2pem(pkcs8.encodedBytes, 'PRIVATE KEY')).single
          as PrivateKeyInfo;
      expect(info.version, 1);
      expect(info.keyPair.privateKey, isA<RsaPrivateKey>());
      expect(info.algorithm.algorithm.name, 'rsaEncryption');
    });

    test('PKCS#8 EC PRIVATE KEY yields a PrivateKeyInfo', () {
      final ecPriv = _pemBody('test/files/ec256.private.key');
      final pkcs8 = ASN1Sequence()
        ..add(ASN1Integer(BigInt.zero))
        ..add(_algId([1, 2, 840, 10045, 2, 1])) // ecPublicKey
        ..add(ASN1OctetString(ecPriv));
      final info = parsePem(_der2pem(pkcs8.encodedBytes, 'PRIVATE KEY')).single
          as PrivateKeyInfo;
      expect(info.keyPair.privateKey, isA<EcPrivateKey>());
    });

    test('PKCS#1 RSA PUBLIC KEY yields an RsaPublicKey', () {
      final seq = ASN1Sequence()
        ..add(ASN1Integer(BigInt.from(3233)))
        ..add(ASN1Integer(BigInt.from(17)));
      final key = parsePem(_der2pem(seq.encodedBytes, 'RSA PUBLIC KEY')).single
          as RsaPublicKey;
      expect(key.modulus, BigInt.from(3233));
      expect(key.exponent, BigInt.from(17));
    });

    test('ENCRYPTED PRIVATE KEY yields an EncryptedPrivateKeyInfo', () {
      final der = ASN1Sequence()
        ..add(_algId([1, 2, 840, 113549, 1, 5, 13])) // pbes2
        ..add(ASN1OctetString(Uint8List.fromList([1, 2, 3, 4])));
      final info = parsePem(_der2pem(der.encodedBytes, 'ENCRYPTED PRIVATE KEY'))
          .single as EncryptedPrivateKeyInfo;
      expect(info.encryptedData, [1, 2, 3, 4]);
      expect(info.encryptionAlgorithm.algorithm, isA<ObjectIdentifier>());
    });
  });

  group('parsePem - error handling', () {
    test('throws when the DER is not a SEQUENCE', () {
      final pem =
          _der2pem(ASN1Integer(BigInt.from(5)).encodedBytes, 'CERTIFICATE');
      expect(() => parsePem(pem).toList(), throwsFormatException);
    });

    test('throws for an unhandled PEM type', () {
      final pem = _der2pem(ASN1Sequence().encodedBytes, 'DSA PRIVATE KEY');
      expect(() => parsePem(pem).toList(), throwsFormatException);
    });

    test('throws when the begin marker is missing', () {
      expect(() => parsePem('this is not a pem').toList(), throwsArgumentError);
    });

    test('throws when the end marker is missing', () {
      expect(() => parsePem('-----BEGIN CERTIFICATE-----\nQUJD').toList(),
          throwsArgumentError);
    });
  });

  group('certificate re-encoding and accessors', () {
    late X509Certificate cert;

    setUp(() {
      final bytes = File('test/resources/rfc5280_cert1.cer').readAsBytesSync();
      cert = X509Certificate.fromAsn1(
          ASN1Parser(bytes).nextObject() as ASN1Sequence);
    });

    test('exposes the RSA public key', () {
      expect(cert.publicKey, isA<RsaPublicKey>());
    });

    test('toPem wraps the public key with PEM markers', () {
      final spki = cert.tbsCertificate.subjectPublicKeyInfo!;
      final pem = toPem(spki);
      expect(pem, startsWith('-----BEGIN PUBLIC KEY-----'));
      expect(pem, contains('-----END PUBLIC KEY-----'));
    });

    test('component toAsn1 methods assemble the expected structures', () {
      final tbs = cert.tbsCertificate;
      expect(tbs.issuer!.toAsn1(), isA<ASN1Sequence>());
      expect(tbs.validity!.toAsn1().elements, hasLength(2));
      expect(tbs.signature!.toAsn1(), isA<ASN1Sequence>());
      expect(tbs.subjectPublicKeyInfo!.toAsn1().elements, hasLength(2));
    });

    test('X509Certificate.toAsn1 produces a three-element SEQUENCE', () {
      final seq = cert.toAsn1();
      expect(seq, isA<ASN1Sequence>());
      expect(seq.elements, hasLength(3));
    });
  });
}
