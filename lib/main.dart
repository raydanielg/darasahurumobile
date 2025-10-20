import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'settings_screen.dart';
import 'home_tab.dart';
import 'notes_tab.dart'; // Now contains NewsTab
import 'my_notes_tab.dart'; // New NotesTab
import 'exams_tab.dart';
import 'post_detail_screen.dart';
import 'onboarding_screen.dart';
import 'feature_tour_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;
  bool _showOnboarding = true;
  bool _showTour = true;

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Darasa Huru',
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent, brightness: Brightness.dark),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
      ),
      home: MainScreen(
        onToggleTheme: _toggleTheme,
        isDarkMode: _isDarkMode,
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = <Widget>[
    HomeTab(),          // 0
    NewsTab(),          // 1
    NotesTab(),         // 2
    ExamsTab(),         // 3
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Row(
          children: [
            Image.asset(
              'assets/Darasa-Huru-Juu-New.png',
              height: 40,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SearchScreen(currentTabIndex: _selectedIndex),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onToggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(
                      title: Row(
                        children: [
                          Image.asset(
                            'assets/Darasa-Huru-Juu-New.png',
                            height: 40,
                          ),
                        ],
                      ),
                    ),
                    body: const SettingsScreen(),
                  ),
                ),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.article),
            label: 'News',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.note_alt),
            label: 'Notes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Exams',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.red,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
      ),
    );
  }
}

class SearchScreen extends StatefulWidget {
  final int currentTabIndex;

  const SearchScreen({super.key, required this.currentTabIndex});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  List<dynamic> _posts = [];
  List<dynamic> _filteredPosts = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    String url;
    switch (widget.currentTabIndex) {
      case 0: // Home
        url = 'https://darasahuru.ac.tz/wp-json/wp/v2/posts?per_page=100&_embed=1';
        break;
      case 1: // News
        url = 'https://darasahuru.ac.tz/wp-json/wp/v2/posts?categories=29&per_page=100&_embed=1';
        break;
      case 2: // Notes
        url = 'https://darasahuru.ac.tz/wp-json/wp/v2/posts?categories=535&per_page=100&_embed=1';
        break;
      case 3: // Exams
        url = 'https://darasahuru.ac.tz/wp-json/wp/v2/posts?categories=30&per_page=100&_embed=1';
        break;
      default:
        url = 'https://darasahuru.ac.tz/wp-json/wp/v2/posts?per_page=100&_embed=1';
    }

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        setState(() {
          _posts = json.decode(response.body);
          _filteredPosts = _posts;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Please turn on the internet and try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Please turn on the internet and try again.';
        _isLoading = false;
      });
    }
  }

  void _filterPosts(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _filteredPosts = _posts.where((post) {
        final title = _stripHtml(post['title']?['rendered'] ?? '').toLowerCase();
        final content = _stripHtml(post['content']?['rendered'] ?? '').toLowerCase();
        return title.contains(_searchQuery) || content.contains(_searchQuery);
      }).toList();
    });
  }

  String _stripHtml(String s) => s.replaceAll(RegExp(r'<[^>]*>'), '');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search posts',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _filterPosts,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _filteredPosts.isEmpty
                        ? const Center(child: Text('No matching posts found.'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16.0),
                            itemCount: _filteredPosts.length,
                            itemBuilder: (context, index) {
                              final post = _filteredPosts[index];
                              final title = _stripHtml(post['title']?['rendered'] ?? 'Post');
                              final content = post['content']?['rendered'] ?? '';
                              final imgUrl = _getFeaturedImage(post);
                              final time = _getPostTime(post);
                              final catId = (post['categories'] is List && (post['categories'] as List).isNotEmpty)
                                  ? (post['categories'][0] as int)
                                  : null;
                              return Card(
                                elevation: 0,
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ListTile(
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: imgUrl != null
                                        ? Image.network(
                                            imgUrl,
                                            width: 64,
                                            height: 64,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(
                                              width: 64,
                                              height: 64,
                                              color: Colors.grey.shade200,
                                              child: const Icon(Icons.image_not_supported, color: Colors.grey),
                                            ),
                                          )
                                        : Container(
                                            width: 64,
                                            height: 64,
                                            color: Colors.grey.shade200,
                                            child: const Icon(Icons.image, color: Colors.grey),
                                          ),
                                  ),
                                  title: Text(
                                    title.isEmpty ? 'Post' : title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  subtitle: time.isNotEmpty
                                      ? Text(time, style: const TextStyle(fontSize: 12, color: Colors.grey))
                                      : null,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PostDetailScreen(
                                          title: title,
                                          htmlContent: content,
                                          categoryId: catId,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  String _getPostTime(dynamic post) {
    try {
      final dateStr = post['date'];
      if (dateStr is String && dateStr.isNotEmpty) {
        final dt = DateTime.tryParse(dateStr);
        if (dt != null) {
          final now = DateTime.now();
          final diff = now.difference(dt);
          if (diff.inSeconds < 60) return '${diff.inSeconds} seconds ago';
          if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
          if (diff.inHours < 24) return '${diff.inHours} hours ago';
          if (diff.inDays == 1) return 'Yesterday';
          if (diff.inDays < 7) return '${diff.inDays} days ago';
          final weeks = (diff.inDays / 7).floor();
          if (weeks < 5) return '$weeks week${weeks > 1 ? 's' : ''} ago';
          final months = (diff.inDays / 30).floor();
          if (months < 12) return '$months month${months > 1 ? 's' : ''} ago';
          final years = (diff.inDays / 365).floor();
          return '$years year${years > 1 ? 's' : ''} ago';
        }
      }
    } catch (_) {}
    return '';
  }

  String? _getFeaturedImage(dynamic post) {
    try {
      final embedded = post['_embedded'];
      if (embedded == null) return null;
      final media = embedded['wp:featuredmedia'];
      if (media is List && media.isNotEmpty) {
        final url = media[0]['source_url'];
        if (url is String && url.isNotEmpty) return url;
      }
    } catch (_) {}
    return null;
  }
}
