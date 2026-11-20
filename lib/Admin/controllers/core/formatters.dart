const kMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String fmtDate(DateTime d) => '${kMonths[d.month - 1]} ${d.day}, ${d.year}';

String money(num v) {
  final s = v.toStringAsFixed(2).split('.');
  final w = s[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  return '\$$w.${s[1]}';
}
