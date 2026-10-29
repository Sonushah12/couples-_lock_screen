import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseCoupleService {
  FirebaseCoupleService({
    required this.auth,
    required this.db,
    required this.functions,
    required this.storage,
  });
  final FirebaseAuth auth;
  final FirebaseFirestore db;
  final FirebaseFunctions functions;
  final FirebaseStorage storage;
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> data = const {},
  ]) async {
    try {
      final result = await functions
          .httpsCallable(
            name,
            options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
          )
          .call(data);
      return Map<String, dynamic>.from(result.data as Map);
    } catch (_) {
      return await _directFallback(name, data);
    }
  }

  Future<Map<String, dynamic>> _directFallback(
    String name,
    Map<String, dynamic> data,
  ) async {
    final user = auth.currentUser;
    if (user == null) {
      throw StateError('Sign in to continue.');
    }
    final uid = user.uid;

    switch (name) {
      case 'saveProfile':
        final n = (data['name'] as String?)?.trim() ?? '';
        final rel = (data['relationship'] as String?)?.trim() ?? 'Couple';
        final ann = (data['anniversary'] as String?)?.trim() ??
            DateTime.now().toIso8601String().substring(0, 10);
        final userRef = db.doc('users/$uid');
        final userSnap = await userRef.get();
        final spaceId = userSnap.data()?['spaceId'] as String?;
        await userRef.set({
          'name': n,
          'relationship': rel,
          'anniversary': ann,
          'onboarded': true,
          'updatedAt': FieldValue.serverTimestamp(),
          if (!userSnap.exists) ...{
            'spaceId': null,
            'notifications': false,
            'createdAt': FieldValue.serverTimestamp(),
          },
        }, SetOptions(merge: true));
        if (spaceId != null) {
          await db.doc('spaces/$spaceId').set({
            'names': {uid: n},
            'relationship': rel,
            'anniversary': ann,
          }, SetOptions(merge: true));
        }
        return {'ok': true};

      case 'createInvite':
        final userRef = db.doc('users/$uid');
        final userSnap = await userRef.get();
        final userData = userSnap.data() ?? {};
        String spaceId = userData['spaceId'] as String? ?? '';
        if (spaceId.isEmpty) {
          final newSpaceRef = db.collection('spaces').doc();
          spaceId = newSpaceRef.id;
          await newSpaceRef.set({
            'memberIds': [uid],
            'names': {uid: userData['name'] ?? 'You'},
            'relationship': userData['relationship'] ?? 'Couple',
            'anniversary': userData['anniversary'] ??
                DateTime.now().toIso8601String().substring(0, 10),
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        final rand = Random();
        final code = List.generate(
          12,
          (_) => '0123456789ABCDEF'[rand.nextInt(16)],
        ).join();
        final expiresAt = DateTime.now().add(const Duration(hours: 24));
        await db.collection('invites').doc(code).set({
          'ownerId': uid,
          'spaceId': spaceId,
          'code': code,
          'expiresAt': Timestamp.fromDate(expiresAt),
          'used': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        await userRef.set({'spaceId': spaceId, 'activeInvite': code},
            SetOptions(merge: true));
        return {'code': code, 'expiresAt': expiresAt.toIso8601String()};

      case 'acceptInvite':
        final rawCode = (data['code'] as String?)?.trim().toUpperCase() ?? '';
        final inviteRef = db.collection('invites').doc(rawCode);
        final inviteSnap = await inviteRef.get();
        if (!inviteSnap.exists) {
          throw StateError('This invitation has expired or is invalid.');
        }
        final invite = inviteSnap.data()!;
        if (invite['used'] == true) {
          throw StateError('This invitation has already been used.');
        }
        final spaceId = invite['spaceId'] as String;
        final userRef = db.doc('users/$uid');
        final userSnap = await userRef.get();
        final userName = userSnap.data()?['name'] ?? 'Partner';
        await db.doc('spaces/$spaceId').update({
          'memberIds': FieldValue.arrayUnion([uid]),
          'names.$uid': userName,
        });
        await userRef.set({'spaceId': spaceId}, SetOptions(merge: true));
        await inviteRef.update({'used': true, 'acceptedBy': uid});
        return {'ok': true};

      case 'sendMoment':
        final id = data['id'] as String;
        final userSnap = await db.doc('users/$uid').get();
        final spaceId = userSnap.data()?['spaceId'] as String?;
        if (spaceId == null) {
          throw StateError('Connect with your partner first.');
        }
        final userName = userSnap.data()?['name'] ?? 'You';
        await db.collection('spaces/$spaceId/moments').doc(id).set({
          'id': id,
          'kind': data['kind'],
          'content': data['content'],
          if (data['drawing'] != null) 'drawing': data['drawing'],
          if (data['photoPath'] != null) 'photoPath': data['photoPath'],
          'senderId': uid,
          'senderName': userName,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return {'ok': true, 'id': id};

      case 'saveAnswer':
        final day = data['day'] as String;
        final answer = data['answer'] as String;
        final userSnap = await db.doc('users/$uid').get();
        final spaceId = userSnap.data()?['spaceId'] as String?;
        if (spaceId == null) {
          throw StateError('Connect with your partner first.');
        }
        await db
            .doc('spaces/$spaceId/questions/$day/answers/$uid')
            .set({'answer': answer, 'updatedAt': FieldValue.serverTimestamp()});
        return {'ok': true};

      case 'addCountdown':
        final id = data['id'] as String;
        final title = data['title'] as String;
        final date = data['date'] as String;
        final userSnap = await db.doc('users/$uid').get();
        final spaceId = userSnap.data()?['spaceId'] as String?;
        if (spaceId == null) {
          throw StateError('Connect with your partner first.');
        }
        await db.collection('spaces/$spaceId/countdowns').doc(id).set({
          'id': id,
          'title': title,
          'date': date,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return {'ok': true};

      case 'removeItem':
        final col = data['collection'] as String;
        final id = data['id'] as String;
        final userSnap = await db.doc('users/$uid').get();
        final spaceId = userSnap.data()?['spaceId'] as String?;
        if (spaceId != null) {
          await db.doc('spaces/$spaceId/$col/$id').delete();
        }
        return {'ok': true};

      case 'disconnectPartner':
        final userSnap = await db.doc('users/$uid').get();
        final spaceId = userSnap.data()?['spaceId'] as String?;
        if (spaceId != null) {
          await db.doc('spaces/$spaceId').update({
            'memberIds': FieldValue.arrayRemove([uid]),
          });
          await db.doc('users/$uid').update({
            'spaceId': FieldValue.delete(),
            'activeInvite': FieldValue.delete(),
          });
        }
        return {'ok': true};

      default:
        return {'ok': true};
    }
  }

  Future<void> upload(String path, Uint8List bytes, String contentType) async {
    if (bytes.length >= 5 * 1024 * 1024) {
      throw StateError('Choose a photo smaller than 5 MB.');
    }
    await storage
        .ref(path)
        .putData(bytes, SettableMetadata(contentType: contentType));
  }

  /// Authenticated SDK reads avoid permanent public download-token URLs.
  Future<Uint8List?> photo(String path) =>
      storage.ref(path).getData(5 * 1024 * 1024);
}

String backendMessage(Object error) {
  if (error is FirebaseFunctionsException) {
    return error.message ?? 'Please retry when you are connected.';
  }
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'invalid-credential' ||
      'user-not-found' ||
      'wrong-password' => 'The email or password is incorrect.',
      'email-already-in-use' =>
        'This email already has an account. Sign in instead.',
      'weak-password' => 'Use at least eight characters for your password.',
      'too-many-requests' =>
        'Too many attempts. Please wait before trying again.',
      'network-request-failed' => 'Check your connection and try again.',
      'requires-recent-login' => 'Sign in again to confirm this action.',
      _ => error.message ?? 'Could not sign in. Please retry.',
    };
  }
  if (error is FirebaseException) {
    return 'Could not connect. Check your connection and retry.';
  }
  if (error is StateError) return error.message.toString();
  return 'Something went wrong. Please try again.';
}
