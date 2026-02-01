import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api/api_service.dart';
import 'package:html_unescape/html_unescape.dart';
import 'post_detail_screen.dart';
import 'widgets/loading_indicator.dart';

class NewsPostsListScreen extends StatefulWidget {
  final String title;
  final int? categoryId; // if provided, fetch by id
  final String? slug; // fallback: resolve to id using slug; 'all' -> 535

  const NewsPostsListScreen({super.key, required this.title, this.categoryId, this.slug});

  @override
  State<NewsPostsListScreen> createState() => _NewsPostsListScreenState();
}

class _NewsPostsListScreenState extends State<NewsPostsListScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _posts = [];
  int _page = 1;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _isLoadingMore || _isLoading) return;
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _posts = [];
      _page = 1;
      _hasMore = true;
      _isLoadingMore = false;
    });
    final int requestId = ++_requestId;
    try {
      int? catId = widget.categoryId;
      if (catId == null) {
        final slug = widget.slug ?? '';
        if (slug == 'all') {
          catId = 535;
        } else if (slug.isNotEmpty) {
          final list = await ApiService.getJson('https://darasahuru.ac.tz/wp-json/wp/v2/categories?slug=$slug') as List<dynamic>?;
          if (list != null && list.isNotEmpty) {
            catId = list[0]['id'] as int;
          }
        }
      }

      if (catId == null) {
        setState(() {
          _error = 'Please turn on the internet and try again.';
          _isLoading = false;
        });
        return;
      }

      final url = 'https://darasahuru.ac.tz/wp-json/wp/v2/posts?categories=$catId&per_page=100&page=1&_embed=1';
      // 1) Try cached instantly
      final cached = await ApiService.getJson(url) as List<dynamic>?;
      if (cached != null && mounted && requestId == _requestId) {
        setState(() {
          _posts = cached;
          _isLoading = false;
          _hasMore = cached.length >= 100;
          _page = 1;
        });
      }
      // 2) Fetch fresh and update
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200 && mounted && requestId == _requestId) {
        final fresh = json.decode(resp.body) as List<dynamic>;
        setState(() {
          _posts = fresh;
          _isLoading = false;
          _hasMore = fresh.length >= 100;
          _page = 1;
        });
      } else if (cached == null && mounted && requestId == _requestId) {
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

  Future<List<dynamic>?> _fetchPosts(int catId, {required int page}) async {
    final url = 'https://darasahuru.ac.tz/wp-json/wp/v2/posts?categories=$catId&per_page=100&page=$page&_embed=1';
    final data = await ApiService.getJson(url) as List<dynamic>?;
    return data;
  }

  Future<void> _loadMore() async {
    setState(() {
      _isLoadingMore = true;
    });
    try {
      int? catId = widget.categoryId;
      if (catId == null) {
        // Resolve again (should be rare since first load resolved it)
        final slug = widget.slug ?? '';
        if (slug == 'all') {
          catId = 535;
        } else if (slug.isNotEmpty) {
          final res = await http.get(Uri.parse('https://darasahuru.ac.tz/wp-json/wp/v2/categories?slug=$slug'));
          if (res.statusCode == 200) {
            final list = json.decode(res.body) as List<dynamic>;
            if (list.isNotEmpty) {
              catId = list[0]['id'] as int;
            }
          }
        }
      }
      if (catId == null) {
        setState(() {
          _isLoadingMore = false;
          _hasMore = false;
        });
        return;
      }

      final nextPage = _page + 1;
      final more = await _fetchPosts(catId, page: nextPage);
      if (more != null && more.isNotEmpty) {
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
    } catch (_) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  String _stripHtml(String s) => s.replaceAll(RegExp(r'<[^>]*>'), '');

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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: _isLoading
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
                      ElevatedButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : _posts.isEmpty
                  ? const Center(child: Text('No posts found.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _posts.length,
                        itemBuilder: (context, index) {
                        final post = _posts[index];
                        final title = HtmlUnescape().convert(_stripHtml(post['title']?['rendered'] ?? 'Post'));
                        final content = post['content']?['rendered'] ?? '';
                        final imgUrl = _featuredImage(post);
                        final time = _timeAgo(post['date'], post['date_gmt']);
                        return Card(
                          elevation: 0,
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
                            subtitle: time.isNotEmpty ? Text(time, style: const TextStyle(fontSize: 12, color: Colors.grey)) : null,
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
    );
  }
}
