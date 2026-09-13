import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:cause_money_record/config/app_color.dart';
import 'package:cause_money_record/config/app_dialog.dart';
import 'package:cause_money_record/config/app_format.dart';
import 'package:cause_money_record/data/model/history.dart';
import 'package:cause_money_record/data/source/source_history.dart';
import 'package:cause_money_record/presentation/controller/c_user.dart';
import 'package:cause_money_record/presentation/controller/history/c_history_form.dart';

/// Create or edit a transaction. Pass [idHistory] to edit, omit it to create.
///
/// Merges the former AddHistoryPage and UpdateHistoryPage, which were the same
/// form differing only in which SourceHistory method they called.
class HistoryFormPage extends StatefulWidget {
  final String? idHistory;

  const HistoryFormPage({Key? key, this.idHistory}) : super(key: key);

  @override
  State<HistoryFormPage> createState() => _HistoryFormPageState();
}

class _HistoryFormPageState extends State<HistoryFormPage> {
  final c = Get.put(CHistoryForm());
  final cUser = Get.put(CUser());
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();

  bool get _isEditing => widget.idHistory != null;

  @override
  void initState() {
    super.initState();
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
      AppDialog.success(context, _isEditing ? 'Berhasil Update History' : 'Berhasil Tambah History');
      await Future.delayed(const Duration(seconds: 1));
      Get.back(result: true);
    } else {
      AppDialog.error(context, _isEditing ? 'Gagal Update History' : 'Gagal Tambah History');
    }
  }

  Future<void> _pickDate() async {
    final result = await showDatePicker(
      context: context, initialDate: DateTime.now(),
      firstDate: DateTime(2022), lastDate: DateTime(DateTime.now().year + 1),
    );
    if (result != null) c.setDate(DateFormat('yyyy-MM-dd').format(result));
  }

  void _addItem() {
    if (_nameController.text.isEmpty || _priceController.text.isEmpty) return;
    c.addItem(HistoryItem(name: _nameController.text, price: _priceController.text));
    _nameController.clear();
    _priceController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.surface,
      appBar: AppBar(
        backgroundColor: AppColor.card, foregroundColor: AppColor.textPrimary, elevation: 0,
        title: Text(_isEditing ? 'Update Entry' : 'New Entry',
          style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _label('Date'), const SizedBox(height: 8),
          InkWell(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColor.card, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColor.border),
              ),
              child: Row(children: [
                Icon(Icons.calendar_today, size: 18, color: AppColor.textSecondary),
                const SizedBox(width: 10),
                Obx(() => Text(c.date, style: TextStyle(color: AppColor.textPrimary, fontSize: 14))),
                const Spacer(),
                Text('Change', style: TextStyle(color: AppColor.accent, fontSize: 13)),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          _label('Type'), const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColor.card, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColor.border),
            ),
            child: Obx(() => DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: c.type, isExpanded: true, dropdownColor: AppColor.card,
                items: ['Pemasukan', 'Pengeluaran'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => c.setType(v ?? 'Pemasukan'),
              ),
            )),
          ),
          const SizedBox(height: 20),
          _label('Item Name'), const SizedBox(height: 8),
          _buildField(_nameController, 'e.g. Lunch', Icons.shopping_bag_outlined),
          const SizedBox(height: 16),
          _label('Price'), const SizedBox(height: 8),
          _buildField(_priceController, '30000', Icons.payments_outlined, isNumber: true),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, height: 44,
            child: OutlinedButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add, size: 18), label: const Text('Add Item'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColor.accent, side: BorderSide(color: AppColor.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _label('Items'), const SizedBox(height: 12),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColor.card, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColor.border),
            ),
            child: Obx(() {
              if (c.items.isEmpty) return Text('No items added', style: TextStyle(color: AppColor.textSecondary, fontSize: 13));
              return Wrap(
                spacing: 8, runSpacing: 8,
                children: List.generate(c.items.length, (index) {
                  final item = c.items[index];
                  return Chip(
                    label: Text('${item.name} - Rp${item.price}', style: const TextStyle(fontSize: 12)),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => c.deleteItem(index),
                    backgroundColor: AppColor.surface, side: BorderSide(color: AppColor.border),
                  );
                }),
              );
            }),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Text('Total', style: TextStyle(fontWeight: FontWeight.w600, color: AppColor.textPrimary)),
            const Spacer(),
            Obx(() => Text(AppFormat.currency(c.total),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColor.accent))),
          ]),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: () { if (c.items.isNotEmpty) _submit(); },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColor.primary, foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              child: Text(_isEditing ? 'Save Changes' : 'Save Entry'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String hint, IconData icon, {bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: AppColor.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint, hintStyle: TextStyle(color: AppColor.textSecondary),
        prefixIcon: Icon(icon, size: 18, color: AppColor.textSecondary),
        filled: true, fillColor: AppColor.card,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColor.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColor.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColor.accent)),
      ),
    );
  }

  Widget _label(String text) {
    return Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColor.textSecondary));
  }
}
