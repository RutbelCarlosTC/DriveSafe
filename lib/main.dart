import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa Firebase según la plataforma
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyCD1gDXtZqElotB-Cjc7-rwgH5d9gsrkVo",
        authDomain: "drivesafe-848b2.firebaseapp.com",
        projectId: "drivesafe-848b2",
        storageBucket: "drivesafe-848b2.firebasestorage.app",
        messagingSenderId: "713205306159",
        appId: "1:713205306159:web:0101419ca26a715f36c7da",
        measurementId: "G-DC5GZYJWWF",
      ),
    );
  } else {
    await Firebase.initializeApp(); // Usa google-services.json en Android
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Driving Detection',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const LoginScreen(),
    );
  }
}
