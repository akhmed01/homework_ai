import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

class AiThinkingIndicator extends StatefulWidget {
  final ThemeData theme;

  const AiThinkingIndicator({super.key, required this.theme});

  @override
  State<AiThinkingIndicator> createState() => _AiThinkingIndicatorState();
}

class _AiThinkingIndicatorState extends State<AiThinkingIndicator> {
  Timer? _timer;
  int _dotCount = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 420), (_) {
      if (!mounted) {
        return;
      }
      setState(() => _dotCount = (_dotCount + 1) % 4);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final dots = '.' * _dotCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text('Thinking$dots', style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class AnimatedAiText extends StatefulWidget {
  final String text;
  final ThemeData theme;
  final TextSpan Function(String, ThemeData) format;
  final bool animate;
  final VoidCallback? onProgress;

  const AnimatedAiText({
    super.key,
    required this.text,
    required this.theme,
    required this.format,
    this.animate = true,
    this.onProgress,
  });

  @override
  State<AnimatedAiText> createState() => _AnimatedAiTextState();
}

class _AnimatedAiTextState extends State<AnimatedAiText>
    with SingleTickerProviderStateMixin {
  late List<String> _characters;
  late AnimationController _cursorController;
  Timer? _typingTimer;
  int _visibleCount = 0;
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);
    _configureAnimation();
  }

  @override
  void didUpdateWidget(covariant AnimatedAiText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.animate != widget.animate) {
      _configureAnimation();
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _cursorController.dispose();
    super.dispose();
  }

  void _configureAnimation() {
    _typingTimer?.cancel();
    _characters = widget.text.characters.toList();

    if (!widget.animate || _characters.isEmpty) {
      _visibleCount = _characters.length;
      _isComplete = true;
      if (mounted) {
        setState(() {});
      }
      return;
    }

    _visibleCount = 0;
    _isComplete = false;
    if (mounted) {
      setState(() {});
    }

    final stepSize = _stepSizeForLength(_characters.length);
    _typingTimer = Timer.periodic(const Duration(milliseconds: 22), (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _visibleCount = math.min(_visibleCount + stepSize, _characters.length);
        _isComplete = _visibleCount >= _characters.length;
      });

      if (_visibleCount % (stepSize * 4) == 0 || _isComplete) {
        widget.onProgress?.call();
      }

      if (_isComplete) {
        _typingTimer?.cancel();
      }
    });
  }

  int _stepSizeForLength(int length) {
    if (length > 1400) {
      return 18;
    }
    if (length > 900) {
      return 12;
    }
    if (length > 500) {
      return 8;
    }
    if (length > 220) {
      return 5;
    }
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    final visibleText = _characters.take(_visibleCount).join();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(text: widget.format(visibleText, widget.theme)),
        if (!_isComplete) ...[
          const SizedBox(height: 6),
          FadeTransition(
            opacity: _cursorController,
            child: Container(
              width: 10,
              height: 2,
              decoration: BoxDecoration(
                color: widget.theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
