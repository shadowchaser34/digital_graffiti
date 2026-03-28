/*import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/home_screen.dart';
import 'widgets/canvas_widget.dart';

/// Application entrypoint.
///
/// Initializes Firebase (required for auth and Firestore) and then starts
/// the app inside a `ProviderScope` so Riverpod providers are available.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase. Add platform config files before running (see README).
  await Firebase.initializeApp();
  runApp(const ProviderScope(child: MyApp()));
}
//testare rulaj proiect
home: const Scaffold(
  body: Center(
    child: Text(
      'TEST',
      style: TextStyle(fontSize: 40),
    ),
  ),
),

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digital Graffiti Wall',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: const Scaffold(
  body: CanvasWidget(),
),
    );
  }
}
*/
/*import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            'TEST',
            style: TextStyle(fontSize: 40),
          ),
        ),
      ),
    );
  }
}*/
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'widgets/canvas_widget.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: CanvasWidget(),
      ),
    );
  }
}