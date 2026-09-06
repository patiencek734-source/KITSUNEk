import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'app_database.dart';
import 'catalog.dart';
import '../services/ai_provider_service.dart';
import '../services/chat_repository.dart';
import '../services/online_auth_service.dart';
import '../services/online_config.dart';

class KitsuneState extends ChangeNotifier {
  final db = AppDatabase.instance;
  final secure = const FlutterSecureStorage();
  final auth = LocalAuthentication();
  final notifications = FlutterLocalNotificationsPlugin();
  final aiService = AiProviderService();
  final onlineConfig = OnlineConfig.current;
  late final OnlineAuthService onlineAuth = OnlineAuthService(config: onlineConfig, secure: secure);

  bool ready = false;
  bool unlocked = false;
  bool onboarded = false;
  bool pinEnabled = false;
  bool biometricEnabled = false;
  ThemeMode themeMode = ThemeMode.dark;
  bool highContrast = false;
  double textScale = 1.0;
  String displayName = '';
  String profile = 'trans_men';
  DateTime? hrtStart;
  AiProvider aiProvider = AiProvider.groq;
  String aiModel = 'llama-3.1-8b-instant';
  String aiEndpoint = '';
  bool aiConsentAccepted = false;
  bool aiEnabled = false;
  Set<String> aiCategories = <String>{'aggregate_trends'};
  bool aiKeyConfigured = false;
  String? lastAiError;
  OnlineSession? onlineSession;
  List<ChatRoom> chatRooms = [];
  ChatRepository? chatRepository;
  bool get onlineChatConfigured => onlineConfig.isConfigured;
  bool get onlineChatSignedIn => onlineSession != null;

  List<Map<String, Object?>> medications = [];
  List<Map<String, Object?>> doses = [];
  List<Map<String, Object?>> labs = [];
  List<Map<String, Object?>> photos = [];
  List<Map<String, Object?>> wellbeing = [];
  List<Map<String, Object?>> journal = [];
  List<Map<String, Object?>> appointments = [];
  List<Map<String, Object?>> reminders = [];
  List<Map<String, Object?>> symptoms = [];
  List<Map<String, Object?>> fieldEntries = [];
  List<Map<String, Object?>> customFields = [];
  List<Map<String, Object?>> customValues = [];
  List<Map<String, Object?>> supportNotes = [];
  List<Map<String, Object?>> medicationSchedules = [];

  Map<String, Object?>? lastDeletedDose;

  Future<void> bootstrap() async {
    await notifications.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    );
    final prefs = await SharedPreferences.getInstance();
    final tm = prefs.getString('themeMode') ?? 'dark';
    themeMode = switch (tm) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
    highContrast = prefs.getBool('highContrast') ?? false;
    textScale = prefs.getDouble('textScale') ?? 1.0;
    displayName = await db.setting('displayName') ?? '';
    profile = await db.setting('profile') ?? 'trans_men';
    final start = await db.setting('hrtStart');
    if (start != null && start.isNotEmpty) hrtStart = DateTime.tryParse(start);
    onboarded = (await db.setting('onboarded')) == '1';
    pinEnabled = (await secure.read(key: 'pin_hash')) != null;
    biometricEnabled = (await db.setting('biometric')) == '1';
    aiProvider = AiProviderLabel.fromId(await db.setting('aiProvider'));
    aiModel = await db.setting('aiModel') ?? _defaultAiModel(aiProvider);
    aiEndpoint = await db.setting('aiEndpoint') ?? '';
    aiConsentAccepted = (await db.setting('aiConsentAccepted')) == '1';
    aiEnabled = (await db.setting('aiEnabled')) == '1';
    final categories = await db.setting('aiCategories');
    if (categories != null && categories.isNotEmpty) {
      aiCategories = categories.split(',').where((item) => item.isNotEmpty).toSet();
    }
    aiKeyConfigured = (await secure.read(key: 'ai_api_key'))?.isNotEmpty == true;
    onlineSession = await onlineAuth.restoreSession();
    if (onlineSession != null) {
      chatRepository = ChatRepository(config: onlineConfig, accessToken: onlineSession!.accessToken, userId: onlineSession!.userId);
      await refreshChatRooms();
    }
    unlocked = !pinEnabled;
    await reload();
    ready = true;
    notifyListeners();
  }

  Future<void> reload() async {
    medications = await db.all('medications', orderBy: 'name COLLATE NOCASE');
    doses = await db.all('dose_logs', where: 'deleted = 0', orderBy: 'actual_at DESC, scheduled_at DESC');
    labs = await db.all('labs', orderBy: 'date DESC');
    photos = await db.all('photos', orderBy: 'date DESC');
    wellbeing = await db.all('wellbeing', orderBy: 'date DESC');
    journal = await db.all('journal', orderBy: 'date DESC');
    appointments = await db.all('appointments', orderBy: 'date ASC');
    reminders = await db.all('reminders', orderBy: 'datetime ASC');
    symptoms = await db.all('symptoms', orderBy: 'date DESC');
    fieldEntries = await db.all('field_entries', orderBy: 'recorded_at DESC');
    customFields = await db.all('custom_fields', orderBy: 'name COLLATE NOCASE');
    customValues = await db.all('custom_values', orderBy: 'recorded_at DESC');
    supportNotes = await db.all('support_notes', orderBy: 'updated_at DESC');
    medicationSchedules = await db.all('medication_schedules', orderBy: 'start_date ASC');
    notifyListeners();
  }

  int get daysOnHrt {
    if (hrtStart == null) return 0;
    return DateTime.now().difference(hrtStart!).inDays;
  }

  List<CatalogField> get catalog => FieldCatalog.forProfile(profile);

  Future<void> completeOnboarding({
    required String name,
    required String selectedProfile,
    required DateTime start,
  }) async {
    displayName = name;
    profile = selectedProfile;
    hrtStart = start;
    await db.setSetting('displayName', name);
    await db.setSetting('profile', selectedProfile);
    await db.setSetting('hrtStart', start.toIso8601String());
    await db.setSetting('onboarded', '1');
    onboarded = true;
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode mode) async {
    themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
      _ => 'dark',
    });
    notifyListeners();
  }

  Future<void> setAccess({required bool contrast, required double scale}) async {
    highContrast = contrast;
    textScale = scale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('highContrast', contrast);
    await prefs.setDouble('textScale', scale);
    notifyListeners();
  }

  Future<void> setPin(String pin) async {
    final salt = const Uuid().v4();
    final hash = sha256.convert(utf8.encode('$salt:$pin')).toString();
    await secure.write(key: 'pin_salt', value: salt);
    await secure.write(key: 'pin_hash', value: hash);
    pinEnabled = true;
    unlocked = true;
    notifyListeners();
  }

  Future<void> clearPin() async {
    await secure.delete(key: 'pin_salt');
    await secure.delete(key: 'pin_hash');
    pinEnabled = false;
    unlocked = true;
    notifyListeners();
  }

  Future<bool> verifyPin(String pin) async {
    final salt = await secure.read(key: 'pin_salt') ?? '';
    final hash = await secure.read(key: 'pin_hash');
    final ok = hash == sha256.convert(utf8.encode('$salt:$pin')).toString();
    if (ok) {
      unlocked = true;
      notifyListeners();
    }
    return ok;
  }

  Future<bool> biometricUnlock() async {
    try {
      final ok = await auth.authenticate(
        localizedReason: 'Unlock KITSUNE',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
      if (ok) {
        unlocked = true;
        notifyListeners();
      }
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<void> setBiometric(bool v) async {
    biometricEnabled = v;
    await db.setSetting('biometric', v ? '1' : '0');
    notifyListeners();
  }

  void lock() {
    unlocked = false;
    notifyListeners();
  }

  Future<void> requestOnlineSignIn(String email) => onlineAuth.requestMagicLink(email);

  Future<void> verifyOnlineCode({required String email, required String code}) async {
    await restoreOnlineSession(await onlineAuth.verifyEmailCode(email: email, code: code));
  }

  Future<void> restoreOnlineSession(OnlineSession session) async {
    await onlineAuth.saveSession(session);
    onlineSession = session;
    chatRepository = ChatRepository(config: onlineConfig, accessToken: session.accessToken, userId: session.userId);
    await refreshChatRooms();
    notifyListeners();
  }

  Future<void> signOutOnline() async {
    await onlineAuth.signOut();
    onlineSession = null;
    chatRepository = null;
    chatRooms = [];
    notifyListeners();
  }

  Future<void> refreshChatRooms() async {
    final repository = chatRepository;
    if (repository == null) return;
    chatRooms = await repository.rooms();
    notifyListeners();
  }

  String _defaultAiModel(AiProvider provider) => switch (provider) {
        AiProvider.groq => 'llama-3.1-8b-instant',
        AiProvider.gemini => 'gemini-2.0-flash',
        AiProvider.anthropic => 'claude-3-5-haiku-latest',
        AiProvider.openAiCompatible => 'your-model',
      };

  Future<void> configureAi({
    required AiProvider provider,
    required String model,
    required String key,
    String endpoint = '',
  }) async {
    aiProvider = provider;
    aiModel = model.trim();
    aiEndpoint = endpoint.trim();
    await secure.write(key: 'ai_api_key', value: key.trim());
    await db.setSetting('aiProvider', provider.id);
    await db.setSetting('aiModel', aiModel);
    await db.setSetting('aiEndpoint', aiEndpoint);
    aiKeyConfigured = key.trim().isNotEmpty;
    aiEnabled = false;
    lastAiError = null;
    notifyListeners();
  }

  Future<void> acceptAiConsent({required Set<String> categories}) async {
    aiCategories = categories;
    aiConsentAccepted = true;
    aiEnabled = true;
    await db.setSetting('aiConsentAccepted', '1');
    await db.setSetting('aiEnabled', '1');
    await db.setSetting('aiCategories', categories.join(','));
    notifyListeners();
  }

  Future<void> revokeAi() async {
    aiEnabled = false;
    aiConsentAccepted = false;
    await db.setSetting('aiEnabled', '0');
    await db.setSetting('aiConsentAccepted', '0');
    notifyListeners();
  }

  Future<void> clearAiKey() async {
    await secure.delete(key: 'ai_api_key');
    aiKeyConfigured = false;
    aiEnabled = false;
    await db.setSetting('aiEnabled', '0');
    notifyListeners();
  }

  Future<String> aiTrendOverview() async {
    if (!unlocked) throw const AiProviderException('Unlock KITSUNE before using AI.');
    if (!aiEnabled || !aiConsentAccepted) throw const AiProviderException('Accept the AI privacy warning before using AI.');
    if (!aiCategories.contains('aggregate_trends')) throw const AiProviderException('Enable aggregate trend sharing first.');
    final key = await secure.read(key: 'ai_api_key');
    if (key == null || key.isEmpty) throw const AiProviderException('Add an AI API key first.');
    final prompt = '''You are an optional reflection tool inside a private HRT tracker. Do not diagnose, predict clinical outcomes, recommend medication changes, or claim to assess trauma recovery. Based only on these aggregate records, provide a concise non-diagnostic summary of patterns, uncertainty, and questions the person could discuss with a qualified clinician. Say when there is not enough data.

HRT days: $daysOnHrt
Medication count: ${medications.length}
Dose records in memory: ${doses.length}
Adherence over 30 days: ${adherencePercent().toStringAsFixed(1)}%
Lab records: ${labs.length}
Progress entries: ${fieldEntries.length}
Wellbeing check-ins: ${wellbeing.length}
Symptoms recorded: ${symptoms.length}
''';
    try {
      lastAiError = null;
      final result = await aiService.complete(config: AiProviderConfig(provider: aiProvider, apiKey: key, model: aiModel, endpoint: aiEndpoint.isEmpty ? null : aiEndpoint), prompt: prompt);
      notifyListeners();
      return result;
    } on AiProviderException catch (error) {
      lastAiError = error.message;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> testAiConnection() async {
    if (!unlocked) throw const AiProviderException('Unlock KITSUNE before testing AI.');
    final key = await secure.read(key: 'ai_api_key');
    if (key == null || key.isEmpty) throw const AiProviderException('Add an AI API key first.');
    await aiService.complete(
      config: AiProviderConfig(
        provider: aiProvider,
        apiKey: key,
        model: aiModel,
        endpoint: aiEndpoint.isEmpty ? null : aiEndpoint,
      ),
      prompt: 'Reply with exactly: KITSUNE connection confirmed.',
    );
  }

  Future<int> saveMedication(Map<String, Object?> values, {int? id}) async {
    if (id == null) {
      final newId = await db.insert('medications', values);
      await reload();
      return newId;
    }
    await db.update('medications', values, id);
    await reload();
    return id;
  }

  Future<void> saveMedicationSchedule(Map<String, Object?> values, {int? id}) async {
    if (id == null) {
      await db.insert('medication_schedules', values);
    } else {
      await db.update('medication_schedules', values, id);
    }
    await reload();
  }

  Future<void> deleteMedicationSchedule(int id) async {
    await db.delete('medication_schedules', id);
    await reload();
  }

  String redactedReportCsv({bool includeSymptoms = true, bool includeWellbeing = true}) {
    final buffer = StringBuffer();
    void section(String name, List<Map<String, Object?>> rows, List<String> columns) {
      buffer.writeln('# $name');
      buffer.writeln(columns.map(db.csvEscape).join(','));
      for (final row in rows) {
        buffer.writeln(columns.map((column) => db.csvEscape(row[column])).join(','));
      }
      buffer.writeln();
    }

    section('medications', medications, ['name', 'dose', 'dose_units', 'route', 'frequency', 'start_date', 'status']);
    section('dose_logs', doses, ['medication_id', 'scheduled_at', 'actual_at', 'status', 'notes']);
    section('labs', labs, ['test_name', 'value', 'unit', 'reference_range', 'date', 'medication_timing', 'peak_trough']);
    if (includeSymptoms) section('symptoms', symptoms, ['name', 'severity', 'date', 'notes']);
    if (includeWellbeing) section('wellbeing', wellbeing, ['date', 'mood', 'energy', 'sleep', 'stress', 'pain', 'motivation', 'dysphoria', 'confidence', 'overall', 'symptoms', 'notes']);
    section('progress', fieldEntries, ['field_id', 'value', 'recorded_at', 'source']);
    return buffer.toString();
  }

  DateTime? nextScheduledDose(int medicationId, {DateTime? from}) {
    final now = from ?? DateTime.now();
    DateTime? best;
    for (final schedule in medicationSchedules.where((item) => item['medication_id'] == medicationId && item['enabled'] != 0)) {
      final start = DateTime.tryParse('${schedule['start_date']}');
      if (start == null) continue;
      final parts = '${schedule['time_of_day']}'.split(':');
      final hour = int.tryParse(parts.first) ?? 0;
      final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
      var candidate = DateTime(now.year, now.month, now.day, hour, minute);
      if (candidate.isBefore(now)) candidate = candidate.add(const Duration(days: 1));
      final recurrence = '${schedule['recurrence']}';
      if (recurrence == 'weekly') {
        final weekdays = '${schedule['weekdays'] ?? ''}'.split(',').where((value) => value.isNotEmpty).map(int.parse).toSet();
        for (var i = 0; i < 7 && !weekdays.contains(candidate.weekday); i++) {
          candidate = candidate.add(const Duration(days: 1));
        }
      } else if (recurrence == 'interval') {
        final interval = (schedule['interval_days'] as num?)?.toInt() ?? 1;
        final daysSinceStart = candidate.difference(DateTime(start.year, start.month, start.day)).inDays;
        final remainder = daysSinceStart % interval;
        if (remainder != 0) candidate = candidate.add(Duration(days: interval - remainder));
      }
      final end = DateTime.tryParse('${schedule['end_date']}');
      if (candidate.isBefore(start) || (end != null && candidate.isAfter(end))) continue;
      if (best == null || candidate.isBefore(best)) best = candidate;
    }
    return best;
  }

  Future<void> deleteMedication(int id) async {
    await db.deleteWhere('medication_schedules', 'medication_id = ?', [id]);
    await db.delete('medications', id);
    await reload();
  }

  Future<void> logDose({
    required int medicationId,
    required String status,
    DateTime? scheduled,
    DateTime? actual,
    String notes = '',
  }) async {
    await db.insert('dose_logs', {
      'medication_id': medicationId,
      'scheduled_at': (scheduled ?? DateTime.now()).toIso8601String(),
      'actual_at': (actual ?? DateTime.now()).toIso8601String(),
      'status': status,
      'notes': notes,
      'deleted': 0,
    });
    if (status == 'taken' || status == 'late') {
      final med = medications.cast<Map<String, Object?>>().where((m) => m['id'] == medicationId);
      if (med.isNotEmpty) {
        final remaining = (med.first['remaining_quantity'] as num?)?.toDouble();
        final typical = (med.first['typical_dose'] as num?)?.toDouble();
        if (remaining != null && typical != null) {
          await db.update('medications', {'remaining_quantity': remaining - typical}, medicationId);
        }
      }
    }
    await reload();
  }

  Future<void> deleteDose(int id) async {
    final row = doses.firstWhere((d) => d['id'] == id);
    lastDeletedDose = Map<String, Object?>.from(row);
    await db.update('dose_logs', {'deleted': 1}, id);
    await reload();
  }

  Future<void> undoDoseDelete() async {
    final row = lastDeletedDose;
    if (row == null || row['id'] == null) return;
    await db.update('dose_logs', {'deleted': 0}, row['id'] as int);
    lastDeletedDose = null;
    await reload();
  }

  double adherencePercent({int days = 30}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final recent = doses.where((d) {
      final t = DateTime.tryParse('${d['scheduled_at'] ?? d['actual_at']}') ?? DateTime.now();
      return t.isAfter(cutoff);
    }).toList();
    if (recent.isEmpty) return 0;
    final taken = recent.where((d) => d['status'] == 'taken' || d['status'] == 'late').length;
    return taken * 100 / recent.length;
  }

  String missedPattern() {
    final missed = doses.where((d) => d['status'] == 'missed').toList();
    if (missed.length >= 3) return 'Several missed doses in history — check your schedule.';
    if (missed.isEmpty) return 'No missed-dose pattern detected.';
    return '${missed.length} missed dose(s) recorded.';
  }

  int? remainingDoses(Map<String, Object?> med) {
    final remaining = (med['remaining_quantity'] as num?)?.toDouble();
    final typical = (med['typical_dose'] as num?)?.toDouble();
    if (remaining == null || typical == null || typical == 0) return null;
    return (remaining / typical).floor();
  }

  Map<String, Object?>? get nextDose {
    if (medications.isEmpty) return null;
    final active = medications.where((m) => '${m['status'] ?? 'active'}' != 'stopped').toList();
    if (active.isEmpty) return null;
    return active.first;
  }

  Future<void> addFieldEntry(String fieldId, String value, {String notes = '', String source = 'user_estimated'}) async {
    await db.insert('field_entries', {
      'field_id': fieldId,
      'value': value,
      'recorded_at': DateTime.now().toIso8601String(),
      'notes': notes,
      'source': source,
    });
    await reload();
  }

  Future<void> addLab(Map<String, Object?> values) async {
    await db.insert('labs', values);
    await reload();
  }

  Future<void> addSymptom(String name, int severity, String notes) async {
    await db.insert('symptoms', {
      'name': name,
      'severity': severity,
      'date': DateTime.now().toIso8601String(),
      'notes': notes,
    });
    await reload();
  }

  Future<void> addWellbeing(Map<String, Object?> values) async {
    await db.insert('wellbeing', values);
    await reload();
  }

  Future<void> addSupportNote({
    required String kind,
    required String title,
    required String body,
    String activation = '',
    String preferredResponse = '',
    String consent = '',
    String visibility = 'private',
    bool requireUnlock = true,
    bool showTimeline = false,
    bool searchable = false,
    bool aiAllowed = false,
    bool exportAllowed = false,
  }) async {
    final now = DateTime.now().toIso8601String();
    await db.insert('support_notes', {
      'kind': kind,
      'title': title,
      'body': body,
      'activation': activation,
      'preferred_response': preferredResponse,
      'consent': consent,
      'created_at': now,
      'updated_at': now,
      'visibility': visibility,
      'require_unlock': requireUnlock ? 1 : 0,
      'show_timeline': showTimeline ? 1 : 0,
      'searchable': searchable ? 1 : 0,
      'ai_allowed': aiAllowed ? 1 : 0,
      'export_allowed': exportAllowed ? 1 : 0,
    });
    await reload();
  }

  bool _isTrue(Object? value) => value == 1 || value == true || value == '1';

  List<Map<String, Object?>> get timelineSupportNotes => supportNotes.where((note) => _isTrue(note['show_timeline'])).toList();

  List<Map<String, Object?>> get searchableSupportNotes => supportNotes.where((note) => _isTrue(note['searchable'])).toList();

  List<Map<String, Object?>> get aiSupportNotes => supportNotes.where((note) => _isTrue(note['ai_allowed'])).toList();

  Future<void> addJournal(String body) async {
    await db.insert('journal', {'date': DateTime.now().toIso8601String(), 'body': body});
    await reload();
  }

  Future<void> addAppointment(Map<String, Object?> values) async {
    await db.insert('appointments', values);
    await reload();
  }

  Future<void> addReminder(Map<String, Object?> values) async {
    final id = await db.insert('reminders', values);
    final when = DateTime.tryParse('${values['datetime']}');
    if (when != null && values['enabled'] == 1) {
      await notifications.show(
        id,
        'KITSUNE reminder',
        '${values['title']}',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'kitsune',
            'KITSUNE',
            channelDescription: 'Medication, refill, and appointment reminders',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    }
    await reload();
  }

  Future<void> pickPhoto({required String category, String caption = '', String notes = '', bool baseline = false}) async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    final dir = await db.photosDir();
    final dest = File(p.join(dir.path, '${const Uuid().v4()}.jpg'));
    await File(file.path).copy(dest.path);
    await db.insert('photos', {
      'path': dest.path,
      'date': DateTime.now().toIso8601String(),
      'category': category,
      'caption': caption,
      'notes': notes,
      'is_baseline': baseline ? 1 : 0,
      'timeline_position': photos.length,
    });
    await reload();
  }

  Future<void> saveCustomField(Map<String, Object?> values, {int? id}) async {
    if (id == null) {
      await db.insert('custom_fields', values);
    } else {
      await db.update('custom_fields', values, id);
    }
    await reload();
  }

  Future<void> addCustomValue(int fieldId, String value) async {
    await db.insert('custom_values', {
      'field_id': fieldId,
      'value': value,
      'recorded_at': DateTime.now().toIso8601String(),
    });
    await reload();
  }

  List<Map<String, Object?>> eventsFor(DateTime day) {
    bool same(Object? iso) {
      final t = DateTime.tryParse('$iso');
      if (t == null) return false;
      return t.year == day.year && t.month == day.month && t.day == day.day;
    }

    return [
      ...doses.where((d) => same(d['actual_at'] ?? d['scheduled_at'])).map((d) => {...d, 'kind': 'dose'}),
      ...symptoms.where((d) => same(d['date'])).map((d) => {...d, 'kind': 'symptom'}),
      ...labs.where((d) => same(d['date'])).map((d) => {...d, 'kind': 'lab'}),
      ...appointments.where((d) => same(d['date'])).map((d) => {...d, 'kind': 'appointment'}),
      ...photos.where((d) => same(d['date'])).map((d) => {...d, 'kind': 'photo'}),
      ...fieldEntries.where((d) => same(d['recorded_at'])).map((d) => {...d, 'kind': 'progress'}),
      ...journal.where((d) => same(d['date'])).map((d) => {...d, 'kind': 'journal'}),
      ...wellbeing.where((d) => same(d['date'])).map((d) => {...d, 'kind': 'wellbeing'}),
      ...timelineSupportNotes.where((d) => same(d['updated_at'])).map((d) => {...d, 'kind': 'support'}),
    ];
  }

  List<Map<String, String>> timeline() {
    final items = <Map<String, String>>[];
    if (hrtStart != null) {
      items.add({'title': 'HRT started', 'date': hrtStart!.toIso8601String(), 'kind': 'milestone'});
    }
    for (final d in doses) {
      items.add({
        'title': 'Dose ${d['status']}',
        'date': '${d['actual_at'] ?? d['scheduled_at']}',
        'kind': 'dose',
      });
    }
    for (final l in labs) {
      items.add({'title': 'Lab: ${l['test_name']}', 'date': '${l['date']}', 'kind': 'lab'});
    }
    for (final p in photos) {
      items.add({'title': 'Photo (${p['category']})', 'date': '${p['date']}', 'kind': 'photo'});
    }
    for (final s in symptoms) {
      items.add({'title': 'Symptom: ${s['name']}', 'date': '${s['date']}', 'kind': 'symptom'});
    }
    for (final a in appointments) {
      items.add({'title': 'Appointment: ${a['title']}', 'date': '${a['date']}', 'kind': 'appointment'});
    }
    for (final e in fieldEntries.take(80)) {
      items.add({'title': 'Logged ${e['field_id']}', 'date': '${e['recorded_at']}', 'kind': 'progress'});
    }
    items.sort((a, b) => (DateTime.tryParse(b['date'] ?? '') ?? DateTime(0))
        .compareTo(DateTime.tryParse(a['date'] ?? '') ?? DateTime(0)));
    return items;
  }

  List<Map<String, String>> search(String q) {
    final query = q.toLowerCase().trim();
    if (query.isEmpty) return [];
    bool hit(Object? v) => '$v'.toLowerCase().contains(query);
    final out = <Map<String, String>>[];
    for (final m in medications) {
      if (hit(m['name']) || hit(m['generic_name']) || hit(m['notes'])) {
        out.add({'type': 'Medication', 'title': '${m['name']}', 'subtitle': '${m['dose']} ${m['dose_units']}'});
      }
    }
    for (final d in doses) {
      if (hit(d['notes']) || hit(d['status'])) {
        out.add({'type': 'Dose', 'title': '${d['status']}', 'subtitle': '${d['actual_at']}'});
      }
    }
    for (final l in labs) {
      if (hit(l['test_name']) || hit(l['notes'])) {
        out.add({'type': 'Lab', 'title': '${l['test_name']}', 'subtitle': '${l['value']} ${l['unit']}'});
      }
    }
    for (final s in symptoms) {
      if (hit(s['name']) || hit(s['notes'])) {
        out.add({'type': 'Symptom', 'title': '${s['name']}', 'subtitle': '${s['date']}'});
      }
    }
    for (final a in appointments) {
      if (hit(a['title']) || hit(a['notes'])) {
        out.add({'type': 'Appointment', 'title': '${a['title']}', 'subtitle': '${a['date']}'});
      }
    }
    for (final j in journal) {
      if (hit(j['body'])) {
        out.add({'type': 'Note', 'title': 'Journal', 'subtitle': '${j['body']}'.substring(0, '${j['body']}'.length.clamp(0, 80))});
      }
    }
    for (final p in photos) {
      if (hit(p['caption']) || hit(p['category']) || hit(p['notes'])) {
        out.add({'type': 'Photo', 'title': '${p['category']}', 'subtitle': '${p['caption']}'});
      }
    }
    for (final f in customFields) {
      if (hit(f['name']) || hit(f['category'])) {
        out.add({'type': 'Custom field', 'title': '${f['name']}', 'subtitle': '${f['category']}'});
      }
    }
    for (final n in searchableSupportNotes) {
      if (hit(n['title']) || hit(n['body']) || hit(n['kind']) || hit(n['activation']) || hit(n['preferred_response'])) {
        out.add({'type': 'Support plan', 'title': '${n['title']}', 'subtitle': '${n['kind']}'});
      }
    }
    for (final e in fieldEntries) {
      if (hit(e['field_id']) || hit(e['value']) || hit(e['notes'])) {
        out.add({'type': 'Progress', 'title': '${e['field_id']}', 'subtitle': '${e['value']}'});
      }
    }
    return out;
  }

  String formatDay(DateTime d) => DateFormat.yMMMd().format(d);
}
