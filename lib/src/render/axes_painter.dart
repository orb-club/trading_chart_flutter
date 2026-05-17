import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../model/chart_theme.dart';
import '../scale/price_scale.dart';
import '../scale/time_scale.dart';

class AxesPainter {
  /// Width reserved for the right-side price axis.
  static const double priceAxisWidth = 64;

  /// Height reserved for the bottom time axis.
  static const double timeAxisHeight = 24;

  static void paintGrid({
    required ui.Canvas canvas,
    required ui.Rect plotRect,
    required ChartTheme theme,
    required List<PriceAxisTick> priceTicks,
    required List<TimeAxisTick> timeTicks,
  }) {
    final paint = ui.Paint()
      ..color = theme.gridLine
      ..strokeWidth = 1;
    for (final t in priceTicks) {
      final y = t.y.roundToDouble() + 0.5;
      switch (theme.gridStyle) {
        case ChartGridStyle.solid:
          canvas.drawLine(
            ui.Offset(plotRect.left, y),
            ui.Offset(plotRect.right, y),
            paint,
          );
        case ChartGridStyle.dotted:
          _drawHorizontalDots(
            canvas: canvas,
            y: y,
            fromX: plotRect.left,
            toX: plotRect.right,
            theme: theme,
            paint: paint,
          );
      }
    }
    for (final t in timeTicks) {
      if (!t.isMajor) continue;
      final x = t.x.roundToDouble() + 0.5;
      switch (theme.gridStyle) {
        case ChartGridStyle.solid:
          canvas.drawLine(
            ui.Offset(x, plotRect.top),
            ui.Offset(x, plotRect.bottom),
            paint,
          );
        case ChartGridStyle.dotted:
          _drawVerticalDots(
            canvas: canvas,
            x: x,
            fromY: plotRect.top,
            toY: plotRect.bottom,
            theme: theme,
            paint: paint,
          );
      }
    }
  }

  static void _drawHorizontalDots({
    required ui.Canvas canvas,
    required double y,
    required double fromX,
    required double toX,
    required ChartTheme theme,
    required ui.Paint paint,
  }) {
    final spacing = theme.gridDotSpacing;
    if (spacing <= 0) return;

    var x = fromX;
    while (x <= toX) {
      canvas.drawCircle(
        ui.Offset(x.roundToDouble() + 0.5, y),
        theme.gridDotRadius,
        paint,
      );
      x += spacing;
    }
  }

  static void _drawVerticalDots({
    required ui.Canvas canvas,
    required double x,
    required double fromY,
    required double toY,
    required ChartTheme theme,
    required ui.Paint paint,
  }) {
    final spacing = theme.gridDotSpacing;
    if (spacing <= 0) return;

    var y = fromY;
    while (y <= toY) {
      canvas.drawCircle(
        ui.Offset(x, y.roundToDouble() + 0.5),
        theme.gridDotRadius,
        paint,
      );
      y += spacing;
    }
  }

  static void paintPriceAxis({
    required ui.Canvas canvas,
    required ui.Rect axisRect,
    required ChartTheme theme,
    required List<PriceAxisTick> ticks,
  }) {
    final linePaint = ui.Paint()
      ..color = theme.axisLine
      ..strokeWidth = 1;
    canvas.drawLine(
      ui.Offset(axisRect.left + 0.5, axisRect.top),
      ui.Offset(axisRect.left + 0.5, axisRect.bottom),
      linePaint,
    );
    for (final t in ticks) {
      _drawText(
        canvas: canvas,
        text: t.label,
        x: axisRect.left + 6,
        y: t.y - 6,
        style: _axisTextStyle(theme.priceAxisTextStyle, theme),
      );
    }
  }

  static void paintTimeAxis({
    required ui.Canvas canvas,
    required ui.Rect axisRect,
    required ChartTheme theme,
    required List<TimeAxisTick> ticks,
  }) {
    final linePaint = ui.Paint()
      ..color = theme.axisLine
      ..strokeWidth = 1;
    canvas.drawLine(
      ui.Offset(axisRect.left, axisRect.top + 0.5),
      ui.Offset(axisRect.right, axisRect.top + 0.5),
      linePaint,
    );
    for (final t in ticks) {
      if (!t.isMajor) continue;
      _drawText(
        canvas: canvas,
        text: t.label,
        x: t.x + 4,
        y: axisRect.top + 4,
        style: _axisTextStyle(theme.timeAxisTextStyle, theme),
      );
    }
  }

  static TextStyle _axisTextStyle(
    TextStyle? style,
    ChartTheme theme,
  ) {
    return style ??
        TextStyle(
          color: theme.text,
          fontSize: theme.axisFontSize,
        );
  }

  static void _drawText({
    required ui.Canvas canvas,
    required String text,
    required double x,
    required double y,
    required TextStyle style,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: style,
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, ui.Offset(x, y));
  }
}
