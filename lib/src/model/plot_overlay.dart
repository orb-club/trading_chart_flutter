import 'package:flutter/widgets.dart';

/// Position data for widgets that should be aligned to the chart plot area.
@immutable
class TradingChartPlotOverlay {
  /// Creates plot overlay layout data.
  const TradingChartPlotOverlay({
    required this.plotRect,
    required this.priceAxisRect,
    required this.timeAxisRect,
  });

  /// Main plot bounds in chart-local coordinates.
  final Rect plotRect;

  /// Price-axis bounds in chart-local coordinates.
  final Rect priceAxisRect;

  /// Time-axis bounds in chart-local coordinates.
  final Rect timeAxisRect;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TradingChartPlotOverlay &&
          plotRect == other.plotRect &&
          priceAxisRect == other.priceAxisRect &&
          timeAxisRect == other.timeAxisRect;

  @override
  int get hashCode => Object.hash(plotRect, priceAxisRect, timeAxisRect);
}

/// Builds a widget aligned to the chart plot area.
typedef TradingChartPlotOverlayBuilder = Widget Function(
  BuildContext context,
  TradingChartPlotOverlay overlay,
);

/// Called whenever the chart plot area layout changes.
typedef TradingChartPlotOverlayChanged = void Function(
  TradingChartPlotOverlay overlay,
);
