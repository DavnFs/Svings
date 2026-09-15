import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:cause_money_record/config/app_color.dart';
import 'package:cause_money_record/config/app_dialog.dart';
import 'package:cause_money_record/config/app_format.dart';
import 'package:cause_money_record/data/model/history.dart';
import 'package:cause_money_record/data/source/source_history.dart';
import 'package:cause_money_record/presentation/controller/c_user.dart';
import 'package:cause_money_record/presentation/controller/history/c_history_form.dart';
import 'package:cause_money_record/presentation/widget/frosted_app_bar.dart';
import 'package:cause_money_record/presentation/widget/pressable.dart';

/// Create or edit a transaction. Pass [idHistory] to edit, omit it to create.
class HistoryFormPage extends StatefulWidget {
  final String? idHistory;

  const HistoryFormPage({super.key, this.idHistory});

  @override
  State<HistoryFormPage> createState() => _HistoryFormPageState();
}

class _HistoryFormPageState extends State<HistoryFormPage> {
  late final CHistoryForm c;
  late final CUser cUser;
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();

  bool get _isEditing => widget.idHistory != null;

  @override
  void initState() {
    super.initState();
    c = Get.find<CHistoryForm>();
    cUser = Get.find<CUser>();
    c.reset();
    if (_isEditing) c.load(widget.idHistory!);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final success = _isEditing
        ? await SourceHistory.update(
            idHistory: widget.idHistory!,
            idUser: cUser.id,
            date: c.date,
            type: c.type,
            items: c.items,
          )
        : await SourceHistory.add(
            idUser: cUser.id,
            date: c.date,
            type: c.type,
            items: c.items,
          );
    if (!mounted) return;
    if (success) {
      HapticFeedback.mediumImpact();
      AppDialog.success(context, _isEditing ? 'Transaction updated successfully' : 'Transaction saved successfully');
      await Future.delayed(const Duration(milliseconds: 700));
      Get.back(result: true);
    } else {
      AppDialog.error(context, _isEditing ? 'Failed to update transaction' : 'Failed to save transaction');
    }
  }

  Future<void> _pickDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(c.date) ?? DateTime.now(),
      firstDate: DateTime(2022),
      lastDate: DateTime(DateTime.now().year + 1),
    );
    if (result != null) c.setDate(DateFormat('yyyy-MM-dd').format(result));
  }

  void _addItem() {
    final name = _nameController.text.trim();
    final price = _priceController.text.trim();
    if (name.isEmpty || price.isEmpty) return;
    HapticFeedback.lightImpact();
    c.addItem(HistoryItem(name: name, price: price));
    _nameController.clear();
    _priceController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = c.type == 'Pemasukan';

    return Scaffold(
      appBar: FrostedAppBar(title: _isEditing ? 'Edit Entry' : 'New Entry'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const _SectionLabel(text: 'Transaction Details'),
          const SizedBox(height: 8),
          _FormGroup(
            child: Column(
              children: [
                Obx(() {
                  final isCurrentlyIncome = c.type == 'Pemasukan';
                  return Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColor.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColor.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Pressable(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              c.setType('Pemasukan');
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isCurrentlyIncome ? AppColor.income : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.arrow_downward_rounded,
                                    size: 16,
                                    color: isCurrentlyIncome ? Colors.white : AppColor.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Income',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isCurrentlyIncome ? FontWeight.w700 : FontWeight.w500,
                                      color: isCurrentlyIncome ? Colors.white : AppColor.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Pressable(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              c.setType('Pengeluaran');
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !isCurrentlyIncome ? AppColor.outcome : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.arrow_upward_rounded,
                                    size: 16,
                                    color: !isCurrentlyIncome ? Colors.white : AppColor.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Expense',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: !isCurrentlyIncome ? FontWeight.w700 : FontWeight.w500,
                                      color: !isCurrentlyIncome ? Colors.white : AppColor.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 14),
                Divider(height: 1, color: AppColor.border),
                const SizedBox(height: 14),
                Pressable(
                  onTap: _pickDate,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 20, color: AppColor.accent),
                        const SizedBox(width: 12),
                        Text(
                          'Date',
                          style: TextStyle(color: AppColor.textSecondary, fontSize: 14),
                        ),
                        const Spacer(),
                        Obx(
                          () => Text(
                            AppFormat.date(c.date),
                            style: TextStyle(
                              color: AppColor.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.chevron_right_rounded, size: 18, color: AppColor.textSecondary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel(text: 'Add Item'),
          const SizedBox(height: 8),
          _FormGroup(
            child: Column(
              children: [
                _ItemField(
                  controller: _nameController,
                  hint: 'Item Description (e.g. Lunch)',
                  icon: Icons.edit_note_rounded,
                ),
                const SizedBox(height: 12),
                _ItemField(
                  controller: _priceController,
                  hint: 'Amount (Rp)',
                  icon: Icons.payments_outlined,
                  isNumber: true,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add to List'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColor.accent,
                      side: BorderSide(color: AppColor.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel(text: 'Recorded Items'),
          const SizedBox(height: 8),
          _FormGroup(
            child: Obx(() {
              if (c.items.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No items added yet. Add an item above to continue.',
                      style: TextStyle(color: AppColor.textSecondary, fontSize: 13),
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: c.items.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: AppColor.border),
                    itemBuilder: (context, index) {
                      final item = c.items[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppColor.surface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColor.textSecondary),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item.name,
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColor.textPrimary),
                              ),
                            ),
                            Text(
                              AppFormat.currency(num.tryParse(item.price) ?? 0),
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColor.textPrimary),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => c.deleteItem(index),
                              child: Icon(Icons.close_rounded, size: 18, color: AppColor.textSecondary),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  Divider(height: 1, color: AppColor.border),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Amount',
                        style: TextStyle(fontWeight: FontWeight.w600, color: AppColor.textPrimary, fontSize: 15),
                      ),
                      Text(
                        AppFormat.currency(c.total),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: isIncome ? AppColor.income : AppColor.accent,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: Obx(
              () => ElevatedButton(
                onPressed: c.items.isNotEmpty ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColor.accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColor.border,
                  disabledForegroundColor: AppColor.textSecondary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                child: Text(_isEditing ? 'Save Changes' : 'Save Transaction'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Single-surface form group: solid matte, radius 18, 16dp padding.
class _FormGroup extends StatelessWidget {
  final Widget child;

  const _FormGroup({required this.child});

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

/// DESIGN.md input: radius 14, hairline border, accent focus ring.
class _ItemField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool isNumber;

  const _ItemField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.isNumber = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: AppColor.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColor.textSecondary.withValues(alpha: 0.7), fontSize: 14),
        prefixIcon: Icon(icon, size: 18, color: AppColor.textSecondary),
        filled: true,
        fillColor: AppColor.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColor.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColor.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColor.accent)),
      ),
    );
  }
}

/// DESIGN.md section label: 13sp w700 secondary.
class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColor.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }
}
