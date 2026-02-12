class NotificationPayload {
  final String packageName;
  final String title;
  final String text;
  final int timestamp;

  const NotificationPayload({
    required this.packageName,
    required this.title,
    required this.text,
    required this.timestamp,
  });

  factory NotificationPayload.fromMap(Map<dynamic, dynamic> map) {
    return NotificationPayload(
      packageName: map['packageName']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      timestamp: map['timestamp'] is int
          ? map['timestamp'] as int
          : int.tryParse(map['timestamp']?.toString() ?? '') ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'packageName': packageName,
      'title': title,
      'text': text,
      'timestamp': timestamp,
    };
  }
}
