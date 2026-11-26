import 'package:flutter/material.dart';
import 'package:testttt/feature/measure/screen/measurefinger.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 144, 124, 179)),
      ),
      home: Measurefinger(),
      debugShowCheckedModeBanner: false,
    );
  }
}


