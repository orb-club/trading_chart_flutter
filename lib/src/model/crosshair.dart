import 'package:flutter/widgets.dart';

import 'candle.dart';

/// Called whenever the interactive crosshair changes.
typedef TradingChartCrosshairChanged = void Function(
  Offset? localPosition,
  int? dataIndex,
  Candle? candle, [
  double? price,
]);
