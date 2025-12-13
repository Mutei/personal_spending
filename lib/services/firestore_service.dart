import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  FirestoreService._();
  static final instance = FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // main users collection
  CollectionReference<Map<String, dynamic>> get usersCol =>
      _db.collection('users');

  // ------------------------------------------------------------
  // BASIC USER STUFF (your original code)
  // ------------------------------------------------------------

  /// check if username is taken
  Future<bool> usernameExists(String username) async {
    final snap = await usersCol
        .where('username', isEqualTo: username.toLowerCase())
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  /// create user document (basic info)
  Future<void> createUserDoc({
    required String uid,
    required String email,
    required String username,
  }) async {
    await usersCol.doc(uid).set({
      'email': email,
      'username': username.toLowerCase(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// get email from username (for login)
  Future<String?> getEmailFromUsername(String username) async {
    final snap = await usersCol
        .where('username', isEqualTo: username.toLowerCase())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.data()['email'] as String?;
  }

  // ------------------------------------------------------------
  // USER META (your original code)
  // ------------------------------------------------------------

  DocumentReference<Map<String, dynamic>> userDoc(String uid) =>
      usersCol.doc(uid);

  /// save "meta" for this user (budget, period)
  Future<void> saveUserMeta({
    required String uid,
    required double monthlyBudget,
    DateTime? periodStart,
    DateTime? periodEnd,
  }) async {
    await userDoc(uid).set({
      'monthlyBudget': monthlyBudget,
      'periodStart': periodStart?.toIso8601String(),
      'periodEnd': periodEnd?.toIso8601String(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// read user meta
  Future<Map<String, dynamic>?> getUserMeta(String uid) async {
    final snap = await userDoc(uid).get();
    return snap.data();
  }

  // ------------------------------------------------------------
  // DAILY SPENDINGS (your original code)
  // users/{uid}/daily_spendings/{yyyy-MM-dd}
  // ------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> dailySpendings(String uid) =>
      userDoc(uid).collection('daily_spendings');

  /// save a single day (dateKey = yyyy-MM-dd)
  Future<void> saveDay({
    required String uid,
    required String dateKey,
    required double total,
    required List<Map<String, dynamic>> entries,
  }) async {
    await dailySpendings(uid).doc(dateKey).set({
      'date': dateKey,
      'total': total,
      'entries': entries,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// get all days for this user
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getAllDays(
    String uid,
  ) async {
    final snap = await dailySpendings(uid).get();
    return snap.docs;
  }

  // ------------------------------------------------------------
  // >>> OTHER SPENDINGS <<<
  // Structure:
  // users/{uid}/other_spendings/{yyyy-MM-dd}/entries/{entryId}
  // ------------------------------------------------------------

  /// subcollection root for other spendings
  CollectionReference<Map<String, dynamic>> otherSpendings(String uid) =>
      userDoc(uid).collection('other_spendings');

  /// helper to make "yyyy-MM-dd"
  String buildDateKey(DateTime date) {
    return "${date.year.toString().padLeft(4, '0')}-"
        "${date.month.toString().padLeft(2, '0')}-"
        "${date.day.toString().padLeft(2, '0')}";
  }

  /// add one other-spending entry, returns the entry doc id
  Future<String> addOtherSpending({
    required String uid,
    required DateTime date,
    required double amount,
    String? title,
    String? category,
    String? bank,
    int? qty,
  }) async {
    final dateKey = buildDateKey(date);

    final dayRef = otherSpendings(uid).doc(dateKey);

    // ensure day doc exists
    await dayRef.set({
      'date': dateKey,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final entryRef = await dayRef.collection('entries').add({
      'amount': amount,
      'title': title,
      'category': category,
      'bank': bank,
      'qty': qty,
      'date': Timestamp.fromDate(date),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return entryRef.id;
  }

  /// update an existing other-spending entry
  Future<void> updateOtherSpending({
    required String uid,
    required String dayId, // yyyy-MM-dd
    required String entryId,
    required Map<String, dynamic> data,
  }) async {
    final entryRef = otherSpendings(
      uid,
    ).doc(dayId).collection('entries').doc(entryId);

    await entryRef.update(data);
  }

  /// delete an other-spending entry
  Future<void> deleteOtherSpending({
    required String uid,
    required String dayId,
    required String entryId,
  }) async {
    final entryRef = otherSpendings(
      uid,
    ).doc(dayId).collection('entries').doc(entryId);

    await entryRef.delete();
  }

  /// read ALL other spendings for a user (all days)
  /// we bring days first, then their entries
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  getOtherSpendingDays(String uid) async {
    final snap = await otherSpendings(uid).get();
    return snap.docs;
  }
}
