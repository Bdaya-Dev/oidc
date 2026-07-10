import 'dart:typed_data';

import 'package:asn1lib/asn1lib.dart';
import 'package:test/test.dart';
import 'package:x509_plus/x509.dart';

/// Builds the DER content-octets for [oid] using the (correct) asn1lib arc
/// constructor, so tests do not depend on the broken [ObjectIdentifier.toAsn1].
ASN1ObjectIdentifier _oid(List<int> arcs) => ASN1ObjectIdentifier(arcs);

void main() {
  group('Extension.fromAsn1', () {
    test('rejects an unrecognized critical extension', () {
      final seq = ASN1Sequence()
        ..add(_oid([2, 5, 29, 99])) // unknown ce extension
        ..add(ASN1Boolean(true))
        ..add(ASN1OctetString(ASN1Null().encodedBytes));
      expect(() => Extension.fromAsn1(seq), throwsA(isA<UnimplementedError>()));
    });

    test('keeps an unrecognized non-critical extension as UnknownExtension',
        () {
      final seq = ASN1Sequence()
        ..add(_oid([2, 5, 29, 99]))
        ..add(ASN1OctetString(ASN1Null().encodedBytes));
      final ext = Extension.fromAsn1(seq);
      expect(ext.isCritical, isFalse);
      expect(ext.extnValue, isA<UnknownExtension>());
    });
  });

  group('ExtensionValue dispatch', () {
    test('routes proxy cert info OID to ProxyCertInfo', () {
      final policy = ASN1Sequence()..add(_oid([1, 3, 6, 1, 5, 5, 7, 21, 1]));
      final pci = ASN1Sequence()..add(policy);
      final v = ExtensionValue.fromAsn1(
          pci, ObjectIdentifier([1, 3, 6, 1, 5, 5, 7, 1, 14]));
      expect(v, isA<ProxyCertInfo>());
    });

    test('routes the Google SCT OID to SctList', () {
      final v = ExtensionValue.fromAsn1(
          ASN1OctetString(Uint8List.fromList([1, 2, 3])),
          ObjectIdentifier([1, 3, 6, 1, 4, 1, 11129, 2, 4, 2]));
      expect(v, isA<SctList>());
    });

    test('falls back to UnknownExtension for an unrelated OID', () {
      final v =
          ExtensionValue.fromAsn1(ASN1Null(), ObjectIdentifier([1, 2, 3, 4]));
      expect(v, isA<UnknownExtension>());
      expect((v as UnknownExtension).id, ObjectIdentifier([1, 2, 3, 4]));
    });
  });

  group('ExtendedKeyUsage', () {
    test('toString lists the named purposes', () {
      final eku = ExtendedKeyUsage([
        ObjectIdentifier([1, 3, 6, 1, 5, 5, 7, 3, 1]), // serverAuth
        ObjectIdentifier([1, 3, 6, 1, 5, 5, 7, 3, 2]), // clientAuth
      ]);
      expect(eku.toString(), 'serverAuth, clientAuth');
    });
  });

  group('PrivateKeyUsagePeriod', () {
    test('toString shows both bounds', () {
      final p = PrivateKeyUsagePeriod(
          notBefore: DateTime.utc(2021), notAfter: DateTime.utc(2022));
      expect(p.toString(),
          'NotBefore:${DateTime.utc(2021)}, NotAfter:${DateTime.utc(2022)}');
    });
  });

  group('BasicConstraints', () {
    test('parses cA and pathLenConstraint', () {
      final seq = ASN1Sequence()
        ..add(ASN1Boolean(true))
        ..add(ASN1Integer(BigInt.from(3)));
      final bc = BasicConstraints.fromAsn1(seq);
      expect(bc.cA, isTrue);
      expect(bc.pathLenConstraint, 3);
      expect(bc.toString(), 'CA:TRUE');
    });

    test('defaults cA to false for an empty sequence', () {
      final bc = BasicConstraints.fromAsn1(ASN1Sequence());
      expect(bc.cA, isFalse);
      expect(bc.pathLenConstraint, isNull);
      expect(bc.toString(), 'CA:FALSE');
    });
  });

  group('CertificatePolicies', () {
    test('parses policies and renders them', () {
      final policyInfo = ASN1Sequence()..add(_oid([2, 5, 29, 32, 0]));
      final cp = CertificatePolicies.fromAsn1(ASN1Sequence()..add(policyInfo));
      expect(cp.policies, hasLength(1));
      expect(cp.toString(), contains('Policy:'));
    });
  });

  group('PolicyQualifierInfo', () {
    test('parses a user-notice qualifier with explicit text', () {
      // Note: a noticeRef with noticeNumbers is intentionally omitted because
      // NoticeReference.fromAsn1 throws a TypeError (see bugsFound).
      final userNotice = ASN1Sequence()
        ..add(ASN1PrintableString('See the CPS'));
      final qualifier = ASN1Sequence()
        ..add(_oid([1, 3, 6, 1, 5, 5, 7, 2, 2])) // id-qt-unotice
        ..add(userNotice);

      final pqi = PolicyQualifierInfo.fromAsn1(qualifier);
      expect(pqi.userNotice, isNotNull);
      expect(pqi.userNotice!.explicitText, 'See the CPS');
      expect(pqi.userNotice!.noticeRef, isNull);
      expect(pqi.userNotice.toString(), contains('Explicit Text: See the CPS'));
      expect(pqi.toString(), contains('User Notice'));
    });

    test('rejects an unsupported qualifier id when parsing', () {
      final qualifier = ASN1Sequence()
        ..add(_oid([1, 3, 6, 1, 5, 5, 7, 2, 99]))
        ..add(ASN1PrintableString('x'));
      expect(() => PolicyQualifierInfo.fromAsn1(qualifier),
          throwsA(isA<UnsupportedError>()));
    });

    test('toString throws for an unsupported qualifier id', () {
      final pqi = PolicyQualifierInfo(
          policyQualifierId: ObjectIdentifier([1, 3, 6, 1, 5, 5, 7, 2, 99]),
          cpsUri: 'x');
      expect(() => pqi.toString(), throwsA(isA<UnsupportedError>()));
    });
  });

  group('QCStatements', () {
    test('parses statements and renders them', () {
      final statement = ASN1Sequence()..add(_oid([0, 4, 0, 1862, 1, 1]));
      final v = ExtensionValue.fromAsn1(ASN1Sequence()..add(statement),
          ObjectIdentifier([1, 3, 6, 1, 5, 5, 7, 1, 3]));
      expect(v, isA<QCStatements>());
      final qcs = v as QCStatements;
      expect(qcs.statements, hasLength(1));
      expect(qcs.statements.first.qcStatementInfo, isNull);
      expect(qcs.statements.first.toString(), contains('QCStatement{'));
    });
  });

  group('ProxyCertInfo / ProxyPolicy', () {
    test('parses a proxy policy without path length or policy octets', () {
      final policy = ASN1Sequence()..add(_oid([1, 3, 6, 1, 5, 5, 7, 21, 1]));
      final pci = ProxyCertInfo.fromAsn1(ASN1Sequence()..add(policy));
      expect(pci.pCPathLenConstraint, isNull);
      expect(pci.proxyPolicy.policyLanguage, isA<ObjectIdentifier>());
      expect(pci.proxyPolicy.policy, isNull);
    });
  });

  group('NameConstraints / GeneralSubtree', () {
    test('parses permitted subtrees and leaves excluded empty', () {
      final dns = ASN1Object.preEncoded(
          0x82, Uint8List.fromList('example.com'.codeUnits));
      final subtree = ASN1Sequence()..add(dns);
      final permitted = ASN1Sequence()..add(subtree);
      final v = ExtensionValue.fromAsn1(
          ASN1Sequence()..add(permitted), ObjectIdentifier([2, 5, 29, 30]));
      expect(v, isA<NameConstraints>());
      final nc = v as NameConstraints;
      expect(nc.permittedSubtrees, hasLength(1));
      expect(nc.excludedSubtrees, isEmpty);
      expect(nc.permittedSubtrees.first.minimum, 0);
      expect(nc.permittedSubtrees.first.maximum, isNull);
      expect(nc.permittedSubtrees.first.base.choice, 2); // dNSName
    });

    test('handles an empty NameConstraints sequence', () {
      final nc = NameConstraints.fromAsn1(ASN1Sequence());
      expect(nc.permittedSubtrees, isEmpty);
      expect(nc.excludedSubtrees, isEmpty);
    });

    test('parses both permitted and excluded subtrees', () {
      ASN1Sequence subtreeFor(String host) {
        final dns =
            ASN1Object.preEncoded(0x82, Uint8List.fromList(host.codeUnits));
        return ASN1Sequence()..add(dns);
      }

      final permitted = ASN1Sequence()..add(subtreeFor('permitted.example'));
      final excluded = ASN1Sequence()..add(subtreeFor('excluded.example'));
      final nc = NameConstraints.fromAsn1(ASN1Sequence()
        ..add(permitted)
        ..add(excluded));
      expect(nc.permittedSubtrees, hasLength(1));
      expect(nc.excludedSubtrees, hasLength(1));
    });
  });

  group('DistributionPoint', () {
    test('parses name, reasons and crlIssuer', () {
      final gnUri = ASN1Object.preEncoded(
          0x86, Uint8List.fromList('http://crl.example.com/a.crl'.codeUnits));
      final dpn = ASN1Object.preEncoded(0xA0, gnUri.encodedBytes);
      final nameEl = ASN1Object.preEncoded(0xA0, dpn.encodedBytes);
      final seq = ASN1Sequence()
        ..add(nameEl)
        ..add(ASN1BitString(Uint8List.fromList([1])))
        ..add(ASN1PrintableString('CRL Issuer'));

      final dp = DistributionPoint.fromAsn1(seq);
      expect(dp.name.toString(), contains('http://crl.example.com/a.crl'));
      expect(dp.reasons, isA<List<DistributionPointReason>>());
      expect(dp.crlIssuer, 'CRL Issuer');
    });
  });

  group('DistributionPointName', () {
    test('parses a nameRelativeToCRLIssuer choice', () {
      final obj = ASN1Object.preEncoded(0xA1, ASN1Sequence().encodedBytes);
      final dpn = DistributionPointName.fromAsn1(obj);
      expect(dpn.choice, 1);
      expect(dpn.relativeDistinguishedName, isNotNull);
      expect(dpn.generalNames, isNull);
      expect(dpn.toString(), startsWith('CRLIssuer:'));
    });

    test('rejects an unsupported choice', () {
      final obj = ASN1Object.preEncoded(0xA2, ASN1Sequence().encodedBytes);
      expect(() => DistributionPointName.fromAsn1(obj),
          throwsA(isA<UnsupportedError>()));
    });
  });

  group('GeneralName choices', () {
    test('parses an IP address', () {
      final gn = GeneralName.fromAsn1(
          ASN1Object.preEncoded(0x87, Uint8List.fromList([127, 0, 0, 1])));
      expect(gn.choice, 7);
      expect(gn.isConstructed, isFalse);
      expect(gn.toString(), startsWith('IPAddress:'));
    });

    test('parses a registeredID', () {
      final oidTlv = ASN1ObjectIdentifier([2, 5, 4, 3]).encodedBytes;
      final gn = GeneralName.fromAsn1(ASN1Object.preEncoded(0x88, oidTlv));
      expect(gn.choice, 8);
      expect(gn.toString(), startsWith('registeredID:'));
    });

    test('parses a constructed choice by re-parsing its contents', () {
      final inner = ASN1PrintableString('x').encodedBytes;
      final gn = GeneralName.fromAsn1(ASN1Object.preEncoded(0xA0, inner));
      expect(gn.isConstructed, isTrue);
      expect(gn.choice, 0);
      expect(gn.toString(), startsWith('otherName:'));
    });

    test('keeps unsupported primitive choices verbatim', () {
      for (final entry in {0x83: 3, 0x84: 4, 0x85: 5}.entries) {
        final gn = GeneralName.fromAsn1(
            ASN1Object.preEncoded(entry.key, Uint8List.fromList([1, 2])));
        expect(gn.choice, entry.value);
        expect(gn.isConstructed, isFalse);
        expect(gn.contents, isA<ASN1Object>());
      }
    });
  });
}
