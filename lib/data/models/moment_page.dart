import 'moment.dart';

/// Keep already-loaded history when a new moment moves the live page boundary.
List<Moment> retainOlderMoments({
  required List<Moment> latest,
  required List<Moment> previous,
  required List<Moment> older,
}) {
  if (latest.isEmpty || older.isEmpty) return List.of(older);
  final known = latest.map((moment) => moment.id).toSet();
  final boundary = latest.last;
  bool beforeBoundary(Moment moment) {
    final time = moment.createdAt.compareTo(boundary.createdAt);
    // Firestore's implicit document-ID order follows the descending date order.
    return time < 0 || (time == 0 && moment.id.compareTo(boundary.id) < 0);
  }

  final byId = {
    for (final moment in older)
      if (!known.contains(moment.id)) moment.id: moment,
    for (final moment in previous)
      if (!known.contains(moment.id) && beforeBoundary(moment))
        moment.id: moment,
  };
  return byId.values.toList()..sort((a, b) {
    final time = b.createdAt.compareTo(a.createdAt);
    return time == 0 ? b.id.compareTo(a.id) : time;
  });
}
