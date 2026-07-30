import 'package:intl/intl.dart';

String formatCurrency(double value) => NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 2,
    ).format(value);

String formatPercent(double value) => '${NumberFormat.decimalPattern('en').format(value)}%';