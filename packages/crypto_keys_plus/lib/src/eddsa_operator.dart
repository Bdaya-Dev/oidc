part of '../crypto_keys.dart';

void _assertEd25519(Identifier curve) {
  if (curve != curves.ed25519) {
    throw UnsupportedError(
        'Only the Ed25519 OKP curve is supported, got `${curve.name}`.');
  }
}

/// Signer for EdDSA (RFC 8037) using Ed25519.
///
/// pointycastle has no Ed25519 implementation, so this signer bypasses the
/// generic [_AsymmetricOperator] / pointycastle dispatch and uses
/// `package:ed25519_edwards` directly.
class _EddsaSigner extends Signer<PrivateKey> {
  _EddsaSigner(Identifier algorithm, PrivateKey key) : super._(algorithm, key);

  @override
  Signature sign(List<int> data) {
    final okp = key as OkpPrivateKey;
    _assertEd25519(okp.curve);
    // RFC 8037: `d` is the RFC 8032 seed; expand it to the full private key.
    final priv = ed.newKeyFromSeed(Uint8List.fromList(okp.rawBytes));
    final message = data is Uint8List ? data : Uint8List.fromList(data);
    // PureEdDSA over the full message; no pre-hashing (RFC 8032 hashes
    // internally).
    return Signature(ed.sign(priv, message));
  }
}

/// Verifier for EdDSA (RFC 8037) using Ed25519.
class _EddsaVerifier extends Verifier<PublicKey> {
  _EddsaVerifier(Identifier algorithm, PublicKey key) : super._(algorithm, key);

  @override
  bool verify(Uint8List data, Signature signature) {
    final okp = key as OkpPublicKey;
    _assertEd25519(okp.curve);
    try {
      return ed.verify(
        ed.PublicKey(okp.rawBytes),
        data,
        signature.data,
      );
    } catch (_) {
      // e.g. ArgumentError on bad key/signature length -> not valid.
      return false;
    }
  }
}
