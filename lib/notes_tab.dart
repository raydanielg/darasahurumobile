import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'post_detail_screen.dart';
import 'news_posts_list_screen.dart';
import 'package:html_unescape/html_unescape.dart';

class NewsTab extends StatefulWidget {
  const NewsTab({super.key});

  @override
  State<NewsTab> createState() => _NewsTabState();
}

class _NewsTabState extends State<NewsTab> {
  List<dynamic> _posts = [];
  List<dynamic> _subcategories = [];
  List<dynamic> _recommendedPosts = [];
  final List<List<dynamic>> _subcatStack = [];
  bool _isLoading = true;
  bool _isTapping = false; // Add this field
  String? _error;
  String? _selectedSubcategory;

  final List<Map<String, String>> _categories = const [
    {'title': 'A level', 'slug': 'a-level'},
    {'title': 'O level', 'slug': 'o-level'},
    {'title': 'Primary', 'slug': 'primary'},
  ];

  String _stripHtml(String s) => s.replaceAll(RegExp(r'<[^>]*>'), '');

  String? _featuredImage(dynamic post) {
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

  Future<void> _fetchRecommendedPosts(int categoryId) async {
    try {
      final response = await http.get(
        Uri.parse('https://darasahuru.ac.tz/wp-json/wp/v2/posts?categories=$categoryId&per_page=4&_embed=1'),
      );
      if (response.statusCode == 200) {
        setState(() {
          _recommendedPosts = json.decode(response.body);
        });
      } else {
        setState(() {
          _recommendedPosts = [];
        });
      }
    } catch (_) {
      setState(() {
        _recommendedPosts = [];
      });
    }
  }

  String _timeAgo(String? dateStr, String? dateGmtStr) {
    try {
      DateTime? dt;
      if (dateGmtStr is String && dateGmtStr.isNotEmpty) {
        dt = DateTime.tryParse(dateGmtStr)?.toLocal();
      }
      dt ??= (dateStr is String && dateStr.isNotEmpty) ? DateTime.tryParse(dateStr) : null;
      if (dt == null) return '';
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
    } catch (_) {
      return '';
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedSubcategory = null;
    _fetchNotesPosts();
  }

  Future<void> _fetchNotesPosts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // First, fetch categories to find the ID for 'news-and-info'
      final categoriesResponse = await http.get(
        Uri.parse('https://darasahuru.ac.tz/wp-json/wp/v2/categories?slug=news-and-info'),
      );
      print('News Categories API Status: ${categoriesResponse.statusCode}');
      print('News Categories Response Body: ${categoriesResponse.body}');
      if (categoriesResponse.statusCode == 200) {
        final List<dynamic> categories = json.decode(categoriesResponse.body);
        if (categories.isNotEmpty) {
          final categoryId = categories[0]['id'];
          print('Found category ID: $categoryId');

          // Then, fetch subcategories for 'news-and-info'
          final subcategoriesResponse = await http.get(
            Uri.parse('https://darasahuru.ac.tz/wp-json/wp/v2/categories?parent=$categoryId&per_page=100'),
          );
          print('Subcategories API Status: ${subcategoriesResponse.statusCode}');
          int postsCategoryId = categoryId;
          if (subcategoriesResponse.statusCode == 200) {
            final List<dynamic> subs = json.decode(subcategoriesResponse.body);
            if (subs.isNotEmpty) {
              postsCategoryId = subs[0]['id'];
            }
            setState(() {
              _subcategories = subs;
              _selectedSubcategory = null; // show menu first; load posts after user taps
            });
          }
          // Do not auto-load posts; wait for user to tap a category
          setState(() {
            _posts = [];
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = 'News category not found.';
            _isLoading = false;
          });
        }
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

  Future<void> _fetchSubcategoriesForCategory(String categoryTitle, String slug) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch category ID by slug
      final catResponse = await http.get(
        Uri.parse('https://darasahuru.ac.tz/wp-json/wp/v2/categories?slug=$slug'),
      );
      if (catResponse.statusCode == 200) {
        final List<dynamic> cats = json.decode(catResponse.body);
        if (cats.isNotEmpty) {
          final catId = cats[0]['id'];
          // Fetch subcategories for that category
          final response = await http.get(
            Uri.parse('https://darasahuru.ac.tz/wp-json/wp/v2/categories?parent=$catId&per_page=100'),
          );
          if (response.statusCode == 200) {
            setState(() {
              // Push current subcategories to stack before going deeper
              _subcatStack.add(List<dynamic>.from(_subcategories));
              _subcategories = json.decode(response.body);
              _posts = [];
              _selectedSubcategory = null; // stay on menu level until user selects a subcategory
              _isLoading = false;
            });
          } else {
            setState(() {
              _error = 'Failed to load subcategories for $categoryTitle.';
              _isLoading = false;
            });
          }
        } else {
          setState(() {
            _error = 'Category $categoryTitle not found.';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _error = 'Failed to load category for $categoryTitle.';
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

  Future<void> _fetchPostsForSubcategory(int subcategoryId) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('https://darasahuru.ac.tz/wp-json/wp/v2/posts?categories=$subcategoryId&per_page=30&_embed=1'),
      );
      if (response.statusCode == 200) {
        setState(() {
          _posts = json.decode(response.body);
          _isLoading = false;
        });
        // Fetch recommended posts for this subcategory (do not block UI)
        _fetchRecommendedPosts(subcategoryId);
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

  Future<void> _fetchPostsForCategory(String categoryTitle) async {
    setState(() {
      _isLoading = true;
      _error = null;
      // Mark selected to show back header in UI
      _selectedSubcategory = 'cat:$categoryTitle';
    });

    try {
      // Find the slug for the category title
      final category = _categories.firstWhere((cat) => cat['title'] == categoryTitle, orElse: () => {'slug': 'all'});
      final slug = category['slug'];

      if (slug == 'all') {
        // For 'All', fetch posts for the main category
        final response = await http.get(
          Uri.parse('https://darasahuru.ac.tz/wp-json/wp/v2/posts?categories=535&per_page=30&_embed=1'),
        );
        if (response.statusCode == 200) {
          setState(() {
            _posts = json.decode(response.body);
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = 'Please turn on the internet and try again.';
            _isLoading = false;
          });
        }
      } else {
        // Fetch category ID by slug
        final catResponse = await http.get(
          Uri.parse('https://darasahuru.ac.tz/wp-json/wp/v2/categories?slug=$slug'),
        );
        if (catResponse.statusCode == 200) {
          final List<dynamic> cats = json.decode(catResponse.body);
          if (cats.isNotEmpty) {
            final catId = cats[0]['id'];
            // Fetch posts for that category
            final response = await http.get(
              Uri.parse('https://darasahuru.ac.tz/wp-json/wp/v2/posts?categories=$catId&per_page=30&_embed=1'),
            );
            if (response.statusCode == 200) {
              setState(() {
                _posts = json.decode(response.body);
                _isLoading = false;
              });
            } else {
              setState(() {
                _error = 'Failed to load posts for $categoryTitle.';
                _isLoading = false;
              });
            }
          } else {
            setState(() {
              _error = 'Category $categoryTitle not found.';
              _isLoading = false;
            });
          }
        } else {
          setState(() {
            _error = 'Failed to load category for $categoryTitle.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading posts for $categoryTitle: $e';
        _isLoading = false;
      });
    }
  }

  Widget _buildSubcategoryMenu() {
    const banned = {'tamisemi', 'universities-colleges', 'necta-info', 'necta-tanzania', 'online-services'};
    final categoriesToShow = _subcategories.isNotEmpty
        ? _subcategories
            .where((c) {
              final slug = (c['slug'] ?? '').toString().toLowerCase();
              final name = (c['name'] ?? '').toString().toLowerCase();
              if (banned.contains(slug)) return false;
              if (slug.contains('univers') || name.contains('univers')) return false;
              return true;
            })
            .map((c) => {
                  'title': c['name'] ?? 'Unknown',
                  'id': c['id'] ?? 0,
                  'slug': c['slug'] ?? ''
                })
            .toList()
        : _categories
            .where((c) {
              final slug = (c['slug'] ?? '').toLowerCase();
              final name = (c['title'] ?? '').toLowerCase();
              if (banned.contains(slug)) return false;
              if (slug.contains('univers') || name.contains('univers')) return false;
              return true;
            })
            .toList();

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Explore news from different categories',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 16.0),
              itemCount: categoriesToShow.length,
              itemBuilder: (context, index) {
                final cat = categoriesToShow[index];
                final titleRaw = cat['title'] ?? 'Unknown';
                final title = HtmlUnescape().convert(titleRaw);
                final id = cat['id'] ?? 0;
                final slug = cat['slug'] ?? '';
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12.0),
                    onTap: () {
                      if (_subcategories.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NewsPostsListScreen(title: title, categoryId: id),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NewsPostsListScreen(title: title, slug: slug),
                          ),
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.folder, color: Colors.blueGrey, size: 28),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_selectedSubcategory != null) {
          setState(() {
            _selectedSubcategory = null;
            _posts = [];
            _error = null;
          });
          return false;
        }
        if (_subcatStack.isNotEmpty) {
          setState(() {
            _subcategories = _subcatStack.removeLast();
            _error = null;
          });
          return false;
        }
        return true;
      },
      child: Scaffold(
        body: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading categories...'),
                  ],
                ),
              )
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _fetchNotesPosts, child: const Text('Retry')),
                      ],
                    ),
                  )
                : _buildSubcategoryMenu(),
      ),
    );
  }
}
