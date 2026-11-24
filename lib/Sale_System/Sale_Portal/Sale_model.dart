// Save as: lib/Admin/pages/sales/sales_models.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

double _d(dynamic v) => v is num ? v.toDouble() : 0;
DateTime _t(dynamic v) => v is Timestamp ? v.toDate() : DateTime.now();

const kServices = [
  'General Handyman',
  'Plumbing',
  'Electrical',
  'Painting',
  'Drywall & Repair',
  'Flooring',
  'Carpentry',
  'Roofing',
  'HVAC',
  'Landscaping',
  'Cleaning',
  'Remodeling',
  'Other',
];

/// Lead pipeline. Only admins can move a lead; reps see the result.
class LeadStatus {
  static const submitted = 'submitted';
  static const contacted = 'contacted';
  static const estimateScheduled = 'estimate_scheduled';
  static const estimateSent = 'estimate_sent';
  static const negotiating = 'negotiating';
  static const won = 'won'; // contract approved
  static const inProgress = 'in_progress';
  static const completed = 'completed';
  static const lost = 'lost';
  static const rejected = 'rejected'; // invalid / duplicate

  /// Happy-path order, used by the progress tracker.
  static const flow = [
    submitted,
    contacted,
    estimateScheduled,
    estimateSent,
    negotiating,
    won,
    inProgress,
    completed,
  ];

  static const _labels = {
    submitted: 'Submitted',
    contacted: 'Contacted',
    estimateScheduled: 'Estimate scheduled',
    estimateSent: 'Estimate sent',
    negotiating: 'Negotiating',
    won: 'Job won',
    inProgress: 'In progress',
    completed: 'Completed',
    lost: 'Lost',
    rejected: 'Rejected',
  };

  static String label(String s) => _labels[s] ?? s;

  static bool isWon(String s) => s == won || s == inProgress || s == completed;
  static bool isClosed(String s) => s == lost || s == rejected;
  static bool isOpen(String s) => !isWon(s) && !isClosed(s);

  static Color color(String s) {
    if (s == completed) return const Color(0xFF34D399);
    if (isWon(s)) return const Color(0xFF22D3EE);
    if (s == lost || s == rejected) return const Color(0xFFFF6B6B);
    if (s == negotiating || s == estimateSent) return const Color(0xFFFFC857);
    return const Color(0xFF7FA8FF);
  }
}

class Lead {
  Lead({
    required this.id,
    required this.repUid,
    required this.repId,
    required this.customerName,
    required this.phone,
    required this.email,
    required this.address,
    required this.service,
    required this.description,
    required this.budgetMin,
    required this.budgetMax,
    required this.photos,
    required this.status,
    required this.assignedToName,
    required this.contractValue,
    required this.amountPaid,
    required this.lostReason,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id, repUid, repId, customerName, phone, email, address;
  final String service, description, status, assignedToName, lostReason;
  final double budgetMin, budgetMax, contractValue, amountPaid;
  final List<String> photos;
  final DateTime createdAt, updatedAt;

  String get budgetLabel => budgetMax <= 0
      ? '—'
      : '${money(budgetMin, cents: false)} – ${money(budgetMax, cents: false)}';

  factory Lead.fromDoc(DocumentSnapshot<Map<String, dynamic>> s) {
    final d = s.data() ?? {};
    return Lead(
      id: s.id,
      repUid: d['repUid'] ?? '',
      repId: d['repId'] ?? '',
      customerName: d['customerName'] ?? '',
      phone: d['phone'] ?? '',
      email: d['email'] ?? '',
      address: d['address'] ?? '',
      service: d['service'] ?? '',
      description: d['description'] ?? '',
      budgetMin: _d(d['budgetMin']),
      budgetMax: _d(d['budgetMax']),
      photos: List<String>.from(d['photos'] ?? const []),
      status: d['status'] ?? LeadStatus.submitted,
      assignedToName: d['assignedToName'] ?? '',
      contractValue: _d(d['contractValue']),
      amountPaid: _d(d['amountPaid']),
      lostReason: d['lostReason'] ?? '',
      createdAt: _t(d['createdAt']),
      updatedAt: _t(d['updatedAt'] ?? d['createdAt']),
    );
  }
}

/// commissions/{leadId}. Written by Cloud Functions / admin only.
class CommissionRec {
  CommissionRec({
    required this.id,
    required this.customerName,
    required this.service,
    required this.contractValue,
    required this.rate,
    required this.total,
    required this.releasable,
    required this.approved,
    required this.paidAmount,
    required this.status,
    required this.paidAt,
    required this.paymentMethod,
    required this.updatedAt,
  });

  final String id, customerName, service, status, paymentMethod;
  final double contractValue, rate, total, releasable, paidAmount;
  final bool approved;
  final DateTime? paidAt;
  final DateTime updatedAt;

  /// Earned on the contract but the customer has not paid for it yet.
  double get awaitingCustomer => (total - releasable).clamp(0, double.infinity);

  /// Customer payment verified, waiting for admin approval.
  double get underReview =>
      approved ? 0 : (releasable - paidAmount).clamp(0, double.infinity);

  /// Approved by admin, not yet paid out.
  double get readyToPay =>
      approved ? (releasable - paidAmount).clamp(0, double.infinity) : 0;

  double get outstanding => (total - paidAmount).clamp(0, double.infinity);

  static const _labels = {
    'pending': 'Awaiting customer payment',
    'payable': 'Under review',
    'approved': 'Approved',
    'partially_paid': 'Partially paid',
    'paid': 'Paid',
    'void': 'Void',
  };
  String get statusLabel => _labels[status] ?? status;

  Color get statusColor {
    switch (status) {
      case 'paid':
        return const Color(0xFF34D399);
      case 'approved':
      case 'partially_paid':
        return const Color(0xFF22D3EE);
      case 'payable':
        return const Color(0xFFFFC857);
      case 'void':
        return const Color(0xFFFF6B6B);
      default:
        return const Color(0xFF9DB2D6);
    }
  }

  factory CommissionRec.fromDoc(DocumentSnapshot<Map<String, dynamic>> s) {
    final d = s.data() ?? {};
    return CommissionRec(
      id: s.id,
      customerName: d['customerName'] ?? '',
      service: d['service'] ?? '',
      contractValue: _d(d['contractValue']),
      rate: _d(d['rate']),
      total: _d(d['totalCommission']),
      releasable: _d(d['releasableAmount']),
      approved: d['approved'] == true,
      paidAmount: _d(d['paidAmount']),
      status: d['status'] ?? 'pending',
      paidAt: d['paidAt'] is Timestamp
          ? (d['paidAt'] as Timestamp).toDate()
          : null,
      paymentMethod: d['paymentMethod'] ?? '',
      updatedAt: _t(d['updatedAt']),
    );
  }
}

class HistoryEntry {
  HistoryEntry(this.action, this.message, this.by, this.at);
  final String action, message, by;
  final DateTime at;

  factory HistoryEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> s) {
    final d = s.data() ?? {};
    return HistoryEntry(
      d['action'] ?? '',
      d['message'] ?? '',
      d['by'] ?? '',
      _t(d['at']),
    );
  }
}

class AppNotification {
  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.leadId,
    required this.read,
    required this.createdAt,
  });
  final String id, title, body, type, leadId;
  final bool read;
  final DateTime createdAt;

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> s) {
    final d = s.data() ?? {};
    return AppNotification(
      id: s.id,
      title: d['title'] ?? '',
      body: d['body'] ?? '',
      type: d['type'] ?? 'info',
      leadId: d['leadId'] ?? '',
      read: d['read'] == true,
      createdAt: _t(d['createdAt']),
    );
  }
}

// ── Formatting helpers ─────────────────────────────────────────────────────
String money(double v, {bool cents = true}) {
  final s = v.toStringAsFixed(cents ? 2 : 0);
  final parts = s.split('.');
  final whole = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (m) => ',',
  );
  return cents ? '\$$whole.${parts[1]}' : '\$$whole';
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String fmtDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';
String monthName(DateTime d) => _months[d.month - 1];

String timeAgo(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return fmtDate(d);
}
