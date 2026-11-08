import '../data/models.dart';

const poundsPerKg = 2.2046226218;

double displayWeight(double kg, WeightUnit unit) =>
    unit == WeightUnit.lb ? kg * poundsPerKg : kg;
double weightToKg(double value, WeightUnit unit) =>
    unit == WeightUnit.lb ? value / poundsPerKg : value;

String formatWeight(double kg, WeightUnit unit) {
  final value = displayWeight(kg, unit);
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

String formatDuration(Duration duration) {
  final seconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
  final minutes = (seconds ~/ 60 % 60).toString().padLeft(2, '0');
  final remainder = (seconds % 60).toString().padLeft(2, '0');
  return seconds >= 3600
      ? '${seconds ~/ 3600}:$minutes:$remainder'
      : '$minutes:$remainder';
}

String formatDate(DateTime date) {
  const months = [
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
  final local = date.toLocal();
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}
