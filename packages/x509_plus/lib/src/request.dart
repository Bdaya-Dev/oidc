part of 'x509_base.dart';

/// https://tools.ietf.org/html/rfc2986
class CertificationRequest {
  final CertificationRequestInfo certificationRequestInfo;
  final AlgorithmIdentifier signatureAlgorithm;
  final Uint8List signature;

  CertificationRequest(
      this.certificationRequestInfo, this.signatureAlgorithm, this.signature);

  /// CertificationRequest ::= SEQUENCE {
  ///   certificationRequestInfo CertificationRequestInfo,
  ///   signatureAlgorithm AlgorithmIdentifier{{ SignatureAlgorithms }},
  ///   signature          BIT STRING
  /// }
  factory CertificationRequest.fromAsn1(ASN1Sequence sequence) {
    final algorithm =
        AlgorithmIdentifier.fromAsn1(sequence.elements[1] as ASN1Sequence);
    return CertificationRequest(
        CertificationRequestInfo.fromAsn1(sequence.elements[0] as ASN1Sequence),
        algorithm,
        (sequence.elements[2] as ASN1BitString).contentBytes());
  }
}

class CertificationRequestInfo {
  final int? version;
  final Name subject;
  final SubjectPublicKeyInfo subjectPublicKeyInfo;
  final Map<String, List<dynamic>>? attributes;

  CertificationRequestInfo(
      this.version, this.subject, this.subjectPublicKeyInfo, this.attributes);

  /// CertificationRequestInfo ::= SEQUENCE {
  ///   version       INTEGER { v1(0) } (v1,...),
  ///   subject       Name,
  ///   subjectPKInfo SubjectPublicKeyInfo{{ PKInfoAlgorithms }},
  ///   attributes    [0] Attributes{{ CRIAttributes }}
  /// }
  factory CertificationRequestInfo.fromAsn1(ASN1Sequence sequence) {
    return CertificationRequestInfo(
        toDart(sequence.elements[0]).toInt() + 1,
        Name.fromAsn1(sequence.elements[1] as ASN1Sequence),
        SubjectPublicKeyInfo.fromAsn1(sequence.elements[2] as ASN1Sequence),
        null /*TODO*/);
  }
}
