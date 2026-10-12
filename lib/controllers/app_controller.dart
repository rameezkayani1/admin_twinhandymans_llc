import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/core.dart';
import '../models/models.dart';

// Controller (demo data only)
class AppController extends GetxController {
  final page = 0.obs;
  final custSearch = ''.obs;
  final reqFilter = 'All'.obs;
  final quoteFilter = 'All'.obs;
  final jobFilter = 'All'.obs;
  final invFilter = 'All'.obs;
  final selectedThread = 0.obs;
  final calMonth = DateTime(2026, 10, 1).obs;
  final selectedDay = DateTime(2026, 10, 4).obs;

  // settings
  final defaultDeposit = 75.0.obs;
  final defaultTax = 6.625.obs;
  final pushNewRequest = true.obs;
  final emailNewRequest = true.obs;
  final pushPayments = true.obs;
  final pushMessages = true.obs;
  final zelleEnabled = true.obs;

  static final _d = (int m, int d) => DateTime(2026, m, d);

  final customers = <Customer>[
    Customer(
      'Sarah Johnson',
      '(908) 555-0142',
      'sarah.j@email.com',
      '45 Maple Ave, Summit, NJ',
      4,
      3850,
      notes: 'Prefers text messages. Gate code 4417.',
      properties: ['45 Maple Ave, Summit, NJ', '12 Oak St, Summit, NJ'],
    ),
    Customer(
      'Michael Brown',
      '(973) 555-0198',
      'm.brown@email.com',
      '210 Broad St, Newark, NJ',
      2,
      1900,
      properties: ['210 Broad St, Newark, NJ'],
    ),
    Customer(
      'Elm Street Property Mgmt',
      '(201) 555-0111',
      'ops@elmstreetpm.com',
      '88 Elm St, Jersey City, NJ',
      9,
      14250,
      notes: 'Commercial property manager. Net-15 terms.',
      properties: [
        '88 Elm St, Jersey City, NJ',
        '90 Elm St, Jersey City, NJ',
        '14 River Rd, Hoboken, NJ',
      ],
    ),
    Customer(
      'Priya Patel',
      '(718) 555-0170',
      'priya.p@email.com',
      '34 Victory Blvd, Staten Island, NY',
      1,
      400,
      properties: ['34 Victory Blvd, Staten Island, NY'],
    ),
    Customer(
      'David Okafor',
      '(908) 555-0123',
      'david.o@email.com',
      '17 Chestnut Ave, Elizabeth, NJ',
      3,
      2100,
      properties: ['17 Chestnut Ave, Elizabeth, NJ'],
    ),
    Customer(
      'Linda Martinez',
      '(862) 555-0160',
      'linda.m@email.com',
      '9 Hillside Dr, Union, NJ',
      5,
      4620,
      properties: ['9 Hillside Dr, Union, NJ'],
    ),
    Customer(
      'Hillside Township',
      '(973) 555-0100',
      'procurement@hillsidenj.gov',
      '1409 Liberty Ave, Hillside, NJ',
      2,
      8900,
      notes: 'Government account. PO required.',
      properties: ['1409 Liberty Ave, Hillside, NJ'],
    ),
  ].obs;

  final requests = <QuoteRequest>[
    QuoteRequest(
      'QR-1042',
      'Sarah Johnson',
      '(908) 555-0142',
      'sarah.j@email.com',
      'Painting',
      'Repaint living room, hallway and two bedrooms. Walls have minor cracks.',
      '45 Maple Ave, Summit, NJ',
      _d(10, 12),
      'Morning',
      1800,
      8,
      1,
      'New',
    ),
    QuoteRequest(
      'QR-1041',
      'Priya Patel',
      '(718) 555-0170',
      'priya.p@email.com',
      'Pressure Washing',
      'Driveway and back patio, approx 900 sq ft.',
      '34 Victory Blvd, Staten Island, NY',
      _d(10, 10),
      'Afternoon',
      450,
      4,
      0,
      'New',
    ),
    QuoteRequest(
      'QR-1040',
      'David Okafor',
      '(908) 555-0123',
      'david.o@email.com',
      'Assembly',
      'Assemble 3 wardrobes and a bunk bed.',
      '17 Chestnut Ave, Elizabeth, NJ',
      _d(10, 9),
      'Evening',
      300,
      6,
      0,
      'In Review',
    ),
    QuoteRequest(
      'QR-1039',
      'Elm Street Property Mgmt',
      '(201) 555-0111',
      'ops@elmstreetpm.com',
      'Cleaning',
      'Weekly commercial cleaning of 2 office floors.',
      '88 Elm St, Jersey City, NJ',
      _d(10, 8),
      'Evening',
      1200,
      2,
      0,
      'In Review',
    ),
    QuoteRequest(
      'QR-1038',
      'Linda Martinez',
      '(862) 555-0160',
      'linda.m@email.com',
      'Waste Disposal',
      'Garage cleanout - old furniture and boxes.',
      '9 Hillside Dr, Union, NJ',
      _d(10, 6),
      'Morning',
      500,
      5,
      1,
      'Quoted',
    ),
    QuoteRequest(
      'QR-1037',
      'Michael Brown',
      '(973) 555-0198',
      'm.brown@email.com',
      'Moving',
      '2-bedroom apartment move, 3rd floor, no elevator.',
      '210 Broad St, Newark, NJ',
      _d(10, 5),
      'Morning',
      950,
      3,
      0,
      'Quoted',
    ),
  ].obs;

  final quotes = <Quote>[
    Quote(
      'Q-2031',
      'Linda Martinez',
      'Waste Disposal',
      'Sent',
      280,
      0,
      40,
      150,
      30,
      0,
      6.625,
      50,
      _d(10, 20),
    ),
    Quote(
      'Q-2030',
      'Michael Brown',
      'Moving',
      'Sent',
      800,
      40,
      0,
      0,
      60,
      50,
      6.625,
      50,
      _d(10, 18),
    ),
    Quote(
      'Q-2029',
      'Sarah Johnson',
      'Painting',
      'Approved',
      900,
      520,
      80,
      40,
      110,
      0,
      0,
      75,
      _d(10, 15),
    ),
    Quote(
      'Q-2028',
      'Hillside Township',
      'General Handyman',
      'Approved',
      2600,
      900,
      150,
      0,
      150,
      0,
      0,
      50,
      _d(10, 14),
    ),
    Quote(
      'Q-2027',
      'David Okafor',
      'Assembly',
      'Changes Requested',
      260,
      0,
      0,
      0,
      40,
      0,
      6.625,
      25,
      _d(10, 12),
    ),
    Quote(
      'Q-2026',
      'Priya Patel',
      'Pressure Washing',
      'Declined',
      350,
      30,
      60,
      0,
      40,
      0,
      6.625,
      50,
      _d(10, 3),
    ),
  ].obs;

  final jobs = <Job>[
    Job(
      'J-3012',
      'Sarah Johnson',
      'Painting',
      '45 Maple Ave, Summit, NJ',
      _d(10, 4),
      '9:00 AM',
      '2 days',
      'Crew A',
      7,
      1650,
      before: 6,
    ),
    Job(
      'J-3011',
      'Hillside Township',
      'General Handyman',
      '1409 Liberty Ave, Hillside, NJ',
      _d(10, 4),
      '11:00 AM',
      '1 day',
      'Crew B',
      6,
      4800,
    ),
    Job(
      'J-3010',
      'Elm Street Property Mgmt',
      'Cleaning',
      '88 Elm St, Jersey City, NJ',
      _d(10, 4),
      '6:00 PM',
      '4 hrs',
      'Crew C',
      5,
      1200,
    ),
    Job(
      'J-3009',
      'Linda Martinez',
      'Lawn Services',
      '9 Hillside Dr, Union, NJ',
      _d(10, 4),
      '2:00 PM',
      '3 hrs',
      'Crew A',
      8,
      250,
      before: 3,
      after: 3,
    ),
    Job(
      'J-3008',
      'Michael Brown',
      'Moving',
      '210 Broad St, Newark, NJ',
      _d(10, 7),
      '8:00 AM',
      '6 hrs',
      'Crew B',
      4,
      950,
    ),
    Job(
      'J-3007',
      'David Okafor',
      'Assembly',
      '17 Chestnut Ave, Elizabeth, NJ',
      _d(10, 9),
      '5:00 PM',
      '3 hrs',
      'Unassigned',
      3,
      300,
    ),
    Job(
      'J-3006',
      'Priya Patel',
      'Pressure Washing',
      '34 Victory Blvd, Staten Island, NY',
      _d(10, 14),
      '10:00 AM',
      '4 hrs',
      'Crew C',
      4,
      400,
    ),
    Job(
      'J-3005',
      'Linda Martinez',
      'Waste Disposal',
      '9 Hillside Dr, Union, NJ',
      _d(9, 28),
      '9:00 AM',
      '3 hrs',
      'Crew A',
      11,
      620,
      before: 4,
      after: 4,
    ),
    Job(
      'J-3004',
      'Sarah Johnson',
      'Cleaning',
      '12 Oak St, Summit, NJ',
      _d(10, 22),
      '1:00 PM',
      '5 hrs',
      'Crew C',
      2,
      520,
    ),
  ].obs;

  final invoices = <Invoice>[
    Invoice(
      'TH-2026-0052',
      'J-3012',
      'Sarah Johnson',
      1650,
      1237.50,
      _d(10, 8),
      'Partial',
      'Apple Pay',
    ),
    Invoice(
      'TH-2026-0051',
      'J-3011',
      'Hillside Township',
      4800,
      2400,
      _d(10, 12),
      'Partial',
      'ACH',
    ),
    Invoice(
      'TH-2026-0050',
      'J-3010',
      'Elm Street Property Mgmt',
      1200,
      0,
      _d(10, 3),
      'Overdue',
      '-',
    ),
    Invoice(
      'TH-2026-0049',
      'J-3009',
      'Linda Martinez',
      250,
      250,
      _d(10, 4),
      'Paid',
      'Card',
    ),
    Invoice(
      'TH-2026-0048',
      'J-3005',
      'Linda Martinez',
      620,
      620,
      _d(9, 28),
      'Paid',
      'Zelle',
    ),
    Invoice(
      'TH-2026-0047',
      'J-3008',
      'Michael Brown',
      950,
      0,
      _d(10, 15),
      'Unpaid',
      '-',
    ),
    Invoice(
      'TH-2026-0046',
      'J-3006',
      'Priya Patel',
      400,
      200,
      _d(10, 14),
      'Partial',
      'Awaiting Zelle',
    ),
  ].obs;

  final payments = <Payment>[
    Payment(
      'PAY-9021',
      'TH-2026-0052',
      'Sarah Johnson',
      1237.50,
      'Apple Pay',
      _d(10, 2),
      'Paid',
      36.34,
    ),
    Payment(
      'PAY-9020',
      'TH-2026-0051',
      'Hillside Township',
      2400,
      'ACH',
      _d(10, 1),
      'Paid',
      5.00,
    ),
    Payment(
      'PAY-9019',
      'TH-2026-0049',
      'Linda Martinez',
      250,
      'Card',
      _d(10, 4),
      'Paid',
      7.55,
    ),
    Payment(
      'PAY-9018',
      'TH-2026-0046',
      'Priya Patel',
      200,
      'Zelle',
      _d(10, 3),
      'Awaiting Zelle',
      0,
    ),
    Payment(
      'PAY-9017',
      'TH-2026-0048',
      'Linda Martinez',
      620,
      'Zelle',
      _d(9, 28),
      'Paid',
      0,
    ),
    Payment(
      'PAY-9016',
      'TH-2026-0045',
      'David Okafor',
      150,
      'Card',
      _d(9, 26),
      'Failed',
      0,
    ),
    Payment(
      'PAY-9015',
      'TH-2026-0044',
      'Michael Brown',
      300,
      'Card',
      _d(9, 24),
      'Refunded',
      0,
    ),
  ].obs;

  final threads = <Thread>[
    Thread('Sarah Johnson', 'J-3012 Painting', 2, [
      Msg('Hi! Will the crew be here at 9 tomorrow?', false, '9:02 AM'),
      Msg('Yes, Crew A arrives at 9:00 AM sharp.', true, '9:10 AM'),
      Msg(
        'Great, could you also touch up the hallway ceiling?',
        false,
        '9:14 AM',
      ),
    ]),
    Thread('Hillside Township', 'J-3011 Handyman', 0, [
      Msg('PO number has been uploaded to the job.', false, 'Yesterday'),
      Msg('Received, thank you. Work starts Oct 4.', true, 'Yesterday'),
    ]),
    Thread('Priya Patel', 'J-3006 Pressure Washing', 1, [
      Msg(
        'I sent the deposit via Zelle. Confirmation attached.',
        false,
        'Oct 3',
      ),
    ]),
    Thread('Michael Brown', 'Q-2030 Moving', 0, [
      Msg('Is the 50% deposit required before booking?', false, 'Oct 2'),
      Msg(
        'Yes, once you approve the quote you can pay the deposit in the app.',
        true,
        'Oct 2',
      ),
    ]),
  ].obs;

  final documents = <DocItem>[
    DocItem('Capability Statement', 'PDF', 'Public', 'Sep 12, 2026'),
    DocItem('Organizational Chart', 'PDF', 'Public', 'Aug 30, 2026'),
    DocItem('Certificate of Insurance', 'PDF', 'Private', 'Sep 01, 2026'),
    DocItem('MBE Certification', 'PDF', 'Public', 'Jul 18, 2026'),
    DocItem('SBE Certification', 'PDF', 'Public', 'Jul 18, 2026'),
    DocItem(
      'Business Registration Certificate',
      'PDF',
      'Private',
      'Jan 10, 2026',
    ),
    DocItem('Standard Terms & Conditions', 'PDF', 'Public', 'Jun 05, 2026'),
  ].obs;

  final reviews = <Review>[
    Review(
      'Linda Martinez',
      'Waste Disposal',
      5,
      'Fast, professional and left everything spotless. Highly recommend!',
      'Sep 29',
      true,
    ),
    Review(
      'Sarah Johnson',
      'Cleaning',
      5,
      'Great communication and the before/after photos were a nice touch.',
      'Sep 25',
      false,
    ),
    Review(
      'Michael Brown',
      'Moving',
      4,
      'Crew was on time and careful. Slight delay on arrival.',
      'Sep 20',
      true,
    ),
    Review(
      'David Okafor',
      'Assembly',
      5,
      'Assembled everything quickly. Will book again.',
      'Sep 15',
      false,
    ),
    Review(
      'Elm Street Property Mgmt',
      'Cleaning',
      4,
      'Reliable weekly service for our offices.',
      'Sep 10',
      true,
    ),
  ].obs;

  final staff = <StaffUser>[
    StaffUser('Mathew Ihemesie', 'mathew@twinshandymanllc.com', 'Owner', true),
    StaffUser('Deacon Obanor', 'deacon@twinshandymanllc.com', 'Owner', true),
    StaffUser('Grace Williams', 'grace@twinshandymanllc.com', 'Manager', true),
    StaffUser('Carlos Rivera', 'carlos@twinshandymanllc.com', 'Crew', true),
    StaffUser('Tyrone Davis', 'tyrone@twinshandymanllc.com', 'Crew', true),
    StaffUser('Ana Costa', 'ana@twinshandymanllc.com', 'Crew', false),
  ].obs;

  final notifications = <AppNotif>[
    AppNotif(
      'New quote request',
      'Sarah Johnson requested a Painting quote',
      '5 min ago',
      Icons.request_quote,
      true,
    ),
    AppNotif(
      'Payment received',
      'Linda Martinez paid \$250.00 (Card)',
      '2 hrs ago',
      Icons.payments,
      true,
    ),
    AppNotif(
      'New message',
      'Priya Patel sent a message',
      '3 hrs ago',
      Icons.chat_bubble,
      true,
    ),
    AppNotif(
      'Quote approved',
      'Hillside Township approved Q-2028',
      'Yesterday',
      Icons.check_circle,
      false,
    ),
    AppNotif(
      'Failed payment',
      'David Okafor card payment failed',
      'Sep 26',
      Icons.error,
      false,
    ),
  ].obs;

  final monthlyRevenue = const {
    'May': 8200.0,
    'Jun': 9600.0,
    'Jul': 10400.0,
    'Aug': 11800.0,
    'Sep': 13100.0,
    'Oct': 12420.0,
  };
  final serviceRevenue = const {
    'Painting': 14800.0,
    'Handyman': 12400.0,
    'Cleaning': 9600.0,
    'Moving': 7300.0,
    'Lawn': 4200.0,
    'Pressure Wash': 3900.0,
    'Waste': 3100.0,
  };

  // computed
  double get outstanding => invoices.fold(0.0, (s, i) => s + i.balance);
  double get collected => payments
      .where((p) => p.status == 'Paid')
      .fold(0.0, (s, p) => s + p.amount);
  double get fees => payments.fold(0.0, (s, p) => s + p.fee);
  int get unreadNotifs => notifications.where((n) => n.unread).length;
  double get avgRating => reviews.isEmpty
      ? 0
      : reviews.fold(0, (s, r) => s + r.stars) / reviews.length;
  List<Job> jobsOn(DateTime d) => jobs
      .where(
        (j) =>
            j.date.year == d.year &&
            j.date.month == d.month &&
            j.date.day == d.day,
      )
      .toList();

  void snack(String m) => Get.snackbar(
    '',
    m,
    titleText: const SizedBox.shrink(),
    margin: const EdgeInsets.all(16),
    backgroundColor: C.navy,
    colorText: Colors.white,
    borderRadius: 0,
    maxWidth: 420,
    duration: const Duration(seconds: 2),
    snackPosition: SnackPosition.BOTTOM,
  );

  void addQuote(Quote q, {String? requestId}) {
    quotes.insert(0, q);
    if (requestId != null) {
      final r = requests.firstWhereOrNull((e) => e.id == requestId);
      if (r != null) r.status = 'Quoted';
      requests.refresh();
    }
    snack('Quote ${q.id} sent to ${q.customer}');
  }

  void setJobStage(Job j, int s) {
    j.stage = s;
    jobs.refresh();
    snack('${j.id} updated to ${jobStages[s]}');
  }

  void markInvoicePaid(Invoice i, String method) {
    payments.insert(
      0,
      Payment(
        'PAY-${9022 + payments.length}',
        i.id,
        i.customer,
        i.balance,
        method,
        DateTime(2026, 10, 4),
        'Paid',
        0,
      ),
    );
    i.paid = i.total;
    i.status = 'Paid';
    i.method = method;
    invoices.refresh();
    snack('${i.id} marked as paid via $method');
  }

  void verifyZelle(Payment p) {
    p.status = 'Paid';
    payments.refresh();
    snack('Zelle payment ${p.id} verified');
  }

  void refund(Payment p) {
    p.status = 'Refunded';
    payments.refresh();
    snack('${money(p.amount)} refunded to ${p.customer}');
  }

  void sendMessage(int t, String text) {
    if (text.trim().isEmpty) return;
    threads[t].msgs.add(Msg(text.trim(), true, 'Now'));
    threads[t].unread = 0;
    threads.refresh();
  }

  void addCustomer(Customer c) {
    customers.insert(0, c);
    snack('Customer ${c.name} added');
  }

  void toggleUser(StaffUser u, bool v) {
    u.active = v;
    staff.refresh();
  }

  void changeRole(StaffUser u, String r) {
    u.role = r;
    staff.refresh();
  }

  void addStaff(StaffUser u) {
    staff.add(u);
    snack('Invitation sent to ${u.email}');
  }

  void markAllRead() {
    for (final n in notifications) {
      n.unread = false;
    }
    notifications.refresh();
  }
}
