import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/homework.dart';

class HomeworkService {
  static final _db = FirebaseFirestore.instance;

  static String get _uid => FirebaseAuth.instance.currentUser!.uid;

  static CollectionReference get _collection =>
      _db.collection('users').doc(_uid).collection('homework');

  static Stream<List<Homework>> getHomework() {
    return _collection
        .orderBy('dueDate')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (doc) => Homework.fromMap(
                  doc.id,
                  doc.data() as Map<String, dynamic>,
                ),
              )
              .toList(),
        );
  }

  static Future<void> addHomework(Homework hw) async {
    await _collection.add(hw.toMap());
  }

  static Future<void> toggleDone(String id, bool current) async {
    await _collection.doc(id).update({'isDone': !current});
  }

  static Future<void> deleteHomework(String id) async {
    await _collection.doc(id).delete();
  }
}
