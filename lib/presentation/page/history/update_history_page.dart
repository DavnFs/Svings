import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:cause_money_record/config/app_color.dart';
import 'package:cause_money_record/config/app_dialog.dart';
import 'package:cause_money_record/config/app_format.dart';
import 'package:cause_money_record/data/source/source_history.dart';
import 'package:cause_money_record/presentation/controller/c_user.dart';
import 'package:cause_money_record/presentation/controller/history/c_update_history.dart';

class UpdateHistoryPage extends StatefulWidget {
  final String date;
  final String idHistory;
  const UpdateHistoryPage({Key? key, required this.date, required this.idHistory}) : super(key: key);

  @override
  State<UpdateHistoryPage> createState() => _UpdateHistoryPageState();
}

class _UpdateHistoryPageState extends State<UpdateHistoryPage> {
  final cUpdate = Get.put(CUpdateHistory());
  final cUser = Get.put(CUser());
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();

  Future<void> _submit() async {
    final success = await SourceHistory.update(
      widget.idHistory, cUser.id, cUpdate.date, cUpdate.type,
      jsonEncode(cUpdate.items), cUpdate.total.toString(),
    );
    if (success) {
      AppDialog.success(context, 'Berhasil Update History');
      await Future.delayed(const Duration(seconds: 1));
      Get.back(result: true);
    } else {
      AppDialog.error(context, 'Gagal Update History');
    }
  }

  Future<void> _pickDate() async {
    final result = await showDatePicker(
      context: context, initialDate: DateTime.now(),
      firstDate: DateTime(2022), lastDate: DateTime(DateTime.now().year + 1),
    );
    if (result != null) cUpdate.setDate(DateFormat('yyyy-MM-dd').format(result));
  }

  @override
  void initState() { super.initState(); cUpdate.init(cUser.id, widget.date); }
  @override
  void dispose() { _nameController.dispose(); _priceController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.surface,
      appBar: AppBar(
        backgroundColor: AppColor.card, foregroundColor: AppColor.textPrimary, elevation: 0,
        title: const Text('Update Entry', style: TextStyle(fontWeight: FontWeight.w600)),
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
                const Icon(Icons.calendar_today, size: 18, color: AppColor.textSecondary),
                const SizedBox(width: 10),
                Obx(() => Text(cUpdate.date, style: const TextStyle(color: AppColor.textPrimary, fontSize: 14))),
                const Spacer(),
                const Text('Change', style: TextStyle(color: AppColor.accent, fontSize: 13)),
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
                value: cUpdate.type, isExpanded: true, dropdownColor: AppColor.card,
                items: ['Pemasukan', 'Pengeluaran'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => cUpdate.setType(v ?? 'Pemasukan'),
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
              onPressed: () {
                if (_nameController.text.isEmpty || _priceController.text.isEmpty) return;
                cUpdate.addItem({'name': _nameController.text, 'price': _priceController.text});
                _nameController.clear();
                _priceController.clear();
              },
              icon: const Icon(Icons.add, size: 18), label: const Text('Add Item'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColor.accent, side: const BorderSide(color: AppColor.border),
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
              if (cUpdate.items.isEmpty) return const Text('No items added', style: TextStyle(color: AppColor.textSecondary, fontSize: 13));
              return Wrap(
                spacing: 8, runSpacing: 8,
                children: List.generate(cUpdate.items.length, (index) {
                  final item = cUpdate.items[index];
                  return Chip(
                    label: Text('${item['name']} - Rp${item['price']}', style: const TextStyle(fontSize: 12)),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => cUpdate.deleteItem(index),
                    backgroundColor: AppColor.surface, side: const BorderSide(color: AppColor.border),
                  );
                }),
              );
            }),
          ),
          const SizedBox(height: 20),
          Row(children: [
            const Text('Total', style: TextStyle(fontWeight: FontWeight.w600, color: AppColor.textPrimary)),
            const Spacer(),
            Obx(() => Text(AppFormat.currency(cUpdate.total.toString()),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColor.accent))),
          ]),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: cUpdate.items.isEmpty ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColor.primary, foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              child: const Text('Save Changes'),
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
      style: const TextStyle(color: AppColor.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint, hintStyle: const TextStyle(color: AppColor.textSecondary),
        prefixIcon: Icon(icon, size: 18, color: AppColor.textSecondary),
        filled: true, fillColor: AppColor.card,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColor.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColor.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColor.accent)),
      ),
    );
  }

  Widget _label(String text) {
    return Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColor.textSecondary));
  }
}
