/// Kategori kodu → Material ikonu — tek kaynak (kategori ekranları, Kasa
/// app bar kısayolları, kategori çipleri ve liste satırları paylaşır).
library;

import 'package:flutter/material.dart';

import '../constants/categories.dart';

/// Kategori kodunun ikonu (bilinmeyen/genel → [fallback]).
IconData categoryIcon(
  String category, {
  IconData fallback = Icons.receipt_long,
}) =>
    switch (category) {
      LedgerCategory.mazot => Icons.local_gas_station,
      LedgerCategory.tamir => Icons.handyman,
      LedgerCategory.bakkal => Icons.storefront,
      _ => fallback,
    };
