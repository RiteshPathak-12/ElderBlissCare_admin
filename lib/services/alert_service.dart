import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/alert_model.dart';

class AlertService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String collectionPath = 'panic_alerts';

  // Get active alerts stream
  Stream<List<AlertModel>> getActiveAlerts() {
    return _db
        .collection(collectionPath)
        .where('status', whereIn: ['active', 'triggered'])
        // Removing orderBy to prevent "missing field" exclusions or missing index issues.
        // If a document doesn't strictly have a 'createdAt' field (e.g. it was named 'timestamp'), 
        // Firestore orderBy automatically excludes it.
        .snapshots()
        .map((snapshot) { 
          debugPrint("--- FIRESTORE REALTIME UPDATE ---");
          debugPrint("Active alerts snapshot docs count: ${snapshot.docs.length}");
          
          List<AlertModel> alerts = snapshot.docs
              .map((doc) => AlertModel.fromFirestore(doc))
              .toList();
          
          for (final doc in snapshot.docs) {
            debugPrint("------------------------------");
            debugPrint("DOC ID : ${doc.id}");
            debugPrint(doc.data().toString());
          }
          
          for (final alert in alerts) {
            debugPrint("============== MODEL ==============");
            debugPrint("Name : ${alert.userName}");
            debugPrint("Phone : ${alert.phone}");
            debugPrint("Status : ${alert.status}");
            debugPrint("Time : ${alert.createdAt}");
            debugPrint("Map : ${alert.mapsUrl}");
          }
          // Sort locally to ensure recent alerts are on top (decending order)
          alerts.sort((a, b) {
            final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });
          
          return alerts;
        })
        .handleError((error) {
          debugPrint("Firestore Stream Error in getActiveAlerts: $error");
          return <AlertModel>[];
        });
  }

  // Get recent alerts for dashboard
  Stream<List<AlertModel>> getRecentAlerts({int limit = 3}) {
    // Relying on the same logic and applying limit locally for dashboard
    return getActiveAlerts().map((alerts) => alerts.take(limit).toList());
  }

  // Count active alerts
  Stream<int> getActiveAlertsCount() {
    return _db
        .collection(collectionPath)
        .where('status', whereIn: ['active', 'triggered'])
        .snapshots()
        .map((snapshot) {
          debugPrint("Active alerts count updated: ${snapshot.size}");
          return snapshot.size;
        })
        .handleError((error) {
          debugPrint("Firestore Stream Error in getActiveAlertsCount: $error");
          return 0; // default to 0 on failure
        });
  }

  // Count total users
  Stream<int> getTotalUsersCount() {
    return _db
        .collection('users')
        .snapshots()
        .map((snapshot) => snapshot.size)
        .handleError((error) {
          debugPrint("Firestore Stream Error in getTotalUsersCount: $error");
          return 0;
        });
  }

  // Resolve alert
  Future<void> resolveAlert(BuildContext context, String alertId) async {
    try {
      await _db.collection(collectionPath).doc(alertId).update({
        'status': 'resolved',
        'resolvedAt': FieldValue.serverTimestamp(),
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Alert resolved successfully")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to resolve alert: $e")),
        );
      }
    }
  }

  // Call user  
  Future<void> callUser(BuildContext context, String phone) async {
    if (phone.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Phone number is empty")),
        );
      }
      return;
    }
    final Uri callUri = Uri.parse("tel:$phone");
    if (await canLaunchUrl(callUri)) {
      await launchUrl(callUri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not launch phone dialer")),
        );
      }
    }
  }

  // Open maps
  Future<void> openMaps(BuildContext context, String mapsUrl) async {
    if (mapsUrl.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location URL is empty")),
        );
      }
      return;
    }
    final Uri mapUri = Uri.parse(mapsUrl);
    if (await canLaunchUrl(mapUri)) {
      await launchUrl(mapUri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open maps")),
        );
      }
    }
  }
}
