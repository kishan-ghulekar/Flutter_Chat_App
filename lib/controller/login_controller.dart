import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class LoginController {
  final FirebaseStorage _firebaseStorage = FirebaseStorage.instance;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firebaseFirestore = FirebaseFirestore.instance;

  Future<void> uploadImage({
    required String fileName,
    required File file,
  }) async {
    log("Uploading image to Firebase storage");
    await _firebaseStorage.ref().child(fileName).putFile(file);
  }

  Future<String> getImageUrl({required String fileName}) async {
    String url = await _firebaseStorage.ref().child(fileName).getDownloadURL();
    return url;
  }

  Future<String> registerUser({
    required BuildContext context,
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredentialObj = await _firebaseAuth
          .createUserWithEmailAndPassword(email: email, password: password);
      log("User Creadiantal: $userCredentialObj");

      if (userCredentialObj.user != null) {
        log(
          "User Registered Successfully with UID: ${userCredentialObj.user!.uid}",
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("User Registered Successfully"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            margin: EdgeInsets.all(15),
            duration: Duration(seconds: 2),
          ),
        );
        return userCredentialObj.user!.uid;
      }
    } on FirebaseAuthException catch (error) {
      log("Error during registration: ${error.message}");
    }
    return "";
  }

  Future<void> storeUserDataToDatabase({
    required Map<String, dynamic> userData,
  }) async {
    await _firebaseFirestore.collection("Users").add(userData);
  }

  Future<bool> loginUser({
    required BuildContext context,
    required String email,
    required String password,
  }) async {
    UserCredential userCredentialObj = await _firebaseAuth
        .signInWithEmailAndPassword(email: email, password: password);
    log("Login Status= $userCredentialObj");

    if (userCredentialObj.user != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Login Successfully"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          margin: EdgeInsets.all(15),
          duration: Duration(seconds: 2),
        ),
      );

      return true;
    }
    return false;
  }
}
