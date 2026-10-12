import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/app_controller.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

class UsersPage extends StatelessWidget {
  const UsersPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Get.find<AppController>();
    const modules = [
      'Customers',
      'Quotes',
      'Jobs',
      'Scheduling',
      'Invoices',
      'Payments',
      'Reports',
      'Settings',
    ];
    const matrix = {
      'Owner': [1, 1, 1, 1, 1, 1, 1, 1],
      'Manager': [1, 1, 1, 1, 0, 0, 0, 0],
      'Crew': [0, 0, 1, 1, 0, 0, 0, 0],
    };
    return PageScaffold(
      title: 'Users & Permissions',
      subtitle: 'Role-based access control',
      actions: [
        ElevatedButton.icon(
          onPressed: () => inviteDialog(context),
          icon: const Icon(Icons.person_add),
          label: const Text('INVITE USER'),
        ),
      ],
      children: [
        Obx(
          () => ResponsiveTable(
            headers: const ['User', 'Role', 'Status', 'Active'],
            rows: [
              for (final u in c.staff)
                [
                  sub(u.name, u.email),
                  DropdownButton<String>(
                    value: u.role,
                    underline: const SizedBox(),
                    items: [
                      for (final r in ['Owner', 'Manager', 'Crew'])
                        DropdownMenuItem(value: r, child: Text(r)),
                    ],
                    onChanged: (v) => c.changeRole(u, v!),
                  ),
                  Chip2(u.active ? 'Active' : 'Inactive'),
                  Switch(
                    value: u.active,
                    activeColor: C.navy,
                    onChanged: (v) => c.toggleUser(u, v),
                  ),
                ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Panel(
          title: 'Permission Matrix',
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingTextStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                color: C.navy,
              ),
              columns: [
                const DataColumn(label: Text('ROLE')),
                for (final m in modules)
                  DataColumn(
                    label: Text(
                      m.toUpperCase(),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
              ],
              rows: [
                for (final e in matrix.entries)
                  DataRow(
                    cells: [
                      DataCell(
                        Text(
                          e.key,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      for (final v in e.value)
                        DataCell(
                          Icon(
                            v == 1
                                ? Icons.check_circle
                                : Icons.remove_circle_outline,
                            color: v == 1 ? C.green : C.line,
                            size: 20,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Crew members only see assigned jobs. No role except Owner can access payment or banking settings.',
          style: TextStyle(color: C.muted, fontSize: 12),
        ),
      ],
    );
  }
}

void inviteDialog(BuildContext context) {
  final c = Get.find<AppController>();
  final n = TextEditingController(), e = TextEditingController();
  String role = 'Crew';
  showDialog(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (ctx, setS) {
        return AlertDialog(
          title: const Text('Invite User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: n,
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: e,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: [
                  for (final r in ['Manager', 'Crew'])
                    DropdownMenuItem(value: r, child: Text(r)),
                ],
                onChanged: (v) => setS(() => role = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (n.text.isEmpty) return;
                c.addStaff(StaffUser(n.text, e.text, role, true));
                Navigator.pop(ctx);
              },
              child: const Text('SEND INVITE'),
            ),
          ],
        );
      },
    ),
  );
}
