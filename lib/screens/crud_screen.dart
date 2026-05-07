import 'dart:convert';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/db_helper.dart';

class CrudScreen extends StatefulWidget {
  const CrudScreen({super.key});

  @override
  State<CrudScreen> createState() => _CrudScreenState();
}

class _CrudScreenState extends State<CrudScreen> {
  // DB helper singleton
  final _db = DatabaseHelper.instance;

  // Holds current list of emails shown in the UI
  List<Map<String, dynamic>> _emails = [];

  // Form controllers for the Add/Edit dialog
  final _senderCtrl  = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _previewCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEmails(); // populate list on screen open
  }

  @override
  void dispose() {
    // Always dispose controllers to free memory
    _senderCtrl.dispose();
    _subjectCtrl.dispose();
    _previewCtrl.dispose();
    super.dispose();
  }

  // ── READ: fetch all rows from SQLite ────────────────────────────────────────
  Future<void> _loadEmails() async {
    final data = await _db.getAllEmails();
    setState(() => _emails = data);
  }

  // ── CREATE / UPDATE dialog ───────────────────────────────────────────────────
  void _showForm({Map<String, dynamic>? existing}) {
    // Pre-fill fields if editing an existing record
    _senderCtrl.text  = existing?['sender']  ?? '';
    _subjectCtrl.text = existing?['subject'] ?? '';
    _previewCtrl.text = existing?['preview'] ?? '';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? 'Add Email' : 'Edit Email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _senderCtrl,  decoration: const InputDecoration(labelText: 'Sender')),
            TextField(controller: _subjectCtrl, decoration: const InputDecoration(labelText: 'Subject')),
            TextField(controller: _previewCtrl, decoration: const InputDecoration(labelText: 'Preview')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final record = {
                'sender':  _senderCtrl.text.trim(),
                'subject': _subjectCtrl.text.trim(),
                'preview': _previewCtrl.text.trim(),
                'time':    DateTime.now().toString().substring(0, 16),
                'isRead':  0,
              };

              if (existing == null) {
                // CREATE — insert new row
                await _db.insertEmail(record);
                _showSnack('Email added ✓');
              } else {
                // UPDATE — update existing row by id
                await _db.updateEmail(existing['id'] as int, record);
                _showSnack('Email updated ✓');
              }

              Navigator.pop(context);
              _loadEmails(); // refresh list
            },
            child: Text(existing == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
  }

  // ── DELETE with confirmation ─────────────────────────────────────────────────
  void _confirmDelete(int id, String sender) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Email'),
        content: Text('Delete email from "$sender"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await _db.deleteEmail(id);
              Navigator.pop(context);
              _loadEmails();
              _showSnack('Deleted ✓');
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── IMPORT from bundled JSON asset ──────────────────────────────────────────
  Future<void> _importFromJson() async {
    // Load the JSON file from Flutter assets folder
    final jsonString = await rootBundle.loadString('assets/emails.json');
    final List<dynamic> jsonList = jsonDecode(jsonString);

    // Map each JSON object to the DB column format
    final records = jsonList.map((e) => {
      'sender':  e['sender']  ?? '',
      'subject': e['subject'] ?? '',
      'preview': e['preview'] ?? '',
      'time':    e['time']    ?? '',
      'isRead':  (e['isRead'] == true) ? 1 : 0,
    }).toList();

    await _db.insertAll(records); // bulk insert
    _loadEmails();
    _showSnack('Imported ${records.length} emails from JSON ✓');
  }

  // ── IMPORT from user-selected Excel (.xlsx) file ────────────────────────────
  Future<void> _importFromExcel() async {
    // Open device file picker, filter to Excel only
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (result == null || result.files.single.bytes == null) return;

    // Parse Excel bytes using the excel package
    final excel = Excel.decodeBytes(result.files.single.bytes!);
    final sheet = excel.tables[excel.tables.keys.first]; // first sheet
    if (sheet == null) return;

    final records = <Map<String, dynamic>>[];

    // Skip header row (index 0), iterate data rows
    for (int i = 1; i < sheet.maxRows; i++) {
      final row = sheet.row(i);
      if (row.isEmpty) continue;

      // Expected Excel columns: A=sender, B=subject, C=preview, D=time
      records.add({
        'sender':  row[0]?.value?.toString() ?? '',
        'subject': row[1]?.value?.toString() ?? '',
        'preview': row[2]?.value?.toString() ?? '',
        'time':    row[3]?.value?.toString() ?? '',
        'isRead':  0,
      });
    }

    await _db.insertAll(records);
    _loadEmails();
    _showSnack('Imported ${records.length} emails from Excel ✓');
  }

  // ── Clear all records ────────────────────────────────────────────────────────
  Future<void> _clearAll() async {
    await _db.clearAll();
    _loadEmails();
    _showSnack('All records cleared');
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  // ── BUILD ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SQLite CRUD'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Import JSON button
          IconButton(
            icon: const Icon(Icons.data_object),
            tooltip: 'Import JSON',
            onPressed: _importFromJson,
          ),
          // Import Excel button
          IconButton(
            icon: const Icon(Icons.table_chart),
            tooltip: 'Import Excel',
            onPressed: _importFromExcel,
          ),
          // Clear all button
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear All',
            onPressed: _clearAll,
          ),
        ],
      ),

      // Show empty state if no records, otherwise show list
      body: _emails.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('No emails. Add one or import.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.separated(
              itemCount: _emails.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final email = _emails[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade700,
                    child: Text(
                      email['sender'][0],
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(email['sender'],
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    email['subject'],
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // EDIT button
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showForm(existing: email),
                      ),
                      // DELETE button
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDelete(
                          email['id'] as int,
                          email['sender'] as String,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

      // FAB to add a new record
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(),
        tooltip: 'Add Email',
        child: const Icon(Icons.add),
      ),
    );
  }
}