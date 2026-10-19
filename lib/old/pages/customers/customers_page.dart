// import 'package:admin_twinhandymans_llc/core/theme.dart';
// import 'package:admin_twinhandymans_llc/pages/login/login_page.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:intl/intl.dart';

// // =========================================================
// // CUSTOMER MODEL  (Firestore document: users/{uid}, role = customer)
// // =========================================================
// class CustomerModel {
//   final String uid;
//   final String name;
//   final String email;
//   final String phone;
//   final DateTime? createdAt;

//   const CustomerModel({
//     required this.uid,
//     required this.name,
//     required this.email,
//     required this.phone,
//     this.createdAt,
//   });

//   factory CustomerModel.fromMap(Map<String, dynamic> map) {
//     return CustomerModel(
//       uid: map['uid'] ?? '',
//       name: map['name'] ?? '',
//       email: map['email'] ?? '',
//       phone: map['phone'] ?? '',
//       createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
//     );
//   }
// }

// // =========================================================
// // CUSTOMERS CONTROLLER  (logic only)
// // =========================================================
// class CustomersController extends GetxController {
//   final _db = FirebaseFirestore.instance;

//   final customers = <CustomerModel>[].obs;
//   final search = ''.obs;
//   final isLoading = true.obs;
//   final error = RxnString();

//   /// Search result (name, phone, email)
//   List<CustomerModel> get filtered {
//     final q = search.value.trim().toLowerCase();
//     if (q.isEmpty) return customers;
//     return customers
//         .where(
//           (u) => '${u.name} ${u.phone} ${u.email}'.toLowerCase().contains(q),
//         )
//         .toList();
//   }

//   @override
//   void onInit() {
//     super.onInit();
//     // Live stream: new registrations appear automatically
//     customers.bindStream(
//       _db
//           .collection('users')
//           .where('role', isEqualTo: 'customer')
//           .snapshots()
//           .map((snap) {
//             isLoading.value = false;
//             error.value = null;
//             final list =
//                 snap.docs.map((d) => CustomerModel.fromMap(d.data())).toList()
//                   ..sort(
//                     (a, b) => (b.createdAt ?? DateTime(2000)).compareTo(
//                       a.createdAt ?? DateTime(2000),
//                     ),
//                   );
//             return list;
//           })
//           .handleError((e) {
//             isLoading.value = false;
//             error.value = e.toString();
//           }),
//     );
//   }

//   Future<void> logout() async {
//     await FirebaseAuth.instance.signOut();
//     Get.delete<CustomersController>();
//     Get.offAll(() => const LoginView());
//   }
// }

// // =========================================================
// // CUSTOMERS PAGE
// // =========================================================
// class CustomersView extends StatefulWidget {
//   const CustomersView({super.key});

//   @override
//   State<CustomersView> createState() => _CustomersViewState();
// }

// class _CustomersViewState extends State<CustomersView> {
//   final c = Get.put(CustomersController());
//   final _search = TextEditingController();

//   @override
//   void dispose() {
//     _search.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: C.bg,
//       appBar: AppBar(
//         backgroundColor: C.navy,
//         foregroundColor: Colors.white,
//         title: const Text(
//           'Customers',
//           style: TextStyle(fontWeight: FontWeight.w900),
//         ),
//         actions: [
//           TextButton.icon(
//             onPressed: c.logout,
//             icon: const Icon(Icons.logout, color: Colors.white70),
//             label: const Text(
//               'Sign out',
//               style: TextStyle(color: Colors.white70),
//             ),
//           ),
//           const SizedBox(width: 8),
//         ],
//       ),
//       body: Center(
//         child: ConstrainedBox(
//           constraints: const BoxConstraints(maxWidth: 1000),
//           child: Padding(
//             padding: const EdgeInsets.all(20),
//             child: Column(
//               children: [
//                 TextField(
//                   controller: _search,
//                   onChanged: (v) => c.search.value = v,
//                   decoration: const InputDecoration(
//                     hintText: 'Search by name, phone or email',
//                     prefixIcon: Icon(Icons.search),
//                   ),
//                 ),
//                 const SizedBox(height: 14),
//                 Expanded(
//                   child: Obx(() {
//                     if (c.error.value != null) {
//                       return _Message(
//                         icon: Icons.error_outline,
//                         text: 'Could not load customers.\n${c.error.value}',
//                       );
//                     }
//                     if (c.isLoading.value) {
//                       return const Center(child: CircularProgressIndicator());
//                     }
//                     final list = c.filtered;
//                     if (list.isEmpty) {
//                       return const _Message(
//                         icon: Icons.people_outline,
//                         text: 'No customers found',
//                       );
//                     }
//                     return Container(
//                       decoration: BoxDecoration(
//                         color: Colors.white,
//                         borderRadius: BorderRadius.circular(14),
//                         border: Border.all(color: C.line),
//                       ),
//                       child: Column(
//                         children: [
//                           Padding(
//                             padding: const EdgeInsets.all(14),
//                             child: Align(
//                               alignment: Alignment.centerLeft,
//                               child: Text(
//                                 '${list.length} customer${list.length == 1 ? '' : 's'}',
//                                 style: const TextStyle(
//                                   fontWeight: FontWeight.w800,
//                                   color: C.navy,
//                                 ),
//                               ),
//                             ),
//                           ),
//                           const Divider(height: 1),
//                           Expanded(
//                             child: ListView.separated(
//                               itemCount: list.length,
//                               separatorBuilder: (_, __) =>
//                                   const Divider(height: 1),
//                               itemBuilder: (_, i) => _CustomerTile(list[i]),
//                             ),
//                           ),
//                         ],
//                       ),
//                     );
//                   }),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _CustomerTile extends StatelessWidget {
//   final CustomerModel u;
//   const _CustomerTile(this.u);

//   @override
//   Widget build(BuildContext context) {
//     final initial = u.name.isNotEmpty ? u.name[0].toUpperCase() : '?';
//     return ListTile(
//       onTap: () => _showDetail(context, u),
//       leading: CircleAvatar(
//         backgroundColor: C.navy,
//         child: Text(initial, style: const TextStyle(color: Colors.white)),
//       ),
//       title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.w800)),
//       subtitle: Text('${u.email}\n${u.phone}'),
//       isThreeLine: true,
//       trailing: const Icon(Icons.chevron_right),
//     );
//   }
// }

// void _showDetail(BuildContext context, CustomerModel u) {
//   final joined = u.createdAt == null
//       ? '-'
//       : DateFormat('MMM d, y • h:mm a').format(u.createdAt!);

//   Widget row(String k, String v) => Padding(
//     padding: const EdgeInsets.symmetric(vertical: 4),
//     child: Row(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         SizedBox(
//           width: 80,
//           child: Text(k, style: const TextStyle(color: C.muted)),
//         ),
//         Flexible(
//           child: SelectableText(
//             v,
//             style: const TextStyle(fontWeight: FontWeight.w700),
//           ),
//         ),
//       ],
//     ),
//   );

//   showDialog(
//     context: context,
//     builder: (_) => AlertDialog(
//       title: Text(u.name),
//       content: Column(
//         mainAxisSize: MainAxisSize.min,
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           row('Email', u.email),
//           row('Phone', u.phone),
//           row('Joined', joined),
//           row('User ID', u.uid),
//         ],
//       ),
//       actions: [
//         TextButton(
//           onPressed: () => Navigator.pop(context),
//           child: const Text('Close'),
//         ),
//       ],
//     ),
//   );
// }

// class _Message extends StatelessWidget {
//   final IconData icon;
//   final String text;
//   const _Message({required this.icon, required this.text});

//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(icon, size: 40, color: C.muted),
//           const SizedBox(height: 10),
//           Text(
//             text,
//             textAlign: TextAlign.center,
//             style: const TextStyle(color: C.muted),
//           ),
//         ],
//       ),
//     );
//   }
// }

// import 'package:flutter/material.dart';
// import 'package:get/get.dart';

// import '../../controllers/app_controller.dart';
// import '../../core/core.dart';
// import '../../models/models.dart';
// import '../../widgets/widgets.dart';
// import '../quotes/quote_builder.dart';

// class CustomersPage extends StatelessWidget {
//   const CustomersPage({super.key});
//   @override
//   Widget build(BuildContext context) {
//     final c = Get.find<AppController>();
//     return PageScaffold(
//       title: 'Customers',
//       subtitle: 'Search, add and manage customer accounts',
//       actions: [
//         ElevatedButton.icon(
//           onPressed: () => addCustomerDialog(context),
//           icon: const Icon(Icons.person_add),
//           label: const Text('ADD CUSTOMER'),
//         ),
//       ],
//       children: [
//         TextField(
//           controller: TextEditingController(text: c.custSearch.value),
//           onChanged: (v) => c.custSearch.value = v,
//           decoration: const InputDecoration(
//             hintText: 'Search by name, phone, email or address',
//             prefixIcon: Icon(Icons.search),
//           ),
//         ),
//         const SizedBox(height: 14),
//         Obx(() {
//           final q = c.custSearch.value.toLowerCase();
//           final list = c.customers
//               .where(
//                 (e) => '${e.name} ${e.phone} ${e.email} ${e.address}'
//                     .toLowerCase()
//                     .contains(q),
//               )
//               .toList();
//           return ResponsiveTable(
//             headers: const [
//               'Customer',
//               'Phone',
//               'Email',
//               'Jobs',
//               'Total Spent',
//             ],
//             rows: [
//               for (final e in list)
//                 [
//                   sub(e.name, e.address),
//                   plain(e.phone),
//                   plain(e.email),
//                   plain('${e.jobs}'),
//                   bold(money(e.spent)),
//                 ],
//             ],
//             onTap: (i) => openCustomer(context, list[i]),
//           );
//         }),
//       ],
//     );
//   }
// }

// void openCustomer(BuildContext context, Customer cu) {
//   final c = Get.find<AppController>();
//   final cj = c.jobs.where((j) => j.customer == cu.name).toList();
//   final cq = c.quotes.where((q) => q.customer == cu.name).toList();
//   final ci = c.invoices.where((i) => i.customer == cu.name).toList();
//   showDetail(
//     context,
//     title: cu.name,
//     actions: [
//       OutlinedButton.icon(
//         onPressed: () {
//           Navigator.pop(context);
//           c.page.value = 8;
//         },
//         icon: const Icon(Icons.chat),
//         label: const Text('Message'),
//       ),
//       ElevatedButton.icon(
//         onPressed: () {
//           Navigator.pop(context);
//           openQuoteBuilder(context, customer: cu.name);
//         },
//         icon: const Icon(Icons.request_quote),
//         label: const Text('NEW QUOTE'),
//       ),
//     ],
//     body: Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         KV('Phone', cu.phone),
//         KV('Email', cu.email),
//         KV('Primary address', cu.address),
//         KV('Saved properties', cu.properties.join('\n')),
//         KV('Total spent', money(cu.spent), boldV: true),
//         const Divider(height: 28),
//         const Text('Notes', style: TextStyle(fontWeight: FontWeight.w900)),
//         const SizedBox(height: 6),
//         TextField(
//           controller: TextEditingController(text: cu.notes),
//           maxLines: 3,
//           decoration: const InputDecoration(hintText: 'Add internal notes...'),
//         ),
//         const Divider(height: 28),
//         Text(
//           'Jobs (${cj.length})',
//           style: const TextStyle(fontWeight: FontWeight.w900),
//         ),
//         for (final j in cj)
//           ListTile(
//             dense: true,
//             contentPadding: EdgeInsets.zero,
//             title: Text('${j.id} • ${j.service}'),
//             trailing: Chip2(jobStages[j.stage]),
//           ),
//         const SizedBox(height: 8),
//         Text(
//           'Quotes (${cq.length})',
//           style: const TextStyle(fontWeight: FontWeight.w900),
//         ),
//         for (final q in cq)
//           ListTile(
//             dense: true,
//             contentPadding: EdgeInsets.zero,
//             title: Text('${q.id} • ${q.service} • ${money(q.total)}'),
//             trailing: Chip2(q.status),
//           ),
//         const SizedBox(height: 8),
//         Text(
//           'Invoices (${ci.length})',
//           style: const TextStyle(fontWeight: FontWeight.w900),
//         ),
//         for (final i in ci)
//           ListTile(
//             dense: true,
//             contentPadding: EdgeInsets.zero,
//             title: Text('${i.id} • ${money(i.total)}'),
//             trailing: Chip2(i.status),
//           ),
//       ],
//     ),
//   );
// }

// void addCustomerDialog(BuildContext context) {
//   final c = Get.find<AppController>();
//   final n = TextEditingController(),
//       p = TextEditingController(),
//       e = TextEditingController(),
//       a = TextEditingController();
//   showDetail(
//     context,
//     title: 'Add Customer',
//     actions: [
//       OutlinedButton(
//         onPressed: () => Navigator.pop(context),
//         child: const Text('Cancel'),
//       ),
//       ElevatedButton(
//         onPressed: () {
//           if (n.text.trim().isEmpty) return;
//           c.addCustomer(
//             Customer(
//               n.text,
//               p.text,
//               e.text,
//               a.text,
//               0,
//               0,
//               properties: [a.text],
//             ),
//           );
//           Navigator.pop(context);
//         },
//         child: const Text('SAVE'),
//       ),
//     ],
//     body: Column(
//       children: [
//         TextField(
//           controller: n,
//           decoration: const InputDecoration(labelText: 'Full name / Company'),
//         ),
//         const SizedBox(height: 12),
//         TextField(
//           controller: p,
//           decoration: const InputDecoration(labelText: 'Phone'),
//         ),
//         const SizedBox(height: 12),
//         TextField(
//           controller: e,
//           decoration: const InputDecoration(labelText: 'Email'),
//         ),
//         const SizedBox(height: 12),
//         TextField(
//           controller: a,
//           decoration: const InputDecoration(labelText: 'Property address'),
//         ),
//       ],
//     ),
//   );
// }
