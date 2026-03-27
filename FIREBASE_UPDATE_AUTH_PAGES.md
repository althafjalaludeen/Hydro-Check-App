# How to Update Authentication Pages for Firebase

## Overview

Your `authentication_pages.dart` currently uses mock authentication. Here's how to update it to use Firebase.

---

## Step 1: Update Imports

### Replace This:
```dart
import 'services/authentication_service.dart';
```

### With This:
```dart
import 'services/firebase_authentication_service.dart';
```

---

## Step 2: Update Login Page

### Current Code (Mock)
```dart
class EnhancedLoginPage extends StatefulWidget {
  const EnhancedLoginPage({super.key});

  @override
  State<EnhancedLoginPage> createState() => _EnhancedLoginPageState();
}

class _EnhancedLoginPageState extends State<EnhancedLoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  void _handleLogin() async {
    final authService = AuthenticationService();  // ← OLD
    
    final response = await authService.login(
      _emailController.text,
      _passwordController.text,
    );

    if (response.success) {
      // Navigate to dashboard
      Navigator.of(context).pushReplacementNamed('/user-dashboard');
    } else {
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'Email'),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                child: _isLoading 
                    ? CircularProgressIndicator()
                    : Text('Login'),
              ),
              SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pushNamed('/register'),
                child: Text('Don\'t have an account? Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
```

### Updated Code (Firebase)
```dart
import 'services/firebase_authentication_service.dart';

class EnhancedLoginPage extends StatefulWidget {
  const EnhancedLoginPage({super.key});

  @override
  State<EnhancedLoginPage> createState() => _EnhancedLoginPageState();
}

class _EnhancedLoginPageState extends State<EnhancedLoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  void _handleLogin() async {
    // Validation
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = FirebaseAuthenticationService();  // ← NEW
      
      final response = await authService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;

      if (response.success) {
        // Login successful - navigate to appropriate dashboard
        final user = response.user;
        
        if (user!.role == 'admin') {
          Navigator.of(context).pushReplacementNamed('/admin-dashboard');
        } else {
          Navigator.of(context).pushReplacementNamed('/user-dashboard');
        }

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Welcome ${user.fullName}! 👋')),
        );
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Water Quality Monitor'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo or Title
              const Icon(Icons.water_drop, size: 64, color: Colors.blue),
              const SizedBox(height: 24),
              const Text(
                'Login to Your Account',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              
              // Email Field
              TextField(
                controller: _emailController,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'user@example.com',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              
              // Password Field
              TextField(
                controller: _passwordController,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              
              // Login Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text('Login'),
                ),
              ),
              const SizedBox(height: 16),
              
              // Register Link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? "),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.of(context).pushNamed('/register'),
                    child: const Text('Register here'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
```

---

## Step 3: Update Registration Page

### Example of Updated Register Page:
```dart
import 'services/firebase_authentication_service.dart';

class EnhancedRegistrationPage extends StatefulWidget {
  const EnhancedRegistrationPage({super.key});

  @override
  State<EnhancedRegistrationPage> createState() =>
      _EnhancedRegistrationPageState();
}

class _EnhancedRegistrationPageState extends State<EnhancedRegistrationPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _mobileNumberController = TextEditingController();
  bool _isLoading = false;

  void _handleRegister() async {
    // Validation
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _fullNameController.text.isEmpty ||
        _mobileNumberController.text.isEmpty) {
      _showError('Please fill in all fields');
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showError('Passwords do not match');
      return;
    }

    if (_passwordController.text.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    if (_mobileNumberController.text.length < 10) {
      _showError('Please enter a valid mobile number');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = FirebaseAuthenticationService();  // ← NEW
      
      final response = await authService.register(
        RegistrationRequest(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: _fullNameController.text.trim(),
          mobileNumber: _mobileNumberController.text.trim(),
        ),
      );

      if (!mounted) return;

      if (response.success) {
        // Registration successful
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Account created! Please login.'),
            duration: Duration(seconds: 2),
          ),
        );

        // Navigate back to login page
        Navigator.of(context).pushReplacementNamed('/login');
      } else {
        _showError(response.message);
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_add, size: 64, color: Colors.blue),
              const SizedBox(height: 24),
              const Text(
                'Create New Account',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              
              // Full Name
              TextField(
                controller: _fullNameController,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  hintText: 'John Doe',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              
              // Email
              TextField(
                controller: _emailController,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'user@example.com',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              
              // Mobile Number
              TextField(
                controller: _mobileNumberController,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: 'Mobile Number',
                  hintText: '+1-555-0100',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              
              // Password
              TextField(
                controller: _passwordController,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              
              // Confirm Password
              TextField(
                controller: _confirmPasswordController,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              
              // Register Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text('Create Account'),
                ),
              ),
              const SizedBox(height: 16),
              
              // Login Link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account? '),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.of(context).pushNamed('/login'),
                    child: const Text('Login here'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _mobileNumberController.dispose();
    super.dispose();
  }
}
```

---

## Step 4: Test the Changes

After updating your authentication pages:

1. **Run the app:**
   ```bash
   flutter run
   ```

2. **Test Registration:**
   - Click "Register here"
   - Fill in all fields
   - Submit
   - Check Firebase Console → Authentication → Should see new user

3. **Test Login:**
   - Enter registered email & password
   - Should navigate to dashboard
   - Check console: "✅ User session restored"

4. **Test Session Persistence:**
   - Close app
   - Reopen app
   - Should go directly to dashboard (not login)

---

## Key Differences from Mock

| Feature | Mock | Firebase |
|---------|------|----------|
| User Storage | In-memory | Firebase Auth + Firestore |
| Password | Stored as SHA256 hash | Firebase Auth handles securely |
| Session | Lost on app restart | Persisted across sessions |
| User Data | Hardcoded | Fetched from Firestore |
| Speed | Instant (no network) | ~1 second (network call) |

---

## Testing Credentials

Once you've set up Firebase, use these test accounts:

```
Admin Account:
Email: admin@building.com
Password: 123456
Mobile: +1-555-0101

Regular User:
Email: user@building.com
Password: 123456
Mobile: +1-555-0102
```

Add these test users in Firebase Console → Authentication tab.

---

## Next: Update Other Pages

After updating authentication pages, update these:

- [ ] `user_dashboard.dart` - Load devices from Firebase
- [ ] `admin_dashboard.dart` - Load devices with real-time updates
- [ ] `add_device_page.dart` - Save devices to Firestore
- [ ] `reading_history_page.dart` - Load readings from Firebase
- [ ] `parameter_detail_page.dart` - Load device details from Firebase

Each will follow a similar pattern:
1. Import Firebase service
2. Create instance: `final service = FirebaseXyzService()`
3. Call appropriate method: `await service.getXyz()`
4. Display results in UI

---

## FAQ

**Q: Do I need to update all pages at once?**
A: No! Update them one at a time. The old services still work during transition.

**Q: Can I test without Firebase project?**
A: Not for Firebase services. You must create a project first.

**Q: Will users see errors during migration?**
A: Test thoroughly on test devices before releasing update.

**Q: How do I go back to mock data?**
A: Keep old service files. They're still there!

---

## Summary

✅ Update imports in authentication_pages.dart
✅ Replace AuthenticationService with FirebaseAuthenticationService
✅ Update error handling
✅ Test registration & login
✅ Verify users appear in Firebase Console
✅ Move on to updating other pages

**You're on your way to a production Firebase backend! 🚀**
