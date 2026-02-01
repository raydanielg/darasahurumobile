import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'post_detail_screen.dart';
import 'api/api_service.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'widgets/loading_indicator.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  List<dynamic> _posts = [];
  List<dynamic> _subcategories = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  static const int _perPage = 20;
  int _totalPages = 1;
  bool _hasMore = true;
  bool _autoLoadAll = false; // do not auto fetch all pages, load as user scrolls
  String? _error;
  String? _selectedCategory; // Selected category slug
  Map<String, int> _categoryCache = {}; // Cache slug to ID
  int _currentPage = 1;
  ScrollController _scrollController = ScrollController();
  int _requestId = 0; // guard to avoid stale updates

  final List<Map<String, String>> _categories = const [
    {'title': 'All', 'slug': 'all'},
    {'title': 'A level', 'slug': 'a-level'}, // Adjust slug if API uses 'alevel-notes' or similar
    {'title': 'O level', 'slug': 'o-level'},
    {'title': 'Primary', 'slug': 'primary'},
    {'title': 'Necta Info', 'slug': 'necta-info'},
    {'title': 'Un & Colleges', 'slug': 'universities-colleges'},
    {'title': 'Tamisemi', 'slug': 'tamisemi'},
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

  Future<void> _loadAllPosts() async {
    // Loop until all pages are fetched
    while (_hasMore && !_isLoadingMore) {
      await _loadMorePosts();
      // Yield to UI
      await Future.delayed(const Duration(milliseconds: 50));
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
    _selectedCategory = 'all'; // Start with All
    _fetchCategories(); // Fetch categories early for speed
    _fetchPosts();

    // Add scroll listener for pagination
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        if (!_isLoading && !_isLoadingMore) {
          _loadMorePosts();
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    ApiService.clearCache();
    _categoryCache.clear();
    _hasMore = true;
    _currentPage = 1;
    await _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    setState(() {
      _error = null;
      _currentPage = 1;
      _posts = [];
      _isLoading = true;
    });
    final int requestId = ++_requestId;

    try {
      String url = 'https://darasahuru.ac.tz/wp-json/wp/v2/posts?per_page='+_perPage.toString()+'&_embed=1&page=1';
      if (_selectedCategory != null && _selectedCategory != 'all') {
        if (_selectedCategory == 'a-level') {
          // Use combined categories 504,34,506,534 with per_page=_perPage
          url = 'https://darasahuru.ac.tz/wp-json/wp/v2/posts?categories=504,34,506,534&per_page='+_perPage.toString()+'&_embed=1&page=1';
        } else if (_selectedCategory == 'o-level') {
          // O Level: combine Form I–IV study notes (12,47,48,24)
          url = 'https://darasahuru.ac.tz/wp-json/wp/v2/posts?categories=12,47,48,24&per_page='+_perPage.toString()+'&_embed=1&page=1';
        } else if (_selectedCategory == 'primary') {
          // Use combined Primary categories with per_page=_perPage
          url = 'https://darasahuru.ac.tz/wp-json/wp/v2/posts?categories=181,182,210,211,54,212,95,213,214&per_page='+_perPage.toString()+'&_embed=1&page=1';
        } else if (_selectedCategory == 'necta-info') {
          // Use specific API for Necta Info with multiple categories
          url = 'https://darasahuru.ac.tz/wp-json/wp/v2/posts?categories=122,55,102,5,73,30,9,51&per_page='+_perPage.toString()+'&_embed=1&page=1';
        } else if (_selectedCategory == 'universities-colleges') {
          // Use specific API for Un & Colleges with multiple categories
          url = 'https://darasahuru.ac.tz/wp-json/wp/v2/posts?categories=57,58,178,66,179,479,466,65,475,97&per_page='+_perPage.toString()+'&_embed=1&page=1';
        } else if (_selectedCategory == 'tamisemi') {
          // Tamisemi: per_page=_perPage and page=1
          url = 'https://darasahuru.ac.tz/wp-json/wp/v2/posts?categories=43&per_page='+_perPage.toString()+'&_embed=1&page=1';
        } else {
          final categoryId = _getCategoryId(_selectedCategory!);
          if (categoryId != null) {
            url = 'https://darasahuru.ac.tz/wp-json/wp/v2/posts?categories=$categoryId&per_page='+_perPage.toString()+'&_embed=1&page=1';
          } else {
            // Fallback: show error if category not found
            setState(() {
              _error = 'Category not found.';
              _isLoading = false;
            });
            return;
          }
        }
      }

      // Try cached first for instant UI (per-category URL). Guard with requestId.
      try {
        final cached = await ApiService.getJson(url) as List<dynamic>?;
        if (cached != null && mounted && requestId == _requestId) {
          setState(() {
            _posts = cached;
            _isLoading = false; // show instantly
            _hasMore = true; // optimistic until headers arrive
          });
        }
      } catch (_) {}

      // Then fetch fresh with headers to get accurate pagination. Guard with requestId.
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200 && mounted && requestId == _requestId) {
        final fresh = json.decode(response.body) as List<dynamic>;
        setState(() {
          _posts = fresh;
          _isLoading = false;
          _totalPages = int.tryParse(response.headers['x-wp-totalpages'] ?? '1') ?? 1;
          _hasMore = _currentPage < _totalPages;
        });
        if (_autoLoadAll && _hasMore) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && requestId == _requestId) {
              _loadAllPosts();
            }
          });
        }
      } else {
        if (mounted && requestId == _requestId) {
          setState(() {
            _error = 'Please turn on the internet and try again.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted && requestId == _requestId) {
        setState(() {
          _error = 'Please turn on the internet and try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchCategories() async {
    if (_categoryCache.isNotEmpty) return; // Already cached
    try {
      final categories = await ApiService.getJson('https://darasahuru.ac.tz/wp-json/wp/v2/categories?per_page=100') as List<dynamic>?;
      if (categories != null) {
        for (var cat in categories) {
          final slug = cat['slug'];
          final id = cat['id'];
          if (slug != null && id != null) {
            _categoryCache[slug] = id;
          }
        }
      }
    } catch (_) {
      // Ignore errors for category fetch
    }
  }

  int? _getCategoryId(String slug) {
    return _categoryCache[slug];
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore) return;
    if (!_hasMore) return;

    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });

    try {
      // Build URL based on selected category and next page
      String url;
      if (_selectedCategory == null || _selectedCategory == 'all') {
        url = 'https://darasahuru.ac.tz/wp-json/wp/v2/posts?per_page='+_perPage.toString()+'&_embed=1&page='+_currentPage.toString();
      } else if (_selectedCategory == 'a-level') {
        // Use combined categories 504,34,506,534 with per_page=_perPage for pagination too
        url = 'https://darasahuru.ac.tz/wp-json/wp/v2/posts?categories=504,34,506,534&per_page='+_perPage.toString()+'&_embed=1&page='+_currentPage.toString();
      } else if (_selectedCategory == 'o-level') {
        // O Level pagination: same combined categories 12,47,48,24
        url = 'https://darasahuru.ac.tz/wp-json/wp/v2/posts?categories=12,47,48,24&per_page='+_perPage.toString()+'&_embed=1&page='+_currentPage.toString();
      } else if (_selectedCategory == 'primary') {
        url = 'https://darasahuru.ac.tz/wp-json/wp/v2/posts?categories=181,182,210,211,54,212,95,213,214&per_page='+_perPage.toString()+'&_embed=1&page='+_currentPage.toString();
      } else if (_selectedCategory == 'necta-info') {
        url = 'https://darasahuru.ac.tz/wp-json/wp/v2/posts?categories=122,55,102,5,73,30,9,51&per_page='+_perPage.toString()+'&_embed=1&page='+_currentPage.toString();
      } else if (_selectedCategory == 'universities-colleges') {
        url = 'https://darasahuru.ac.tz/wp-json/wp/v2/posts?categories=57,58,178,66,179,479,466,65,475,97&per_page='+_perPage.toString()+'&_embed=1&page='+_currentPage.toString();
      } else if (_selectedCategory == 'tamisemi') {
        url = 'https://darasahuru.ac.tz/wp-json/wp/v2/posts?categories=43&per_page='+_perPage.toString()+'&_embed=1&page='+_currentPage.toString();
      } else {
        final categoryId = _getCategoryId(_selectedCategory!);
        url = 'https://darasahuru.ac.tz/wp-json/wp/v2/posts?categories=$categoryId&per_page='+_perPage.toString()+'&_embed=1&page='+_currentPage.toString();
      }

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final newPosts = json.decode(response.body) as List;
        if (newPosts.isNotEmpty) {
          setState(() {
            _posts.addAll(newPosts);
            _isLoadingMore = false;
            _totalPages = int.tryParse(response.headers['x-wp-totalpages'] ?? _totalPages.toString()) ?? _totalPages;
            _hasMore = _currentPage < _totalPages;
          });
        } else {
          // No more posts
          setState(() {
            _isLoadingMore = false;
            _hasMore = false;
          });
        }
      } else {
        setState(() {
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _fetchSubcategoriesForUnColleges() async {
    try {
      final response = await http.get(
        Uri.parse('https://darasahuru.ac.tz/wp-json/wp/v2/categories?parent=63'),
      );
      if (response.statusCode == 200) {
        setState(() {
          _subcategories = json.decode(response.body);
        });
      }
    } catch (_) {
      // Ignore errors for subcategory fetch
    }
  }

  Widget _buildCategoryMenu() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((cat) {
                final title = cat['title']!;
                final slug = cat['slug']!;
                final isSelected = _selectedCategory == slug;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(title),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected && _selectedCategory != slug) {
                        setState(() {
                          _selectedCategory = slug;
                        });
                        _fetchPosts(); // Quick refresh on selection
                      }
                    },
                    selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    backgroundColor: Colors.grey.shade100,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildCategoryMenu(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          PulsingRingsLoader(color: Colors.red),
                          SizedBox(height: 16),
                          Text('Loading posts...'),
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
                              ElevatedButton(
                                onPressed: _fetchPosts,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _posts.isEmpty
                          ? const Center(child: Text('No posts found.'))
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(16.0),
                              itemCount: _posts.length + (_isLoadingMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (_isLoadingMore && index == _posts.length) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: Center(child: PulsingRingsLoader(color: Colors.red, size: 28)),
                                  );
                                }

                                final post = _posts[index];
                                final title = HtmlUnescape().convert(_stripHtml(post['title']?['rendered'] ?? 'Post'));
                                final content = post['content']?['rendered'] ?? '';
                                final imgUrl = _featuredImage(post);
                                final time = _timeAgo(post['date'], post['date_gmt']);
                                return Card(
                                  elevation: 0, // Flat design, no shadow
                                  margin: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(color: Colors.grey.shade300, width: 1),
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
                                              loadingBuilder: (context, child, loadingProgress) {
                                                if (loadingProgress == null) return child;
                                                return Container(
                                                  width: 64,
                                                  height: 64,
                                                  color: Colors.grey.shade200,
                                                  child: const Center(child: PulsingRingsLoader(color: Colors.red, size: 24)),
                                                );
                                              },
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
                                    trailing: null,
                                    onTap: () {
                                      final catId = (post['categories'] is List && (post['categories'] as List).isNotEmpty)
                                          ? (post['categories'][0] as int)
                                          : null;
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => PostDetailScreen(
                                            title: title,
                                            htmlContent: content,
                                            categoryId: catId,
                                            postUrl: (post['link'] is String) ? post['link'] as String : null,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }
}
