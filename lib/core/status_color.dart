import 'package:flutter/material.dart';

import 'app_colors.dart';

Color statusColor(String s) {
  final t = s.toLowerCase();
  if ([
    'paid',
    'completed',
    'approved',
    'active',
    'closed',
    'public',
    'verified',
    'job closed',
    'final payment received',
  ].contains(t))
    return C.green;
  if ([
    'pending',
    'new',
    'unpaid',
    'sent',
    'quote sent',
    'in review',
    'awaiting zelle',
    'scheduled',
    'private',
  ].contains(t))
    return C.orange;
  if ([
    'declined',
    'failed',
    'overdue',
    'refunded',
    'inactive',
    'changes requested',
  ].contains(t))
    return C.red;
  return C.blue;
}
