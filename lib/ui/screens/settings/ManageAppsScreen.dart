import 'package:flutter/material.dart';
import '../../theme/pushin_theme.dart';

/// Manage Apps Screen - Select which apps to block
///
/// Design:
/// - Search bar for filtering apps
/// - List of installed apps with checkboxes
/// - Visual indication of selected apps
/// - Popular apps section at top
///
/// Visual Reference: GO Club app selection (dark theme, toggles)
class ManageAppsScreen extends StatefulWidget {
  const ManageAppsScreen({super.key});

  @override
  State<ManageAppsScreen> createState() => _ManageAppsScreenState();
}

class _ManageAppsScreenState extends State<ManageAppsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Mock app data (in production, fetch from platform channel)
  final List<AppItem> _apps = [
    AppItem(
        name: 'Instagram',
        packageName: 'com.instagram.android',
        icon: Icons.photo_camera,
        isBlocked: true,
        category: 'Social'),
    AppItem(
        name: 'TikTok',
        packageName: 'com.tiktok.android',
        icon: Icons.music_note,
        isBlocked: true,
        category: 'Social'),
    AppItem(
        name: 'Twitter',
        packageName: 'com.twitter.android',
        icon: Icons.tag,
        isBlocked: true,
        category: 'Social'),
    AppItem(
        name: 'Facebook',
        packageName: 'com.facebook.katana',
        icon: Icons.facebook,
        isBlocked: false,
        category: 'Social'),
    AppItem(
        name: 'YouTube',
        packageName: 'com.google.android.youtube',
        icon: Icons.play_circle,
        isBlocked: false,
        category: 'Entertainment'),
    AppItem(
        name: 'Netflix',
        packageName: 'com.netflix.mediaclient',
        icon: Icons.movie,
        isBlocked: false,
        category: 'Entertainment'),
    AppItem(
        name: 'Reddit',
        packageName: 'com.reddit.frontpage',
        icon: Icons.forum,
        isBlocked: false,
        category: 'Social'),
    AppItem(
        name: 'Snapchat',
        packageName: 'com.snapchat.android',
        icon: Icons.chat,
        isBlocked: false,
        category: 'Social'),
    AppItem(
        name: 'WhatsApp',
        packageName: 'com.whatsapp',
        icon: Icons.message,
        isBlocked: false,
        category: 'Communication'),
    AppItem(
        name: 'Telegram',
        packageName: 'org.telegram.messenger',
        icon: Icons.send,
        isBlocked: false,
        category: 'Communication'),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AppItem> get _filteredApps {
    if (_searchQuery.isEmpty) {
      return _apps;
    }
    return _apps.where((app) {
      return app.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  List<AppItem> get _blockedApps {
    return _apps.where((app) => app.isBlocked).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E293B),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Manage Blocked Apps',
                        style: PushinTheme.appsText,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48), // Balance back button
                  ],
                ),
              ),

              // Summary Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: PushinTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: PushinTheme.primaryBlue.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.block,
                        color: Colors.white,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_blockedApps.length} apps blocked',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Requires workout to access',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search apps...',
                    hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.white.withOpacity(0.6),
                    ),
                    filled: true,
                    fillColor: PushinTheme.surfaceDark.withOpacity(0.6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                          20), // More rounded like workout cards
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Apps List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _filteredApps.length,
                  itemBuilder: (context, index) {
                    final app = _filteredApps[index];
                    return _AppTile(
                      app: app,
                      onToggle: (value) {
                        setState(() {
                          app.isBlocked = value;
                        });
                      },
                    );
                  },
                ),
              ),

              // Bottom Info
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: PushinTheme.surfaceDark.withOpacity(0.6),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: PushinTheme.primaryBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Blocked apps require a workout to access',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// App Tile Widget
class _AppTile extends StatelessWidget {
  final AppItem app;
  final ValueChanged<bool> onToggle;

  const _AppTile({
    required this.app,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: app.isBlocked
            ? PushinTheme.primaryBlue.withOpacity(0.1)
            : PushinTheme.surfaceDark.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: app.isBlocked
            ? Border.all(
                color: PushinTheme.primaryBlue.withOpacity(0.3),
                width: 1.5,
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onToggle(!app.isBlocked),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // App Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getCategoryColor().withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    app.icon,
                    color: _getCategoryColor(),
                    size: 24,
                  ),
                ),

                const SizedBox(width: 16),

                // App Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        app.category,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),

                // Toggle Switch
                Switch(
                  value: app.isBlocked,
                  onChanged: onToggle,
                  activeColor: PushinTheme.primaryBlue,
                  activeTrackColor: PushinTheme.primaryBlue.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor() {
    switch (app.category) {
      case 'Social':
        return PushinTheme.primaryBlue;
      case 'Entertainment':
        return PushinTheme.errorRed;
      case 'Communication':
        return PushinTheme.successGreen;
      default:
        return PushinTheme.textSecondary;
    }
  }
}

/// App Item Model
class AppItem {
  final String name;
  final String packageName;
  final IconData icon;
  final String category;
  bool isBlocked;

  AppItem({
    required this.name,
    required this.packageName,
    required this.icon,
    required this.category,
    required this.isBlocked,
  });
}
