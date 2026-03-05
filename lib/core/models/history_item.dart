enum MediaType { video, audio, image }

class HistoryItem {
  final String id;
  final String title;
  final String thumbnailUrl;
  final String sourceUrl;
  final String filePath;
  final DateTime timestamp;
  final MediaType type;
  final String platform;
  final int sizeBytes;
  final List<String> galleryPaths;

  HistoryItem({
    required this.id,
    required this.title,
    required this.thumbnailUrl,
    required this.sourceUrl,
    required this.filePath,
    required this.timestamp,
    required this.type,
    required this.platform,
    required this.sizeBytes,
    this.galleryPaths = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'thumbnailUrl': thumbnailUrl,
    'sourceUrl': sourceUrl,
    'filePath': filePath,
    'timestamp': timestamp.toIso8601String(),
    'type': type.index,
    'platform': platform,
    'sizeBytes': sizeBytes,
    'galleryPaths': galleryPaths,
  };

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
    id: json['id'],
    title: json['title'],
    thumbnailUrl: json['thumbnailUrl'],
    sourceUrl: json['sourceUrl'],
    filePath: json['filePath'],
    timestamp: DateTime.parse(json['timestamp']),
    type: MediaType.values[json['type']],
    platform: json['platform'],
    sizeBytes: json['sizeBytes'],
    galleryPaths: List<String>.from(json['galleryPaths'] ?? []),
  );
}
