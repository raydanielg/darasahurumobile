import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'post_detail_screen.dart';
import 'package:html_unescape/html_unescape.dart';
import 'widgets/loading_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class NotesTab extends StatefulWidget {
  const NotesTab({super.key});

  @override
  State<NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<NotesTab> {
  List<dynamic> _subcategories = [];
  List<dynamic> _posts = [];
  final List<List<dynamic>> _subcatStack = [];
  final List<String?> _nameStack = [];
  bool _isLoading = true;
  bool _isTapping = false;
  String? _error;
  String? _selectedSubcategory; // id as string
  String? _currentCategoryName;
  
  // Pagination state for posts list
  int _page = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  int? _currentCategoryId;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initLoad();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initLoad() async {
    final hadCache = await _loadCachedRootSubcategories();
    if (!hadCache) {
      await _fetchRootAndSubcategories();
    } else {
      unawaited(_refreshRootAndSubcategories());
    }
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore && _currentCategoryId != null) {
        _loadMorePosts();
      }
    }
  }

  Future<bool> _loadCachedRootSubcategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('notes_root_subcats');
      if (cached != null) {
        final data = json.decode(cached);
        if (mounted) {
          setState(() {
            _subcategories = (data is List) ? data : [];
            _isLoading = false;
            _error = null;
            _selectedSubcategory = null;
            _posts = [];
            _subcatStack.clear();
            _nameStack.clear();
            _currentCategoryName = null;
          });
        }
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> _refreshRootAndSubcategories() async {
    try {
      // Get root category by slug 'study-notes'
      final rootResp = await http.get(Uri.parse('https://darasahuru.ac.tz/wp-json/wp/v2/categories?slug=study-notes'));
      if (rootResp.statusCode != 200) return;
      final roots = json.decode(rootResp.body) as List;
      if (roots.isEmpty) return;
      final rootId = roots[0]['id'];

      final subsResp = await http.get(Uri.parse('https://darasahuru.ac.tz/wp-json/wp/v2/categories?parent=$rootId&per_page=100'));
      if (subsResp.statusCode == 200) {
        final list = json.decode(subsResp.body) as List;
        if (!mounted) return;
        setState(() {
          _subcategories = list;
          _error = null;
        });
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('notes_root_subcats', json.encode(_subcategories));
          await prefs.setInt('notes_root_id', rootId);
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<List<dynamic>> _fetchChildCategories(int parentId) async {
    final resp = await http.get(Uri.parse('https://darasahuru.ac.tz/wp-json/wp/v2/categories?parent=$parentId&per_page=100'));
    if (resp.statusCode == 200) {
      return json.decode(resp.body) as List<dynamic>;
    }
    return [];
  }

  Future<void> _openCategory(int id, String name) async {
    _error = null;
    // Push current level to stack before moving deeper
    setState(() {
      _subcatStack.add(List<dynamic>.from(_subcategories));
      _nameStack.add(_currentCategoryName);
    });

    // Try cached first
    final cached = await _readCachedCategory(id);
    if (mounted && cached != null) {
      setState(() {
        _applyCategoryResult(cached, id, name);
        _isTapping = false;
      });
      unawaited(_refreshCategoryInBackground(id, name));
      return;
    }

    // No cache: show loader and fetch
    setState(() {
      _isTapping = true;
    });
    try {
      final children = await _fetchChildCategories(id);
      if (children.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _applyCategoryResult({'type': 'subcats', 'data': children}, id, name);
          _isTapping = false;
        });
        await _saveCachedCategory(id, {'type': 'subcats', 'data': children});
      } else {
        final resp = await http.get(Uri.parse('https://darasahuru.ac.tz/wp-json/wp/v2/posts?categories='+id.toString()+'&per_page=100&page=1&_embed=1'));
        if (resp.statusCode == 200) {
          final posts = json.decode(resp.body) as List;
          if (!mounted) return;
          setState(() {
            _applyCategoryResult({'type': 'posts', 'data': posts}, id, name);
            _isTapping = false;
          });
          await _saveCachedCategory(id, {'type': 'posts', 'data': posts});
        } else {
          if (!mounted) return;
          setState(() {
            _isTapping = false;
            _error = 'Please turn on the internet and try again.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTapping = false;
          _error = 'Failed to open category: $e';
        });
      }
    }
  }

  Future<void> _fetchRootAndSubcategories() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _selectedSubcategory = null;
      _posts = [];
      _subcategories = [];
      _subcatStack.clear();
    });

    try {
      // Get root category by slug 'study-notes'
      final rootResp = await http.get(Uri.parse('https://darasahuru.ac.tz/wp-json/wp/v2/categories?slug=study-notes'));
      if (rootResp.statusCode != 200) throw Exception('Failed to load root category');
      final roots = json.decode(rootResp.body) as List;
      if (roots.isEmpty) throw Exception('Category study-notes not found');
      final rootId = roots[0]['id'];

      // Fetch subcategories for that root
      final subsResp = await http.get(Uri.parse('https://darasahuru.ac.tz/wp-json/wp/v2/categories?parent=$rootId&per_page=100'));
      if (subsResp.statusCode == 200) {
        setState(() {
          _subcategories = json.decode(subsResp.body) as List;
          _isLoading = false;
        });
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('notes_root_subcats', json.encode(_subcategories));
          await prefs.setInt('notes_root_id', rootId);
        } catch (_) {}
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

  Future<Map<String, dynamic>?> _readCachedCategory(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('notes_cat_'+id.toString());
      if (raw == null) return null;
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  Future<void> _saveCachedCategory(int id, Map<String, dynamic> value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('notes_cat_'+id.toString(), json.encode(value));
    } catch (_) {}
  }

  void _applyCategoryResult(Map<String, dynamic> result, int id, String name) {
    if (result['type'] == 'subcats') {
      _subcategories = result['data'] ?? [];
      _posts = [];
      _selectedSubcategory = null;
      _currentCategoryName = name;
    } else if (result['type'] == 'posts') {
      _selectedSubcategory = id.toString();
      _posts = result['data'] ?? [];
      _currentCategoryName = name;
      _page = 1;
      _hasMore = _posts.length >= 100;
      _currentCategoryId = id;
    } else {
      _error = result['message'] ?? 'Failed to load data. Please try again.';
    }
  }

  Future<void> _refreshCategoryInBackground(int id, String name) async {
    try {
      final children = await _fetchChildCategories(id);
      if (children.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _applyCategoryResult({'type': 'subcats', 'data': children}, id, name);
        });
        await _saveCachedCategory(id, {'type': 'subcats', 'data': children});
      } else {
        final resp = await http.get(Uri.parse('https://darasahuru.ac.tz/wp-json/wp/v2/posts?categories='+id.toString()+'&per_page=20&_embed=1'));
        if (resp.statusCode == 200) {
          final posts = json.decode(resp.body) as List;
          if (!mounted) return;
          setState(() {
            _applyCategoryResult({'type': 'posts', 'data': posts}, id, name);
          });
          await _saveCachedCategory(id, {'type': 'posts', 'data': posts});
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchPostsForSubcategory(int subId) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _posts = [];
    });
    try {
      final resp = await http.get(Uri.parse('https://darasahuru.ac.tz/wp-json/wp/v2/posts?categories=$subId&per_page=100&page=1&_embed=1'));
      if (resp.statusCode == 200) {
        setState(() {
          _selectedSubcategory = subId.toString();
          _posts = json.decode(resp.body) as List;
          _page = 1;
          _hasMore = _posts.length >= 100;
          _currentCategoryId = subId;
          _isLoading = false;
        });
        try {
          await _saveCachedCategory(subId, {'type': 'posts', 'data': _posts});
        } catch (_) {}
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

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_hasMore || _currentCategoryId == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _page + 1;
      final resp = await http.get(Uri.parse(
          'https://darasahuru.ac.tz/wp-json/wp/v2/posts?categories='+_currentCategoryId.toString()+'&per_page=100&page='+nextPage.toString()+'&_embed=1'));
      if (resp.statusCode == 200) {
        final more = json.decode(resp.body) as List;
        if (more.isNotEmpty) {
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
      child: _isLoading
          ? const Center(child: PulsingRingsLoader(color: Colors.red))
          : _error != null
              ? Center(child: Text(_error!))
              : _selectedSubcategory == null
                  ? Container(
                      color: const Color(0xFFFDF7FF),
                      child: Column(
                        children: [
                          if (_subcatStack.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _subcategories = _subcatStack.removeLast();
                                        _currentCategoryName =
                                            _nameStack.isNotEmpty ? _nameStack.removeLast() : null;
                                        _error = null;
                                      });
                                    },
                                    icon: const Icon(Icons.arrow_back),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _currentCategoryName ?? 'My Notes',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Container(
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
                                    child: const Icon(Icons.edit_note_rounded,
                                        color: Colors.white, size: 28),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'My Saved Notes',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Chagua darasa au mada uliyohifadhi.',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Colors.white.withOpacity(0.9),
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: _subcategories.length,
                              itemBuilder: (context, index) {
                                final sub = _subcategories[index];
                                final name = sub['name'] ?? 'Category';
                                final id = sub['id'] as int;
                                final count = sub['count'] ?? 0;
                                final accentColors = [
                                  Colors.red,
                                  Colors.deepOrange,
                                  Colors.pink,
                                  Colors.orange,
                                ];
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
                                    onTap: () => _openCategory(id, name),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0, vertical: 14.0),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(12),
                                              color: color.withOpacity(0.12),
                                            ),
                                            child: Icon(Icons.folder,
                                                color: color, size: 24),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  name.toString().toUpperCase(),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                if (_subcatStack.length >= 2)
                                                  Text(
                                                    '$count items',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors
                                                          .grey.shade600,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(Icons.chevron_right,
                                              color: Colors.grey.shade500),
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
                    )
                  : Column(
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
                                    // keep current name as parent when going back to subcategories
                                  });
                                },
                                icon: const Icon(Icons.arrow_back),
                              ),
                              const SizedBox(width: 8),
                              Text(_currentCategoryName ?? 'Notes', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: _posts.isEmpty
                              ? const Center(child: Text('No notes found.'))
                              : RefreshIndicator(
                                  onRefresh: () async {
                                    if (_selectedSubcategory != null) {
                                      final id = int.tryParse(_selectedSubcategory!);
                                      if (id != null) {
                                        await _fetchPostsForSubcategory(id);
                                      }
                                    }
                                  },
                                  child: ListView.builder(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.all(16.0),
                                    itemCount: _posts.length + (_isLoadingMore ? 1 : 0),
                                    itemBuilder: (context, index) {
                                      if (_isLoadingMore && index == _posts.length) {
                                        return const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 16),
                                          child: Center(
                                            child: PulsingRingsLoader(color: Colors.red, size: 24),
                                          ),
                                        );
                                      }
                                      final post = _posts[index];
                                      final rawTitle = post['title']?['rendered'] ?? 'Note';
                                      final title = HtmlUnescape().convert(_stripHtml(rawTitle));
                                      final content = post['content']?['rendered'] ?? '';
                                      final snippet = HtmlUnescape().convert(_stripHtml(content));
                                      final preview = snippet.length > 140 ? snippet.substring(0, 140) + '…' : snippet;
                                      final catId = (post['categories'] is List && (post['categories'] as List).isNotEmpty)
                                          ? (post['categories'][0] as int)
                                          : null;
                                      final imgUrl = _featuredImage(post);
                                      return Card(
                                        elevation: 0,
                                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12.0),
                                          side: BorderSide(color: Colors.grey.shade300, width: 1),
                                        ),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(12.0),
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
                                          child: Padding(
                                            padding: const EdgeInsets.all(12.0),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                ClipRRect(
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
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        title,
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Text(
                                                        preview,
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                const Icon(Icons.chevron_right),
                                              ],
                                            ),
                                          ),
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
