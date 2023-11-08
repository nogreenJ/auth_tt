import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:twitter_login/twitter_login.dart';
import 'text_composer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'keys.dart' as keys;

class ChatScreen extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return ChatScreenState();
  }
}

class ChatScreenState extends State<ChatScreen> {
  User? _currentUser;
  FirebaseAuth auth = FirebaseAuth.instance;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLoading = false;

  final CollectionReference _mensagens =
      FirebaseFirestore.instance.collection("mensagens");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Chat App"),
        ),
        body: Column(
          children: <Widget>[
            Expanded(
                child: StreamBuilder<QuerySnapshot>(
              stream: _mensagens.orderBy("time").snapshots(),
              builder: (context, snapshot) {
                switch (snapshot.connectionState) {
                  case ConnectionState.waiting:
                    return Center(child: CircularProgressIndicator());
                  default:
                    List<DocumentSnapshot> documents =
                        snapshot.data!.docs.reversed.toList();
                    return ListView.builder(
                        itemCount: documents.length,
                        reverse: true,
                        itemBuilder: (context, index) {
                          return Container(
                            margin: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 10),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                    child: Column(
                                  children: <Widget>[
                                    documents[index].get('url') != ""
                                        ? Image.network(
                                            documents[index].get('url'),
                                            width: 150)
                                        : Text(
                                            documents[index].get('text'),
                                            style: TextStyle(fontSize: 16),
                                          )
                                  ],
                                ))
                              ],
                            ),
                          );
                        });
                }
              },
            )),
            TextComposer(_sendMessage),
          ],
        ));
  }

  void _sendMessage({String? text, XFile? imgFile}) async {
    User? user = await _getUser(context: context);
    if (user == null) {
      return;
    }

    Map<String, dynamic> data = {
      'url': "",
      'time': Timestamp.now(),
    };

    if (imgFile != null) {
      firebase_storage.UploadTask uploadTask;
      firebase_storage.Reference ref = firebase_storage.FirebaseStorage.instance
          .ref()
          .child("imgs")
          .child(DateTime.now().millisecondsSinceEpoch.toString());
      final metadados = firebase_storage.SettableMetadata(
          contentType: "image/jpeg",
          customMetadata: {"picked-file-path": imgFile.path});
      if (kIsWeb) {
        uploadTask = ref.putData(await imgFile.readAsBytes(), metadados);
      } else {
        uploadTask = ref.putFile(File(imgFile.path));
      }
      var taskSnapshot = await uploadTask;
      String imageUrl = "";
      imageUrl = await taskSnapshot.ref.getDownloadURL();
      data['url'] = imageUrl;
    } else {
      data["text"] = text;
    }
    _mensagens.add(data);
  }

  Future<User?> _getUser({required BuildContext context}) async {
    if (_currentUser != null) {
      return _currentUser;
    }
    User? user;
    if (kIsWeb) {
      TwitterAuthProvider authProvider = TwitterAuthProvider();
      try {
        final UserCredential userCredential =
            await auth.signInWithPopup(authProvider);
        user = userCredential.user;
      } catch (e) {
        print(e);
      }
    } else {
      final twitterLogin = TwitterLogin(
        apiKey: keys.apiKey,
        apiSecretKey: keys.apiSecretKey,
        redirectURI: "twittersdk://",
      );
      final authResult = await twitterLogin.login();

      if (authResult.status == TwitterLoginStatus.loggedIn) {
        final AuthCredential twitterAuthCredential =
            TwitterAuthProvider.credential(
                accessToken: authResult.authToken!,
                secret: authResult.authTokenSecret!);

        final userCredential =
            await auth.signInWithCredential(twitterAuthCredential);
        _currentUser = userCredential.user;
      }
    }
    if (_currentUser == null) {
      return null;
    }
    _currentUser = user;
    print("user logado: " + user!.displayName.toString());
    return user;
  }
}
