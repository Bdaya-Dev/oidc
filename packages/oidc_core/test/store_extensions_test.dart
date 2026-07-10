import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

void main() {
  late OidcMemoryStore store;

  setUp(() async {
    store = OidcMemoryStore();
    await store.init();
  });

  group('nonce helpers (secureTokens namespace)', () {
    test('setCurrentNonce then getCurrentNonce round-trips', () async {
      await store.setCurrentNonce('the-nonce');
      expect(await store.getCurrentNonce(), 'the-nonce');
    });

    test('setCurrentNonce(null) removes the stored nonce', () async {
      await store.setCurrentNonce('the-nonce');
      await store.setCurrentNonce(null);
      expect(await store.getCurrentNonce(), isNull);
    });

    test('an absent nonce reads as null', () async {
      expect(await store.getCurrentNonce(), isNull);
    });
  });

  group('front-channel logout request helpers (request namespace)', () {
    test('set then get round-trips the request', () async {
      await store.setCurrentFrontChannelLogoutRequest('sid=abc');
      expect(
        await store.getCurrentFrontChannelLogoutRequest(),
        'sid=abc',
      );
    });

    test('setting null removes the request', () async {
      await store.setCurrentFrontChannelLogoutRequest('sid=abc');
      await store.setCurrentFrontChannelLogoutRequest(null);
      expect(await store.getCurrentFrontChannelLogoutRequest(), isNull);
    });
  });

  group('single-key set/get/remove extension helpers', () {
    test('set then get on a namespace', () async {
      await store.set(
        OidcStoreNamespace.discoveryDocument,
        key: 'k',
        value: 'v',
      );
      expect(
        await store.get(OidcStoreNamespace.discoveryDocument, key: 'k'),
        'v',
      );
    });

    test('remove deletes a single key', () async {
      await store.set(
        OidcStoreNamespace.discoveryDocument,
        key: 'k',
        value: 'v',
      );
      await store.remove(OidcStoreNamespace.discoveryDocument, key: 'k');
      expect(
        await store.get(OidcStoreNamespace.discoveryDocument, key: 'k'),
        isNull,
      );
    });
  });

  group('getStatesWithResponses', () {
    test('returns empty when no responses are stored', () async {
      expect(await store.getStatesWithResponses(), isEmpty);
    });

    test(
      'pairs each stored state with its response, dropping responses that '
      'have no matching state data',
      () async {
        // s1 has both state data + a response.
        await store.setStateData(state: 's1', stateData: 'data1');
        await store.setStateResponseData(state: 's1', stateData: 'resp1');
        // s2 has a response but NO state data → must be dropped.
        await store.setStateResponseData(state: 's2', stateData: 'resp2');

        final result = await store.getStatesWithResponses();
        expect(result.keys, ['s1']);
        expect(result['s1']!.stateData, 'data1');
        expect(result['s1']!.stateResponse, 'resp1');
      },
    );

    test('returns empty when only state data (no responses) exists', () async {
      await store.setStateData(state: 's1', stateData: 'data1');
      expect(await store.getStatesWithResponses(), isEmpty);
    });
  });

  group('OidcStoreNamespace values', () {
    test('each namespace carries its wire value', () {
      expect(OidcStoreNamespace.session.value, 'session');
      expect(OidcStoreNamespace.state.value, 'state');
      expect(OidcStoreNamespace.stateResponse.value, 'response.state');
      expect(OidcStoreNamespace.request.value, 'request');
      expect(OidcStoreNamespace.discoveryDocument.value, 'discoveryDocument');
      expect(OidcStoreNamespace.secureTokens.value, 'secureTokens');
    });
  });
}
