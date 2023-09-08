import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // String? _platformName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Oidc Example')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                GoRouter.of(context).go('/auth');
              },
              child: const Text('Go to Auth Page'),
            ),
            ElevatedButton(
              onPressed: () {
                GoRouter.of(context).go('/secret-route');
              },
              child: const Text('Go to Secret page'),
            ),
          ],
        ),
      ),
    );
  }
}
