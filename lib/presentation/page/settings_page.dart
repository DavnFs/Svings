import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import 'package:cause_money_record/config/app_format.dart';
import 'package:cause_money_record/data/email/email_sync.dart';
import 'package:cause_money_record/data/email/gmail_client.dart';
import 'package:cause_money_record/data/email/llm_parser.dart';
import 'package:cause_money_record/data/model/account.dart';
import 'package:cause_money_record/data/model/history.dart';
import 'package:cause_money_record/data/source/source_email.dart';
import 'package:cause_money_record/data/source/source_history.dart';
import 'package:cause_money_record/presentation/controller/c_accounts.dart';
import 'package:cause_money_record/presentation/controller/c_settings.dart';
import 'package:cause_money_record/presentation/controller/c_user.dart';
import 'package:cause_money_record/presentation/widget/account_widgets.dart';

/// Settings, reached from the top-bar gear. Reads everything from the single
/// [CSettings] â€” no local duplicates of theme/glass/LLM state.
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text('Settings')),
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

/// MD3 tonal group: surfaceContainerLow, no shadows.
class _Group extends StatelessWidget {
  final Widget child;
  const _Group({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
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
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface)),
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
    final scheme = Theme.of(context).colorScheme;
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurface)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ],
        ]),
      ),
      Switch(key: toggleKey, value: value, onChanged: onChanged),
    ]);
  }
}

// ---------------------------------------------------------------------------
// 1. Security
// ---------------------------------------------------------------------------

/// Biometric app lock only. A PIN flow needs its own secure-storage + lock
/// screen and does not exist yet â€” the UI says exactly that instead of
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
        const SnackBar(
            content: Text('Biometric unlock is not available on this device')),
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
                subtitle:
                    s.appLock ? 'On â€” unlock with fingerprint / face' : 'Off',
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
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
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
      final accounts = Get.find<CAccounts>();
      final sync = EmailSync(
        llm: (body, {receivedAt}) => LlmParser.parseWithFallback(
          body,
          receivedAt: receivedAt,
          apiKey: key ?? '',
          model: s.llmModel,
        ),
        onRateLimit: (_) => s.recordRateHit(),
        accountForSender: s.accountForSender,
        recentEmailTransactions: () async {
          final id = Get.find<CUser>().id;
          if (id.isEmpty) return [];
          final rows = await SourceHistory.emailTransferRows(id);
          return rows
              .map((r) => TransferMatchRow(
                    id: r['id'] as String,
                    date: r['date'] as String,
                    total: r['total'] as double,
                    type: r['type'] as String,
                    accountId: r['accountId'] as String?,
                  ))
              .toList();
        },
      );
      final outcome = await sync.sync(messages);
      await _confirmAndSave(outcome, accounts);
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

  /// Auto-save per the existing policy: mapped senders to their account,
  /// unmapped to the default (flagged in the log for Reassign). Possible
  /// transfer pairs are saved as two rows and flagged — never merged here.
  Future<void> _confirmAndSave(
    SyncOutcome outcome,
    CAccounts accounts,
  ) async {
    final id = Get.find<CUser>().id;
    if (id.isEmpty || outcome.candidates.isEmpty) return;
    if (accounts.accounts.isEmpty) await accounts.getAccounts(id);
    var list = accounts.accounts;
    if (list.isEmpty) return;
    final fallback = list.any((a) => a.name == Account.defaultName)
        ? list.firstWhere((a) => a.name == Account.defaultName)
        : list.first;
    for (final c in outcome.candidates) {
      final accountId = c.accountId ?? fallback.id;
      final hint = c.possibleTransferWith == null
          ? ''
          : ' Possible transfer with ${c.possibleTransferWith} — confirm in Transactions.';
      final notes = [
        if (c.sender != null) 'From: ${c.sender}',
        if (c.subject != null) 'Subject: ${c.subject}',
        'via ${c.transaction.matchedBy}$hint',
      ].join('\n');
      await SourceHistory.add(
        idUser: id,
        date:
            '${c.transaction.date.year}-${c.transaction.date.month.toString().padLeft(2, '0')}-${c.transaction.date.day.toString().padLeft(2, '0')}',
        type: c.transaction.type,
        items: [
          HistoryItem(
            name: c.transaction.merchant ?? c.subject ?? 'Email import',
            price: c.transaction.total.toString(),
          ),
        ],
        notes: notes.isEmpty ? null : notes,
        source: 'email',
        rawEmailId: c.rawEmailId,
        accountId: accountId,
      );
    }
    await accounts.getAccounts(id);
  }

  @override
  Widget build(BuildContext context) {
    final s = Get.find<CSettings>();
    final scheme = Theme.of(context).colorScheme;
    final connected = GmailClient.isConnected;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionTitle(text: 'Gmail & Automation'),
      _Group(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        connected
                            ? GmailClient.accountEmail ?? 'Connected'
                            : 'Not connected',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface)),
                    const SizedBox(height: 2),
                    Text(
                      connected
                          ? 'Read-only Gmail access'
                          : 'Connect to auto-import receipts',
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ]),
            ),
            TextButton(
              key: const Key('settings_gmail_connect'),
              onPressed: connected ? _disconnect : _connect,
              child: Text(connected ? 'Disconnect' : 'Connect',
                  style: TextStyle(
                      color: connected ? scheme.error : scheme.primary)),
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
                  style:
                      TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                );
              }),
            ),
            FilledButton.icon(
              key: const Key('settings_sync_now'),
              onPressed: !connected || _syncing ? null : _syncNow,
              icon: _syncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sync, size: 16),
              label: const Text('Sync now'),
            ),
          ]),
          if (_syncNote != null) ...[
            const SizedBox(height: 8),
            Text(_syncNote!,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ],
          Obx(() => s.rateLimited
              ? Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(children: [
                    Icon(Icons.warning_amber_rounded,
                        color: scheme.onErrorContainer, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'LLM rate-limited (${s.rateHits}Ã— 429). Sync stalled on the AI '
                        'fallback â€” regex results are unaffected. Try again later.',
                        style: TextStyle(
                            fontSize: 12, color: scheme.onErrorContainer),
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
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface)),
          const SizedBox(height: 4),
          Text(
              'Regex runs first against known sender templates. The LLM is only '
              'called when regex finds no amount â€” enforced in code, not just described.',
              style: TextStyle(
                  fontSize: 12, color: scheme.onSurfaceVariant, height: 1.4)),
          const SizedBox(height: 12),
          Row(children: [
            const Chip(label: Text('Groq')),
            const SizedBox(width: 8),
            Expanded(
              child: Obx(() => DropdownButtonFormField<String>(
                    key: const Key('settings_llm_model'),
                    initialValue: s.llmModel,
                    decoration: const InputDecoration(
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    items: CSettings.groqModels
                        .map((m) => DropdownMenuItem(
                            value: m,
                            child:
                                Text(m, style: const TextStyle(fontSize: 13))))
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
                  hintText: s.hasApiKey
                      ? 'Key saved (â€¢â€¢â€¢${s.apiKeyTail}) â€” paste to replace'
                      : 'Paste Groq API key',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
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
              style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
      ),
      const SizedBox(height: 12),
      const _SenderMappingCard(),
      const SizedBox(height: 12),
      const _AutoImportsLog(),
      const SizedBox(height: 12),
      Card.outlined(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Icon(Icons.verified_outlined,
                color: Theme.of(context).colorScheme.tertiary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'No duplicates: every email is stored once by Gmail message ID â€” '
                're-syncing the same inbox never creates a second transaction.',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }
}

/// Sender -> account mapping for auto-imports. Unmapped senders fall back to
/// the default account and are flagged in the log â€” never guessed.
///
/// The mapping lives in CSettings (single source); this card only edits it.
class _SenderMappingCard extends StatefulWidget {
  const _SenderMappingCard();

  @override
  State<_SenderMappingCard> createState() => _SenderMappingCardState();
}

class _SenderMappingCardState extends State<_SenderMappingCard> {
  final _sender = TextEditingController();
  String? _accountId;

  @override
  void dispose() {
    _sender.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = Get.find<CSettings>();
    final accounts = Get.find<CAccounts>();
    final scheme = Theme.of(context).colorScheme;
    return Card.outlined(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sender â†’ account',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface)),
            const SizedBox(height: 4),
            Text(
                'Emails from a mapped sender land directly in that account. '
                'Anything unmapped goes to Lainnya, flagged for review.',
                style: TextStyle(
                    fontSize: 12, color: scheme.onSurfaceVariant, height: 1.4)),
            const SizedBox(height: 12),
            Obx(() {
              final entries = s.senderMap.entries.toList();
              if (entries.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('No mappings yet.',
                      style: TextStyle(
                          fontSize: 13, color: scheme.onSurfaceVariant)),
                );
              }
              return Column(
                children: entries
                    .map((e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(children: [
                            Expanded(
                              child: Text(e.key,
                                  style: TextStyle(
                                      fontSize: 13, color: scheme.onSurface)),
                            ),
                            Text(accounts.byId(e.value)?.name ?? 'â€”',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: scheme.onSurfaceVariant)),
                            IconButton(
                              tooltip: 'Remove mapping',
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () => s.setSenderMapping(e.key, null),
                            ),
                          ]),
                        ))
                    .toList(),
              );
            }),
            TextField(
              controller: _sender,
              decoration: const InputDecoration(
                hintText: 'Sender (e.g. noreply@bca.co.id)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Obx(() {
              final list = accounts.accounts;
              final current =
                  _accountId != null && list.any((a) => a.id == _accountId)
                      ? _accountId
                      : (list.isEmpty ? null : list.first.id);
              return Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: current,
                    decoration: const InputDecoration(
                        labelText: 'Account', border: OutlineInputBorder()),
                    items: list
                        .map((a) => DropdownMenuItem(
                            value: a.id, child: AccountDropdownItem(account: a)))
                        .toList(),
                    onChanged: (v) => setState(() => _accountId = v),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: list.isEmpty
                      ? null
                      : () async {
                          final sender = _sender.text.trim();
                          if (sender.isEmpty) return;
                          await s.setSenderMapping(
                              sender, _accountId ?? list.first.id);
                          _sender.clear();
                          if (context.mounted) {
                            FocusScope.of(context).unfocus();
                          }
                        },
                  child: const Text('Add'),
                ),
              ]);
            }),
          ],
        ),
      ),
    );
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
      // and the message-ID dedupe still prevents a silent re-create â€” the
      // reparse path only re-reads stored rows, it never re-inserts.
      try {
        await SourceEmail.markIgnored(h.rawEmailId!);
      } catch (_) {}
    }
    if (!mounted) return;
    if (ok) {
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Auto-import undone â€” email will be skipped')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card.outlined(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text('Recent auto-imports',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface)),
              ),
              DropdownButton<String>(
                value: _filter,
                underline: const SizedBox.shrink(),
                style: TextStyle(fontSize: 13, color: scheme.onSurface),
                items: const [
                  DropdownMenuItem(value: 'All', child: Text('All')),
                  DropdownMenuItem(value: 'Pemasukan', child: Text('Income')),
                  DropdownMenuItem(
                      value: 'Pengeluaran', child: Text('Expense')),
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
                final scheme = Theme.of(context).colorScheme;
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
                        style: TextStyle(
                            fontSize: 13, color: scheme.onSurfaceVariant)),
                  );
                }
                return Column(
                  children: list.map((h) {
                    final accounts = Get.find<CAccounts>();
                    final accountName =
                        accounts.byId(h.accountId)?.name ?? 'Lainnya';
                    final unmapped = h.accountId == null ||
                        accounts.byId(h.accountId)?.name ==
                            Account.defaultName;
                    // Possible-transfer flag: the sync wrote the partner row's
                    // id into this row's notes at import time. Parsed back out
                    // here so the log can offer a confirm/merge action.
                    // firstOrNull needs the collection package — the where +
                    // isEmpty check below avoids the dependency.
                    final partnerId = _transferPartnerId(h.notes);
                    final matches = partnerId == null
                        ? const <History>[]
                        : list
                            .where((o) => o.idHistory == partnerId)
                            .toList();
                    final partner =
                        matches.isEmpty ? null : matches.first;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(AppFormat.currency(h.total),
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: scheme.onSurface)),
                                  Text(
                                      '${AppFormat.date(h.date)} · ${h.type} · $accountName',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: scheme.onSurfaceVariant)),
                                ],
                              ),
                            ),
                            TextButton(
                              key: Key('settings_undo_${h.idHistory}'),
                              onPressed: () => _undo(h),
                              child: const Text('Undo'),
                            ),
                          ]),
                          if (unmapped)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(children: [
                                Expanded(
                                  child: Text(
                                      'Unmapped sender — move it to the right account.',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: scheme.onSurfaceVariant)),
                                ),
                                TextButton(
                                  key: Key(
                                      'settings_reassign_${h.idHistory}'),
                                  onPressed: () => _reassign(context, h),
                                  child: const Text('Reassign'),
                                ),
                              ]),
                            ),
                          // Confirm/merge only: the pair stays two rows until
                          // the user taps Merge. Coincidental same-amount
                          // pairs are dismissed with "Not a transfer".
                          if (partner != null && h.idHistory != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(children: [
                                Expanded(
                                  child: Text(
                                      'Possible transfer with ${AppFormat.currency(partner.total)} on ${AppFormat.date(partner.date)}.',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: scheme.onSurfaceVariant)),
                                ),
                                TextButton(
                                  key: Key('settings_merge_${h.idHistory}'),
                                  onPressed: () =>
                                      _mergeTransfer(context, h, partner),
                                  child: const Text('Merge'),
                                ),
                              ]),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Moves an auto-imported row to the user-picked account. Type untouched.
  Future<void> _reassign(BuildContext context, History h) async {
    final accounts = Get.find<CAccounts>();
    if (accounts.accounts.isEmpty || h.idHistory == null) return;
    final picked = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Move to account'),
        content: DropdownButtonFormField<String>(
          initialValue: h.accountId,
          decoration:
              const InputDecoration(border: OutlineInputBorder()),
          items: accounts.accounts
              .map((a) => DropdownMenuItem(
                  value: a.id, child: AccountDropdownItem(account: a)))
              .toList(),
          onChanged: (v) => Navigator.pop(c, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancel')),
        ],
      ),
    );
    if (picked == null || picked == h.accountId) return;
    final ok = await SourceHistory.reassignAccount(h.idHistory!, picked);
    if (!context.mounted) return;
    if (ok) {
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction moved')));
    }
  }

  /// Merges a flagged pair into one transfer, user-confirmed only. The
  /// OUTGOING (expense) row becomes the transfer; the incoming row is deleted.
  /// Direction decides the legs — never the row order in the list.
  Future<void> _mergeTransfer(
      BuildContext context, History h, History partner) async {
    final outgoing = h.type == 'Pengeluaran' ? h : partner;
    final incoming = h.type == 'Pengeluaran' ? partner : h;
    if (outgoing.idHistory == null ||
        incoming.idHistory == null ||
        outgoing.accountId == null ||
        incoming.accountId == null) {
      return;
    }
    final ok = await SourceHistory.mergeAsTransfer(
      outgoingId: outgoing.idHistory!,
      incomingId: incoming.idHistory!,
      fromAccountId: outgoing.accountId!,
      toAccountId: incoming.accountId!,
    );
    if (!context.mounted) return;
    if (ok) {
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Merged into a transfer')));
    }
  }
}

/// Reads the partner id the sync embedded in the notes at import time.
/// Null when this row was never flagged.
String? _transferPartnerId(String? notes) {
  if (notes == null) return null;
  final m = RegExp(r'Possible transfer with (\S+)').firstMatch(notes);
  return m?[1];
}

// ---------------------------------------------------------------------------
// 3. Appearance
// ---------------------------------------------------------------------------

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context) {
    final s = Get.find<CSettings>();
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionTitle(text: 'Appearance'),
      _Group(
        child: Obx(() => Column(children: [
              Row(children: [
                Expanded(
                  child: Text('Theme',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: scheme.onSurface)),
                ),
                DropdownButton<ThemeMode>(
                  key: const Key('settings_theme_mode'),
                  value: s.themeMode,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(
                        value: ThemeMode.system, child: Text('System')),
                    DropdownMenuItem(
                        value: ThemeMode.light, child: Text('Light')),
                    DropdownMenuItem(
                        value: ThemeMode.dark, child: Text('Dark')),
                  ],
                  onChanged: (m) {
                    if (m != null) s.setThemeMode(m);
                  },
                ),
              ]),
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
        buf.writeln(
            '${h.date},${h.type},${h.total},"${(h.notes ?? '').replaceAll('"', '""')}"');
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
        content: const Text(
            'This permanently deletes every transaction. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text('Continue',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () =>
                Navigator.pop(c, controller.text.trim() == 'DELETE'),
            child: Text('Delete everything',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
      SnackBar(
          content: Text(ok ? 'All data deleted' : 'Reset failed â€” try again')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = Get.find<CSettings>();
    final scheme = Theme.of(context).colorScheme;
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
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: scheme.onSurface)),
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
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Reset all data',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: scheme.error)),
                        Text('Deletes every transaction permanently',
                            style: TextStyle(
                                fontSize: 12, color: scheme.onSurfaceVariant)),
                      ]),
                ),
                TextButton(
                  key: const Key('settings_reset_data'),
                  onPressed: () => _reset(context),
                  child: Text('Resetâ€¦', style: TextStyle(color: scheme.error)),
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
    final scheme = Theme.of(context).colorScheme;
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
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface)),
                ),
                Text(v == null ? 'â€¦' : 'v${v.version} (${v.buildNumber})',
                    style: TextStyle(
                        fontSize: 13, color: scheme.onSurfaceVariant)),
              ]),
              const Divider(height: 24),
              Row(children: [
                Expanded(
                  child: Text('Found a bug?',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: scheme.onSurface)),
                ),
                TextButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Bug reports: reply in the project thread')),
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
