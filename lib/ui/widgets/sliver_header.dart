import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class FloatingDynamicSliverHeader extends StatefulWidget {
  final Widget child;
  final Color? backgroundColor;
  final bool pinned;
  final bool floating;

  const FloatingDynamicSliverHeader(
      {super.key,
      required this.child,
      this.backgroundColor,
      this.pinned = false,
      this.floating = true});

  @override
  State<FloatingDynamicSliverHeader> createState() =>
      _FloatingDynamicSliverHeaderState();
}

class _FloatingDynamicSliverHeaderState
    extends State<FloatingDynamicSliverHeader> with TickerProviderStateMixin {
  double _height = 300;

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
        pinned: widget.pinned,
        floating: widget.floating,
        delegate: _FloatingDynamicHeaderDelegate(
            height: _height,
            floating: !widget.pinned,
            ticker: this,
            onHeightChanged: (h) => setState(() => _height = h),
            child: ColoredBox(
                color: widget.backgroundColor ??
                    Theme.of(context).colorScheme.surface,
                child: widget.child)));
  }
}

class _FloatingDynamicHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;
  final bool floating;
  final ValueChanged<double> onHeightChanged;
  final TickerProvider _ticker;

  _FloatingDynamicHeaderDelegate(
      {required this.child,
      required this.height,
      required this.floating,
      required TickerProvider ticker,
      required this.onHeightChanged})
      : _ticker = ticker;

  @override
  TickerProvider? get vsync => _ticker;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(context, shrinkOffset, overlapsContent) => OverflowBox(
      minHeight: 0,
      maxHeight: double.infinity,
      alignment: Alignment.topLeft,
      child: _MeasureSize(
          onSizeChanged: (size) => onHeightChanged(size.height), child: child));

  @override
  bool shouldRebuild(_FloatingDynamicHeaderDelegate old) =>
      old.height != height || old.child != child || old.floating != floating;

  @override
  FloatingHeaderSnapConfiguration? get snapConfiguration =>
      floating ? FloatingHeaderSnapConfiguration() : null;
}

class _MeasureSize extends SingleChildRenderObjectWidget {
  final ValueChanged<Size> onSizeChanged;

  const _MeasureSize({required this.onSizeChanged, required Widget child})
      : super(child: child);

  @override
  RenderObject createRenderObject(context) =>
      _MeasureSizeRenderObject(onSizeChanged);
}

class _MeasureSizeRenderObject extends RenderProxyBox {
  final ValueChanged<Size> onSizeChanged;
  Size _oldSize = Size.zero;

  _MeasureSizeRenderObject(this.onSizeChanged);

  @override
  void performLayout() {
    super.performLayout();
    if (size != _oldSize) {
      _oldSize = size;
      WidgetsBinding.instance.addPostFrameCallback((_) => onSizeChanged(size));
    }
  }
}
