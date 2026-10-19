import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/app_controller.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';
import '../quotes/quote_builder.dart';

// ── Firestore: customers live in users/{uid} where role == 'customer' ───────
final _usersRef = FirebaseFirestore.instance.collection('users');

Stream<List<Customer>> customersStream() {
  return _usersRef.where('role', isEqualTo: 'customer').snapshots().map((snap) {
    final list = snap.docs.map((d) => customerFromMap(d.data())).toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  });
}

Customer customerFromMap(Map<String, dynamic> m) {
  final address = (m['address'] ?? '') as String;
  final props =
      (m['properties'] as List?)?.map((e) => '$e').toList() ??
      (address.isNotEmpty ? [address] : <String>[]);
  return Customer(
    (m['name'] ?? '') as String,
    (m['phone'] ?? '') as String,
    (m['email'] ?? '') as String,
    address,
    ((m['jobs'] ?? 0) as num).toInt(),
    ((m['spent'] ?? 0) as num).toDouble(),
    properties: props,
    notes: (m['notes'] ?? '') as String,
  );
}

class CustomersPage extends StatelessWidget {
  const CustomersPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Get.find<AppController>();
    return PageScaffold(
      title: 'Customers',
      subtitle: 'Search, and manage customer accounts',
      // actions: [
      //   ElevatedButton.icon(
      //     onPressed: () => addCustomerDialog(context),
      //     icon: const Icon(Icons.person_add),
      //     label: const Text('ADD CUSTOMER'),
      //   ),
      // ],
      children: [
        TextField(
          controller: TextEditingController(text: c.custSearch.value),
          onChanged: (v) => c.custSearch.value = v,
          decoration: const InputDecoration(
            hintText: 'Search by name, phone, email or address',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 14),
        StreamBuilder<List<Customer>>(
          stream: customersStream(),
          builder: (context, snap) {
            if (snap.hasError) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Could not load customers. Check your permissions.',
                ),
              );
            }
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final all = snap.data!;
            return Obx(() {
              final q = c.custSearch.value.toLowerCase();
              final list = all
                  .where(
                    (e) => '${e.name} ${e.phone} ${e.email} ${e.address}'
                        .toLowerCase()
                        .contains(q),
                  )
                  .toList();
              return ResponsiveTable(
                headers: const [
                  'Customer',
                  'Phone',
                  'Email',
                  'Jobs',
                  'Total Spent',
                ],
                rows: [
                  for (final e in list)
                    [
                      sub(e.name, e.address),
                      plain(e.phone),
                      plain(e.email),
                      plain('${e.jobs}'),
                      bold(money(e.spent)),
                    ],
                ],
                onTap: (i) => openCustomer(context, list[i]),
              );
            });
          },
        ),
      ],
    );
  }
}

void openCustomer(BuildContext context, Customer cu) {
  final c = Get.find<AppController>();
  final cj = c.jobs.where((j) => j.customer == cu.name).toList();
  final cq = c.quotes.where((q) => q.customer == cu.name).toList();
  final ci = c.invoices.where((i) => i.customer == cu.name).toList();
  showDetail(
    context,
    title: cu.name,
    actions: [
      OutlinedButton.icon(
        onPressed: () {
          Navigator.pop(context);
          c.page.value = 8;
        },
        icon: const Icon(Icons.chat),
        label: const Text('Message'),
      ),
      ElevatedButton.icon(
        onPressed: () {
          Navigator.pop(context);
          openQuoteBuilder(context, customer: cu.name);
        },
        icon: const Icon(Icons.request_quote),
        label: const Text('NEW QUOTE'),
      ),
    ],
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KV('Phone', cu.phone),
        KV('Email', cu.email),
        KV('Primary address', cu.address),
        KV('Saved properties', cu.properties.join('\n')),
        KV('Total spent', money(cu.spent), boldV: true),
        const Divider(height: 28),
        const Text('Notes', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        TextField(
          controller: TextEditingController(text: cu.notes),
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Add internal notes...'),
        ),
        const Divider(height: 28),
        Text(
          'Jobs (${cj.length})',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        for (final j in cj)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text('${j.id} • ${j.service}'),
            trailing: Chip2(jobStages[j.stage]),
          ),
        const SizedBox(height: 8),
        Text(
          'Quotes (${cq.length})',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        for (final q in cq)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text('${q.id} • ${q.service} • ${money(q.total)}'),
            trailing: Chip2(q.status),
          ),
        const SizedBox(height: 8),
        Text(
          'Invoices (${ci.length})',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        for (final i in ci)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text('${i.id} • ${money(i.total)}'),
            trailing: Chip2(i.status),
          ),
      ],
    ),
  );
}

void addCustomerDialog2(BuildContext context) {
  final n = TextEditingController(),
      p = TextEditingController(),
      e = TextEditingController(),
      a = TextEditingController();
  showDetail(
    context,
    title: 'Add Customer',
    actions: [
      OutlinedButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      ElevatedButton(
        onPressed: () async {
          if (n.text.trim().isEmpty) return;
          try {
            final doc = _usersRef.doc(); // auto id (no login account yet)
            await doc.set({
              'uid': doc.id,
              'name': n.text.trim(),
              'email': e.text.trim().toLowerCase(),
              'phone': p.text.trim(),
              'address': a.text.trim(),
              'properties': a.text.trim().isEmpty ? [] : [a.text.trim()],
              'role': 'customer',
              'jobs': 0,
              'spent': 0,
              'notes': '',
              'createdByAdmin': true,
              'createdAt': FieldValue.serverTimestamp(),
            });
            if (context.mounted) Navigator.pop(context);
          } catch (_) {
            Get.snackbar('Error', 'Could not save customer. Please try again.');
          }
        },
        child: const Text('SAVE'),
      ),
    ],
    body: Column(
      children: [
        TextField(
          controller: n,
          decoration: const InputDecoration(labelText: 'Full name / Company'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: p,
          decoration: const InputDecoration(labelText: 'Phone'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: e,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: a,
          decoration: const InputDecoration(labelText: 'Property address'),
        ),
      ],
    ),
  );
}
