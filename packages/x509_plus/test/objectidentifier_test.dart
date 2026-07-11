import 'dart:io';

import 'package:asn1lib/asn1lib.dart';
import 'package:test/test.dart';
import 'package:x509_plus/x509.dart';

void main() {
  group('name', () {
    test('return correct name', () {
      var oid = ObjectIdentifier([2, 5, 4, 3]);
      expect(oid.name, 'commonName');
    });

    test('throw UnknownOIDNameError when unknown oid', () {
      var oid = ObjectIdentifier([1, 2, 3, 4, 5, 6]);
      expect(() => oid.name, throwsA(TypeMatcher<UnknownOIDNameError>()));
    });
  });

  group('toAsn1 / fromAsn1 round-trip', () {
    // Real-world OIDs, including ones with multi-byte (>= 128) arcs that
    // exercise the base-128 encoding path.
    final oids = <List<int>>[
      [2, 5, 4, 3], // commonName
      [1, 2, 840, 113549, 1, 1, 11], // sha256WithRSAEncryption
      [1, 3, 6, 1, 5, 5, 7, 3, 1], // serverAuth
      [1, 2, 840, 10045, 3, 1, 7], // prime256v1
      [2, 16, 840, 1, 113730, 1, 13], // netscape-comment
    ];

    for (final nodes in oids) {
      test('${nodes.join('.')} survives toAsn1 -> fromAsn1', () {
        final oid = ObjectIdentifier(nodes);
        final roundTripped = ObjectIdentifier.fromAsn1(oid.toAsn1());
        expect(roundTripped, equals(oid));
        expect(roundTripped.nodes, equals(nodes));
      });

      test('${nodes.join('.')} toAsn1 produces correct DER value bytes', () {
        // asn1lib decodes the DER value octets independently of x509_plus'
        // own decoder, so this cross-checks that toAsn1() emits valid DER
        // (not the previously doubly-encoded bytes).
        final der = ObjectIdentifier(nodes).toAsn1().encodedBytes;
        final decoded = ASN1Parser(der).nextObject() as ASN1ObjectIdentifier;
        expect(decoded.oi, equals(nodes));
      });
    }
  });

  group('certificate re-encode preserves subject/issuer OIDs', () {
    test('rfc5280 cert survives toPem -> parse round-trip', () {
      final bytes = File('test/resources/rfc5280_cert1.cer').readAsBytesSync();
      final cert = X509Certificate.fromAsn1(
          ASN1Parser(bytes).nextObject() as ASN1Sequence);

      List<ObjectIdentifier> oidsOf(Name name) => [
            for (final rdn in name.names)
              ...rdn.keys.whereType<ObjectIdentifier>()
          ];

      final subjectOids = oidsOf(cert.tbsCertificate.subject!);
      final issuerOids = oidsOf(cert.tbsCertificate.issuer!);
      expect(subjectOids, isNotEmpty);
      expect(issuerOids, isNotEmpty);

      // Re-encode the Name (drives ObjectIdentifier.toAsn1 via fromDart) and
      // parse it back. Before the fix the OIDs were doubly encoded and the
      // recovered arcs did not match the originals.
      final subjectReparsed =
          Name.fromAsn1(cert.tbsCertificate.subject!.toAsn1());
      final issuerReparsed =
          Name.fromAsn1(cert.tbsCertificate.issuer!.toAsn1());

      expect(oidsOf(subjectReparsed), equals(subjectOids));
      expect(oidsOf(issuerReparsed), equals(issuerOids));

      // The full PEM of the re-encoded subject must round-trip through a real
      // DER parser as well.
      final der = cert.tbsCertificate.subject!.toAsn1().encodedBytes;
      final subjectFromDer =
          Name.fromAsn1(ASN1Parser(der).nextObject() as ASN1Sequence);
      expect(oidsOf(subjectFromDer), equals(subjectOids));
    });
  }, testOn: 'vm');
}
