// Save as: lib/Admin/pages/sales/sales_service.dart
import 'dart:typed_data';

import 'package:admin_twinhandymans_llc/Sale_System/Sale_Portal/Sale_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Web push needs a VAPID key (Firebase console > Cloud Messaging > Web config).
const kVapidKey = '';

class DuplicateLeadException implements Exception {
  @override
  String toString() => 'duplicate';
}

/// All Firestore / Storage access for the rep portal in one place, so the
/// same service can be reused by the iOS / Android apps later.
class SalesService {
  SalesService._();
  static final instance = SalesService._();

  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  // ── Streams (every query is filtered by the rep's own uid) ───────────────
  Stream<Map<String, dynamic>?> repStream(String uid) =>
      _db.collection('reps').doc(uid).snapshots().map((s) => s.data());

  Stream<List<Lead>> leads(String uid) => _db
      .collection('leads')
      .where('repUid', isEqualTo: uid)
      .snapshots()
      .map((q) {
        final l = q.docs.map(Lead.fromDoc).toList();
        l.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return l;
      });

  Stream<List<CommissionRec>> commissions(String uid) => _db
      .collection('commissions')
      .where('repUid', isEqualTo: uid)
      .snapshots()
      .map((q) {
        final l = q.docs.map(CommissionRec.fromDoc).toList();
        l.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return l;
      });

  Stream<List<AppNotification>> notifications(String uid) => _db
      .collection('notifications')
      .where('uid', isEqualTo: uid)
      .snapshots()
      .map((q) {
        final l = q.docs.map(AppNotification.fromDoc).toList();
        l.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return l.take(50).toList();
      });

  Stream<List<Map<String, dynamic>>> promos() => _db
      .collection('promos')
      .where('active', isEqualTo: true)
      .snapshots()
      .map((q) {
        final l = q.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        l.sort((a, b) {
          final x = a['createdAt'], y = b['createdAt'];
          if (x is Timestamp && y is Timestamp) return y.compareTo(x);
          return 0;
        });
        return l;
      });

  Stream<List<HistoryEntry>> history(String leadId) => _db
      .collection('leads')
      .doc(leadId)
      .collection('history')
      .orderBy('at', descending: true)
      .snapshots()
      .map((q) => q.docs.map(HistoryEntry.fromDoc).toList());

  // ── Duplicate protection ────────────────────────────────────────────────
  static String _slug(String s) {
    final x = s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return x.length > 120 ? x.substring(0, 120) : x;
  }

  static String _digits(String p) {
    final d = p.replaceAll(RegExp(r'[^0-9]'), '');
    return d.length > 10 ? d.substring(d.length - 10) : d;
  }

  /// One open lead per (phone + service) and per (address + service),
  /// across ALL reps. Keys are released by Cloud Functions when a lead is
  /// marked lost / rejected.
  List<String> dedupeKeys(String phone, String address, String service) => [
    'p_${_digits(phone)}_${_slug(service)}',
    'a_${_slug(address)}_${_slug(service)}',
  ];

  // ── Submit a lead ───────────────────────────────────────────────────────
  Future<String> submitLead({
    required String repUid,
    required String repId,
    required String repName,
    required String customerName,
    required String phone,
    required String email,
    required String address,
    required String service,
    required String description,
    required double budgetMin,
    required double budgetMax,
    required List<Uint8List> photos,
  }) async {
    final keys = dedupeKeys(phone, address, service);

    // Fast pre-check (before spending bandwidth on photo uploads).
    for (final k in keys) {
      if ((await _db.collection('dedupe_keys').doc(k).get()).exists) {
        throw DuplicateLeadException();
      }
    }

    final ref = _db.collection('leads').doc();
    final urls = <String>[];
    for (var i = 0; i < photos.length; i++) {
      final r = _storage.ref('lead_photos/$repUid/${ref.id}/$i.jpg');
      await r.putData(photos[i], SettableMetadata(contentType: 'image/jpeg'));
      urls.add(await r.getDownloadURL());
    }

    // Authoritative check + write in one transaction.
    await _db.runTransaction((tx) async {
      for (final k in keys) {
        if ((await tx.get(_db.collection('dedupe_keys').doc(k))).exists) {
          throw DuplicateLeadException();
        }
      }
      for (final k in keys) {
        tx.set(_db.collection('dedupe_keys').doc(k), {
          'leadId': ref.id,
          'repUid': repUid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      tx.set(ref, {
        'repUid': repUid,
        'repId': repId,
        'repName': repName,
        'customerName': customerName,
        'phone': phone,
        'email': email.toLowerCase(),
        'address': address,
        'service': service,
        'description': description,
        'budgetMin': budgetMin,
        'budgetMax': budgetMax,
        'photos': urls,
        'status': LeadStatus.submitted,
        'dedupeKeys': keys,
        'customerConsent': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.set(ref.collection('history').doc(), {
        'action': 'created',
        'message': 'Lead submitted by $repName ($repId)',
        'by': repName,
        'at': FieldValue.serverTimestamp(),
      });
    });
    return ref.id;
  }

  // ── Notifications & preferences ─────────────────────────────────────────
  Future<void> markRead(String id) =>
      _db.collection('notifications').doc(id).update({'read': true});

  Future<void> markAllRead(List<AppNotification> list) async {
    final batch = _db.batch();
    for (final n in list.where((n) => !n.read)) {
      batch.update(_db.collection('notifications').doc(n.id), {'read': true});
    }
    await batch.commit();
  }

  Future<void> setPrefs(String uid, {bool? email, bool? push}) async {
    final prefs = <String, dynamic>{};
    if (email != null) prefs['email'] = email;
    if (push != null) prefs['push'] = push;
    await _db.collection('reps').doc(uid).set({
      'prefs': prefs,
    }, SetOptions(merge: true));
    if (push == true) await registerPush(uid);
  }

  /// Saves this device's FCM token so Cloud Functions can push to it.
  Future<void> registerPush(String uid) async {
    try {
      final m = FirebaseMessaging.instance;
      final perm = await m.requestPermission();
      if (perm.authorizationStatus == AuthorizationStatus.denied) return;
      if (kIsWeb && kVapidKey.isEmpty) return;
      final token = await m.getToken(vapidKey: kIsWeb ? kVapidKey : null);
      if (token == null) return;
      final ref = _db.collection('reps').doc(uid);
      await ref.update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });
      m.onTokenRefresh.listen(
        (t) => ref.update({
          'fcmTokens': FieldValue.arrayUnion([t]),
        }),
      );
    } catch (e) {
      debugPrint('⚠️ push registration failed: $e');
    }
  }
}
