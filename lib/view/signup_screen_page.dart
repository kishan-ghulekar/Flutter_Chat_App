import 'dart:developer';
import 'dart:io';

import 'package:chat_app/controller/login_controller.dart';
import 'package:chat_app/controller/user_controller.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class SignupScreenPage extends StatefulWidget {
  const SignupScreenPage({super.key});

  State<SignupScreenPage> createState() => _SignupScreenPageState();
}

class _SignupScreenPageState extends State<SignupScreenPage> {
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController nameController = TextEditingController();

  ImagePicker picker = ImagePicker();
  XFile? selectedImage;

  LoginController loginController = LoginController();

  bool isRegisterLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Transform.flip(
              flipX: true,
              child: Container(
                alignment: Alignment.center,
                child: Image.asset(
                  "assets/images/logincontainer.png",
                  fit: BoxFit.fitWidth,
                  width: 380,
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(
              "SignUp Now",
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "Please fill the details and create account",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            GestureDetector(
              onTap: () async {
                selectedImage = await picker.pickImage(
                  source: ImageSource.gallery,
                );
                log(selectedImage!.path);
                setState(() {});
              },
              child: Container(
                padding: EdgeInsets.all(2),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child:
                      (selectedImage == null)
                          ? Image.network(
                            "https://cdn.pixabay.com/photo/2023/02/18/11/00/icon-7797704_640.png",
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          )
                          : Image.file(
                            File(selectedImage!.path),
                            width: 100,
                            height: 100,
                          ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 10,
              ),
              child: TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: "Enter Name",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 10,
              ),
              child: TextField(
                controller: emailController,
                decoration: InputDecoration(
                  hintText: "Enter Email",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 10,
              ),
              child: TextField(
                controller: passwordController,
                decoration: InputDecoration(
                  hintText: "Enter Password",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                if (!isRegisterLoading) {
                  signupData();
                }
              },

              style: ButtonStyle(
                minimumSize: WidgetStatePropertyAll(Size(380, 50)),
                backgroundColor: WidgetStatePropertyAll(Colors.lightBlue),
              ),
              child:
                  (isRegisterLoading)
                      ? CircularProgressIndicator()
                      : Text(
                        "SignUp",
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
            ),
            SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
              },
              child: Text(
                "Already have an account? Login",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
              ),
            ),
          ],
        ),
      ),
    );
  }

  signupData() async {
    isRegisterLoading = true;
    setState(() {});

    String fileName =
        DateTime.now().microsecondsSinceEpoch.toString() + selectedImage!.name;

    await loginController.uploadImage(
      fileName: fileName,
      file: File(selectedImage!.path),
    );

    String generateImageUrl = await loginController.getImageUrl(
      fileName: fileName,
    );
    log("GENERATED IMAGE URL: $generateImageUrl");

    //Register user with email and password
    String userId = await loginController.registerUser(
      context: context,
      email: emailController.text.trim(),
      password: passwordController.text.trim(),
    );
    if (userId != "") {
      Map<String, dynamic> userDataObj = {
        "name": nameController.text.trim(),
        "email": emailController.text.trim(),
        "profile_image": generateImageUrl,
        "userId": userId,
      };

      await loginController.storeUserDataToDatabase(userData: userDataObj);

      UserController _userController = UserController();
      _userController.setUserData(
        profileImage: generateImageUrl,
        name: nameController.text.trim(),
        emailId: emailController.text.trim(),
        userId: userId,
        isLoggedIn: true,
      );

      nameController.clear();
      emailController.clear();
      passwordController.clear();
      selectedImage = null;

      Navigator.of(context).pop();
    }
    isRegisterLoading = false;
    setState(() {});
  }
}
