import 'package:oidc_core/oidc_core.dart';
import 'package:test/test.dart';

void main() {
  group('OidcStore state/stateResponse extensions', () {
    late OidcMemoryStore store;

    setUp(() async {
      store = OidcMemoryStore();
      await store.init();
    });

    test(
      'setStateData/setStateResponseData write to separate namespaces',
      () async {
        await store.setStateData(state: 's1', stateData: 'data1');
        await store.setStateResponseData(state: 's1', stateData: 'resp1');

        expect(await store.getStateData('s1'), 'data1');
        expect(await store.getStateResponseData('s1'), 'resp1');
      },
    );

    test(
      'removeStateResponseData clears ONLY the stateResponse namespace '
      '(regression: previously cleared the state namespace)',
      () async {
        await store.setStateData(state: 's1', stateData: 'data1');
        await store.setStateResponseData(state: 's1', stateData: 'resp1');

        await store.removeStateResponseData('s1');

        // The state-response must be gone...
        expect(await store.getStateResponseData('s1'), isNull);
        // ...but the state data must be untouched.
        expect(await store.getStateData('s1'), 'data1');
      },
    );
  });
}
