import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'post_detail_screen.dart';
import 'api/api_service.dart';

class ExamsTab extends StatefulWidget {
  const ExamsTab({super.key});

  @override
  State<ExamsTab> createState() => _ExamsTabState();
}

class _ExamsTabState extends State<ExamsTab> {
  List<dynamic> _posts = [];
  List<dynamic> _subcategories = [];
  final List<List<dynamic>> _subcatStack = [];
  bool _isLoading = true;
  bool _isTapping = false; // New loading state for taps
  String? _error;
  String? _selectedSubcategory;

  String _stripHtml(String s) => s.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll(RegExp(r'&#\d+;'), '').replaceAll('&nbsp;', ' ').replaceAll('&amp;', '&').replaceAll('&lt;', '<').replaceAll('&gt;', '>').replaceAll('&quot;', '"').replaceAll('&#8217;', '’').replaceAll('&#8216;', '‘').replaceAll('&#8220;', '"').replaceAll('&#8221;', '"').trim();

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
    _selectedSubcategory = null; // Start with cards view
    _fetchExamsPosts();
  }

  Future<void> _fetchExamsPosts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Directly fetch subcategories for parent 535 (Exams MITIHANI)
      final subcategoriesResponse = await http.get(
        Uri.parse('https://darasahuru.ac.tz/wp-json/wp/v2/categories?parent=535&per_page=100'),
      );
      if (subcategoriesResponse.statusCode == 200) {
        setState(() {
          _subcategories = json.decode(subcategoriesResponse.body);
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

  Widget _buildSubcategoryCards() {
    if (_subcategories.isEmpty && !_isLoading && !_isTapping) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isLoading || _isTapping) ...[
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading categories...'),
                  ],
                ),
              ),
            ),
          ] else if (_error != null) ...[
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_error!),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _error = null;
                        });
                        _fetchExamsPosts();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1,
                ),
                itemCount: _subcategories.length,
                itemBuilder: (context, index) {
                  final subcat = _subcategories[index];
                  final title = subcat['name'] ?? 'Unknown';
                  final id = subcat['id'];
                  final count = subcat['count'] ?? 0;
                  final isSelected = _selectedSubcategory == id.toString();
                  return Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: () async {
                        setState(() {
                          _isTapping = true;
                          _error = null;
                        });
                        try {
                          final result = await ApiService.loadCategoryForUI(id);
                          if (mounted) {
                            setState(() {
                              _isTapping = false;
                              // Push current subcategories level to stack before moving deeper
                              _subcatStack.add(List<dynamic>.from(_subcategories));
                              if (result['type'] == 'subcats') {
                                _subcategories = result['data'];
                                _posts = [];
                                _selectedSubcategory = null; // New level: show deeper subcategories
                              } else if (result['type'] == 'posts') {
                                _selectedSubcategory = id.toString();
                                _posts = result['data'];
                              } else {
                                _error = result['message'] ?? 'Failed to load data. Please try again.';
                              }
                            });
                          }
                        } catch (e) {
                          if (mounted) {
                            setState(() {
                              _isTapping = false;
                              _error = 'Please turn on the internet and try again.';
                            });
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder,
                              size: 48,
                              color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.black,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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
          return false; // handled
        }
        if (_subcatStack.isNotEmpty) {
          setState(() {
            _subcategories = _subcatStack.removeLast();
            _error = null;
          });
          return false; // handled
        }
        return true; // allow default back
      },
      child: Scaffold(
        body: _selectedSubcategory != null
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
                        'Posts in ${_subcategories.firstWhere((subcat) => subcat['id'].toString() == _selectedSubcategory)['name'] ?? 'Selected Subcategory'}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
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
                                    onPressed: () async {
                                      setState(() {
                                        _isTapping = true;
                                        _error = null;
                                      });
                                      final result = await ApiService.loadCategoryForUI(int.parse(_selectedSubcategory!));
                                      setState(() {
                                        _isTapping = false;
                                        if (result['type'] == 'posts') {
                                          _posts = result['data'];
                                          _error = null;
                                        } else {
                                          _error = result['message'] ?? 'Retry failed';
                                        }
                                      });
                                    },
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : _posts.isEmpty
                              ? const Center(child: Text('No posts found.'))
                              : ListView.builder(
                                  padding: const EdgeInsets.all(16.0),
                                  itemCount: _posts.length,
                                  itemBuilder: (context, index) {
                                    final post = _posts[index];
                                    final title = _stripHtml(post['title']?['rendered'] ?? 'Post');
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
                                                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
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
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => PostDetailScreen(
                                                title: title,
                                                htmlContent: content,
                                                categoryId: int.parse(_selectedSubcategory!), // Pass category ID for recommendations
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
            )
          : _buildSubcategoryCards(),
      ),
    );
  }
}
