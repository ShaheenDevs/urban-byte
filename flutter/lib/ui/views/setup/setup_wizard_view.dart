import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:urban_byte/app/api_config.dart';

class SetupWizardView extends StatefulWidget {
  const SetupWizardView({super.key});
  @override
  State<SetupWizardView> createState() => _SetupWizardViewState();
}

class _SetupWizardViewState extends State<SetupWizardView> {
  bool loading = true;
  String? error;
  Map<String, dynamic>? result;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await http
          .get(Uri.parse('$apiBaseUrl/health/setup'))
          .timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body);
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          decoded is! Map ||
          decoded['success'] != true ||
          decoded['data'] is! Map) {
        throw Exception(decoded is Map
            ? (decoded['message'] ?? 'Setup status request failed.').toString()
            : 'Invalid API response.');
      }
      if (!mounted) return;
      setState(() => result = Map<String, dynamic>.from(decoded['data']));
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  static const labels = <String, String>{
    'restaurant': 'Restaurant profile',
    'branch': 'Main branch',
    'ownerAccount': 'Owner account',
    'roles': 'Staff roles',
    'permissions': 'Permissions',
    'menuCategories': 'Menu categories',
    'menuProducts': 'Menu products',
    'inventoryIngredients': 'Inventory ingredients',
    'suppliers': 'Suppliers',
  };

  @override
  Widget build(BuildContext context) {
    final checks = result?['checks'] is Map
        ? Map<String, dynamic>.from(result!['checks'])
        : <String, dynamic>{};
    final ready = result?['ready'] == true;
    return Scaffold(
      appBar: AppBar(title: const Text('First-Time Setup'), actions: [
        IconButton(
            onPressed: loading ? null : refresh,
            tooltip: 'Refresh status',
            icon: const Icon(Icons.refresh))
      ]),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? _message(context, error!, true)
              : SingleChildScrollView(
                child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(children: [
                      Icon(
                          ready ? Icons.check_circle : Icons.settings_suggest,
                          size: 52,
                          color: ready
                              ? Colors.green
                              : Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 12),
                      Text(
                          ready
                              ? 'Initial setup records found'
                              : 'Setup is incomplete',
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Text(
                          ready
                              ? 'Core restaurant records are present. Review the remaining operational settings before going live.'
                              : 'Complete the missing items below. This screen checks database records; it does not create or change them.',
                          textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      ...labels.entries.map((entry) {
                        final done = checks[entry.key] == true;
                        return Card(
                            child: ListTile(
                          leading: Icon(
                              done
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: done
                                  ? Colors.green
                                  : Theme.of(context).colorScheme.error),
                          title: Text(entry.value),
                          trailing: Text(done ? 'Found' : 'Missing',
                              style: TextStyle(
                                  color: done
                                      ? Colors.green
                                      : Theme.of(context).colorScheme.error)),
                        ));
                      }),
                      const SizedBox(height: 12),
                      if (result?['counts'] is Map)
                        Text(
                            'Database counts: ${(result!['counts'] as Map).entries.map((e) => '${e.key}: ${e.value}').join('  •  ')}',
                            style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                          onPressed: refresh,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Check again')),
                    ]),
                  ),
              ),
    );
  }

  Widget _message(BuildContext context, String message, bool isError) => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isError ? Icons.cloud_off : Icons.info_outline, size: 48),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: refresh, child: const Text('Retry'))
            ],
          )));
}
