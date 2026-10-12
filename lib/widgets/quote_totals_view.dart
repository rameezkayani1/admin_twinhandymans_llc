import 'package:flutter/material.dart';

import '../core/core.dart';
import '../models/models.dart';

Widget totalsView(Quote q) {
  Widget row(String a, String b, {bool strong = false, Color? col}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            a,
            style: TextStyle(
              fontWeight: strong ? FontWeight.w900 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          b,
          style: TextStyle(
            fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
            color: col,
            fontSize: strong ? 16 : 14,
          ),
        ),
      ],
    ),
  );
  return Column(
    children: [
      row('Labor', money(q.labor)),
      row('Materials', money(q.materials)),
      row('Equipment', money(q.equipment)),
      row('Disposal fees', money(q.disposal)),
      row('Travel / service fee', money(q.travel)),
      row('Discount', '- ${money(q.discount)}', col: C.green),
      row('Tax (${q.taxPct}%)', money(q.subtotal * q.taxPct / 100)),
      const Divider(),
      row('Project Total', money(q.total), strong: true),
      Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        color: C.yellow.withAlpha(40),
        child: Column(
          children: [
            row(
              'Required Deposit (${q.depositPct.toStringAsFixed(0)}%)',
              money(q.deposit),
              strong: true,
            ),
            row('Remaining Balance', money(q.balance), strong: true),
          ],
        ),
      ),
    ],
  );
}
