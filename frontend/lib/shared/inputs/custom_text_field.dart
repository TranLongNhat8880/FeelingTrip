import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../mascot/koharu_controller.dart';

class CustomTextField extends StatefulWidget {
  const CustomTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.prefixIcon,
    this.isPassword = false,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
    this.minLines,
    this.enabled = true,
    this.readOnly = false,
    this.onChanged,
    this.errorText,
    this.helperText,
    this.inputFormatters,
    this.onTap,
    this.suffixIcon,
    this.textInputAction,
    this.onFieldSubmitted,
    this.guideId,
  });

  final String label;
  final String? guideId;
  final String? hint;
  final TextEditingController? controller;
  final IconData? prefixIcon;
  final bool isPassword;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;
  final int? maxLines;
  final int? minLines;
  final bool enabled;
  final bool readOnly;
  final ValueChanged<String>? onChanged;
  final String? errorText;
  final String? helperText;
  final List<TextInputFormatter>? inputFormatters;
  final VoidCallback? onTap;
  final Widget? suffixIcon;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _obscure = true;
  late final FocusNode _focusNode;
  bool _isFocused = false;
  FormFieldState<String>? _fieldState;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
    widget.controller?.addListener(_onControllerChange);
  }

  @override
  void didUpdateWidget(CustomTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerChange);
      widget.controller?.addListener(_onControllerChange);
    }
  }

  void _onControllerChange() {
    if (_fieldState != null && widget.controller != null) {
      if (_fieldState!.value != widget.controller!.text) {
        _fieldState!.didChange(widget.controller!.text);
      }
    }
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() => _isFocused = _focusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerChange);
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  IconData? _resolvePrefixIcon() {
    if (widget.prefixIcon != null) return widget.prefixIcon;
    if (widget.isPassword) return Icons.lock_outline_rounded;
    if (widget.keyboardType == TextInputType.emailAddress) {
      return Icons.mail_outline_rounded;
    }
    if (widget.keyboardType == TextInputType.phone) {
      return Icons.phone_outlined;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final prefix = _resolvePrefixIcon();

    return KoharuTarget(
      id: widget.guideId,
      enabled: widget.enabled,
      child: FormField<String>(
        validator: (val) {
          final text = widget.controller != null
              ? widget.controller!.text
              : val;
          return widget.validator?.call(text);
        },
        initialValue: widget.controller?.text,
        builder: (fieldState) {
          _fieldState = fieldState;
          final hasError = fieldState.hasError || widget.errorText != null;
          final errorMessage = fieldState.errorText ?? widget.errorText;

          final borderColor = hasError
              ? AppColors.error
              : (_isFocused ? AppColors.primary : const Color(0xFFE2E8F0));

          final iconColor = hasError
              ? AppColors.error
              : (_isFocused ? AppColors.primary : const Color(0xFF8A97AB));

          final inputField = Container(
            decoration: BoxDecoration(
              color: widget.enabled
                  ? (_isFocused ? Colors.white : const Color(0xFFFAFCFE))
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: borderColor,
                width: (_isFocused || hasError) ? 1.5 : 1.1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (prefix != null) ...[
                  Icon(prefix, size: 22, color: iconColor),
                  const SizedBox(width: 13),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: hasError
                              ? AppColors.error
                              : (_isFocused
                                    ? AppColors.primary
                                    : const Color(0xFF5D6889)),
                        ),
                      ),
                      const SizedBox(height: 2),
                      TextFormField(
                        controller: widget.controller,
                        focusNode: _focusNode,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF09143B),
                        ),
                        obscureText: widget.isPassword && _obscure,
                        enableSuggestions: !widget.isPassword,
                        autocorrect: !widget.isPassword,
                        keyboardType: widget.keyboardType,
                        maxLines: widget.isPassword ? 1 : widget.maxLines,
                        minLines: widget.isPassword ? 1 : widget.minLines,
                        enabled: widget.enabled,
                        readOnly: widget.readOnly,
                        onChanged: (val) {
                          fieldState.didChange(val);
                          widget.onChanged?.call(val);
                        },
                        inputFormatters: widget.inputFormatters,
                        onTap: widget.onTap,
                        textInputAction: widget.textInputAction,
                        onFieldSubmitted: widget.onFieldSubmitted,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          hintText: widget.hint,
                          hintStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF969DB3),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.isPassword)
                  IconButton(
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: _obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                    onPressed: widget.enabled
                        ? () => setState(() => _obscure = !_obscure)
                        : null,
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: const Color(0xFF8A97AB),
                    ),
                  )
                else if (widget.suffixIcon != null)
                  widget.suffixIcon!,
              ],
            ),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              widget.readOnly && widget.onTap != null
                  ? GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.enabled ? widget.onTap : null,
                      child: inputField,
                    )
                  : inputField,
              if (hasError)
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 4),
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.error,
                    ),
                  ),
                )
              else if (widget.helperText != null)
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 4),
                  child: Text(
                    widget.helperText!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
