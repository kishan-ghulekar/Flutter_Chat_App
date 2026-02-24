import 'package:chat_app/controller/login_controller.dart';
import 'package:chat_app/view/chat_screen.dart';
import 'package:chat_app/view/signup_screen_page.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  final LoginController _loginController = LoginController();

  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: MediaQuery.of(context).size.width * .95,

              alignment: Alignment.centerLeft,
              child: Image.asset(
                "assets/images/logincontainer.png",
                width: MediaQuery.of(context).size.width * .95,
                fit: BoxFit.cover,
              ),
            ),
            SizedBox(height: 20),
            Text(
              "Login Now",
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "Please login to continue using our app",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
            ),
            SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 20,
              ),
              child: TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: "Enter Email",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 20,
              ),
              child: TextField(
                controller: passwordController,
                decoration: InputDecoration(
                  labelText: "Enter Password",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: () async {
                isLoading = true;
                setState(() {});

                bool status = await _loginController.loginUser(
                  context: context,
                  email: emailController.text,
                  password: passwordController.text,
                );

                if (status) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) {
                        return ChatScreen();
                      },
                    ),
                    (r) => false,
                  );
                }
                isLoading = false;
                setState(() {});
              },
              style: ButtonStyle(
                minimumSize: WidgetStatePropertyAll(Size(380, 50)),
                backgroundColor: WidgetStatePropertyAll(Colors.lightBlue),
              ),
              child: Text(
                "Login",
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
            SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) {
                      return SignupScreenPage();
                    },
                  ),
                );
              },
              child: Text(
                "Don't have an account?Sign Up",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
