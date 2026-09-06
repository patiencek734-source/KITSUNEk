import 'package:flutter/material.dart';
import '../state/kitsune_state.dart';
import '../theme/marble_background.dart';
import '../theme/marble_theme.dart';
import '../widgets/common.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.state});
  final KitsuneState state;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final name = TextEditingController();
  String profile = 'trans_men';
  DateTime start = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return MarbleBackground(
      dark: dark,
      child: Scaffold(
        appBar: AppBar(title: const Text('KITSUNE')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Private HRT tracking', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text('Everything stays on this phone. This is a personal tracker, not medical advice.'),
            const SizedBox(height: 20),
            TextField(controller: name, decoration: deco('What should we call you?')),
            const SizedBox(height: 16),
            SectionTitle('Profile'),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'trans_men', label: Text('Trans man'), icon: Icon(Icons.north)),
                ButtonSegment(value: 'trans_women', label: Text('Trans woman'), icon: Icon(Icons.south)),
              ],
              selected: {profile},
              onSelectionChanged: (s) => setState(() => profile = s.first),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('HRT start date'),
              subtitle: Text(widget.state.formatDay(start)),
              trailing: const Icon(Icons.event),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  firstDate: DateTime(1980),
                  lastDate: DateTime.now(),
                  initialDate: start,
                );
                if (d != null) setState(() => start = d);
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () async {
                await widget.state.completeOnboarding(
                  name: name.text.trim().isEmpty ? 'Friend' : name.text.trim(),
                  selectedProfile: profile,
                  start: start,
                );
              },
              child: const Text('Enter KITSUNE'),
            ),
          ],
        ),
      ),
    );
  }
}
