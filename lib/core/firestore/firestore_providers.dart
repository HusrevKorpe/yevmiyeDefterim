/// Ortak Firestore sağlayıcısı (kural §7).
///
/// Tüm repository'ler [FirebaseFirestore]'u bu sağlayıcıdan alır; testlerde
/// `overrideWithValue(...)` ile sahte/emülatör örneği geçilebilir.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final Provider<FirebaseFirestore> firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
