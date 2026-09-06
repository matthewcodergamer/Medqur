class ClinicalClock {
  const ClinicalClock._();

  /// Medqur uses an explicit 24-hour clinical clock for encounter/audit text so
  /// entries such as 06:37 and 18:37 are never ambiguous.
  static String time(DateTime value) {
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  static String dateTime(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${time(local)}';
  }

  static String dateTimeShort(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} • ${time(local)}';
  }
}
