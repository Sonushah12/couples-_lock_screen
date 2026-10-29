class Moment {
  const Moment({
    required this.id,
    required this.kind,
    required this.content,
    required this.createdAt,
    this.drawing,
    this.senderId,
    this.senderName,
    this.photoPath,
  });
  final String id, kind, content;
  final DateTime createdAt;
  final List<List<double>>? drawing;
  final String? senderId, senderName, photoPath;
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'drawing': drawing,
    'senderId': senderId,
    'senderName': senderName,
    'photoPath': photoPath,
  };
  factory Moment.fromJson(Map<String, dynamic> json) => Moment(
    id: json['id'],
    kind: json['kind'],
    content: json['content'],
    createdAt: DateTime.parse(json['createdAt']),
    drawing: (json['drawing'] as List?)
        ?.map((e) => (e as List).map((n) => (n as num).toDouble()).toList())
        .toList(),
    senderId: json['senderId'],
    senderName: json['senderName'],
    photoPath: json['photoPath'],
  );
}

class Countdown {
  const Countdown(this.title, this.date, {this.id});
  final String title;
  final String? id;
  final DateTime date;
  int daysFrom(DateTime now) => DateTime(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime(now.year, now.month, now.day)).inDays;
  Map<String, dynamic> toJson() => {
    'title': title,
    'date': date.toIso8601String(),
    'id': id,
  };
  factory Countdown.fromJson(Map<String, dynamic> json) =>
      Countdown(json['title'], DateTime.parse(json['date']), id: json['id']);
}
