import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';

/// A single input supports autofill and paste; the six cells adapt to small screens.
class AppOtpField extends StatefulWidget {
  const AppOtpField({
    super.key,
    required this.controller,
    required this.focusNode,
    this.enabled = true,
    this.hasError = false,
    this.onCompleted,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final bool hasError;
  final ValueChanged<String>? onCompleted;

  @override
  State<AppOtpField> createState() => _AppOtpFieldState();
}

class _AppOtpFieldState extends State<AppOtpField> {
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.controller, widget.focusNode]),
    builder: (context, _) => Stack(
      alignment: Alignment.center,
      children: [
        Opacity(
          opacity: 0,
          alwaysIncludeSemantics: true,
          child: TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            enabled: widget.enabled,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.oneTimeCode],
            decoration: const InputDecoration(labelText: 'Mã OTP gồm 6 chữ số'),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            onChanged: (value) {
              if (value.length == 6) widget.onCompleted?.call(value);
            },
          ),
        ),
        ExcludeSemantics(
          child: GestureDetector(
            onTap: widget.enabled ? widget.focusNode.requestFocus : null,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                for (var index = 0; index < 6; index++) ...[
                  if (index > 0) const SizedBox(width: AppSizes.spaceS),
                  Expanded(
                    child: AnimatedContainer(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 150),
                      height: math.max(
                        60,
                        MediaQuery.textScalerOf(context).scale(24) + 24,
                      ),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color:
                            widget.focusNode.hasFocus &&
                                index == widget.controller.text.length
                            ? AppColors.surface
                            : AppColors.inputSurface,
                        borderRadius: BorderRadius.circular(
                          AppSizes.inputRadius,
                        ),
                        border: Border.all(
                          color: widget.hasError
                              ? AppColors.error
                              : widget.focusNode.hasFocus &&
                                    index == widget.controller.text.length
                              ? AppColors.primary
                              : AppColors.border,
                          width:
                              widget.focusNode.hasFocus &&
                                  index == widget.controller.text.length
                              ? 1.6
                              : 1,
                        ),
                      ),
                      child: Text(
                        index < widget.controller.text.length
                            ? widget.controller.text[index]
                            : '',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
