import 'package:flutter/material.dart';

class PulsingRingsLoader extends StatefulWidget {
  final double size;
  final Color color;
  final Duration duration;

  const PulsingRingsLoader({
    super.key,
    this.size = 48,
    this.color = Colors.red,
    this.duration = const Duration(seconds: 2),
  });

  @override
  State<PulsingRingsLoader> createState() => _PulsingRingsLoaderState();
}

class _PulsingRingsLoaderState extends State<PulsingRingsLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _t1;
  late final Animation<double> _t2;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
    _t1 = CurvedAnimation(parent: _controller, curve: Curves.linear);
    _t2 = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 1.0, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _Ring(size: widget.size, color: widget.color, t: _t1),
          _Ring(size: widget.size, color: widget.color, t: _t2),
        ],
      ),
    );
  }
}

class _Ring extends AnimatedWidget {
  final double size;
  final Color color;
  const _Ring({required this.size, required this.color, required Animation<double> t}) : super(listenable: t);

  Animation<double> get t => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) {
    final scale = t.value.clamp(0.0, 1.0);
    final opacity = (1.0 - scale).clamp(0.0, 1.0);
    final side = size * scale;
    return Opacity(
      opacity: opacity,
      child: Container(
        width: side,
        height: side,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
        ),
      ),
    );
  }
}
