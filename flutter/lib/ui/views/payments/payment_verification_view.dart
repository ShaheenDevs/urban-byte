import 'package:flutter/material.dart';
import '../../../services/payment_service.dart';

class PaymentVerificationView extends StatefulWidget {
  const PaymentVerificationView({super.key});
  @override
  State<PaymentVerificationView> createState() =>
      _PaymentVerificationViewState();
}

class _PaymentVerificationViewState extends State<PaymentVerificationView> {
  final _service = PaymentService();
  late Future<List<Map<String, dynamic>>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = _service.list(status: 'pending');
  }

  Future<void> _verify(String id) async {
    setState(() => _busy = true);
    try {
      await _service.verify(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Payment verified.')));
      setState(_reload);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Payment Verification'), actions: [
          IconButton(
              onPressed: () => setState(_reload),
              icon: const Icon(Icons.refresh))
        ]),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError)
              return Center(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(snapshot.error.toString(),
                          textAlign: TextAlign.center)));
            final payments = snapshot.data ?? [];
            if (payments.isEmpty)
              return const Center(child: Text('No pending payments.'));
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: payments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final p = payments[index];
                final id = p['id'].toString();
                return Card(
                    child: ListTile(
                  title: Text('PKR ${p['amount'] ?? '0.00'}'),
                  subtitle: Text(
                      'Order #${p['orderId']} · ${p['method']}\nReference: ${p['reference'] ?? '—'}'),
                  isThreeLine: true,
                  trailing: FilledButton(
                      onPressed: _busy ? null : () => _verify(id),
                      child: const Text('Verify')),
                ));
              },
            );
          },
        ),
      );
}
