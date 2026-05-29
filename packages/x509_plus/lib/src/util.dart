
import 'dart:convert';

import 'package:asn1lib/asn1lib.dart';

import '../x509.dart';

ObjectIdentifier? _ecParametersFromAsn1(ASN1Object object) {
  // https://tools.ietf.org/html/rfc5480#section-2.1.1
  //     ECParameters ::= CHOICE {
  //       namedCurve         OBJECT IDENTIFIER
  //       -- implicitCurve   NULL
  //       -- specifiedCurve  SpecifiedECDomain
  //     }
  //       -- implicitCurve and specifiedCurve MUST NOT be used in PKIX.
  //       -- Details for SpecifiedECDomain can be found in [X9.62].
  //       -- Any future additions to this CHOICE should be coordinated
  //       -- with ANSI X9.
  if (object is ASN1ObjectIdentifier) {
    return ObjectIdentifier.fromAsn1(object);
  }
  return null;
}

KeyPair ecKeyPairFromAsn1(ASN1Sequence sequence) {
  // https://tools.ietf.org/html/rfc5915
  //   ECPrivateKey ::= SEQUENCE {
  //     version        INTEGER { ecPrivkeyVer1(1) } (ecPrivkeyVer1),
  //     privateKey     OCTET STRING,
  //     parameters [0] ECParameters {{ NamedCurve }} OPTIONAL,
  //     publicKey  [1] BIT STRING OPTIONAL
  //   }
  var version = toDart(sequence.elements[0]);
  if (version != BigInt.one) {
    throw UnsupportedError('Only `ecPrivkeyVer1` supported.');
  }

  var privateKey = toBigInt(sequence.elements[1].contentBytes());

  var l = sequence.elements[1].contentBytes().length;

  Identifier? curve;

  var i = 2;
  if (sequence.elements.length > i && sequence.elements[i].tag == 0xa0) {
    var e = ASN1Parser(sequence.elements[i].valueBytes()).nextObject();
    curve = _curveObjectIdentifierToIdentifier(_ecParametersFromAsn1(e)!);
    i++;
  }
  curve ??= _lengthToCurve(l);

  EcPublicKey? publicKey;
  if (sequence.elements.length > i && sequence.elements[i].tag == 0xa1) {
    var e = ASN1Parser(sequence.elements[i].contentBytes()).nextObject()
        as ASN1BitString;
    // https://tools.ietf.org/html/rfc5480#section-2.2
    // ECPoint ::= OCTET STRING

    publicKey = ecPublicKeyFromAsn1(e, curve: curve);
  }

  return KeyPair(
      privateKey: EcPrivateKey(eccPrivateKey: privateKey, curve: curve),
      publicKey: publicKey);
}

Identifier _curveObjectIdentifierToIdentifier(ObjectIdentifier id) {
  var curve = {
    'secp256k1': curves.p256k,
    'prime256v1': curves.p256,
    'secp384r1': curves.p384,
    'secp521r1': curves.p521,
  }[id.name];
  if (curve == null) {
    throw UnsupportedError('Curves of type $id not supported');
  }
  return curve;
}

KeyPair rsaKeyPairFromAsn1(ASN1Sequence sequence) {
  // var version = _toDart(sequence.elements[0]).toInt() + 1;
  var modulus = toDart(sequence.elements[1]);
  var publicExponent = toDart(sequence.elements[2]);
  var privateExponent = toDart(sequence.elements[3]);
  var prime1 = toDart(sequence.elements[4]);
  var prime2 = toDart(sequence.elements[5]);
  // var exponent1 = _toDart(sequence.elements[6]);
  // var exponent2 = _toDart(sequence.elements[7]);
  // var coefficient = _toDart(sequence.elements[8]);
  var privateKey = RsaPrivateKey(
      modulus: modulus,
      privateExponent: privateExponent,
      firstPrimeFactor: prime1,
      secondPrimeFactor: prime2);
  var publicKey = RsaPublicKey(modulus: modulus, exponent: publicExponent);
  return KeyPair(publicKey: publicKey, privateKey: privateKey);
}

RsaPublicKey rsaPublicKeyFromAsn1(ASN1Sequence sequence) {
  var modulus = (sequence.elements[0] as ASN1Integer).valueAsBigInteger;
  var exponent = (sequence.elements[1] as ASN1Integer).valueAsBigInteger;
  return RsaPublicKey(modulus: modulus, exponent: exponent);
}

Identifier _lengthToCurve(int l) {
  switch (l) {
    case 32:
      return curves.p256;
    case 48:
      return curves.p384;
    case 66:
      return curves.p521;
  }
  throw UnsupportedError('No matching curve for length $l');
}

EcPublicKey ecPublicKeyFromAsn1(ASN1BitString bitString, {Identifier? curve}) {
  var bytes = bitString.contentBytes();
  var compression = bytes[0];
  switch (compression) {
    case 4:
      // uncompressed
      var l = (bytes.length - 1) ~/ 2;
      var x = toBigInt(bytes.sublist(1, l + 1));
      var y = toBigInt(bytes.sublist(l + 1));
      return EcPublicKey(
          xCoordinate: x, yCoordinate: y, curve: curve ?? _lengthToCurve(l));
    case 2:
    case 3:
      throw UnsupportedError('Compressed key not supported');
    default:
      throw ArgumentError('Invalid compression value $compression');
  }
}

KeyPair keyPairFromAsn1(ASN1BitString data, ObjectIdentifier algorithm) {
  switch (algorithm.name) {
    case 'rsaEncryption':
      var sequence =
          ASN1Parser(data.contentBytes()).nextObject() as ASN1Sequence;
      return rsaKeyPairFromAsn1(sequence);
    case 'ecPublicKey':
      var sequence =
          ASN1Parser(data.contentBytes()).nextObject() as ASN1Sequence;
      return ecKeyPairFromAsn1(sequence);
    case 'sha1WithRSAEncryption':
  }
  throw UnimplementedError('Unknown algoritmh $algorithm');
}

PublicKey publicKeyFromAsn1(ASN1BitString data, AlgorithmIdentifier algorithm) {
  switch (algorithm.algorithm.name) {
    case 'rsaEncryption':
      var s = ASN1Parser(data.contentBytes()).nextObject() as ASN1Sequence;
      return rsaPublicKeyFromAsn1(s);
    case 'ecPublicKey':
      return ecPublicKeyFromAsn1(data,
          curve: _curveObjectIdentifierToIdentifier(algorithm.parameters));
    case 'sha1WithRSAEncryption':
  }
  throw UnimplementedError('Unknown algoritmh $algorithm');
}

String keyToString(Key key, [String prefix = '']) {
  if (key is RsaPublicKey) {
    var buffer = StringBuffer();
    var l = key.modulus.bitLength;
    buffer.writeln('${prefix}Modulus ($l bit):');
    buffer.writeln(toHexString(key.modulus, '$prefix\t', 15));
    buffer.writeln('${prefix}Exponent: ${key.exponent}');
    return buffer.toString();
  }
  return '$prefix$key';
}

ASN1BitString keyToAsn1(Key key) {
  var s = ASN1Sequence();
  if (key is RsaPublicKey) {
    s
      ..add(ASN1Integer(key.modulus))
      ..add(ASN1Integer(key.exponent));
  }
  return ASN1BitString(s.encodedBytes);
}

ASN1BitString keyPairToAsn1(KeyPair keyPair) {
  var s = ASN1Sequence();

  var key = keyPair.privateKey as RsaPrivateKey;
  var publicKey = keyPair.publicKey as RsaPublicKey;
  var pSub1 = key.firstPrimeFactor - BigInt.one;
  var qSub1 = key.secondPrimeFactor - BigInt.one;
  var exponent1 = key.privateExponent.remainder(pSub1);
  var exponent2 = key.privateExponent.remainder(qSub1);
  var coefficient = key.secondPrimeFactor.modInverse(key.firstPrimeFactor);

  s
    ..add(fromDart(0)) // version
    ..add(fromDart(key.modulus))
    ..add(fromDart(publicKey.exponent))
    ..add(fromDart(key.privateExponent))
    ..add(fromDart(key.firstPrimeFactor))
    ..add(fromDart(key.secondPrimeFactor))
    ..add(fromDart(exponent1))
    ..add(fromDart(exponent2))
    ..add(fromDart(coefficient));

  return ASN1BitString(s.encodedBytes);
}

ASN1Object fromDart(dynamic obj) {
  if (obj == null) return ASN1Null();
  if (obj is List<int>) return ASN1BitString(obj);
  if (obj is List) {
    var s = ASN1Sequence();
    for (var v in obj) {
      s.add(fromDart(v));
    }
    return s;
  }
  if (obj is Set) {
    var s = ASN1Set();
    for (var v in obj) {
      s.add(fromDart(v));
    }
    return s;
  }
  if (obj is BigInt) return ASN1Integer(obj);
  if (obj is int) return ASN1Integer(BigInt.from(obj));
  if (obj is ObjectIdentifier) return obj.toAsn1();
  if (obj is bool) return ASN1Boolean(obj);
  if (obj is String) return ASN1PrintableString(obj);
  if (obj is DateTime) return ASN1UtcTime(obj);

  throw ArgumentError.value(obj, 'obj', 'cannot be encoded as ASN1Object');
}

dynamic toDart(ASN1Object obj) {
  if (obj is ASN1Null) return null;
  if (obj is ASN1Sequence) return obj.elements.map(toDart).toList();
  if (obj is ASN1Set) return obj.elements.map(toDart).toSet();
  if (obj is ASN1Integer) return obj.valueAsBigInteger;
  if (obj is ASN1ObjectIdentifier) return ObjectIdentifier.fromAsn1(obj);
  if (obj is ASN1BitString) return obj.stringValue;
  if (obj is ASN1Boolean) return obj.booleanValue;
  if (obj is ASN1OctetString) return obj.stringValue;
  if (obj is ASN1PrintableString) return obj.stringValue;
  if (obj is ASN1UtcTime) return obj.dateTimeValue;
  if (obj is ASN1GeneralizedTime) return obj.dateTimeValue;
  if (obj is ASN1IA5String) return obj.stringValue;
  if (obj is ASN1UTF8String) return obj.utf8StringValue;

  // ASN.1 Identifier format is below:
  // | 7 | 6 |  5  | 4| 3| 2|1|0|
  // | Class | P/C | Tag number |
  //
  // The Class type is below:
  // 0 0(0): Universal
  // 0 1(1): Applicaation
  // 1 0(2): Context-Specific
  // 1 1(3): Private
  //
  // The P/C is below:
  // 0: Primitive
  // 1: Constructed
  switch (obj.tag) {
    case 0xa0: // 10 1 00000 => Class is Context-Specific, P/C is Constructed and Tag Number is 0
      return toDart(ASN1Parser(obj.valueBytes()).nextObject());
    case 0x86: // 10 0 00110 => Class is Context-Specific, P/C is Primitive and Tag Number is 6
      return utf8.decode(obj.valueBytes());
  }
  throw ArgumentError(
      'Cannot convert $obj (${obj.runtimeType}) to dart object.');
}

String toHexString(BigInt v, [String prefix = '', int bytesPerLine = 15]) {
  var str = v.toRadixString(16);
  if (str.length % 2 != 0) {
    str = '0$str';
  }
  var buffer = StringBuffer();
  for (var i = 0; i < str.length; i += bytesPerLine * 2) {
    var l = Iterable.generate(
        str.length - i < bytesPerLine * 2
            ? (str.length - i) ~/ 2
            : bytesPerLine,
        (j) => str.substring(i + j * 2, i + j * 2 + 2));
    var s = l.join(':');
    buffer.writeln('$prefix$s${str.length - i <= bytesPerLine * 2 ? '' : ':'}');
  }
  return buffer.toString();
}

BigInt toBigInt(List<int> bytes) =>
    bytes.fold(BigInt.zero, (a, b) => a * BigInt.from(256) + BigInt.from(b));
