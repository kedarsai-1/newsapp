import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../onboarding/onboarding_design.dart';

/// Six-box OTP input with auto-advance and backspace-back behaviour.
class AuthOtpInput extends StatefulWidget {
  final int length;
  final void Function(String code) onChanged;
  final void Function(String code)? onCompleted;
  final bool autofocus;

  const AuthOtpInput({
    super.key,
    this.length = 6,
    required this.onChanged,
    this.onCompleted,
    this.autofocus = true,
  });

  @override
  State<AuthOtpInput> createState() => AuthOtpInputState();
}

class AuthOtpInputState extends State<AuthOtpInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers =
        List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNodes.first.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get value => _controllers.map((c) => c.text).join();

  void clear() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes.first.requestFocus();
    widget.onChanged('');
  }

  void _handleChanged(int index, String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      _controllers[index].text = '';
      widget.onChanged(value);
      return;
    }
    // Paste support: distribute pasted digits across boxes.
    if (digits.length > 1) {
      final remaining = digits.substring(0, 1);
      _controllers[index].value = TextEditingValue(
        text: remaining,
        selection: TextSelection.collapsed(offset: remaining.length),
      );
      var cursor = index + 1;
      for (var i = 1; i < digits.length && cursor < widget.length; i++) {
        _controllers[cursor].text = digits[i];
        cursor++;
      }
      if (cursor < widget.length) {
        _focusNodes[cursor].requestFocus();
      } else {
        _focusNodes.last.unfocus();
      }
    } else {
      _controllers[index].value = TextEditingValue(
        text: digits,
        selection: const TextSelection.collapsed(offset: 1),
      );
      if (index + 1 < widget.length) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    }
    final next = value;
    widget.onChanged(next);
    if (next.length == widget.length && widget.onCompleted != null) {
      widget.onCompleted!(next);
    }
  }

  KeyEventResult _onKey(int index, FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _controllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
      widget.onChanged(value);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final boxWidth =
            (constraints.maxWidth - spacing * (widget.length - 1)) /
                widget.length;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(widget.length, (i) {
            final filled = _controllers[i].text.isNotEmpty;
            return SizedBox(
              width: boxWidth.clamp(40.0, 60.0),
              height: 56,
              child: Focus(
                onKeyEvent: (node, event) => _onKey(i, node, event),
                child: TextField(
                  controller: _controllers[i],
                  focusNode: _focusNodes[i],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 1,
                  cursorColor: OnboardingDesign.accent(context),
                  style: GoogleFonts.notoSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: OnboardingDesign.titleColor(context),
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: filled
                        ? OnboardingDesign.accent(context).withValues(alpha: 0.06)
                        : const Color(0xFFF9FAFB),
                    contentPadding: EdgeInsets.zero,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: filled
                            ? OnboardingDesign.accent(context)
                            : OnboardingDesign.outline(context),
                        width: filled ? 1.4 : 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: OnboardingDesign.accent(context),
                        width: 1.6,
                      ),
                    ),
                  ),
                  onChanged: (v) => _handleChanged(i, v),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
