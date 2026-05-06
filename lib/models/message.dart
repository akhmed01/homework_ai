import 'dart:io';

class Message {
  final String id;
  final String text;
  final bool isUser;
  final File? image;

  Message({String? id, required this.text, required this.isUser, this.image})
    : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();
}
