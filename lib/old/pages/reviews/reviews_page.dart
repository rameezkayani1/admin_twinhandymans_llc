import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/app_controller.dart';
import '../../core/core.dart';
import '../../widgets/widgets.dart';

class ReviewsPage extends StatelessWidget {
  const ReviewsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Get.find<AppController>();
    Widget stars(int n) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < 5; i++)
          Icon(
            i < n ? Icons.star : Icons.star_border,
            color: C.yellow,
            size: 18,
          ),
      ],
    );
    return PageScaffold(
      title: 'Reviews',
      subtitle: 'Customer feedback collected after job completion',
      actions: [
        OutlinedButton.icon(
          onPressed: () => c.snack('Review link copied (Google)'),
          icon: const Icon(Icons.link),
          label: const Text('Copy Google review link'),
        ),
      ],
      children: [
        Obx(
          () => Grid(
            minWidth: 220,
            children: [
              Stat(
                'Average Rating',
                '${c.avgRating.toStringAsFixed(1)} ★',
                Icons.star,
                color: C.yellow,
              ),
              Stat(
                'Total Reviews',
                '${c.reviews.length}',
                Icons.rate_review,
                color: C.blue,
              ),
              Stat(
                'Awaiting Reply',
                '${c.reviews.where((r) => !r.replied).length}',
                Icons.reply,
                color: C.orange,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Obx(
          () => Column(
            children: [
              for (final r in c.reviews)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              r.customer,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            stars(r.stars),
                            Chip2(r.service, color: C.navy),
                            Text(
                              r.date,
                              style: const TextStyle(
                                color: C.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(r.text),
                        const SizedBox(height: 8),
                        r.replied
                            ? const Chip2('Replied', color: C.green)
                            : TextButton.icon(
                                onPressed: () {
                                  r.replied = true;
                                  c.reviews.refresh();
                                  c.snack('Reply posted');
                                },
                                icon: const Icon(Icons.reply),
                                label: const Text('Reply'),
                              ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
