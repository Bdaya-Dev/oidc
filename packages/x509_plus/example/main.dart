import 'dart:io';

import 'package:x509_plus/x509.dart';

void main() {
  var certRequest = parsePem(File('test/files/csr.pem').readAsStringSync())
      .first as CertificationRequest;

  print(certRequest.certificationRequestInfo.subject);
}
