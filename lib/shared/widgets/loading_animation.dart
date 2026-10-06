import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// A looping Lottie animation with a message below it, for long waits.
/// Falls back to a spinner if the animation can't be loaded.
class LoadingAnimation extends StatelessWidget {
  const LoadingAnimation({
    super.key,
    required this.asset,
    required this.message,
    this.size = 240,
  });

  final String asset;

  /// Shown without trailing dots; [AnimatedLoadingText] adds them.
  final String message;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Lottie.asset(
            asset,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => SizedBox.square(
              dimension: size,
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: AnimatedLoadingText(message),
          ),
        ],
      ),
    );
  }
}

/// [message] followed by dots that count up from one to three, gently
/// pulsing. The dots not yet shown are drawn transparent, so the centred
/// text keeps its width and doesn't shift.
class AnimatedLoadingText extends StatefulWidget {
  const AnimatedLoadingText(this.message, {super.key});

  final String message;

  @override
  State<AnimatedLoadingText> createState() => _AnimatedLoadingTextState();
}

class _AnimatedLoadingTextState extends State<AnimatedLoadingText>
    with SingleTickerProviderStateMixin {
  static const _maxDots = 3;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.headlineSmall;

    return Semantics(
      label: widget.message,
      liveRegion: true,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final progress = _controller.value;
            final dots = ((progress * _maxDots).floor() + 1).clamp(1, _maxDots);
            // 0 → 1 → 0 over each cycle, so the text fades to 55% and back.
            final dip = Curves.easeInOut.transform(
              1 - (2 * progress - 1).abs(),
            );

            return Opacity(
              opacity: 1 - 0.45 * dip,
              child: Text.rich(
                TextSpan(
                  text: widget.message,
                  children: [
                    TextSpan(text: '.' * dots),
                    TextSpan(
                      text: '.' * (_maxDots - dots),
                      style: const TextStyle(color: Colors.transparent),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: style,
              ),
            );
          },
        ),
      ),
    );
  }
}
