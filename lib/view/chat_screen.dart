// import 'dart:developer';

// import 'package:chat_app/controller/chat_controller.dart';
// import 'package:chat_app/controller/user_controller.dart';
// import 'package:chat_app/view/login_screen.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';

// class ChatScreen extends StatefulWidget {
//   const ChatScreen({super.key});

//   @override
//   State<ChatScreen> createState() => _ChatScreenState();
// }

// class _ChatScreenState extends State<ChatScreen> {
//   final TextEditingController _messageController = TextEditingController();
//   final ChatController _chatController = ChatController();
//   final UserController _userController = UserController();
//   final ScrollController _ScrollController = ScrollController();

//   @override
//   void initState() {
//     super.initState();
//     Future.delayed(Duration(seconds: 0), () async {
//       await _userController.getUserData();
//     });
//   }

//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         toolbarHeight: 70,
//         backgroundColor: Colors.blue,

//         title: Row(
//           children: [
//             ClipRRect(
//               borderRadius: BorderRadius.circular(40),
//               child: Image.network(
//                 "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSOH2aZnIHWjMQj2lQUOWIL2f4Hljgab0ecZQ&s",
//                 fit: BoxFit.cover,
//                 height: 60,
//                 width: 60,
//               ),
//             ),
//             SizedBox(width: 5),
//             Text("Flutter 2025"),
//           ],
//         ),
//         actions: [
//           IconButton(
//             onPressed: () {
//               FirebaseAuth.instance.signOut();
//               Navigator.of(context).pushReplacement(
//                 MaterialPageRoute(
//                   builder: (context) {
//                     return LoginScreen();
//                   },
//                 ),
//               );
//             },
//             icon: Icon(Icons.logout),
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           Expanded(
//             child: Container(
//               child: Container(
//                 color: Colors.white,
//                 child: Stack(
//                   children: [
//                     // StreamBuilder(
//                     //   stream:
//                     //       FirebaseFirestore.instance
//                     //           .collection("chatsData")
//                     //           .orderBy("time",descending: false)
//                     //           .snapshots(),
//                     //   builder: (context, snapshot) {
//                     //     log("Chat Data");
//                     //     return ListView.builder(
//                     //       itemCount: snapshot.data?.docs.length,
//                     //       itemBuilder: (context, index) {
//                     //         return messageCard(
//                     //           index: index,
//                     //           userId: snapshot.data?.docs[index]['userId'],
//                     //           profileImage:
//                     //               snapshot.data?.docs[index]['profileImage'],
//                     //           name: snapshot.data?.docs[index]['name'],
//                     //           message: snapshot.data?.docs[index]['message'],
//                     //           docId: snapshot.data!.docs[index].id.toString(),
//                     //           time: snapshot.data?.docs[index]['time'],
//                     //         );
//                     //       },
//                     //     );
//                     //   },
//                     // ),
//                     StreamBuilder<QuerySnapshot>(
//                       stream: ChatController().getMessages(),

//                       builder: (context, snapshot) {

//                         if (snapshot.connectionState ==
//                             ConnectionState.waiting) {
//                           return Center(child: CircularProgressIndicator());
//                         }

//                         if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
//                           return Center(child: Text("No messages"));
//                         }

//                         var messages = snapshot.data!.docs;

//                         return ListView.builder(
//                           itemCount: messages.length,
//                           itemBuilder: (context, index) {
//                             var data = messages[index];

//                             return ListTile(title: Text(data["message"]));
//                           },
//                         );
//                       },
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//           Padding(
//             padding: EdgeInsets.symmetric(horizontal: 20, vertical: 30),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: TextField(
//                     controller: _messageController,
//                     decoration: InputDecoration(
//                       fillColor: Colors.white,
//                       filled: true,
//                       border: InputBorder.none,
//                       hintText: "Type your messsage",
//                     ),
//                   ),
//                 ),
//                 GestureDetector(
//                   onTap: () async {
//                     Map<String, dynamic> data = {
//                       "profileImage": _userController.profileImage,
//                       "userId": _userController.userId,
//                       "name": _userController.name,
//                       "message": _messageController.text.trim(),
//                       "time": Timestamp.now(),
//                     };
//                     await _chatController.sendMessage(messageBody: data);
//                     _ScrollController.animateTo(
//                       _ScrollController.position.maxScrollExtent + 200,
//                       duration: Duration(seconds: 1),
//                       curve: Curves.ease,
//                     );
//                     _messageController.clear();
//                     log("Data $data");
//                   },
//                   child: Container(
//                     padding: EdgeInsets.all(10),
//                     decoration: BoxDecoration(
//                       shape: BoxShape.circle,
//                       color: Colors.blue,
//                     ),
//                     child: Icon(Icons.send),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   messageCard({
//     required int index,
//     required String userId,
//     required String profileImage,
//     required String name,
//     required Timestamp time,
//     required String message,
//     required String docId,
//   }) {
//     return Padding(
//       padding: const EdgeInsets.all(10),
//       child: GestureDetector(
//         onDoubleTap: () async {
//           if (_userController.userId == userId) {
//             Map<String, dynamic> updatedData = {
//               "profileImage": _userController.profileImage,
//               "userId": _userController.userId,
//               "name": _userController.name,
//               "message": "This message was deleted",
//               "time": time,
//             };
//             await _chatController.updateMessage(
//               docId: docId,
//               messageUpdateBody: updatedData,
//             );
//           }
//         },
//         child: Row(
//           mainAxisAlignment:
//               _userController.userId == userId
//                   ? MainAxisAlignment.end
//                   : MainAxisAlignment.start,
//           crossAxisAlignment: CrossAxisAlignment.end,
//           children: [
//             /// Profile Image (only for others)
//             if (_userController.userId != userId)
//               Padding(
//                 padding: const EdgeInsets.only(right: 8),
//                 child: ClipRRect(
//                   borderRadius: BorderRadius.circular(30),
//                   child:
//                       profileImage == ""
//                           ? Image.network(
//                             "https://play-lh.googleusercontent.com/Il1s7VYRV23p_J7m1rS8y96ldviGz0aCF31d_fLN1Yjaa8MrZGaNhqGe7uD7mHvXR2vu",
//                             height: 40,
//                             width: 40,
//                             fit: BoxFit.cover,
//                           )
//                           : Image.network(
//                             profileImage,
//                             height: 40,
//                             width: 40,
//                             fit: BoxFit.cover,
//                           ),
//                 ),
//               ),

//             /// Chat Bubble
//             Flexible(
//               child: Container(
//                 padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                 decoration: BoxDecoration(
//                   color:
//                       _userController.userId == userId
//                           ? Color(0xffDCF8C6)
//                           : Colors.grey.shade300,
//                   borderRadius: BorderRadius.only(
//                     topLeft: Radius.circular(15),
//                     topRight: Radius.circular(15),
//                     bottomLeft:
//                         _userController.userId == userId
//                             ? Radius.circular(15)
//                             : Radius.circular(0),
//                     bottomRight:
//                         _userController.userId == userId
//                             ? Radius.circular(0)
//                             : Radius.circular(15),
//                   ),
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     /// Name (only for others)
//                     if (_userController.userId != userId)
//                       Text(
//                         name,
//                         style: TextStyle(
//                           fontSize: 13,
//                           fontWeight: FontWeight.bold,
//                           color: Colors.blue,
//                         ),
//                       ),

//                     /// Message
//                     Text(message, style: TextStyle(fontSize: 15)),

//                     SizedBox(height: 5),

//                     /// Time bottom right
//                     Align(
//                       alignment: Alignment.bottomRight,
//                       child: Text(
//                         TimeOfDay.fromDateTime(time.toDate()).format(context),
//                         style: TextStyle(
//                           fontSize: 10,
//                           color: Colors.grey.shade600,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
import 'dart:developer';

import 'package:chat_app/controller/chat_controller.dart';
import 'package:chat_app/controller/user_controller.dart';
import 'package:chat_app/view/login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ChatController _chatController = ChatController();
  final UserController _userController = UserController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await _userController.getUserData();
    });
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    Map<String, dynamic> data = {
      "profileImage": _userController.profileImage ?? "",
      "userId": _userController.userId,
      "name": _userController.name,
      "message": _messageController.text.trim(),
      "time": Timestamp.now(),
    };

    await _chatController.sendMessage(messageBody: data);

    _messageController.clear();

    Future.delayed(const Duration(milliseconds: 300), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    });

    log("Message Sent: $data");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        backgroundColor: Colors.white,
        elevation: 1,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: Image.network(
                "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSOH2aZnIHWjMQj2lQUOWIL2f4Hljgab0ecZQ&s",
                height: 50,
                width: 50,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            const Text("Flutter 2025", style: TextStyle(color: Colors.black)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              FirebaseAuth.instance.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            icon: const Icon(Icons.logout, color: Colors.black),
          ),
        ],
      ),
      body: Column(
        children: [
          /// CHAT AREA
          Expanded(
            child: Stack(
              children: [
                /// Background Image
                Positioned.fill(
                  child: Image.asset(
                    "assets/images/chat_bg.png", // Add in pubspec.yaml
                    fit: BoxFit.cover,
                  ),
                ),

                /// Messages
                StreamBuilder<QuerySnapshot>(
                  stream: _chatController.getMessages(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text("No messages yet"));
                    }

                    var messages = snapshot.data!.docs;

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        var data = messages[index];

                        return messageCard(
                          userId: data["userId"],
                          profileImage: data["profileImage"],
                          name: data["name"],
                          message: data["message"],
                          time: data["time"],

                          docId: messages[index].id,
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),

          /// MESSAGE INPUT
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: "Type your message...",
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue,
                    ),
                    child: const Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// MESSAGE BUBBLE
  Widget messageCard({
    required String userId,
    required String profileImage,
    required String name,
    required String message,
    required Timestamp time,
    required String docId,
  }) {
    bool isMe = _userController.userId == userId;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          /// Receiver Profile Image (only for others)
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: CircleAvatar(
                radius: 16,
                backgroundImage:
                    profileImage.isEmpty
                        ? const NetworkImage(
                          "https://play-lh.googleusercontent.com/Il1s7VYRV23p_J7m1rS8y96ldviGz0aCF31d_fLN1Yjaa8MrZGaNhqGe7uD7mHvXR2vu",
                        )
                        : NetworkImage(profileImage),
              ),
            ),

          /// Message Bubble
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color:
                    isMe
                        ? const Color(0xffDCF8C6) // sender color
                        : Colors.white, // receiver color
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft:
                      isMe
                          ? const Radius.circular(18)
                          : const Radius.circular(0),
                  bottomRight:
                      isMe
                          ? const Radius.circular(0)
                          : const Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// Receiver Name (optional)
                  if (!isMe)
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),

                  /// Message Text
                  Text(
                    message,
                    style: const TextStyle(fontSize: 15, color: Colors.black),
                  ),

                  const SizedBox(height: 4),

                  /// Time bottom right
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      TimeOfDay.fromDateTime(time.toDate()).format(context),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
