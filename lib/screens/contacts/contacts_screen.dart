import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<Contact> _contacts = [];
  bool _loading = true;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  Future<void> _fetchContacts() async {
    final granted = await FlutterContacts.requestPermission();
    if (!granted) {
      setState(() {
        _hasPermission = false;
        _loading = false;
      });
      return;
    }

    _hasPermission = true;
    final contacts = await FlutterContacts.getContacts(
        withProperties: true, withPhoto: true);
    setState(() {
      _contacts = contacts;
      _loading = false;
    });
  }

  Widget _buildAvatar(Contact contact) {
    if (contact.photo == null || contact.photo!.isEmpty) {
      return CircleAvatar(
        backgroundColor: Colors.white24,
        child: const Icon(Icons.person, color: Colors.white),
      );
    }
    return CircleAvatar(
      backgroundImage: MemoryImage(Uint8List.fromList(contact.photo!)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Contacts')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_hasPermission) {
      return Scaffold(
        appBar: AppBar(title: const Text('Contacts')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.block, size: 56, color: Colors.grey),
                SizedBox(height: 12),
                Text('Contacts permission denied',
                    style: TextStyle(fontSize: 16)),
                SizedBox(height: 8),
                Text('Open app settings to allow contact access.'),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Contacts')),
      body: ListView.separated(
        itemCount: _contacts.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 0.5, color: Colors.white12),
        itemBuilder: (context, index) {
          final c = _contacts[index];
          final phone = c.phones.isNotEmpty ? c.phones.first.number : '';
          return ListTile(
            leading: _buildAvatar(c),
            title: Text(c.displayName,
                style: const TextStyle(color: Colors.white)),
            subtitle:
                Text(phone, style: const TextStyle(color: Colors.white70)),
            onTap: () {
              // TODO: Start chat with the selected contact
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Selected ${c.displayName}')));
            },
          );
        },
      ),
    );
  }
}
