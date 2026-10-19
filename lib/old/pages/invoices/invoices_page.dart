import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/app_controller.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

class InvoicesPage extends StatelessWidget {
  const InvoicesPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Get.find<AppController>();
    return PageScaffold(
      title: 'Invoices',
      subtitle: 'Auto-generated from approved quotes',
      actions: [
        OutlinedButton.icon(
          onPressed: () => c.snack('Invoices exported (demo)'),
          icon: const Icon(Icons.file_download),
          label: const Text('Export'),
        ),
      ],
      children: [
        Obx(
          () => Grid(
            minWidth: 220,
            children: [
              Stat(
                'Total Invoiced',
                money(c.invoices.fold(0.0, (s, i) => s + i.total)),
                Icons.receipt_long,
              ),
              Stat(
                'Collected',
                money(c.invoices.fold(0.0, (s, i) => s + i.paid)),
                Icons.check_circle,
                color: C.green,
              ),
              Stat(
                'Outstanding',
                money(c.outstanding),
                Icons.pending_actions,
                color: C.red,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilterBar(const [
          'All',
          'Paid',
          'Partial',
          'Unpaid',
          'Overdue',
        ], c.invFilter),
        const SizedBox(height: 14),
        Obx(() {
          final f = c.invFilter.value;
          final list = c.invoices
              .where((i) => f == 'All' || i.status == f)
              .toList();
          return ResponsiveTable(
            headers: const [
              'Invoice',
              'Job',
              'Total',
              'Paid',
              'Balance',
              'Due',
              'Status',
            ],
            rows: [
              for (final i in list)
                [
                  sub(i.id, i.customer),
                  plain(i.job),
                  bold(money(i.total)),
                  plain(money(i.paid)),
                  plain(money(i.balance)),
                  plain(fmtDate(i.due)),
                  Chip2(i.status),
                ],
            ],
            onTap: (k) => openInvoice(context, list[k]),
          );
        }),
      ],
    );
  }
}

void openInvoice(BuildContext context, Invoice i) {
  final c = Get.find<AppController>();
  showDetail(
    context,
    title: 'Invoice ${i.id}',
    actions: [
      OutlinedButton.icon(
        onPressed: () => c.snack('Invoice PDF downloaded'),
        icon: const Icon(Icons.download),
        label: const Text('PDF'),
      ),
      OutlinedButton.icon(
        onPressed: () => c.snack('Reminder sent to ${i.customer}'),
        icon: const Icon(Icons.notifications_active),
        label: const Text('Send reminder'),
      ),
      if (i.balance > 0)
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            final m = await showDialog<String>(
              context: context,
              builder: (_) => SimpleDialog(
                title: const Text('Mark as paid via...'),
                children: [
                  for (final e in ['Zelle', 'Cash', 'Check', 'Card'])
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(context, e),
                      child: Text(e),
                    ),
                ],
              ),
            );
            if (m != null) c.markInvoicePaid(i, m);
          },
          child: const Text('MARK PAID'),
        ),
    ],
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [const Logo(small: true), const Spacer(), Chip2(i.status)],
        ),
        const SizedBox(height: 6),
        const Text(
          '1156 Liberty Avenue, Hillside, NJ 07205',
          style: TextStyle(color: C.muted, fontSize: 12),
        ),
        const Divider(height: 28),
        KV('Bill to', i.customer),
        KV('Job', i.job),
        KV('Due date', fmtDate(i.due)),
        KV('Payment method', i.method),
        const Divider(height: 28),
        KV('Total', money(i.total), boldV: true),
        KV('Deposit / paid', money(i.paid)),
        KV('Balance due', money(i.balance), boldV: true),
        const SizedBox(height: 10),
        const Text(
          'Terms: Balance due upon completion. Thank you for your business!',
          style: TextStyle(color: C.muted, fontSize: 12),
        ),
      ],
    ),
  );
}
