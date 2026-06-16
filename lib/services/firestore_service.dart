import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get _today => DateFormat('yyyy-MM-dd').format(DateTime.now());

  // ─── STOCK IN ─────────────────────────────────────────────────

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
      'totalValue': qtyReceived * unitCost,
      'supplier': supplier.trim(),
      'receivedBy': receivedBy.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getStockInStream() {
    return _db
        .collection('stock_in')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ─── SALES ────────────────────────────────────────────────────

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
      'totalAmount': qtySold * unitPrice,
      'paymentMethod': paymentMethod,
      'cashierName': cashierName.trim(),
      'receiptNo': receiptNo.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getSalesStream() {
    return _db
        .collection('sales')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getTodaySalesStream() {
    return _db
        .collection('sales')
        .where('date', isEqualTo: _today)
        .snapshots();
  }

  // ─── RETURNS ──────────────────────────────────────────────────

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

  Stream<QuerySnapshot> getReturnsStream() {
    return _db
        .collection('returns')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getTodayReturnsStream() {
    return _db
        .collection('returns')
        .where('date', isEqualTo: _today)
        .snapshots();
  }

  // ─── STOCK VERIFICATION ───────────────────────────────────────

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
      'difference': physicalCount - systemQty,
      'verifiedBy': verifiedBy.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getStockVerificationStream() {
    return _db
        .collection('stock_verification')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getTodayStockVerificationStream() {
    return _db
        .collection('stock_verification')
        .where('date', isEqualTo: _today)
        .snapshots();
  }
}