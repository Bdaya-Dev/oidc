import 'dart:convert' as convert;

import 'package:crypto_keys_plus/crypto_keys.dart';

/// Holds an unmodifiable JSON object
///
/// This object implements the equality operator, base64 (de)serialization and
/// convenient methods to get typed properties.
class JsonObject {
  final Map<String, dynamic> _json;
  String? _encodedString;

  JsonObject._(this._json, [this._encodedString]);

  /// Constructs a [JsonObject] from a [json] map.
  ///
  /// The [json] map is deep cloned to an unmodifiable copy.
  JsonObject.from(Map<String, dynamic>? json) : this._(_clone(json));

  /// Constructs a [JsonObject] from a [bytes] representation of the json string
  JsonObject.fromBytes(List<int> bytes)
      : this._(_clone(convert.json.decode(convert.utf8.decode(bytes))),
            encodeBase64EncodedBytes(bytes));

  /// Constructs a [JsonObject] from a base64 [encodedString] representation of
  /// the json string
  JsonObject.decode(String encodedString)
      : this.fromBytes(decodeBase64EncodedBytes(encodedString));

  /// Returns a JSON representation
  Map<String, dynamic> toJson() => _json;

  @override
  int get hashCode => toBase64EncodedString().hashCode;

  @override
  bool operator ==(other) =>
      other is JsonObject &&
      toBase64EncodedString() == other.toBase64EncodedString();

  static dynamic _clone(dynamic v) {
    if (v is Map) {
      return Map<String, dynamic>.unmodifiable(
          Map<String, dynamic>.fromIterables(
              v.keys as Iterable<String>, v.values.map(_clone)));
    }
    if (v is List) return List.unmodifiable(v.map(_clone));
    if (v == null || v is num || v is bool || v is String) return v;
    throw ArgumentError.value(v, 'Not a json value');
  }

  /// Returns the bytes representing the encoded JSON
  List<int> toBytes() => decodeBase64EncodedBytes(toBase64EncodedString());

  /// Returns the base64 representation
  String toBase64EncodedString() => _encodedString ??=
      encodeBase64EncodedBytes(convert.utf8.encode(convert.json.encode(_json)));

  /// Returns the property [key] as a core dart value
  dynamic operator [](String key) => _json[key];

  /// Returns the property [key] as a typed object
  T? getTyped<T>(String key, {T Function(dynamic v)? factory}) {
    return _typedMap.putIfAbsent(
        key, () => _convert(this[key], factory: factory));
  }

  /// Returns the property [key] as a typed list
  List<T>? getTypedList<T>(String key, {T Function(dynamic v)? factory}) {
    return _typedMap.putIfAbsent(key, () {
      var v = this[key];
      if (v == null) return null;

      if (v is List) {
        return List<T>.unmodifiable(
            v.map((i) => _convert(i, factory: factory)));
      }

      return List<T>.unmodifiable([_convert(v, factory: factory)]);
    });
  }

  final Map<String, dynamic> _typedMap = {};

  T? _convert<T>(dynamic v, {T Function(dynamic v)? factory}) {
    if (v == null) return null;
    switch (T) {
      case == Uri:
        return Uri.parse(v) as T;
      case == DateTime:
        return DateTime.fromMillisecondsSinceEpoch(((v as num).round() * 1000))
            as T;
      case == Duration:
        return Duration(seconds: (v as num).round()) as T;
      case == String:
      case == num:
      case == bool:
        return v;
      default:
        return factory == null ? v : factory(v);
    }
  }

  @override
  String toString() => _json.toString();
}

List<int> decodeBase64EncodedBytes(String encodedString) =>
    convert.base64Url.decode(encodedString +
        List.filled((4 - encodedString.length % 4) % 4, '=').join());

String encodeBase64EncodedBytes(List<int> data) =>
    convert.base64Url.encode(data).replaceAll('=', '');

String encodeBigInt(BigInt? v) {
  final b256 = BigInt.from(256);
  var bytes = <int>[];
  while (v != BigInt.zero) {
    bytes.add((v! % b256).toInt());
    v = v ~/ b256;
  }
  return convert.base64Url.encode(bytes.reversed.toList());
}

Map<String, dynamic> safeUnion(Iterable<Map<String, dynamic>?> items) {
  var out = <String, dynamic>{};
  for (var i in items) {
    if (i == null) continue;
    for (var k in out.keys.toSet().intersection(i.keys.toSet())) {
      if (out[k] != i[k]) {
        throw ArgumentError('Dublicate key `$k`');
      }
    }
    out.addAll(i);
  }
  return out;
}

Map<String, dynamic> commonUnion(Iterable<Map<String, dynamic>> items) {
  if (items.isEmpty) return {};
  var out = <String, dynamic>{}..addAll(items.first);
  for (var i in items) {
    for (var k in out.keys.toList()) {
      if (out[k] != i[k]) {
        out.remove(k);
      }
    }
    if (out.isEmpty) return out;
  }
  return out;
}

final curvesByName = <String, Identifier>{
  'P-256': curves.p256,
  'P-256K': curves.p256k,
  'P-384': curves.p384,
  'P-521': curves.p521
};
