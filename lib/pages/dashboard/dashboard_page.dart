import 'package:admin_twinhandymans_llc/old/models/job.dart';
import 'package:admin_twinhandymans_llc/old/pages/jobs/jobs_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/app_controller.dart';
import '../../core/core.dart';
import '../../widgets/widgets.dart';
import '../jobs/jobs_page.dart';
import '../quotes/quote_builder.dart';
import '../requests/requests_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Get.find<AppController>();
    return Obx(() {
      final today = c.jobsOn(DateTime(2026, 10, 4));
      final pending = c.quotes.where((q) => q.status == 'Sent').length;
      final approved = c.quotes.where((q) => q.status == 'Approved').length;
      final maxRev = c.monthlyRevenue.values.reduce((a, b) => a > b ? a : b);
      return PageScaffold(
        title: 'Business Overview',
        subtitle: 'Sunday, Oct 4, 2026 • Welcome back, Mathew',
        actions: [
          OutlinedButton.icon(
            onPressed: () => c.page.value = 2,
            icon: const Icon(Icons.inbox),
            label: const Text('Quote Requests'),
          ),
          ElevatedButton.icon(
            onPressed: () => openQuoteBuilder(context),
            icon: const Icon(Icons.add),
            label: const Text('NEW QUOTE'),
          ),
        ],
        children: [
          Grid(
            minWidth: 250,
            children: [
              Stat(
                "Today's Jobs",
                '${today.length}',
                Icons.construction,
                onTap: () => c.page.value = 4,
              ),
              Stat(
                'Pending Quotes',
                '$pending',
                Icons.hourglass_bottom,
                color: C.orange,
                onTap: () => c.page.value = 3,
              ),
              Stat(
                'Approved Quotes',
                '$approved',
                Icons.check_circle_outline,
                color: C.green,
                onTap: () => c.page.value = 3,
              ),
              Stat(
                'Outstanding Invoices',
                money(c.outstanding),
                Icons.receipt_long,
                color: C.red,
                onTap: () => c.page.value = 6,
              ),
              Stat(
                'Monthly Revenue',
                money(12420),
                Icons.trending_up,
                color: C.green,
                hint: '+8.4% vs last month',
              ),
              Stat(
                'Payments Received',
                money(c.collected),
                Icons.payments,
                color: C.blue,
                onTap: () => c.page.value = 7,
              ),
              Stat(
                'New Customers',
                '6',
                Icons.person_add_alt,
                hint: 'This month',
              ),
              Stat(
                'Reviews',
                '${c.avgRating.toStringAsFixed(1)} ★',
                Icons.star,
                color: C.yellow,
                hint: '${c.reviews.length} reviews',
                onTap: () => c.page.value = 10,
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, box) {
              final two = box.maxWidth >= 900;
              final left = Column(
                children: [
                  Panel(
                    title: 'Revenue (last 6 months)',
                    child: SizedBox(
                      height: 220,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (final e in c.monthlyRevenue.entries)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      '\$${(e.value / 1000).toStringAsFixed(1)}k',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      height: 150 * e.value / maxRev,
                                      color: e.key == 'Oct' ? C.yellow : C.navy,
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
                  ),
                  const SizedBox(height: 16),
                  Panel(
                    title: "Today's Jobs",
                    trailing: TextButton(
                      onPressed: () => c.page.value = 5,
                      child: const Text('Open calendar'),
                    ),
                    child: Column(
                      children: [
                        for (final j in today)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 64,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              color: C.navy,
                              child: Text(
                                j.time,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: C.yellow,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            title: Text(
                              '${j.service} • ${j.customer}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text('${j.address}\n${j.crew}'),
                            isThreeLine: true,
                            trailing: Chip2(jobStages[j.stage]),
                            onTap: () => openJob(context, j as Job),
                          ),
                      ],
                    ),
                  ),
                ],
              );
              final right = Column(
                children: [
                  Panel(
                    title: 'Job Pipeline',
                    child: Column(
                      children: [
                        for (final g in [
                          [
                            'Quote Requests',
                            c.requests
                                .where(
                                  (r) =>
                                      r.status == 'New' ||
                                      r.status == 'In Review',
                                )
                                .length,
                            C.orange,
                          ],
                          ['Quotes Sent', pending, C.blue],
                          [
                            'Awaiting Deposit',
                            c.quotes
                                .where((q) => q.status == 'Approved')
                                .length,
                            C.yellow,
                          ],
                          [
                            'Scheduled',
                            c.jobs
                                .where((j) => j.stage >= 4 && j.stage < 6)
                                .length,
                            C.navy,
                          ],
                          [
                            'In Progress',
                            c.jobs
                                .where((j) => j.stage >= 6 && j.stage < 8)
                                .length,
                            C.green,
                          ],
                          [
                            'Final Payment Due',
                            c.jobs
                                .where((j) => j.stage >= 8 && j.stage < 10)
                                .length,
                            C.red,
                          ],
                        ])
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  color: g[2] as Color,
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: Text(g[0] as String)),
                                Text(
                                  '${g[1]}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Panel(
                    title: 'New Quote Requests',
                    trailing: TextButton(
                      onPressed: () => c.page.value = 2,
                      child: const Text('View all'),
                    ),
                    child: Column(
                      children: [
                        for (final r
                            in c.requests
                                .where((r) => r.status == 'New')
                                .take(3))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '${r.service} • ${r.customer}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              'Budget ${money(r.budget)} • ${fmtDate(r.date)}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => RequestsPage(),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Panel(
                    title: 'Recent Payments',
                    child: Column(
                      children: [
                        for (final p in c.payments.take(4))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              p.customer,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text('${p.method} • ${fmtDate(p.date)}'),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  money(p.amount),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Chip2(p.status),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
              return two
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: left),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: right),
                      ],
                    )
                  : Column(children: [left, const SizedBox(height: 16), right]);
            },
          ),
        ],
      );
    });
  }
}
