import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/app_controller.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

class JobsPage extends StatelessWidget {
  const JobsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Get.find<AppController>();
    return PageScaffold(
      title: 'Jobs',
      subtitle: 'Track every approved project from deposit to close',
      children: [
        FilterBar(const [
          'All',
          'Scheduled',
          'In Progress',
          'Completed',
          'Unassigned',
        ], c.jobFilter),
        const SizedBox(height: 14),
        Obx(() {
          final f = c.jobFilter.value;
          bool ok(Job j) {
            switch (f) {
              case 'Scheduled':
                return j.stage >= 3 && j.stage <= 5;
              case 'In Progress':
                return j.stage == 6 || j.stage == 7;
              case 'Completed':
                return j.stage >= 8;
              case 'Unassigned':
                return j.crew == 'Unassigned';
              default:
                return true;
            }
          }

          final list = c.jobs.where(ok).toList();
          return ResponsiveTable(
            headers: const [
              'Job',
              'Service',
              'Schedule',
              'Crew',
              'Amount',
              'Status',
            ],
            rows: [
              for (final j in list)
                [
                  sub(j.customer, '${j.id} • ${j.address}'),
                  plain(j.service),
                  plain('${fmtDate(j.date)} • ${j.time}'),
                  plain(j.crew),
                  bold(money(j.amount)),
                  Chip2(jobStages[j.stage]),
                ],
            ],
            onTap: (i) => openJob(context, list[i]),
          );
        }),
      ],
    );
  }
}

void openJob(BuildContext context, Job j) {
  final c = Get.find<AppController>();
  showDialog(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (ctx, setS) {
        Widget photos(String t, int n) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$t ($n)',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (int i = 0; i < n; i++)
                    Container(
                      width: 54,
                      height: 54,
                      color: C.line,
                      child: const Icon(Icons.image, color: C.muted, size: 20),
                    ),
                  InkWell(
                    onTap: () {
                      setS(() {
                        t == 'Before' ? j.before++ : j.after++;
                      });
                      c.jobs.refresh();
                    },
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        border: Border.all(color: C.navy),
                      ),
                      child: const Icon(
                        Icons.add_a_photo,
                        size: 20,
                        color: C.navy,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
            child: Column(
              children: [
                Container(
                  color: C.navy,
                  padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${j.id} • ${j.service}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        KV('Customer', j.customer),
                        KV('Address', j.address),
                        KV('Schedule', '${fmtDate(j.date)} • ${j.time}'),
                        KV('Duration', j.duration),
                        KV('Amount', money(j.amount), boldV: true),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value:
                              [
                                'Unassigned',
                                'Crew A',
                                'Crew B',
                                'Crew C',
                              ].contains(j.crew)
                              ? j.crew
                              : 'Unassigned',
                          decoration: const InputDecoration(
                            labelText: 'Assigned crew',
                          ),
                          items: [
                            for (final e in [
                              'Unassigned',
                              'Crew A',
                              'Crew B',
                              'Crew C',
                            ])
                              DropdownMenuItem(value: e, child: Text(e)),
                          ],
                          onChanged: (v) {
                            setS(() => j.crew = v!);
                            c.jobs.refresh();
                          },
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Job Status',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        for (int i = 0; i < jobStages.length; i++)
                          InkWell(
                            onTap: () {
                              setS(() => j.stage = i);
                              c.setJobStage(j, i);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Row(
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    alignment: Alignment.center,
                                    color: i < j.stage
                                        ? C.green
                                        : (i == j.stage ? C.yellow : C.line),
                                    child: i < j.stage
                                        ? const Icon(
                                            Icons.check,
                                            size: 15,
                                            color: Colors.white,
                                          )
                                        : Text(
                                            '${i + 1}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    jobStages[i],
                                    style: TextStyle(
                                      fontWeight: i == j.stage
                                          ? FontWeight.w900
                                          : FontWeight.w500,
                                      color: i > j.stage ? C.muted : C.text,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            photos('Before', j.before),
                            const SizedBox(width: 12),
                            photos('After', j.after),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const TextField(
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Job instructions / notes for crew',
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
      },
    ),
  );
}
