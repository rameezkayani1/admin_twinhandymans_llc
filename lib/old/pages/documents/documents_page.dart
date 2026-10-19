import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/app_controller.dart';
import '../../core/core.dart';
import '../../widgets/widgets.dart';

class DocumentsPage extends StatelessWidget {
  const DocumentsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Get.find<AppController>();
    return PageScaffold(
      title: 'Documents',
      subtitle:
          'Government & commercial contracting section (shown in the app as PDFs)',
      actions: [
        ElevatedButton.icon(
          onPressed: () => c.snack('Upload document (demo)'),
          icon: const Icon(Icons.upload_file),
          label: const Text('UPLOAD'),
        ),
      ],
      children: [
        Panel(
          title: 'Company Registration Info',
          child: Grid(
            minWidth: 220,
            gap: 12,
            children: const [
              KV2('NAICS Codes', '238320, 561720, 561790, 484210'),
              KV2('UEI', 'TH7K2M9QX4N1 (demo)'),
              KV2('CAGE Code', 'Pending issuance'),
              KV2('Certifications', 'MBE, SBE'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Obx(
          () => ResponsiveTable(
            headers: const [
              'Document',
              'Type',
              'Visibility',
              'Updated',
              'Actions',
            ],
            rows: [
              for (final d in c.documents)
                [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.picture_as_pdf, color: C.red),
                      const SizedBox(width: 10),
                      Flexible(child: bold(d.name)),
                    ],
                  ),
                  plain(d.type),
                  Chip2(d.visibility),
                  plain(d.updated),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Download',
                        onPressed: () => c.snack('${d.name} downloaded'),
                        icon: const Icon(Icons.download),
                      ),
                      IconButton(
                        tooltip: 'Toggle visibility',
                        onPressed: () {
                          d.visibility = d.visibility == 'Public'
                              ? 'Private'
                              : 'Public';
                          c.documents.refresh();
                        },
                        icon: Icon(
                          d.visibility == 'Public'
                              ? Icons.public
                              : Icons.lock_outline,
                        ),
                      ),
                    ],
                  ),
                ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Sensitive documents stay private unless you explicitly make them public.',
          style: TextStyle(color: C.muted, fontSize: 12),
        ),
      ],
    );
  }
}
