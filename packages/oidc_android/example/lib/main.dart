// ignore_for_file: always_use_package_imports

import 'package:bdaya_shared_value/bdaya_shared_value.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'app_state.dart' as app_state;

// you must run this app with --web-port 22433

void main() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  });

  runApp(
    SharedValue.wrapApp(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
        ),
        home: const Scaffold(
          body: Text('Ready!'),
        ),
        builder: (context, child) {
          /// A platform-agnostic way to initialize
          /// the app state before displaying the routes.
          return FutureBuilder(
            future: app_state.initApp(),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator.adaptive(),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(snapshot.error.toString()),
                );
              }
              return child!;
            },
          );
        },
      ),
    ),
  );
}
