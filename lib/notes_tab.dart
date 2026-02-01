import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api/api_service.dart';
import 'dart:convert';
import 'post_detail_screen.dart';
import 'news_posts_list_screen.dart';
import 'package:html_unescape/html_unescape.dart';
import 'widgets/loading_indicator.dart';

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
  int _requestId = 0; // guard to avoid stale updates
  
  // Pagination variables
  int _page = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  int? _currentCategoryId;
  final ScrollController _scrollController = ScrollController();

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

  Future<void> _loadChildrenOrPosts({required int parentId, required String title}) async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final int requestId = ++_requestId;
      // Load child categories of parentId
      final children = await ApiService.getJson(
        'https://darasahuru.ac.tz/wp-json/wp/v2/categories?parent=$parentId&per_page=100',
      ) as List<dynamic>?;
      if (children != null && children.isNotEmpty && mounted && requestId == _requestId) {
        // Drill down into children list
        setState(() {
          _subcatStack.add(List<dynamic>.from(_subcategories));
          _subcategories = children;
          _posts = [];
          _selectedSubcategory = null;
          _isLoading = false;
        });
      } else {
        // No children: show posts for this category id
        await _fetchPostsForSubcategory(parentId);
        if (mounted && requestId == _requestId) {
          setState(() {
            _selectedSubcategory = title;
          });
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Please turn on the internet and try again.';
        _isLoading = false;
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
    _scrollController.addListener(_onScroll);
    _fetchNotesPosts();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore && _currentCategoryId != null) {
        _loadMorePosts();
      }
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_hasMore || _currentCategoryId == null) return;
    
    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _page + 1;
      final url = 'https://darasahuru.ac.tz/wp-json/wp/v2/posts?categories=$_currentCategoryId&per_page=100&page=$nextPage&_embed=1';
      final more = await ApiService.getJson(url) as List<dynamic>?;
      
      if (more != null && more.isNotEmpty && mounted) {
        setState(() {
          _posts.addAll(more);
          _page = nextPage;
          _hasMore = more.length >= 100;
          _isLoadingMore = false;
        });
      } else {
        setState(() {
          _hasMore = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _fetchNotesPosts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final int requestId = ++_requestId;

    try {
      // First, fetch categories to find the ID for 'news-and-info' (cache-first)
      final categories = await ApiService.getJson('https://darasahuru.ac.tz/wp-json/wp/v2/categories?slug=news-and-info') as List<dynamic>?;
      if (categories != null) {
        if (categories.isNotEmpty) {
          final categoryId = categories[0]['id'];
          // Then, fetch subcategories for 'news-and-info' (cache-first)
          final subs = await ApiService.getJson('https://darasahuru.ac.tz/wp-json/wp/v2/categories?parent=$categoryId&per_page=100') as List<dynamic>?;
          if (mounted && requestId == _requestId) {
            setState(() {
              _subcategories = subs ?? [];
              _selectedSubcategory = null; // show menu first; load posts after user taps
              _posts = [];
              _isLoading = false;
            });
          }
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
      _page = 1;
      _hasMore = true;
      _currentCategoryId = subcategoryId;
    });

    try {
      final data = await ApiService.getJson('https://darasahuru.ac.tz/wp-json/wp/v2/posts?categories=$subcategoryId&per_page=100&page=1&_embed=1') as List<dynamic>?;
      if (data != null) {
        setState(() {
          _posts = data;
          _hasMore = data.length >= 100;
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
      _page = 1;
      _hasMore = true;
    });

    try {
      // Find the slug for the category title
      final category = _categories.firstWhere((cat) => cat['title'] == categoryTitle, orElse: () => {'slug': 'all'});
      final slug = category['slug'];

      if (slug == 'all') {
        // For 'All', fetch posts for the main category
        _currentCategoryId = 535;
        final response = await http.get(
          Uri.parse('https://darasahuru.ac.tz/wp-json/wp/v2/posts?categories=535&per_page=100&page=1&_embed=1'),
        );
        if (response.statusCode == 200) {
          final data = json.decode(response.body) as List<dynamic>;
          setState(() {
            _posts = data;
            _hasMore = data.length >= 100;
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
        final cats = await ApiService.getJson('https://darasahuru.ac.tz/wp-json/wp/v2/categories?slug=$slug') as List<dynamic>?;
        if (cats != null) {
          if (cats.isNotEmpty) {
            final catId = cats[0]['id'];
            _currentCategoryId = catId;
            // Fetch posts for that category
            final posts = await ApiService.getJson('https://darasahuru.ac.tz/wp-json/wp/v2/posts?categories=$catId&per_page=100&page=1&_embed=1') as List<dynamic>?;
            if (posts != null) {
              setState(() {
                _posts = posts;
                _hasMore = posts.length >= 100;
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
    final categoriesToShow = _subcategories.isNotEmpty
        ? _subcategories
            .map((c) => {
                  'title': c['name'] ?? 'Unknown',
                  'id': c['id'] ?? 0,
                  'slug': c['slug'] ?? ''
                })
            .toList()
        : _categories.toList();

    final accentColors = [
      Colors.red,
      Colors.deepOrange,
      Colors.pink,
      Colors.orange,
    ];

    return Container(
      color: const Color(0xFFFDF7FF),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_subcategories.isNotEmpty && _subcatStack.isNotEmpty)
            Container(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        if (_subcatStack.isNotEmpty) {
                          _subcategories = _subcatStack.removeLast();
                        } else {
                          _subcategories = [];
                        }
                        _error = null;
                      });
                    },
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Notes Levels',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFFFF1744), Color(0xFFFF8A65)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'News & Information',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Chagua kipengele ili kusoma taarifa na matangazo mapya.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
                final color = accentColors[index % accentColors.length];
                return Card(
                  color: Colors.white,
                  elevation: 0,
                  margin: const EdgeInsets.symmetric(vertical: 6.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.0),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14.0),
                    onTap: () async {
                      if (_subcategories.isNotEmpty) {
                        await _loadChildrenOrPosts(parentId: id, title: title);
                      } else {
                        try {
                          final cats = await ApiService.getJson('https://darasahuru.ac.tz/wp-json/wp/v2/categories?slug=$slug') as List<dynamic>?;
                          if (cats != null && cats.isNotEmpty) {
                            final topId = cats[0]['id'] as int;
                            await _loadChildrenOrPosts(parentId: topId, title: title);
                          }
                        } catch (_) {}
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: color.withOpacity(0.12),
                            ),
                            child: Icon(Icons.folder, color: color, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Class: $title',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.chevron_right, color: Colors.grey.shade500),
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

  Widget _buildPostsList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _posts.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _posts.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: PulsingRingsLoader(color: Colors.red, size: 32),
            ),
          );
        }
        final post = _posts[index];
        final rawTitle = post['title']?['rendered'] ?? 'Post';
        final title = HtmlUnescape().convert(rawTitle);
        final imgUrl = _featuredImage(post);
        final time = _timeAgo(post['date'], post['date_gmt']);
        final catId = (post['categories'] is List && (post['categories'] as List).isNotEmpty)
            ? (post['categories'][0] as int)
            : null;
        final content = post['content']?['rendered'] ?? '';
        return Card(
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
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
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: time.isNotEmpty ? Text(time) : null,
            onTap: () {
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
                    PulsingRingsLoader(color: Colors.red),
                    SizedBox(height: 16),
                    Text('Loading...'),
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
                : (_posts.isNotEmpty
                    ? Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _selectedSubcategory = null;
                                      _posts = [];
                                      _error = null;
                                    });
                                  },
                                  icon: const Icon(Icons.arrow_back),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'News',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: RefreshIndicator(
                              onRefresh: () async {
                                if (_currentCategoryId != null) {
                                  await _fetchPostsForSubcategory(_currentCategoryId!);
                                } else {
                                  await _fetchNotesPosts();
                                }
                              },
                              child: _buildPostsList(),
                            ),
                          ),
                        ],
                      )
                    : _buildSubcategoryMenu()),
      ),
    );
  }
}
