import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // needed for rootBundle

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dynamic Email List',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const EmailListScreen(),
    );
  }
}

// ── Data model with fromJson factory ──────────────────────────────────────────
class EmailItem {
  final String sender;
  final String subject;
  final String preview;
  final String time;
  final bool isRead;

  const EmailItem({
    required this.sender,
    required this.subject,
    required this.preview,
    required this.time,
    required this.isRead,
  });

  // Parse one JSON object into an EmailItem
  factory EmailItem.fromJson(Map<String, dynamic> json) {
    return EmailItem(
      sender: json['sender'] as String,
      subject: json['subject'] as String,
      preview: json['preview'] as String,
      time: json['time'] as String,
      isRead: json['isRead'] as bool,
    );
  }
}

// ── Email List Screen (StatefulWidget to handle async loading) ─────────────────
class EmailListScreen extends StatefulWidget {
  const EmailListScreen({super.key});

  @override
  State<EmailListScreen> createState() => _EmailListScreenState();
}

class _EmailListScreenState extends State<EmailListScreen> {
  late Future<List<EmailItem>> _emailsFuture;

  @override
  void initState() {
    super.initState();
    _emailsFuture = _loadEmails(); // start loading JSON on init
  }

  // Load and parse the JSON asset file
  Future<List<EmailItem>> _loadEmails() async {
    final jsonString = await rootBundle.loadString('assets/emails.json');
    final List<dynamic> jsonList = jsonDecode(jsonString);
    // Convert each map in the list to an EmailItem object
    return jsonList.map((json) => EmailItem.fromJson(json)).toList();
  }

  // Show a SnackBar when an email tile is tapped
  void _showSnackBar(BuildContext context, String sender) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opened email from $sender'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbox (Dynamic)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      // FutureBuilder handles the three states: loading, error, data ready
      body: FutureBuilder<List<EmailItem>>(
        future: _emailsFuture,
        builder: (context, snapshot) {
          // State 1: Still loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // State 2: Error occurred
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          // State 3: Data is ready
          final emails = snapshot.data!;
          return ListView.separated(
            itemCount: emails.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final email = emails[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade700,
                  child: Text(
                    email.sender[0],
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  email.sender,
                  style: TextStyle(
                    fontWeight: email.isRead ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      email.subject,
                      style: TextStyle(
                        fontWeight: email.isRead ? FontWeight.normal : FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      email.preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
                trailing: Text(
                  email.time,
                  style: TextStyle(
                    fontSize: 12,
                    color: email.isRead ? Colors.grey : Colors.blue,
                  ),
                ),
                isThreeLine: true,
                onTap: () => _showSnackBar(context, email.sender),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.edit),
      ),
    );
  }
}