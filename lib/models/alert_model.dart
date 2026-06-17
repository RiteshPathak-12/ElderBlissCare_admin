import 'package:cloud_firestore/cloud_firestore.dart';

class AlertModel {
  final String id;
  final String userId;
  final String userName;
  final String phone;
  final double? latitude;
  final double? longitude;
  final String mapsUrl;
  final String message;
  final String status;
  final DateTime? createdAt;
  final DateTime? resolvedAt;

  AlertModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.phone,
    this.latitude,
    this.longitude,
    required this.mapsUrl,
    required this.message,
    required this.status,
    this.createdAt,
    this.resolvedAt,
  });

  factory AlertModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // Safely handle both naming conventions that might be used by the user app
    final createdAtRaw = data['createdAt'] ?? data['timestamp'];
    final mapsUrlRaw = data['mapsUrl'] ?? data['locationUrl'] ?? '';

    return AlertModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Unknown User',
      phone: data['phone'] ?? 'No Phone',
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      mapsUrl: mapsUrlRaw,
      message: data['message'] ?? 'Emergency help needed',
      status: data['status'] ?? 'active',
      createdAt: createdAtRaw != null ? (createdAtRaw as Timestamp).toDate() : null,
      resolvedAt: data['resolvedAt'] != null ? (data['resolvedAt'] as Timestamp).toDate() : null,
    );
  }
}
