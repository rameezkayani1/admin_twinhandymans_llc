import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/app_controller.dart';
import '../../core/core.dart';
import '../../widgets/widgets.dart';
import '../jobs/jobs_page.dart';

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Get.find<AppController>();
    return PageScaffold(
      title: 'Calendar & Scheduling',
      subtitle: 'Customers request dates — you control the final schedule',
      children: [
        Obx(() {
          final m = c.calMonth.value;
          final first = DateTime(m.year, m.month, 1);
          final days = DateTime(m.year, m.month + 1, 0).day;
          final offset = first.weekday % 7;
          final cells = <Widget>[
            for (final d in ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'])
              Center(
                child: Text(
                  d,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: C.muted,
                    fontSize: 12,
                  ),
                ),
              ),
            for (int i = 0; i < offset; i++) const SizedBox(),
            for (int d = 1; d <= days; d++)
              Builder(
                builder: (_) {
                  final date = DateTime(m.year, m.month, d);
                  final js = c.jobsOn(date);
                  final sel = c.selectedDay.value == date;
                  return InkWell(
                    onTap: () => c.selectedDay.value = date,
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: sel ? C.navy : Colors.white,
                        border: Border.all(color: sel ? C.navy : C.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$d',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: sel ? Colors.white : C.text,
                            ),
                          ),
                          const Spacer(),
                          if (js.isNotEmpty)
                            Row(
                              children: [
                                for (int i = 0; i < js.length && i < 4; i++)
                                  Container(
                                    width: 7,
                                    height: 7,
                                    margin: const EdgeInsets.only(right: 3),
                                    color: sel ? C.yellow : C.navy,
                                  ),
                              ],
                            ),
                          if (js.isNotEmpty)
                            Text(
                              '${js.length} job${js.length > 1 ? 's' : ''}',
                              style: TextStyle(
                                fontSize: 10,
                                color: sel ? C.yellow : C.muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ];
          final grid = Panel(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () =>
                          c.calMonth.value = DateTime(m.year, m.month - 1, 1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '${kMonths[m.month - 1]} ${m.year}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          c.calMonth.value = DateTime(m.year, m.month + 1, 1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                LayoutBuilder(
                  builder: (context, box) {
                    final cellH = box.maxWidth < 500 ? 56.0 : 82.0;
                    return GridView.count(
                      crossAxisCount: 7,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: (box.maxWidth / 7) / cellH,
                      children: cells,
                    );
                  },
                ),
              ],
            ),
          );
          final sel = c.selectedDay.value;
          final dayJobs = c.jobsOn(sel);
          final side = Panel(
            title: fmtDate(sel),
            child: dayJobs.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'No jobs scheduled',
                        style: TextStyle(color: C.muted),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (final j in dayJobs)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            border: Border(
                              left: BorderSide(color: C.yellow, width: 4),
                            ),
                            color: Color(0xFFFAFBFC),
                          ),
                          child: InkWell(
                            onTap: () => openJob(context, j),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${j.time} • ${j.service}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(j.customer),
                                Text(
                                  j.address,
                                  style: const TextStyle(
                                    color: C.muted,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    Chip2(jobStages[j.stage]),
                                    Chip2(j.crew, color: C.navy),
                                    Chip2(j.duration, color: C.muted),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          );
          return LayoutBuilder(
            builder: (context, box) {
              if (box.maxWidth >= 900) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: grid),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: side),
                  ],
                );
              }
              return Column(children: [grid, const SizedBox(height: 16), side]);
            },
          );
        }),
      ],
    );
  }
}
