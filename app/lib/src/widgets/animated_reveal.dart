import 'package:flutter/material.dart';

/// Subtle size + fade-in for home cards that conditionally appear, swap or
/// collapse (r5b): the forecast area's single card, the transient correction
/// notice, and the mode-chip strip.
///
/// Wraps the child in an [AnimatedSize] (the height interpolates between card
/// states, including to/from empty) plus a [FadeTransition] so content fades
/// in, driven by a fresh [AnimationController] per child change — when the
/// child's runtime type or [Key] changes, the fade restarts. The child is
/// replaced **instantly** (no cross-fade of old + new), so semantics — e.g. the
/// `liveRegion` correction notice — never double-announce mid-transition.
///
/// **Reduce motion:** gated on the platform flag
/// `MediaQuery.disableAnimations` (the OS reduce-motion setting; the app has no
/// parallel seam). When it is on, the child renders directly and **no animation
/// widgets are mounted** — nothing can run and sizes jump straight.
class AnimatedReveal extends StatefulWidget {
  const AnimatedReveal({
    super.key,
    this.child,
    this.duration = kAnimatedRevealDuration,
  });

  /// The card to show, or null for the collapsed "nothing" state (rendered as
  /// an empty box so the collapse transition animates).
  final Widget? child;

  /// The length of a single appear / swap / collapse transition.
  final Duration duration;

  @override
  State<AnimatedReveal> createState() => _AnimatedRevealState();
}

/// Short enough to feel like one gesture, long enough to read as deliberate.
const Duration kAnimatedRevealDuration = Duration(milliseconds: 200);

class _AnimatedRevealState extends State<AnimatedReveal>
    with
        // One controller per child change — reuse a full TickerProvider rather
        // than the single-ticker mixin, which can only vend one ticker.
        TickerProviderStateMixin {
  AnimationController? _controller;
  CurvedAnimation? _fade;
  Type? _lastChildType;
  Key? _lastChildKey;

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    // Reduce motion: no animation widgets at all — the child (or the empty
    // box) renders straight.
    if (MediaQuery.of(context).disableAnimations) {
      _tearDownFade();
      return child ?? const SizedBox.shrink();
    }
    final type = child?.runtimeType;
    final key = child?.key;
    if (_controller == null || type != _lastChildType || key != _lastChildKey) {
      _tearDownFade();
      _lastChildType = type;
      _lastChildKey = key;
      final controller = AnimationController(
        vsync: this,
        duration: widget.duration,
      );
      _controller = controller;
      _fade = CurvedAnimation(parent: controller, curve: Curves.fastOutSlowIn);
      controller.forward();
    }
    return AnimatedSize(
      duration: widget.duration,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.topLeft,
      child: FadeTransition(
        opacity: _fade!,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }

  void _tearDownFade() {
    _controller?.dispose();
    _controller = null;
    _fade = null;
  }

  @override
  void dispose() {
    _tearDownFade();
    super.dispose();
  }
}
