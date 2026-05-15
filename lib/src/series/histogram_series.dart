import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../model/candle.dart';
import '../model/chart_theme.dart';
import '../scale/price_scale.dart';
import '../scale/time_scale.dart';

/// Volume bars rendered in an "overlay" sub-region inside the main plot,
/// using their own [PriceScale] (0..maxVolume in view).
///
/// The series uses the theme volume color for every bar.
@immutable
class VolumeHistogramSeries {
  final List<Candle> data;

  const VolumeHistogramSeries({required this.data});

  void paint({
    required ui.Canvas canvas,
    required ui.Size size,
    required TimeScale timeScale,
    required PriceScale priceScale,
    required ChartTheme theme,
  }) {
    if (data.isEmpty) return;
    final width = size.width;
    final height = size.height;

    final paint = ui.Paint()..color = theme.volumeColor;

    final range = timeScale.visibleIntegerRange(width);
    final barWidth = (timeScale.barSpacing * 0.7).clamp(1.0, double.infinity);

    final baseY = priceScale.priceToY(priceScale.minPrice, height);

    for (var i = range.from; i <= range.to; i++) {
      final c = data[i];
      final v = c.volume;
      if (v == null || v <= 0) continue;
      final x = timeScale.indexToX(i.toDouble(), width);
      final topY = priceScale.priceToY(v, height);
      if (topY >= baseY) continue;
      final left = (x - barWidth / 2).roundToDouble();
      final right = (x + barWidth / 2).roundToDouble();
      canvas.drawRect(
        ui.Rect.fromLTRB(left, topY, right, baseY),
        paint,
      );
    }
  }

  /// Computes 0..maxVolume across the visible integer index range.
  ({double min, double max})? volumeRange(int from, int to) {
    if (data.isEmpty) return null;
    final lo = from.clamp(0, data.length - 1);
    final hi = to.clamp(0, data.length - 1);
    if (hi < lo) return null;
    var max = 0.0;
    var any = false;
    for (var i = lo; i <= hi; i++) {
      final v = data[i].volume;
      if (v == null) continue;
      any = true;
      if (v > max) max = v;
    }
    if (!any) return null;
    return (min: 0, max: max);
  }
}
