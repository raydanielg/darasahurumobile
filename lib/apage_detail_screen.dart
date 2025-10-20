import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import '../api/api_service.dart';

class PageDetailScreen extends StatefulWidget {
  final String title;
  final String slug;

  const PageDetailScreen({
    super.key,
    required this.title,
    required this.slug,
  });

  @override
  State<PageDetailScreen> createState() => _PageDetailScreenState();
}

class _PageDetailScreenState extends State<PageDetailScreen> {
  String? _content;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final content = await ApiService.fetchPageContent(widget.slug);

    setState(() {
      _isLoading = false;
      if (content != null) {
        _content = content;
      } else {
        _error = 'Failed to load content.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadContent,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Html(
                    data: _content ?? '<p>No content available.</p>',
                    style: {
                      'body': Style(fontSize: FontSize(16.0), lineHeight: LineHeight.number(1.6)),
                      'h1': Style(margin: Margins.only(bottom: 12)),
                      'h2': Style(margin: Margins.only(top: 16, bottom: 8)),
                      'p': Style(margin: Margins.only(bottom: 12)),
                      'ul': Style(margin: Margins.only(bottom: 12)),
                      'ol': Style(margin: Margins.only(bottom: 12)),
                    },
                  ),
                ),
    );
  }
}
