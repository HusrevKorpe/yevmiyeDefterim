/// Uygulama geneli tek tarih seçici sarmalayıcı.
///
/// Neden var:
///  1. Metin ölçeği tavanı — uygulama düşük-teknoloji kullanıcı için büyük
///     sistem yazısını (tavansız) destekler. Material tarih seçici sabit boyutlu
///     tasarlandığından aşırı ölçekte taşar (sarı-siyah şerit). Seçicinin
///     metnini güvenli bir tavana (`_maxPickerTextScale`) kırparak takvim her
///     zaman düzgün sığar. Uygulamanın geri kalanı büyük yazıyı korur.
///  2. Güvenli `initialDate` — çağıran, aralık dışında (ör. `lastDate`'ten
///     ileri) bir başlangıç verirse `showDatePicker` assert atıp çökerdi.
///     Burada başlangıç her zaman `[firstDate, lastDate]` içine sıkıştırılır.
library;

import 'package:flutter/material.dart';

import '../date/app_date.dart';

/// Takvim düzeninin taşmadan sığdığı en yüksek makul metin ölçeği.
const double _maxPickerTextScale = 1.6;

/// ISO (`yyyy-MM-dd`) alır, ISO döner (iptal edilirse `null`).
///
/// [lastDate] verilmezse bugüne (saat bileşeni olmadan) ayarlanır; [firstDate]
/// verilmezse 2020 başına.
Future<String?> pickAppDate(
  BuildContext context, {
  required String initialIso,
  String? helpText,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  final DateTime first = firstDate ?? DateTime(2020);
  final DateTime last = lastDate ??
      () {
        final now = DateTime.now();
        return DateTime(now.year, now.month, now.day);
      }();

  // Başlangıcı aralığa sıkıştır — aksi halde showDatePicker assert atar.
  DateTime initial = parseIsoDate(initialIso);
  if (initial.isBefore(first)) initial = first;
  if (initial.isAfter(last)) initial = last;

  final picked = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first,
    lastDate: last,
    helpText: helpText,
    builder: (context, child) => MediaQuery.withClampedTextScaling(
      maxScaleFactor: _maxPickerTextScale,
      child: child!,
    ),
  );
  return picked == null ? null : toIsoDate(picked);
}
