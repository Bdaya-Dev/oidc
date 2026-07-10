import 'dart:io';
import 'dart:typed_data';

import 'package:asn1lib/asn1lib.dart';
import 'package:test/test.dart';
import 'package:x509_plus/src/util.dart';
import 'package:x509_plus/x509.dart';

/// Big-endian fixed-length byte encoding of [v].
Uint8List _bigToBytes(BigInt v, int len) {
  final out = Uint8List(len);
  final mask = BigInt.from(0xff);
  for (var i = len - 1; i >= 0; i--) {
    out[i] = (v & mask).toInt();
    v = v >> 8;
  }
  return out;
}

void main() {
  group('ObjectIdentifier', () {
    test('fromAsn1 decodes multi-byte arcs and equality/hashCode agree', () {
      // Build the encoded OID via the asn1lib constructor (plain arcs) rather
      // than ObjectIdentifier.toAsn1, which is broken (see bugsFound).
      final encoded = ASN1ObjectIdentifier([1, 2, 840, 113549, 1, 1, 11]);
      final oid = ObjectIdentifier.fromAsn1(encoded);
      expect(oid, equals(ObjectIdentifier([1, 2, 840, 113549, 1, 1, 11])));
      expect(oid.hashCode,
          equals(ObjectIdentifier([1, 2, 840, 113549, 1, 1, 11]).hashCode));
      expect(oid.name, 'sha256WithRSAEncryption');
    });
  });

  group('fromDart', () {
    test('encodes each supported Dart type', () {
      expect(fromDart(null), isA<ASN1Null>());
      expect(fromDart(<int>[1, 2, 3]), isA<ASN1BitString>());
      expect(fromDart(<BigInt>[BigInt.one]), isA<ASN1Sequence>());
      expect(fromDart(<BigInt>{BigInt.one, BigInt.two}), isA<ASN1Set>());
      expect(fromDart(BigInt.from(42)), isA<ASN1Integer>());
      expect(fromDart(7), isA<ASN1Integer>());
      expect(fromDart(ObjectIdentifier([2, 5, 4, 3])),
          isA<ASN1ObjectIdentifier>());
      expect(fromDart(true), isA<ASN1Boolean>());
      expect(fromDart('hello'), isA<ASN1PrintableString>());
      expect(fromDart(DateTime.utc(2020, 1, 1)), isA<ASN1UtcTime>());
    });

    test('throws ArgumentError for an unsupported type', () {
      expect(() => fromDart(3.14), throwsArgumentError);
    });
  });

  group('toDart', () {
    test('decodes primitives and containers', () {
      expect(toDart(ASN1Null()), isNull);
      expect(toDart(ASN1Integer(BigInt.from(9))), BigInt.from(9));
      expect(toDart(ASN1Boolean(true)), isTrue);
      expect(toDart(ASN1PrintableString('abc')), 'abc');

      final seq = ASN1Sequence()
        ..add(ASN1Integer(BigInt.one))
        ..add(ASN1Boolean(false));
      expect(toDart(seq), [BigInt.one, false]);
    });

    test('unwraps a context-specific [0] constructed object (tag 0xa0)', () {
      final inner = ASN1PrintableString('nested');
      final wrapped = ASN1Object.preEncoded(0xa0, inner.encodedBytes);
      expect(toDart(wrapped), 'nested');
    });

    test('throws ArgumentError for an unconvertible object', () {
      final obj = ASN1Object.preEncoded(0x99, Uint8List.fromList([1, 2]));
      expect(() => toDart(obj), throwsArgumentError);
    });
  });

  group('toHexString', () {
    test('pads odd-length hex to whole bytes', () {
      expect(toHexString(BigInt.from(0xf)).trim(), '0f');
    });

    test('joins bytes with colons', () {
      expect(toHexString(BigInt.from(0xabcd)).trim(), 'ab:cd');
    });
  });

  group('keyToString / keyToAsn1', () {
    final rsaPublic = RsaPublicKey(
      modulus: BigInt.parse('123456789012345678901234567890123456789'),
      exponent: BigInt.from(65537),
    );

    test('renders an RSA public key with modulus and exponent', () {
      final s = keyToString(rsaPublic);
      expect(s, contains('Modulus'));
      expect(s, contains('Exponent: 65537'));
    });

    test('renders a non-RSA key via its own toString', () {
      final pem = File('test/files/ec256.public.key').readAsStringSync();
      final info = parsePem(pem).single as SubjectPublicKeyInfo;
      expect(keyToString(info.subjectPublicKey), isNotEmpty);
    });

    test('encodes an RSA public key to a BIT STRING', () {
      expect(keyToAsn1(rsaPublic), isA<ASN1BitString>());
    });
  });

  group('keyPairToAsn1', () {
    test('encodes a parsed RSA key pair', () {
      final pem = File('test/files/rsa.key').readAsStringSync();
      final keyPair = parsePem(pem).single as KeyPair;
      expect(keyPairToAsn1(keyPair), isA<ASN1BitString>());
    });
  });

  group('ecPublicKeyFromAsn1', () {
    late BigInt x;
    late BigInt y;

    setUp(() {
      final pem = File('test/files/ec256.public.key').readAsStringSync();
      final info = parsePem(pem).single as SubjectPublicKeyInfo;
      final key = info.subjectPublicKey as EcPublicKey;
      x = key.xCoordinate;
      y = key.yCoordinate;
    });

    test('parses an uncompressed point and infers the curve from length', () {
      final bytes =
          Uint8List.fromList([4, ..._bigToBytes(x, 32), ..._bigToBytes(y, 32)]);
      final key = ecPublicKeyFromAsn1(ASN1BitString(bytes));
      expect(key.curve, curves.p256);
      expect(key.xCoordinate, x);
      expect(key.yCoordinate, y);
    });

    test('rejects a compressed point', () {
      final bytes = Uint8List.fromList([2, ..._bigToBytes(x, 32)]);
      expect(() => ecPublicKeyFromAsn1(ASN1BitString(bytes)),
          throwsA(isA<UnsupportedError>()));
    });

    test('rejects an invalid compression byte', () {
      final bytes = Uint8List.fromList([99, 1, 2, 3]);
      expect(
          () => ecPublicKeyFromAsn1(ASN1BitString(bytes)), throwsArgumentError);
    });

    test('throws when no curve matches the point length', () {
      final bytes = Uint8List.fromList([4, 1, 2]);
      expect(() => ecPublicKeyFromAsn1(ASN1BitString(bytes)),
          throwsA(isA<UnsupportedError>()));
    });
  });

  group('keyPairFromAsn1 / publicKeyFromAsn1 unsupported algorithms', () {
    test('keyPairFromAsn1 throws UnimplementedError for a signature OID', () {
      final sha1Rsa = ObjectIdentifier([1, 2, 840, 113549, 1, 1, 5]);
      expect(
          () => keyPairFromAsn1(
              ASN1BitString(Uint8List.fromList([1, 2])), sha1Rsa),
          throwsA(isA<UnimplementedError>()));
    });

    test('publicKeyFromAsn1 throws UnimplementedError for a signature OID', () {
      final alg = AlgorithmIdentifier(
          ObjectIdentifier([1, 2, 840, 113549, 1, 1, 5]), null);
      expect(
          () =>
              publicKeyFromAsn1(ASN1BitString(Uint8List.fromList([1, 2])), alg),
          throwsA(isA<UnimplementedError>()));
    });

    test('publicKeyFromAsn1 rejects an unsupported EC curve', () {
      final alg = AlgorithmIdentifier(
        ObjectIdentifier([1, 2, 840, 10045, 2, 1]), // ecPublicKey
        ObjectIdentifier(
            [1, 2, 840, 10045, 3, 1, 2]), // prime192v2 (unsupported)
      );
      expect(
          () => publicKeyFromAsn1(
              ASN1BitString(Uint8List.fromList([4, 1, 2])), alg),
          throwsA(isA<UnsupportedError>()));
    });
  });

  group('ecKeyPairFromAsn1', () {
    test('rejects a non-v1 EC private key', () {
      final seq = ASN1Sequence()
        ..add(ASN1Integer(BigInt.two))
        ..add(ASN1OctetString(Uint8List.fromList([1, 2, 3, 4])));
      expect(() => ecKeyPairFromAsn1(seq), throwsA(isA<UnsupportedError>()));
    });
  });
}
