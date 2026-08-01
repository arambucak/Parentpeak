import 'base_page.dart';

class LoginPage extends BasePage {
  LoginPage(super.tester);

  static const emailField    = 'email_field';
  static const passwordField = 'password_field';
  static const loginButton   = 'login_button';
  static const errorMessage  = 'error_message';

  Future<void> enterEmail(String email) => enterText(emailField, email);
  Future<void> enterPassword(String pass) => enterText(passwordField, pass);
  Future<void> tapLogin() => tapByKey(loginButton);

  Future<void> login(String email, String password) async {
    await enterEmail(email);
    await enterPassword(password);
    await tapLogin();
  }

  bool isErrorVisible() => isVisible(errorMessage);
}
