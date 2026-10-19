import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/app_controller.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';
import '../quotes/quote_builder.dart';

class RequestsPage extends StatelessWidget {
  const RequestsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Get.find<AppController>();
    return PageScaffold(
      title: 'Quote Requests',
      subtitle: 'Requests submitted from the mobile app and website',
      children: [
        FilterBar(const ['All', 'New', 'In Review', 'Quoted'], c.reqFilter),
        const SizedBox(height: 14),
        Obx(() {
          final f = c.reqFilter.value;
          final list = c.requests
              .where((r) => f == 'All' || r.status == f)
              .toList();
          return ResponsiveTable(
            headers: const [
              'Request',
              'Service',
              'Preferred Date',
              'Budget',
              'Media',
              'Status',
            ],
            rows: [
              for (final r in list)
                [
                  sub(r.customer, r.id),
                  plain(r.service),
                  plain('${fmtDate(r.date)} • ${r.time}'),
                  bold(money(r.budget)),
                  plain('${r.photos} photos, ${r.videos} video'),
                  Chip2(r.status),
                ],
            ],
            onTap: (i) => openRequest(context, list[i]),
          );
        }),
      ],
    );
  }
}

void openRequest(BuildContext context, QuoteRequest r) {
  final c = Get.find<AppController>();
  showDetail(
    context,
    title: '${r.id} • ${r.service}',
    actions: [
      OutlinedButton(
        onPressed: () {
          r.status = 'In Review';
          c.requests.refresh();
          Navigator.pop(context);
        },
        child: const Text('Mark In Review'),
      ),
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
          openQuoteBuilder(context, request: r);
        },
        icon: const Icon(Icons.request_quote),
        label: const Text('CREATE QUOTE'),
      ),
    ],
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Chip2(r.status),
            const Spacer(),
            Text(
              'Budget ${money(r.budget)}',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 14),
        KV('Customer', r.customer),
        KV('Phone', r.phone),
        KV('Email', r.email),
        KV('Address', r.address),
        KV('Preferred', '${fmtDate(r.date)} • ${r.time}'),
        const Divider(height: 26),
        const Text(
          'Description of work',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(r.description),
        const SizedBox(height: 18),
        Text(
          'Uploads (${r.photos} photos, ${r.videos} video)',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (int i = 0; i < r.photos; i++)
              Container(
                width: 78,
                height: 78,
                color: C.line,
                child: const Icon(Icons.image, color: C.muted),
              ),
            for (int i = 0; i < r.videos; i++)
              Container(
                width: 78,
                height: 78,
                color: C.navy,
                child: const Icon(Icons.play_circle, color: C.yellow),
              ),
          ],
        ),
      ],
    ),
  );
}
