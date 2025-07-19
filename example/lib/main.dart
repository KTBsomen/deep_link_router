import 'package:flutter/material.dart';
import 'package:deep_link_router/deep_link_router.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DeepLink Router Example',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isLoading = true;
  String? pendingLinkInfo;

  @override
  void initState() {
    super.initState();
    _initializeDeepLinkRouter();
  }

  Future<void> _initializeDeepLinkRouter() async {
    // Configure the deep link router with routes
    DeepLinkRouter.instance.configure(
      routes: [
        // Route 1: Handle /profile?userId=123
        DeepLinkRoute(
          matcher: (uri) =>
              uri.path == '/profile' &&
              uri.queryParameters.containsKey('userId'),
          handler: (context, uri) async {
            try {
              final userId = uri.queryParameters['userId']!;
              print("Navigating to ProfileScreen with userId: $userId");

              // Navigate to profile screen
              navigatorKey.currentState?.push(
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(userId: userId),
                ),
              );
              return true;
            } catch (e) {
              print("Error handling profile deep link: $e");
              return false;
            }
          },
        ),

        // Route 2: Handle /group?groupId=abc
        DeepLinkRoute(
          matcher: (uri) =>
              uri.path == '/group' &&
              uri.queryParameters.containsKey('groupId'),
          handler: (context, uri) async {
            try {
              final groupId = uri.queryParameters['groupId']!;
              print("Navigating to GroupScreen with groupId: $groupId");

              // Navigate to group screen
              navigatorKey.currentState?.push(
                MaterialPageRoute(
                  builder: (_) => GroupScreen(groupId: groupId),
                ),
              );
              return true;
            } catch (e) {
              print("Error handling group deep link: $e");
              return false;
            }
          },
        ),

        // Route 3: Handle /settings
        DeepLinkRoute(
          matcher: (uri) => uri.path == '/settings',
          handler: (context, uri) async {
            try {
              print("Navigating to SettingsScreen");

              // Navigate to settings screen
              navigatorKey.currentState?.push(
                MaterialPageRoute(builder: (_) => SettingsScreen()),
              );
              return true;
            } catch (e) {
              print("Error handling settings deep link: $e");
              return false;
            }
          },
        ),
      ],
      onUnhandled: (context, uri) async {
        print("Unhandled deep link: $uri");
        // Show a dialog or navigate to a fallback screen
        _showUnhandledLinkDialog(uri);
        return true;
      },
    );

    // Initialize the router
    try {
      await DeepLinkRouter.instance.initialize(context);

      // Check for pending deep links
      Uri? pendingLink = await DeepLinkRouter.getPendingDeepLink();
      if (pendingLink != null) {
        setState(() {
          pendingLinkInfo = "Pending link: $pendingLink";
        });

        // Complete pending navigation after a short delay
        Future.delayed(Duration(milliseconds: 500), () async {
          await DeepLinkRouter.completePendingNavigation(context);
        });
      }
    } catch (e) {
      print("Error initializing DeepLinkRouter: $e");
    }

    setState(() {
      isLoading = false;
    });
  }

  void _showUnhandledLinkDialog(Uri uri) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Unhandled Deep Link'),
        content: Text('Received unhandled deep link: $uri'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('DeepLink Router Example'),
        backgroundColor: Colors.blue,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Deep Link Router Status',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          SizedBox(height: 8),
                          Text('✅ Router initialized successfully'),
                          if (pendingLinkInfo != null) ...[
                            SizedBox(height: 8),
                            Text(
                              pendingLinkInfo!,
                              style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),

                  Text(
                    'Test Deep Links:',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  SizedBox(height: 16),

                  Text(
                    'To test deep links, use these URLs in your app:',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  SizedBox(height: 12),

                  _buildDeepLinkExample(
                    'Profile Page',
                    'yourapp://profile?userId=123',
                    'Opens profile for user 123',
                  ),

                  _buildDeepLinkExample(
                    'Group Page',
                    'yourapp://group?groupId=abc',
                    'Opens group with ID abc',
                  ),

                  _buildDeepLinkExample(
                    'Settings Page',
                    'yourapp://settings',
                    'Opens settings screen',
                  ),

                  _buildDeepLinkExample(
                    'Unhandled Link',
                    'yourapp://unknown',
                    'Shows unhandled dialog',
                  ),

                  SizedBox(height: 24),

                  Text(
                    'Manual Navigation:',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  SizedBox(height: 16),

                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfileScreen(userId: 'manual-123'),
                        ),
                      );
                    },
                    child: Text('Go to Profile (Manual)'),
                  ),

                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GroupScreen(groupId: 'manual-abc'),
                        ),
                      );
                    },
                    child: Text('Go to Group (Manual)'),
                  ),

                  ElevatedButton(
                    onPressed: () async {
                      Uri? pendingLink =
                          await DeepLinkRouter.getPendingDeepLink();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            pendingLink != null
                                ? 'Pending link: $pendingLink'
                                : 'No pending links',
                          ),
                        ),
                      );
                    },
                    child: Text('Check Pending Links'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDeepLinkExample(String title, String url, String description) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text(
              url,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Colors.blue,
              ),
            ),
            SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  final String userId;

  const ProfileScreen({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile Screen'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile Information',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: 12),
                    Text('User ID: $userId'),
                    SizedBox(height: 8),
                    Text('This page was opened via deep link routing.'),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),

            Text(
              'Deep Link Test Results:',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 12),

            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Deep link successfully handled!'),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text('Route: /profile?userId=$userId'),
                    Text('Handler: ProfileScreen'),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24),

            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GroupScreen(groupId: 'from-profile'),
                  ),
                );
              },
              child: Text('Go to Group Screen'),
            ),
          ],
        ),
      ),
    );
  }
}

class GroupScreen extends StatelessWidget {
  final String groupId;

  const GroupScreen({Key? key, required this.groupId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Group Screen'),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Group Information',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: 12),
                    Text('Group ID: $groupId'),
                    SizedBox(height: 8),
                    Text('This page was opened via deep link routing.'),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),

            Text(
              'Deep Link Test Results:',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 12),

            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Deep link successfully handled!'),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text('Route: /group?groupId=$groupId'),
                    Text('Handler: GroupScreen'),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24),

            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(userId: 'from-group'),
                  ),
                );
              },
              child: Text('Go to Profile Screen'),
            ),

            SizedBox(height: 12),

            ElevatedButton(
              onPressed: () async {
                // Simulate checking pending navigation
                await DeepLinkRouter.completePendingNavigation(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Checked for pending navigation')),
                );
              },
              child: Text('Complete Pending Navigation'),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings'), backgroundColor: Colors.purple),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: 12),
                    Text('This is the settings screen.'),
                    SizedBox(height: 8),
                    Text('Opened via deep link: /settings'),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),

            Card(
              color: Colors.purple.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.purple),
                        SizedBox(width: 8),
                        Text('Deep link successfully handled!'),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text('Route: /settings'),
                    Text('Handler: SettingsScreen'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
