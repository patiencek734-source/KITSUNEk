import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../state/kitsune_state.dart';
import '../../theme/marble_background.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.state});
  final KitsuneState state;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final pin = TextEditingController();
  String? error;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return MarbleBackground(
      dark: dark,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('KITSUNE', style: Theme.of(context).textTheme.headlineMedium?.copyWith(letterSpacing: 6)),
                const SizedBox(height: 8),
                const Text('Locked'),
                const SizedBox(height: 28),
                TextField(
                  controller: pin,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'PIN'),
                  onSubmitted: (_) => _unlock(),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 20),
                FilledButton(onPressed: _unlock, child: const Text('Unlock')),
                if (widget.state.biometricEnabled) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final ok = await widget.state.biometricUnlock();
                      if (!ok && mounted) setState(() => error = 'Biometric unlock failed');
                    },
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Use biometrics'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _unlock() async {
    final ok = await widget.state.verifyPin(pin.text);
    if (!ok && mounted) setState(() => error = 'Incorrect PIN');
  }
}
