// ============================================================
// FIRESTORE SERVICE
// Central service for all database read/write operations.
//
// Collections used:
//   stock_in           → Goods received from suppliers
//   sales              → Sales transactions
//   returns            → Customer returns
//   stock_verification → Physical stock count records
//
// All writes include a 'createdAt' server timestamp for
// accurate ordering and audit trail.
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Returns today's date as a string in 'yyyy-MM-dd' format.
  /// Used as the 'date' field in all records for easy date-based filtering.
  String get _today => DateFormat('yyyy-MM-dd').format(DateTime.now());

  // ─── STOCK IN ──────────────────────────────────────────────────────────────

  /// Records new goods received from a supplier.
  /// totalValue is auto-calculated as qtyReceived × unitCost.
  Future<void> addStockIn({
    required String itemName,
    required int qtyReceived,
    required double unitCost,
    required String supplier,
    required String receivedBy,
  }) async {
    await _db.collection('stock_in').add({
      'date': _today,
      'itemName': itemName.trim(),
      'qtyReceived': qtyReceived,
      'unitCost': unitCost,
      'totalValue': qtyReceived * unitCost, // Pre-calculated for reporting
      'supplier': supplier.trim(),
      'receivedBy': receivedBy.trim(),
      'createdAt': FieldValue.serverTimestamp(), // For ordering by time
    });
  }

  /// Real-time stream of all stock-in records, newest first.
  Stream<QuerySnapshot> getStockInStream() {
    return _db
        .collection('stock_in')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ─── SALES ─────────────────────────────────────────────────────────────────

  /// Records a new sales transaction.
  /// totalAmount is auto-calculated as qtySold × unitPrice.
  Future<void> addSale({
    required String itemName,
    required int qtySold,
    required double unitPrice,
    required String paymentMethod,
    required String cashierName,
    required String receiptNo,
  }) async {
    await _db.collection('sales').add({
      'date': _today,
      'itemName': itemName.trim(),
      'qtySold': qtySold,
      'unitPrice': unitPrice,
      'totalAmount': qtySold * unitPrice, // Pre-calculated for reporting
      'paymentMethod': paymentMethod,     // Cash, POS, Transfer, or Credit
      'cashierName': cashierName.trim(),
      'receiptNo': receiptNo.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Real-time stream of ALL sales records, newest first.
  /// Used in the All Records tab.
  Stream<QuerySnapshot> getSalesStream() {
    return _db
        .collection('sales')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Real-time stream of TODAY'S sales only.
  /// Used in the Dashboard and Daily Report for live revenue tracking.
  Stream<QuerySnapshot> getTodaySalesStream() {
    return _db
        .collection('sales')
        .where('date', isEqualTo: _today)
        .snapshots();
  }

  // ─── RETURNS ───────────────────────────────────────────────────────────────

  /// Records a customer return.
  /// actionTaken: Restocked, Refund Given, Exchanged, or Pending.
  Future<void> addReturn({
    required String itemName,
    required int qtyReturned,
    required String reason,
    required String actionTaken,
    required String processedBy,
  }) async {
    await _db.collection('returns').add({
      'date': _today,
      'itemName': itemName.trim(),
      'qtyReturned': qtyReturned,
      'reason': reason.trim(),
      'actionTaken': actionTaken,
      'processedBy': processedBy.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Real-time stream of ALL returns records, newest first.
  Stream<QuerySnapshot> getReturnsStream() {
    return _db
        .collection('returns')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Real-time stream of TODAY'S returns only.
  /// Used in the Dashboard to show today's return count.
  Stream<QuerySnapshot> getTodayReturnsStream() {
    return _db
        .collection('returns')
        .where('date', isEqualTo: _today)
        .snapshots();
  }

  // ─── STOCK VERIFICATION ────────────────────────────────────────────────────

  /// Records a physical stock count for one item.
  /// difference = physicalCount - systemQty
  ///   Positive → surplus (more on shelf than records show)
  ///   Negative → shortage (less on shelf than records show)
  ///   Zero     → perfect match
  Future<void> addStockVerification({
    required String itemName,
    required int systemQty,
    required int physicalCount,
    required String verifiedBy,
  }) async {
    await _db.collection('stock_verification').add({
      'date': _today,
      'itemName': itemName.trim(),
      'systemQty': systemQty,
      'physicalCount': physicalCount,
      'difference': physicalCount - systemQty, // Key metric for discrepancies
      'verifiedBy': verifiedBy.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Real-time stream of all stock verification records, newest first.
  Stream<QuerySnapshot> getStockVerificationStream() {
    return _db
        .collection('stock_verification')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Real-time stream of TODAY'S stock verifications only.
  Stream<QuerySnapshot> getTodayStockVerificationStream() {
    return _db
        .collection('stock_verification')
        .where('date', isEqualTo: _today)
        .snapshots();
  }
}