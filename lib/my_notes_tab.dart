import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'post_detail_screen.dart';
import 'package:html_unescape/html_unescape.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchRootAndSubcategories();
  }

  Future<List<dynamic>> _fetchChildCategories(int parentId) async {
    final resp = await http.get(Uri.parse('https://darasahuru.ac.tz/wp-json/wp/v2/categories?parent=$parentId&per_page=100'));
    if (resp.statusCode == 200) {
      return json.decode(resp.body) as List<dynamic>;
    }
    return [];
  }

  Future<void> _openCategory(int id, String name) async {
    setState(() {
      _isTapping = true;
      _error = null;
    });
    try {
      final children = await _fetchChildCategories(id);
      if (children.isNotEmpty) {
        setState(() {
          _subcatStack.add(List<dynamic>.from(_subcategories));
          _nameStack.add(_currentCategoryName);
          _subcategories = children;
          _posts = [];
          _selectedSubcategory = null;
          _currentCategoryName = name;
          _isTapping = false;
        });
      } else {
        await _fetchPostsForSubcategory(id);
        if (mounted) {
          setState(() {
            _currentCategoryName = name;
            _isTapping = false;
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

  Future<void> _fetchPostsForSubcategory(int subId) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _posts = [];
    });
    try {
      final resp = await http.get(Uri.parse('https://darasahuru.ac.tz/wp-json/wp/v2/posts?categories=$subId&per_page=20&_embed=1'));
      if (resp.statusCode == 200) {
        setState(() {
          _selectedSubcategory = subId.toString();
          _posts = json.decode(resp.body) as List;
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

  String _stripHtml(String s) => s.replaceAll(RegExp(r'<[^>]*>'), '');

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
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _selectedSubcategory == null
                  ? Column(
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
                                      _currentCategoryName = _nameStack.isNotEmpty ? _nameStack.removeLast() : null;
                                      _error = null;
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
                          child: ListView.builder(
                              padding: const EdgeInsets.all(16.0),
                              itemCount: _subcategories.length,
                              itemBuilder: (context, index) {
                                final sub = _subcategories[index];
                                final name = sub['name'] ?? 'Category';
                                final id = sub['id'] as int;
                                final count = sub['count'] ?? 0;
                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                                  child: ListTile(
                                    leading: const Icon(Icons.folder),
                                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: (_subcatStack.length >= 2)
                                        ? Text('$count items')
                                        : null,
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => _openCategory(id, name),
                                  ),
                                );
                              },
                            ),
                        ),
                      ],
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
                              : ListView.builder(
                                  padding: const EdgeInsets.all(16.0),
                                  itemCount: _posts.length,
                                  itemBuilder: (context, index) {
                                    final post = _posts[index];
                                    final rawTitle = post['title']?['rendered'] ?? 'Note';
                                    final title = HtmlUnescape().convert(_stripHtml(rawTitle));
                                    final content = post['content']?['rendered'] ?? '';
                                    final snippet = HtmlUnescape().convert(_stripHtml(content));
                                    final preview = snippet.length > 140 ? snippet.substring(0, 140) + '…' : snippet;
                                    final catId = (post['categories'] is List && (post['categories'] as List).isNotEmpty)
                                        ? (post['categories'][0] as int)
                                        : null;
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
                                              Container(
                                                width: 40,
                                                height: 40,
                                                decoration: BoxDecoration(
                                                  color: Colors.blueGrey.shade50,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Icon(Icons.description, color: Colors.blueGrey),
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
                      ],
                    ),
    );
  }
}
