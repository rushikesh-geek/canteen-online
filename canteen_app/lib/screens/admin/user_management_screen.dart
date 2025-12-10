/// User Role Management Screen
/// 
/// Admin-only screen to manage user roles:
/// - View all users
/// - Assign roles (admin, counter, student)
/// - View user details and wallet balance
library;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:canteen_app/theme/app_theme.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _roleFilter = 'All';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          // Add counter staff button
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Add Counter Staff',
            onPressed: _showAddCounterStaffDialog,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          
          return Column(
            children: [
              // Search and filter bar - responsive
              Container(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                color: Colors.white,
                child: isMobile
                    ? Column(
                        children: [
                          // Search field
                          TextField(
                            decoration: InputDecoration(
                              hintText: 'Search by name or email...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                              isDense: true,
                            ),
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value.toLowerCase();
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          // Role filter as chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: ['All', 'admin', 'counter', 'student'].map((role) {
                                final isSelected = _roleFilter == role;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    label: Text(role.toUpperCase()),
                                    selected: isSelected,
                                    avatar: Icon(
                                      _getRoleIcon(role),
                                      size: 16,
                                      color: isSelected ? Colors.white : _getRoleColor(role),
                                    ),
                                    onSelected: (selected) {
                                      setState(() => _roleFilter = role);
                                    },
                                    backgroundColor: Colors.grey[100],
                                    selectedColor: _getRoleColor(role),
                                    labelStyle: TextStyle(
                                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          // Search field
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Search by name or email...',
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value.toLowerCase();
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Role filter dropdown
                          DropdownButton<String>(
                            value: _roleFilter,
                            items: ['All', 'admin', 'counter', 'student'].map((role) {
                              return DropdownMenuItem(
                                value: role,
                                child: Row(
                                  children: [
                                    Icon(
                                      _getRoleIcon(role),
                                      size: 18,
                                      color: _getRoleColor(role),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(role.toUpperCase()),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _roleFilter = value);
                              }
                            },
                          ),
                        ],
                      ),
              ),
          
          // Users list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildUsersQuery(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                var users = snapshot.data!.docs;
                
                // Apply role filter client-side (avoids composite index)
                if (_roleFilter != 'All') {
                  users = users.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['role'] == _roleFilter;
                  }).toList();
                }
                
                // Apply search filter
                if (_searchQuery.isNotEmpty) {
                  users = users.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['name'] as String? ?? '').toLowerCase();
                    final email = (data['email'] as String? ?? '').toLowerCase();
                    return name.contains(_searchQuery) || email.contains(_searchQuery);
                  }).toList();
                }
                
                // Sort by name client-side
                users.sort((a, b) {
                  final nameA = ((a.data() as Map<String, dynamic>)['name'] as String? ?? '').toLowerCase();
                  final nameB = ((b.data() as Map<String, dynamic>)['name'] as String? ?? '').toLowerCase();
                  return nameA.compareTo(nameB);
                });
                
                if (users.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No users found'),
                      ],
                    ),
                  );
                }
                
                // Count by role
                final roleCounts = <String, int>{};
                for (var doc in users) {
                  final data = doc.data() as Map<String, dynamic>;
                  final role = data['role'] as String? ?? 'student';
                  roleCounts[role] = (roleCounts[role] ?? 0) + 1;
                }
                
                return Column(
                  children: [
                    // Summary bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: AppTheme.lightIndigo,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Text('Total: ${users.length}'),
                          Text('Admins: ${roleCounts['admin'] ?? 0}'),
                          Text('Counter: ${roleCounts['counter'] ?? 0}'),
                          Text('Students: ${roleCounts['student'] ?? 0}'),
                        ],
                      ),
                    ),
                    
                    // Users list
                    Expanded(
                      child: ListView.builder(
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final doc = users[index];
                          final data = doc.data() as Map<String, dynamic>;
                          return _buildUserTile(doc.id, data);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
            ],
          );
        },
      ),
    );
  }

  Stream<QuerySnapshot> _buildUsersQuery() {
    // Simple query without composite index - filter role client-side
    return _firestore.collection('users').snapshots();
  }

  Widget _buildUserTile(String docId, Map<String, dynamic> data) {
    final name = data['name'] as String? ?? 'Unknown';
    final email = data['email'] as String? ?? '';
    final role = data['role'] as String? ?? 'student';
    final walletBalance = (data['walletBalance'] as num?)?.toDouble() ?? 0;
    final photoUrl = data['photoUrl'] as String?;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(role).withValues(alpha: 0.2),
          backgroundImage: photoUrl != null && photoUrl.isNotEmpty
              ? NetworkImage(photoUrl)
              : null,
          child: photoUrl == null || photoUrl.isEmpty
              ? Text(
                  name[0].toUpperCase(),
                  style: TextStyle(
                    color: _getRoleColor(role),
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getRoleColor(role).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_getRoleIcon(role), size: 14, color: _getRoleColor(role)),
                  const SizedBox(width: 4),
                  Text(
                    role.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _getRoleColor(role),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(email, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            if (role == 'student')
              Text(
                'Wallet: ₹${walletBalance.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 12,
                  color: walletBalance > 0 ? AppTheme.successGreen : Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'change_role') {
              _showChangeRoleDialog(docId, name, role);
            } else if (value == 'view_details') {
              _showUserDetailsDialog(docId, data);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'view_details',
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18),
                  SizedBox(width: 8),
                  Text('View Details'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'change_role',
              child: Row(
                children: [
                  Icon(Icons.badge_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('Change Role'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangeRoleDialog(String docId, String userName, String currentRole) {
    String selectedRole = currentRole;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Change Role for $userName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select new role:',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              ...['admin', 'counter', 'student'].map((role) {
                final isSelected = selectedRole == role;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () {
                      setDialogState(() {
                        selectedRole = role;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _getRoleColor(role).withValues(alpha: 0.1)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? _getRoleColor(role) : Colors.grey[300]!,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getRoleIcon(role),
                            color: _getRoleColor(role),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  role.toUpperCase(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _getRoleColor(role),
                                  ),
                                ),
                                Text(
                                  _getRoleDescription(role),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check_circle, color: _getRoleColor(role)),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedRole == currentRole
                  ? null
                  : () async {
                      await _firestore.collection('users').doc(docId).update({
                        'role': selectedRole,
                        'roleUpdatedAt': FieldValue.serverTimestamp(),
                      });
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$userName is now a ${selectedRole.toUpperCase()}'),
                            backgroundColor: AppTheme.successGreen,
                          ),
                        );
                      }
                    },
              child: const Text('Update Role'),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserDetailsDialog(String docId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.person),
            const SizedBox(width: 8),
            Expanded(child: Text(data['name'] as String? ?? 'User Details')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Email', data['email'] as String? ?? '-'),
            _buildDetailRow('Role', (data['role'] as String? ?? 'student').toUpperCase()),
            _buildDetailRow('Wallet Balance', '₹${(data['walletBalance'] as num?)?.toStringAsFixed(2) ?? '0.00'}'),
            _buildDetailRow('Provider', data['provider'] as String? ?? '-'),
            if (data['createdAt'] != null)
              _buildDetailRow('Joined', _formatTimestamp(data['createdAt'] as Timestamp)),
            if (data['lastLogin'] != null)
              _buildDetailRow('Last Login', _formatTimestamp(data['lastLogin'] as Timestamp)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCounterStaffDialog() {
    final emailController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Counter Staff Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Counter staff can login with this email and manage orders at the counter terminal.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: 'counter1@canteen.com',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.lightAmber,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.warningAmber),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.warningAmber, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'The user must sign up first with this email, then you can assign the counter role.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty) return;
              
              // Find user by email
              final query = await _firestore
                  .collection('users')
                  .where('email', isEqualTo: email)
                  .get();
              
              if (query.docs.isEmpty) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('User not found. They must sign up first.'),
                      backgroundColor: AppTheme.errorRed,
                    ),
                  );
                }
                return;
              }
              
              // Update role to counter
              await query.docs.first.reference.update({
                'role': 'counter',
                'roleUpdatedAt': FieldValue.serverTimestamp(),
              });
              
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Counter staff role assigned successfully!'),
                    backgroundColor: AppTheme.successGreen,
                  ),
                );
              }
            },
            child: const Text('Assign Role'),
          ),
        ],
      ),
    );
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'counter':
        return Icons.point_of_sale;
      default:
        return Icons.school;
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return AppTheme.errorRed;
      case 'counter':
        return AppTheme.accentOrange;
      default:
        return AppTheme.primaryIndigo;
    }
  }

  String _getRoleDescription(String role) {
    switch (role) {
      case 'admin':
        return 'Full access: menu, slots, orders, users';
      case 'counter':
        return 'POS terminal: create orders, payments';
      default:
        return 'App user: browse menu, place orders';
    }
  }

  String _formatTimestamp(Timestamp ts) {
    final dt = ts.toDate();
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
