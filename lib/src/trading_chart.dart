import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'chart_controller.dart';
import 'model/candle.dart';
import 'model/bar_marker.dart';
import 'model/chart_pane.dart';
import 'model/chart_theme.dart';
import 'model/crosshair.dart';
import 'model/last_value_label.dart';
import 'model/plot_overlay.dart';
import 'render/render_trading_chart.dart';
import 'series/line_series.dart';

/// A static candlestick chart widget with no built-in gestures.
///
/// Renders [candles] through a single custom render object. Use
/// [InteractiveTradingChart] if you also want pan, zoom and crosshair.
class TradingChart extends LeafRenderObjectWidget {
  /// Creates a static candlestick chart.
  const TradingChart({
    super.key,
    required this.candles,
    this.theme = ChartTheme.dark,
    this.initialBarSpacing = 8,
    this.rightOffsetBars = 8,
    this.showVolume = true,
    this.overlays = const [],
    this.panes = const [],
    this.markers = const [],
    this.controller,
    this.onVisibleRangeChanged,
    this.logarithmicPriceScale = false,
    this.priceAxisWidth = 64,
    this.timeAxisHeight = 24,
    this.showCrosshairOverlay = true,
    this.showOhlcLegend = true,
    this.showLastValueLabel = true,
    this.showGrid = true,
    this.onCrosshairChanged,
    this.onLastValueLabelChanged,
    this.onPlotOverlayChanged,
  });

  /// The full ordered list of bars to render. Times must be ascending.
  final List<Candle> candles;

  /// Colors and font sizes used by the chart.
  final ChartTheme theme;

  /// Pixel width allocated per bar at startup. Adjusted later by zoom.
  final double initialBarSpacing;

  /// Number of empty bar slots reserved at the right edge of the plot.
  final double rightOffsetBars;

  /// Show the translucent volume histogram in the bottom 20 % of the plot.
  final bool showVolume;

  /// Line overlays drawn on top of the candles (e.g. moving averages).
  final List<LineSeries> overlays;

  /// Extra panes stacked under the main plot (e.g. RSI, MACD).
  final List<ChartPane> panes;

  /// Markers anchored to candles by time (e.g. trade entries, news flags).
  final List<BarMarker> markers;

  /// Optional imperative controller for live updates and viewport control.
  final ChartController? controller;

  /// Optional callback invoked when the visible logical range changes.
  ///
  /// Wire this to load older candles when the user scrolls past the start
  /// of the data.
  final VisibleRangeChanged? onVisibleRangeChanged;

  /// When true, the main price scale interpolates in log-space, so equal
  /// percentage moves take equal screen distance. Falls back to linear when
  /// the visible minimum is non-positive.
  final bool logarithmicPriceScale;

  /// Width reserved for the right-side price axis.
  final double priceAxisWidth;

  /// Height reserved for the bottom time axis.
  final double timeAxisHeight;

  /// Whether the package paints its built-in crosshair labels and guide lines.
  final bool showCrosshairOverlay;

  /// Whether the package paints its built-in OHLC legend.
  final bool showOhlcLegend;

  /// Whether the package paints its built-in latest-price label.
  final bool showLastValueLabel;

  /// Whether the package paints its built-in plot grid.
  final bool showGrid;

  /// Optional listener for externally painting app-specific crosshair UI.
  final TradingChartCrosshairChanged? onCrosshairChanged;

  /// Optional listener for externally positioning a latest-price label widget.
  final TradingChartLastValueLabelChanged? onLastValueLabelChanged;

  /// Optional listener for externally positioning plot-aligned widgets.
  final TradingChartPlotOverlayChanged? onPlotOverlayChanged;

  @override
  RenderTradingChart createRenderObject(BuildContext context) {
    final r = RenderTradingChart(
      candles: candles,
      theme: theme,
      initialBarSpacing: initialBarSpacing,
      rightOffsetBars: rightOffsetBars,
      showVolume: showVolume,
      overlays: overlays,
      panes: panes,
      markers: markers,
      logarithmicPriceScale: logarithmicPriceScale,
      priceAxisWidth: priceAxisWidth,
      timeAxisHeight: timeAxisHeight,
      showCrosshairOverlay: showCrosshairOverlay,
      showOhlcLegend: showOhlcLegend,
      showLastValueLabel: showLastValueLabel,
      showGrid: showGrid,
    );
    r
      ..onVisibleRangeChanged = onVisibleRangeChanged
      ..onCrosshairChanged = onCrosshairChanged
      ..onLastValueLabelChanged = onLastValueLabelChanged
      ..onPlotOverlayChanged = onPlotOverlayChanged;
    controller?.attach(r);
    return r;
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderTradingChart renderObject,
  ) {
    renderObject
      ..candles = candles
      ..theme = theme
      ..showVolume = showVolume
      ..overlays = overlays
      ..panes = panes
      ..markers = markers
      ..logarithmicPriceScale = logarithmicPriceScale
      ..priceAxisWidth = priceAxisWidth
      ..timeAxisHeight = timeAxisHeight
      ..showCrosshairOverlay = showCrosshairOverlay
      ..showOhlcLegend = showOhlcLegend
      ..showLastValueLabel = showLastValueLabel
      ..showGrid = showGrid
      ..onVisibleRangeChanged = onVisibleRangeChanged
      ..onCrosshairChanged = onCrosshairChanged
      ..onLastValueLabelChanged = onLastValueLabelChanged
      ..onPlotOverlayChanged = onPlotOverlayChanged;
    if (controller != null) controller!.attach(renderObject);
  }

  @override
  void didUnmountRenderObject(RenderTradingChart renderObject) {
    controller?.detach();
  }
}

enum _GestureZone { plot, priceAxis, timeAxis }

/// TradingView-style interactive wrapper.
///
/// Behavior summary:
/// - Drag in plot: pan X. Single-finger.
/// - Pinch in plot: zoom X around focal point.
/// - Drag on time axis (bottom): zoom X around right edge.
/// - Drag on price axis (right): manual zoom Y around drag start.
/// - Mouse wheel in plot: animated zoom X around cursor.
/// - Long-press in plot: crosshair on, drag moves it. Release: off.
/// - Optional tap-and-drag crosshair mode: tap shows it, plot drag scrubs it.
/// - Hover (mouse): crosshair follows immediately.
/// - Double-tap on plot: scroll to latest.
/// - Double-tap on price axis: re-enable autofit.
/// - Double-tap on time axis: reset bar spacing + follow latest.
class InteractiveTradingChart extends StatefulWidget {
  /// Creates an interactive candlestick chart.
  const InteractiveTradingChart({
    super.key,
    required this.candles,
    this.theme = ChartTheme.dark,
    this.initialBarSpacing = 8,
    this.rightOffsetBars = 8,
    this.showVolume = true,
    this.overlays = const [],
    this.panes = const [],
    this.markers = const [],
    this.controller,
    this.onVisibleRangeChanged,
    this.logarithmicPriceScale = false,
    this.priceAxisWidth = 64,
    this.timeAxisHeight = 24,
    this.showCrosshairOverlay = true,
    this.showOhlcLegend = true,
    this.showGrid = true,
    this.gridBuilder,
    this.lastValueLabelBuilder,
    this.onCrosshairChanged,
    this.touchCrosshairMode = TouchCrosshairMode.longPress,
  });

  /// The full ordered list of bars to render. Times must be ascending.
  final List<Candle> candles;

  /// Colors and font sizes used by the chart.
  final ChartTheme theme;

  /// Pixel width allocated per bar at startup. Adjusted later by zoom.
  final double initialBarSpacing;

  /// Number of empty bar slots reserved at the right edge of the plot.
  final double rightOffsetBars;

  /// Show the translucent volume histogram in the bottom 20 % of the plot.
  final bool showVolume;

  /// Line overlays drawn on top of the candles (e.g. moving averages).
  final List<LineSeries> overlays;

  /// Extra panes stacked under the main plot (e.g. RSI, MACD).
  final List<ChartPane> panes;

  /// Markers anchored to candles by time (e.g. trade entries, news flags).
  final List<BarMarker> markers;

  /// Optional imperative controller for live updates and viewport control.
  final ChartController? controller;

  /// Optional callback invoked when the visible logical range changes.
  ///
  /// Wire this to load older candles when the user scrolls past the start
  /// of the data.
  final VisibleRangeChanged? onVisibleRangeChanged;

  /// When true, the main price scale interpolates in log-space, so equal
  /// percentage moves take equal screen distance. Falls back to linear when
  /// the visible minimum is non-positive.
  final bool logarithmicPriceScale;

  /// Width reserved for the right-side price axis.
  final double priceAxisWidth;

  /// Height reserved for the bottom time axis.
  final double timeAxisHeight;

  /// Whether the package paints its built-in crosshair labels and guide lines.
  final bool showCrosshairOverlay;

  /// Whether the package paints its built-in OHLC legend.
  final bool showOhlcLegend;

  /// Whether the package paints its built-in plot grid.
  ///
  /// When [gridBuilder] is provided, the built-in grid is automatically
  /// suppressed and the custom grid widget is positioned over the plot.
  final bool showGrid;

  /// Builds a custom grid widget positioned over the main plot area.
  final TradingChartPlotOverlayBuilder? gridBuilder;

  /// Builds a custom latest-price label widget.
  ///
  /// When provided, the package owns the label position but does not paint the
  /// built-in latest-price label on the canvas.
  final TradingChartLastValueLabelBuilder? lastValueLabelBuilder;

  /// Optional listener for externally painting app-specific crosshair UI.
  final TradingChartCrosshairChanged? onCrosshairChanged;

  /// How touch input should activate the crosshair.
  final TouchCrosshairMode touchCrosshairMode;

  @override
  State<InteractiveTradingChart> createState() =>
      _InteractiveTradingChartState();
}

class _InteractiveTradingChartState extends State<InteractiveTradingChart>
    with TickerProviderStateMixin {
  final GlobalKey _chartKey = GlobalKey();
  TradingChartLastValueLabel? _lastValueLabel;
  TradingChartPlotOverlay? _plotOverlay;
  bool _lastValueLabelUpdateScheduled = false;
  bool _plotOverlayUpdateScheduled = false;

  RenderTradingChart? get _render =>
      _chartKey.currentContext?.findRenderObject() as RenderTradingChart?;

  // ───────── gesture state ─────────

  _GestureZone _zone = _GestureZone.plot;
  Offset _scaleStartFocal = Offset.zero;
  double _scaleStartBarSpacing = 8;
  double _scaleStartAnchorIndex = 0;
  double _priceDragStartY = 0;
  double _timeAxisDragStartX = 0;
  bool _crosshairActive = false;
  bool _crosshairScaleActive = false;

  // Inertia (fling) for X-pan in the plot.
  Ticker? _flingTicker;
  double _flingVelocityX = 0; // pixels/sec
  Duration _flingLastTick = Duration.zero;

  // Animated wheel zoom.
  AnimationController? _wheelAnim;
  Offset _wheelAnchor = Offset.zero;
  double _wheelStartSpacing = 8;
  double _wheelTargetSpacing = 8;

  // Velocity tracker for fling.
  VelocityTracker? _panVelocity;

  int? _tapCrosshairPointer;
  Offset? _tapCrosshairStart;
  bool _tapCrosshairMoved = false;

  @override
  void initState() {
    super.initState();
    _wheelAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    )..addListener(_tickWheel);
  }

  @override
  void dispose() {
    _flingTicker?.dispose();
    _wheelAnim?.dispose();
    super.dispose();
  }

  // ───────── zone detection ─────────

  _GestureZone _zoneFor(Offset local) {
    final r = _render;
    if (r == null) return _GestureZone.plot;
    if (r.isOverPriceAxis(local)) return _GestureZone.priceAxis;
    if (r.isOverTimeAxis(local)) return _GestureZone.timeAxis;
    return _GestureZone.plot;
  }

  // ───────── scale (pan + pinch) ─────────

  void _onScaleStart(ScaleStartDetails d) {
    _stopFling();
    final r = _render;
    if (r == null) return;
    _zone = _zoneFor(d.localFocalPoint);
    _crosshairScaleActive =
        widget.touchCrosshairMode == TouchCrosshairMode.tapAndDrag &&
            _crosshairActive &&
            r.isOverPlot(d.localFocalPoint);
    if (_crosshairScaleActive) {
      r.setCrosshair(d.localFocalPoint);
      return;
    }

    _scaleStartFocal = d.localFocalPoint;
    _scaleStartBarSpacing = r.timeScale.barSpacing;
    _scaleStartAnchorIndex = r.captureAnchorIndex(d.localFocalPoint.dx);
    _priceDragStartY = d.localFocalPoint.dy;
    _timeAxisDragStartX = d.localFocalPoint.dx;
    _panVelocity = VelocityTracker.withKind(PointerDeviceKind.touch);
    _panVelocity!.addPosition(Duration.zero, d.localFocalPoint);
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final r = _render;
    if (r == null) return;

    // Crosshair gestures disable pan/zoom while the user scrubs the chart.
    if (_crosshairScaleActive) {
      r.setCrosshair(d.localFocalPoint);
      return;
    }

    _panVelocity?.addPosition(
      Duration(milliseconds: DateTime.now().millisecondsSinceEpoch),
      d.localFocalPoint,
    );

    switch (_zone) {
      case _GestureZone.plot:
        if (d.scale != 1.0) {
          r.setSpacingAtAnchor(
            anchorIndex: _scaleStartAnchorIndex,
            anchorX: _scaleStartFocal.dx,
            newSpacing: _scaleStartBarSpacing * d.scale,
          );
        } else if (d.focalPointDelta.dx != 0) {
          r.panByPixels(d.focalPointDelta.dx);
        }
        break;
      case _GestureZone.priceAxis:
        final dy = d.localFocalPoint.dy - _priceDragStartY;
        if (dy.abs() < 0.5) return;
        final factor = math.exp(dy / 200);
        _priceDragStartY = d.localFocalPoint.dy;
        r.priceZoomAt(anchorY: _scaleStartFocal.dy, factor: factor);
        break;
      case _GestureZone.timeAxis:
        final dx = d.localFocalPoint.dx - _timeAxisDragStartX;
        if (dx.abs() < 0.5) return;
        final factor = math.exp(dx / 200);
        _timeAxisDragStartX = d.localFocalPoint.dx;
        r.zoomAt(anchorX: r.plotWidth, factor: factor);
        break;
    }
  }

  void _onScaleEnd(ScaleEndDetails d) {
    if (_crosshairScaleActive) {
      _crosshairScaleActive = false;
      return;
    }
    if (_zone != _GestureZone.plot) return;
    final v = _panVelocity?.getVelocity().pixelsPerSecond.dx ?? 0;
    if (v.abs() < 200) return;
    _startFling(v);
  }

  // ───────── fling inertia ─────────

  void _startFling(double velocityPxSec) {
    _flingVelocityX = velocityPxSec;
    _flingLastTick = Duration.zero;
    _flingTicker?.dispose();
    _flingTicker = createTicker(_onFlingTick)..start();
  }

  void _onFlingTick(Duration elapsed) {
    final r = _render;
    if (r == null) {
      _stopFling();
      return;
    }
    final dt = (elapsed - _flingLastTick).inMicroseconds / 1e6;
    _flingLastTick = elapsed;
    if (dt <= 0) return;
    final dx = _flingVelocityX * dt;
    r.panByPixels(dx);
    _flingVelocityX *= math.exp(-3.5 * dt);
    if (_flingVelocityX.abs() < 30) {
      _stopFling();
    }
  }

  void _stopFling() {
    _flingTicker?.dispose();
    _flingTicker = null;
    _flingVelocityX = 0;
  }

  // ───────── mouse wheel + trackpad scroll (animated, accumulating) ─────────

  void _onPointerSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    final r = _render;
    if (r == null) return;
    if (!r.isOverPlot(e.localPosition)) return;
    _stopFling();

    final dy = e.scrollDelta.dy;
    final dx = e.scrollDelta.dx;

    final isTrackpad = e.kind == PointerDeviceKind.trackpad;

    if (isTrackpad) {
      if (dx != 0) r.panByPixels(-dx);
      if (dy != 0) {
        final factor = math.exp(-dy * 0.005);
        final desired = (r.timeScale.barSpacing * factor).clamp(1.0, 60.0);
        final factorClamped = desired / r.timeScale.barSpacing;
        if ((factorClamped - 1).abs() > 1e-4) {
          r.zoomAt(anchorX: e.localPosition.dx, factor: factorClamped);
        }
      }
      return;
    }

    if (dy == 0) return;
    final factor = math.exp(-dy * 0.0035);
    final desired = (r.timeScale.barSpacing * factor).clamp(1.0, 60.0);
    _animateZoomTo(anchor: e.localPosition, newSpacing: desired);
  }

  void _onPointerDown(PointerDownEvent e) {
    if (widget.touchCrosshairMode != TouchCrosshairMode.tapAndDrag) return;
    final r = _render;
    if (r == null) return;

    _tapCrosshairPointer = e.pointer;
    _tapCrosshairStart = e.localPosition;
    _tapCrosshairMoved = false;
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (widget.touchCrosshairMode != TouchCrosshairMode.tapAndDrag) return;
    if (_tapCrosshairPointer != e.pointer) return;
    final start = _tapCrosshairStart;
    if (start == null) return;
    if ((e.localPosition - start).distance > kTouchSlop) {
      _tapCrosshairMoved = true;
    }
  }

  void _onPointerUp(PointerUpEvent e) {
    if (widget.touchCrosshairMode != TouchCrosshairMode.tapAndDrag) return;
    if (_tapCrosshairPointer != e.pointer) return;
    final r = _render;
    _tapCrosshairPointer = null;
    _tapCrosshairStart = null;
    if (r == null) return;

    if (!_tapCrosshairMoved && r.isOverPlot(e.localPosition)) {
      _stopFling();
      _crosshairActive = true;
      _crosshairScaleActive = false;
      r.setCrosshair(e.localPosition);
    } else if (!_tapCrosshairMoved && !r.isOverPlot(e.localPosition)) {
      _clearCrosshair();
    }
  }

  void _animateZoomTo({required Offset anchor, required double newSpacing}) {
    final r = _render;
    if (r == null) return;
    _wheelAnchor = anchor;
    _wheelStartSpacing = r.timeScale.barSpacing;
    _wheelTargetSpacing = newSpacing.clamp(1.0, 60.0);
    _wheelAnim!
      ..stop()
      ..value = 0
      ..forward();
  }

  void _tickWheel() {
    final r = _render;
    if (r == null) return;
    final t = Curves.easeOut.transform(_wheelAnim!.value);
    final desired =
        _wheelStartSpacing + (_wheelTargetSpacing - _wheelStartSpacing) * t;
    final factor = desired / r.timeScale.barSpacing;
    if ((factor - 1).abs() < 1e-4) return;
    r.zoomAt(anchorX: _wheelAnchor.dx, factor: factor);
  }

  // ───────── trackpad pan/zoom (native PanZoom events) ─────────

  Offset _panZoomFocal = Offset.zero;
  double _panZoomStartSpacing = 8;
  double _panZoomAnchorIndex = 0;
  bool _panZoomIsTrackpad = false;

  void _onPanZoomStart(PointerPanZoomStartEvent e) {
    final r = _render;
    if (r == null) return;
    _stopFling();
    _panZoomFocal = e.localPosition;
    _panZoomStartSpacing = r.timeScale.barSpacing;
    _panZoomAnchorIndex = r.captureAnchorIndex(e.localPosition.dx);
    _panZoomIsTrackpad = true;
  }

  void _onPanZoomUpdate(PointerPanZoomUpdateEvent e) {
    final r = _render;
    if (r == null) return;
    if (!_panZoomIsTrackpad) return;

    if (e.scale != 1.0) {
      r.setSpacingAtAnchor(
        anchorIndex: _panZoomAnchorIndex,
        anchorX: _panZoomFocal.dx,
        newSpacing: _panZoomStartSpacing * e.scale,
      );
    }
    if (e.scale == 1.0 && (e.panDelta.dx != 0 || e.panDelta.dy != 0)) {
      if (e.panDelta.dx != 0) r.panByPixels(e.panDelta.dx);
      if (e.panDelta.dy != 0) {
        final factor = math.exp(-e.panDelta.dy * 0.0035);
        r.zoomAt(anchorX: e.localPosition.dx, factor: factor);
      }
    }
  }

  void _onPanZoomEnd(PointerPanZoomEndEvent e) {
    _panZoomIsTrackpad = false;
  }

  // ───────── crosshair (long-press on touch + hover on mouse) ─────────

  void _onHover(PointerHoverEvent e) {
    final r = _render;
    if (r == null) return;
    if (r.isOverPlot(e.localPosition)) {
      r.setCrosshair(e.localPosition);
    } else {
      r.setCrosshair(null);
    }
  }

  void _onExit(PointerExitEvent e) {
    _clearCrosshair();
  }

  void _onLongPressStart(LongPressStartDetails d) {
    if (widget.touchCrosshairMode != TouchCrosshairMode.longPress) return;
    final r = _render;
    if (r == null) return;
    if (!r.isOverPlot(d.localPosition)) return;
    _stopFling();
    _crosshairActive = true;
    _crosshairScaleActive = true;
    r.setCrosshair(d.localPosition);
  }

  void _onLongPressMove(LongPressMoveUpdateDetails d) {
    if (widget.touchCrosshairMode != TouchCrosshairMode.longPress) return;
    _render?.setCrosshair(d.localPosition);
  }

  void _onLongPressEnd(LongPressEndDetails d) {
    if (widget.touchCrosshairMode != TouchCrosshairMode.longPress) return;
    _crosshairActive = false;
    _crosshairScaleActive = false;
    _render?.setCrosshair(null);
  }

  void _onPointerCancel(PointerCancelEvent e) {
    _tapCrosshairPointer = null;
    _tapCrosshairStart = null;
    _tapCrosshairMoved = false;
    _clearCrosshair();
  }

  void _clearCrosshair() {
    _crosshairActive = false;
    _crosshairScaleActive = false;
    _render?.setCrosshair(null);
  }

  // ───────── double tap ─────────

  Offset _lastTapDown = Offset.zero;
  void _onTapDown(TapDownDetails d) {
    _lastTapDown = d.localPosition;
  }

  void _onDoubleTap() {
    final r = _render;
    if (r == null) return;
    final zone = _zoneFor(_lastTapDown);
    switch (zone) {
      case _GestureZone.plot:
        r.scrollToLatest();
        break;
      case _GestureZone.priceAxis:
        r.resetPriceAutoFit();
        break;
      case _GestureZone.timeAxis:
        r.resetTimeScale(barSpacing: widget.initialBarSpacing);
        break;
    }
  }

  // ───────── build ─────────

  @override
  Widget build(BuildContext context) {
    final lastValueLabelBuilder = widget.lastValueLabelBuilder;
    final gridBuilder = widget.gridBuilder;
    final plotOverlay = _plotOverlay;
    final lastValueLabel = _lastValueLabel;
    final chart = TradingChart(
      key: _chartKey,
      candles: widget.candles,
      theme: widget.theme,
      initialBarSpacing: widget.initialBarSpacing,
      rightOffsetBars: widget.rightOffsetBars,
      showVolume: widget.showVolume,
      overlays: widget.overlays,
      panes: widget.panes,
      markers: widget.markers,
      controller: widget.controller,
      onVisibleRangeChanged: widget.onVisibleRangeChanged,
      logarithmicPriceScale: widget.logarithmicPriceScale,
      priceAxisWidth: widget.priceAxisWidth,
      timeAxisHeight: widget.timeAxisHeight,
      showCrosshairOverlay: widget.showCrosshairOverlay,
      showOhlcLegend: widget.showOhlcLegend,
      showGrid: widget.showGrid && gridBuilder == null,
      showLastValueLabel: lastValueLabelBuilder == null,
      onCrosshairChanged: widget.onCrosshairChanged,
      onLastValueLabelChanged:
          lastValueLabelBuilder == null ? null : _handleLastValueLabelChanged,
      onPlotOverlayChanged:
          gridBuilder == null ? null : _handlePlotOverlayChanged,
    );
    final child = lastValueLabelBuilder == null && gridBuilder == null
        ? chart
        : Stack(
            fit: StackFit.expand,
            children: [
              if (gridBuilder != null && plotOverlay != null)
                IgnorePointer(
                  child: CustomMultiChildLayout(
                    delegate: _ChartOverlayLayoutDelegate(
                      plotOverlay: plotOverlay,
                    ),
                    children: [
                      LayoutId(
                        id: _ChartOverlaySlot.grid,
                        child: gridBuilder(context, plotOverlay),
                      ),
                    ],
                  ),
                ),
              chart,
              if (lastValueLabelBuilder != null && lastValueLabel != null)
                IgnorePointer(
                  child: CustomMultiChildLayout(
                    delegate: _ChartOverlayLayoutDelegate(
                      lastValueLabel: lastValueLabel,
                    ),
                    children: [
                      LayoutId(
                        id: _ChartOverlaySlot.lastValueLabel,
                        child: lastValueLabelBuilder(context, lastValueLabel),
                      ),
                    ],
                  ),
                ),
            ],
          );

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerSignal: _onPointerSignal,
      onPointerHover: _onHover,
      onPointerCancel: _onPointerCancel,
      onPointerPanZoomStart: _onPanZoomStart,
      onPointerPanZoomUpdate: _onPanZoomUpdate,
      onPointerPanZoomEnd: _onPanZoomEnd,
      child: MouseRegion(
        onExit: _onExit,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _onTapDown,
          onDoubleTap: _onDoubleTap,
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          onScaleEnd: _onScaleEnd,
          onLongPressStart: _onLongPressStart,
          onLongPressMoveUpdate: _onLongPressMove,
          onLongPressEnd: _onLongPressEnd,
          child: child,
        ),
      ),
    );
  }

  void _handleLastValueLabelChanged(TradingChartLastValueLabel? label) {
    if (_lastValueLabel == label || _lastValueLabelUpdateScheduled) {
      return;
    }

    _lastValueLabelUpdateScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _lastValueLabelUpdateScheduled = false;
      if (!mounted || _lastValueLabel == label) {
        return;
      }

      setState(() => _lastValueLabel = label);
    });
  }

  void _handlePlotOverlayChanged(TradingChartPlotOverlay overlay) {
    if (_plotOverlay == overlay || _plotOverlayUpdateScheduled) {
      return;
    }

    _plotOverlayUpdateScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _plotOverlayUpdateScheduled = false;
      if (!mounted || _plotOverlay == overlay) {
        return;
      }

      setState(() => _plotOverlay = overlay);
    });
  }
}

enum _ChartOverlaySlot { grid, lastValueLabel }

class _ChartOverlayLayoutDelegate extends MultiChildLayoutDelegate {
  _ChartOverlayLayoutDelegate({
    this.plotOverlay,
    this.lastValueLabel,
  });

  final TradingChartPlotOverlay? plotOverlay;
  final TradingChartLastValueLabel? lastValueLabel;

  @override
  void performLayout(Size size) {
    final plotOverlay = this.plotOverlay;
    if (plotOverlay != null && hasChild(_ChartOverlaySlot.grid)) {
      layoutChild(
        _ChartOverlaySlot.grid,
        BoxConstraints.tight(plotOverlay.plotRect.size),
      );
      positionChild(_ChartOverlaySlot.grid, plotOverlay.plotRect.topLeft);
    }

    final label = lastValueLabel;
    if (label == null || !hasChild(_ChartOverlaySlot.lastValueLabel)) {
      return;
    }
    final childSize = layoutChild(
      _ChartOverlaySlot.lastValueLabel,
      BoxConstraints.loose(size),
    );
    final left = (label.priceAxisRect.right - childSize.width - 1).clamp(
      0.0,
      math.max(0, size.width - childSize.width).toDouble(),
    );
    final top = (label.y - childSize.height / 2).clamp(
      label.priceAxisRect.top,
      math
          .max(label.priceAxisRect.top,
              label.priceAxisRect.bottom - childSize.height)
          .toDouble(),
    );

    positionChild(_ChartOverlaySlot.lastValueLabel, Offset(left, top));
  }

  @override
  bool shouldRelayout(covariant _ChartOverlayLayoutDelegate oldDelegate) {
    return oldDelegate.plotOverlay != plotOverlay ||
        oldDelegate.lastValueLabel != lastValueLabel;
  }
}
