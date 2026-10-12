import 'package:flutter/material.dart';

import '../core/core.dart';

Widget bold(String t) =>
    Text(t, style: const TextStyle(fontWeight: FontWeight.w700));
Widget plain(String t) => Text(t);
Widget sub(String a, String b) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    Text(a, style: const TextStyle(fontWeight: FontWeight.w800)),
    Text(b, style: const TextStyle(color: C.muted, fontSize: 12)),
  ],
);
