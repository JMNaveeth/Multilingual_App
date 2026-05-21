import 'package:multilingual_chat_app/models/message.dart';

/// RichMessage wraps a [Message] with optional extra payload for image/file/location/contact.
class RichMessage {
  final Message message;

  /// For image messages: local file path.
  final String? imagePath;

  /// For file messages.
  final String? fileName;
  final String? filePath;
  final int? fileSizeBytes;
  final String? audioPath;

  /// For location messages.
  final double? latitude;
  final double? longitude;
  final String? locationLabel;

  /// For contact messages.
  final String? contactName;
  final String? contactPhone;

  const RichMessage({
    required this.message,
    this.imagePath,
    this.fileName,
    this.filePath,
    this.fileSizeBytes,
    this.audioPath,
    this.latitude,
    this.longitude,
    this.locationLabel,
    this.contactName,
    this.contactPhone,
  });
}
