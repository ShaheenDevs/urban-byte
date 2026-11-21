import 'package:flutter/material.dart';
import '../../../app/app.locator.dart';
import '../../../services/operations_service.dart';

class NotificationInboxSheet extends StatefulWidget {
  const NotificationInboxSheet({super.key});
  @override
  State<NotificationInboxSheet> createState() => _NotificationInboxSheetState();
}

class _NotificationInboxSheetState extends State<NotificationInboxSheet> {
  final api = locator<OperationsService>();
  late Future<List<Map<String, dynamic>>> pending;

  @override
  void initState() {
    super.initState();
    pending = api.notifications();
  }

  void reload() => setState(() => pending = api.notifications());

  Future<void> markRead(Map<String, dynamic> item) async {
    await api.markNotificationRead('${item['id']}');
    reload();
  }

  Future<void> markAll() async {
    await api.markAllNotificationsRead();
    reload();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: Column(
            children: [
              ListTile(
                title: Text('Notifications',
                    style: Theme.of(context).textTheme.titleLarge),
                trailing: TextButton(
                    onPressed: markAll, child: const Text('Mark all read')),
              ),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: pending,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text(snapshot.error.toString()));
                    }
                    final rows = snapshot.data ?? [];
                    if (rows.isEmpty) {
                      return const Center(child: Text('No notifications yet.'));
                    }
                    return RefreshIndicator(
                      onRefresh: () async => reload(),
                      child: ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = rows[index];
                          final isRead = item['readAt'] != null;
                          return ListTile(
                            leading: Icon(
                              isRead
                                  ? Icons.notifications_none
                                  : Icons.notifications_active,
                              color: isRead
                                  ? Theme.of(context).colorScheme.outline
                                  : Theme.of(context).colorScheme.primary,
                            ),
                            title: Text(item['title']?.toString() ?? 'Update'),
                            subtitle: Text(item['body']?.toString() ?? ''),
                            trailing: isRead
                                ? null
                                : IconButton(
                                    tooltip: 'Mark as read',
                                    icon: const Icon(Icons.done),
                                    onPressed: () => markRead(item),
                                  ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
}
