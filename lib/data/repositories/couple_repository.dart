import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../services/local_storage_service.dart';
import '../services/firebase_couple_service.dart';
import '../models/moment.dart';
import '../models/moment_page.dart';
import '../models/couple_state.dart';
import '../services/firebase_config.dart';

class CoupleRepository {
  CoupleRepository(this.storage, {this.cloud}) {
    state = cloud?.auth.currentUser == null ? storage.read() : {};
  }
  final LocalStorageService storage;
  final FirebaseCoupleService? cloud;
  late Map<String, dynamic> state;
  final _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;
  final List<StreamSubscription<dynamic>> _spaceSubscriptions = [];
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<dynamic>? _profileSubscription;
  StreamSubscription<dynamic>? _partnerAnswers;
  String? _spaceId;
  Map<String, dynamic> _sharedProfile = {};
  bool _memberConfirmed = false;
  int _generation = 0;
  int _sessionGeneration = 0;
  bool loading = false, cached = false, hasMore = false;
  String? error;
  QueryDocumentSnapshot<Map<String, dynamic>>? _cursor;
  final List<Moment> _older = [];
  String get day => DateTime.now().toUtc().toIso8601String().substring(0, 10);
  String? get uid => cloud?.auth.currentUser?.uid;
  bool get isCloud => uid != null;
  String? get spaceId => _spaceId;
  bool get paired => ((state['memberIds'] as List?)?.length ?? 0) == 2;
  bool get verified =>
      isCloud &&
      (FirebaseConfig.emulator ||
          kDebugMode ||
          (cloud?.auth.currentUser?.emailVerified ?? false) ||
          (cloud?.auth.currentUser?.isAnonymous ?? false));
  List<Moment>? _cachedMoments;
  List<Countdown>? _cachedCountdowns;
  final Map<String, Uint8List> _photoCache = {};

  List<Moment> get moments {
    if (_cachedMoments != null) return _cachedMoments!;
    final raw = state['moments'] as List?;
    if (raw == null || raw.isEmpty) return _cachedMoments = const [];
    return _cachedMoments = raw
        .map((e) => Moment.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  List<Countdown> get countdowns {
    if (_cachedCountdowns != null) return _cachedCountdowns!;
    final raw = state['countdowns'] as List?;
    if (raw == null || raw.isEmpty) return _cachedCountdowns = const [];
    return _cachedCountdowns = raw
        .map((e) => Countdown.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  void _invalidateCaches() {
    _cachedMoments = null;
    _cachedCountdowns = null;
  }

  void _emit() {
    _invalidateCaches();
    if (!_changes.isClosed) _changes.add(null);
  }

  void _failure(Object e) {
    error = backendMessage(e);
    loading = false;
    _emit();
  }

  void start() {
    if (cloud == null || _authSubscription != null) return;
    _authSubscription = cloud!.auth.authStateChanges().listen(
      (_) => refresh(),
      onError: _failure,
    );
  }

  Future<void> _stopSpace() async {
    _generation++;
    _sharedProfile = {};
    _memberConfirmed = false;
    await _partnerAnswers?.cancel();
    _partnerAnswers = null;
    for (final subscription in _spaceSubscriptions) {
      await subscription.cancel();
    }
    _spaceSubscriptions.clear();
    _older.clear();
    _cursor = null;
    hasMore = false;
    _spaceId = null;
  }

  Future<void> refresh() async {
    final session = ++_sessionGeneration;
    await _profileSubscription?.cancel();
    if (session != _sessionGeneration) return;
    _profileSubscription = null;
    await _stopSpace();
    if (session != _sessionGeneration) return;
    error = null;
    cached = false;
    if (!isCloud) {
      state = storage.read();
      loading = false;
      _emit();
      return;
    }
    final identity = uid!;
    state = {};
    loading = true;
    _emit();
    _profileSubscription = cloud!.db
        .doc('users/$identity')
        .snapshots(includeMetadataChanges: true)
        .listen((snapshot) async {
          if (uid != identity || session != _sessionGeneration) return;
          final profile = snapshot.data() ?? {};
          final nextSpace = profile['spaceId'] as String?;
          if (_spaceId != nextSpace) {
            await _stopSpace();
            if (uid != identity || session != _sessionGeneration) return;
            state = {...profile};
            _spaceId = nextSpace;
            if (nextSpace != null) _listenSpace(nextSpace);
          } else {
            state = mergeProfileState(state, profile, _sharedProfile);
          }
          loading = false;
          cached = snapshot.metadata.isFromCache;
          error = null;
          _emit();
        }, onError: _failure);
  }

  void _listenSpace(String space) {
    final generation = _generation;
    final identity = uid!;
    final questionDay = day;
    bool valid() => generation == _generation && uid == identity;
    void fail(Object e) {
      if (!valid()) return;
      if (e is FirebaseException && e.code == 'permission-denied') {
        state.removeWhere(
          (key, _) => [
            'moments',
            'countdowns',
            'answers',
            'partnerAnswer',
            'answerAuthors',
            'memberIds',
            'partner',
          ].contains(key),
        );
        _stopSpace();
      }
      _failure(e);
    }

    final ref = cloud!.db.doc('spaces/$space');
    _spaceSubscriptions.add(
      ref
          .snapshots(includeMetadataChanges: true)
          .listen(
            (snapshot) {
              if (!valid()) return;
              if (snapshot.metadata.isFromCache && !_memberConfirmed) return;
              final data = snapshot.data();
              if (data == null ||
                  !(data['memberIds'] as List).contains(identity)) {
                state.removeWhere(
                  (key, _) => [
                    'moments',
                    'countdowns',
                    'partnerAnswer',
                    'answerAuthors',
                    'answers',
                    'memberIds',
                    'partner',
                  ].contains(key),
                );
                _stopSpace();
                _emit();
                return;
              }
              if (!snapshot.metadata.isFromCache) _memberConfirmed = true;
              final names = Map<String, dynamic>.from(data['names'] ?? {});
              _sharedProfile = {
                'memberIds': data['memberIds'],
                'partner':
                    names.entries
                        .where((e) => e.key != identity)
                        .map((e) => e.value)
                        .firstOrNull ??
                    '',
                'relationship': data['relationship'],
                'anniversary': data['anniversary'],
              };
              state = {...state, ..._sharedProfile};
              cached = snapshot.metadata.isFromCache;
              _emit();
            },
            onError: (Object e) {
              fail(e);
            },
          ),
    );
    _spaceSubscriptions.add(
      ref
          .collection('moments')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(includeMetadataChanges: true)
          .listen(
            (snapshot) {
              if (!valid()) return;
              if (snapshot.metadata.isFromCache && !_memberConfirmed) return;
              final latest = snapshot.docs
                  .map((doc) => _moment(doc.data()))
                  .toList();
              final known = latest.map((m) => m.id).toSet();
              if (!snapshot.metadata.isFromCache && latest.length < 50) {
                // The complete collection now fits in this server snapshot.
                _older.clear();
              } else {
                final retained = retainOlderMoments(
                  latest: latest,
                  previous: moments,
                  older: _older,
                );
                _older
                  ..clear()
                  ..addAll(retained);
              }
              _older.removeWhere((m) => known.contains(m.id));
              state['moments'] = [
                ...latest,
                ..._older,
              ].map((m) => m.toJson()).toList();
              _cursor ??= snapshot.docs.lastOrNull;
              if (_older.isEmpty) {
                _cursor = snapshot.docs.lastOrNull;
                hasMore = snapshot.docs.length == 50;
              }
              cached = snapshot.metadata.isFromCache;
              _emit();
            },
            onError: (Object e) {
              fail(e);
            },
          ),
    );
    _spaceSubscriptions.add(
      ref
          .collection('countdowns')
          .orderBy('date')
          .snapshots(includeMetadataChanges: true)
          .listen(
            (snapshot) {
              if (!valid()) return;
              if (snapshot.metadata.isFromCache && !_memberConfirmed) return;
              state['countdowns'] = snapshot.docs
                  .map((d) => {...d.data(), 'id': d.id})
                  .toList();
              _emit();
            },
            onError: (Object e) {
              fail(e);
            },
          ),
    );
    _spaceSubscriptions.add(
      ref
          .collection('questions')
          .doc(questionDay)
          .collection('answers')
          .doc(identity)
          .snapshots(includeMetadataChanges: true)
          .listen(
            (snapshot) async {
              if (!valid()) return;
              if (snapshot.metadata.isFromCache && !_memberConfirmed) return;
              state['answers'] = {
                questionDay: snapshot.data()?['answer'] ?? '',
              };
              await _partnerAnswers?.cancel();
              if (!valid()) return;
              _partnerAnswers = null;
              state.remove('partnerAnswer');
              state.remove('answerAuthors');
              if (snapshot.exists && valid()) {
                _partnerAnswers = ref
                    .collection('questions')
                    .doc(questionDay)
                    .collection('answers')
                    .snapshots(includeMetadataChanges: true)
                    .listen(
                      (answers) {
                        if (!valid()) return;
                        if (answers.metadata.isFromCache && !_memberConfirmed) {
                          return;
                        }
                        state['answerAuthors'] = {
                          for (final doc in answers.docs)
                            doc.id: doc.data()['answer'],
                        };
                        _emit();
                      },
                      onError: (Object e) {
                        fail(e);
                      },
                    );
              }
              _emit();
            },
            onError: (Object e) {
              fail(e);
            },
          ),
    );
  }

  static Moment _moment(Map<String, dynamic> data) {
    final drawing = data['drawing'] as List?;
    return Moment.fromJson({
      ...data,
      'createdAt':
          (data['createdAt'] as Timestamp?)?.toDate().toIso8601String() ??
          DateTime.now().toIso8601String(),
      'drawing': drawing
          ?.map((p) => p is Map ? [p['x'], p['y'], p['color']] : p)
          .toList(),
    });
  }

  Future<void> loadMore() async {
    if (!isCloud || _spaceId == null || _cursor == null || !hasMore) return;
    final generation = _generation;
    final snapshot = await cloud!.db
        .collection('spaces/$_spaceId/moments')
        .orderBy('createdAt', descending: true)
        .startAfterDocument(_cursor!)
        .limit(50)
        .get();
    if (generation != _generation) return;
    _older.addAll(snapshot.docs.map((d) => _moment(d.data())));
    _cursor = snapshot.docs.lastOrNull ?? _cursor;
    hasMore = snapshot.docs.length == 50;
    final byId = {
      for (final m in [...moments, ..._older]) m.id: m,
    };
    state['moments'] = byId.values.map((m) => m.toJson()).toList();
    _emit();
  }

  Future<void> update(Map<String, dynamic> values) async {
    if (isCloud) {
      await cloud!.call('saveProfile', {
        'name': values['name'],
        'relationship': values['relationship'],
        'anniversary': (values['anniversary'] as String).substring(0, 10),
      });
      return;
    }
    final next = {...state, ...values};
    await storage.write(next);
    state = next;
    _emit();
  }

  static String newId() {
    final random = Random.secure();
    return List.generate(
      20,
      (_) =>
          'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'[random
              .nextInt(62)],
    ).join();
  }

  Future<void> addMoment(Moment moment) async {
    if (isCloud) {
      await cloud!.call('sendMoment', {
        'id': moment.id,
        'kind': moment.kind,
        'content': moment.content,
        if (moment.drawing != null) 'drawing': moment.drawing,
        if (moment.photoPath != null) 'photoPath': moment.photoPath,
      });
    } else {
      await update({
        'moments': [moment, ...moments].map((e) => e.toJson()).toList(),
      });
    }
  }

  Future<void> saveAnswer(String text, {String? questionDay}) async {
    final answerDay = questionDay ?? day;
    if (answerDay != day) {
      throw StateError(
        'Today’s question has changed. Open the new question to answer.',
      );
    }
    if (isCloud) {
      await cloud!.call('saveAnswer', {'day': answerDay, 'answer': text});
    } else {
      await update({
        'answers': {...?(state['answers'] as Map?), answerDay: text},
      });
    }
  }

  Future<void> addCountdown(String title, DateTime date) async {
    final id = newId();
    if (isCloud) {
      await cloud!.call('addCountdown', {
        'id': id,
        'title': title,
        'date': date.toIso8601String().substring(0, 10),
      });
    } else {
      await update({
        'countdowns': [
          ...countdowns,
          Countdown(title, date, id: id),
        ].map((c) => c.toJson()).toList(),
      });
    }
  }

  Future<void> remove(String collection, String id) async {
    if (isCloud) {
      await cloud!.call('removeItem', {'collection': collection, 'id': id});
      if (collection == 'moments') {
        // Earlier pages are fetched once, so remove deleted items from that cache.
        _older.removeWhere((moment) => moment.id == id);
        state['moments'] = moments
            .where((moment) => moment.id != id)
            .map((moment) => moment.toJson())
            .toList();
        _emit();
      }
    } else {
      await update({
        collection: ((state[collection] as List?) ?? [])
            .where((item) => item['id'] != id)
            .toList(),
      });
    }
  }

  Future<Map<String, dynamic>> export() async =>
      isCloud ? cloud!.call('exportData') : Map.of(state);
  Future<void> clear() async {
    _photoCache.clear();
    await storage.write({});
    if (!isCloud) {
      state = {};
      _emit();
    }
  }

  Future<Uint8List?> photo(String path) async {
    final cached = _photoCache[path];
    if (cached != null) return cached;
    final bytes = await cloud?.photo(path);
    if (bytes != null) {
      if (_photoCache.length >= 60) {
        _photoCache.remove(_photoCache.keys.first);
      }
      _photoCache[path] = bytes;
    }
    return bytes;
  }
  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _profileSubscription?.cancel();
    await _stopSpace();
    await _changes.close();
  }
}
