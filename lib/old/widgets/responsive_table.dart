import 'package:flutter/material.dart';

import '../core/core.dart';
import 'panel.dart';

/// Table on wide screens, stacked cards on phones.
class ResponsiveTable extends StatelessWidget {
  final List<String> headers;
  final List<List<Widget>> rows;
  final void Function(int)? onTap;
  const ResponsiveTable({
    super.key,
    required this.headers,
    required this.rows,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Panel(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(30),
            child: Text('No records found', style: TextStyle(color: C.muted)),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth < 720) {
          return Column(
            children: [
              for (int r = 0; r < rows.length; r++)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: C.line),
                  ),
                  child: InkWell(
                    onTap: onTap == null ? null : () => onTap!(r),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: DefaultTextStyle.merge(
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                  child: rows[r][0],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: C.muted),
                            ],
                          ),
                          const SizedBox(height: 8),
                          for (int i = 1; i < rows[r].length; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 110,
                                    child: Text(
                                      headers[i],
                                      style: const TextStyle(
                                        color: C.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: rows[r][i],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        }
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: C.line),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: box.maxWidth - 2),
              child: DataTable(
                showCheckboxColumn: false,
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFFF7F8FA),
                ),
                headingTextStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: C.navy,
                  fontSize: 12.5,
                ),
                dataRowMinHeight: 54,
                dataRowMaxHeight: 64,
                columns: [
                  for (final h in headers)
                    DataColumn(label: Text(h.toUpperCase())),
                ],
                rows: [
                  for (int r = 0; r < rows.length; r++)
                    DataRow(
                      onSelectChanged: onTap == null ? null : (_) => onTap!(r),
                      cells: [for (final cell in rows[r]) DataCell(cell)],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
