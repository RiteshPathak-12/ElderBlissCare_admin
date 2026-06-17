import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../services/auth_service.dart';
import '../../providers/settings_provider.dart';
import '../auth/login_screen.dart';
import 'alert_history_screen.dart';
import 'manage_admins_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = "v1.0.0";
  
  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = "v${packageInfo.version}";
      });
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    await Provider.of<AuthService>(context, listen: false).signOut();
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false, // Prevents back navigation
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    
    final String adminEmail = user?.email ?? "support@elderbliss.com";
    // We would ideally fetch the name from Firestore `users/{uid}`, 
    // but we can fallback to email prefix if not immediately available.
    final String adminName = user != null ? adminEmail.split('@')[0] : "Admin User";

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 10),

        // 🔷 Profile Card
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.blue,
                  child: Icon(
                    Icons.admin_panel_settings,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        adminName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        adminEmail,
                        style: const TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "Admin Role",
                          style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // 🔔 Notifications
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SwitchListTile(
            value: settingsProvider.notificationsEnabled,
            onChanged: (value) {
              settingsProvider.toggleNotifications(value);
            },
            secondary: const Icon(
              Icons.notifications_active,
              color: Colors.red,
            ),
            title: const Text("Emergency Notifications"),
            subtitle: const Text("Receive realtime panic alerts"),
          ),
        ),

        const SizedBox(height: 16),

        // 🌙 Dark Mode (Temporarily Disabled)
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SwitchListTile(
            value: false, // Force to false while disabled
            onChanged: (value) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Dark Mode is temporarily disabled for maintenance.')),
              );
              // settingsProvider.toggleDarkMode(value);
            },
            secondary: const Icon(
              Icons.dark_mode,
              color: Colors.indigo,
            ),
            title: const Text("Dark Mode"),
            subtitle: const Text("Temporarily unavailable"),
          ),
        ),

        const SizedBox(height: 16),

        // 📊 Alert History
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            leading: const Icon(Icons.history, color: Colors.orange),
            title: const Text("Alert History"),
            subtitle: const Text("View resolved alerts"),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AlertHistoryScreen()),
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        // 👨‍💼 Manage Admins
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            leading: const Icon(Icons.group, color: Colors.blue),
            title: const Text("Manage Admins"),
            subtitle: const Text("Add or remove admin access"),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageAdminsScreen()),
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        // 🚪 Logout
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            onTap: () => _handleLogout(context),
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout"),
            subtitle: const Text("Sign out from admin app"),
          ),
        ),

        const SizedBox(height: 30),

        // 🔹 Version
        Center(
          child: Text(
            "ElderBliss Admin $_appVersion",
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }
}

