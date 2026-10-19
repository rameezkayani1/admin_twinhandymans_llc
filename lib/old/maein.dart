// // Twins Handyman LLC - Admin Portal (UI only, demo data, GetX, single file)
// // pubspec.yaml -> dependencies: flutter, get: ^4.6.6
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';

// void main() {
//   WidgetsFlutterBinding.ensureInitialized();
//   Get.put(AppController(), permanent: true);
//   runApp(const TwinsAdminAdpp());
// }

// // ───────────────────────── THEME ─────────────────────────
// class C {
//   static const navy = Color(0xFF10233A);
//   static const navy2 = Color(0xFF1B3556);
//   static const yellow = Color(0xFFF5B800);
//   static const bg = Color(0xFFF3F5F8);
//   static const line = Color(0xFFE2E6EC);
//   static const text = Color(0xFF1B2433);
//   static const muted = Color(0xFF6B7686);
//   static const green = Color(0xFF1E9E5A);
//   static const red = Color(0xFFD64545);
//   static const blue = Color(0xFF2F6FDE);
//   static const orange = Color(0xFFE9812A);
// }

// const _months = [
//   'Jan',
//   'Feb',
//   'Mar',
//   'Apr',
//   'May',
//   'Jun',
//   'Jul',
//   'Aug',
//   'Sep',
//   'Oct',
//   'Nov',
//   'Dec',
// ];
// String fmtDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';
// String money(num v) {
//   final s = v.toStringAsFixed(2).split('.');
//   final w = s[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
//   return '\$$w.${s[1]}';
// }

// Color statusColor(String s) {
//   final t = s.toLowerCase();
//   if ([
//     'paid',
//     'completed',
//     'approved',
//     'active',
//     'closed',
//     'public',
//     'verified',
//     'job closed',
//     'final payment received',
//   ].contains(t))
//     return C.green;
//   if ([
//     'pending',
//     'new',
//     'unpaid',
//     'sent',
//     'quote sent',
//     'in review',
//     'awaiting zelle',
//     'scheduled',
//     'private',
//   ].contains(t))
//     return C.orange;
//   if ([
//     'declined',
//     'failed',
//     'overdue',
//     'refunded',
//     'inactive',
//     'changes requested',
//   ].contains(t))
//     return C.red;
//   return C.blue;
// }

// class TwinsAdminApp extends StatelessWidget {
//   const TwinsAdminApp({super.key});
//   @override
//   Widget build(BuildContext context) {
//     return GetMaterialApp(
//       debugShowCheckedModeBanner: false,
//       title: 'Twins Handyman Admin',
//       theme: ThemeData(
//         useMaterial3: true,
//         scaffoldBackgroundColor: C.bg,
//         colorScheme: ColorScheme.fromSeed(
//           seedColor: C.navy,
//           primary: C.navy,
//           secondary: C.yellow,
//         ),
//         fontFamily: 'Roboto',
//         dividerColor: C.line,
//         inputDecorationTheme: const InputDecorationTheme(
//           border: OutlineInputBorder(borderRadius: BorderRadius.zero),
//           enabledBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.zero,
//             borderSide: BorderSide(color: C.line),
//           ),
//           focusedBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.zero,
//             borderSide: BorderSide(color: C.navy, width: 1.6),
//           ),
//           isDense: true,
//           filled: true,
//           fillColor: Colors.white,
//         ),
//         elevatedButtonTheme: ElevatedButtonThemeData(
//           style: ElevatedButton.styleFrom(
//             backgroundColor: C.yellow,
//             foregroundColor: C.navy,
//             elevation: 0,
//             shape: const RoundedRectangleBorder(),
//             padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
//             textStyle: const TextStyle(fontWeight: FontWeight.w800),
//           ),
//         ),
//         outlinedButtonTheme: OutlinedButtonThemeData(
//           style: OutlinedButton.styleFrom(
//             foregroundColor: C.navy,
//             side: const BorderSide(color: C.navy),
//             shape: const RoundedRectangleBorder(),
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
//           ),
//         ),
//         dialogTheme: const DialogThemeData(
//           shape: RoundedRectangleBorder(),
//           backgroundColor: Colors.white,
//         ),
//       ),
//       home: const LoginPage(),
//     );
//   }
// }

// // ───────────────────────── MODELS ─────────────────────────
// class Customer {
//   String name, phone, email, address, notes;
//   int jobs;
//   double spent;
//   List<String> properties;
//   Customer(
//     this.name,
//     this.phone,
//     this.email,
//     this.address,
//     this.jobs,
//     this.spent, {
//     this.notes = '',
//     this.properties = const [],
//   });
// }

// class QuoteRequest {
//   String id,
//       customer,
//       phone,
//       email,
//       service,
//       description,
//       address,
//       time,
//       status;
//   DateTime date;
//   double budget;
//   int photos, videos;
//   QuoteRequest(
//     this.id,
//     this.customer,
//     this.phone,
//     this.email,
//     this.service,
//     this.description,
//     this.address,
//     this.date,
//     this.time,
//     this.budget,
//     this.photos,
//     this.videos,
//     this.status,
//   );
// }

// class Quote {
//   String id, customer, service, status;
//   double labor,
//       materials,
//       equipment,
//       disposal,
//       travel,
//       discount,
//       taxPct,
//       depositPct;
//   DateTime expires;
//   Quote(
//     this.id,
//     this.customer,
//     this.service,
//     this.status,
//     this.labor,
//     this.materials,
//     this.equipment,
//     this.disposal,
//     this.travel,
//     this.discount,
//     this.taxPct,
//     this.depositPct,
//     this.expires,
//   );
//   double get subtotal =>
//       labor + materials + equipment + disposal + travel - discount;
//   double get total => subtotal + subtotal * taxPct / 100;
//   double get deposit => total * depositPct / 100;
//   double get balance => total - deposit;
// }

// const jobStages = [
//   'Quote Submitted',
//   'Quote Sent',
//   'Quote Approved',
//   'Deposit Paid',
//   'Scheduled',
//   'Crew Assigned',
//   'Work Started',
//   'Work In Progress',
//   'Work Completed',
//   'Final Payment Due',
//   'Final Payment Received',
//   'Job Closed',
// ];

// class Job {
//   String id, customer, service, address, time, duration, crew;
//   DateTime date;
//   int stage;
//   double amount;
//   int before, after;
//   Job(
//     this.id,
//     this.customer,
//     this.service,
//     this.address,
//     this.date,
//     this.time,
//     this.duration,
//     this.crew,
//     this.stage,
//     this.amount, {
//     this.before = 0,
//     this.after = 0,
//   });
// }

// class Invoice {
//   String id, job, customer, status, method;
//   double total, paid;
//   DateTime due;
//   Invoice(
//     this.id,
//     this.job,
//     this.customer,
//     this.total,
//     this.paid,
//     this.due,
//     this.status,
//     this.method,
//   );
//   double get balance => total - paid;
// }

// class Payment {
//   String id, invoice, customer, method, status;
//   double amount, fee;
//   DateTime date;
//   Payment(
//     this.id,
//     this.invoice,
//     this.customer,
//     this.amount,
//     this.method,
//     this.date,
//     this.status,
//     this.fee,
//   );
// }

// class Msg {
//   String text;
//   bool mine;
//   String time;
//   Msg(this.text, this.mine, this.time);
// }

// class Thread {
//   String customer, job;
//   int unread;
//   List<Msg> msgs;
//   Thread(this.customer, this.job, this.unread, this.msgs);
// }

// class DocItem {
//   String name, type, visibility, updated;
//   DocItem(this.name, this.type, this.visibility, this.updated);
// }

// class Review {
//   String customer, service, text, date;
//   int stars;
//   bool replied;
//   Review(
//     this.customer,
//     this.service,
//     this.stars,
//     this.text,
//     this.date,
//     this.replied,
//   );
// }

// class StaffUser {
//   String name, email, role;
//   bool active;
//   StaffUser(this.name, this.email, this.role, this.active);
// }

// class AppNotif {
//   String title, body, time;
//   IconData icon;
//   bool unread;
//   AppNotif(this.title, this.body, this.time, this.icon, this.unread);
// }

// // ───────────────────────── CONTROLLER (demo data only) ─────────────────────────
// class AppController extends GetxController {
//   final page = 0.obs;
//   final custSearch = ''.obs;
//   final reqFilter = 'All'.obs;
//   final quoteFilter = 'All'.obs;
//   final jobFilter = 'All'.obs;
//   final invFilter = 'All'.obs;
//   final selectedThread = 0.obs;
//   final calMonth = DateTime(2026, 10, 1).obs;
//   final selectedDay = DateTime(2026, 10, 4).obs;

//   // settings
//   final defaultDeposit = 75.0.obs;
//   final defaultTax = 6.625.obs;
//   final pushNewRequest = true.obs;
//   final emailNewRequest = true.obs;
//   final pushPayments = true.obs;
//   final pushMessages = true.obs;
//   final zelleEnabled = true.obs;

//   static final _d = (int m, int d) => DateTime(2026, m, d);

//   final customers = <Customer>[
//     Customer(
//       'Sarah Johnson',
//       '(908) 555-0142',
//       'sarah.j@email.com',
//       '45 Maple Ave, Summit, NJ',
//       4,
//       3850,
//       notes: 'Prefers text messages. Gate code 4417.',
//       properties: ['45 Maple Ave, Summit, NJ', '12 Oak St, Summit, NJ'],
//     ),
//     Customer(
//       'Michael Brown',
//       '(973) 555-0198',
//       'm.brown@email.com',
//       '210 Broad St, Newark, NJ',
//       2,
//       1900,
//       properties: ['210 Broad St, Newark, NJ'],
//     ),
//     Customer(
//       'Elm Street Property Mgmt',
//       '(201) 555-0111',
//       'ops@elmstreetpm.com',
//       '88 Elm St, Jersey City, NJ',
//       9,
//       14250,
//       notes: 'Commercial property manager. Net-15 terms.',
//       properties: [
//         '88 Elm St, Jersey City, NJ',
//         '90 Elm St, Jersey City, NJ',
//         '14 River Rd, Hoboken, NJ',
//       ],
//     ),
//     Customer(
//       'Priya Patel',
//       '(718) 555-0170',
//       'priya.p@email.com',
//       '34 Victory Blvd, Staten Island, NY',
//       1,
//       400,
//       properties: ['34 Victory Blvd, Staten Island, NY'],
//     ),
//     Customer(
//       'David Okafor',
//       '(908) 555-0123',
//       'david.o@email.com',
//       '17 Chestnut Ave, Elizabeth, NJ',
//       3,
//       2100,
//       properties: ['17 Chestnut Ave, Elizabeth, NJ'],
//     ),
//     Customer(
//       'Linda Martinez',
//       '(862) 555-0160',
//       'linda.m@email.com',
//       '9 Hillside Dr, Union, NJ',
//       5,
//       4620,
//       properties: ['9 Hillside Dr, Union, NJ'],
//     ),
//     Customer(
//       'Hillside Township',
//       '(973) 555-0100',
//       'procurement@hillsidenj.gov',
//       '1409 Liberty Ave, Hillside, NJ',
//       2,
//       8900,
//       notes: 'Government account. PO required.',
//       properties: ['1409 Liberty Ave, Hillside, NJ'],
//     ),
//   ].obs;

//   final requests = <QuoteRequest>[
//     QuoteRequest(
//       'QR-1042',
//       'Sarah Johnson',
//       '(908) 555-0142',
//       'sarah.j@email.com',
//       'Painting',
//       'Repaint living room, hallway and two bedrooms. Walls have minor cracks.',
//       '45 Maple Ave, Summit, NJ',
//       _d(10, 12),
//       'Morning',
//       1800,
//       8,
//       1,
//       'New',
//     ),
//     QuoteRequest(
//       'QR-1041',
//       'Priya Patel',
//       '(718) 555-0170',
//       'priya.p@email.com',
//       'Pressure Washing',
//       'Driveway and back patio, approx 900 sq ft.',
//       '34 Victory Blvd, Staten Island, NY',
//       _d(10, 10),
//       'Afternoon',
//       450,
//       4,
//       0,
//       'New',
//     ),
//     QuoteRequest(
//       'QR-1040',
//       'David Okafor',
//       '(908) 555-0123',
//       'david.o@email.com',
//       'Assembly',
//       'Assemble 3 wardrobes and a bunk bed.',
//       '17 Chestnut Ave, Elizabeth, NJ',
//       _d(10, 9),
//       'Evening',
//       300,
//       6,
//       0,
//       'In Review',
//     ),
//     QuoteRequest(
//       'QR-1039',
//       'Elm Street Property Mgmt',
//       '(201) 555-0111',
//       'ops@elmstreetpm.com',
//       'Cleaning',
//       'Weekly commercial cleaning of 2 office floors.',
//       '88 Elm St, Jersey City, NJ',
//       _d(10, 8),
//       'Evening',
//       1200,
//       2,
//       0,
//       'In Review',
//     ),
//     QuoteRequest(
//       'QR-1038',
//       'Linda Martinez',
//       '(862) 555-0160',
//       'linda.m@email.com',
//       'Waste Disposal',
//       'Garage cleanout - old furniture and boxes.',
//       '9 Hillside Dr, Union, NJ',
//       _d(10, 6),
//       'Morning',
//       500,
//       5,
//       1,
//       'Quoted',
//     ),
//     QuoteRequest(
//       'QR-1037',
//       'Michael Brown',
//       '(973) 555-0198',
//       'm.brown@email.com',
//       'Moving',
//       '2-bedroom apartment move, 3rd floor, no elevator.',
//       '210 Broad St, Newark, NJ',
//       _d(10, 5),
//       'Morning',
//       950,
//       3,
//       0,
//       'Quoted',
//     ),
//   ].obs;

//   final quotes = <Quote>[
//     Quote(
//       'Q-2031',
//       'Linda Martinez',
//       'Waste Disposal',
//       'Sent',
//       280,
//       0,
//       40,
//       150,
//       30,
//       0,
//       6.625,
//       50,
//       _d(10, 20),
//     ),
//     Quote(
//       'Q-2030',
//       'Michael Brown',
//       'Moving',
//       'Sent',
//       800,
//       40,
//       0,
//       0,
//       60,
//       50,
//       6.625,
//       50,
//       _d(10, 18),
//     ),
//     Quote(
//       'Q-2029',
//       'Sarah Johnson',
//       'Painting',
//       'Approved',
//       900,
//       520,
//       80,
//       40,
//       110,
//       0,
//       0,
//       75,
//       _d(10, 15),
//     ),
//     Quote(
//       'Q-2028',
//       'Hillside Township',
//       'General Handyman',
//       'Approved',
//       2600,
//       900,
//       150,
//       0,
//       150,
//       0,
//       0,
//       50,
//       _d(10, 14),
//     ),
//     Quote(
//       'Q-2027',
//       'David Okafor',
//       'Assembly',
//       'Changes Requested',
//       260,
//       0,
//       0,
//       0,
//       40,
//       0,
//       6.625,
//       25,
//       _d(10, 12),
//     ),
//     Quote(
//       'Q-2026',
//       'Priya Patel',
//       'Pressure Washing',
//       'Declined',
//       350,
//       30,
//       60,
//       0,
//       40,
//       0,
//       6.625,
//       50,
//       _d(10, 3),
//     ),
//   ].obs;

//   final jobs = <Job>[
//     Job(
//       'J-3012',
//       'Sarah Johnson',
//       'Painting',
//       '45 Maple Ave, Summit, NJ',
//       _d(10, 4),
//       '9:00 AM',
//       '2 days',
//       'Crew A',
//       7,
//       1650,
//       before: 6,
//     ),
//     Job(
//       'J-3011',
//       'Hillside Township',
//       'General Handyman',
//       '1409 Liberty Ave, Hillside, NJ',
//       _d(10, 4),
//       '11:00 AM',
//       '1 day',
//       'Crew B',
//       6,
//       4800,
//     ),
//     Job(
//       'J-3010',
//       'Elm Street Property Mgmt',
//       'Cleaning',
//       '88 Elm St, Jersey City, NJ',
//       _d(10, 4),
//       '6:00 PM',
//       '4 hrs',
//       'Crew C',
//       5,
//       1200,
//     ),
//     Job(
//       'J-3009',
//       'Linda Martinez',
//       'Lawn Services',
//       '9 Hillside Dr, Union, NJ',
//       _d(10, 4),
//       '2:00 PM',
//       '3 hrs',
//       'Crew A',
//       8,
//       250,
//       before: 3,
//       after: 3,
//     ),
//     Job(
//       'J-3008',
//       'Michael Brown',
//       'Moving',
//       '210 Broad St, Newark, NJ',
//       _d(10, 7),
//       '8:00 AM',
//       '6 hrs',
//       'Crew B',
//       4,
//       950,
//     ),
//     Job(
//       'J-3007',
//       'David Okafor',
//       'Assembly',
//       '17 Chestnut Ave, Elizabeth, NJ',
//       _d(10, 9),
//       '5:00 PM',
//       '3 hrs',
//       'Unassigned',
//       3,
//       300,
//     ),
//     Job(
//       'J-3006',
//       'Priya Patel',
//       'Pressure Washing',
//       '34 Victory Blvd, Staten Island, NY',
//       _d(10, 14),
//       '10:00 AM',
//       '4 hrs',
//       'Crew C',
//       4,
//       400,
//     ),
//     Job(
//       'J-3005',
//       'Linda Martinez',
//       'Waste Disposal',
//       '9 Hillside Dr, Union, NJ',
//       _d(9, 28),
//       '9:00 AM',
//       '3 hrs',
//       'Crew A',
//       11,
//       620,
//       before: 4,
//       after: 4,
//     ),
//     Job(
//       'J-3004',
//       'Sarah Johnson',
//       'Cleaning',
//       '12 Oak St, Summit, NJ',
//       _d(10, 22),
//       '1:00 PM',
//       '5 hrs',
//       'Crew C',
//       2,
//       520,
//     ),
//   ].obs;

//   final invoices = <Invoice>[
//     Invoice(
//       'TH-2026-0052',
//       'J-3012',
//       'Sarah Johnson',
//       1650,
//       1237.50,
//       _d(10, 8),
//       'Partial',
//       'Apple Pay',
//     ),
//     Invoice(
//       'TH-2026-0051',
//       'J-3011',
//       'Hillside Township',
//       4800,
//       2400,
//       _d(10, 12),
//       'Partial',
//       'ACH',
//     ),
//     Invoice(
//       'TH-2026-0050',
//       'J-3010',
//       'Elm Street Property Mgmt',
//       1200,
//       0,
//       _d(10, 3),
//       'Overdue',
//       '-',
//     ),
//     Invoice(
//       'TH-2026-0049',
//       'J-3009',
//       'Linda Martinez',
//       250,
//       250,
//       _d(10, 4),
//       'Paid',
//       'Card',
//     ),
//     Invoice(
//       'TH-2026-0048',
//       'J-3005',
//       'Linda Martinez',
//       620,
//       620,
//       _d(9, 28),
//       'Paid',
//       'Zelle',
//     ),
//     Invoice(
//       'TH-2026-0047',
//       'J-3008',
//       'Michael Brown',
//       950,
//       0,
//       _d(10, 15),
//       'Unpaid',
//       '-',
//     ),
//     Invoice(
//       'TH-2026-0046',
//       'J-3006',
//       'Priya Patel',
//       400,
//       200,
//       _d(10, 14),
//       'Partial',
//       'Awaiting Zelle',
//     ),
//   ].obs;

//   final payments = <Payment>[
//     Payment(
//       'PAY-9021',
//       'TH-2026-0052',
//       'Sarah Johnson',
//       1237.50,
//       'Apple Pay',
//       _d(10, 2),
//       'Paid',
//       36.34,
//     ),
//     Payment(
//       'PAY-9020',
//       'TH-2026-0051',
//       'Hillside Township',
//       2400,
//       'ACH',
//       _d(10, 1),
//       'Paid',
//       5.00,
//     ),
//     Payment(
//       'PAY-9019',
//       'TH-2026-0049',
//       'Linda Martinez',
//       250,
//       'Card',
//       _d(10, 4),
//       'Paid',
//       7.55,
//     ),
//     Payment(
//       'PAY-9018',
//       'TH-2026-0046',
//       'Priya Patel',
//       200,
//       'Zelle',
//       _d(10, 3),
//       'Awaiting Zelle',
//       0,
//     ),
//     Payment(
//       'PAY-9017',
//       'TH-2026-0048',
//       'Linda Martinez',
//       620,
//       'Zelle',
//       _d(9, 28),
//       'Paid',
//       0,
//     ),
//     Payment(
//       'PAY-9016',
//       'TH-2026-0045',
//       'David Okafor',
//       150,
//       'Card',
//       _d(9, 26),
//       'Failed',
//       0,
//     ),
//     Payment(
//       'PAY-9015',
//       'TH-2026-0044',
//       'Michael Brown',
//       300,
//       'Card',
//       _d(9, 24),
//       'Refunded',
//       0,
//     ),
//   ].obs;

//   final threads = <Thread>[
//     Thread('Sarah Johnson', 'J-3012 Painting', 2, [
//       Msg('Hi! Will the crew be here at 9 tomorrow?', false, '9:02 AM'),
//       Msg('Yes, Crew A arrives at 9:00 AM sharp.', true, '9:10 AM'),
//       Msg(
//         'Great, could you also touch up the hallway ceiling?',
//         false,
//         '9:14 AM',
//       ),
//     ]),
//     Thread('Hillside Township', 'J-3011 Handyman', 0, [
//       Msg('PO number has been uploaded to the job.', false, 'Yesterday'),
//       Msg('Received, thank you. Work starts Oct 4.', true, 'Yesterday'),
//     ]),
//     Thread('Priya Patel', 'J-3006 Pressure Washing', 1, [
//       Msg(
//         'I sent the deposit via Zelle. Confirmation attached.',
//         false,
//         'Oct 3',
//       ),
//     ]),
//     Thread('Michael Brown', 'Q-2030 Moving', 0, [
//       Msg('Is the 50% deposit required before booking?', false, 'Oct 2'),
//       Msg(
//         'Yes, once you approve the quote you can pay the deposit in the app.',
//         true,
//         'Oct 2',
//       ),
//     ]),
//   ].obs;

//   final documents = <DocItem>[
//     DocItem('Capability Statement', 'PDF', 'Public', 'Sep 12, 2026'),
//     DocItem('Organizational Chart', 'PDF', 'Public', 'Aug 30, 2026'),
//     DocItem('Certificate of Insurance', 'PDF', 'Private', 'Sep 01, 2026'),
//     DocItem('MBE Certification', 'PDF', 'Public', 'Jul 18, 2026'),
//     DocItem('SBE Certification', 'PDF', 'Public', 'Jul 18, 2026'),
//     DocItem(
//       'Business Registration Certificate',
//       'PDF',
//       'Private',
//       'Jan 10, 2026',
//     ),
//     DocItem('Standard Terms & Conditions', 'PDF', 'Public', 'Jun 05, 2026'),
//   ].obs;

//   final reviews = <Review>[
//     Review(
//       'Linda Martinez',
//       'Waste Disposal',
//       5,
//       'Fast, professional and left everything spotless. Highly recommend!',
//       'Sep 29',
//       true,
//     ),
//     Review(
//       'Sarah Johnson',
//       'Cleaning',
//       5,
//       'Great communication and the before/after photos were a nice touch.',
//       'Sep 25',
//       false,
//     ),
//     Review(
//       'Michael Brown',
//       'Moving',
//       4,
//       'Crew was on time and careful. Slight delay on arrival.',
//       'Sep 20',
//       true,
//     ),
//     Review(
//       'David Okafor',
//       'Assembly',
//       5,
//       'Assembled everything quickly. Will book again.',
//       'Sep 15',
//       false,
//     ),
//     Review(
//       'Elm Street Property Mgmt',
//       'Cleaning',
//       4,
//       'Reliable weekly service for our offices.',
//       'Sep 10',
//       true,
//     ),
//   ].obs;

//   final staff = <StaffUser>[
//     StaffUser('Mathew Ihemesie', 'mathew@twinshandymanllc.com', 'Owner', true),
//     StaffUser('Deacon Obanor', 'deacon@twinshandymanllc.com', 'Owner', true),
//     StaffUser('Grace Williams', 'grace@twinshandymanllc.com', 'Manager', true),
//     StaffUser('Carlos Rivera', 'carlos@twinshandymanllc.com', 'Crew', true),
//     StaffUser('Tyrone Davis', 'tyrone@twinshandymanllc.com', 'Crew', true),
//     StaffUser('Ana Costa', 'ana@twinshandymanllc.com', 'Crew', false),
//   ].obs;

//   final notifications = <AppNotif>[
//     AppNotif(
//       'New quote request',
//       'Sarah Johnson requested a Painting quote',
//       '5 min ago',
//       Icons.request_quote,
//       true,
//     ),
//     AppNotif(
//       'Payment received',
//       'Linda Martinez paid \$250.00 (Card)',
//       '2 hrs ago',
//       Icons.payments,
//       true,
//     ),
//     AppNotif(
//       'New message',
//       'Priya Patel sent a message',
//       '3 hrs ago',
//       Icons.chat_bubble,
//       true,
//     ),
//     AppNotif(
//       'Quote approved',
//       'Hillside Township approved Q-2028',
//       'Yesterday',
//       Icons.check_circle,
//       false,
//     ),
//     AppNotif(
//       'Failed payment',
//       'David Okafor card payment failed',
//       'Sep 26',
//       Icons.error,
//       false,
//     ),
//   ].obs;

//   final monthlyRevenue = const {
//     'May': 8200.0,
//     'Jun': 9600.0,
//     'Jul': 10400.0,
//     'Aug': 11800.0,
//     'Sep': 13100.0,
//     'Oct': 12420.0,
//   };
//   final serviceRevenue = const {
//     'Painting': 14800.0,
//     'Handyman': 12400.0,
//     'Cleaning': 9600.0,
//     'Moving': 7300.0,
//     'Lawn': 4200.0,
//     'Pressure Wash': 3900.0,
//     'Waste': 3100.0,
//   };

//   // computed
//   double get outstanding => invoices.fold(0.0, (s, i) => s + i.balance);
//   double get collected => payments
//       .where((p) => p.status == 'Paid')
//       .fold(0.0, (s, p) => s + p.amount);
//   double get fees => payments.fold(0.0, (s, p) => s + p.fee);
//   int get unreadNotifs => notifications.where((n) => n.unread).length;
//   double get avgRating => reviews.isEmpty
//       ? 0
//       : reviews.fold(0, (s, r) => s + r.stars) / reviews.length;
//   List<Job> jobsOn(DateTime d) => jobs
//       .where(
//         (j) =>
//             j.date.year == d.year &&
//             j.date.month == d.month &&
//             j.date.day == d.day,
//       )
//       .toList();

//   void snack(String m) => Get.snackbar(
//     '',
//     m,
//     titleText: const SizedBox.shrink(),
//     margin: const EdgeInsets.all(16),
//     backgroundColor: C.navy,
//     colorText: Colors.white,
//     borderRadius: 0,
//     maxWidth: 420,
//     duration: const Duration(seconds: 2),
//     snackPosition: SnackPosition.BOTTOM,
//   );

//   void addQuote(Quote q, {String? requestId}) {
//     quotes.insert(0, q);
//     if (requestId != null) {
//       final r = requests.firstWhereOrNull((e) => e.id == requestId);
//       if (r != null) r.status = 'Quoted';
//       requests.refresh();
//     }
//     snack('Quote ${q.id} sent to ${q.customer}');
//   }

//   void setJobStage(Job j, int s) {
//     j.stage = s;
//     jobs.refresh();
//     snack('${j.id} updated to ${jobStages[s]}');
//   }

//   void markInvoicePaid(Invoice i, String method) {
//     payments.insert(
//       0,
//       Payment(
//         'PAY-${9022 + payments.length}',
//         i.id,
//         i.customer,
//         i.balance,
//         method,
//         DateTime(2026, 10, 4),
//         'Paid',
//         0,
//       ),
//     );
//     i.paid = i.total;
//     i.status = 'Paid';
//     i.method = method;
//     invoices.refresh();
//     snack('${i.id} marked as paid via $method');
//   }

//   void verifyZelle(Payment p) {
//     p.status = 'Paid';
//     payments.refresh();
//     snack('Zelle payment ${p.id} verified');
//   }

//   void refund(Payment p) {
//     p.status = 'Refunded';
//     payments.refresh();
//     snack('${money(p.amount)} refunded to ${p.customer}');
//   }

//   void sendMessage(int t, String text) {
//     if (text.trim().isEmpty) return;
//     threads[t].msgs.add(Msg(text.trim(), true, 'Now'));
//     threads[t].unread = 0;
//     threads.refresh();
//   }

//   void addCustomer(Customer c) {
//     customers.insert(0, c);
//     snack('Customer ${c.name} added');
//   }

//   void toggleUser(StaffUser u, bool v) {
//     u.active = v;
//     staff.refresh();
//   }

//   void changeRole(StaffUser u, String r) {
//     u.role = r;
//     staff.refresh();
//   }

//   void addStaff(StaffUser u) {
//     staff.add(u);
//     snack('Invitation sent to ${u.email}');
//   }

//   void markAllRead() {
//     for (final n in notifications) {
//       n.unread = false;
//     }
//     notifications.refresh();
//   }
// }

// // ───────────────────────── LOGIN ─────────────────────────
// class LoginPage extends StatelessWidget {
//   const LoginPage({super.key});
//   @override
//   Widget build(BuildContext context) {
//     final wide = MediaQuery.of(context).size.width >= 900;
//     final form = Center(
//       child: SingleChildScrollView(
//         padding: const EdgeInsets.all(28),
//         child: ConstrainedBox(
//           constraints: const BoxConstraints(maxWidth: 400),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               if (!wide) ...[const Logo(), const SizedBox(height: 28)],
//               const Text(
//                 'Admin Sign In',
//                 style: TextStyle(
//                   fontSize: 28,
//                   fontWeight: FontWeight.w900,
//                   color: C.navy,
//                 ),
//               ),
//               const SizedBox(height: 6),
//               const Text(
//                 'Manage quotes, jobs, payments and customers.',
//                 style: TextStyle(color: C.muted),
//               ),
//               const SizedBox(height: 28),
//               const TextField(
//                 decoration: InputDecoration(
//                   labelText: 'Email',
//                   prefixIcon: Icon(Icons.mail_outline),
//                 ),
//               ),
//               const SizedBox(height: 14),
//               const TextField(
//                 obscureText: true,
//                 decoration: InputDecoration(
//                   labelText: 'Password',
//                   prefixIcon: Icon(Icons.lock_outline),
//                 ),
//               ),
//               const SizedBox(height: 8),
//               Align(
//                 alignment: Alignment.centerRight,
//                 child: TextButton(
//                   onPressed: () {},
//                   child: const Text('Forgot password?'),
//                 ),
//               ),
//               const SizedBox(height: 8),
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton(
//                   onPressed: () => Get.off(() => const Shell()),
//                   child: const Text('SIGN IN'),
//                 ),
//               ),
//               const SizedBox(height: 12),
//               const Text(
//                 'Demo mode: tap Sign In to continue. MFA is enabled for owner accounts.',
//                 style: TextStyle(color: C.muted, fontSize: 12),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: wide
//           ? Row(
//               children: [
//                 Expanded(
//                   child: Container(
//                     color: C.navy,
//                     padding: const EdgeInsets.all(56),
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: const [
//                         // Logo(light: true),
//                         SizedBox(height: 40),
//                         Text(
//                           'Run your contracting\nbusiness from one place.',
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontSize: 40,
//                             fontWeight: FontWeight.w900,
//                             height: 1.1,
//                           ),
//                         ),
//                         SizedBox(height: 18),
//                         Text(
//                           'Quotes • Jobs • Scheduling • Invoices • Payments • Reviews',
//                           style: TextStyle(
//                             color: Color(0xFFB8C4D6),
//                             fontSize: 16,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//                 Expanded(child: form),
//               ],
//             )
//           : form,
//     );
//   }
// }

// const String kLogoUrl =
//     'https://twinshandymanllc.com/wp-content/uploads/2026/09/WhatsApp-Image-2026-09-23-at-00.54.39.jpeg';

// class LogoMark extends StatelessWidget {
//   final double size;
//   const LogoMark({super.key, required this.size});
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: size,
//       height: size,
//       color: Colors.white,
//       child: Image.network(
//         kLogoUrl,
//         fit: BoxFit.contain,
//         loadingBuilder: (c, child, p) => p == null
//             ? child
//             : const Center(
//                 child: SizedBox(
//                   width: 16,
//                   height: 16,
//                   child: CircularProgressIndicator(
//                     strokeWidth: 2,
//                     color: C.navy,
//                   ),
//                 ),
//               ),
//         errorBuilder: (c, e, st) => Container(
//           alignment: Alignment.center,
//           color: C.yellow,
//           child: Text(
//             'TH',
//             style: TextStyle(
//               fontWeight: FontWeight.w900,
//               fontSize: size * .42,
//               color: C.navy,
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// class Logo extends StatelessWidget {
//   final bool light;
//   final bool small;
//   const Logo({super.key, this.light = false, this.small = false});
//   @override
//   Widget build(BuildContext context) {
//     final s = small ? 38.0 : 52.0;
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         // LogoMark(size: s),
//         const SizedBox(width: 12),
//         Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text(
//               'TWINS HANDYMAN',
//               style: TextStyle(
//                 fontWeight: FontWeight.w900,
//                 letterSpacing: 1,
//                 fontSize: small ? 13 : 16,
//                 color: light ? Colors.white : C.navy,
//               ),
//             ),
//             Text(
//               'ADMIN PORTAL',
//               style: TextStyle(
//                 fontSize: small ? 10 : 11,
//                 letterSpacing: 2,
//                 color: light ? C.yellow : C.muted,
//                 fontWeight: FontWeight.w700,
//               ),
//             ),
//           ],
//         ),
//       ],
//     );
//   }
// }

// // ───────────────────────── SHELL (responsive layout) ─────────────────────────
// class NavItem {
//   final String label;
//   final IconData icon;
//   const NavItem(this.label, this.icon);
// }

// const navItems = [
//   NavItem('Dashboard', Icons.dashboard_outlined),
//   NavItem('Customers', Icons.people_outline),
//   NavItem('Quote Requests', Icons.inbox_outlined),
//   NavItem('Quotes', Icons.request_quote_outlined),
//   NavItem('Jobs', Icons.construction_outlined),
//   NavItem('Calendar', Icons.calendar_month_outlined),
//   NavItem('Invoices', Icons.receipt_long_outlined),
//   NavItem('Payments', Icons.payments_outlined),
//   NavItem('Messages', Icons.chat_bubble_outline),
//   NavItem('Documents', Icons.folder_open_outlined),
//   NavItem('Reviews', Icons.star_outline),
//   NavItem('Reports', Icons.bar_chart_outlined),
//   NavItem('Users & Permissions', Icons.admin_panel_settings_outlined),
//   NavItem('Settings', Icons.settings_outlined),
// ];

// class Shell extends StatelessWidget {
//   const Shell({super.key});
//   Widget _page(int i) {
//     switch (i) {
//       case 0:
//         return const DashboardPage();
//       case 1:
//         return const CustomersPage();
//       case 2:
//         return const RequestsPage();
//       case 3:
//         return const QuotesPage();
//       case 4:
//         return const JobsPage();
//       case 5:
//         return const CalendarPage();
//       case 6:
//         return const InvoicesPage();
//       case 7:
//         return const PaymentsPage();
//       case 8:
//         return const MessagesPage();
//       case 9:
//         return const DocumentsPage();
//       case 10:
//         return const ReviewsPage();
//       case 11:
//         return const ReportsPage();
//       case 12:
//         return const UsersPage();
//       default:
//         return const SettingsPage();
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final c = Get.find<AppController>();
//     return LayoutBuilder(
//       builder: (context, box) {
//         final w = box.maxWidth;
//         final mobile = w < 760;
//         final extended = w >= 1150;
//         return Scaffold(
//           drawer: mobile
//               ? const Drawer(
//                   shape: RoundedRectangleBorder(),
//                   child: SideNav(extended: true, inDrawer: true),
//                 )
//               : null,
//           body: Row(
//             children: [
//               if (!mobile) SideNav(extended: extended),
//               Expanded(
//                 child: Column(
//                   children: [
//                     TopBar(mobile: mobile),
//                     Expanded(child: Obx(() => _page(c.page.value))),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }
// }

// class SideNav extends StatelessWidget {
//   final bool extended;
//   final bool inDrawer;
//   const SideNav({super.key, required this.extended, this.inDrawer = false});
//   @override
//   Widget build(BuildContext context) {
//     final c = Get.find<AppController>();
//     return Container(
//       width: extended ? 252 : 74,
//       color: C.navy,
//       child: SafeArea(
//         child: Column(
//           children: [
//             Container(
//               height: 72,
//               alignment: extended ? Alignment.centerLeft : Alignment.center,
//               padding: EdgeInsets.symmetric(horizontal: extended ? 18 : 0),
//               child: extended
//                   ? const Logo(light: true, small: true)
//                   : const LogoMark(size: 40),
//             ),
//             const Divider(height: 1, color: C.navy2),
//             Expanded(
//               child: ListView(
//                 padding: const EdgeInsets.symmetric(vertical: 8),
//                 children: [
//                   for (int i = 0; i < navItems.length; i++)
//                     Obx(() {
//                       final sel = c.page.value == i;
//                       final badge = i == 2
//                           ? c.requests.where((r) => r.status == 'New').length
//                           : (i == 8
//                                 ? c.threads.fold<int>(0, (s, t) => s + t.unread)
//                                 : 0);
//                       return Tooltip(
//                         message: extended ? '' : navItems[i].label,
//                         child: InkWell(
//                           onTap: () {
//                             c.page.value = i;
//                             if (inDrawer) Navigator.of(context).pop();
//                           },
//                           child: Container(
//                             height: 46,
//                             margin: const EdgeInsets.symmetric(
//                               horizontal: 10,
//                               vertical: 2,
//                             ),
//                             padding: EdgeInsets.symmetric(
//                               horizontal: extended ? 14 : 0,
//                             ),
//                             color: sel ? C.yellow : Colors.transparent,
//                             child: Row(
//                               mainAxisAlignment: extended
//                                   ? MainAxisAlignment.start
//                                   : MainAxisAlignment.center,
//                               children: [
//                                 Icon(
//                                   navItems[i].icon,
//                                   size: 21,
//                                   color: sel ? C.navy : const Color(0xFFB8C4D6),
//                                 ),
//                                 if (extended) ...[
//                                   const SizedBox(width: 14),
//                                   Expanded(
//                                     child: Text(
//                                       navItems[i].label,
//                                       style: TextStyle(
//                                         color: sel ? C.navy : Colors.white,
//                                         fontWeight: sel
//                                             ? FontWeight.w800
//                                             : FontWeight.w500,
//                                       ),
//                                     ),
//                                   ),
//                                   if (badge > 0)
//                                     Container(
//                                       padding: const EdgeInsets.symmetric(
//                                         horizontal: 7,
//                                         vertical: 2,
//                                       ),
//                                       color: sel ? C.navy : C.yellow,
//                                       child: Text(
//                                         '$badge',
//                                         style: TextStyle(
//                                           fontSize: 11,
//                                           fontWeight: FontWeight.w800,
//                                           color: sel ? C.yellow : C.navy,
//                                         ),
//                                       ),
//                                     ),
//                                 ],
//                               ],
//                             ),
//                           ),
//                         ),
//                       );
//                     }),
//                 ],
//               ),
//             ),
//             const Divider(height: 1, color: C.navy2),
//             InkWell(
//               onTap: () => Get.offAll(() => const LoginPage()),
//               child: Container(
//                 height: 56,
//                 padding: EdgeInsets.symmetric(horizontal: extended ? 22 : 0),
//                 alignment: extended ? Alignment.centerLeft : Alignment.center,
//                 child: Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     const Icon(
//                       Icons.logout,
//                       color: Color(0xFFB8C4D6),
//                       size: 20,
//                     ),
//                     if (extended) ...const [
//                       SizedBox(width: 14),
//                       Text('Sign out', style: TextStyle(color: Colors.white)),
//                     ],
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class TopBar extends StatelessWidget {
//   final bool mobile;
//   const TopBar({super.key, required this.mobile});
//   @override
//   Widget build(BuildContext context) {
//     final c = Get.find<AppController>();
//     return Container(
//       height: 64,
//       padding: const EdgeInsets.symmetric(horizontal: 16),
//       decoration: const BoxDecoration(
//         color: Colors.white,
//         border: Border(bottom: BorderSide(color: C.line)),
//       ),
//       child: Row(
//         children: [
//           if (mobile)
//             IconButton(
//               icon: const Icon(Icons.menu),
//               onPressed: () => Scaffold.of(context).openDrawer(),
//             ),
//           Expanded(
//             child: Obx(
//               () => Text(
//                 navItems[c.page.value].label,
//                 overflow: TextOverflow.ellipsis,
//                 style: const TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.w900,
//                   color: C.navy,
//                 ),
//               ),
//             ),
//           ),
//           if (!mobile)
//             SizedBox(
//               width: 280,
//               child: TextField(
//                 decoration: const InputDecoration(
//                   hintText: 'Search customers, jobs, invoices...',
//                   prefixIcon: Icon(Icons.search, size: 20),
//                 ),
//                 onSubmitted: (v) {
//                   c.custSearch.value = v;
//                   c.page.value = 1;
//                 },
//               ),
//             ),
//           const SizedBox(width: 6),
//           Obx(
//             () => IconButton(
//               onPressed: () => showNotifications(context),
//               icon: Badge(
//                 isLabelVisible: c.unreadNotifs > 0,
//                 label: Text('${c.unreadNotifs}'),
//                 backgroundColor: C.red,
//                 child: const Icon(Icons.notifications_none),
//               ),
//             ),
//           ),
//           const SizedBox(width: 4),
//           const CircleAvatar(
//             radius: 17,
//             backgroundColor: C.navy,
//             child: Text(
//               'MI',
//               style: TextStyle(
//                 color: C.yellow,
//                 fontSize: 12,
//                 fontWeight: FontWeight.w800,
//               ),
//             ),
//           ),
//           if (!mobile) ...const [
//             SizedBox(width: 10),
//             Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   'Mathew Ihemesie',
//                   style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
//                 ),
//                 Text('Owner', style: TextStyle(color: C.muted, fontSize: 11)),
//               ],
//             ),
//           ],
//         ],
//       ),
//     );
//   }
// }

// void showNotifications(BuildContext context) {
//   final c = Get.find<AppController>();
//   showDialog(
//     context: context,
//     builder: (_) => Dialog(
//       alignment: Alignment.topRight,
//       insetPadding: const EdgeInsets.fromLTRB(16, 70, 16, 16),
//       child: ConstrainedBox(
//         constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Padding(
//               padding: const EdgeInsets.fromLTRB(18, 14, 8, 8),
//               child: Row(
//                 children: [
//                   const Expanded(
//                     child: Text(
//                       'Notifications',
//                       style: TextStyle(
//                         fontWeight: FontWeight.w900,
//                         fontSize: 16,
//                       ),
//                     ),
//                   ),
//                   TextButton(
//                     onPressed: c.markAllRead,
//                     child: const Text('Mark all read'),
//                   ),
//                 ],
//               ),
//             ),
//             const Divider(height: 1),
//             Flexible(
//               child: Obx(
//                 () => ListView(
//                   shrinkWrap: true,
//                   children: [
//                     for (final n in c.notifications)
//                       ListTile(
//                         leading: CircleAvatar(
//                           backgroundColor: C.navy,
//                           radius: 18,
//                           child: Icon(n.icon, color: C.yellow, size: 18),
//                         ),
//                         title: Text(
//                           n.title,
//                           style: TextStyle(
//                             fontWeight: n.unread
//                                 ? FontWeight.w800
//                                 : FontWeight.w500,
//                           ),
//                         ),
//                         subtitle: Text('${n.body}\n${n.time}'),
//                         isThreeLine: true,
//                         trailing: n.unread
//                             ? const Icon(Icons.circle, size: 9, color: C.yellow)
//                             : null,
//                       ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     ),
//   );
// }

// // ───────────────────────── SHARED WIDGETS ─────────────────────────
// class PageScaffold extends StatelessWidget {
//   final String title, subtitle;
//   final List<Widget> actions;
//   final List<Widget> children;
//   const PageScaffold({
//     super.key,
//     required this.title,
//     this.subtitle = '',
//     this.actions = const [],
//     required this.children,
//   });
//   @override
//   Widget build(BuildContext context) {
//     final w = MediaQuery.of(context).size.width;
//     final pad = w < 600 ? 14.0 : 24.0;
//     return SingleChildScrollView(
//       padding: EdgeInsets.all(pad),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Wrap(
//             spacing: 12,
//             runSpacing: 12,
//             crossAxisAlignment: WrapCrossAlignment.center,
//             alignment: WrapAlignment.spaceBetween,
//             children: [
//               Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Text(
//                     title,
//                     style: const TextStyle(
//                       fontSize: 26,
//                       fontWeight: FontWeight.w900,
//                       color: C.navy,
//                     ),
//                   ),
//                   if (subtitle.isNotEmpty)
//                     Text(subtitle, style: const TextStyle(color: C.muted)),
//                 ],
//               ),
//               if (actions.isNotEmpty)
//                 Wrap(spacing: 10, runSpacing: 10, children: actions),
//             ],
//           ),
//           const SizedBox(height: 18),
//           ...children,
//         ],
//       ),
//     );
//   }
// }

// class Panel extends StatelessWidget {
//   final String? title;
//   final Widget? trailing;
//   final Widget child;
//   final EdgeInsets padding;
//   const Panel({
//     super.key,
//     this.title,
//     this.trailing,
//     required this.child,
//     this.padding = const EdgeInsets.all(18),
//   });
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: double.infinity,
//       decoration: BoxDecoration(
//         color: Colors.white,
//         border: Border.all(color: C.line),
//       ),
//       padding: padding,
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           if (title != null) ...[
//             Row(
//               children: [
//                 Expanded(
//                   child: Text(
//                     title!,
//                     style: const TextStyle(
//                       fontWeight: FontWeight.w900,
//                       fontSize: 16,
//                       color: C.navy,
//                     ),
//                   ),
//                 ),
//                 if (trailing != null) trailing!,
//               ],
//             ),
//             const SizedBox(height: 14),
//           ],
//           child,
//         ],
//       ),
//     );
//   }
// }

// class Grid extends StatelessWidget {
//   final List<Widget> children;
//   final double minWidth;
//   final double gap;
//   const Grid({
//     super.key,
//     required this.children,
//     this.minWidth = 240,
//     this.gap = 14,
//   });
//   @override
//   Widget build(BuildContext context) {
//     return LayoutBuilder(
//       builder: (context, box) {
//         final cols = (box.maxWidth / minWidth).floor().clamp(
//           1,
//           children.length == 0 ? 1 : children.length,
//         );
//         final w = (box.maxWidth - gap * (cols - 1)) / cols;
//         return Wrap(
//           spacing: gap,
//           runSpacing: gap,
//           children: [for (final ch in children) SizedBox(width: w, child: ch)],
//         );
//       },
//     );
//   }
// }

// class Stat extends StatelessWidget {
//   final String label, value;
//   final IconData icon;
//   final String? hint;
//   final Color color;
//   final VoidCallback? onTap;
//   const Stat(
//     this.label,
//     this.value,
//     this.icon, {
//     super.key,
//     this.hint,
//     this.color = C.navy,
//     this.onTap,
//   });
//   @override
//   Widget build(BuildContext context) {
//     return InkWell(
//       onTap: onTap,
//       child: Container(
//         padding: const EdgeInsets.all(18),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           border: Border.all(color: C.line),
//           boxShadow: const [],
//         ),
//         child: Row(
//           children: [
//             Container(
//               width: 46,
//               height: 46,
//               color: color.withAlpha(25),
//               child: Icon(icon, color: color),
//             ),
//             const SizedBox(width: 14),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     label,
//                     style: const TextStyle(
//                       color: C.muted,
//                       fontSize: 12,
//                       fontWeight: FontWeight.w600,
//                     ),
//                   ),
//                   const SizedBox(height: 2),
//                   FittedBox(
//                     fit: BoxFit.scaleDown,
//                     child: Text(
//                       value,
//                       style: const TextStyle(
//                         fontSize: 24,
//                         fontWeight: FontWeight.w900,
//                         color: C.text,
//                       ),
//                     ),
//                   ),
//                   if (hint != null)
//                     Text(
//                       hint!,
//                       style: const TextStyle(fontSize: 11, color: C.muted),
//                     ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class Chip2 extends StatelessWidget {
//   final String text;
//   final Color? color;
//   const Chip2(this.text, {super.key, this.color});
//   @override
//   Widget build(BuildContext context) {
//     final col = color ?? statusColor(text);
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
//       color: col.withAlpha(30),
//       child: Text(
//         text,
//         style: TextStyle(
//           color: col,
//           fontWeight: FontWeight.w800,
//           fontSize: 11.5,
//         ),
//       ),
//     );
//   }
// }

// class FilterBar extends StatelessWidget {
//   final List<String> options;
//   final RxString value;
//   const FilterBar(this.options, this.value, {super.key});
//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       height: 40,
//       child: ListView(
//         scrollDirection: Axis.horizontal,
//         children: [
//           for (final o in options)
//             Obx(
//               () => Padding(
//                 padding: const EdgeInsets.only(right: 8),
//                 child: InkWell(
//                   onTap: () => value.value = o,
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(horizontal: 16),
//                     alignment: Alignment.center,
//                     decoration: BoxDecoration(
//                       color: value.value == o ? C.navy : Colors.white,
//                       border: Border.all(
//                         color: value.value == o ? C.navy : C.line,
//                       ),
//                     ),
//                     child: Text(
//                       o,
//                       style: TextStyle(
//                         fontWeight: FontWeight.w700,
//                         color: value.value == o ? Colors.white : C.text,
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }

// /// Table on wide screens, stacked cards on phones.
// class ResponsiveTable extends StatelessWidget {
//   final List<String> headers;
//   final List<List<Widget>> rows;
//   final void Function(int)? onTap;
//   const ResponsiveTable({
//     super.key,
//     required this.headers,
//     required this.rows,
//     this.onTap,
//   });
//   @override
//   Widget build(BuildContext context) {
//     if (rows.isEmpty) {
//       return const Panel(
//         child: Center(
//           child: Padding(
//             padding: EdgeInsets.all(30),
//             child: Text('No records found', style: TextStyle(color: C.muted)),
//           ),
//         ),
//       );
//     }
//     return LayoutBuilder(
//       builder: (context, box) {
//         if (box.maxWidth < 720) {
//           return Column(
//             children: [
//               for (int r = 0; r < rows.length; r++)
//                 Container(
//                   margin: const EdgeInsets.only(bottom: 10),
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     border: Border.all(color: C.line),
//                   ),
//                   child: InkWell(
//                     onTap: onTap == null ? null : () => onTap!(r),
//                     child: Padding(
//                       padding: const EdgeInsets.all(14),
//                       child: Column(
//                         children: [
//                           Row(
//                             children: [
//                               Expanded(
//                                 child: DefaultTextStyle.merge(
//                                   style: const TextStyle(
//                                     fontWeight: FontWeight.w800,
//                                     fontSize: 15,
//                                   ),
//                                   child: rows[r][0],
//                                 ),
//                               ),
//                               const Icon(Icons.chevron_right, color: C.muted),
//                             ],
//                           ),
//                           const SizedBox(height: 8),
//                           for (int i = 1; i < rows[r].length; i++)
//                             Padding(
//                               padding: const EdgeInsets.symmetric(vertical: 3),
//                               child: Row(
//                                 children: [
//                                   SizedBox(
//                                     width: 110,
//                                     child: Text(
//                                       headers[i],
//                                       style: const TextStyle(
//                                         color: C.muted,
//                                         fontSize: 12,
//                                       ),
//                                     ),
//                                   ),
//                                   Expanded(
//                                     child: Align(
//                                       alignment: Alignment.centerLeft,
//                                       child: rows[r][i],
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//             ],
//           );
//         }
//         return Container(
//           width: double.infinity,
//           decoration: BoxDecoration(
//             color: Colors.white,
//             border: Border.all(color: C.line),
//           ),
//           child: SingleChildScrollView(
//             scrollDirection: Axis.horizontal,
//             child: ConstrainedBox(
//               constraints: BoxConstraints(minWidth: box.maxWidth - 2),
//               child: DataTable(
//                 showCheckboxColumn: false,
//                 headingRowColor: WidgetStateProperty.all(
//                   const Color(0xFFF7F8FA),
//                 ),
//                 headingTextStyle: const TextStyle(
//                   fontWeight: FontWeight.w800,
//                   color: C.navy,
//                   fontSize: 12.5,
//                 ),
//                 dataRowMinHeight: 54,
//                 dataRowMaxHeight: 64,
//                 columns: [
//                   for (final h in headers)
//                     DataColumn(label: Text(h.toUpperCase())),
//                 ],
//                 rows: [
//                   for (int r = 0; r < rows.length; r++)
//                     DataRow(
//                       onSelectChanged: onTap == null ? null : (_) => onTap!(r),
//                       cells: [for (final cell in rows[r]) DataCell(cell)],
//                     ),
//                 ],
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }
// }

// Widget bold(String t) =>
//     Text(t, style: const TextStyle(fontWeight: FontWeight.w700));
// Widget plain(String t) => Text(t);
// Widget sub(String a, String b) => Column(
//   crossAxisAlignment: CrossAxisAlignment.start,
//   mainAxisAlignment: MainAxisAlignment.center,
//   children: [
//     Text(a, style: const TextStyle(fontWeight: FontWeight.w800)),
//     Text(b, style: const TextStyle(color: C.muted, fontSize: 12)),
//   ],
// );

// class KV extends StatelessWidget {
//   final String k, v;
//   final bool boldV;
//   const KV(this.k, this.v, {super.key, this.boldV = false});
//   @override
//   Widget build(BuildContext context) => Padding(
//     padding: const EdgeInsets.symmetric(vertical: 5),
//     child: Row(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         SizedBox(
//           width: 130,
//           child: Text(k, style: const TextStyle(color: C.muted)),
//         ),
//         Expanded(
//           child: Text(
//             v,
//             style: TextStyle(
//               fontWeight: boldV ? FontWeight.w900 : FontWeight.w600,
//             ),
//           ),
//         ),
//       ],
//     ),
//   );
// }

// Future<void> showDetail(
//   BuildContext context, {
//   required String title,
//   required Widget body,
//   List<Widget> actions = const [],
// }) {
//   return showDialog(
//     context: context,
//     builder: (_) => Dialog(
//       insetPadding: const EdgeInsets.all(16),
//       child: ConstrainedBox(
//         constraints: const BoxConstraints(maxWidth: 640, maxHeight: 700),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Container(
//               color: C.navy,
//               padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
//               child: Row(
//                 children: [
//                   Expanded(
//                     child: Text(
//                       title,
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontWeight: FontWeight.w900,
//                         fontSize: 16,
//                       ),
//                     ),
//                   ),
//                   IconButton(
//                     onPressed: () => Navigator.of(context).pop(),
//                     icon: const Icon(Icons.close, color: Colors.white),
//                   ),
//                 ],
//               ),
//             ),
//             Flexible(
//               child: SingleChildScrollView(
//                 padding: const EdgeInsets.all(20),
//                 child: body,
//               ),
//             ),
//             if (actions.isNotEmpty)
//               Container(
//                 decoration: const BoxDecoration(
//                   border: Border(top: BorderSide(color: C.line)),
//                 ),
//                 padding: const EdgeInsets.all(14),
//                 child: Wrap(
//                   spacing: 10,
//                   runSpacing: 10,
//                   alignment: WrapAlignment.end,
//                   children: actions,
//                 ),
//               ),
//           ],
//         ),
//       ),
//     ),
//   );
// }

// // ───────────────────────── DASHBOARD ─────────────────────────
// class DashboardPage extends StatelessWidget {
//   const DashboardPage({super.key});
//   @override
//   Widget build(BuildContext context) {
//     final c = Get.find<AppController>();
//     return Obx(() {
//       final today = c.jobsOn(DateTime(2026, 10, 4));
//       final pending = c.quotes.where((q) => q.status == 'Sent').length;
//       final approved = c.quotes.where((q) => q.status == 'Approved').length;
//       final maxRev = c.monthlyRevenue.values.reduce((a, b) => a > b ? a : b);
//       return PageScaffold(
//         title: 'Business Overview',
//         subtitle: 'Sunday, Oct 4, 2026 • Welcome back, Mathew',
//         actions: [
//           OutlinedButton.icon(
//             onPressed: () => c.page.value = 2,
//             icon: const Icon(Icons.inbox),
//             label: const Text('Quote Requests'),
//           ),
//           ElevatedButton.icon(
//             onPressed: () => openQuoteBuilder(context),
//             icon: const Icon(Icons.add),
//             label: const Text('NEW QUOTE'),
//           ),
//         ],
//         children: [
//           Grid(
//             minWidth: 250,
//             children: [
//               Stat(
//                 "Today's Jobs",
//                 '${today.length}',
//                 Icons.construction,
//                 onTap: () => c.page.value = 4,
//               ),
//               Stat(
//                 'Pending Quotes',
//                 '$pending',
//                 Icons.hourglass_bottom,
//                 color: C.orange,
//                 onTap: () => c.page.value = 3,
//               ),
//               Stat(
//                 'Approved Quotes',
//                 '$approved',
//                 Icons.check_circle_outline,
//                 color: C.green,
//                 onTap: () => c.page.value = 3,
//               ),
//               Stat(
//                 'Outstanding Invoices',
//                 money(c.outstanding),
//                 Icons.receipt_long,
//                 color: C.red,
//                 onTap: () => c.page.value = 6,
//               ),
//               Stat(
//                 'Monthly Revenue',
//                 money(12420),
//                 Icons.trending_up,
//                 color: C.green,
//                 hint: '+8.4% vs last month',
//               ),
//               Stat(
//                 'Payments Received',
//                 money(c.collected),
//                 Icons.payments,
//                 color: C.blue,
//                 onTap: () => c.page.value = 7,
//               ),
//               Stat(
//                 'New Customers',
//                 '6',
//                 Icons.person_add_alt,
//                 hint: 'This month',
//               ),
//               Stat(
//                 'Reviews',
//                 '${c.avgRating.toStringAsFixed(1)} ★',
//                 Icons.star,
//                 color: C.yellow,
//                 hint: '${c.reviews.length} reviews',
//                 onTap: () => c.page.value = 10,
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//           LayoutBuilder(
//             builder: (context, box) {
//               final two = box.maxWidth >= 900;
//               final left = Column(
//                 children: [
//                   Panel(
//                     title: 'Revenue (last 6 months)',
//                     child: SizedBox(
//                       height: 220,
//                       child: Row(
//                         crossAxisAlignment: CrossAxisAlignment.end,
//                         children: [
//                           for (final e in c.monthlyRevenue.entries)
//                             Expanded(
//                               child: Padding(
//                                 padding: const EdgeInsets.symmetric(
//                                   horizontal: 6,
//                                 ),
//                                 child: Column(
//                                   mainAxisAlignment: MainAxisAlignment.end,
//                                   children: [
//                                     Text(
//                                       '\$${(e.value / 1000).toStringAsFixed(1)}k',
//                                       style: const TextStyle(
//                                         fontSize: 11,
//                                         fontWeight: FontWeight.w700,
//                                       ),
//                                     ),
//                                     const SizedBox(height: 4),
//                                     Container(
//                                       height: 150 * e.value / maxRev,
//                                       color: e.key == 'Oct' ? C.yellow : C.navy,
//                                     ),
//                                     const SizedBox(height: 6),
//                                     Text(
//                                       e.key,
//                                       style: const TextStyle(
//                                         color: C.muted,
//                                         fontSize: 12,
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             ),
//                         ],
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                   Panel(
//                     title: "Today's Jobs",
//                     trailing: TextButton(
//                       onPressed: () => c.page.value = 5,
//                       child: const Text('Open calendar'),
//                     ),
//                     child: Column(
//                       children: [
//                         for (final j in today)
//                           ListTile(
//                             contentPadding: EdgeInsets.zero,
//                             leading: Container(
//                               width: 64,
//                               padding: const EdgeInsets.symmetric(vertical: 8),
//                               color: C.navy,
//                               child: Text(
//                                 j.time,
//                                 textAlign: TextAlign.center,
//                                 style: const TextStyle(
//                                   color: C.yellow,
//                                   fontWeight: FontWeight.w800,
//                                   fontSize: 12,
//                                 ),
//                               ),
//                             ),
//                             title: Text(
//                               '${j.service} • ${j.customer}',
//                               style: const TextStyle(
//                                 fontWeight: FontWeight.w700,
//                               ),
//                             ),
//                             subtitle: Text('${j.address}\n${j.crew}'),
//                             isThreeLine: true,
//                             trailing: Chip2(jobStages[j.stage]),
//                             onTap: () => openJob(context, j),
//                           ),
//                       ],
//                     ),
//                   ),
//                 ],
//               );
//               final right = Column(
//                 children: [
//                   Panel(
//                     title: 'Job Pipeline',
//                     child: Column(
//                       children: [
//                         for (final g in [
//                           [
//                             'Quote Requests',
//                             c.requests
//                                 .where(
//                                   (r) =>
//                                       r.status == 'New' ||
//                                       r.status == 'In Review',
//                                 )
//                                 .length,
//                             C.orange,
//                           ],
//                           ['Quotes Sent', pending, C.blue],
//                           [
//                             'Awaiting Deposit',
//                             c.quotes
//                                 .where((q) => q.status == 'Approved')
//                                 .length,
//                             C.yellow,
//                           ],
//                           [
//                             'Scheduled',
//                             c.jobs
//                                 .where((j) => j.stage >= 4 && j.stage < 6)
//                                 .length,
//                             C.navy,
//                           ],
//                           [
//                             'In Progress',
//                             c.jobs
//                                 .where((j) => j.stage >= 6 && j.stage < 8)
//                                 .length,
//                             C.green,
//                           ],
//                           [
//                             'Final Payment Due',
//                             c.jobs
//                                 .where((j) => j.stage >= 8 && j.stage < 10)
//                                 .length,
//                             C.red,
//                           ],
//                         ])
//                           Padding(
//                             padding: const EdgeInsets.symmetric(vertical: 7),
//                             child: Row(
//                               children: [
//                                 Container(
//                                   width: 10,
//                                   height: 10,
//                                   color: g[2] as Color,
//                                 ),
//                                 const SizedBox(width: 10),
//                                 Expanded(child: Text(g[0] as String)),
//                                 Text(
//                                   '${g[1]}',
//                                   style: const TextStyle(
//                                     fontWeight: FontWeight.w900,
//                                     fontSize: 16,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                   Panel(
//                     title: 'New Quote Requests',
//                     trailing: TextButton(
//                       onPressed: () => c.page.value = 2,
//                       child: const Text('View all'),
//                     ),
//                     child: Column(
//                       children: [
//                         for (final r
//                             in c.requests
//                                 .where((r) => r.status == 'New')
//                                 .take(3))
//                           ListTile(
//                             contentPadding: EdgeInsets.zero,
//                             title: Text(
//                               '${r.service} • ${r.customer}',
//                               style: const TextStyle(
//                                 fontWeight: FontWeight.w700,
//                               ),
//                             ),
//                             subtitle: Text(
//                               'Budget ${money(r.budget)} • ${fmtDate(r.date)}',
//                             ),
//                             trailing: const Icon(Icons.chevron_right),
//                             onTap: () => openRequest(context, r),
//                           ),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                   Panel(
//                     title: 'Recent Payments',
//                     child: Column(
//                       children: [
//                         for (final p in c.payments.take(4))
//                           ListTile(
//                             contentPadding: EdgeInsets.zero,
//                             title: Text(
//                               p.customer,
//                               style: const TextStyle(
//                                 fontWeight: FontWeight.w700,
//                               ),
//                             ),
//                             subtitle: Text('${p.method} • ${fmtDate(p.date)}'),
//                             trailing: Column(
//                               mainAxisAlignment: MainAxisAlignment.center,
//                               crossAxisAlignment: CrossAxisAlignment.end,
//                               children: [
//                                 Text(
//                                   money(p.amount),
//                                   style: const TextStyle(
//                                     fontWeight: FontWeight.w900,
//                                   ),
//                                 ),
//                                 Chip2(p.status),
//                               ],
//                             ),
//                           ),
//                       ],
//                     ),
//                   ),
//                 ],
//               );
//               return two
//                   ? Row(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Expanded(flex: 3, child: left),
//                         const SizedBox(width: 16),
//                         Expanded(flex: 2, child: right),
//                       ],
//                     )
//                   : Column(children: [left, const SizedBox(height: 16), right]);
//             },
//           ),
//         ],
//       );
//     });
//   }
// }

// // ───────────────────────── CUSTOMERS ─────────────────────────
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

// // ───────────────────────── QUOTE REQUESTS ─────────────────────────
// class RequestsPage extends StatelessWidget {
//   const RequestsPage({super.key});
//   @override
//   Widget build(BuildContext context) {
//     final c = Get.find<AppController>();
//     return PageScaffold(
//       title: 'Quote Requests',
//       subtitle: 'Requests submitted from the mobile app and website',
//       children: [
//         FilterBar(const ['All', 'New', 'In Review', 'Quoted'], c.reqFilter),
//         const SizedBox(height: 14),
//         Obx(() {
//           final f = c.reqFilter.value;
//           final list = c.requests
//               .where((r) => f == 'All' || r.status == f)
//               .toList();
//           return ResponsiveTable(
//             headers: const [
//               'Request',
//               'Service',
//               'Preferred Date',
//               'Budget',
//               'Media',
//               'Status',
//             ],
//             rows: [
//               for (final r in list)
//                 [
//                   sub(r.customer, r.id),
//                   plain(r.service),
//                   plain('${fmtDate(r.date)} • ${r.time}'),
//                   bold(money(r.budget)),
//                   plain('${r.photos} photos, ${r.videos} video'),
//                   Chip2(r.status),
//                 ],
//             ],
//             onTap: (i) => openRequest(context, list[i]),
//           );
//         }),
//       ],
//     );
//   }
// }

// void openRequest(BuildContext context, QuoteRequest r) {
//   final c = Get.find<AppController>();
//   showDetail(
//     context,
//     title: '${r.id} • ${r.service}',
//     actions: [
//       OutlinedButton(
//         onPressed: () {
//           r.status = 'In Review';
//           c.requests.refresh();
//           Navigator.pop(context);
//         },
//         child: const Text('Mark In Review'),
//       ),
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
//           openQuoteBuilder(context, request: r);
//         },
//         icon: const Icon(Icons.request_quote),
//         label: const Text('CREATE QUOTE'),
//       ),
//     ],
//     body: Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             Chip2(r.status),
//             const Spacer(),
//             Text(
//               'Budget ${money(r.budget)}',
//               style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
//             ),
//           ],
//         ),
//         const SizedBox(height: 14),
//         KV('Customer', r.customer),
//         KV('Phone', r.phone),
//         KV('Email', r.email),
//         KV('Address', r.address),
//         KV('Preferred', '${fmtDate(r.date)} • ${r.time}'),
//         const Divider(height: 26),
//         const Text(
//           'Description of work',
//           style: TextStyle(fontWeight: FontWeight.w900),
//         ),
//         const SizedBox(height: 6),
//         Text(r.description),
//         const SizedBox(height: 18),
//         Text(
//           'Uploads (${r.photos} photos, ${r.videos} video)',
//           style: const TextStyle(fontWeight: FontWeight.w900),
//         ),
//         const SizedBox(height: 8),
//         Wrap(
//           spacing: 8,
//           runSpacing: 8,
//           children: [
//             for (int i = 0; i < r.photos; i++)
//               Container(
//                 width: 78,
//                 height: 78,
//                 color: C.line,
//                 child: const Icon(Icons.image, color: C.muted),
//               ),
//             for (int i = 0; i < r.videos; i++)
//               Container(
//                 width: 78,
//                 height: 78,
//                 color: C.navy,
//                 child: const Icon(Icons.play_circle, color: C.yellow),
//               ),
//           ],
//         ),
//       ],
//     ),
//   );
// }

// // ───────────────────────── QUOTES + BUILDER ─────────────────────────
// class QuotesPage extends StatelessWidget {
//   const QuotesPage({super.key});
//   @override
//   Widget build(BuildContext context) {
//     final c = Get.find<AppController>();
//     return PageScaffold(
//       title: 'Quotes',
//       subtitle: 'Create, send and track customer quotes',
//       actions: [
//         ElevatedButton.icon(
//           onPressed: () => openQuoteBuilder(context),
//           icon: const Icon(Icons.add),
//           label: const Text('NEW QUOTE'),
//         ),
//       ],
//       children: [
//         FilterBar(const [
//           'All',
//           'Sent',
//           'Approved',
//           'Changes Requested',
//           'Declined',
//         ], c.quoteFilter),
//         const SizedBox(height: 14),
//         Obx(() {
//           final f = c.quoteFilter.value;
//           final list = c.quotes
//               .where((q) => f == 'All' || q.status == f)
//               .toList();
//           return ResponsiveTable(
//             headers: const [
//               'Quote',
//               'Service',
//               'Total',
//               'Deposit',
//               'Balance',
//               'Expires',
//               'Status',
//             ],
//             rows: [
//               for (final q in list)
//                 [
//                   sub(q.customer, q.id),
//                   plain(q.service),
//                   bold(money(q.total)),
//                   plain(
//                     '${money(q.deposit)} (${q.depositPct.toStringAsFixed(0)}%)',
//                   ),
//                   plain(money(q.balance)),
//                   plain(fmtDate(q.expires)),
//                   Chip2(q.status),
//                 ],
//             ],
//             onTap: (i) => openQuote(context, list[i]),
//           );
//         }),
//       ],
//     );
//   }
// }

// void openQuote(BuildContext context, Quote q) {
//   showDetail(
//     context,
//     title: '${q.id} • ${q.service}',
//     actions: [
//       OutlinedButton.icon(
//         onPressed: () =>
//             Get.find<AppController>().snack('Quote PDF downloaded'),
//         icon: const Icon(Icons.download),
//         label: const Text('PDF'),
//       ),
//       if (q.status == 'Changes Requested' || q.status == 'Sent')
//         ElevatedButton(
//           onPressed: () {
//             Navigator.pop(context);
//             openQuoteBuilder(context, customer: q.customer);
//           },
//           child: const Text('REVISE QUOTE'),
//         ),
//     ],
//     body: Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             Chip2(q.status),
//             const Spacer(),
//             Text(
//               'Expires ${fmtDate(q.expires)}',
//               style: const TextStyle(color: C.muted),
//             ),
//           ],
//         ),
//         const SizedBox(height: 14),
//         KV('Customer', q.customer),
//         const Divider(height: 24),
//         totalsView(q),
//       ],
//     ),
//   );
// }

// Widget totalsView(Quote q) {
//   Widget row(String a, String b, {bool strong = false, Color? col}) => Padding(
//     padding: const EdgeInsets.symmetric(vertical: 4),
//     child: Row(
//       children: [
//         Expanded(
//           child: Text(
//             a,
//             style: TextStyle(
//               fontWeight: strong ? FontWeight.w900 : FontWeight.w500,
//             ),
//           ),
//         ),
//         Text(
//           b,
//           style: TextStyle(
//             fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
//             color: col,
//             fontSize: strong ? 16 : 14,
//           ),
//         ),
//       ],
//     ),
//   );
//   return Column(
//     children: [
//       row('Labor', money(q.labor)),
//       row('Materials', money(q.materials)),
//       row('Equipment', money(q.equipment)),
//       row('Disposal fees', money(q.disposal)),
//       row('Travel / service fee', money(q.travel)),
//       row('Discount', '- ${money(q.discount)}', col: C.green),
//       row('Tax (${q.taxPct}%)', money(q.subtotal * q.taxPct / 100)),
//       const Divider(),
//       row('Project Total', money(q.total), strong: true),
//       Container(
//         margin: const EdgeInsets.only(top: 8),
//         padding: const EdgeInsets.all(12),
//         color: C.yellow.withAlpha(40),
//         child: Column(
//           children: [
//             row(
//               'Required Deposit (${q.depositPct.toStringAsFixed(0)}%)',
//               money(q.deposit),
//               strong: true,
//             ),
//             row('Remaining Balance', money(q.balance), strong: true),
//           ],
//         ),
//       ),
//     ],
//   );
// }

// void openQuoteBuilder(
//   BuildContext context, {
//   QuoteRequest? request,
//   String? customer,
// }) {
//   showDialog(
//     context: context,
//     builder: (_) => QuoteBuilder(request: request, customer: customer),
//   );
// }

// class QuoteBuilder extends StatefulWidget {
//   final QuoteRequest? request;
//   final String? customer;
//   const QuoteBuilder({super.key, this.request, this.customer});
//   @override
//   State<QuoteBuilder> createState() => _QuoteBuilderState();
// }

// class _QuoteBuilderState extends State<QuoteBuilder> {
//   final c = Get.find<AppController>();
//   late String customer =
//       widget.request?.customer ?? widget.customer ?? c.customers.first.name;
//   late String service = widget.request?.service ?? 'Painting';
//   final f = <String, TextEditingController>{
//     'Labor': TextEditingController(text: '900'),
//     'Materials': TextEditingController(text: '350'),
//     'Equipment': TextEditingController(text: '0'),
//     'Disposal fees': TextEditingController(text: '0'),
//     'Travel / service fee': TextEditingController(text: '50'),
//     'Discount': TextEditingController(text: '0'),
//   };
//   late double taxPct = c.defaultTax.value;
//   late double depositPct = c.defaultDeposit.value;
//   bool fixedDeposit = false;
//   final fixedCtl = TextEditingController(text: '500');
//   DateTime expires = DateTime(2026, 10, 25);
//   final terms = TextEditingController(
//     text:
//         'Deposit is required to book. Balance due upon completion. Quote valid until the expiration date.',
//   );
//   final notes = TextEditingController();

//   double n(String k) => double.tryParse(f[k]!.text) ?? 0;
//   Quote get preview {
//     final q = Quote(
//       'Q-${2032 + c.quotes.length - 6}',
//       customer,
//       service,
//       'Sent',
//       n('Labor'),
//       n('Materials'),
//       n('Equipment'),
//       n('Disposal fees'),
//       n('Travel / service fee'),
//       n('Discount'),
//       taxPct,
//       depositPct,
//       expires,
//     );
//     if (fixedDeposit && q.total > 0)
//       q.depositPct = ((double.tryParse(fixedCtl.text) ?? 0) / q.total * 100)
//           .clamp(0, 100);
//     return q;
//   }

//   @override
//   Widget build(BuildContext context) {
//     final names = c.customers.map((e) => e.name).toList();
//     if (!names.contains(customer)) names.add(customer);
//     final services = [
//       'Painting',
//       'Moving',
//       'Cleaning',
//       'Assembly',
//       'Lawn Services',
//       'Waste Disposal',
//       'Pressure Washing',
//       'General Handyman',
//       'Other',
//     ];
//     if (!services.contains(service)) services.add(service);
//     final q = preview;
//     final form = Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         DropdownButtonFormField<String>(
//           value: customer,
//           decoration: const InputDecoration(labelText: 'Customer'),
//           items: [
//             for (final e in names) DropdownMenuItem(value: e, child: Text(e)),
//           ],
//           onChanged: (v) => setState(() => customer = v!),
//         ),
//         const SizedBox(height: 12),
//         DropdownButtonFormField<String>(
//           value: service,
//           decoration: const InputDecoration(labelText: 'Service'),
//           items: [
//             for (final e in services)
//               DropdownMenuItem(value: e, child: Text(e)),
//           ],
//           onChanged: (v) => setState(() => service = v!),
//         ),
//         const SizedBox(height: 16),
//         Grid(
//           minWidth: 170,
//           gap: 12,
//           children: [
//             for (final k in f.keys)
//               TextField(
//                 controller: f[k],
//                 keyboardType: TextInputType.number,
//                 onChanged: (_) => setState(() {}),
//                 decoration: InputDecoration(labelText: k, prefixText: '\$ '),
//               ),
//           ],
//         ),
//         const SizedBox(height: 12),
//         Row(
//           children: [
//             Expanded(
//               child: Text(
//                 'Tax: ${taxPct.toStringAsFixed(3)}%',
//                 style: const TextStyle(fontWeight: FontWeight.w700),
//               ),
//             ),
//             Expanded(
//               flex: 2,
//               child: Slider(
//                 value: taxPct,
//                 min: 0,
//                 max: 10,
//                 divisions: 40,
//                 activeColor: C.navy,
//                 onChanged: (v) => setState(() => taxPct = v),
//               ),
//             ),
//           ],
//         ),
//         Row(
//           children: [
//             const Expanded(
//               child: Text(
//                 'Deposit type',
//                 style: TextStyle(fontWeight: FontWeight.w700),
//               ),
//             ),
//             SegmentedButton<bool>(
//               showSelectedIcon: false,
//               segments: const [
//                 ButtonSegment(value: false, label: Text('Percent')),
//                 ButtonSegment(value: true, label: Text('Fixed \$')),
//               ],
//               selected: {fixedDeposit},
//               onSelectionChanged: (s) => setState(() => fixedDeposit = s.first),
//             ),
//           ],
//         ),
//         if (!fixedDeposit)
//           Row(
//             children: [
//               Expanded(
//                 child: Text(
//                   'Deposit: ${depositPct.toStringAsFixed(0)}%',
//                   style: const TextStyle(fontWeight: FontWeight.w700),
//                 ),
//               ),
//               Expanded(
//                 flex: 2,
//                 child: Slider(
//                   value: depositPct,
//                   min: 0,
//                   max: 100,
//                   divisions: 20,
//                   activeColor: C.navy,
//                   onChanged: (v) => setState(() => depositPct = v),
//                 ),
//               ),
//             ],
//           )
//         else
//           Padding(
//             padding: const EdgeInsets.only(top: 8),
//             child: TextField(
//               controller: fixedCtl,
//               keyboardType: TextInputType.number,
//               onChanged: (_) => setState(() {}),
//               decoration: const InputDecoration(
//                 labelText: 'Fixed deposit amount',
//                 prefixText: '\$ ',
//               ),
//             ),
//           ),
//         const SizedBox(height: 12),
//         ListTile(
//           contentPadding: EdgeInsets.zero,
//           title: const Text(
//             'Expiration date',
//             style: TextStyle(fontWeight: FontWeight.w700),
//           ),
//           subtitle: Text(fmtDate(expires)),
//           trailing: const Icon(Icons.calendar_today),
//           onTap: () async {
//             final d = await showDatePicker(
//               context: context,
//               initialDate: expires,
//               firstDate: DateTime(2026, 10, 4),
//               lastDate: DateTime(2027, 12, 31),
//             );
//             if (d != null) setState(() => expires = d);
//           },
//         ),
//         TextField(
//           controller: terms,
//           maxLines: 3,
//           decoration: const InputDecoration(labelText: 'Terms & conditions'),
//         ),
//         const SizedBox(height: 12),
//         TextField(
//           controller: notes,
//           maxLines: 2,
//           decoration: const InputDecoration(labelText: 'Notes to customer'),
//         ),
//         const SizedBox(height: 12),
//         OutlinedButton.icon(
//           onPressed: () => c.snack('Attachment picker (demo)'),
//           icon: const Icon(Icons.attach_file),
//           label: const Text('Add attachments'),
//         ),
//       ],
//     );
//     final summary = Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         border: Border.all(color: C.line),
//         color: const Color(0xFFFAFBFC),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             'QUOTE PREVIEW',
//             style: TextStyle(
//               fontWeight: FontWeight.w900,
//               letterSpacing: 1,
//               color: C.muted,
//               fontSize: 12,
//             ),
//           ),
//           const SizedBox(height: 10),
//           totalsView(q),
//         ],
//       ),
//     );
//     return Dialog(
//       insetPadding: const EdgeInsets.all(14),
//       child: ConstrainedBox(
//         constraints: const BoxConstraints(maxWidth: 980, maxHeight: 760),
//         child: Column(
//           children: [
//             Container(
//               color: C.navy,
//               padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
//               child: Row(
//                 children: [
//                   Expanded(
//                     child: Text(
//                       widget.request != null
//                           ? 'Create Quote for ${widget.request!.id}'
//                           : 'New Quote',
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontWeight: FontWeight.w900,
//                         fontSize: 16,
//                       ),
//                     ),
//                   ),
//                   IconButton(
//                     onPressed: () => Navigator.pop(context),
//                     icon: const Icon(Icons.close, color: Colors.white),
//                   ),
//                 ],
//               ),
//             ),
//             Expanded(
//               child: LayoutBuilder(
//                 builder: (context, box) {
//                   if (box.maxWidth > 760) {
//                     return Row(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Expanded(
//                           flex: 3,
//                           child: SingleChildScrollView(
//                             padding: const EdgeInsets.all(20),
//                             child: form,
//                           ),
//                         ),
//                         Expanded(
//                           flex: 2,
//                           child: SingleChildScrollView(
//                             padding: const EdgeInsets.fromLTRB(0, 20, 20, 20),
//                             child: summary,
//                           ),
//                         ),
//                       ],
//                     );
//                   }
//                   return SingleChildScrollView(
//                     padding: const EdgeInsets.all(16),
//                     child: Column(
//                       children: [form, const SizedBox(height: 16), summary],
//                     ),
//                   );
//                 },
//               ),
//             ),
//             Container(
//               decoration: const BoxDecoration(
//                 border: Border(top: BorderSide(color: C.line)),
//               ),
//               padding: const EdgeInsets.all(14),
//               child: Wrap(
//                 alignment: WrapAlignment.end,
//                 spacing: 10,
//                 runSpacing: 10,
//                 children: [
//                   OutlinedButton(
//                     onPressed: () {
//                       c.snack('Draft saved');
//                       Navigator.pop(context);
//                     },
//                     child: const Text('Save Draft'),
//                   ),
//                   ElevatedButton.icon(
//                     onPressed: () {
//                       c.addQuote(preview, requestId: widget.request?.id);
//                       Navigator.pop(context);
//                       c.page.value = 3;
//                     },
//                     icon: const Icon(Icons.send),
//                     label: const Text('SEND TO CUSTOMER'),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // ───────────────────────── JOBS ─────────────────────────
// class JobsPage extends StatelessWidget {
//   const JobsPage({super.key});
//   @override
//   Widget build(BuildContext context) {
//     final c = Get.find<AppController>();
//     return PageScaffold(
//       title: 'Jobs',
//       subtitle: 'Track every approved project from deposit to close',
//       children: [
//         FilterBar(const [
//           'All',
//           'Scheduled',
//           'In Progress',
//           'Completed',
//           'Unassigned',
//         ], c.jobFilter),
//         const SizedBox(height: 14),
//         Obx(() {
//           final f = c.jobFilter.value;
//           bool ok(Job j) {
//             switch (f) {
//               case 'Scheduled':
//                 return j.stage >= 3 && j.stage <= 5;
//               case 'In Progress':
//                 return j.stage == 6 || j.stage == 7;
//               case 'Completed':
//                 return j.stage >= 8;
//               case 'Unassigned':
//                 return j.crew == 'Unassigned';
//               default:
//                 return true;
//             }
//           }

//           final list = c.jobs.where(ok).toList();
//           return ResponsiveTable(
//             headers: const [
//               'Job',
//               'Service',
//               'Schedule',
//               'Crew',
//               'Amount',
//               'Status',
//             ],
//             rows: [
//               for (final j in list)
//                 [
//                   sub(j.customer, '${j.id} • ${j.address}'),
//                   plain(j.service),
//                   plain('${fmtDate(j.date)} • ${j.time}'),
//                   plain(j.crew),
//                   bold(money(j.amount)),
//                   Chip2(jobStages[j.stage]),
//                 ],
//             ],
//             onTap: (i) => openJob(context, list[i]),
//           );
//         }),
//       ],
//     );
//   }
// }

// void openJob(BuildContext context, Job j) {
//   final c = Get.find<AppController>();
//   showDialog(
//     context: context,
//     builder: (_) => StatefulBuilder(
//       builder: (ctx, setS) {
//         Widget photos(String t, int n) => Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 '$t ($n)',
//                 style: const TextStyle(fontWeight: FontWeight.w900),
//               ),
//               const SizedBox(height: 8),
//               Wrap(
//                 spacing: 6,
//                 runSpacing: 6,
//                 children: [
//                   for (int i = 0; i < n; i++)
//                     Container(
//                       width: 54,
//                       height: 54,
//                       color: C.line,
//                       child: const Icon(Icons.image, color: C.muted, size: 20),
//                     ),
//                   InkWell(
//                     onTap: () {
//                       setS(() {
//                         t == 'Before' ? j.before++ : j.after++;
//                       });
//                       c.jobs.refresh();
//                     },
//                     child: Container(
//                       width: 54,
//                       height: 54,
//                       decoration: BoxDecoration(
//                         border: Border.all(color: C.navy),
//                       ),
//                       child: const Icon(
//                         Icons.add_a_photo,
//                         size: 20,
//                         color: C.navy,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         );
//         return Dialog(
//           insetPadding: const EdgeInsets.all(16),
//           child: ConstrainedBox(
//             constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
//             child: Column(
//               children: [
//                 Container(
//                   color: C.navy,
//                   padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
//                   child: Row(
//                     children: [
//                       Expanded(
//                         child: Text(
//                           '${j.id} • ${j.service}',
//                           style: const TextStyle(
//                             color: Colors.white,
//                             fontWeight: FontWeight.w900,
//                             fontSize: 16,
//                           ),
//                         ),
//                       ),
//                       IconButton(
//                         onPressed: () => Navigator.pop(ctx),
//                         icon: const Icon(Icons.close, color: Colors.white),
//                       ),
//                     ],
//                   ),
//                 ),
//                 Expanded(
//                   child: SingleChildScrollView(
//                     padding: const EdgeInsets.all(20),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         KV('Customer', j.customer),
//                         KV('Address', j.address),
//                         KV('Schedule', '${fmtDate(j.date)} • ${j.time}'),
//                         KV('Duration', j.duration),
//                         KV('Amount', money(j.amount), boldV: true),
//                         const SizedBox(height: 10),
//                         DropdownButtonFormField<String>(
//                           value:
//                               [
//                                 'Unassigned',
//                                 'Crew A',
//                                 'Crew B',
//                                 'Crew C',
//                               ].contains(j.crew)
//                               ? j.crew
//                               : 'Unassigned',
//                           decoration: const InputDecoration(
//                             labelText: 'Assigned crew',
//                           ),
//                           items: [
//                             for (final e in [
//                               'Unassigned',
//                               'Crew A',
//                               'Crew B',
//                               'Crew C',
//                             ])
//                               DropdownMenuItem(value: e, child: Text(e)),
//                           ],
//                           onChanged: (v) {
//                             setS(() => j.crew = v!);
//                             c.jobs.refresh();
//                           },
//                         ),
//                         const SizedBox(height: 20),
//                         const Text(
//                           'Job Status',
//                           style: TextStyle(fontWeight: FontWeight.w900),
//                         ),
//                         const SizedBox(height: 8),
//                         for (int i = 0; i < jobStages.length; i++)
//                           InkWell(
//                             onTap: () {
//                               setS(() => j.stage = i);
//                               c.setJobStage(j, i);
//                             },
//                             child: Padding(
//                               padding: const EdgeInsets.symmetric(vertical: 5),
//                               child: Row(
//                                 children: [
//                                   Container(
//                                     width: 22,
//                                     height: 22,
//                                     alignment: Alignment.center,
//                                     color: i < j.stage
//                                         ? C.green
//                                         : (i == j.stage ? C.yellow : C.line),
//                                     child: i < j.stage
//                                         ? const Icon(
//                                             Icons.check,
//                                             size: 15,
//                                             color: Colors.white,
//                                           )
//                                         : Text(
//                                             '${i + 1}',
//                                             style: const TextStyle(
//                                               fontSize: 11,
//                                               fontWeight: FontWeight.w800,
//                                             ),
//                                           ),
//                                   ),
//                                   const SizedBox(width: 12),
//                                   Text(
//                                     jobStages[i],
//                                     style: TextStyle(
//                                       fontWeight: i == j.stage
//                                           ? FontWeight.w900
//                                           : FontWeight.w500,
//                                       color: i > j.stage ? C.muted : C.text,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                         const SizedBox(height: 20),
//                         Row(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             photos('Before', j.before),
//                             const SizedBox(width: 12),
//                             photos('After', j.after),
//                           ],
//                         ),
//                         const SizedBox(height: 16),
//                         const TextField(
//                           maxLines: 3,
//                           decoration: InputDecoration(
//                             labelText: 'Job instructions / notes for crew',
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     ),
//   );
// }

// // ───────────────────────── CALENDAR ─────────────────────────
// class CalendarPage extends StatelessWidget {
//   const CalendarPage({super.key});
//   @override
//   Widget build(BuildContext context) {
//     final c = Get.find<AppController>();
//     return PageScaffold(
//       title: 'Calendar & Scheduling',
//       subtitle: 'Customers request dates — you control the final schedule',
//       children: [
//         Obx(() {
//           final m = c.calMonth.value;
//           final first = DateTime(m.year, m.month, 1);
//           final days = DateTime(m.year, m.month + 1, 0).day;
//           final offset = first.weekday % 7;
//           final cells = <Widget>[
//             for (final d in ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'])
//               Center(
//                 child: Text(
//                   d,
//                   style: const TextStyle(
//                     fontWeight: FontWeight.w800,
//                     color: C.muted,
//                     fontSize: 12,
//                   ),
//                 ),
//               ),
//             for (int i = 0; i < offset; i++) const SizedBox(),
//             for (int d = 1; d <= days; d++)
//               Builder(
//                 builder: (_) {
//                   final date = DateTime(m.year, m.month, d);
//                   final js = c.jobsOn(date);
//                   final sel = c.selectedDay.value == date;
//                   return InkWell(
//                     onTap: () => c.selectedDay.value = date,
//                     child: Container(
//                       margin: const EdgeInsets.all(2),
//                       padding: const EdgeInsets.all(6),
//                       decoration: BoxDecoration(
//                         color: sel ? C.navy : Colors.white,
//                         border: Border.all(color: sel ? C.navy : C.line),
//                       ),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             '$d',
//                             style: TextStyle(
//                               fontWeight: FontWeight.w800,
//                               color: sel ? Colors.white : C.text,
//                             ),
//                           ),
//                           const Spacer(),
//                           if (js.isNotEmpty)
//                             Row(
//                               children: [
//                                 for (int i = 0; i < js.length && i < 4; i++)
//                                   Container(
//                                     width: 7,
//                                     height: 7,
//                                     margin: const EdgeInsets.only(right: 3),
//                                     color: sel ? C.yellow : C.navy,
//                                   ),
//                               ],
//                             ),
//                           if (js.isNotEmpty)
//                             Text(
//                               '${js.length} job${js.length > 1 ? 's' : ''}',
//                               style: TextStyle(
//                                 fontSize: 10,
//                                 color: sel ? C.yellow : C.muted,
//                               ),
//                             ),
//                         ],
//                       ),
//                     ),
//                   );
//                 },
//               ),
//           ];
//           final grid = Panel(
//             padding: const EdgeInsets.all(14),
//             child: Column(
//               children: [
//                 Row(
//                   children: [
//                     IconButton(
//                       onPressed: () =>
//                           c.calMonth.value = DateTime(m.year, m.month - 1, 1),
//                       icon: const Icon(Icons.chevron_left),
//                     ),
//                     Expanded(
//                       child: Center(
//                         child: Text(
//                           '${_months[m.month - 1]} ${m.year}',
//                           style: const TextStyle(
//                             fontWeight: FontWeight.w900,
//                             fontSize: 18,
//                           ),
//                         ),
//                       ),
//                     ),
//                     IconButton(
//                       onPressed: () =>
//                           c.calMonth.value = DateTime(m.year, m.month + 1, 1),
//                       icon: const Icon(Icons.chevron_right),
//                     ),
//                   ],
//                 ),
//                 LayoutBuilder(
//                   builder: (context, box) {
//                     final cellH = box.maxWidth < 500 ? 56.0 : 82.0;
//                     return GridView.count(
//                       crossAxisCount: 7,
//                       shrinkWrap: true,
//                       physics: const NeverScrollableScrollPhysics(),
//                       childAspectRatio: (box.maxWidth / 7) / cellH,
//                       children: cells,
//                     );
//                   },
//                 ),
//               ],
//             ),
//           );
//           final sel = c.selectedDay.value;
//           final dayJobs = c.jobsOn(sel);
//           final side = Panel(
//             title: fmtDate(sel),
//             child: dayJobs.isEmpty
//                 ? const Padding(
//                     padding: EdgeInsets.symmetric(vertical: 20),
//                     child: Center(
//                       child: Text(
//                         'No jobs scheduled',
//                         style: TextStyle(color: C.muted),
//                       ),
//                     ),
//                   )
//                 : Column(
//                     children: [
//                       for (final j in dayJobs)
//                         Container(
//                           margin: const EdgeInsets.only(bottom: 10),
//                           padding: const EdgeInsets.all(12),
//                           decoration: const BoxDecoration(
//                             border: Border(
//                               left: BorderSide(color: C.yellow, width: 4),
//                             ),
//                             color: Color(0xFFFAFBFC),
//                           ),
//                           child: InkWell(
//                             onTap: () => openJob(context, j),
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text(
//                                   '${j.time} • ${j.service}',
//                                   style: const TextStyle(
//                                     fontWeight: FontWeight.w900,
//                                   ),
//                                 ),
//                                 Text(j.customer),
//                                 Text(
//                                   j.address,
//                                   style: const TextStyle(
//                                     color: C.muted,
//                                     fontSize: 12,
//                                   ),
//                                 ),
//                                 const SizedBox(height: 6),
//                                 Wrap(
//                                   spacing: 8,
//                                   runSpacing: 4,
//                                   children: [
//                                     Chip2(jobStages[j.stage]),
//                                     Chip2(j.crew, color: C.navy),
//                                     Chip2(j.duration, color: C.muted),
//                                   ],
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                     ],
//                   ),
//           );
//           return LayoutBuilder(
//             builder: (context, box) {
//               if (box.maxWidth >= 900) {
//                 return Row(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Expanded(flex: 3, child: grid),
//                     const SizedBox(width: 16),
//                     Expanded(flex: 2, child: side),
//                   ],
//                 );
//               }
//               return Column(children: [grid, const SizedBox(height: 16), side]);
//             },
//           );
//         }),
//       ],
//     );
//   }
// }

// // ───────────────────────── INVOICES ─────────────────────────
// class InvoicesPage extends StatelessWidget {
//   const InvoicesPage({super.key});
//   @override
//   Widget build(BuildContext context) {
//     final c = Get.find<AppController>();
//     return PageScaffold(
//       title: 'Invoices',
//       subtitle: 'Auto-generated from approved quotes',
//       actions: [
//         OutlinedButton.icon(
//           onPressed: () => c.snack('Invoices exported (demo)'),
//           icon: const Icon(Icons.file_download),
//           label: const Text('Export'),
//         ),
//       ],
//       children: [
//         Obx(
//           () => Grid(
//             minWidth: 220,
//             children: [
//               Stat(
//                 'Total Invoiced',
//                 money(c.invoices.fold(0.0, (s, i) => s + i.total)),
//                 Icons.receipt_long,
//               ),
//               Stat(
//                 'Collected',
//                 money(c.invoices.fold(0.0, (s, i) => s + i.paid)),
//                 Icons.check_circle,
//                 color: C.green,
//               ),
//               Stat(
//                 'Outstanding',
//                 money(c.outstanding),
//                 Icons.pending_actions,
//                 color: C.red,
//               ),
//             ],
//           ),
//         ),
//         const SizedBox(height: 16),
//         FilterBar(const [
//           'All',
//           'Paid',
//           'Partial',
//           'Unpaid',
//           'Overdue',
//         ], c.invFilter),
//         const SizedBox(height: 14),
//         Obx(() {
//           final f = c.invFilter.value;
//           final list = c.invoices
//               .where((i) => f == 'All' || i.status == f)
//               .toList();
//           return ResponsiveTable(
//             headers: const [
//               'Invoice',
//               'Job',
//               'Total',
//               'Paid',
//               'Balance',
//               'Due',
//               'Status',
//             ],
//             rows: [
//               for (final i in list)
//                 [
//                   sub(i.id, i.customer),
//                   plain(i.job),
//                   bold(money(i.total)),
//                   plain(money(i.paid)),
//                   plain(money(i.balance)),
//                   plain(fmtDate(i.due)),
//                   Chip2(i.status),
//                 ],
//             ],
//             onTap: (k) => openInvoice(context, list[k]),
//           );
//         }),
//       ],
//     );
//   }
// }

// void openInvoice(BuildContext context, Invoice i) {
//   final c = Get.find<AppController>();
//   showDetail(
//     context,
//     title: 'Invoice ${i.id}',
//     actions: [
//       OutlinedButton.icon(
//         onPressed: () => c.snack('Invoice PDF downloaded'),
//         icon: const Icon(Icons.download),
//         label: const Text('PDF'),
//       ),
//       OutlinedButton.icon(
//         onPressed: () => c.snack('Reminder sent to ${i.customer}'),
//         icon: const Icon(Icons.notifications_active),
//         label: const Text('Send reminder'),
//       ),
//       if (i.balance > 0)
//         ElevatedButton(
//           onPressed: () async {
//             Navigator.pop(context);
//             final m = await showDialog<String>(
//               context: context,
//               builder: (_) => SimpleDialog(
//                 title: const Text('Mark as paid via...'),
//                 children: [
//                   for (final e in ['Zelle', 'Cash', 'Check', 'Card'])
//                     SimpleDialogOption(
//                       onPressed: () => Navigator.pop(context, e),
//                       child: Text(e),
//                     ),
//                 ],
//               ),
//             );
//             if (m != null) c.markInvoicePaid(i, m);
//           },
//           child: const Text('MARK PAID'),
//         ),
//     ],
//     body: Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [const Logo(small: true), const Spacer(), Chip2(i.status)],
//         ),
//         const SizedBox(height: 6),
//         const Text(
//           '1156 Liberty Avenue, Hillside, NJ 07205',
//           style: TextStyle(color: C.muted, fontSize: 12),
//         ),
//         const Divider(height: 28),
//         KV('Bill to', i.customer),
//         KV('Job', i.job),
//         KV('Due date', fmtDate(i.due)),
//         KV('Payment method', i.method),
//         const Divider(height: 28),
//         KV('Total', money(i.total), boldV: true),
//         KV('Deposit / paid', money(i.paid)),
//         KV('Balance due', money(i.balance), boldV: true),
//         const SizedBox(height: 10),
//         const Text(
//           'Terms: Balance due upon completion. Thank you for your business!',
//           style: TextStyle(color: C.muted, fontSize: 12),
//         ),
//       ],
//     ),
//   );
// }

// // ───────────────────────── PAYMENTS ─────────────────────────
// class PaymentsPage extends StatelessWidget {
//   const PaymentsPage({super.key});
//   @override
//   Widget build(BuildContext context) {
//     final c = Get.find<AppController>();
//     return PageScaffold(
//       title: 'Payments',
//       subtitle: 'Processed via Stripe • settled to business bank account',
//       children: [
//         Obx(
//           () => Grid(
//             minWidth: 220,
//             children: [
//               Stat(
//                 'Collected',
//                 money(c.collected),
//                 Icons.account_balance_wallet,
//                 color: C.green,
//               ),
//               Stat(
//                 'Processing Fees',
//                 money(c.fees),
//                 Icons.percent,
//                 color: C.orange,
//               ),
//               Stat(
//                 'Awaiting Zelle',
//                 '${c.payments.where((p) => p.status == 'Awaiting Zelle').length}',
//                 Icons.hourglass_top,
//                 color: C.blue,
//               ),
//               Stat(
//                 'Failed',
//                 '${c.payments.where((p) => p.status == 'Failed').length}',
//                 Icons.error_outline,
//                 color: C.red,
//               ),
//             ],
//           ),
//         ),
//         const SizedBox(height: 16),
//         Obx(() {
//           final list = c.payments.toList();
//           return ResponsiveTable(
//             headers: const [
//               'Payment',
//               'Invoice',
//               'Amount',
//               'Method',
//               'Date',
//               'Status',
//               'Action',
//             ],
//             rows: [
//               for (final p in list)
//                 [
//                   sub(p.customer, p.id),
//                   plain(p.invoice),
//                   bold(money(p.amount)),
//                   plain(p.method),
//                   plain(fmtDate(p.date)),
//                   Chip2(p.status),
//                   if (p.status == 'Awaiting Zelle')
//                     TextButton(
//                       onPressed: () => c.verifyZelle(p),
//                       child: const Text('Verify'),
//                     )
//                   else if (p.status == 'Paid')
//                     TextButton(
//                       onPressed: () => showDialog(
//                         context: context,
//                         builder: (_) => AlertDialog(
//                           title: const Text('Refund payment?'),
//                           content: Text(
//                             'Refund ${money(p.amount)} to ${p.customer}?',
//                           ),
//                           actions: [
//                             TextButton(
//                               onPressed: () => Navigator.pop(context),
//                               child: const Text('Cancel'),
//                             ),
//                             TextButton(
//                               onPressed: () {
//                                 c.refund(p);
//                                 Navigator.pop(context);
//                               },
//                               child: const Text(
//                                 'Refund',
//                                 style: TextStyle(color: C.red),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                       child: const Text('Refund'),
//                     )
//                   else if (p.status == 'Failed')
//                     TextButton(
//                       onPressed: () =>
//                           c.snack('Retry link sent to ${p.customer}'),
//                       child: const Text('Retry'),
//                     )
//                   else
//                     const Text('-'),
//                 ],
//             ],
//           );
//         }),
//         const SizedBox(height: 16),
//         Panel(
//           title: 'Zelle Instructions (shown to customers)',
//           child: Obx(
//             () => Column(
//               children: [
//                 SwitchListTile(
//                   contentPadding: EdgeInsets.zero,
//                   activeColor: C.navy,
//                   title: const Text('Enable "Pay with Zelle"'),
//                   subtitle: const Text(
//                     'Customer pays via their bank app, then you verify the payment manually.',
//                   ),
//                   value: c.zelleEnabled.value,
//                   onChanged: (v) => c.zelleEnabled.value = v,
//                 ),
//                 if (c.zelleEnabled.value)
//                   const KV('Zelle email', 'admin@twinshandymanllc.com'),
//               ],
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }

// // ───────────────────────── MESSAGES ─────────────────────────
// class MessagesPage extends StatelessWidget {
//   const MessagesPage({super.key});
//   @override
//   Widget build(BuildContext context) {
//     final c = Get.find<AppController>();
//     return LayoutBuilder(
//       builder: (context, box) {
//         final wide = box.maxWidth >= 860;
//         final list = Obx(
//           () => ListView(
//             children: [
//               for (int i = 0; i < c.threads.length; i++)
//                 Container(
//                   color: wide && c.selectedThread.value == i
//                       ? C.yellow.withAlpha(40)
//                       : Colors.white,
//                   child: ListTile(
//                     leading: CircleAvatar(
//                       backgroundColor: C.navy,
//                       child: Text(
//                         c.threads[i].customer[0],
//                         style: const TextStyle(
//                           color: C.yellow,
//                           fontWeight: FontWeight.w800,
//                         ),
//                       ),
//                     ),
//                     title: Text(
//                       c.threads[i].customer,
//                       style: TextStyle(
//                         fontWeight: c.threads[i].unread > 0
//                             ? FontWeight.w900
//                             : FontWeight.w600,
//                       ),
//                     ),
//                     subtitle: Text(
//                       '${c.threads[i].job}\n${c.threads[i].msgs.last.text}',
//                       maxLines: 2,
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                     isThreeLine: true,
//                     trailing: c.threads[i].unread > 0
//                         ? CircleAvatar(
//                             radius: 10,
//                             backgroundColor: C.red,
//                             child: Text(
//                               '${c.threads[i].unread}',
//                               style: const TextStyle(
//                                 fontSize: 11,
//                                 color: Colors.white,
//                               ),
//                             ),
//                           )
//                         : null,
//                     onTap: () {
//                       c.selectedThread.value = i;
//                       c.threads[i].unread = 0;
//                       c.threads.refresh();
//                       if (!wide)
//                         Navigator.of(context).push(
//                           MaterialPageRoute(
//                             builder: (_) => Scaffold(
//                               appBar: AppBar(
//                                 backgroundColor: C.navy,
//                                 foregroundColor: Colors.white,
//                                 title: Text(c.threads[i].customer),
//                               ),
//                               body: ChatView(index: i),
//                             ),
//                           ),
//                         );
//                     },
//                   ),
//                 ),
//             ],
//           ),
//         );
//         if (!wide) return list;
//         return Padding(
//           padding: const EdgeInsets.all(24),
//           child: Container(
//             decoration: BoxDecoration(
//               border: Border.all(color: C.line),
//               color: Colors.white,
//             ),
//             child: Row(
//               children: [
//                 SizedBox(width: 340, child: list),
//                 const VerticalDivider(width: 1),
//                 Expanded(
//                   child: Obx(() => ChatView(index: c.selectedThread.value)),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
// }

// class ChatView extends StatefulWidget {
//   final int index;
//   const ChatView({super.key, required this.index});
//   @override
//   State<ChatView> createState() => _ChatViewState();
// }

// class _ChatViewState extends State<ChatView> {
//   final ctl = TextEditingController();
//   @override
//   Widget build(BuildContext context) {
//     final c = Get.find<AppController>();
//     return Column(
//       children: [
//         Obx(
//           () => Container(
//             width: double.infinity,
//             padding: const EdgeInsets.all(14),
//             decoration: const BoxDecoration(
//               border: Border(bottom: BorderSide(color: C.line)),
//             ),
//             child: Text(
//               '${c.threads[widget.index].customer} • ${c.threads[widget.index].job}',
//               style: const TextStyle(fontWeight: FontWeight.w900),
//             ),
//           ),
//         ),
//         Expanded(
//           child: Obx(
//             () => ListView(
//               padding: const EdgeInsets.all(16),
//               children: [
//                 for (final m in c.threads[widget.index].msgs)
//                   Align(
//                     alignment: m.mine
//                         ? Alignment.centerRight
//                         : Alignment.centerLeft,
//                     child: Container(
//                       constraints: const BoxConstraints(maxWidth: 420),
//                       margin: const EdgeInsets.symmetric(vertical: 4),
//                       padding: const EdgeInsets.all(12),
//                       color: m.mine ? C.navy : const Color(0xFFEEF1F5),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.end,
//                         children: [
//                           Text(
//                             m.text,
//                             style: TextStyle(
//                               color: m.mine ? Colors.white : C.text,
//                             ),
//                           ),
//                           const SizedBox(height: 4),
//                           Text(
//                             m.time,
//                             style: TextStyle(
//                               fontSize: 10,
//                               color: m.mine ? const Color(0xFFB8C4D6) : C.muted,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//           ),
//         ),
//         Container(
//           padding: const EdgeInsets.all(10),
//           decoration: const BoxDecoration(
//             border: Border(top: BorderSide(color: C.line)),
//           ),
//           child: Row(
//             children: [
//               IconButton(
//                 onPressed: () =>
//                     c.snack('Attach photo / video / document (demo)'),
//                 icon: const Icon(Icons.attach_file),
//               ),
//               Expanded(
//                 child: TextField(
//                   controller: ctl,
//                   onSubmitted: (v) {
//                     c.sendMessage(widget.index, v);
//                     ctl.clear();
//                   },
//                   decoration: const InputDecoration(
//                     hintText: 'Type a message...',
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 8),
//               ElevatedButton(
//                 onPressed: () {
//                   c.sendMessage(widget.index, ctl.text);
//                   ctl.clear();
//                 },
//                 child: const Icon(Icons.send),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
// }

// // ───────────────────────── DOCUMENTS ─────────────────────────
// class DocumentsPage extends StatelessWidget {
//   const DocumentsPage({super.key});
//   @override
//   Widget build(BuildContext context) {
//     final c = Get.find<AppController>();
//     return PageScaffold(
//       title: 'Documents',
//       subtitle:
//           'Government & commercial contracting section (shown in the app as PDFs)',
//       actions: [
//         ElevatedButton.icon(
//           onPressed: () => c.snack('Upload document (demo)'),
//           icon: const Icon(Icons.upload_file),
//           label: const Text('UPLOAD'),
//         ),
//       ],
//       children: [
//         Panel(
//           title: 'Company Registration Info',
//           child: Grid(
//             minWidth: 220,
//             gap: 12,
//             children: const [
//               KV2('NAICS Codes', '238320, 561720, 561790, 484210'),
//               KV2('UEI', 'TH7K2M9QX4N1 (demo)'),
//               KV2('CAGE Code', 'Pending issuance'),
//               KV2('Certifications', 'MBE, SBE'),
//             ],
//           ),
//         ),
//         const SizedBox(height: 16),
//         Obx(
//           () => ResponsiveTable(
//             headers: const [
//               'Document',
//               'Type',
//               'Visibility',
//               'Updated',
//               'Actions',
//             ],
//             rows: [
//               for (final d in c.documents)
//                 [
//                   Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       const Icon(Icons.picture_as_pdf, color: C.red),
//                       const SizedBox(width: 10),
//                       Flexible(child: bold(d.name)),
//                     ],
//                   ),
//                   plain(d.type),
//                   Chip2(d.visibility),
//                   plain(d.updated),
//                   Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       IconButton(
//                         tooltip: 'Download',
//                         onPressed: () => c.snack('${d.name} downloaded'),
//                         icon: const Icon(Icons.download),
//                       ),
//                       IconButton(
//                         tooltip: 'Toggle visibility',
//                         onPressed: () {
//                           d.visibility = d.visibility == 'Public'
//                               ? 'Private'
//                               : 'Public';
//                           c.documents.refresh();
//                         },
//                         icon: Icon(
//                           d.visibility == 'Public'
//                               ? Icons.public
//                               : Icons.lock_outline,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//             ],
//           ),
//         ),
//         const SizedBox(height: 10),
//         const Text(
//           'Sensitive documents stay private unless you explicitly make them public.',
//           style: TextStyle(color: C.muted, fontSize: 12),
//         ),
//       ],
//     );
//   }
// }

// class KV2 extends StatelessWidget {
//   final String k, v;
//   const KV2(this.k, this.v, {super.key});
//   @override
//   Widget build(BuildContext context) => Container(
//     padding: const EdgeInsets.all(12),
//     color: const Color(0xFFF7F8FA),
//     child: Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(k, style: const TextStyle(color: C.muted, fontSize: 12)),
//         const SizedBox(height: 4),
//         Text(v, style: const TextStyle(fontWeight: FontWeight.w800)),
//       ],
//     ),
//   );
// }

// // ───────────────────────── REVIEWS ─────────────────────────
// class ReviewsPage extends StatelessWidget {
//   const ReviewsPage({super.key});
//   @override
//   Widget build(BuildContext context) {
//     final c = Get.find<AppController>();
//     Widget stars(int n) => Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         for (int i = 0; i < 5; i++)
//           Icon(
//             i < n ? Icons.star : Icons.star_border,
//             color: C.yellow,
//             size: 18,
//           ),
//       ],
//     );
//     return PageScaffold(
//       title: 'Reviews',
//       subtitle: 'Customer feedback collected after job completion',
//       actions: [
//         OutlinedButton.icon(
//           onPressed: () => c.snack('Review link copied (Google)'),
//           icon: const Icon(Icons.link),
//           label: const Text('Copy Google review link'),
//         ),
//       ],
//       children: [
//         Obx(
//           () => Grid(
//             minWidth: 220,
//             children: [
//               Stat(
//                 'Average Rating',
//                 '${c.avgRating.toStringAsFixed(1)} ★',
//                 Icons.star,
//                 color: C.yellow,
//               ),
//               Stat(
//                 'Total Reviews',
//                 '${c.reviews.length}',
//                 Icons.rate_review,
//                 color: C.blue,
//               ),
//               Stat(
//                 'Awaiting Reply',
//                 '${c.reviews.where((r) => !r.replied).length}',
//                 Icons.reply,
//                 color: C.orange,
//               ),
//             ],
//           ),
//         ),
//         const SizedBox(height: 16),
//         Obx(
//           () => Column(
//             children: [
//               for (final r in c.reviews)
//                 Container(
//                   margin: const EdgeInsets.only(bottom: 10),
//                   child: Panel(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Wrap(
//                           spacing: 12,
//                           runSpacing: 4,
//                           crossAxisAlignment: WrapCrossAlignment.center,
//                           children: [
//                             Text(
//                               r.customer,
//                               style: const TextStyle(
//                                 fontWeight: FontWeight.w900,
//                               ),
//                             ),
//                             stars(r.stars),
//                             Chip2(r.service, color: C.navy),
//                             Text(
//                               r.date,
//                               style: const TextStyle(
//                                 color: C.muted,
//                                 fontSize: 12,
//                               ),
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 8),
//                         Text(r.text),
//                         const SizedBox(height: 8),
//                         r.replied
//                             ? const Chip2('Replied', color: C.green)
//                             : TextButton.icon(
//                                 onPressed: () {
//                                   r.replied = true;
//                                   c.reviews.refresh();
//                                   c.snack('Reply posted');
//                                 },
//                                 icon: const Icon(Icons.reply),
//                                 label: const Text('Reply'),
//                               ),
//                       ],
//                     ),
//                   ),
//                 ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
// }

// // ───────────────────────── REPORTS ─────────────────────────
// class ReportsPage extends StatelessWidget {
//   const ReportsPage({super.key});
//   @override
//   Widget build(BuildContext context) {
//     final c = Get.find<AppController>();
//     final maxS = c.serviceRevenue.values.reduce((a, b) => a > b ? a : b);
//     final maxM = c.monthlyRevenue.values.reduce((a, b) => a > b ? a : b);
//     return PageScaffold(
//       title: 'Reports',
//       subtitle: 'Business performance • exportable',
//       actions: [
//         OutlinedButton.icon(
//           onPressed: () => c.snack('Exported to CSV'),
//           icon: const Icon(Icons.table_chart),
//           label: const Text('CSV'),
//         ),
//         OutlinedButton.icon(
//           onPressed: () => c.snack('Exported to PDF'),
//           icon: const Icon(Icons.picture_as_pdf),
//           label: const Text('PDF'),
//         ),
//       ],
//       children: [
//         Grid(
//           minWidth: 220,
//           children: const [
//             Stat(
//               'Quote Conversion',
//               '64%',
//               Icons.swap_horiz,
//               color: C.green,
//               hint: '16 of 25 quotes approved',
//             ),
//             Stat(
//               'Job Volume (Oct)',
//               '28',
//               Icons.construction,
//               hint: '+4 vs Sep',
//             ),
//             Stat(
//               'Recurring Revenue',
//               '\$3,450',
//               Icons.autorenew,
//               color: C.blue,
//               hint: 'Per month',
//             ),
//             Stat(
//               'New Customers',
//               '6',
//               Icons.person_add_alt,
//               color: C.orange,
//               hint: 'Oct 2026',
//             ),
//           ],
//         ),
//         const SizedBox(height: 16),
//         LayoutBuilder(
//           builder: (context, box) {
//             final a = Panel(
//               title: 'Revenue by Service Type',
//               child: Column(
//                 children: [
//                   for (final e in c.serviceRevenue.entries)
//                     Padding(
//                       padding: const EdgeInsets.symmetric(vertical: 6),
//                       child: Row(
//                         children: [
//                           SizedBox(
//                             width: 100,
//                             child: Text(
//                               e.key,
//                               style: const TextStyle(
//                                 fontWeight: FontWeight.w600,
//                               ),
//                             ),
//                           ),
//                           Expanded(
//                             child: LayoutBuilder(
//                               builder: (_, b) => Align(
//                                 alignment: Alignment.centerLeft,
//                                 child: Container(
//                                   height: 18,
//                                   width: b.maxWidth * e.value / maxS,
//                                   color: C.navy,
//                                 ),
//                               ),
//                             ),
//                           ),
//                           SizedBox(
//                             width: 80,
//                             child: Text(
//                               money(e.value).replaceAll('.00', ''),
//                               textAlign: TextAlign.right,
//                               style: const TextStyle(
//                                 fontWeight: FontWeight.w800,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                 ],
//               ),
//             );
//             final b = Panel(
//               title: 'Monthly Revenue',
//               child: SizedBox(
//                 height: 200,
//                 child: Row(
//                   crossAxisAlignment: CrossAxisAlignment.end,
//                   children: [
//                     for (final e in c.monthlyRevenue.entries)
//                       Expanded(
//                         child: Padding(
//                           padding: const EdgeInsets.symmetric(horizontal: 5),
//                           child: Column(
//                             mainAxisAlignment: MainAxisAlignment.end,
//                             children: [
//                               Container(
//                                 height: 140 * e.value / maxM,
//                                 color: C.yellow,
//                               ),
//                               const SizedBox(height: 6),
//                               Text(
//                                 e.key,
//                                 style: const TextStyle(
//                                   color: C.muted,
//                                   fontSize: 12,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                   ],
//                 ),
//               ),
//             );
//             return box.maxWidth >= 900
//                 ? Row(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Expanded(child: a),
//                       const SizedBox(width: 16),
//                       Expanded(child: b),
//                     ],
//                   )
//                 : Column(children: [a, const SizedBox(height: 16), b]);
//           },
//         ),
//         const SizedBox(height: 16),
//         Panel(
//           title: 'Payment Summary',
//           child: Obx(
//             () => Column(
//               children: [
//                 const KV(
//                   'Card / Apple Pay / Google Pay',
//                   'Stripe • 2.9% + \$0.30',
//                 ),
//                 const KV('ACH', 'Stripe • 0.8% (max \$5)'),
//                 const KV('Zelle', 'No processing fee'),
//                 KV('Total fees paid', money(c.fees), boldV: true),
//                 KV('Outstanding invoices', money(c.outstanding), boldV: true),
//               ],
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }

// // ───────────────────────── USERS & PERMISSIONS ─────────────────────────
// class UsersPage extends StatelessWidget {
//   const UsersPage({super.key});
//   @override
//   Widget build(BuildContext context) {
//     final c = Get.find<AppController>();
//     const modules = [
//       'Customers',
//       'Quotes',
//       'Jobs',
//       'Scheduling',
//       'Invoices',
//       'Payments',
//       'Reports',
//       'Settings',
//     ];
//     const matrix = {
//       'Owner': [1, 1, 1, 1, 1, 1, 1, 1],
//       'Manager': [1, 1, 1, 1, 0, 0, 0, 0],
//       'Crew': [0, 0, 1, 1, 0, 0, 0, 0],
//     };
//     return PageScaffold(
//       title: 'Users & Permissions',
//       subtitle: 'Role-based access control',
//       actions: [
//         ElevatedButton.icon(
//           onPressed: () => inviteDialog(context),
//           icon: const Icon(Icons.person_add),
//           label: const Text('INVITE USER'),
//         ),
//       ],
//       children: [
//         Obx(
//           () => ResponsiveTable(
//             headers: const ['User', 'Role', 'Status', 'Active'],
//             rows: [
//               for (final u in c.staff)
//                 [
//                   sub(u.name, u.email),
//                   DropdownButton<String>(
//                     value: u.role,
//                     underline: const SizedBox(),
//                     items: [
//                       for (final r in ['Owner', 'Manager', 'Crew'])
//                         DropdownMenuItem(value: r, child: Text(r)),
//                     ],
//                     onChanged: (v) => c.changeRole(u, v!),
//                   ),
//                   Chip2(u.active ? 'Active' : 'Inactive'),
//                   Switch(
//                     value: u.active,
//                     activeColor: C.navy,
//                     onChanged: (v) => c.toggleUser(u, v),
//                   ),
//                 ],
//             ],
//           ),
//         ),
//         const SizedBox(height: 16),
//         Panel(
//           title: 'Permission Matrix',
//           child: SingleChildScrollView(
//             scrollDirection: Axis.horizontal,
//             child: DataTable(
//               headingTextStyle: const TextStyle(
//                 fontWeight: FontWeight.w800,
//                 color: C.navy,
//               ),
//               columns: [
//                 const DataColumn(label: Text('ROLE')),
//                 for (final m in modules)
//                   DataColumn(
//                     label: Text(
//                       m.toUpperCase(),
//                       style: const TextStyle(fontSize: 11),
//                     ),
//                   ),
//               ],
//               rows: [
//                 for (final e in matrix.entries)
//                   DataRow(
//                     cells: [
//                       DataCell(
//                         Text(
//                           e.key,
//                           style: const TextStyle(fontWeight: FontWeight.w800),
//                         ),
//                       ),
//                       for (final v in e.value)
//                         DataCell(
//                           Icon(
//                             v == 1
//                                 ? Icons.check_circle
//                                 : Icons.remove_circle_outline,
//                             color: v == 1 ? C.green : C.line,
//                             size: 20,
//                           ),
//                         ),
//                     ],
//                   ),
//               ],
//             ),
//           ),
//         ),
//         const SizedBox(height: 10),
//         const Text(
//           'Crew members only see assigned jobs. No role except Owner can access payment or banking settings.',
//           style: TextStyle(color: C.muted, fontSize: 12),
//         ),
//       ],
//     );
//   }
// }

// void inviteDialog(BuildContext context) {
//   final c = Get.find<AppController>();
//   final n = TextEditingController(), e = TextEditingController();
//   String role = 'Crew';
//   showDialog(
//     context: context,
//     builder: (_) => StatefulBuilder(
//       builder: (ctx, setS) {
//         return AlertDialog(
//           title: const Text('Invite User'),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               TextField(
//                 controller: n,
//                 decoration: const InputDecoration(labelText: 'Full name'),
//               ),
//               const SizedBox(height: 12),
//               TextField(
//                 controller: e,
//                 decoration: const InputDecoration(labelText: 'Email'),
//               ),
//               const SizedBox(height: 12),
//               DropdownButtonFormField<String>(
//                 value: role,
//                 decoration: const InputDecoration(labelText: 'Role'),
//                 items: [
//                   for (final r in ['Manager', 'Crew'])
//                     DropdownMenuItem(value: r, child: Text(r)),
//                 ],
//                 onChanged: (v) => setS(() => role = v!),
//               ),
//             ],
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(ctx),
//               child: const Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 if (n.text.isEmpty) return;
//                 c.addStaff(StaffUser(n.text, e.text, role, true));
//                 Navigator.pop(ctx);
//               },
//               child: const Text('SEND INVITE'),
//             ),
//           ],
//         );
//       },
//     ),
//   );
// }

// // ───────────────────────── SETTINGS ─────────────────────────
// class SettingsPage extends StatelessWidget {
//   const SettingsPage({super.key});
//   @override
//   Widget build(BuildContext context) {
//     final c = Get.find<AppController>();
//     return PageScaffold(
//       title: 'Business Settings',
//       subtitle: 'Owner-only settings',
//       actions: [
//         ElevatedButton(
//           onPressed: () => c.snack('Settings saved'),
//           child: const Text('SAVE CHANGES'),
//         ),
//       ],
//       children: [
//         Panel(
//           title: 'Company Profile',
//           child: Grid(
//             minWidth: 280,
//             gap: 12,
//             children: [
//               TextField(
//                 controller: TextEditingController(text: 'Twins Handyman LLC'),
//                 decoration: const InputDecoration(labelText: 'Business name'),
//               ),
//               TextField(
//                 controller: TextEditingController(text: 'twinshandymanllc.com'),
//                 decoration: const InputDecoration(labelText: 'Website'),
//               ),
//               TextField(
//                 controller: TextEditingController(
//                   text: '1156 Liberty Avenue, Hillside, NJ 07205',
//                 ),
//                 decoration: const InputDecoration(labelText: 'Address'),
//               ),
//               TextField(
//                 controller: TextEditingController(text: '908-567-9897'),
//                 decoration: const InputDecoration(labelText: 'Phone'),
//               ),
//               TextField(
//                 controller: TextEditingController(
//                   text: 'North Jersey & Staten Island',
//                 ),
//                 decoration: const InputDecoration(labelText: 'Service area'),
//               ),
//               TextField(
//                 controller: TextEditingController(text: '9:00 AM - 9:00 PM'),
//                 decoration: const InputDecoration(labelText: 'Business hours'),
//               ),
//             ],
//           ),
//         ),
//         const SizedBox(height: 16),
//         Obx(
//           () => Panel(
//             title: 'Quote Defaults',
//             child: Column(
//               children: [
//                 Row(
//                   children: [
//                     Expanded(
//                       child: Text(
//                         'Default deposit: ${c.defaultDeposit.value.toStringAsFixed(0)}%',
//                         style: const TextStyle(fontWeight: FontWeight.w700),
//                       ),
//                     ),
//                     Expanded(
//                       flex: 2,
//                       child: Slider(
//                         value: c.defaultDeposit.value,
//                         min: 0,
//                         max: 100,
//                         divisions: 20,
//                         activeColor: C.navy,
//                         onChanged: (v) => c.defaultDeposit.value = v,
//                       ),
//                     ),
//                   ],
//                 ),
//                 Row(
//                   children: [
//                     Expanded(
//                       child: Text(
//                         'Default tax: ${c.defaultTax.value.toStringAsFixed(3)}%',
//                         style: const TextStyle(fontWeight: FontWeight.w700),
//                       ),
//                     ),
//                     Expanded(
//                       flex: 2,
//                       child: Slider(
//                         value: c.defaultTax.value,
//                         min: 0,
//                         max: 10,
//                         divisions: 40,
//                         activeColor: C.navy,
//                         onChanged: (v) => c.defaultTax.value = v,
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ),
//         const SizedBox(height: 16),
//         Obx(
//           () => Panel(
//             title: 'Notifications',
//             child: Column(
//               children: [
//                 SwitchListTile(
//                   contentPadding: EdgeInsets.zero,
//                   activeColor: C.navy,
//                   title: const Text('Push: new quote request'),
//                   value: c.pushNewRequest.value,
//                   onChanged: (v) => c.pushNewRequest.value = v,
//                 ),
//                 SwitchListTile(
//                   contentPadding: EdgeInsets.zero,
//                   activeColor: C.navy,
//                   title: const Text('Email: new quote request'),
//                   value: c.emailNewRequest.value,
//                   onChanged: (v) => c.emailNewRequest.value = v,
//                 ),
//                 SwitchListTile(
//                   contentPadding: EdgeInsets.zero,
//                   activeColor: C.navy,
//                   title: const Text('Push: payments received / failed'),
//                   value: c.pushPayments.value,
//                   onChanged: (v) => c.pushPayments.value = v,
//                 ),
//                 SwitchListTile(
//                   contentPadding: EdgeInsets.zero,
//                   activeColor: C.navy,
//                   title: const Text('Push: new messages'),
//                   value: c.pushMessages.value,
//                   onChanged: (v) => c.pushMessages.value = v,
//                 ),
//               ],
//             ),
//           ),
//         ),
//         const SizedBox(height: 16),
//         const Panel(
//           title: 'Security',
//           child: Column(
//             children: [
//               ListTile(
//                 contentPadding: EdgeInsets.zero,
//                 leading: Icon(Icons.shield_outlined),
//                 title: Text('Multi-factor authentication'),
//                 trailing: Chip2('Enabled'),
//               ),
//               ListTile(
//                 contentPadding: EdgeInsets.zero,
//                 leading: Icon(Icons.history),
//                 title: Text('Audit log'),
//                 subtitle: Text('Last login: Oct 4, 2026 • 8:41 AM'),
//                 trailing: Icon(Icons.chevron_right),
//               ),
//               ListTile(
//                 contentPadding: EdgeInsets.zero,
//                 leading: Icon(Icons.backup_outlined),
//                 title: Text('Data backups'),
//                 subtitle: Text('Daily • Last backup 3:00 AM'),
//                 trailing: Chip2('Healthy'),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
// }
