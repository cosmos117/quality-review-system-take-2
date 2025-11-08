import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/team_controller.dart';
import '../../models/team_member.dart';

class EmployeePage extends StatefulWidget {
  const EmployeePage({super.key});

  @override
  State<EmployeePage> createState() => _TeamPageState();
}

class _TeamPageState extends State<EmployeePage> {
  late final TeamController _ctrl;
  int? _sortColumnIndex;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(TeamController());

    if (_ctrl.members.isEmpty) {
      _ctrl.loadInitial([
        TeamMember(
          id: 't1',
          name: 'Emma Carter',
          email: 'emma.carter@example.com',
          role: 'Team Leader',
          status: 'Active',
          dateAdded: '2023-08-15',
          lastActive: '2024-05-20',
        ),
        TeamMember(
          id: 't2',
          name: 'Liam Walker',
          email: 'liam.walker@example.com',
          role: 'Member',
          status: 'Active',
          dateAdded: '2023-09-22',
          lastActive: '2024-05-21',
        ),
        TeamMember(
          id: 't3',
          name: 'Olivia Harris',
          email: 'olivia.harris@example.com',
          role: 'Reviewer',
          status: 'Inactive',
          dateAdded: '2023-10-10',
          lastActive: '2024-04-30',
        ),
        TeamMember(
          id: 't4',
          name: 'Noah Clark',
          email: 'noah.clark@example.com',
          role: 'Member',
          status: 'Active',
          dateAdded: '2023-11-05',
          lastActive: '2024-05-19',
        ),
        TeamMember(
          id: 't5',
          name: 'Ava Lewis',
          email: 'ava.lewis@example.com',
          role: 'Team Leader',
          status: 'Pending',
          dateAdded: '2023-12-18',
          lastActive: 'Never',
        ),
      ]);
    }
  }

  Widget _roleChip(String text) {
    return Chip(
      label: Text(text, style: const TextStyle(fontSize: 12)),
      backgroundColor: const Color(0xFFEFF3F7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  // Status no longer used in admin view; password added instead.

  Future<void> _showAddDialog() async {
    final formKey = GlobalKey<FormState>();
    String name = '';
    String email = '';
    String role = 'Executor/Reviewer';
    String password = '';
    bool obscure = true;
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      barrierLabel: 'Add Employee Dialog',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, _, _) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondary, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 520,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Add Team Member',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close),
                              tooltip: 'Close dialog',
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Full name *',
                          ),
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty)
                              return 'Enter name';
                            if (v.trim().length < 2) return 'Name too short';
                            return null;
                          },
                          onSaved: (v) => name = v!.trim(),
                          autofocus: true,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Email *',
                          ),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty)
                              return 'Enter email';
                            final value = v.trim();
                            final gmailPattern = RegExp(
                              r'^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$',
                            );
                            if (!gmailPattern.hasMatch(value))
                              return 'Invalid email format';
                            final exists = _ctrl.members.any(
                              (m) =>
                                  m.email.toLowerCase() == value.toLowerCase(),
                            );
                            if (exists) return 'Email already in use';
                            return null;
                          },
                          onSaved: (v) => email = v!.trim(),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: role,
                          items: ['Team Leader', 'Executor/Reviewer']
                              .map(
                                (r) =>
                                    DropdownMenuItem(value: r, child: Text(r)),
                              )
                              .toList(),
                          onChanged: (v) => role = v ?? role,
                          decoration: const InputDecoration(
                            labelText: 'Role *',
                          ),
                        ),
                        const SizedBox(height: 12),
                        StatefulBuilder(
                          builder: (context, setInner) {
                            return TextFormField(
                              decoration: InputDecoration(
                                labelText: 'Password *',
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    obscure
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  onPressed: () =>
                                      setInner(() => obscure = !obscure),
                                  tooltip: obscure
                                      ? 'Show password'
                                      : 'Hide password',
                                ),
                              ),
                              obscureText: obscure,
                              textInputAction: TextInputAction.done,
                              validator: (v) {
                                if (v == null || v.isEmpty)
                                  return 'Enter password';
                                if (v.length < 6) return 'Min 6 chars';
                                if (!RegExp(r'[A-Za-z]').hasMatch(v) ||
                                    !RegExp(r'\d').hasMatch(v)) {
                                  return 'Include letter & number';
                                }
                                return null;
                              },
                              onSaved: (v) => password = v!.trim(),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () {
                                if (formKey.currentState?.validate() ?? false) {
                                  formKey.currentState?.save();
                                  final newMember = TeamMember(
                                    id: DateTime.now().millisecondsSinceEpoch
                                        .toString(),
                                    name: name,
                                    email: email,
                                    role: role,
                                    status: 'Active',
                                    dateAdded: DateTime.now()
                                        .toIso8601String()
                                        .split('T')
                                        .first,
                                    lastActive: 'Never',
                                    password: password,
                                  );
                                  _ctrl.addMember(newMember);
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Member added'),
                                    ),
                                  );
                                }
                              },
                              child: const Text('Add Member'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showEditDialog(TeamMember m) async {
    final formKey = GlobalKey<FormState>();
    String name = m.name;
    String email = m.email;
    String role = (m.role == 'Team Leader')
        ? 'Team Leader'
        : 'Executor/Reviewer';
    String password = m.password ?? '';
    bool obscure = true;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      barrierLabel: 'Edit Employee Dialog',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, _, _) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondary, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 520,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Edit Member',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close),
                              tooltip: 'Close dialog',
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          initialValue: name,
                          decoration: const InputDecoration(
                            labelText: 'Full name *',
                          ),
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty)
                              return 'Enter name';
                            if (v.trim().length < 2) return 'Name too short';
                            return null;
                          },
                          onSaved: (v) => name = v!.trim(),
                          autofocus: true,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          initialValue: email,
                          decoration: const InputDecoration(
                            labelText: 'Email *',
                          ),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty)
                              return 'Enter email';
                            final value = v.trim();
                            final gmailPattern = RegExp(
                              r'^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$',
                            );
                            if (!gmailPattern.hasMatch(value))
                              return 'Invalid email format';
                            final exists = _ctrl.members.any(
                              (mm) =>
                                  mm.id != m.id &&
                                  mm.email.toLowerCase() == value.toLowerCase(),
                            );
                            if (exists) return 'Email already in use';
                            return null;
                          },
                          onSaved: (v) => email = v!.trim(),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: role,
                          items: ['Team Leader', 'Executor/Reviewer']
                              .map(
                                (r) =>
                                    DropdownMenuItem(value: r, child: Text(r)),
                              )
                              .toList(),
                          onChanged: (v) => role = v ?? role,
                          decoration: const InputDecoration(
                            labelText: 'Role *',
                          ),
                        ),
                        const SizedBox(height: 12),
                        StatefulBuilder(
                          builder: (context, setInner) {
                            return TextFormField(
                              initialValue: password,
                              decoration: InputDecoration(
                                labelText: 'Password *',
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    obscure
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  onPressed: () =>
                                      setInner(() => obscure = !obscure),
                                  tooltip: obscure
                                      ? 'Show password'
                                      : 'Hide password',
                                ),
                              ),
                              obscureText: obscure,
                              textInputAction: TextInputAction.done,
                              validator: (v) {
                                if (v == null || v.isEmpty)
                                  return 'Enter password';
                                if (v.length < 6) return 'Min 6 chars';
                                if (!RegExp(r'[A-Za-z]').hasMatch(v) ||
                                    !RegExp(r'\d').hasMatch(v)) {
                                  return 'Include letter & number';
                                }
                                return null;
                              },
                              onSaved: (v) => password = v!.trim(),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () {
                                if (formKey.currentState?.validate() ?? false) {
                                  formKey.currentState?.save();
                                  final updated = m.copyWith(
                                    name: name,
                                    email: email,
                                    role: role,
                                    password: password,
                                  );
                                  _ctrl.updateMember(m.id, updated);
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Member updated'),
                                    ),
                                  );
                                }
                              },
                              child: const Text('Save Changes'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(TeamMember m) async {
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      barrierLabel: 'Delete Member Dialog',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondary, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 420,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Delete Member',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          icon: const Icon(Icons.close),
                          tooltip: 'Close dialog',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Are you sure you want to delete "${m.name}"?'),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                          ),
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    if (confirmed == true) _ctrl.deleteMember(m.id);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'User Management',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      ElevatedButton.icon(
                        onPressed: _showAddDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add New User'),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Obx(() {
                          final list = _ctrl.filtered;
                          return DataTable(
                            columnSpacing: 24,
                            sortAscending: _sortAscending,
                            sortColumnIndex: _sortColumnIndex,
                            columns: [
                              DataColumn(
                                label: const Text('User'),
                                onSort: (colIndex, asc) {
                                  setState(() {
                                    _sortColumnIndex = colIndex;
                                    _sortAscending = asc;
                                    _ctrl.members.sort(
                                      (a, b) => asc
                                          ? a.name.compareTo(b.name)
                                          : b.name.compareTo(a.name),
                                    );
                                  });
                                },
                              ),
                              const DataColumn(label: Text('Email')),
                              const DataColumn(label: Text('Role')),
                              const DataColumn(label: Text('Password')),
                              DataColumn(
                                label: const Text('Date Added'),
                                onSort: (colIndex, asc) {
                                  setState(() {
                                    _sortColumnIndex = colIndex;
                                    _sortAscending = asc;
                                    _ctrl.members.sort(
                                      (a, b) => asc
                                          ? a.dateAdded.compareTo(b.dateAdded)
                                          : b.dateAdded.compareTo(a.dateAdded),
                                    );
                                  });
                                },
                              ),
                              const DataColumn(label: Text('Last Active')),
                              const DataColumn(label: Text('Actions')),
                            ],
                            rows: list.map((e) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          child: Text(e.name[0]),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(e.name),
                                      ],
                                    ),
                                  ),
                                  DataCell(Text(e.email)),
                                  DataCell(
                                    _roleChip(
                                      e.role == 'Team Leader'
                                          ? 'Team Leader'
                                          : 'Executor/Reviewer',
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      e.password != null &&
                                              e.password!.isNotEmpty
                                          ? '••••••'
                                          : 'Not Set',
                                    ),
                                  ),
                                  DataCell(Text(e.dateAdded)),
                                  DataCell(Text(e.lastActive)),
                                  DataCell(
                                    Row(
                                      children: [
                                        IconButton(
                                          onPressed: () => _showEditDialog(e),
                                          icon: const Icon(
                                            Icons.edit,
                                            size: 20,
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () => _confirmDelete(e),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 20,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          );
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filters',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Filter by Role',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Obx(
                          () => Column(
                            children: [
                              CheckboxListTile(
                                value: _ctrl.selectedRoles.contains(
                                  'Team Leader',
                                ),
                                onChanged: (v) => v == true
                                    ? _ctrl.selectedRoles.add('Team Leader')
                                    : _ctrl.selectedRoles.remove('Team Leader'),
                                title: const Text('Team Leader'),
                              ),
                              CheckboxListTile(
                                value: _ctrl.selectedRoles.contains(
                                  'Executor/Reviewer',
                                ),
                                onChanged: (v) => v == true
                                    ? _ctrl.selectedRoles.add(
                                        'Executor/Reviewer',
                                      )
                                    : _ctrl.selectedRoles.remove(
                                        'Executor/Reviewer',
                                      ),
                                title: const Text('Executor/Reviewer'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Status filters removed.
                        ElevatedButton(
                          onPressed: () => _ctrl.clearFilters(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF2F5F8),
                            foregroundColor: Colors.black,
                          ),
                          child: const Text('Clear Filters'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
