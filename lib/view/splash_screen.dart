import 'package:chat_app/view/chat_screen.dart';
import 'package:chat_app/view/login_screen.dart';
import '../../controller/user_controller.dart';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  @override
  SplashScreen({super.key});

  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    navigateToScreen();
  }

  navigateToScreen() {
    Future.delayed(const Duration(seconds: 2), () async {
      UserController _userController = UserController();
      await _userController.getUserData();

      if (_userController.isLogged!) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => ChatScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue,
      body: Center(
        child: Image(image: AssetImage("assets/images/SplashScreenStick.png")),
      ),
    );
  }
}
