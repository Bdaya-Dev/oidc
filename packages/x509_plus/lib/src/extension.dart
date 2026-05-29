part of 'x509_base.dart';

/// An X.509 extension
class Extension {
  /// The extension's object identifier.
  final ObjectIdentifier extnId;

  /// Returns `true` if this extension is critical.
  ///
  ///  A certificate-using system MUST reject the certificate if it encounters
  ///  a critical extension it does not recognize or a critical extension
  ///  that contains information that it cannot process.  A non-critical
  ///  extension MAY be ignored if it is not recognized, but MUST be
  ///  processed if it is recognized.
  final bool isCritical;

  /// The extension's value.
  final ExtensionValue extnValue;

  const Extension(
      {required this.extnId, this.isCritical = false, required this.extnValue});

  /// Creates a Extension from an [ASN1Sequence].
  ///
  /// The ASN.1 definition is:
  ///
  ///   Extension  ::=  SEQUENCE  {
  ///     extnID      OBJECT IDENTIFIER,
  ///     critical    BOOLEAN DEFAULT FALSE,
  ///     extnValue   OCTET STRING
  ///                 -- contains the DER encoding of an ASN.1 value
  ///                 -- corresponding to the extension type identified
  ///                 -- by extnID
  ///   }
  factory Extension.fromAsn1(ASN1Sequence sequence) {
    var id = toDart(sequence.elements[0]);
    var critical = false;
    var octetIndex = 1;
    if (sequence.elements.length > 2) {
      critical = toDart(sequence.elements[1]);
      octetIndex = 2;
    }

    final value = ExtensionValue.fromAsn1(
      ASN1Parser(
        sequence.elements[octetIndex].contentBytes(),
      ).nextObject(),
      id,
    );
    if (value is UnknownExtension && critical) {
      throw UnimplementedError(
          'Cannot handle critical extension $id (${id.parent} ${id.nodes.last})');
    }

    return Extension(extnId: id, isCritical: critical, extnValue: value);
  }

  @override
  String toString([String prefix = '']) {
    var buffer = StringBuffer();
    buffer.writeln("$prefix$extnId: ${isCritical ? "critical" : ""}");
    buffer.writeln('$prefix\t$extnValue');
    return buffer.toString();
  }
}

/// The base class for extension values.
abstract class ExtensionValue {
  static const ceId = ObjectIdentifier([2, 5, 29]);
  static const peId = ObjectIdentifier([1, 3, 6, 1, 5, 5, 7, 1]);
  static const goog24Id = ObjectIdentifier([1, 3, 6, 1, 4, 1, 11129, 2, 4]);

  const ExtensionValue();

  /// Creates an extension value from an [ASN1Object].
  ///
  /// [id] defines the type of extension to create.
  factory ExtensionValue.fromAsn1(ASN1Object obj, ObjectIdentifier id) {
    if (id.parent == ceId) {
      switch (id.nodes.last) {
        case 35:
          return AuthorityKeyIdentifier.fromAsn1(obj as ASN1Sequence);
        case 14:
          return SubjectKeyIdentifier.fromAsn1(obj);
        case 15:
          return KeyUsage.fromAsn1(obj as ASN1BitString);
        case 32:
          return CertificatePolicies.fromAsn1(obj as ASN1Sequence);
        case 31:
          return CrlDistributionPoints.fromAsn1(obj as ASN1Sequence);
        case 17: // subject alternative name extension
        case 18: // issuer alternative name extension
          return GeneralNames.fromAsn1(obj as ASN1Sequence);
        case 9: // TODO: subject directory attributes extension
        case 30:
          return NameConstraints.fromAsn1(obj as ASN1Sequence);
        case 33: // TODO: policy mappings extension
        case 36: // TODO: policy constraints extension
          break;
        case 19:
          return BasicConstraints.fromAsn1(obj as ASN1Sequence);
        case 37:
          return ExtendedKeyUsage.fromAsn1(obj as ASN1Sequence);
        case 16:
          return PrivateKeyUsagePeriod.fromAsn1(obj as ASN1Sequence);
      }
    }
    if (id.parent == peId) {
      switch (id.nodes.last) {
        case 1:
          return AuthorityInformationAccess.fromAsn1(obj as ASN1Sequence);
        case 3:
          return QCStatements.fromAsn1(obj as ASN1Sequence);
        case 14:
          return ProxyCertInfo.fromAsn1(obj as ASN1Sequence);
      }
    }
    if (id.parent == goog24Id) {
      switch (id.nodes.last) {
        case 2:
          return SctList.fromAsn1(obj as ASN1OctetString);
      }
    }
    return UnknownExtension(obj, id);
  }
}

/// An authority key identifier extension value.
///
/// The authority key identifier extension provides a means of identifying the
/// public key corresponding to the private key used to sign a certificate.
class AuthorityKeyIdentifier extends ExtensionValue {
  final List<int>? keyIdentifier;
  final GeneralNames? authorityCertIssuer;
  final BigInt? authorityCertSerialNumber;

  AuthorityKeyIdentifier(this.keyIdentifier, this.authorityCertIssuer,
      this.authorityCertSerialNumber);

  /// Creates an authority key identifier extension value from an [ASN1Sequence].
  ///
  /// The ASN.1 definition is:
  ///
  ///   AuthorityKeyIdentifier ::= SEQUENCE {
  ///     keyIdentifier             [0] KeyIdentifier           OPTIONAL,
  ///     authorityCertIssuer       [1] GeneralNames            OPTIONAL,
  ///     authorityCertSerialNumber [2] CertificateSerialNumber OPTIONAL  }
  ///
  ///   KeyIdentifier ::= OCTET STRING
  factory AuthorityKeyIdentifier.fromAsn1(ASN1Sequence sequence) {
    Uint8List? keyId;
    GeneralNames? issuer;
    BigInt? number;
    for (var o in sequence.elements) {
      switch (o.tag & 0x1f) {
        case 0:
          keyId = o.contentBytes();
          break;
        case 1:
          issuer = GeneralNames.fromAsn1(o);
          break;
        case 2:
          number =
              (ASN1Parser(o.encodedBytes..[0] = 2).nextObject() as ASN1Integer)
                  .valueAsBigInteger;
      }
    }
    return AuthorityKeyIdentifier(keyId, issuer, number);
  }
}

/// The subject key identifier extension provides a means of identifying
/// certificates that contain a particular public key.
class SubjectKeyIdentifier extends ExtensionValue {
  final List<int>? keyIdentifier;

  SubjectKeyIdentifier(this.keyIdentifier);

  factory SubjectKeyIdentifier.fromAsn1(ASN1Object obj) {
    return SubjectKeyIdentifier(obj.contentBytes());
  }
}

/// The key usage extension defines the purpose (e.g., encipherment, signature,
/// certificate signing) of the key contained in the certificate.
class KeyUsage extends ExtensionValue {
  /// True when the subject public key is used for verifying digital signatures,
  /// other than signatures on certificates and CRLs, such as those used in an
  /// entity authentication service, a data origin authentication service,
  /// and/or an integrity service.
  final bool digitalSignature;

  /// True when the subject public key is used to verify digital signatures,
  /// other than signatures on certificates and CRLs, used to provide a
  /// non-repudiation service that protects against the signing entity falsely
  /// denying some action.  In the case of later conflict, a reliable third
  /// party may determine the authenticity of the signed data.
  ///
  /// Note that recent editions of X.509 have renamed the nonRepudiation bit to
  /// contentCommitment.
  final bool nonRepudiation;

  /// True when the subject public key is used for enciphering private or secret
  /// keys, i.e., for key transport.
  ///
  /// For example, this bit shall be set when an RSA public key is to be used
  /// for encrypting a symmetric content-decryption key or an asymmetric private
  /// key.
  final bool keyEncipherment;

  /// True when the subject public key is used for directly enciphering raw user
  /// data without the use of an intermediate symmetric cipher.
  ///
  /// Note that the use of this bit is extremely uncommon; almost all
  /// applications use key transport or key agreement to establish a symmetric
  /// key.
  final bool dataEncipherment;

  /// True when the subject public key is used for key agreement.
  ///
  /// For example, when a Diffie-Hellman key is to be used for key management,
  /// then this bit is set.
  final bool keyAgreement;

  /// True when the subject public key is used for verifying signatures on
  /// public key certificates.
  ///
  /// If the keyCertSign bit is asserted, then the cA bit in the basic
  /// constraints extension MUST also be asserted.
  final bool keyCertSign;

  /// True when the subject public key is used for verifying signatures on
  /// certificate revocation lists (e.g., CRLs, delta CRLs, or ARLs).
  final bool cRLSign;

  /// When true (and the keyAgreement bit is also set), the subject public key
  /// may be used only for enciphering data while performing key agreement.
  final bool encipherOnly;

  /// When true (and the keyAgreement bit is also set), the subject public key
  /// may be used only for deciphering data while performing key agreement.
  final bool decipherOnly;

  const KeyUsage(
      {required this.digitalSignature,
      required this.nonRepudiation,
      required this.keyEncipherment,
      required this.dataEncipherment,
      required this.keyAgreement,
      required this.keyCertSign,
      required this.cRLSign,
      required this.encipherOnly,
      required this.decipherOnly});

  /// Creates a key usage extension from an [ASN1BitString].
  ///
  /// The ASN.1 definition is:
  ///
  ///   KeyUsage ::= BIT STRING {
  ///     digitalSignature        (0),
  ///     nonRepudiation          (1), -- recent editions of X.509 have
  ///                                  -- renamed this bit to contentCommitment
  ///     keyEncipherment         (2),
  ///     dataEncipherment        (3),
  ///     keyAgreement            (4),
  ///     keyCertSign             (5),
  ///     cRLSign                 (6),
  ///     encipherOnly            (7),
  ///     decipherOnly            (8) }
  factory KeyUsage.fromAsn1(ASN1BitString bitString) {
    var bits = bitString.stringValue
        .map((v) => (v + 256).toRadixString(2).substring(1))
        .join()
        .split('')
        .map((v) => v == '1')
        .toList();
    bits = bits.take(bits.length - bitString.unusedbits).toList();
    bits.addAll(Iterable.generate(9, (_) => false));
    bits = bits.take(9).toList();
    return KeyUsage(
        digitalSignature: bits[0],
        nonRepudiation: bits[1],
        keyEncipherment: bits[2],
        dataEncipherment: bits[3],
        keyAgreement: bits[4],
        keyCertSign: bits[5],
        cRLSign: bits[6],
        encipherOnly: bits[7],
        decipherOnly: bits[8]);
  }

  @override
  String toString() => [
        digitalSignature ? 'Digital Signature' : null
        // TODO others
      ].where((v) => v != null).join(',');
}

/// This extension indicates one or more purposes for which the certified
/// public key may be used, in addition to or in place of the basic purposes
/// indicated in the key usage extension.
class ExtendedKeyUsage extends ExtensionValue {
  final List<ObjectIdentifier> ids;

  const ExtendedKeyUsage(this.ids);

  factory ExtendedKeyUsage.fromAsn1(ASN1Sequence sequence) {
    return ExtendedKeyUsage((toDart(sequence) as List).cast());
  }

  @override
  String toString() => ids.join(', ');
}

class PrivateKeyUsagePeriod extends ExtensionValue {
  final DateTime? notBefore;
  final DateTime? notAfter;

  PrivateKeyUsagePeriod({this.notBefore, this.notAfter});

  /// Creates a basic constraints extension value from an [ASN1Sequence].
  ///
  /// The ASN.1 definition is:
  ///
  ///    PrivateKeyUsagePeriod ::= SEQUENCE {
  ///      notBefore       [0]     GeneralizedTime OPTIONAL,
  ///      notAfter        [1]     GeneralizedTime OPTIONAL }
  factory PrivateKeyUsagePeriod.fromAsn1(ASN1Sequence sequence) {
    DateTime? notBefore;
    DateTime? notAfter;
    for (var o in sequence.elements) {
      var taggedObject = o;
      if (taggedObject.tag == 128) {
        notBefore = ASN1GeneralizedTime.fromBytes(o.encodedBytes).dateTimeValue;
      } else if (taggedObject.tag == 129) {
        notAfter = ASN1GeneralizedTime.fromBytes(o.encodedBytes).dateTimeValue;
      }
    }
    return PrivateKeyUsagePeriod(notBefore: notBefore, notAfter: notAfter);
  }

  @override
  String toString() => 'NotBefore:$notBefore, NotAfter:$notAfter';
}

/// The basic constraints extension identifies whether the subject of the
/// certificate is a CA and the maximum depth of valid certification paths
/// that include this certificate.
class BasicConstraints extends ExtensionValue {
  final bool cA;
  final int? pathLenConstraint;

  BasicConstraints({this.cA = false, this.pathLenConstraint});

  /// Creates a basic constraints extension value from an [ASN1Sequence].
  ///
  /// The ASN.1 definition is:
  ///
  ///   BasicConstraints ::= SEQUENCE {
  ///       cA                      BOOLEAN DEFAULT FALSE,
  ///       pathLenConstraint       INTEGER (0..MAX) OPTIONAL }
  factory BasicConstraints.fromAsn1(ASN1Sequence sequence) {
    var cA = false;
    int? len;
    for (var o in sequence.elements) {
      if (o is ASN1Boolean) {
        cA = o.booleanValue;
      }
      if (o is ASN1Integer) {
        len = o.intValue;
      }
    }
    return BasicConstraints(cA: cA, pathLenConstraint: len);
  }

  @override
  String toString() => [
        "CA:${"$cA".toUpperCase()}"
        // TODO: path length constraint
      ].join(',');
}

/// The certificate policies extension contains a sequence of one or more policy
/// information terms, each of which consists of an object identifier (OID) and
/// optional qualifiers.
class CertificatePolicies extends ExtensionValue {
  final List<PolicyInformation> policies;

  CertificatePolicies({required this.policies});

  /// Creates a certificate policies extension value from an [ASN1Sequence].
  ///
  /// The ASN.1 definition is:
  ///
  ///   CertificatePolicies ::= SEQUENCE SIZE (1..MAX) OF PolicyInformation
  factory CertificatePolicies.fromAsn1(ASN1Sequence sequence) {
    return CertificatePolicies(policies: [
      for (var e in sequence.elements)
        PolicyInformation.fromAsn1(e as ASN1Sequence)
    ]);
  }

  @override
  String toString([String prefix = '']) =>
      policies.map((p) => p.toString(prefix)).join('\n');
}

class PolicyInformation {
  final ObjectIdentifier policyIdentifier;

  final List<PolicyQualifierInfo> policyQualifiers;

  PolicyInformation(
      {required this.policyIdentifier, this.policyQualifiers = const []});

  /// The ASN.1 definition is:
  ///
  ///   PolicyInformation ::= SEQUENCE {
  ///     policyIdentifier   CertPolicyId,
  ///     policyQualifiers   SEQUENCE SIZE (1..MAX) OF PolicyQualifierInfo OPTIONAL }
  factory PolicyInformation.fromAsn1(ASN1Sequence sequence) {
    var policyIdentifier = toDart(sequence.elements[0]);
    var policyQualifiers = <PolicyQualifierInfo>[];
    if (sequence.elements.length > 1) {
      policyQualifiers.addAll((sequence.elements[1] as ASN1Sequence)
          .elements
          .map((e) => PolicyQualifierInfo.fromAsn1(e as ASN1Sequence)));
    }
    return PolicyInformation(
        policyIdentifier: policyIdentifier, policyQualifiers: policyQualifiers);
  }

  @override
  String toString([String prefix = '']) {
    var buffer = StringBuffer();
    String piString;
    try {
      piString = policyIdentifier.toString();
    } catch (e) {
      if (e is UnknownOIDNameError) {
        // It is unique definition policy. should not convert name.
        // In this case, to be just combined numbers.
        piString = policyIdentifier.nodes.map((i) => i.toString()).join('.');
      } else {
        rethrow;
      }
    }
    buffer.writeln('${prefix}Policy: $piString');
    buffer.writeln(
        policyQualifiers.map((q) => q.toString('$prefix\t')).join('\n'));
    return buffer.toString();
  }
}

class PolicyQualifierInfo {
  final ObjectIdentifier policyQualifierId;

  final String? cpsUri;

  final UserNotice? userNotice;

  PolicyQualifierInfo(
      {required this.policyQualifierId, this.cpsUri, this.userNotice})
      : assert(cpsUri != null || userNotice != null);

  /// The ASN.1 definition is:
  ///
  ///   PolicyQualifierInfo ::= SEQUENCE {
  ///     policyQualifierId  PolicyQualifierId,
  ///     qualifier          ANY DEFINED BY policyQualifierId }
  factory PolicyQualifierInfo.fromAsn1(ASN1Sequence sequence) {
    var policyQualifierId = toDart(sequence.elements[0]) as ObjectIdentifier;

    switch (policyQualifierId.nodes.last) {
      case 1: // cps
        var cpsUri = toDart(sequence.elements[1]);
        return PolicyQualifierInfo(
            policyQualifierId: policyQualifierId, cpsUri: cpsUri);
      case 2: // unotice
        return PolicyQualifierInfo(
            policyQualifierId: policyQualifierId,
            userNotice:
                UserNotice.fromAsn1(sequence.elements[1] as ASN1Sequence));
    }
    throw UnsupportedError(
        'Policy qualifier id $policyQualifierId not supported');
  }

  @override
  String toString([String prefix = '']) {
    switch (policyQualifierId.nodes.last) {
      case 1: // cps
        return '${prefix}CPS: $cpsUri';
      case 2: // unotice
        return '${prefix}User Notice:\n'
            '${userNotice?.toString('$prefix\t')}';
    }
    throw UnsupportedError(
        'Policy qualifier id $policyQualifierId not supported');
  }
}

class UserNotice {
  final NoticeReference? noticeRef;
  final String? explicitText;

  UserNotice({this.noticeRef, this.explicitText});

  /// The ASN.1 definition is:
  ///
  ///   UserNotice ::= SEQUENCE {
  ///     noticeRef        NoticeReference OPTIONAL,
  ///     explicitText     DisplayText OPTIONAL }
  factory UserNotice.fromAsn1(ASN1Sequence sequence) {
    NoticeReference? noticeRef;
    String? explicitText;
    for (var e in sequence.elements) {
      if (e is ASN1Sequence) {
        noticeRef = NoticeReference.fromAsn1(e);
      } else {
        explicitText = toDart(e);
      }
    }
    return UserNotice(noticeRef: noticeRef, explicitText: explicitText);
  }

  @override
  String toString([String prefix = '']) {
    var buffer = StringBuffer();
    if (explicitText != null) {
      buffer.writeln('${prefix}Explicit Text: $explicitText');
    }
    if (noticeRef != null) {
      buffer.writeln('${prefix}Notice Reference: $noticeRef');
    }
    return buffer.toString();
  }
}

class NoticeReference {
  final String organization;

  final List<int> noticeNumbers;

  NoticeReference({required this.organization, required this.noticeNumbers});

  /// The ASN.1 definition is:
  ///
  ///   NoticeReference ::= SEQUENCE {
  ///     organization     DisplayText,
  ///     noticeNumbers    SEQUENCE OF INTEGER }
  factory NoticeReference.fromAsn1(ASN1Sequence sequence) {
    return NoticeReference(
        organization: toDart(sequence.elements[0]),
        noticeNumbers: toDart(sequence.elements[1]));
  }

  @override
  String toString() => '$organization $noticeNumbers';
}

/// The CRL distribution points extension identifies how CRL information is
/// obtained.
class CrlDistributionPoints extends ExtensionValue {
  final List<DistributionPoint> points;
  CrlDistributionPoints({required this.points});

  /// The ASN.1 definition is:
  ///
  ///   CRLDistributionPoints ::= SEQUENCE SIZE (1..MAX) OF DistributionPoint
  factory CrlDistributionPoints.fromAsn1(ASN1Sequence sequence) {
    return CrlDistributionPoints(points: [
      for (var e in sequence.elements)
        DistributionPoint.fromAsn1(e as ASN1Sequence)
    ]);
  }
}

class DistributionPoint {
  final DistributionPointName? name;
  final List<DistributionPointReason>? reasons;
  final String? crlIssuer;

  DistributionPoint({this.name, this.reasons, this.crlIssuer});

  /// The ASN.1 definition is:
  ///
  ///   DistributionPoint ::= SEQUENCE {
  ///     distributionPoint       [0]     DistributionPointName OPTIONAL,
  ///     reasons                 [1]     ReasonFlags OPTIONAL,
  ///     cRLIssuer               [2]     GeneralNames OPTIONAL }
  factory DistributionPoint.fromAsn1(ASN1Sequence sequence) {
    var name = sequence.elements.isEmpty
        ? null
        : DistributionPointName.fromAsn1(
            ASN1Object.fromBytes(sequence.elements[0].valueBytes()));
    var reasons = sequence.elements.length <= 1
        ? null
        : (sequence.elements[1] as ASN1BitString)
            .valueBytes()
            .map((v) => DistributionPointReason.values[v])
            .toList();

    var crlIssuer =
        sequence.elements.length <= 2 ? null : toDart(sequence.elements[2]);
    return DistributionPoint(
        name: name, reasons: reasons, crlIssuer: crlIssuer);
  }
}

class DistributionPointName {
  final int choice;
  final GeneralNames? generalNames;
  final RelativeDistinguishedName? relativeDistinguishedName;
  static final _choiceName = [
    'Full Name',
    'CRLIssuer',
  ];

  DistributionPointName(
      this.choice, this.generalNames, this.relativeDistinguishedName);

  // DistributionPointName ::= CHOICE {
  //   fullName [0] GeneralNames,
  //   nameRelativeToCRLIssuer [1] RelativeDistinguishedName
  // }
  factory DistributionPointName.fromAsn1(ASN1Object obj) {
    var choice = 0x1F & obj.tag;
    var childObj = ASN1Parser(obj.valueBytes()).nextObject();
    GeneralNames? generalNames;
    RelativeDistinguishedName? relativeName;

    switch (choice) {
      case 0:
        generalNames = GeneralNames.fromAsn1(childObj);
        break;
      case 1:
        relativeName = RelativeDistinguishedName();
        break;
      default:
        throw UnsupportedError(
            'Not supported CHOICE ($choice) by DistributionPointName.');
    }
    return DistributionPointName(choice, generalNames, relativeName);
  }

  @override
  String toString() {
    String contentsString;
    if (generalNames != null) {
      contentsString = generalNames.toString();
    } else {
      contentsString = relativeDistinguishedName.toString();
    }
    return '${_choiceName[choice]}: $contentsString';
  }
}

class RelativeDistinguishedName {}

enum DistributionPointReason {
  unused,
  keyCompromise,
  cACompromise,
  affiliationChanged,
  superseded,
  cessationOfOperation,
  certificateHold,
  privilegeWithdrawn,
  aACompromise
}

/// The authority information access extension indicates how to access
/// information and services for the issuer of the certificate in which
/// the extension appears.
///
/// Information and services may include on-line validation services and CA
/// policy data.
class AuthorityInformationAccess extends ExtensionValue {
  final List<AccessDescription> descriptions;

  AuthorityInformationAccess({required this.descriptions});

  /// The ASN.1 definition is:
  ///
  ///   AuthorityInfoAccessSyntax  ::=
  ///     SEQUENCE SIZE (1..MAX) OF AccessDescription
  factory AuthorityInformationAccess.fromAsn1(ASN1Sequence sequence) {
    return AuthorityInformationAccess(descriptions: [
      for (var e in sequence.elements)
        AccessDescription.fromAsn1(e as ASN1Sequence)
    ]);
  }
}

class QCStatements extends ExtensionValue {
  final List<QCStatement> statements;

  QCStatements({required this.statements});

  factory QCStatements.fromAsn1(ASN1Sequence sequence) {
    return QCStatements(statements: [
      for (var i in sequence.elements) QCStatement.fromAsn1(i as ASN1Sequence)
    ]);
  }
}

class QCStatement {
  final ObjectIdentifier statementId;
  final dynamic qcStatementInfo;

  /// The ASN.1 definition is:
  ///
  ///  QCStatement ::= SEQUENCE {
  ///  statementId        OBJECT IDENTIFIER,
  ///  statementInfo      ANY DEFINED BY statementId OPTIONAL}
  QCStatement({required this.statementId, required this.qcStatementInfo});

  factory QCStatement.fromAsn1(ASN1Sequence sequence) {
    var statementId = ObjectIdentifier.fromAsn1(
        ASN1ObjectIdentifier.fromBytes(sequence.elements[0].encodedBytes));

    dynamic qcStatementInfo;
    if (sequence.elements.length > 1) {
      qcStatementInfo = toDart(sequence.elements[1]);
    }

    return QCStatement(
        statementId: statementId, qcStatementInfo: qcStatementInfo);
  }

  @override
  String toString() {
    return 'QCStatement{statementId: $statementId, qcStatementInfo: $qcStatementInfo}';
  }
}

class AccessDescription {
  final ObjectIdentifier? accessMethod;
  final String? accessLocation;

  AccessDescription({this.accessLocation, this.accessMethod});

  /// The ASN.1 definition is:
  ///   AccessDescription  ::=  SEQUENCE {
  ///     accessMethod          OBJECT IDENTIFIER,
  ///     accessLocation        GeneralName  }
  factory AccessDescription.fromAsn1(ASN1Sequence sequence) {
    return AccessDescription(
        accessMethod: toDart(sequence.elements[0]),
        accessLocation: toDart(sequence.elements[1]));
  }
}

class GeneralName {
  final bool isConstructed;
  final int choice;
  final ASN1Object contents;

  GeneralName(
      {required this.isConstructed,
      required this.choice,
      required this.contents});

  /// The ASN.1 definition is:
  ///   GeneralName ::= CHOICE {
  //       otherName                       [0]     OtherName,
  //       rfc822Name                      [1]     IA5String,
  //       dNSName                         [2]     IA5String,
  //       x400Address                     [3]     ORAddress,
  //       directoryName                   [4]     Name,
  //       ediPartyName                    [5]     EDIPartyName,
  //       uniformResourceIdentifier       [6]     IA5String,
  //       iPAddress                       [7]     OCTET STRING,
  //       registeredID                    [8]     OBJECT IDENTIFIER}
  static final _choiceName = [
    'otherName',
    'rfc822Name',
    'DNS',
    'x400Address',
    'directoryName',
    'ediPartyName',
    'URI',
    'IPAddress',
    'registeredID',
  ];

  factory GeneralName.fromAsn1(ASN1Object obj) {
    var tag = obj.tag;
    var isConstructed = (0xA0 & tag) == 0xA0;
    var choice = 0x1F & tag;
    ASN1Object? contents;
    if (isConstructed) {
      contents = ASN1Parser(obj.valueBytes()).nextObject();
    } else {
      switch (choice) {
        case 1:
        case 2:
        case 6:
          contents = ASN1IA5String(String.fromCharCodes(obj.valueBytes()));
          break;
        case 7: // IPAddress (OctetString)
          contents = ASN1OctetString(obj.valueBytes());
          break;
        case 8: // registeredID (ObjectIdentifier)
          contents = ASN1ObjectIdentifier.fromBytes(obj.valueBytes());
          break;
        case 0: // TODO: unimplemented.
        case 3:
        case 4:
        case 5: // ediPartyName
          //  EDIPartyName ::= SEQUENCE {
          //   nameAssigner            [0]     DirectoryString OPTIONAL,
          //   partyName               [1]     DirectoryString }
          log('Warning Not Supported CHOICE($choice).');
          contents = obj;
      }
    }
    return GeneralName(
        isConstructed: isConstructed, choice: choice, contents: contents!);
  }

  @override
  String toString() {
    String contentsString;
    if (contents is ASN1IA5String) {
      contentsString = (contents as ASN1IA5String).stringValue;
    } else if (contents is ASN1OctetString) {
      contentsString = (contents as ASN1OctetString).stringValue;
    } else {
      contentsString = contents.toString();
    }
    return '${_choiceName[choice]}:$contentsString';
  }
}

class GeneralNames extends ExtensionValue {
  List<GeneralName> names;

  GeneralNames(this.names);

  //GeneralNames :: = SEQUENCE SIZE (1..MAX) OF GeneralName
  factory GeneralNames.fromAsn1(ASN1Object obj) {
    if (obj is ASN1Sequence) {
      var sequence = obj;
      return GeneralNames(sequence.elements.map((n) {
        return GeneralName.fromAsn1(n);
      }).toList());
    } else {
      var name = GeneralName.fromAsn1(obj);
      return GeneralNames([name]);
    }
  }

  @override
  String toString() {
    return names.map((n) => n.toString()).join(', ');
  }
}

class NameConstraints extends ExtensionValue {
  final List<GeneralSubtree> permittedSubtrees;

  final List<GeneralSubtree> excludedSubtrees;

  // NameConstraints ::= SEQUENCE {
  //   permittedSubtrees       [0]     GeneralSubtrees OPTIONAL,
  //   excludedSubtrees        [1]     GeneralSubtrees OPTIONAL }
  factory NameConstraints.fromAsn1(ASN1Sequence obj) {
    var s1 = obj.elements.isNotEmpty ? obj.elements[0] as ASN1Sequence : null;
    var s2 = obj.elements.length > 1 ? obj.elements[1] as ASN1Sequence : null;

    return NameConstraints(
      permittedSubtrees: [
        if (s1 != null)
          for (var v in s1.elements) GeneralSubtree.fromAsn1(v as ASN1Sequence),
      ],
      excludedSubtrees: [
        if (s2 != null)
          for (var v in s2.elements) GeneralSubtree.fromAsn1(v as ASN1Sequence),
      ],
    );
  }

  NameConstraints(
      {this.permittedSubtrees = const [], this.excludedSubtrees = const []});
}

class GeneralSubtree {
  final GeneralName base;

  final int minimum;

  final int? maximum;

  GeneralSubtree({required this.base, this.minimum = 0, this.maximum});

  // GeneralSubtree ::= SEQUENCE {
  //   base                    GeneralName,
  //   minimum         [0]     BaseDistance DEFAULT 0,
  //   maximum         [1]     BaseDistance OPTIONAL }
  factory GeneralSubtree.fromAsn1(ASN1Sequence obj) {
    return GeneralSubtree(
        base: GeneralName.fromAsn1(obj.elements[0]),
        minimum: obj.elements.length > 1 ? toDart(obj.elements[1]) : 0,
        maximum: obj.elements.length > 2 ? toDart(obj.elements[2]) : null);
  }
}

class ProxyCertInfo extends ExtensionValue {
  final BigInt? pCPathLenConstraint;

  final ProxyPolicy proxyPolicy;

  // ProxyCertInfoExtension  ::= SEQUENCE {
  //   pCPathLenConstraint     ProxyCertPathLengthConstraint OPTIONAL,
  //   proxyPolicy             ProxyPolicy
  // }
  factory ProxyCertInfo.fromAsn1(ASN1Sequence obj) {
    return ProxyCertInfo(
        pCPathLenConstraint:
            obj.elements.length > 1 ? toDart(obj.elements[0]) : null,
        proxyPolicy: ProxyPolicy.fromAsn1(obj.elements.last as ASN1Sequence));
  }

  ProxyCertInfo({this.pCPathLenConstraint, required this.proxyPolicy});
}

class ProxyPolicy {
  final ObjectIdentifier policyLanguage;

  final String? policy;

  // ProxyPolicy  ::= SEQUENCE {
  //   policyLanguage          OBJECT IDENTIFIER,
  //   policy                  OCTET STRING OPTIONAL
  // }
  factory ProxyPolicy.fromAsn1(ASN1Sequence obj) {
    return ProxyPolicy(
        policyLanguage:
            ObjectIdentifier.fromAsn1(obj.elements[0] as ASN1ObjectIdentifier),
        policy: obj.elements.length > 1 ? toDart(obj.elements[1]) : null);
  }

  ProxyPolicy({required this.policyLanguage, this.policy});
}

class UnknownExtension extends ExtensionValue {
  final ASN1Object object;
  final ObjectIdentifier id;

  UnknownExtension(this.object, this.id);
}

class SctList extends ExtensionValue {
  SctList.fromAsn1(ASN1OctetString octetString);
}
