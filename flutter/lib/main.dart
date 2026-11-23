import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'app/app.locator.dart';
import './ui/views/setup/setup_wizard_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupLocator();
  runApp(const UrbanByteApp());
}

class UrbanByteApp extends StatelessWidget {
  const UrbanByteApp({super.key, this.setupClient});
  final http.Client? setupClient;
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Urban Byte',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFE53935),
          ),
          useMaterial3: true,
        ),
        home: SetupWizardView(client: setupClient),
      );
}
