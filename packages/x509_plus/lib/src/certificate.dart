part of 'x509_base.dart';

/// A Certificate.
abstract class Certificate {
  /// The public key from this certificate.
  PublicKey get publicKey;
}

/// A X.509 Certificate
class X509Certificate implements Certificate {
  /// The to-be-signed certificate
  final TbsCertificate tbsCertificate;

  ///
  final AlgorithmIdentifier signatureAlgorithm;
  final List<int>? signatureValue;

  @override
  PublicKey get publicKey =>
      tbsCertificate.subjectPublicKeyInfo!.subjectPublicKey;

  const X509Certificate(
      this.tbsCertificate, this.signatureAlgorithm, this.signatureValue);

  /// Creates a certificate from an [ASN1Sequence].
  ///
  /// The ASN.1 definition is:
  ///
  ///   Certificate  ::=  SEQUENCE  {
  ///     tbsCertificate       TBSCertificate,
  ///     signatureAlgorithm   AlgorithmIdentifier,
  ///     signatureValue       BIT STRING  }
  factory X509Certificate.fromAsn1(ASN1Sequence sequence) {
    final algorithm =
        AlgorithmIdentifier.fromAsn1(sequence.elements[1] as ASN1Sequence);
    return X509Certificate(
        TbsCertificate.fromAsn1(sequence.elements[0] as ASN1Sequence),
        algorithm,
        toDart(sequence.elements[2]));
  }

  ASN1Sequence toAsn1() {
    return ASN1Sequence()
      ..add(tbsCertificate.toAsn1())
      ..add(signatureAlgorithm.toAsn1())
      ..add(fromDart(signatureValue));
  }

  @override
  String toString([String prefix = '']) {
    var buffer = StringBuffer();
    buffer.writeln('Certificate: ');
    buffer.writeln('\tData:');
    buffer.writeln(tbsCertificate.toString('\t\t'));
    buffer.writeln('\tSignature Algorithm: $signatureAlgorithm');
    buffer.writeln(toHexString(toBigInt(signatureValue!), '$prefix\t\t', 18));
    return buffer.toString();
  }
}

/// An unsigned (To-Be-Signed) certificate.
class TbsCertificate {
  /// The version number of the certificate.
  final int? version;

  /// The serial number of the certificate.
  final int? serialNumber;

  /// The signature of the certificate.
  final AlgorithmIdentifier? signature;

  /// The issuer of the certificate.
  final Name? issuer;

  /// The time interval for which this certificate is valid.
  final Validity? validity;

  /// The subject of the certificate.
  final Name? subject;

  final SubjectPublicKeyInfo? subjectPublicKeyInfo;

  /// The issuer unique id.
  final List<int>? issuerUniqueID;

  /// The subject unique id.
  final List<int>? subjectUniqueID;

  /// List of extensions.
  final List<Extension>? extensions;

  const TbsCertificate(
      {this.version,
      this.serialNumber,
      this.signature,
      this.issuer,
      this.validity,
      this.subject,
      this.subjectPublicKeyInfo,
      this.issuerUniqueID,
      this.subjectUniqueID,
      this.extensions});

  /// Creates a to-be-signed certificate from an [ASN1Sequence].
  ///
  /// The ASN.1 definition is:
  ///
  ///   TBSCertificate  ::=  SEQUENCE  {
  ///     version         [0]  EXPLICIT Version DEFAULT v1,
  ///     serialNumber         CertificateSerialNumber,
  ///     signature            AlgorithmIdentifier,
  ///     issuer               Name,
  ///     validity             Validity,
  ///     subject              Name,
  ///     subjectPublicKeyInfo SubjectPublicKeyInfo,
  ///     issuerUniqueID  [1]  IMPLICIT UniqueIdentifier OPTIONAL,
  ///                          -- If present, version MUST be v2 or v3
  ///     subjectUniqueID [2]  IMPLICIT UniqueIdentifier OPTIONAL,
  ///                          -- If present, version MUST be v2 or v3
  ///     extensions      [3]  EXPLICIT Extensions OPTIONAL
  ///                          -- If present, version MUST be v3 }
  ///
  ///   Version  ::=  INTEGER  {  v1(0), v2(1), v3(2)  }
  ///
  ///   CertificateSerialNumber  ::=  INTEGER
  ///
  ///   UniqueIdentifier  ::=  BIT STRING
  ///
  ///   Extensions  ::=  SEQUENCE SIZE (1..MAX) OF Extension
  ///
  factory TbsCertificate.fromAsn1(ASN1Sequence sequence) {
    var elements = sequence.elements;
    var version = 1;
    if (elements.first.tag == 0xa0) {
      var e =
          ASN1Parser(elements.first.valueBytes()).nextObject() as ASN1Integer;
      version = e.valueAsBigInteger.toInt() + 1;
      elements = elements.skip(1).toList();
    }
    var optionals = elements.skip(6);
    Uint8List? iUid, sUid;
    List<Extension>? ex;
    for (var o in optionals) {
      if (o.tag >> 6 == 2) {
        // context
        switch (o.tag & 0x1f) {
          case 1:
            iUid = o.contentBytes();
            break;
          case 2:
            sUid = o.contentBytes();
            break;
          case 3:
            ex = (ASN1Parser(o.contentBytes()).nextObject() as ASN1Sequence)
                .elements
                .map((v) => Extension.fromAsn1(v as ASN1Sequence))
                .toList();
        }
      }
    }

    return TbsCertificate(
        version: version,
        serialNumber: (elements[0] as ASN1Integer).valueAsBigInteger.toInt(),
        signature: AlgorithmIdentifier.fromAsn1(elements[1] as ASN1Sequence),
        issuer: Name.fromAsn1(elements[2] as ASN1Sequence),
        validity: Validity.fromAsn1(elements[3] as ASN1Sequence),
        subject: Name.fromAsn1(elements[4] as ASN1Sequence),
        subjectPublicKeyInfo:
            SubjectPublicKeyInfo.fromAsn1(elements[5] as ASN1Sequence),
        issuerUniqueID: iUid,
        subjectUniqueID: sUid,
        extensions: ex);
  }

  ASN1Sequence toAsn1() {
    var seq = ASN1Sequence();

    if (version != 1) {
      var v = ASN1Integer(BigInt.from(version! - 1));
      var o = ASN1Object.preEncoded(0xa0, v.encodedBytes);
      var b = o.encodedBytes
        ..setRange(o.encodedBytes.length - v.encodedBytes.length,
            o.encodedBytes.length, v.encodedBytes);
      o = ASN1Object.fromBytes(b);
      seq.add(o);
    }
    seq
      ..add(fromDart(serialNumber))
      ..add(signature!.toAsn1())
      ..add(issuer!.toAsn1())
      ..add(validity!.toAsn1())
      ..add(subject!.toAsn1())
      ..add(subjectPublicKeyInfo!.toAsn1());
    if (version! > 1) {
      if (issuerUniqueID != null) {
        // TODO
        // var iuid = ASN1BitString.fromBytes(issuerUniqueID);
        //ASN1Object.preEncoded(tag, valBytes)
      }
    }
    return seq;
  }

  @override
  String toString([String prefix = '']) {
    var buffer = StringBuffer();
    buffer.writeln('${prefix}Version: $version');
    buffer.writeln('${prefix}Serial Number: $serialNumber');
    buffer.writeln('${prefix}Signature Algorithm: $signature');
    buffer.writeln('${prefix}Issuer: $issuer');
    buffer.writeln('${prefix}Validity:');
    buffer.writeln(validity?.toString('$prefix\t') ?? '');
    buffer.writeln('${prefix}Subject: $subject');
    buffer.writeln('${prefix}Subject Public Key Info:');
    buffer.writeln(subjectPublicKeyInfo?.toString('$prefix\t') ?? '');
    if (extensions != null && extensions!.isNotEmpty) {
      buffer.writeln('${prefix}X509v3 extensions:');
      for (var e in extensions!) {
        buffer.writeln(e.toString('$prefix\t'));
      }
    }
    return buffer.toString();
  }
}
