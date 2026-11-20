import 'package:flutter/material.dart';
import '../ui/views/auth/login_view.dart';
class UrbanByteApp extends StatelessWidget {
  const UrbanByteApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Urban Byte', debugShowCheckedModeBanner: false,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE53935)), useMaterial3: true),
    home: const LoginView(),
  );
}
