/// [JSON Web Key](https://tools.ietf.org/html/rfc7517)
library;

import 'package:clock/clock.dart';
import 'dart:async';
import 'dart:async' as async show runZoned;
import 'dart:convert';
import 'dart:convert' as convert;
import 'dart:typed_data';

import 'package:asn1lib/asn1lib.dart';
import 'package:crypto_keys_plus/crypto_keys.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'jwa.dart';
import 'package:meta/meta.dart';
import 'package:x509_plus/x509.dart' as x509;

import 'jose.dart';
import 'util.dart';

/// JSON Web Key (JWK) represents a cryptographic key
class JsonWebKey extends JsonObject {
  final KeyPair _keyPair;

  JsonWebKey.fromKeyPair({
    required KeyPair keyPair,
    required Map<String, dynamic> json,
  })  : _keyPair = keyPair,
        super.from(json) {
    if (json['kty'] == null) throw ArgumentError.notNull('keyType');
    if (x509CertificateChain != null && x509CertificateChain!.isNotEmpty) {
      var cert = x509CertificateChain!.first;

      if (_keyPair.publicKey != cert.publicKey) {
        throw ArgumentError("The public key in 'x5c' does not match this key.");
      }
    }
  }

  /// Constructs a [JsonWebKey] from its JSON representation
  static JsonWebKey? fromJson(Map<String, dynamic> json) {
    final kp = KeyPair.fromJwk(json);
    if (kp == null) {
      return null;
    }
    return JsonWebKey.fromKeyPair(keyPair: kp, json: json);
  }

  static String _bytesToBase64(List<int> bytes) {
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static String _intToBase64(BigInt v) {
    var s = v.toRadixString(16);
    if (s.length % 2 != 0) s = '0$s';

    return _bytesToBase64(s
        .replaceAllMapped(RegExp('[0-9a-f]{2}'), (m) => '${m.group(0)},')
        .split(',')
        .where((v) => v.isNotEmpty)
        .map((v) => int.parse(v, radix: 16))
        .toList());
  }

  /// Creates a JsonWebKey from a [PublicKey] and/or [PrivateKey]
  factory JsonWebKey.fromCryptoKeys({
    PublicKey? publicKey,
    PrivateKey? privateKey,
    String? keyId,
  }) {
    if (publicKey == null && privateKey == null) {
      throw ArgumentError('Either publicKey or privateKey should be non null');
    }

    if (privateKey is RsaPrivateKey) {
      if (publicKey != null && publicKey is! RsaPublicKey) {
        throw ArgumentError.value(
            publicKey, 'publicKey', 'should be an RsaPublicKey');
      }

      return JsonWebKey.rsa(
        modulus: privateKey.modulus,
        exponent: (publicKey as RsaPublicKey?)?.exponent,
        privateExponent: privateKey.privateExponent,
        firstPrimeFactor: privateKey.firstPrimeFactor,
        secondPrimeFactor: privateKey.secondPrimeFactor,
        keyId: keyId,
      );
    }

    String toCurveName(Identifier? curve) {
      return curvesByName.entries
          .firstWhere((element) => element.value == curve)
          .key;
    }

    if (privateKey is EcPrivateKey) {
      if (publicKey != null && publicKey is! EcPublicKey) {
        throw ArgumentError.value(
            publicKey, 'publicKey', 'should be an EcPublicKey');
      }

      return JsonWebKey.ec(
        curve: toCurveName(privateKey.curve),
        privateKey: privateKey.eccPrivateKey,
        xCoordinate: (publicKey as EcPublicKey?)?.xCoordinate,
        yCoordinate: publicKey?.yCoordinate,
        keyId: keyId,
      );
    }

    if (privateKey != null) {
      throw UnsupportedError(
          'Private key of type ${privateKey.runtimeType} not supported');
    }

    if (publicKey is RsaPublicKey) {
      return JsonWebKey.rsa(
        modulus: publicKey.modulus,
        exponent: publicKey.exponent,
        keyId: keyId,
      );
    }

    if (publicKey is EcPublicKey) {
      return JsonWebKey.ec(
          curve: toCurveName(publicKey.curve),
          xCoordinate: publicKey.xCoordinate,
          yCoordinate: publicKey.yCoordinate,
          keyId: keyId);
    }

    throw UnsupportedError(
        'Public key of type ${publicKey.runtimeType} not supported');
  }

  /// Creates a JsonWebKey of type RSA
  static JsonWebKey rsa({
    required BigInt modulus,
    BigInt? exponent,
    BigInt? privateExponent,
    BigInt? firstPrimeFactor,
    BigInt? secondPrimeFactor,
    String? keyId,
    String? algorithm,
  }) =>
      JsonWebKey.fromJson({
        'kty': 'RSA',
        'n': _intToBase64(modulus),
        if (exponent != null) 'e': _intToBase64(exponent),
        if (privateExponent != null) 'd': _intToBase64(privateExponent),
        if (firstPrimeFactor != null) 'p': _intToBase64(firstPrimeFactor),
        if (secondPrimeFactor != null) 'q': _intToBase64(secondPrimeFactor),
        if (keyId != null) 'kid': keyId,
        if (algorithm != null) 'alg': algorithm
      })!;

  /// Creates a JsonWebKey of type EC
  static JsonWebKey ec({
    required String curve,
    BigInt? xCoordinate,
    BigInt? yCoordinate,
    BigInt? privateKey,
    String? keyId,
    String? algorithm,
  }) =>
      JsonWebKey.fromJson({
        'kty': 'EC',
        'crv': curve,
        if (xCoordinate != null) 'x': _intToBase64(xCoordinate),
        if (yCoordinate != null) 'y': _intToBase64(yCoordinate),
        if (privateKey != null) 'd': _intToBase64(privateKey),
        if (keyId != null) 'kid': keyId,
        if (algorithm != null) 'alg': algorithm
      })!;

  /// Creates a JsonWebKey of type oct
  static JsonWebKey symmetric({required BigInt key, String? keyId}) =>
      JsonWebKey.fromJson({
        'kty': 'oct',
        'k': _intToBase64(key),
        if (keyId != null) 'kid': keyId,
      })!;

  /// Parses a PEM encoded public or private key
  factory JsonWebKey.fromPem(String pem, {String? keyId}) {
    var v = x509.parsePem(pem).first;

    if (v is x509.PrivateKeyInfo) {
      v = v.keyPair;
    }

    if (v is KeyPair) {
      return JsonWebKey.fromCryptoKeys(
          publicKey: v.publicKey, privateKey: v.privateKey, keyId: keyId);
    }
    if (v is x509.X509Certificate) {
      v = v.tbsCertificate.subjectPublicKeyInfo;
    }
    if (v is x509.SubjectPublicKeyInfo) {
      return JsonWebKey.fromCryptoKeys(
        publicKey: v.subjectPublicKey,
        keyId: keyId,
      );
    }
    throw UnsupportedError('Cannot create JWK from ${v.runtimeType}');
  }

  /// Generates a random key suitable for the specified [algorithm]
  factory JsonWebKey.generate(String? algorithm, {int? keyBitLength}) {
    var alg = JsonWebAlgorithm.getByName(algorithm);
    return alg.generateRandomKey(keyBitLength: keyBitLength);
  }

  KeyPair get cryptoKeyPair => _keyPair;

  /// The cryptographic algorithm family used with the key, such as `RSA` or
  /// `EC`.
  String get keyType => this['kty'];

  /// The intended use of the public key.
  ///
  /// Values defined by the specification are:
  ///
  /// * `sig` (signature)
  /// * `enc` (encryption)
  ///
  /// Other values MAY be used.
  ///
  String? get publicKeyUse => this['use'];

  /// The operation(s) that the key is intended to be used for.
  ///
  /// Values defined by the specification are:
  ///
  /// * `sign` (compute digital signature or MAC)
  /// * `verify` (verify digital signature or MAC)
  /// * `encrypt` (encrypt content)
  /// * `decrypt` (decrypt content and validate decryption, if applicable)
  /// * `wrapKey` (encrypt key)
  /// * `unwrapKey` (decrypt key and validate decryption, if applicable)
  /// * `deriveKey` (derive key)
  /// * `deriveBits` (derive bits not to be used as a key)
  ///
  /// Other values MAY be used.
  Set<String>? get keyOperations => getTypedList<String>('key_ops')?.toSet();

  /// The algorithm intended for use with the key.
  String? get algorithm => this['alg'];

  /// Key ID used to match a specific key.
  ///
  /// This is used, for instance, to choose among a set of keys within a JWK Set
  /// during key rollover.
  String? get keyId => this['kid'];

  /// A resource for an X.509 public key certificate or certificate chain.
  Uri? get x509Url => this['x5u'] == null ? null : Uri.parse(this['x5u']);

  /// A chain of one or more PKIX certificates.
  List<x509.X509Certificate>? get x509CertificateChain =>
      (this['x5c'] as List?)?.map((v) {
        var bytes = convert.base64.decode(v);
        var p = ASN1Parser(bytes);
        var o = p.nextObject();
        if (o is! ASN1Sequence) {
          throw FormatException('Expected SEQUENCE, got ${o.runtimeType}');
        }
        var s = o;
        return x509.X509Certificate.fromAsn1(s);
      }).toList();

  /// A base64url encoded SHA-1 thumbprint (a.k.a. digest) of the DER encoding
  /// of an X.509 certificate.
  String? get x509CertificateThumbprint => this['x5t'];

  /// A base64url encoded SHA-256 thumbprint (a.k.a. digest) of the DER encoding
  /// of an X.509 certificate.
  String? get x509CertificateSha256Thumbprint => this['x5t#S256'];

  /// Compute digital signature or MAC
  List<int> sign(List<int> data, {String? algorithm}) {
    _assertCanDo('sign');
    var signer = _keyPair.privateKey!.createSigner(_getAlgorithm(algorithm));
    var signature = signer.sign(data);
    return signature.data;
  }

  /// Verify digital signature or MAC
  bool verify(List<int> data, List<int> signature, {String? algorithm}) {
    _assertCanDo('verify');
    var verifier = _keyPair.publicKey!.createVerifier(_getAlgorithm(algorithm));
    return verifier.verify(
        Uint8List.fromList(data), Signature(Uint8List.fromList(signature)));
  }

  /// Encrypt content
  EncryptionResult encrypt(List<int> data,
      {List<int>? initializationVector,
      List<int>? additionalAuthenticatedData,
      String? algorithm}) {
    _assertCanDo('encrypt');
    algorithm ??= this.algorithm;
    var encrypter =
        _keyPair.publicKey!.createEncrypter(_getAlgorithm(algorithm));
    return encrypter.encrypt(Uint8List.fromList(data),
        initializationVector: initializationVector != null
            ? Uint8List.fromList(initializationVector)
            : null,
        additionalAuthenticatedData: additionalAuthenticatedData != null
            ? Uint8List.fromList(additionalAuthenticatedData)
            : null);
  }

  /// Decrypt content and validate decryption, if applicable
  List<int> decrypt(List<int> data,
      {List<int>? initializationVector,
      List<int>? authenticationTag,
      List<int>? additionalAuthenticatedData,
      String? algorithm}) {
    _assertCanDo('decrypt');
    algorithm ??= this.algorithm;
    var decrypter =
        _keyPair.privateKey!.createEncrypter(_getAlgorithm(algorithm));
    return decrypter.decrypt(EncryptionResult(Uint8List.fromList(data),
        initializationVector: initializationVector != null
            ? Uint8List.fromList(initializationVector)
            : null,
        authenticationTag: authenticationTag != null
            ? Uint8List.fromList(authenticationTag)
            : null,
        additionalAuthenticatedData: additionalAuthenticatedData != null
            ? Uint8List.fromList(additionalAuthenticatedData)
            : null));
  }

  /// Encrypt key
  List<int> wrapKey(JsonWebKey key, {String? algorithm}) {
    _assertCanDo('wrapKey');
    if (key.keyType != 'oct') {
      throw UnsupportedError('Can only wrap symmetric keys');
    }
    algorithm ??= this.algorithm;
    var encrypter =
        _keyPair.publicKey!.createEncrypter(_getAlgorithm(algorithm));
    var v = encrypter
        .encrypt(Uint8List.fromList(decodeBase64EncodedBytes(key['k'])));
    return v.data;
  }

  /// Decrypt key and validate decryption, if applicable
  JsonWebKey unwrapKey(List<int> data, {String? algorithm}) {
    _assertCanDo('unwrapKey');
    algorithm ??= this.algorithm;
    var decrypter =
        _keyPair.privateKey!.createEncrypter(_getAlgorithm(algorithm));
    var v = decrypter.decrypt(EncryptionResult(Uint8List.fromList(data)));
    return JsonWebKey.fromJson({
      'kty': 'oct',
      'k': encodeBase64EncodedBytes(v),
      'use': 'enc',
      'key_ops': ['encrypt', 'decrypt']
    })!;
  }

  /// Returns true if this key can be used with the JSON Web Algorithm
  /// identified by [algorithm]
  bool usableForAlgorithm(String algorithm) {
    if (this.algorithm != null && this.algorithm != algorithm) return false;
    var alg = JsonWebAlgorithm.getByName(algorithm);

    return alg.type == keyType;
  }

  /// Returns true if this key can be used for the [operation]
  ///
  /// The value of [operation] should be one of the possible values for
  /// [keyOperations].
  bool usableForOperation(String operation) {
    var ops = keyOperations;
    if (ops != null && !ops.contains(operation)) return false;
    var alg = algorithm == null ? null : JsonWebAlgorithm.getByName(algorithm);
    if (alg != null && publicKeyUse != null && alg.use != publicKeyUse) {
      return false;
    }

    switch (operation) {
      case 'sign':
      case 'unwrapKey':
      case 'decrypt':
        return _keyPair.privateKey != null;
      case 'verify':
      case 'wrapKey':
      case 'encrypt':
        return _keyPair.publicKey != null;
    }
    return false;
  }

  /// Returns a JSON Web Algorithm name that can be used with this key for
  /// [operation]
  String? algorithmForOperation(String operation) {
    if (!usableForOperation(operation)) return null;
    if (algorithm != null) return algorithm;

    return JsonWebAlgorithm.find(operation: operation, keyType: keyType)
        .firstOrNull
        ?.name;
  }

  AlgorithmIdentifier _getAlgorithm(String? algorithm) {
    algorithm ??= this['alg'];
    if (this['alg'] != null) {
      if (this['alg'] != algorithm) {
        throw ArgumentError.value(algorithm, 'algorithm',
            "Algorithm should match key algorithm '${this['alg']}'");
      }
    }
    if (algorithm == null) {
      throw ArgumentError('No algorithm specified');
    }
    var id = AlgorithmIdentifier.getByJwaName(algorithm);

    if (id == null) {
      throw UnsupportedError('Algorithm with name $algorithm not found');
    }
    return id;
  }

  void _assertCanDo(String op) {
    if (!usableForOperation(op)) {
      throw StateError("This JsonWebKey does not support the '$op' operation.");
    }
  }
}

/// Represents a set of [JsonWebKey]s
class JsonWebKeySet extends JsonObject {
  /// An array of JWK values
  List<JsonWebKey> get keys =>
      getTypedList<JsonWebKey?>('keys', factory: (v) => JsonWebKey.fromJson(v))
          ?.nonNulls
          .toList() ??
      const [];

  /// Constructs a [JsonWebKeySet] from the list of [keys]
  factory JsonWebKeySet.fromKeys(Iterable<JsonWebKey?> keys) =>
      JsonWebKeySet.fromJson({
        'keys': keys.map((v) => v?.toJson()).nonNulls.toList(),
      });

  /// Constructs a [JsonWebKeySet] from its JSON representation
  JsonWebKeySet.fromJson(Map<String, dynamic> super.json) : super.from();
}

/// A key store to lookup [JsonWebKey]s
class JsonWebKeyStore {
  final List<JsonWebKey> _keys = [];
  final List<JsonWebKeySet> _keySets = [];
  final List<Uri> _keySetUrls = [];

  /// Adds a key set to this tore
  void addKeySet(JsonWebKeySet keys) => _keySets.add(keys);

  /// Adds a key to this store
  void addKey(JsonWebKey? key) {
    if (key == null) {
      return;
    }
    _keys.add(key);
  }

  /// Adds a key set url to this store
  void addKeySetUrl(Uri url) => _keySetUrls.add(url);

  /// Find [JsonWebKey]s for a [JoseObject] with header [header].
  ///
  /// See also [https://tools.ietf.org/html/rfc7515#appendix-D]
  Stream<JsonWebKey?> findJsonWebKeys(JoseHeader header, String operation) {
    if (header.algorithm == 'none') return Stream.fromIterable([null]);
    return _allKeys(header).where(
      (key) => _isValidKeyFor(key, header, operation),
    );
  }

  Stream<JsonWebKey> _allKeys(JoseHeader header) async* {
    // The keys added with `addKey`
    yield* Stream.fromIterable(_keys);

    // The keys added with `addKeySet`
    for (var s in _keySets) {
      yield* Stream.fromIterable(s.keys);
    }

    // The keys added with `addKeySetUrl`
    for (var url in _keySetUrls) {
      yield* _keysFromSet(url).where((v) => v != null).cast();
    }
  }

  bool _isValidKeyFor(JsonWebKey? key, JoseHeader header, String operation) {
    if (key == null) {
      return false;
    }

    if ((header.keyId != null) && (header.keyId != key.keyId)) {
      return false;
    }

    return key.usableForAlgorithm(
            operation == 'encrypt' || operation == 'decrypt'
                ? header.encryptionAlgorithm!
                : header.algorithm!) &&
        key.usableForOperation(operation);
  }

  Stream<JsonWebKey?> _keysFromSet(Uri uri) async* {
    var set = await JsonWebKeySetLoader.current.read(uri);
    yield* Stream.fromIterable(set.keys);
  }
}

/// Used for loading JSON Web Key sets from an url
///
/// The default loader will handle urls with `data` and `http(s)` schemes. Http
/// requests will be cached.
///
/// The default behavior can be changed with [runZoned]. This can be useful for
/// testing purposes or changing the caching behavior.
///
/// Example:
///
///   JsonWebKeySetLoader.runZoned(() async {
///     var key = await set.findJsonWebKeys(header, operation).first;
///   }, loader: DefaultJsonWebKeySetLoader(httpClient: MockClient()));
///
abstract class JsonWebKeySetLoader {
  @visibleForOverriding
  Future<String> readAsString(Uri uri);

  Future<JsonWebKeySet> read(Uri uri) async {
    return JsonWebKeySet.fromJson(convert.json.decode(await readAsString(uri)));
  }

  static JsonWebKeySetLoader _global = DefaultJsonWebKeySetLoader();

  static JsonWebKeySetLoader get current {
    return Zone.current[_jsonWebKeySetLoaderToken] ?? _global;
  }

  static set global(JsonWebKeySetLoader value) {
    _global = value;
  }

  static final _jsonWebKeySetLoaderToken = Object();

  static T runZoned<T>(T Function() body, {JsonWebKeySetLoader? loader}) {
    return async
        .runZoned(body, zoneValues: {_jsonWebKeySetLoaderToken: loader});
  }
}

/// A [JsonWebKeySetLoader] that uses [http.Client] to make http requests.
class DefaultJsonWebKeySetLoader extends JsonWebKeySetLoader {
  final http.Client _httpClient;

  final Map<Uri, MapEntry<DateTime, String>> _cache = {};
  final Duration _cacheExpiry;

  /// Creates a [DefaultJsonWebKeySetLoader]
  ///
  /// A custom [httpClient] can be used for doing the http requests.
  ///
  /// If the response includes valid "date" and "expires" headers, those are
  /// used instead of [cacheExpiry].
  DefaultJsonWebKeySetLoader({
    http.Client? httpClient,
    Duration cacheExpiry = const Duration(minutes: 5),
  })  : _httpClient = httpClient ?? http.Client(),
        _cacheExpiry = cacheExpiry;

  @override
  Future<String> readAsString(Uri uri) async {
    switch (uri.scheme) {
      case 'data':
        return uri.data!.contentAsString();
      case 'https':
      case 'http':
        var v = _cache[uri];
        if (v != null && v.key.isAfter(clock.now())) {
          return v.value;
        }
        var r = await _httpClient.get(uri);
        _cache[uri] = MapEntry(_localExpire(r), r.body);
        return r.body;
      default:
        throw UnsupportedError(
          'Uri\'s with scheme ${uri.scheme} not supported',
        );
    }
  }

  DateTime _localExpire(http.Response response) {
    DateTime? fromHeader(String key) {
      final str = response.headers[key];
      if (str is String) {
        try {
          return parseHttpDate(str);
        } on FormatException {
          // noop!
        }
      }
      return null;
    }

    var delta = _cacheExpiry;

    final date = fromHeader('date');
    if (date != null) {
      final expires = fromHeader('expires');

      if (expires != null) {
        // Since the server time may not match the local time, calculate a delta
        final newDelta = expires.difference(date);
        if (!newDelta.isNegative) {
          delta = newDelta;
        }
      }
    }
    return clock.now().add(delta);
  }
}
