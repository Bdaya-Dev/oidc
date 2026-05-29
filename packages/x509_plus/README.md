
[:heart: sponsor](https://github.com/sponsors/rbellens)

# x509

Dart library for parsing and working with X.509 certificates.


## Usage

A simple usage example:

```dart
import 'package:x509_plus/x509.dart';
import 'dart:io';

void main() {
  var cert = parsePem(new File('cert.pem').readAsStringSync());

  print(cert);
}
```

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/appsup-dart/x509/issues



## Sponsor

Creating and maintaining this package takes a lot of time. If you like the result, please consider to [:heart: sponsor](https://github.com/sponsors/rbellens). 
With your support, I will be able to further improve and support this project.
Also, check out my other dart packages at [pub.dev](https://pub.dev/packages?q=publisher%3Aappsup.be).


