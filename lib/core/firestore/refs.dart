/// Firestore referans yardımcıları (plan §3 — `workspaces/main/...`).
///
/// Tek ortak workspace altında iç içe koleksiyonlar. String yolları tek yerde
/// tutar (kural §7: string tekrar etme). Riverpod'a bağımlı değildir; sağlayıcı
/// [firestore_providers.dart] içindedir.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/collections.dart';

/// `workspaces/main` dokümanı.
DocumentReference<Map<String, dynamic>> workspaceRef(FirebaseFirestore db) =>
    db.collection(FsCollections.workspaces).doc(kWorkspaceId);

/// `workspaces/main/workers`.
CollectionReference<Map<String, dynamic>> workersCol(FirebaseFirestore db) =>
    workspaceRef(db).collection(FsCollections.workers);

/// `workspaces/main/attendance`.
CollectionReference<Map<String, dynamic>> attendanceCol(FirebaseFirestore db) =>
    workspaceRef(db).collection(FsCollections.attendance);

/// `workspaces/main/advances`.
CollectionReference<Map<String, dynamic>> advancesCol(FirebaseFirestore db) =>
    workspaceRef(db).collection(FsCollections.advances);

/// `workspaces/main/ledger`.
CollectionReference<Map<String, dynamic>> ledgerCol(FirebaseFirestore db) =>
    workspaceRef(db).collection(FsCollections.ledger);

/// `workspaces/main/payrolls`.
CollectionReference<Map<String, dynamic>> payrollsCol(FirebaseFirestore db) =>
    workspaceRef(db).collection(FsCollections.payrolls);

/// `workspaces/main/settings/config`.
DocumentReference<Map<String, dynamic>> settingsDocRef(FirebaseFirestore db) =>
    workspaceRef(db)
        .collection(FsCollections.settings)
        .doc(kSettingsDocId);
