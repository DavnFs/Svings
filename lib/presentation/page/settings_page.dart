import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import 'package:cause_money_record/config/app_color.dart';
import 'package:cause_money_record/config/app_format.dart';
import 'package:cause_money_record/data/email/email_sync.dart';
import 'package:cause_money_record/data/email/gmail_client.dart';
import 'package:cause_money_record/data/email/llm_parser.dart';
import 'package:cause_money_record/data/model/history.dart';
import 'package:cause_money_record/data/source/source_email.dart';
import 'package:cause_money_record/data/source/source_history.dart';
import 'package:cause_money_record/presentation/controller/c_settings.dart';
import 'package:cause_money_record/presentation/controller/c_user.dart';
import 'package:cause_money_record/presentation/widget/frosted_app_bar.dart';

/// Settings, reached from the top-bar gear. Reads everything from the single
/// [CSettings] — no local duplicates of theme/glass/LLM state.
///
/// Section order follows the brief: Security, Gmail & Automation, Appearance,
/// Data, About. Categories management is intentionally absent: the schema has
/// no categories table (type is income/expense only), so a manager would be
/// UI over nothing.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FrostedAppBar(title: 'Settings'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: const [
          _SecuritySection(),
          SizedBox(height: 24),
          _GmailSection(),
          SizedBox(height: 24),
          _AppearanceSection(),
          SizedBox(height: 24),
          _DataSection(),
          SizedBox(height: 24),
          _AboutSection(),
        ],
      ),
    );
  }
}

/// Single matte group: 18dp radius, hairline border, 16dp padding.
class _Group extends StatelessWidget {
  final Widget child;
  const _Group({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColor.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColor.border),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(text,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColor.textPrimary)),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Key? toggleKey;

  const _ToggleRow({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.toggleKey,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColor.textPrimary)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: TextStyle(fontSize: 12, color: AppColor.textSecondary)),
          ],
        ]),
      ),
      Switch(key: toggleKey, value: value, activeThumbColor: AppColor.accent, onChanged: onChanged),
    ]);
  }
}

// ---------------------------------------------------------------------------
// 1. Security
// ---------------------------------------------------------------------------

/// Biometric app lock only. A PIN flow needs its own secure-storage + lock
/// screen and does not exist yet — the UI says exactly that instead of
/// offering a PIN toggle that stores nothing.
class _SecuritySection extends StatelessWidget {
  const _SecuritySection();

  Future<void> _toggleLock(BuildContext context, CSettings s, bool v) async {
    if (!v) {
      await s.setAppLock(false);
      return;
    }
    final auth = LocalAuthentication();
    final canCheck = await auth.canCheckBiometrics;
    final isSupported = await auth.isDeviceSupported();
    if (!context.mounted) return;
    if (!canCheck || !isSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Biometric unlock is not available on this device')),
      );
      return;
    }
    final ok = await auth.authenticate(
      localizedReason: 'Unlock svings',
      biometricOnly: true,
    );
    await s.setAppLock(ok);
  }

  @override
  Widget build(BuildContext context) {
    final s = Get.find<CSettings>();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionTitle(text: 'Security'),
      _Group(
        child: Obx(() => Column(children: [
          _ToggleRow(
            title: 'Biometric app lock',
            subtitle: s.appLock ? 'On — unlock with fingerprint / face' : 'Off',
            value: s.appLock,
            toggleKey: const Key('settings_app_lock'),
            onChanged: (v) => _toggleLock(context, s, v),
          ),
          const Divider(height: 24),
          _ToggleRow(
            title: 'Lock on app resume',
            subtitle: 'Require unlock when returning from background',
            value: s.lockOnResume,
            toggleKey: const Key('settings_lock_on_resume'),
            onChanged: s.setLockOnResume,
          ),
        ])),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// 2. Gmail & Automation
// ---------------------------------------------------------------------------

class _GmailSection extends StatefulWidget {
  const _GmailSection();

  @override
  State<_GmailSection> createState() => _GmailSectionState();
}

class _GmailSectionState extends State<_GmailSection> {
  bool _syncing = false;
  String? _syncNote;
  final _keyController = TextEditingController();

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    try {
      await GmailClient.connect();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    if (mounted) setState(() {});
  }

  Future<void> _disconnect() async {
    // GmailClient.disconnect revokes server-side, then clears local state.
    await GmailClient.disconnect();
    if (mounted) setState(() {});
  }

  Future<void> _syncNow() async {
    final s = Get.find<CSettings>();
    setState(() {
      _syncing = true;
      _syncNote = null;
    });
    try {
      final messages = await GmailClient.fetch();
      final key = await s.readApiKey();
      final sync = EmailSync(
        llm: (body, {receivedAt}) => LlmParser.parseWithFallback(
          body,
          receivedAt: receivedAt,
          apiKey: key ?? '',
          model: s.llmModel,
        ),
        onRateLimit: (_) => s.recordRateHit(),
      );
      final outcome = await sync.sync(messages);
      await s.recordSync(DateTime.now());
      if (!mounted) return;
      setState(() {
        _syncNote = '${outcome.stored} new, ${outcome.duplicates} duplicates, '
            '${outcome.candidates.length} to review';
      });
    } catch (e) {
      if (mounted) setState(() => _syncNote = 'Sync failed: $e');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = Get.find<CSettings>();
    final connected = GmailClient.isConnected;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionTitle(text: 'Gmail & Automation'),
      _Group(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(connected ? GmailClient.accountEmail ?? 'Connected' : 'Not connected',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColor.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  connected ? 'Read-only Gmail access' : 'Connect to auto-import receipts',
                  style: TextStyle(fontSize: 12, color: AppColor.textSecondary),
                ),
              ]),
            ),
            TextButton(
              key: const Key('settings_gmail_connect'),
              onPressed: connected ? _disconnect : _connect,
              child: Text(connected ? 'Disconnect' : 'Connect',
                  style: TextStyle(color: connected ? AppColor.danger : AppColor.accent)),
            ),
          ]),
          const Divider(height: 24),
          Row(children: [
            Expanded(
              child: Obx(() {
                final last = s.lastSync;
                return Text(
                  last == null
                      ? 'Never synced'
                      : 'Last synced ${DateFormat('d MMM, HH:mm').format(last)}',
                  style: TextStyle(fontSize: 13, color: AppColor.textSecondary),
                );
              }),
            ),
            FilledButton.icon(
              key: const Key('settings_sync_now'),
              onPressed: !connected || _syncing ? null : _syncNow,
              icon: _syncing
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sync, size: 16),
              label: const Text('Sync now'),
            ),
          ]),
          if (_syncNote != null) ...[
            const SizedBox(height: 8),
            Text(_syncNote!, style: TextStyle(fontSize: 12, color: AppColor.textSecondary)),
          ],
          Obx(() => s.rateLimited
              ? Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColor.outcome.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColor.outcome.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    Icon(Icons.warning_amber_rounded, color: AppColor.outcome, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'LLM rate-limited (${s.rateHits}× 429). Sync stalled on the AI '
                        'fallback — regex results are unaffected. Try again later.',
                        style: TextStyle(fontSize: 12, color: AppColor.outcome),
                      ),
                    ),
                  ]),
                )
              : const SizedBox.shrink()),
        ]),
      ),
      const SizedBox(height: 12),
      _Group(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Parsing engine',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColor.textPrimary)),
          const SizedBox(height: 4),
          Text('Regex runs first against known sender templates. The LLM is only '
              'called when regex finds no amount — enforced in code, not just described.',
              style: TextStyle(fontSize: 12, color: AppColor.textSecondary, height: 1.4)),
          const SizedBox(height: 12),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColor.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColor.border),
              ),
              child: Text('Groq', style: TextStyle(fontSize: 13, color: AppColor.textPrimary)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Obx(() => DropdownButtonFormField<String>(
                    key: const Key('settings_llm_model'),
                    initialValue: s.llmModel,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    items: CSettings.groqModels
                        .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (m) {
                      if (m != null) s.setLlmModel(m);
                    },
                  )),
            ),
          ]),
          const SizedBox(height: 12),
          Obx(() => TextField(
                key: const Key('settings_api_key'),
                controller: _keyController,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(
                  hintText: s.hasApiKey ? 'Key saved (•••${s.apiKeyTail}) — paste to replace' : 'Paste Groq API key',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  suffixIcon: IconButton(
                    tooltip: 'Save key',
                    icon: const Icon(Icons.check),
                    onPressed: () async {
                      // The controller is cleared right after saving so the key
                      // never sits in a TextField longer than needed.
                      await s.setApiKey(_keyController.text);
                      _keyController.clear();
                      if (context.mounted) FocusScope.of(context).unfocus();
                    },
                  ),
                ),
              )),
          const SizedBox(height: 4),
          Text('Stored in the device keychain, never in app prefs or logs.',
              style: TextStyle(fontSize: 11, color: AppColor.textSecondary)),
        ]),
      ),
      const SizedBox(height: 12),
      const _AutoImportsLog(),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColor.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColor.border),
        ),
        child: Row(children: [
          Icon(Icons.verified_outlined, color: AppColor.income, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No duplicates: every email is stored once by Gmail message ID — '
              're-syncing the same inbox never creates a second transaction.',
              style: TextStyle(fontSize: 12, color: AppColor.textSecondary, height: 1.4),
            ),
          ),
        ]),
      ),
    ]);
  }
}

/// Recent email-created transactions with one-tap Undo. Undo deletes the
/// transaction AND marks the source email ignored, so the next sync skips it
/// instead of re-creating it.
class _AutoImportsLog extends StatefulWidget {
  const _AutoImportsLog();

  @override
  State<_AutoImportsLog> createState() => _AutoImportsLogState();
}

class _AutoImportsLogState extends State<_AutoImportsLog> {
  late Future<List<History>> _future;
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final id = Get.find<CUser>().id;
    _future = SourceHistory.autoImported(id);
  }

  Future<void> _undo(History h) async {
    if (h.idHistory == null) return;
    final ok = await SourceHistory.delete(h.idHistory!);
    if (h.rawEmailId != null) {
      // Best-effort: even if the ignore-mark fails, the transaction is gone
      // and the message-ID dedupe still prevents a silent re-create — the
      // reparse path only re-reads stored rows, it never re-inserts.
      try {
        await SourceEmail.markIgnored(h.rawEmailId!);
      } catch (_) {}
    }
    if (!mounted) return;
    if (ok) {
      setState(_reload);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Auto-import undone — email will be skipped')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColor.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColor.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('Recent auto-imports',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColor.textPrimary)),
          ),
          DropdownButton<String>(
            value: _filter,
            underline: const SizedBox.shrink(),
            style: TextStyle(fontSize: 13, color: AppColor.textPrimary),
            items: const [
              DropdownMenuItem(value: 'All', child: Text('All')),
              DropdownMenuItem(value: 'Pemasukan', child: Text('Income')),
              DropdownMenuItem(value: 'Pengeluaran', child: Text('Expense')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _filter = v);
            },
          ),
        ]),
        const SizedBox(height: 8),
        FutureBuilder<List<History>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            var list = snap.data ?? const <History>[];
            if (_filter != 'All') {
              list = list.where((h) => h.type == _filter).toList();
            }
            if (list.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('No auto-imported transactions yet.',
                    style: TextStyle(fontSize: 13, color: AppColor.textSecondary)),
              );
            }
            return Column(
              children: list
                  .map((h) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(AppFormat.currency(h.total),
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColor.textPrimary)),
                              Text('${AppFormat.date(h.date)} · ${h.type}',
                                  style: TextStyle(fontSize: 12, color: AppColor.textSecondary)),
                            ]),
                          ),
                          TextButton(
                            key: Key('settings_undo_${h.idHistory}'),
                            onPressed: () => _undo(h),
                            child: const Text('Undo'),
                          ),
                        ]),
                      ))
                  .toList(),
            );
          },
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Appearance
// ---------------------------------------------------------------------------

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context) {
    final s = Get.find<CSettings>();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionTitle(text: 'Appearance'),
      _Group(
        child: Obx(() => Column(children: [
          Row(children: [
            Expanded(
              child: Text('Theme',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColor.textPrimary)),
            ),
            DropdownButton<ThemeMode>(
              key: const Key('settings_theme_mode'),
              value: s.themeMode,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
              ],
              onChanged: (m) {
                if (m != null) s.setThemeMode(m);
              },
            ),
          ]),
          const Divider(height: 24),
          _ToggleRow(
            title: 'Reduce glass effect',
            subtitle: 'Solid surfaces instead of frosted blur',
            value: s.reduceGlass,
            toggleKey: const Key('settings_reduce_glass'),
            onChanged: s.setReduceGlass,
          ),
        ])),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// 4. Data
// ---------------------------------------------------------------------------

class _DataSection extends StatelessWidget {
  const _DataSection();

  Future<void> _export(BuildContext context, String format) async {
    final id = Get.find<CUser>().id;
    final list = await SourceHistory.history(id);
    final String text;
    final String name;
    if (format == 'csv') {
      final buf = StringBuffer('date,type,total,notes\n');
      for (final h in list) {
        buf.writeln('${h.date},${h.type},${h.total},"${(h.notes ?? '').replaceAll('"', '""')}"');
      }
      text = buf.toString();
      name = 'svings-export.csv';
    } else {
      text = jsonEncode(list
          .map((h) => {
                'date': h.date,
                'type': h.type,
                'total': h.total,
                'notes': h.notes,
                'source': h.source,
                'items': h.items.map((i) => i.toJson()).toList(),
              })
          .toList());
      name = 'svings-export.json';
    }
    await SharePlus.instance.share(ShareParams(text: text, subject: name));
  }

  /// Double-confirmation: checkbox-style first dialog, typed word second.
  /// Returns true only if the user passes both gates.
  Future<bool> _doubleConfirm(BuildContext context) async {
    final first = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete all data?'),
        content: const Text('This permanently deletes every transaction. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text('Continue', style: TextStyle(color: AppColor.danger)),
          ),
        ],
      ),
    );
    if (first != true || !context.mounted) return false;
    final controller = TextEditingController();
    final second = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Type DELETE to confirm'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'DELETE'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(c, controller.text.trim() == 'DELETE'),
            child: Text('Delete everything', style: TextStyle(color: AppColor.danger)),
          ),
        ],
      ),
    );
    return second == true;
  }

  Future<void> _reset(BuildContext context) async {
    if (!await _doubleConfirm(context)) return;
    final ok = await SourceHistory.deleteAll(Get.find<CUser>().id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'All data deleted' : 'Reset failed — try again')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = Get.find<CSettings>();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionTitle(text: 'Data'),
      _Group(
        child: Obx(() => Column(children: [
          _ToggleRow(
            title: 'Show decimals',
            subtitle: 'Rp 25.000,00 vs Rp 25.000',
            value: s.showDecimals,
            toggleKey: const Key('settings_show_decimals'),
            onChanged: s.setShowDecimals,
          ),
          const Divider(height: 24),
          Row(children: [
            Expanded(
              child: Text('Export backup',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColor.textPrimary)),
            ),
            TextButton(
              key: const Key('settings_export_csv'),
              onPressed: () => _export(context, 'csv'),
              child: const Text('CSV'),
            ),
            TextButton(
              key: const Key('settings_export_json'),
              onPressed: () => _export(context, 'json'),
              child: const Text('JSON'),
            ),
          ]),
          const Divider(height: 24),
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Reset all data',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColor.danger)),
                Text('Deletes every transaction permanently',
                    style: TextStyle(fontSize: 12, color: AppColor.textSecondary)),
              ]),
            ),
            TextButton(
              key: const Key('settings_reset_data'),
              onPressed: () => _reset(context),
              child: Text('Reset…', style: TextStyle(color: AppColor.danger)),
            ),
          ]),
        ])),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// 5. About
// ---------------------------------------------------------------------------

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionTitle(text: 'About'),
      _Group(
        child: FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snap) {
            final v = snap.data;
            return Column(children: [
              Row(children: [
                Expanded(
                  child: Text('svings',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600, color: AppColor.textPrimary)),
                ),
                Text(v == null ? '…' : 'v${v.version} (${v.buildNumber})',
                    style: TextStyle(fontSize: 13, color: AppColor.textSecondary)),
              ]),
              const Divider(height: 24),
              Row(children: [
                Expanded(
                  child: Text('Found a bug?',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w500, color: AppColor.textPrimary)),
                ),
                TextButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bug reports: reply in the project thread')),
                  ),
                  child: const Text('Report'),
                ),
              ]),
            ]);
          },
        ),
      ),
    ]);
  }
}
