import 'package:flutter/material.dart';
import '../../services/alert_service.dart';
import '../../models/alert_model.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AlertService _alertService = AlertService();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overview',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: StreamBuilder<int>(
                  stream: _alertService.getActiveAlertsCount(),
                  builder: (context, snapshot) {
                    final value = snapshot.data?.toString() ?? '-';
                    return _buildSummaryCard(
                      title: 'Active Alerts',
                      value: value,
                      icon: Icons.warning_amber_rounded,
                      color: Colors.red.shade400,
                    );
                  }
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StreamBuilder<int>(
                  stream: _alertService.getTotalUsersCount(),
                  builder: (context, snapshot) {
                    final value = snapshot.data?.toString() ?? '-';
                    return _buildSummaryCard(
                      title: 'Total Users',
                      value: value,
                      icon: Icons.people,
                      color: Colors.blue.shade400,
                    );
                  }
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            'Recent Alerts',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<AlertModel>>(
              stream: _alertService.getRecentAlerts(limit: 3),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return const Center(child: Text("Error fetching recent alerts"));
                }
                
                final recentAlerts = snapshot.data ?? [];
                
                if (recentAlerts.isEmpty) {
                  return const Center(
                    child: Text(
                      "No alerts found in the system.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: recentAlerts.length,
                  itemBuilder: (context, index) {
                    final alert = recentAlerts[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: alert.status == 'active' 
                            ? Colors.red 
                            : Colors.grey.shade300,
                        ),
                        borderRadius: BorderRadius.circular(12)
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: alert.status == 'active' ? Colors.red.shade100 : Colors.grey.shade200,
                          child: Icon(
                            alert.status == 'active' ? Icons.priority_high : Icons.check, 
                            color: alert.status == 'active' ? Colors.red.shade900 : Colors.green.shade700
                          ),
                        ),
                        title: Text('Emergency Alert - ${alert.userName}'),
                        subtitle: Text(
                          'Status: ${alert.status.toUpperCase()}',
                          style: TextStyle(
                            color: alert.status == 'active' ? Colors.red : Colors.grey
                          ),
                        ),
                      ),
                    );
                  },
                );
              }
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSummaryCard({required String title, required String value, required IconData icon, required Color color}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 36),
            const SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.grey[800]),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
