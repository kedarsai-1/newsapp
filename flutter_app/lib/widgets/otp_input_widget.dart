import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/feed/feed_xpresso_theme.dart';

/// 6-box OTP input widget with glass styling.
/// Usage:
///   GlassOtpInput(onCompleted: (code) => submitCode(code))
class GlassOtpInput extends StatefulWidget {
  final void Function(String code) onCompleted;
  final void Function(String code)? onChanged;
  final int length;
  final bool autoFocus;

  const GlassOtpInput({
    super.key,
    required this.onCompleted,
    this.onChanged,
    this.length = 6,
    this.autoFocus = true,
  });

  @override
  State<GlassOtpInput> createState() => _GlassOtpInputState();
}

class _GlassOtpInputState extends State<GlassOtpInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  late final List<String> _values;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes  = List.generate(widget.length, (_) => FocusNode());
    _values      = List.filled(widget.length, '');

    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNodes[0].requestFocus();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  void _onChanged(int index, String value) {
    if (value.length == widget.length) {
      for (int i = 0; i < widget.length; i++) {
        _controllers[i].text = value[i];
        _values[i] = value[i];
      }
      _focusNodes.last.requestFocus();
      final code = _values.join();
      widget.onChanged?.call(code);
      if (code.length == widget.length) widget.onCompleted(code);
      setState(() {});
      return;
    }

    if (value.isEmpty) {
      _values[index] = '';
      widget.onChanged?.call(_values.join());
      setState(() {});
      return;
    }

    final digit = value[value.length - 1];
    if (!RegExp(r'^\d$').hasMatch(digit)) {
      _controllers[index].text = _values[index];
      return;
    }

    _controllers[index].text = digit;
    _controllers[index].selection = TextSelection.fromPosition(
        TextPosition(offset: 1));
    _values[index] = digit;

    if (index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    } else {
      _focusNodes[index].unfocus();
    }

    final code = _values.join();
    widget.onChanged?.call(code);
    if (code.length == widget.length && !code.contains('')) {
      widget.onCompleted(code);
    }
    setState(() {});
  }

  void _onKeyDown(int index, RawKeyEvent event) {
    if (event is RawKeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _values[index].isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
      _values[index - 1] = '';
      widget.onChanged?.call(_values.join());
      setState(() {});
    }
  }

  void clear() {
    for (int i = 0; i < widget.length; i++) {
      _controllers[i].clear();
      _values[i] = '';
    }
    _focusNodes[0].requestFocus();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final fx = context.fx;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.length, (i) {
        final filled  = _values[i].isNotEmpty;
        final focused = _focusNodes[i].hasFocus;
        return Container(
          width: 44, height: 54,
          margin: EdgeInsets.symmetric(
              horizontal: widget.length <= 6 ? 5 : 3),
          decoration: BoxDecoration(
            color: filled ? fx.accentSurface : fx.glassSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: focused
                  ? fx.accent
                  : filled
                      ? fx.accentBorder
                      : fx.glassBorder,
              width: focused ? 1.5 : 0.8,
            ),
          ),
          child: RawKeyboardListener(
            focusNode: FocusNode(skipTraversal: true),
            onKey: (e) => _onKeyDown(i, e),
            child: TextFormField(
              controller: _controllers[i],
              focusNode: _focusNodes[i],
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(widget.length),
              ],
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: filled ? fx.accentLight : fx.title,
                letterSpacing: 0,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                counterText: '',
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (v) => _onChanged(i, v),
              maxLength: widget.length,
            ),
          ),
        );
      }),
    );
  }
}

class ResendOtpButton extends StatefulWidget {
  final Future<void> Function() onResend;
  final int cooldownSeconds;

  const ResendOtpButton({
    super.key,
    required this.onResend,
    this.cooldownSeconds = 60,
  });

  @override
  State<ResendOtpButton> createState() => _ResendOtpButtonState();
}

class _ResendOtpButtonState extends State<ResendOtpButton> {
  int _seconds = 0;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  void _startCooldown() {
    setState(() => _seconds = widget.cooldownSeconds);
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _seconds--);
      return _seconds > 0;
    });
  }

  Future<void> _resend() async {
    setState(() => _loading = true);
    try {
      await widget.onResend();
      _startCooldown();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fx = context.fx;
    if (_loading) {
      return SizedBox(
        height: 20, width: 20,
        child: CircularProgressIndicator(
            strokeWidth: 2, color: fx.accentLight),
      );
    }

    if (_seconds > 0) {
      return RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 13, color: fx.textTertiary),
          children: [
            const TextSpan(text: 'Resend code in '),
            TextSpan(
              text: '$_seconds s',
              style: TextStyle(
                  color: fx.accentLight, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _resend,
      child: Text(
        'Resend OTP',
        style: TextStyle(
          fontSize: 13,
          color: fx.accentLight,
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.underline,
          decorationColor: fx.accentLight,
        ),
      ),
    );
  }
}
