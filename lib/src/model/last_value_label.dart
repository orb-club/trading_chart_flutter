import 'package:flutter/widgets.dart';

import 'candle.dart';

/// Position and value data for the latest-price label overlay.
@immutable
class TradingChartLastValueLabel {
  const TradingChartLastValueLabel({
    required this.candle,
    required this.price,
    required this.y,
    required this.plotRect,
    required this.priceAxisRect,
  });

  /// Latest candle currently represented by the label.
  final Candle candle;

  /// Price value represented by the label.
  final double price;

  /// Vertical center of the label in chart-local coordinates.
  final double y;

  /// Main plot bounds in chart-local coordinates.
  final Rect plotRect;

  /// Price-axis bounds in chart-local coordinates.
  final Rect priceAxisRect;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TradingChartLastValueLabel &&
          candle == other.candle &&
          price == other.price &&
          y == other.y &&
          plotRect == other.plotRect &&
          priceAxisRect == other.priceAxisRect;

  @override
  int get hashCode => Object.hash(candle, price, y, plotRect, priceAxisRect);
}

/// Builds a custom widget for the latest-price label.
typedef TradingChartLastValueLabelBuilder = Widget Function(
  BuildContext context,
  TradingChartLastValueLabel label,
);

/// Called whenever the latest-price label position changes.
typedef TradingChartLastValueLabelChanged = void Function(
  TradingChartLastValueLabel? label,
);
