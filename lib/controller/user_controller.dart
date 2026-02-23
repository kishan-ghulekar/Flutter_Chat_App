import 'package:shared_preferences/shared_preferences.dart';

class UserController {
  String? profileImage;
  String? name;
  String? emailId;
  String? userId;
  bool? isLogged;

  Future<void> setUserData({
    required String profileImage,
    required String name,
    required String emailId,
    required String userId,
    required bool isLoggedIn,
  }) async {
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    await sharedPreferences.setString("profileImage", profileImage);
    await sharedPreferences.setString("name", name);
    await sharedPreferences.setString("emailId", emailId);
    await sharedPreferences.setString("userId", userId);
    await sharedPreferences.setBool("loginFlag", isLoggedIn);
  }

  Future<void> getUserData() async {
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    profileImage = sharedPreferences.getString("profileImage") ?? "";
    name = sharedPreferences.getString("name") ?? "";
    emailId = sharedPreferences.getString("emailId") ?? "";
    userId = sharedPreferences.getString("userId") ?? "";
    isLogged = sharedPreferences.getBool("loginFlag") ?? false;
  }
}
