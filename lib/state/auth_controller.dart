import 'package:flutter/foundation.dart';

class AuthController extends ChangeNotifier {
  bool _signedIn = false;
  bool get signedIn => _signedIn;
  void enterDemo() {
    _signedIn = true;
    notifyListeners();
  }

  void logout() {
    _signedIn = false;
    notifyListeners();
  }
}
