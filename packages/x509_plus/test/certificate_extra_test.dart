// Reads DER fixtures from disk in setUpAll: dart:io File reads cannot run on
// the web platform (see #353's convention: fixture tests are pinned to vm).
@TestOn('vm')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:asn1lib/asn1lib.dart';
import 'package:test/test.dart';
import 'package:x509_plus/x509.dart';

void main() {
  group('TbsCertificate.fromAsn1 optional unique IDs', () {
    // RFC 5280 §4.1.2.8 defines `issuerUniqueID` ([1] IMPLICIT) and
    // `subjectUniqueID` ([2] IMPLICIT) as optional BIT STRING fields between
    // the six required TBSCertificate fields and the [3] extensions. Real
    // CA certificates essentially never populate them (deprecated by
    // RFC 5280), so no fixture in `test/resources` carries them. Reuse the
    // six required fields from a real certificate and append hand-built
    // context-tagged elements to exercise the two parsing branches.
    late List<ASN1Object> requiredFields;

    setUpAll(() {
      final bytes = File('test/resources/rfc5280_cert1.cer').readAsBytesSync();
      final certSeq = ASN1Parser(bytes).nextObject() as ASN1Sequence;
      final tbsSeq = certSeq.elements[0] as ASN1Sequence;
      var elements = tbsSeq.elements;
      if (elements.first.tag == 0xa0) {
        // Drop the explicit version tag; the six required fields follow it.
        elements = elements.skip(1).toList();
      }
      requiredFields = elements.take(6).toList();
    });

    test('parses issuerUniqueID ([1]) and subjectUniqueID ([2])', () {
      final seq = ASN1Sequence();
      for (final e in requiredFields) {
        seq.add(e);
      }
      final issuerUid = ASN1Object.preEncoded(
          0x81, Uint8List.fromList([0x00, 0xff, 0x00, 0xff]));
      final subjectUid =
          ASN1Object.preEncoded(0x82, Uint8List.fromList([0x00, 0xaa, 0xbb]));
      seq.add(issuerUid);
      seq.add(subjectUid);

      final tbs = TbsCertificate.fromAsn1(seq);
      expect(tbs.issuerUniqueID, [0x00, 0xff, 0x00, 0xff]);
      expect(tbs.subjectUniqueID, [0x00, 0xaa, 0xbb]);
    });

    test('leaves both unique IDs null when absent', () {
      final seq = ASN1Sequence();
      for (final e in requiredFields) {
        seq.add(e);
      }
      final tbs = TbsCertificate.fromAsn1(seq);
      expect(tbs.issuerUniqueID, isNull);
      expect(tbs.subjectUniqueID, isNull);
    });

    test('parses only issuerUniqueID when subjectUniqueID is absent', () {
      final seq = ASN1Sequence();
      for (final e in requiredFields) {
        seq.add(e);
      }
      final issuerUid = ASN1Object.preEncoded(0x81, Uint8List.fromList([0x07]));
      seq.add(issuerUid);

      final tbs = TbsCertificate.fromAsn1(seq);
      expect(tbs.issuerUniqueID, [0x07]);
      expect(tbs.subjectUniqueID, isNull);
    });
  });
}
