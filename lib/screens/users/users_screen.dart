import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .snapshots(),
      builder: (context, snapshot) {
        // Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        // Error
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        // No users
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 80,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  "No Users Found",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "No registered users available.",
                ),
              ],
            ),
          );
        }

        final users = snapshot.data!.docs;

        return Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: "Search users...",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // User List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final doc = users[index];

                  final userData =
                  doc.data() as Map<String, dynamic>;

                  String name =
                      userData['display_name'] ??
                          userData['name'] ??
                          'Unknown User';

                  String phone =
                      userData['phone_number'] ??
                          userData['phone'] ??
                          'No Phone';

                  String role =
                      userData['role'] ??
                          'user';

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),

                      leading: CircleAvatar(
                        radius: 28,
                        backgroundColor: role == 'admin'
                            ? Colors.red
                            : Colors.blue,
                        child: Icon(
                          role == 'admin'
                              ? Icons.admin_panel_settings
                              : Icons.person,
                          color: Colors.white,
                        ),
                      ),

                      title: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),

                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(phone),
                            const SizedBox(height: 4),
                            Text(
                              "Role: ${role.toUpperCase()}",
                              style: TextStyle(
                                color: role == 'admin'
                                    ? Colors.red
                                    : Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      trailing: PopupMenuButton(
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'view',
                            child: Text("View Profile"),
                          ),
                          const PopupMenuItem(
                            value: 'alerts',
                            child: Text("View Alerts"),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text("Remove User"),
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'delete') {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "User deletion is disabled by Firestore rules.",
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}