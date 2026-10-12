import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/app_controller.dart';
import '../../core/core.dart';
import '../../widgets/widgets.dart';

class PaymentsPage extends StatelessWidget {
  const PaymentsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Get.find<AppController>();
    return PageScaffold(
      title: 'Payments',
      subtitle: 'Processed via Stripe • settled to business bank account',
      children: [
        Obx(
          () => Grid(
            minWidth: 220,
            children: [
              Stat(
                'Collected',
                money(c.collected),
                Icons.account_balance_wallet,
                color: C.green,
              ),
              Stat(
                'Processing Fees',
                money(c.fees),
                Icons.percent,
                color: C.orange,
              ),
              Stat(
                'Awaiting Zelle',
                '${c.payments.where((p) => p.status == 'Awaiting Zelle').length}',
                Icons.hourglass_top,
                color: C.blue,
              ),
              Stat(
                'Failed',
                '${c.payments.where((p) => p.status == 'Failed').length}',
                Icons.error_outline,
                color: C.red,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Obx(() {
          final list = c.payments.toList();
          return ResponsiveTable(
            headers: const [
              'Payment',
              'Invoice',
              'Amount',
              'Method',
              'Date',
              'Status',
              'Action',
            ],
            rows: [
              for (final p in list)
                [
                  sub(p.customer, p.id),
                  plain(p.invoice),
                  bold(money(p.amount)),
                  plain(p.method),
                  plain(fmtDate(p.date)),
                  Chip2(p.status),
                  if (p.status == 'Awaiting Zelle')
                    TextButton(
                      onPressed: () => c.verifyZelle(p),
                      child: const Text('Verify'),
                    )
                  else if (p.status == 'Paid')
                    TextButton(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Refund payment?'),
                          content: Text(
                            'Refund ${money(p.amount)} to ${p.customer}?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                c.refund(p);
                                Navigator.pop(context);
                              },
                              child: const Text(
                                'Refund',
                                style: TextStyle(color: C.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                      child: const Text('Refund'),
                    )
                  else if (p.status == 'Failed')
                    TextButton(
                      onPressed: () =>
                          c.snack('Retry link sent to ${p.customer}'),
                      child: const Text('Retry'),
                    )
                  else
                    const Text('-'),
                ],
            ],
          );
        }),
        const SizedBox(height: 16),
        Panel(
          title: 'Zelle Instructions (shown to customers)',
          child: Obx(
            () => Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: C.navy,
                  title: const Text('Enable "Pay with Zelle"'),
                  subtitle: const Text(
                    'Customer pays via their bank app, then you verify the payment manually.',
                  ),
                  value: c.zelleEnabled.value,
                  onChanged: (v) => c.zelleEnabled.value = v,
                ),
                if (c.zelleEnabled.value)
                  const KV('Zelle email', 'admin@twinshandymanllc.com'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
