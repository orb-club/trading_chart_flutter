import 'package:flutter/widgets.dart';

import 'candle.dart';

/// Called whenever the interactive crosshair changes.
typedef TradingChartCrosshairChanged = void Function(
  Offset? localPosition,
  int? dataIndex,
  Candle? candle, [
  double? price,
]);

/// Configures how touch input activates the crosshair.
enum TouchCrosshairMode {
  /// Touch crosshair starts on long press and clears when the gesture ends.
  longPress,

  /// A tap in the plot shows the crosshair, then later plot drags scrub it.
  tapAndDrag,
}
