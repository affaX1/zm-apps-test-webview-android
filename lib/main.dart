import 'package:flutter/material.dart';
import 'logic.dart';
import 'webview.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // runApp(
  //   MaterialApp(
  //     debugShowCheckedModeBanner: false,
  //     home: PortalViewerPage(feewPath: Uri.parse('https://apptest4.click/')),
  //   ),
  // );
  runApp(const ZmAppsWebviewApp());
}

class ZmAppsWebviewApp extends StatefulWidget {
  const ZmAppsWebviewApp({super.key});

  @override
  State<ZmAppsWebviewApp> createState() => _ZmAppsWebviewAppState();
}

class _ZmAppsWebviewAppState extends State<ZmAppsWebviewApp> {
  late Future<StartupResult> _startupFuture;

  @override
  void initState() {
    super.initState();
    _startupFuture = initializeApp();
  }

  void _retryInitialization() {
    setState(() {
      _startupFuture = initializeApp();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZM Apps Webview',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F62FE)),
      ),
      home: FutureBuilder<StartupResult>(
        future: _startupFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SplashScreen();
          }
          if (snapshot.hasError) {
            print('[App] Startup error: ${snapshot.error}');
            return StartupErrorScreen(
              error: snapshot.error,
              onRetry: _retryInitialization,
            );
          }
          final StartupResult? result = snapshot.data;
          print('[App] Startup result: $result');
          if (result != null && result.passed && result.link != null) {
            return PortalViewerPage(feewPath: result.link!);
          }
          return PlaceholderScreen(result: result);
        },
      ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading...'),
          ],
        ),
      ),
    );
  }
}

class StartupErrorScreen extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const StartupErrorScreen({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              const Text('Failed to start the app'),
              const SizedBox(height: 8),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  final StartupResult? result;

  const PlaceholderScreen({super.key, this.result});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Заглушка')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.hourglass_empty, size: 56),
              const SizedBox(height: 16),
              const Text(
                'Запрос к серверу не дал ссылку. Показываем заглушку.',
                textAlign: TextAlign.center,
              ),
              if (result != null) ...[
                const SizedBox(height: 12),
                Text(
                  'passed: ${result!.passed}, link: ${result!.link ?? '-'}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (result!.message.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      result!.message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                if (result!.fromCache)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Показано из кэша',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
