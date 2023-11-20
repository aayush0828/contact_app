import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

void main() {
  runApp(ContactsApp());
}

class Contact {
  final String name;
  final String phoneNumber;
  final String email;
  final String? imagePath;
  
  Contact({
    required this.name,
    required this.phoneNumber,
    required this.email,
    this.imagePath,
  });
}

class ContactsApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Contacts App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: ContactListScreen(),
    );
  }
}

class ContactListScreen extends StatefulWidget {
  @override
  _ContactListScreenState createState() => _ContactListScreenState();
}

class _ContactListScreenState extends State<ContactListScreen> {
  late Database _database;
  List<Contact> _contacts = [];

  @override
  void initState() {
    super.initState();
    _initDatabase();
  }

  Future<void> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    _database = await openDatabase(
      join(dbPath, 'contacts.db'),
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE contacts(id INTEGER PRIMARY KEY, name TEXT, phoneNumber TEXT, email TEXT, imagePath TEXT)',
        );
      },
      version: 1,
    );
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final contactsData = await _database.query('contacts');
    final contacts = contactsData.map((e) => Contact(
          name: e['name'] as String,
          phoneNumber: e['phoneNumber'] as String,
          email: e['email'] as String,
          imagePath: e['imagePath'] as String?,
        )).toList();
    contacts.sort((a, b) => a.name.compareTo(b.name));
    setState(() {
      _contacts = contacts;
    });
  }

  Future<void> _deleteContact(int id) async {
    await _database.delete('contacts', where: 'id = ?', whereArgs: [id]);
    _loadContacts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Contacts')),
      body: ListView.builder(
        itemCount: _contacts.length,
        itemBuilder: (ctx, index) {
          return ContactTile(
            contact: _contacts[index],
            onDelete: () => _deleteContact(index),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddContact(context),
        child: Icon(Icons.add),
      ),
    );
  }

  void _navigateToAddContact(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (BuildContext context) => AddContactScreen(database: _database)),
    );
    _loadContacts();
  }
}


class AddContactScreen extends StatefulWidget {
  final Database database;
  AddContactScreen({required this.database});
  @override
  _AddContactScreenState createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneNumberController;
  late TextEditingController _emailController;
  String? _imagePath;
  String _selectedCountryCode = "+91"; // Default country code

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneNumberController = TextEditingController();
    _emailController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneNumberController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _getImage() async {
    final pickedImage = await ImagePicker().getImage(source: ImageSource.gallery);
    if (pickedImage != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = DateTime.now().toIso8601String();
      final savedImage = await File(pickedImage.path).copy('${appDir.path}/$fileName');
      setState(() {
        _imagePath = savedImage.path;
      });
    }
  }

  bool validateEmail(String email) {
    // Use regular expressions to validate the email format.
    // You can find regex patterns for email validation online.
    // For example, to check for the format "abc123@gmail.com":
    final emailRegExp = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegExp.hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add Contact')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ContactAvatar(imagePath: _imagePath),
            TextButton.icon(
              onPressed: _getImage,
              icon: Icon(Icons.camera),
              label: Text('Add Photo'),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Name'),
            ),
            Row(
              children: [
                DropdownButton<String>(
                  value: _selectedCountryCode,
                  onChanged: (newValue) {
                    setState(() {
                      _selectedCountryCode = newValue!;
                    });
                  },
                  items: [
                    DropdownMenuItem(value: "+91", child: Text('+91 (India)')),
                    // Add more country codes here...
                  ],
                ),
                SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _phoneNumberController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      hintText: 'Enter phone number',
                    ),
                  ),
                ),
              ],
            ),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                bool isValidPhoneNumber = validatePhoneNumber(_phoneNumberController.text);
                if (!isValidPhoneNumber) {
                  // ... (your error message dialog)
                  return;
                }

                // Validate the email before saving
                if (!validateEmail(_emailController.text)) {
                  // Show an error message dialog for invalid email format
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text('Invalid Email'),
                        content: Text('Please enter a valid email address.'),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: Text('OK'),
                          ),
                        ],
                      );
                    },
                  );
                  return;
                }

                final newContact = Contact(
                  name: _nameController.text,
                  phoneNumber: _selectedCountryCode + _phoneNumberController.text,
                  email: _emailController.text,
                  imagePath: _imagePath,
                );

                await widget.database.insert('contacts', newContact.toMap());

                Navigator.pop(context);
              },
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  bool validatePhoneNumber(String phoneNumber) {
    
    return true; // Placeholder for validation
  }
}
class ContactTile extends StatelessWidget {
  // Remaining code for the ContactTile
  final Contact contact;
  final VoidCallback onDelete;
  ContactTile({
    required this.contact,
    required this.onDelete,
  });
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: contact.imagePath != null
          ? CircleAvatar(backgroundImage: FileImage(File(contact.imagePath!)))
          : CircleAvatar(child: Text(contact.name[0])),
      title: Text(contact.name),
      subtitle: Text(contact.phoneNumber),
      trailing: IconButton(
        icon: Icon(Icons.delete),
        onPressed: onDelete,
      ),
    );
  }
}

class ContactAvatar extends StatelessWidget {
  // Remaining code for the ContactAvatar
  final String? imagePath;
  final String? name;
  ContactAvatar({this.imagePath, this.name});
  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 50,
      backgroundColor: Colors.blue,
      child: imagePath != null
          ? CircleAvatar(
              backgroundImage: FileImage(File(imagePath!)),
              radius: 48,
            )
          : Text(
              name != null ? name![0] : '',
              style: TextStyle(fontSize: 32, color: Colors.white),
            ),
    );
  }
}
extension ContactExtension on Contact {
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'email': email,
      'imagePath': imagePath,
    };
  }
}
class AppColors {
  static const primaryColor = Colors.blue;
  static const accentColor = Colors.blueAccent;
}
