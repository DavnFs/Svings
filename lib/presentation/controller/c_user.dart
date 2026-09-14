import 'package:get/get.dart';
import 'package:cause_money_record/data/model/user.dart';

class CUser extends GetxController {
  final _data = const User().obs;
  User get data => _data.value;

  String get id => _data.value.idUser ?? '';
  String get name => _data.value.name ?? '';

  void setData(User user) => _data.value = user;
}
