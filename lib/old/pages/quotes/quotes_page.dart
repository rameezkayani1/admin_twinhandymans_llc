import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/app_controller.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';
import 'quote_builder.dart';

class QuotesPage extends StatelessWidget {
  const QuotesPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Get.find<AppController>();
    return PageScaffold(
      title: 'Quotes',
      subtitle: 'Create, send and track customer quotes',
      actions: [
        ElevatedButton.icon(
          onPressed: () => openQuoteBuilder(context),
          icon: const Icon(Icons.add),
          label: const Text('NEW QUOTE'),
        ),
      ],
      children: [
        FilterBar(const [
          'All',
          'Sent',
          'Approved',
          'Changes Requested',
          'Declined',
        ], c.quoteFilter),
        const SizedBox(height: 14),
        Obx(() {
          final f = c.quoteFilter.value;
          final list = c.quotes
              .where((q) => f == 'All' || q.status == f)
              .toList();
          return ResponsiveTable(
            headers: const [
              'Quote',
              'Service',
              'Total',
              'Deposit',
              'Balance',
              'Expires',
              'Status',
            ],
            rows: [
              for (final q in list)
                [
                  sub(q.customer, q.id),
                  plain(q.service),
                  bold(money(q.total)),
                  plain(
                    '${money(q.deposit)} (${q.depositPct.toStringAsFixed(0)}%)',
                  ),
                  plain(money(q.balance)),
                  plain(fmtDate(q.expires)),
                  Chip2(q.status),
                ],
            ],
            onTap: (i) => openQuote(context, list[i]),
          );
        }),
      ],
    );
  }
}

void openQuote(BuildContext context, Quote q) {
  showDetail(
    context,
    title: '${q.id} • ${q.service}',
    actions: [
      OutlinedButton.icon(
        onPressed: () =>
            Get.find<AppController>().snack('Quote PDF downloaded'),
        icon: const Icon(Icons.download),
        label: const Text('PDF'),
      ),
      if (q.status == 'Changes Requested' || q.status == 'Sent')
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            openQuoteBuilder(context, customer: q.customer);
          },
          child: const Text('REVISE QUOTE'),
        ),
    ],
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Chip2(q.status),
            const Spacer(),
            Text(
              'Expires ${fmtDate(q.expires)}',
              style: const TextStyle(color: C.muted),
            ),
          ],
        ),
        const SizedBox(height: 14),
        KV('Customer', q.customer),
        const Divider(height: 24),
        totalsView(q),
      ],
    ),
  );
}
