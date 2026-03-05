class MediaMetadata {
  final String id;
  final String title;
  final String? author;
  final String? thumbnailUrl;
  final String sourceUrl;
  final int durationSeconds;
  final String platform;
  final List<MediaFormat> availableFormats;

  final bool isPhoto;
  final List<String> galleryUrls;

  MediaMetadata({
    required this.id,
    required this.title,
    this.author,
    this.thumbnailUrl,
    required this.sourceUrl,
    this.durationSeconds = 0,
    this.platform = "Unknown",
    this.availableFormats = const [],
    this.isPhoto = false,
    this.galleryUrls = const [],
  });
}

class MediaFormat {
  final String formatId;
  final String extension;
  final String? resolution;
  final String? note;
  final int sizeBytes;
  final bool isVideo;
  final String? thumbnailUrl;

  MediaFormat({
    required this.formatId,
    required this.extension,
    this.resolution,
    this.note,
    this.sizeBytes = 0,
    this.isVideo = true,
    this.thumbnailUrl,
  });
}
