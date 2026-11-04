import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/admin_security_service.dart';

/// Shows the 4-digit PIN prompt dialog for Admin Access.
/// Returns true if the user enters the correct PIN, false otherwise.
Future<bool> showAdminPinDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => const _AdminPinDialog(),
  );
  return result ?? false;
}

class _AdminPinDialog extends StatefulWidget {
  const _AdminPinDialog();

  @override
  State<_AdminPinDialog> createState() => _AdminPinDialogState();
}

class _AdminPinDialogState extends State<_AdminPinDialog> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _errorMessage;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleDigitChanged(String value) async {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
    if (value.length == 4) {
      await _verifyPin(value);
    }
  }

  Future<void> _verifyPin(String pin) async {
    if (_verifying) return;
    setState(() => _verifying = true);

    final isValid = await AdminSecurityService.verifyPin(pin);
    if (!mounted) return;

    if (isValid) {
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(true);
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _verifying = false;
        _errorMessage = 'Incorrect PIN. Try again.';
        _pinController.clear();
      });
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131926) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.cyanAccent.withAlpha(100),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.cyanAccent.withAlpha(isDark ? 40 : 25),
                blurRadius: 30,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 180 : 40),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Security Shield Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.cyanAccent.withAlpha(30),
                  border: Border.all(
                    color: Colors.cyanAccent.withAlpha(140),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Colors.cyanAccent,
                  size: 34,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'Admin Access',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                'Enter 4-digit security PIN to proceed',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 24),

              // 4 PIN visual boxes
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _pinController,
                builder: (context, value, _) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final hasDigit = index < value.text.length;
                      final isCurrent = index == value.text.length;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 52,
                        height: 58,
                        decoration: BoxDecoration(
                          color: hasDigit
                              ? Colors.cyanAccent.withAlpha(isDark ? 40 : 25)
                              : (isDark ? const Color(0xFF1E2638) : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _errorMessage != null
                                ? Colors.redAccent
                                : (isCurrent
                                    ? Colors.cyanAccent
                                    : (hasDigit
                                        ? Colors.cyanAccent.withAlpha(160)
                                        : Colors.white24)),
                            width: isCurrent || hasDigit ? 2 : 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          hasDigit ? '●' : '',
                          style: TextStyle(
                            fontSize: 24,
                            color: _errorMessage != null
                                ? Colors.redAccent
                                : Colors.cyanAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
              const SizedBox(height: 12),

              // Error or Default Hint
              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                Text(
                  'Default PIN is 1234',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.black38,
                    letterSpacing: 0.5,
                  ),
                ),
              const SizedBox(height: 20),

              // Hidden invisible input to capture soft keyboard
              Opacity(
                opacity: 0.0,
                child: SizedBox(
                  width: 1,
                  height: 1,
                  child: TextField(
                    controller: _pinController,
                    focusNode: _focusNode,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    onChanged: _handleDigitChanged,
                  ),
                ),
              ),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.cyanAccent.shade700,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _verifying
                          ? null
                          : () {
                              if (_pinController.text.length == 4) {
                                _verifyPin(_pinController.text);
                              } else {
                                setState(() {
                                  _errorMessage = 'Please enter all 4 digits.';
                                });
                              }
                            },
                      child: _verifying
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Text(
                              'Unlock',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
