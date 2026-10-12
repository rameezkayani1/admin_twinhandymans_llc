import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/app_controller.dart';
import '../../core/core.dart';
import '../../widgets/widgets.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Get.find<AppController>();
    final maxS = c.serviceRevenue.values.reduce((a, b) => a > b ? a : b);
    final maxM = c.monthlyRevenue.values.reduce((a, b) => a > b ? a : b);
    return PageScaffold(
      title: 'Reports',
      subtitle: 'Business performance • exportable',
      actions: [
        OutlinedButton.icon(
          onPressed: () => c.snack('Exported to CSV'),
          icon: const Icon(Icons.table_chart),
          label: const Text('CSV'),
        ),
        OutlinedButton.icon(
          onPressed: () => c.snack('Exported to PDF'),
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('PDF'),
        ),
      ],
      children: [
        Grid(
          minWidth: 220,
          children: const [
            Stat(
              'Quote Conversion',
              '64%',
              Icons.swap_horiz,
              color: C.green,
              hint: '16 of 25 quotes approved',
            ),
            Stat(
              'Job Volume (Oct)',
              '28',
              Icons.construction,
              hint: '+4 vs Sep',
            ),
            Stat(
              'Recurring Revenue',
              '\$3,450',
              Icons.autorenew,
              color: C.blue,
              hint: 'Per month',
            ),
            Stat(
              'New Customers',
              '6',
              Icons.person_add_alt,
              color: C.orange,
              hint: 'Oct 2026',
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, box) {
            final a = Panel(
              title: 'Revenue by Service Type',
              child: Column(
                children: [
                  for (final e in c.serviceRevenue.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 100,
                            child: Text(
                              e.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (_, b) => Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  height: 18,
                                  width: b.maxWidth * e.value / maxS,
                                  color: C.navy,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: Text(
                              money(e.value).replaceAll('.00', ''),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
            final b = Panel(
              title: 'Monthly Revenue',
              child: SizedBox(
                height: 200,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final e in c.monthlyRevenue.entries)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                height: 140 * e.value / maxM,
                                color: C.yellow,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                e.key,
                                style: const TextStyle(
                                  color: C.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
            return box.maxWidth >= 900
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: a),
                      const SizedBox(width: 16),
                      Expanded(child: b),
                    ],
                  )
                : Column(children: [a, const SizedBox(height: 16), b]);
          },
        ),
        const SizedBox(height: 16),
        Panel(
          title: 'Payment Summary',
          child: Obx(
            () => Column(
              children: [
                const KV(
                  'Card / Apple Pay / Google Pay',
                  'Stripe • 2.9% + \$0.30',
                ),
                const KV('ACH', 'Stripe • 0.8% (max \$5)'),
                const KV('Zelle', 'No processing fee'),
                KV('Total fees paid', money(c.fees), boldV: true),
                KV('Outstanding invoices', money(c.outstanding), boldV: true),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
