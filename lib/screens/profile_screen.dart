import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inno_ft/screens/signin_signup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../components/theme_toggle_switch.dart';
import '../components/trip_provider.dart';
import '../screens/create_trip_screen.dart';
import '../screens/find_trip_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  File? _imageFile;
  String userName = "";
  String userEmail = "";
  String userPhone = "";
  String? profileImageUrl;
  double userRating = 0.0;
  List<String> activeTrips = [];
  List<String> tripHistory = [];
  String? token;

  final String baseUrl = "http://localhost:8069";

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final authToken = prefs.getString('Authorization');

    if (authToken == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => SignInSignUpScreen()),
      );
    } else {
      setState(() {
        token = authToken;
      });
      _loadUserData(authToken);
    }
  }

  void showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadUserData(String? authToken) async {
    if (authToken == null) {
      showErrorDialog(context, 'Error: No authentication token found.');
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/profile'),
        headers: {
          'Authorization': authToken,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['user'];
        setState(() {
          userName = data['Name'];
          userEmail = data['Email'];
          userPhone = data['Phone'];
          userRating = data['Raiting'] ?? 0.0;
          profileImageUrl = data['ProfilePic'] ?? "";
          activeTrips = ["None"];
          tripHistory = ["None"];
        });
      } else {
        showErrorDialog(
            context, 'Error loading profile: ${response.statusCode}');
      }
    } catch (e) {
      showErrorDialog(context, 'Error loading profile: $e');
    }
  }

  Future<void> _updateUserProfile(String name, String phone) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('Authorization');

    if (token == null) {
      showErrorDialog(context, 'User is not authenticated');
      return;
    }

    try {
      var request = http.MultipartRequest(
        'PATCH',
        Uri.parse('$baseUrl/user/profile'),
      );
      request.headers['Authorization'] = token;
      request.fields['name'] = name;
      request.fields['city'] = phone;

      if (_imageFile != null) {
        request.files.add(
            await http.MultipartFile.fromPath('profile_pic', _imageFile!.path));
      }

      var response = await request.send();
      if (response.statusCode != 200) {
        showErrorDialog(
            context, 'Error updating profile: ${response.statusCode}');
      }
    } catch (e) {
      showErrorDialog(context, 'Error updating profile: $e');
    }
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
      _updateUserProfile(userName, userPhone);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeTrips = ref.watch(activeTripsProvider);
    final tripHistory = ref.watch(tripHistoryProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('InnoFellowTravelers'),
          backgroundColor: Colors.blue.shade700,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(
                  text: 'Profile',
                  icon: Icon(
                    Icons.person,
                    color: Colors.white,
                  )),
              Tab(
                  text: 'Create Trip',
                  icon: Icon(
                    Icons.add_circle,
                    color: Colors.white,
                  )),
              Tab(
                  text: 'Find Trip',
                  icon: Icon(
                    Icons.search,
                    color: Colors.white,
                  )),
            ],
          ),
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: Container(
                color: Colors.blue.shade900.withOpacity(0.8),
              ),
            ),
            TabBarView(
              children: [
                _buildProfileContent(context),
                CreateTripScreen(),
                FindTripScreen(),
              ],
            ),
            ThemeToggleSwitch(),
          ],
        ),
      ),
    );
  }

  void showEditDialog(BuildContext context, String field, String currentValue) {
    TextEditingController controller =
        TextEditingController(text: currentValue);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text('Edit $field',
              style: TextStyle(color: Colors.blue.shade700)),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'Enter new $field',
              labelStyle: const TextStyle(color: Colors.white),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.blue.shade700),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: () {
                if (field == 'name' && controller.text.isEmpty) {
                  showErrorDialog(context, 'Name cannot be empty.');
                  return;
                }
                if (field == 'email' && !isEmailValid(controller.text)) {
                  showErrorDialog(context, 'Invalid email format.');
                  return;
                }
                if (field == 'phone' && !isPhoneValid(controller.text)) {
                  showErrorDialog(context,
                      'Phone number must start with +7 or 8 and contain 11 digits.');
                  return;
                }

                if (field == 'name') {
                  setState(() {
                    userName = controller.text;
                  });
                }
                if (field == 'email') {
                  setState(() {
                    userEmail = controller.text;
                  });
                }
                if (field == 'phone') {
                  setState(() {
                    userPhone = controller.text;
                  });
                }
                _updateUserProfile(userName, userPhone);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: _imageFile != null
                      ? FileImage(_imageFile!)
                      : (profileImageUrl != "" && token != null
                              ? NetworkImage(
                                  "$baseUrl/user/profile/picture",
                                  headers: {
                                    'Authorization': token!,
                                  },
                                )
                              : const AssetImage(
                                  'assets/base_profile_picture.jpeg'))
                          as ImageProvider,
                ),
                TextButton(
                  onPressed: _pickImage,
                  child: const Text(
                    'Change Photo',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildUserInfo('Name', userName, () {
            showEditDialog(context, 'name', userName);
          }),
          _buildUserInfo('Email', userEmail, () {
            showEditDialog(context, 'email', userEmail);
          }),
          _buildUserInfo('Phone', userPhone, () {
            showEditDialog(context, 'phone', userPhone);
          }),
          const SizedBox(height: 20),
          Text(
            'Rating: $userRating',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Active Trips:',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          if (activeTrips.isEmpty)
            const Text('No active trips available.')
          else
            const Text('Some active trips available.'),
          const SizedBox(height: 20),
          const Text(
            'Trip History:',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          if (tripHistory.isEmpty)
            const Text('No trip history available.')
          else
            ListView.builder(
              shrinkWrap: true,
              itemCount: tripHistory.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(tripHistory[index]),
                );
              },
            ),
          ElevatedButton(
            onPressed: _showClearHistoryDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade900,
            ),
            child: const Text('Clear History'),
          ),
        ],
      ),
    );
  }

  Widget _buildTripItem(Map<String, String> trip) {
    return ListTile(
      title: Text('From ${trip['from']} to ${trip['to']}'),
      subtitle: Text('Departure: ${trip['departure']}'),
      trailing: trip['driver'] == 'your'
          ? Text('(your)', style: TextStyle(color: Colors.white))
          : null,
      onTap: () => _showTripDetailsDialog(trip),
    );
  }

  void _showTripDetailsDialog(Map<String, String> trip) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Trip Details'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('From: ${trip['from']}'),
              Text('To: ${trip['to']}'),
              Text('Departure: ${trip['departure']}'),
              Text('Arrival: ${trip['arrival']}'),
              Text('Seats: ${trip['availableSeats']}/${trip['totalSeats']}'),
              Text('Driver: ${trip['driver']}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () {
                ref.read(activeTripsProvider.notifier).removeTrip(trip);
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            if (trip['driver'] == 'your') ...[
              TextButton(
                onPressed: () {
                  ref.read(activeTripsProvider.notifier).removeTrip(trip);
                  ref
                      .read(tripHistoryProvider.notifier)
                      .addTripToHistory('${trip['from']} to ${trip['to']}');
                  Navigator.pop(context);
                },
                child: Text('Finish'),
              ),
            ],
          ],
        );
      },
    );
  }

  bool isEmailValid(String email) {
    final RegExp emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    return emailRegex.hasMatch(email);
  }

  bool isPhoneValid(String phone) {
    final RegExp phoneRegex = RegExp(r'^(\+7|8)\d{10}$');
    return phoneRegex.hasMatch(phone);
  }

  Widget _buildUserInfo(String label, String value, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label: $value',
            style: const TextStyle(fontSize: 16, color: Colors.white),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }

  void _showClearHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Clear Trip History'),
          content:
              const Text('Are you sure you want to clear your trip history?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: () {
                ref.read(tripHistoryProvider.notifier).clearHistory();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade900,
              ),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );
  }

  void _showCurrentPasswordDialog(BuildContext context) {
    TextEditingController currentPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Enter Current Password'),
          content: TextField(
            controller: currentPasswordController,
            decoration: InputDecoration(labelText: 'Current Password'),
            obscureText: true,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (_checkCurrentPassword(currentPasswordController.text)) {
                  Navigator.pop(context);
                  _showNewPasswordDialog(context);
                } else {
                  _showErrorDialog(context, 'Incorrect current password.');
                }
              },
              child: Text('Enter'),
            ),
          ],
        );
      },
    );
  }

  bool _checkCurrentPassword(String currentPassword) {
    return currentPassword == "123456";
  }

  void _showNewPasswordDialog(BuildContext context) {
    TextEditingController newPasswordController = TextEditingController();
    TextEditingController confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Enter New Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: newPasswordController,
                decoration: InputDecoration(labelText: 'New Password'),
                obscureText: true,
              ),
              TextField(
                controller: confirmPasswordController,
                decoration: InputDecoration(labelText: 'Confirm Password'),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (_validateNewPassword(context, newPasswordController.text,
                    confirmPasswordController.text)) {
                  Navigator.pop(context);
                }
              },
              child: Text('Change'),
            ),
          ],
        );
      },
    );
  }

  bool _validateNewPassword(
      BuildContext context, String newPassword, String confirmPassword) {
    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      _showErrorDialog(context, 'New password fields cannot be empty.');
      return false;
    }

    if (newPassword != confirmPassword) {
      _showErrorDialog(context, 'Passwords do not match.');
      return false;
    }

    if (!_isPasswordValid(newPassword)) {
      _showErrorDialog(context,
          'Password must be at least 8 characters long and include a digit and a special character.');
      return false;
    }

    return true;
  }

  bool _isPasswordValid(String password) {
    if (password.length < 8) return false;
    bool hasDigit = password.contains(RegExp(r'\d'));
    bool hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    return hasDigit && hasSpecialChar;
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}
