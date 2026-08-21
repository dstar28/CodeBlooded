/// Lightweight date formatting helpers for Trip Planning.
///
/// No `intl` dependency is added for this prompt — trip dates only need
/// simple, consistent short/full text like "Aug 21" and "Aug 21, 2026".
const List<String> _monthAbbreviations = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String formatShortDate(DateTime date) {
  return '${_monthAbbreviations[date.month - 1]} ${date.day}';
}

String formatFullDate(DateTime date) {
  return '${_monthAbbreviations[date.month - 1]} ${date.day}, ${date.year}';
}

String formatDateRange(DateTime start, DateTime end) {
  return '${formatShortDate(start)} – ${formatShortDate(end)}';
}