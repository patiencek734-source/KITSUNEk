import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'data/catalog.dart';
import 'features/lock/lock_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'services/ai_provider_service.dart';
import 'services/chat_repository.dart';
import 'state/kitsune_state.dart';
import 'theme/marble_background.dart';
import 'theme/marble_theme.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = KitsuneState();
  await state.bootstrap();
  runApp(KitsuneApp(state: state));
}

class KitsuneApp extends StatelessWidget {
  const KitsuneApp({super.key, required this.state});
  final KitsuneState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'KITSUNE',
        theme: MarbleTheme.light(highContrast: state.highContrast, textScale: state.textScale),
        darkTheme: MarbleTheme.dark(highContrast: state.highContrast, textScale: state.textScale),
        themeMode: state.themeMode,
        home: !state.onboarded
            ? OnboardingScreen(state: state)
            : !state.unlocked
                ? LockScreen(state: state)
                : HomeShell(state: state),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.state});
  final KitsuneState state;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  final search = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final pages = [
      Dashboard(state: widget.state, onNavigate: (value) => setState(() => index = value)),
      MedicationsPage(state: widget.state),
      ProgressPage(state: widget.state),
      CalendarPage(state: widget.state),
      SettingsPage(state: widget.state),
      OnlineChatPage(state: widget.state),
    ];
    return MarbleBackground(
      dark: Theme.of(context).brightness == Brightness.dark,
      child: Scaffold(
        appBar: AppBar(
          title: Text(['Home', 'Medications', 'Progress', 'Calendar', 'Settings', 'Chat'][index]),
          actions: [
            IconButton(
              tooltip: 'Search your records',
              icon: const Icon(Icons.search),
              onPressed: () => showSearch(context: context, delegate: RecordSearch(widget.state)),
            ),
            IconButton(
              tooltip: 'Lock KITSUNE',
              icon: const Icon(Icons.lock_outline),
              onPressed: widget.state.lock,
            ),
          ],
        ),
        body: IndexedStack(index: index, children: pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (value) => setState(() => index = value),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.medication_outlined), selectedIcon: Icon(Icons.medication), label: 'Meds'),
            NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Progress'),
            NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Calendar'),
            NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune), label: 'Settings'),
            NavigationDestination(icon: Icon(Icons.forum_outlined), selectedIcon: Icon(Icons.forum), label: 'Chat'),
          ],
        ),
      ),
    );
  }
}

class OnlineChatPage extends StatefulWidget {
  const OnlineChatPage({super.key, required this.state});
  final KitsuneState state;

  @override
  State<OnlineChatPage> createState() => _OnlineChatPageState();
}

class _OnlineChatPageState extends State<OnlineChatPage> {
  final email = TextEditingController();
  final code = TextEditingController();
  bool codeSent = false;
  bool busy = false;
  String? error;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    if (!state.onlineChatConfigured) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Online chat is not configured for this build. Local tracking remains fully available.')));
    }
    if (!state.onlineChatSignedIn) return _signIn(context);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Community chat', style: Theme.of(context).textTheme.headlineSmall), IconButton(tooltip: 'Sign out', icon: const Icon(Icons.logout), onPressed: state.signOutOnline)]),
      const Text('Chat is separate from your private tracker. Health records, journal entries, photos, and support plans are not uploaded.'),
      const SizedBox(height: 12),
      if (state.chatRooms.isEmpty) const EmptyHint('No rooms are available for this account yet.') else ...state.chatRooms.map((room) => ListTile(leading: const Icon(Icons.forum_outlined), title: Text(room.name), subtitle: Text(room.description), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatRoomPage(state: state, room: room))))),
    ]);
  }

  Widget _signIn(BuildContext context) => ListView(padding: const EdgeInsets.all(24), children: [
        Text('Enable online chat', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Chat requires a separate account. Your local HRT, medication, trauma, journal, photo, and lab records stay on this device unless you explicitly share them elsewhere.'),
        const SizedBox(height: 16),
        TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: deco('Email address')),
        if (codeSent) ...[const SizedBox(height: 12), TextField(controller: code, keyboardType: TextInputType.number, decoration: deco('Email verification code'))],
        const SizedBox(height: 16),
        if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        FilledButton.icon(icon: Icon(codeSent ? Icons.login : Icons.mail_outline), label: Text(codeSent ? 'Verify and enter chat' : 'Send sign-in code'), onPressed: busy ? null : () => codeSent ? _verify() : _request()),
      ];

  Future<void> _request() async {
    setState(() { busy = true; error = null; });
    try {
      await widget.state.requestOnlineSignIn(email.text);
      if (mounted) setState(() => codeSent = true);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _verify() async {
    setState(() { busy = true; error = null; });
    try {
      await widget.state.verifyOnlineCode(email: email.text, code: code.text);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class ChatRoomPage extends StatefulWidget {
  const ChatRoomPage({super.key, required this.state, required this.room});
  final KitsuneState state;
  final ChatRoom room;

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final body = TextEditingController();
  List<ChatMessage> messages = [];
  bool busy = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.room.name)), body: Column(children: [Expanded(child: busy ? const Center(child: CircularProgressIndicator()) : error != null ? Center(child: Text(error!)) : messages.isEmpty ? const EmptyHint('No messages yet.') : ListView(reverse: true, padding: const EdgeInsets.all(12), children: messages.map((message) => ListTile(title: Text(message.body), subtitle: Text(_date(message.createdAt.toIso8601String())))).toList()),), SafeArea(child: Padding(padding: const EdgeInsets.all(8), child: Row(children: [Expanded(child: TextField(controller: body, minLines: 1, maxLines: 4, decoration: deco('Message'))), IconButton(tooltip: 'Send message', icon: const Icon(Icons.send), onPressed: _send)])))]));

  Future<void> _load() async {
    try {
      final repository = widget.state.chatRepository;
      if (repository == null) throw const ChatException('Chat session is unavailable.');
      messages = await repository.messages(widget.room.id);
    } catch (e) {
      error = '$e';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _send() async {
    final text = body.text.trim();
    final repository = widget.state.chatRepository;
    if (text.isEmpty || repository == null) return;
    try {
      await repository.sendMessage(roomId: widget.room.id, body: text);
      body.clear();
      await _load();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }
}

class Dashboard extends StatelessWidget {
  const Dashboard({super.key, required this.state, required this.onNavigate});
  final KitsuneState state;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final next = state.nextDose;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text('Welcome, ${state.displayName}', style: Theme.of(context).textTheme.headlineSmall),
        Text('${state.daysOnHrt} days since HRT began'),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _MetricCard(label: 'Adherence', value: '${state.adherencePercent().round()}%', icon: Icons.check_circle_outline)),
          const SizedBox(width: 10),
          Expanded(child: _MetricCard(label: 'Entries', value: '${state.fieldEntries.length}', icon: Icons.edit_note)),
        ]),
        KitsuneCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle('Next scheduled dose'),
          Text(next == null ? 'No medication added yet' : '${next['name']} - ${next['dose']} ${next['dose_units'] ?? ''}'),
          if (next != null) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              FilledButton.icon(icon: const Icon(Icons.done), label: const Text('Taken'), onPressed: () => state.logDose(medicationId: next['id'] as int, status: 'taken')),
              OutlinedButton.icon(icon: const Icon(Icons.remove_circle_outline), label: const Text('Missed'), onPressed: () => state.logDose(medicationId: next['id'] as int, status: 'missed')),
            ]),
          ],
        ])),
        SectionTitle('Quick actions'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ActionChip(avatar: const Icon(Icons.medication, size: 18), label: const Text('Medications'), onPressed: () => onNavigate(1)),
          ActionChip(avatar: const Icon(Icons.add_chart, size: 18), label: const Text('Progress'), onPressed: () => onNavigate(2)),
          ActionChip(avatar: const Icon(Icons.note_add_outlined, size: 18), label: const Text('Journal'), onPressed: () => _journal(context)),
          ActionChip(avatar: const Icon(Icons.warning_amber_outlined, size: 18), label: const Text('Symptom'), onPressed: () => _symptom(context)),
        ]),
        SectionTitle('Recent activity'),
        if (state.timeline().isEmpty) const EmptyHint('Your private timeline will appear here as you log care, changes, and milestones.')
        else ...state.timeline().take(5).map((item) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.circle_outlined),
              title: Text(item['title']!),
              subtitle: Text(_date(item['date'])),
            )),
      ],
    );
  }

  Future<void> _journal(BuildContext context) async {
    final controller = TextEditingController();
    await showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Private journal note'), content: TextField(controller: controller, maxLines: 5, decoration: deco('Write only what feels right')), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), FilledButton(onPressed: () { if (controller.text.trim().isNotEmpty) state.addJournal(controller.text.trim()); Navigator.pop(ctx); }, child: const Text('Save'))]));
  }

  Future<void> _symptom(BuildContext context) async {
    final controller = TextEditingController();
    await showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Log a symptom'), content: TextField(controller: controller, decoration: deco('Symptom')), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), FilledButton(onPressed: () { if (controller.text.trim().isNotEmpty) state.addSymptom(controller.text.trim(), 1, ''); Navigator.pop(ctx); }, child: const Text('Save'))]));
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => KitsuneCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon), const SizedBox(height: 8), Text(value, style: Theme.of(context).textTheme.headlineSmall), Text(label)]));
}

class MedicationsPage extends StatelessWidget {
  const MedicationsPage({super.key, required this.state});
  final KitsuneState state;
  @override
  Widget build(BuildContext context) => _RecordsPage(
        title: 'Medications',
        state: state,
        empty: 'Add each medication separately so dose history and refills stay clear.',
        records: state.medications,
        action: () => _medicationDialog(context),
        builder: (m) => ExpansionTile(
          leading: const Icon(Icons.medication_outlined),
          title: Text('${m['name']}'),
          subtitle: Text('${m['dose'] ?? ''} ${m['dose_units'] ?? ''} ${m['route'] ?? ''}'),
          trailing: Text(state.remainingDoses(m)?.toString() ?? ''),
          children: [
              ...state.medicationSchedules.where((schedule) => schedule['medication_id'] == m['id']).map((schedule) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.schedule),
                    title: Text('${schedule['recurrence']} at ${schedule['time_of_day']}'),
                    subtitle: Text('Next: ${_date(state.nextScheduledDose(m['id'] as int)?.toIso8601String())}'),
                    trailing: IconButton(tooltip: 'Delete schedule', icon: const Icon(Icons.delete_outline), onPressed: () => state.deleteMedicationSchedule(schedule['id'] as int)),
                  )),
              ListTile(leading: const Icon(Icons.add_alarm), title: const Text('Add schedule'), onTap: () => _scheduleDialog(context, m)),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Align(alignment: Alignment.centerLeft, child: Text(state.missedPattern()))),
            ...state.doses.where((d) => d['medication_id'] == m['id']).take(8).map((d) => ListTile(
                  dense: true,
                  leading: Icon(d['status'] == 'missed' ? Icons.remove_circle_outline : Icons.check_circle_outline),
                  title: Text('${d['status']}'),
                  subtitle: Text(_date('${d['actual_at'] ?? d['scheduled_at']}')),
                  trailing: d['id'] == null ? null : IconButton(tooltip: 'Delete dose log', icon: const Icon(Icons.delete_outline), onPressed: () => state.deleteDose(d['id'] as int)),
                )),
          ],
        ),
      );

  Future<void> _medicationDialog(BuildContext context) async {
    final name = TextEditingController();
    final dose = TextEditingController();
    final units = TextEditingController();
    await showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Add medication'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: deco('Medication name')), TextField(controller: dose, decoration: deco('Dose')), TextField(controller: units, decoration: deco('Units (mg, mL, etc.)'))]), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), FilledButton(onPressed: () { if (name.text.trim().isNotEmpty) state.saveMedication({'name': name.text.trim(), 'dose': dose.text.trim(), 'dose_units': units.text.trim(), 'status': 'active', 'start_date': DateTime.now().toIso8601String()}); Navigator.pop(ctx); }, child: const Text('Add'))]));
  }

  Future<void> _scheduleDialog(BuildContext context, Map<String, Object?> medication) async {
    var recurrence = 'daily';
    var notifications = false;
    var time = const TimeOfDay(hour: 9, minute: 0);
    final interval = TextEditingController(text: '1');
    await showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) => AlertDialog(title: Text('Schedule ${medication['name']}'), content: Column(mainAxisSize: MainAxisSize.min, children: [DropdownButtonFormField<String>(value: recurrence, decoration: deco('Recurrence'), items: const [DropdownMenuItem(value: 'daily', child: Text('Daily')), DropdownMenuItem(value: 'weekly', child: Text('Weekly')), DropdownMenuItem(value: 'interval', child: Text('Every number of days'))], onChanged: (value) => setDialog(() => recurrence = value ?? recurrence)), if (recurrence == 'interval') TextField(controller: interval, keyboardType: TextInputType.number, decoration: deco('Interval in days')), ListTile(contentPadding: EdgeInsets.zero, title: const Text('Time'), subtitle: Text(time.format(context)), trailing: const Icon(Icons.schedule), onTap: () async { final picked = await showTimePicker(context: context, initialTime: time); if (picked != null) setDialog(() => time = picked); }), SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Optional notifications'), value: notifications, onChanged: (value) => setDialog(() => notifications = value))])), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), FilledButton(onPressed: () { final now = DateTime.now(); state.saveMedicationSchedule({'medication_id': medication['id'], 'recurrence': recurrence, 'interval_days': int.tryParse(interval.text) ?? 1, 'time_of_day': '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}', 'start_date': DateTime(now.year, now.month, now.day).toIso8601String(), 'timezone': now.timeZoneName, 'enabled': 1, 'notifications_enabled': notifications ? 1 : 0}); Navigator.pop(ctx); }, child: const Text('Save'))])));
  }
}

class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key, required this.state});
  final KitsuneState state;
  @override
  Widget build(BuildContext context) {
    final grouped = FieldCatalog.grouped(state.profile);
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Progress and care', style: Theme.of(context).textTheme.headlineSmall),
        IconButton(tooltip: 'Add transition entry', icon: const Icon(Icons.add), onPressed: () => _fieldDialog(context, grouped)),
      ]),
      const Text('Track HRT changes, health context, and your own words. Nothing here diagnoses, scores, or decides what progress means.'),
      KitsuneCard(child: Wrap(spacing: 8, runSpacing: 8, children: [
        ActionChip(avatar: const Icon(Icons.science_outlined, size: 18), label: const Text('Lab result'), onPressed: () => _labDialog(context)),
        ActionChip(avatar: const Icon(Icons.show_chart, size: 18), label: const Text('Lab trends'), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LabDashboard(state: state)))),
        ActionChip(avatar: const Icon(Icons.self_improvement, size: 18), label: const Text('Wellbeing'), onPressed: () => _wellbeingDialog(context)),
        ActionChip(avatar: const Icon(Icons.shield_outlined, size: 18), label: const Text('Support plan'), onPressed: () => _supportDialog(context)),
        ActionChip(avatar: const Icon(Icons.spa_outlined, size: 18), label: const Text('Toolkit'), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SupportToolkitPage(state: state)))),
        ActionChip(avatar: const Icon(Icons.auto_awesome, size: 18), label: const Text('AI overview'), onPressed: () => _aiOverview(context)),
        ActionChip(avatar: const Icon(Icons.event_outlined, size: 18), label: const Text('Appointment'), onPressed: () => _appointmentDialog(context)),
        ActionChip(avatar: const Icon(Icons.photo_camera_outlined, size: 18), label: const Text('Timeline photo'), onPressed: () => state.pickPhoto(category: 'transition')),
      ])),
      const SectionTitle('HRT health records'),
      if (state.labs.isEmpty) const EmptyHint('Add lab values with timing and provider context when you choose.') else ...state.labs.take(5).map((l) => ListTile(leading: const Icon(Icons.science_outlined), title: Text('${l['test_name']}'), subtitle: Text('${l['value']} ${l['unit'] ?? ''} - ${_date('${l['date']}')}'))),
      const SectionTitle('Trauma-informed support'),
      if (state.supportNotes.isEmpty) const EmptyHint('Keep grounding tools, boundaries, consent preferences, and safety plans private and optional.') else ...state.supportNotes.take(5).map((n) => ListTile(leading: const Icon(Icons.shield_outlined), title: Text('${n['title']}'), subtitle: Text('${n['kind']} - ${n['body'] ?? ''}'))),
      const SectionTitle('Transition entries'),
      if (state.fieldEntries.isEmpty) const EmptyHint('Choose a private field to track. Nothing is scored or shared.') else ...state.fieldEntries.take(30).map((e) => ListTile(leading: const Icon(Icons.timeline), title: Text('${e['field_id']}'), subtitle: Text('${e['value']} - ${_date('${e['recorded_at']}')}'))),
    ];
  }

  Future<void> _labDialog(BuildContext context) async {
    final test = TextEditingController();
    final value = TextEditingController();
    final unit = TextEditingController();
    final timing = TextEditingController();
    await showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Record a lab result'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: test, decoration: deco('Test name')), TextField(controller: value, decoration: deco('Value')), TextField(controller: unit, decoration: deco('Unit')), TextField(controller: timing, decoration: deco('Medication timing, if useful'))])), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), FilledButton(onPressed: () { if (test.text.trim().isNotEmpty) state.addLab({'test_name': test.text.trim(), 'value': value.text.trim(), 'unit': unit.text.trim(), 'date': DateTime.now().toIso8601String(), 'medication_timing': timing.text.trim()}); Navigator.pop(ctx); }, child: const Text('Save'))]));
  }

  Future<void> _wellbeingDialog(BuildContext context) async {
    final notes = TextEditingController();
    String? energy = 'steady';
    String? sleep = 'steady';
    await showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) => AlertDialog(title: const Text('Optional wellbeing check-in'), content: Column(mainAxisSize: MainAxisSize.min, children: [DropdownButtonFormField<String>(value: energy, decoration: deco('Energy, in your own words'), items: const [DropdownMenuItem(value: 'low', child: Text('Low')), DropdownMenuItem(value: 'steady', child: Text('Steady')), DropdownMenuItem(value: 'high', child: Text('High')), DropdownMenuItem(value: 'skip', child: Text('Prefer not to say'))], onChanged: (v) => setDialog(() => energy = v)), DropdownButtonFormField<String>(value: sleep, decoration: deco('Sleep, in your own words'), items: const [DropdownMenuItem(value: 'low', child: Text('Restless')), DropdownMenuItem(value: 'steady', child: Text('Okay')), DropdownMenuItem(value: 'high', child: Text('Restful')), DropdownMenuItem(value: 'skip', child: Text('Prefer not to say'))], onChanged: (v) => setDialog(() => sleep = v)), TextField(controller: notes, maxLines: 3, decoration: deco('Optional notes'))])), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Skip')), FilledButton(onPressed: () { state.addWellbeing({'date': DateTime.now().toIso8601String(), 'energy': _wellbeingValue(energy), 'sleep': _wellbeingValue(sleep), 'notes': notes.text.trim()}); Navigator.pop(ctx); }, child: const Text('Save'))])));
  }

  Future<void> _supportDialog(BuildContext context) async {
    final title = TextEditingController();
    final body = TextEditingController();
    final activation = TextEditingController();
    final response = TextEditingController();
    final consent = TextEditingController();
    String kind = 'grounding';
    var showTimeline = false;
    var searchable = false;
    var aiAllowed = false;
    var exportAllowed = false;
    await showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) => AlertDialog(title: const Text('Private support plan'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [DropdownButtonFormField<String>(value: kind, decoration: deco('Type'), items: const [DropdownMenuItem(value: 'grounding', child: Text('Grounding tool')), DropdownMenuItem(value: 'safety', child: Text('Safety plan')), DropdownMenuItem(value: 'boundaries', child: Text('Boundary or consent preference')), DropdownMenuItem(value: 'trigger', child: Text('Trigger context')), DropdownMenuItem(value: 'self_compassion', child: Text('Self-compassion note'))], onChanged: (v) => setDialog(() => kind = v ?? kind)), TextField(controller: title, decoration: deco('Short title')), TextField(controller: body, maxLines: 3, decoration: deco('What would you like to remember?')), TextField(controller: activation, decoration: deco('Optional: when might this help?')), TextField(controller: response, decoration: deco('Optional: what response feels supportive?')), TextField(controller: consent, decoration: deco('Optional: consent or privacy preference')), const SizedBox(height: 8), SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Show in timeline'), value: showTimeline, onChanged: (value) => setDialog(() => showTimeline = value)), SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Allow search'), value: searchable, onChanged: (value) => setDialog(() => searchable = value)), SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Allow AI access'), subtitle: const Text('Only if separately selected for an AI request'), value: aiAllowed, onChanged: (value) => setDialog(() => aiAllowed = value)), SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Include in exports'), value: exportAllowed, onChanged: (value) => setDialog(() => exportAllowed = value))])), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), FilledButton(onPressed: title.text.trim().isEmpty ? null : () { state.addSupportNote(kind: kind, title: title.text.trim(), body: body.text.trim(), activation: activation.text.trim(), preferredResponse: response.text.trim(), consent: consent.text.trim(), showTimeline: showTimeline, searchable: searchable, aiAllowed: aiAllowed, exportAllowed: exportAllowed); Navigator.pop(ctx); }, child: const Text('Save privately'))])));
  }

  Future<void> _appointmentDialog(BuildContext context) async {
    final title = TextEditingController();
    final kind = TextEditingController(text: 'healthcare');
    final notes = TextEditingController();
    await showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Add appointment'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: title, decoration: deco('Title')), TextField(controller: kind, decoration: deco('Type or provider')), TextField(controller: notes, maxLines: 3, decoration: deco('Notes or questions to bring'))]), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), FilledButton(onPressed: title.text.trim().isEmpty ? null : () { state.addAppointment({'title': title.text.trim(), 'kind': kind.text.trim(), 'date': DateTime.now().toIso8601String(), 'notes': notes.text.trim()}); Navigator.pop(ctx); }, child: const Text('Save'))]));
  }

  Future<void> _aiOverview(BuildContext context) async {
    if (!state.aiEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enable optional AI in Settings first.')));
      return;
    }
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => const AlertDialog(content: Row(children: [CircularProgressIndicator(), SizedBox(width: 16), Expanded(child: Text('Asking the selected AI provider...'))])));
    try {
      final result = await state.aiTrendOverview();
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('AI trend overview'), content: SingleChildScrollView(child: Text(result)), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))]));
    } catch (error) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('AI unavailable'), content: Text('$error'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))]));
    }
  }

  Future<void> _fieldDialog(BuildContext context, Map<String, List<CatalogField>> grouped) async {
    CatalogField? selected;
    final value = TextEditingController();
    await showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) => AlertDialog(title: const Text('Log progress'), content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [DropdownButtonFormField<CatalogField>(decoration: deco('What would you like to track?'), items: [for (final group in grouped.values) ...group.map((f) => DropdownMenuItem(value: f, child: Text(f.label)))], onChanged: (f) => setDialog(() => selected = f)), TextField(controller: value, decoration: deco('Your value'))])), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), FilledButton(onPressed: selected == null || value.text.trim().isEmpty ? null : () { state.addFieldEntry(selected!.id, value.text.trim()); Navigator.pop(ctx); }, child: const Text('Save'))])));
  }
}

class LabDashboard extends StatefulWidget {
  const LabDashboard({super.key, required this.state});
  final KitsuneState state;

  @override
  State<LabDashboard> createState() => _LabDashboardState();
}

class _LabDashboardState extends State<LabDashboard> {
  String? analyte;

  @override
  Widget build(BuildContext context) {
    final names = widget.state.labs.map((lab) => '${lab['test_name']}').where((name) => name.isNotEmpty).toSet().toList()..sort();
    analyte ??= names.isEmpty ? null : names.first;
    final values = widget.state.labs.where((lab) => '${lab['test_name']}' == analyte).map((lab) => (date: DateTime.tryParse('${lab['date']}') ?? DateTime.now(), value: double.tryParse('${lab['value']}'))).where((item) => item.value != null).toList()..sort((a, b) => a.date.compareTo(b.date));
    return Scaffold(appBar: AppBar(title: const Text('Lab trends')), body: ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Charts organize recorded values; they do not determine whether a result is safe or unsafe. Discuss interpretation with a qualified clinician.'),
      const SizedBox(height: 12),
      if (names.isEmpty) const EmptyHint('Add a numeric lab result to see a trend.') else DropdownButtonFormField<String>(value: analyte, decoration: deco('Analyte'), items: names.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(), onChanged: (value) => setState(() => analyte = value)),
      const SizedBox(height: 16),
      if (values.length < 2) const EmptyHint('At least two numeric results are needed for a trend chart.') else SizedBox(height: 260, child: LineChart(LineChartData(titlesData: const FlTitlesData(show: false), borderData: FlBorderData(show: true), lineBarsData: [LineChartBarData(isCurved: true, spots: [for (var index = 0; index < values.length; index++) FlSpot(index.toDouble(), values[index].value!)]),]))),
      const SectionTitle('Recorded values'),
      ...values.reversed.map((item) => ListTile(leading: const Icon(Icons.science_outlined), title: Text('${item.value}'), subtitle: Text(_date(item.date.toIso8601String())))),
    ]));
  }
}

class SupportToolkitPage extends StatelessWidget {
  const SupportToolkitPage({super.key, required this.state});
  final KitsuneState state;

  @override
  Widget build(BuildContext context) {
    final grounding = state.supportNotes.where((note) => note['kind'] == 'grounding').toList();
    final safety = state.supportNotes.where((note) => note['kind'] == 'safety').toList();
    return Scaffold(appBar: AppBar(title: const Text('Support toolkit')), body: ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Use only what feels appropriate. You can stop at any time. KITSUNE does not monitor emergencies or replace professional support.'),
      const SectionTitle('Grounding now'),
      const ListTile(leading: Icon(Icons.visibility_outlined), title: Text('Orient to the room'), subtitle: Text('Name five things you can see, four you can feel, three you can hear, two you can smell, and one you can taste. Skip any step that feels unhelpful.')),
      const ListTile(leading: Icon(Icons.air), title: Text('Gentle breathing'), subtitle: Text('Try a comfortable inhale and a slightly longer exhale. Stop if focusing on breathing feels uncomfortable.')),
      if (grounding.isNotEmpty) ...[const SectionTitle('Your grounding notes'), ...grounding.map((note) => ListTile(leading: const Icon(Icons.bookmark_outline), title: Text('${note['title']}'), subtitle: Text('${note['body'] ?? ''}')))],
      const SectionTitle('Safety plan'),
      if (safety.isEmpty) const EmptyHint('Add a private safety plan from Progress. It is stored on this device.') else ...safety.map((note) => ListTile(leading: const Icon(Icons.shield_outlined), title: Text('${note['title']}'), subtitle: Text('${note['body'] ?? ''}'))),
      const SizedBox(height: 12),
      const Text('If you may be in immediate danger, contact local emergency services or a crisis service in your region. This app cannot contact help automatically.'),
    ]));
  }
}

int _wellbeingValue(String? value) => switch (value) { 'low' => 1, 'high' => 3, 'skip' => 0, _ => 2 };

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, required this.state});
  final KitsuneState state;
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime day = DateTime.now();
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [CalendarDatePicker(initialDate: day, firstDate: DateTime(2000), lastDate: DateTime(2100), onDateChanged: (d) => setState(() => day = d)), SectionTitle('Events for ${DateFormat.yMMMd().format(day)}'), ...widget.state.eventsFor(day).map((e) => ListTile(leading: Icon(_icon(e['kind'] as String)), title: Text('${e['kind']}'), subtitle: Text('${e['name'] ?? e['title'] ?? e['field_id'] ?? e['status'] ?? ''}'))), if (widget.state.eventsFor(day).isEmpty) const EmptyHint('No entries for this day.')]);
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.state});
  final KitsuneState state;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
        const SectionTitle('Appearance'),
        DropdownButtonFormField<ThemeMode>(value: state.themeMode, decoration: deco('Theme'), items: const [DropdownMenuItem(value: ThemeMode.system, child: Text('System')), DropdownMenuItem(value: ThemeMode.light, child: Text('Light')), DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark'))], onChanged: (v) { if (v != null) state.setTheme(v); }),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('High contrast'), value: state.highContrast, onChanged: (v) => state.setAccess(contrast: v, scale: state.textScale)),
        const SectionTitle('Privacy and access'),
        const SectionTitle('Optional AI'),
        ListTile(leading: const Icon(Icons.auto_awesome), title: Text(state.aiEnabled ? 'AI enabled: ${state.aiProvider.label}' : 'Set up optional AI'), subtitle: Text(state.aiKeyConfigured ? 'Key stored securely on this device' : 'No provider key configured'), onTap: () => _aiSettings(context)),
        if (state.aiKeyConfigured) ListTile(leading: const Icon(Icons.wifi_tethering), title: const Text('Test AI connection'), subtitle: const Text('Sends only a fixed test phrase'), onTap: () => _testAi(context)),
        if (state.aiEnabled) ListTile(leading: const Icon(Icons.visibility_off_outlined), title: const Text('Disable AI consent'), subtitle: const Text('Stops AI requests immediately'), onTap: () => state.revokeAi()),
        ListTile(leading: const Icon(Icons.file_download_outlined), title: const Text('Export local data'), subtitle: const Text('CSV export stays under your control'), onTap: () async => Share.share(await state.db.exportCsv(), subject: 'KITSUNE export')),
        ListTile(leading: const Icon(Icons.assignment_outlined), title: const Text('Create redacted clinician report'), subtitle: const Text('Excludes journals, support plans, photos, keys, and online sessions'), onTap: () => _shareReport(context)),
        ListTile(leading: const Icon(Icons.picture_as_pdf_outlined), title: const Text('Share redacted PDF report'), subtitle: const Text('Uses the same privacy-limited report data'), onTap: () => _sharePdfReport()),
        ListTile(leading: const Icon(Icons.data_object), title: const Text('Share JSON backup'), onTap: () async => Share.share(jsonEncode(await state.db.dumpAll()), subject: 'KITSUNE backup')),
        ListTile(leading: const Icon(Icons.lock_outline), title: Text(state.pinEnabled ? 'Change or remove PIN' : 'Set a PIN'), onTap: () => _pin(context)),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Biometric unlock'), value: state.biometricEnabled, onChanged: (v) => state.setBiometric(v)),
        ListTile(leading: const Icon(Icons.delete_forever_outlined), title: const Text('Delete all tracked data'), onTap: () async { if (await confirmDelete(context, title: 'Delete everything?', body: 'This permanently removes local records and disables AI access.')) { await state.db.deleteEverything(); await state.clearAiKey(); await state.revokeAi(); await state.reload(); } }),
        const SizedBox(height: 12),
        const Text('KITSUNE is offline-first. It does not require an account, identity disclosure, reminders, journaling, recovery scoring, or automatic sharing.'),
      ]);

  Future<void> _pin(BuildContext context) async {
    final controller = TextEditingController();
    await showDialog(context: context, builder: (ctx) => AlertDialog(title: Text(state.pinEnabled ? 'Replace PIN' : 'Set a PIN'), content: TextField(controller: controller, keyboardType: TextInputType.number, obscureText: true, decoration: deco('PIN')), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), if (state.pinEnabled) TextButton(onPressed: () { state.clearPin(); Navigator.pop(ctx); }, child: const Text('Remove')), FilledButton(onPressed: () { if (controller.text.length >= 4) state.setPin(controller.text); Navigator.pop(ctx); }, child: const Text('Save'))]));
  }

  Future<void> _shareReport(BuildContext context) async {
    await Share.share(state.redactedReportCsv(), subject: 'KITSUNE redacted clinician report');
  }

  Future<void> _sharePdfReport() async {
    final document = pw.Document();
    final report = state.redactedReportCsv();
    final lines = report.split('\n');
    for (var start = 0; start < lines.length; start += 80) {
      final pageLines = lines.skip(start).take(80).join('\n');
      document.addPage(pw.Page(build: (_) => pw.Text(pageLines)));
    }
    await Printing.sharePdf(bytes: await document.save(), filename: 'kitsune_redacted_report.pdf');
  }

  Future<void> _aiSettings(BuildContext context) async {
    final key = TextEditingController();
    final model = TextEditingController(text: state.aiModel);
    final endpoint = TextEditingController(text: state.aiEndpoint);
    var provider = state.aiProvider;
    await showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) => AlertDialog(title: const Text('Optional AI setup'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('AI is not secure or private. Anything sent to a provider leaves this phone and may be retained or processed under that provider\'s policies. KITSUNE cannot guarantee deletion or confidentiality.'), const SizedBox(height: 12), DropdownButtonFormField<AiProvider>(value: provider, decoration: deco('Provider'), items: [for (final item in AiProvider.values) DropdownMenuItem(value: item, child: Text(item.label))], onChanged: (value) => setDialog(() => provider = value ?? provider)), TextField(controller: model, decoration: deco('Model')), if (provider == AiProvider.openAiCompatible) TextField(controller: endpoint, decoration: deco('HTTPS endpoint')), TextField(controller: key, obscureText: true, decoration: deco(state.aiKeyConfigured ? 'New API key (leave blank to keep current)' : 'API key'))])), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), if (state.aiKeyConfigured) TextButton(onPressed: () { state.clearAiKey(); Navigator.pop(ctx); }, child: const Text('Delete key')), FilledButton(onPressed: () async { if (key.text.trim().isEmpty && !state.aiKeyConfigured) return; await state.configureAi(provider: provider, model: model.text, key: key.text.trim().isEmpty ? (await state.secure.read(key: 'ai_api_key') ?? '') : key.text, endpoint: endpoint.text); if (ctx.mounted) Navigator.pop(ctx); if (context.mounted) _aiConsent(context); }, child: const Text('Continue'))])));
  }

  Future<void> _aiConsent(BuildContext context) async {
    var aggregate = true;
    var wellbeing = false;
    final accepted = await showDialog<bool>(context: context, barrierDismissible: false, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) => AlertDialog(title: const Text('Confirm AI privacy choice'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('AI can be wrong. It is not a clinician and must not be used for diagnosis, dosage changes, treatment decisions, or trauma recovery judgments.'), CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('Aggregate HRT trends'), subtitle: const Text('Counts, adherence percentage, and record totals'), value: aggregate, onChanged: (value) => setDialog(() => aggregate = value ?? false)), CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('Wellbeing totals'), subtitle: const Text('Number of check-ins only, not journal text'), value: wellbeing, onChanged: (value) => setDialog(() => wellbeing = value ?? false))])), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Do not enable')), FilledButton(onPressed: aggregate ? () => Navigator.pop(ctx, true) : null, child: const Text('I understand and enable'))])));
    if (accepted == true) {
      await state.acceptAiConsent(categories: {if (aggregate) 'aggregate_trends', if (wellbeing) 'wellbeing_totals'});
    }
  }

  Future<void> _testAi(BuildContext context) async {
    try {
      await state.testAiConnection();
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AI connection confirmed.')));
    } catch (error) {
      if (context.mounted) showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Connection test failed'), content: Text('$error'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))]));
    }
  }
}

class _RecordsPage extends StatelessWidget {
  const _RecordsPage({required this.title, required this.state, required this.empty, required this.records, required this.action, required this.builder});
  final String title;
  final KitsuneState state;
  final String empty;
  final List<Map<String, Object?>> records;
  final VoidCallback action;
  final Widget Function(Map<String, Object?>) builder;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: Theme.of(context).textTheme.headlineSmall), IconButton(tooltip: 'Add', icon: const Icon(Icons.add), onPressed: action)]), if (records.isEmpty) EmptyHint(empty) else ...records.map(builder)]);
}

class RecordSearch extends SearchDelegate<void> {
  RecordSearch(this.state);
  final KitsuneState state;
  @override
  List<Widget>? buildActions(BuildContext context) => [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];
  @override
  Widget? buildLeading(BuildContext context) => IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));
  @override
  Widget buildResults(BuildContext context) => _results();
  @override
  Widget buildSuggestions(BuildContext context) => _results();
  Widget _results() { final results = state.search(query); return ListView(children: results.map((r) => ListTile(title: Text(r['title']!), subtitle: Text('${r['type']}: ${r['subtitle']}'))).toList()); }
}

String _date(String? value) => value == null ? '' : (DateTime.tryParse(value) == null ? value : DateFormat.yMMMd().format(DateTime.parse(value)));
IconData _icon(String kind) => switch (kind) { 'dose' => Icons.medication, 'symptom' => Icons.warning_amber, 'lab' => Icons.science_outlined, 'appointment' => Icons.event, 'photo' => Icons.photo, _ => Icons.circle_outlined };