import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:html/dom.dart' as dom;
import 'dart:math';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:html_unescape/html_unescape.dart';
import 'widgets/loading_indicator.dart';
import 'news_posts_list_screen.dart';

class PostDetailScreen extends StatefulWidget {
  final String title;
  final String htmlContent;
  final int? categoryId;
  final String? postUrl;

  const PostDetailScreen({
    super.key,
    required this.title,
    required this.htmlContent,
    this.categoryId,
    this.postUrl,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  List<dynamic> _recommendedPosts = [];
  bool _isLoadingRecommendations = true;
  bool _useWebView = true; // Default to WebView for full web preview experience
  late WebViewController _webViewController;
  bool _isWebViewLoading = true;
  String? _webViewError;
  double _textScale = 1.0;

  @override
  void initState() {
    super.initState();
    _fetchRecommendedPosts();
    if (_useWebView) {
      _webViewController = _createWebViewController();
    }
  }

  bool _isDocumentLink(Uri uri) {
    try {
      final path = uri.path.toLowerCase();
      final host = uri.host.toLowerCase();
      if (path.endsWith('.pdf') ||
          path.endsWith('.doc') ||
          path.endsWith('.docx') ||
          path.endsWith('.ppt') ||
          path.endsWith('.pptx') ||
          path.endsWith('.xls') ||
          path.endsWith('.xlsx')) {
        return true;
      }
      if (host.contains('drive.google.com') || host.contains('docs.google.com') || host.contains('dropbox.com')) {
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  String _fileNameFromUri(Uri uri) {
    try {
      final segs = uri.pathSegments;
      if (segs.isNotEmpty) return segs.last;
    } catch (_) {}
    return uri.toString();
  }

  Future<bool> _openInternalPostById(int id) async {
    try {
      final postResp = await http.get(
        Uri.parse('https://darasahuru.ac.tz/wp-json/wp/v2/posts/$id?_embed=1'),
      );
      if (postResp.statusCode == 200) {
        final item = json.decode(postResp.body);
        final rawTitle = item['title']?['rendered'] ?? 'Post';
        final title = HtmlUnescape().convert(rawTitle);
        final content = item['content']?['rendered'] ?? '';
        final catId = (item['categories'] is List && (item['categories'] as List).isNotEmpty)
            ? (item['categories'][0] as int)
            : null;
        final link = item['link'] as String?;
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PostDetailScreen(
                title: title,
                htmlContent: content,
                categoryId: catId,
                postUrl: link,
              ),
            ),
          );
        }
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _fetchRecommendedPosts() async {
    if (widget.categoryId == null) {
      setState(() {
        _isLoadingRecommendations = false;
      });
      // Ensure WebView reflects state (no related)
      if (_useWebView) {
        try { _webViewController.loadHtmlString(_prepareHtmlForWebView(widget.htmlContent)); } catch (_) {}
      }
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('https://darasahuru.ac.tz/wp-json/wp/v2/posts?categories=${widget.categoryId}&per_page=5&_embed=1'),
      );
      if (response.statusCode == 200) {
        setState(() {
          _recommendedPosts = json.decode(response.body);
          _isLoadingRecommendations = false;
        });
        if (_useWebView) {
          try { _webViewController.loadHtmlString(_prepareHtmlForWebView(widget.htmlContent)); } catch (_) {}
        }
      } else {
        setState(() {
          _isLoadingRecommendations = false;
        });
        if (_useWebView) {
          try { _webViewController.loadHtmlString(_prepareHtmlForWebView(widget.htmlContent)); } catch (_) {}
        }
      }
    } catch (e) {
      setState(() {
        _isLoadingRecommendations = false;
      });
      if (_useWebView) {
        try { _webViewController.loadHtmlString(_prepareHtmlForWebView(widget.htmlContent)); } catch (_) {}
      }
    }
  }

  WebViewController _createWebViewController() {
    final htmlContent = _prepareHtmlForWebView(widget.htmlContent);
    final webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isWebViewLoading = true;
              _webViewError = null;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isWebViewLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            final isMainFrame = error.isForMainFrame ?? true;
            if (isMainFrame) {
              final desc = error.description.toLowerCase();
              String message;
              if (desc.contains('err_socket_not_connected') ||
                  desc.contains('err_internet_disconnected') ||
                  desc.contains('err_name_not_resolved') ||
                  desc.contains('host lookup')) {
                message = 'Please turn on the internet and try again.';
              } else {
                message = 'Failed to load content.';
              }
              setState(() {
                _isWebViewLoading = false;
                _webViewError = message;
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            final uri = Uri.tryParse(request.url);
            if (uri != null && _isPdfOrDrive(uri)) {
              // Open PDFs/Drive externally
              _openExternal(uri);
              return NavigationDecision.prevent;
            }
            if (request.url.contains('darasahuru.ac.tz')) {
              _handleInternalLink(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadHtmlString(htmlContent);

    return webViewController;
  }

  Widget _wrapWithBackground(Widget child) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/bgone.jpg'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.72),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }

  Widget _buildWebViewContent() {
    return _isWebViewLoading
      ? const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PulsingRingsLoader(color: Colors.red),
              SizedBox(height: 16),
              Text('Loading content...'),
            ],
          ),
        )
      : _webViewError != null
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_webViewError!),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _webViewController = _createWebViewController();
                    });
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          )
        : WebViewWidget(
            controller: _webViewController,
          );
  }

  Widget _buildFlutterHtmlContent() {
    return Html(
      data: _prepareHtmlForImages(_transformMediaEmbeds(widget.htmlContent)),
      onLinkTap: (String? url, Map<String, String> attributes, dom.Element? element) {
        if (url != null) {
          // Check if this is an image link (starts with #image:)
          if (url.startsWith('#image:')) {
            final imageUrl = url.substring(7); // Remove '#image:' prefix
            _showImageDialog(imageUrl, attributes?['alt'] ?? '');
          } else {
            _handleLinkTap(url);
          }
        }
      },
      style: {
        'body': Style(
          margin: Margins.all(0),
          padding: HtmlPaddings.all(0),
          fontSize: FontSize(16.0),
          lineHeight: LineHeight(1.6),
        ),
        'h1, h2, h3, h4, h5, h6': Style(
          margin: Margins.only(top: 16.0, bottom: 8.0),
          fontWeight: FontWeight.bold,
        ),
        'h1': Style(color: Colors.red.shade700),
        'h2': Style(color: Colors.blue.shade700),
        'h3': Style(color: Colors.green.shade700),
        'p': Style(
          margin: Margins.only(bottom: 12.0),
        ),
        'a': Style(
          color: Colors.blue,
          textDecoration: TextDecoration.underline,
        ),
        'img': Style(
          width: Width(100, Unit.percent),
          height: Height.auto(),
          margin: Margins.symmetric(vertical: 8.0),
        ),
      },
      extensions: [
        TagExtension(tagsToExtend: {"img"}, builder: (context) {
          final attrs = context.attributes;
          String src = attrs["src"] ?? "";
          final alt = attrs["alt"] ?? "";
          // Fallbacks for lazy-loaded images
          if (src.isEmpty) {
            src = attrs["data-src"] ?? attrs["data-original"] ?? attrs["data-lazy-src"] ?? "";
          }
          // Fallback for srcset/data-srcset (pick first)
          String srcset = attrs["srcset"] ?? attrs["data-srcset"] ?? "";
          // Normalize base URL early
          src = _normalizeImageUrl(src);

          // If we still don't have a source, render nothing to avoid flicker
          if (src.isEmpty) {
            return const SizedBox.shrink();
          }

          return LayoutBuilder(builder: (ctx, constraints) {
            final maxWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : double.infinity;
            final dpr = MediaQuery.of(ctx).devicePixelRatio;
            final targetCacheWidth = maxWidth.isFinite && maxWidth > 0 ? (maxWidth * dpr).round() : null;

            // If srcset is available, pick the best candidate near our target width
            if (srcset.isNotEmpty) {
              final picked = _pickBestFromSrcset(srcset, targetCacheWidth);
              if (picked != null && picked.isNotEmpty) {
                src = _normalizeImageUrl(picked);
              }
            }

            if (src.toLowerCase().endsWith('.webp')) {
              return SizedBox(
                width: maxWidth.isFinite ? maxWidth : null,
                child: _WebPImageWidget(imageUrl: src, alt: alt),
              );
            }

            return SizedBox(
              width: maxWidth.isFinite ? maxWidth : null,
              child: CachedNetworkImage(
                key: ValueKey(src),
                imageUrl: src,
                fit: BoxFit.fitWidth,
                memCacheWidth: targetCacheWidth,
                alignment: Alignment.topLeft,
                fadeInDuration: const Duration(milliseconds: 0),
                fadeOutDuration: const Duration(milliseconds: 0),
                useOldImageOnUrlChange: true,
                placeholder: (context, url) => Container(
                  height: 200,
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(),
                ),
                errorWidget: (context, url, error) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.broken_image),
                    if (alt.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          alt,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            );
          });
        }),
        TagExtension(tagsToExtend: {"a"}, builder: (context) {
          final attrs = context.attributes;
          final href = attrs["href"] ?? "";
          if (href.isEmpty) return const SizedBox.shrink();
          final norm = _normalizeImageUrl(href);
          final uri = Uri.tryParse(norm);
          if (uri != null && _isDocumentLink(uri)) {
            final name = _fileNameFromUri(uri);
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                leading: const Icon(Icons.insert_drive_file),
                title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(uri.host, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: ElevatedButton(
                  onPressed: () => _openExternal(uri),
                  child: const Text('Open'),
                ),
                onTap: () => _openExternal(uri),
              ),
            );
          }
          return const SizedBox.shrink();
        }),
      ],
    );
  }

  String _prepareHtmlForWebView(String html) {
    final transformed = _transformMediaEmbeds(html);
    final relatedSection = _buildRelatedHtml();
    return '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          :root { --dh-scale: 1; }
          body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            color: #333;
            padding: 16px;
            margin: 0;
            font-size: calc(16px * var(--dh-scale));
            background: transparent;
          }
          h1, h2, h3, h4, h5, h6 {
            margin-top: 24px;
            margin-bottom: 12px;
            font-weight: 600;
          }
          h1 { color: #c62828; }
          h2 { color: #1565c0; }
          h3 { color: #2e7d32; }
          p {
            margin-bottom: 16px;
          }
          a {
            color: #007bff;
            text-decoration: none;
          }
          a:hover {
            text-decoration: underline;
          }
          img {
            max-width: 100%;
            height: auto;
            display: block;
            margin: 16px 0;
            border-radius: 8px;
          }
          .video-wrapper { position: relative; width: 100%; max-width: 100%; }
          .video-wrapper::before { content: ""; display: block; padding-top: 56.25%; }
          .video-wrapper > iframe {
            position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: 0; border-radius: 8px;
          }
          iframe { max-width: 100%; border: 0; }
          .content-wrapper {
            max-width: 100%;
          }
          .related { margin-top: 16px; }
          .related h2 { margin: 0 0 8px 0; font-size: 1em; }
          .rel-card { display: flex; gap: 8px; align-items: center; padding: 8px; border: 1px solid #eee; border-radius: 8px; text-decoration: none; color: inherit; margin-bottom: 8px; }
          .rel-card:hover { background: #fafafa; }
          .rel-card img { width: 56px; height: 56px; object-fit: cover; border-radius: 8px; flex-shrink: 0; }
          .rel-card .rel-title { font-weight: 600; font-size: .95em; }
          .rel-card .rel-time { color: #888; font-size: .85em; margin-top: 2px; }
        </style>
      </head>
      <body>
        <div class="content-wrapper">
          ${transformed}
          ${relatedSection}
        </div>
      </body>
      </html>
    ''';
  }

  String _buildRelatedHtml() {
    try {
      if (_recommendedPosts.isEmpty) return '';
      final buf = StringBuffer();
      buf.writeln('<div class="related">');
      buf.writeln('<h2>Related Posts</h2>');
      final limit = _recommendedPosts.length < 4 ? _recommendedPosts.length : 4;
      for (int i = 0; i < limit; i++) {
        final post = _recommendedPosts[i];
        final rawTitle = post['title']?['rendered'] ?? 'Post';
        final title = HtmlUnescape().convert(rawTitle);
        final link = (post['link'] is String) ? post['link'] as String : '#';
        final img = _getFeaturedImage(post);
        final time = _getPostTime(post);
        final imgTag = (img != null && img.isNotEmpty) ? '<img src="$img" alt="" />' : '';
        buf.writeln('<a class="rel-card" href="$link">$imgTag<div><div class="rel-title">${_escapeHtml(title)}</div>${time.isNotEmpty ? '<div class="rel-time">${_escapeHtml(time)}</div>' : ''}</div></a>');
      }
      buf.writeln('</div>');
      return buf.toString();
    } catch (_) {
      return '';
    }
  }

  String _escapeHtml(String s) {
    return s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  void _reloadWebView() {
    try {
      _webViewController.reload();
    } catch (_) {}
  }

  Future<void> _openOriginalInBrowser() async {
    try {
      final link = widget.postUrl ?? _extractFirstLink(widget.htmlContent);
      if (link != null) {
        final uri = Uri.tryParse(link);
        if (uri != null) {
          await _openExternal(uri);
          return;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Original link not available.')),
      );
    } catch (_) {}
  }

  void _adjustTextScale(double delta) {
    setState(() {
      _textScale = (_textScale + delta).clamp(0.8, 1.8);
    });
    try {
      _webViewController.runJavaScript("document.documentElement.style.setProperty('--dh-scale', '$_textScale')");
    } catch (_) {}
  }

  String _transformMediaEmbeds(String html) {
    try {
      // Replace plain YouTube links with responsive iframe embeds
      // Matches https://www.youtube.com/watch?v=VIDEO_ID and https://youtu.be/VIDEO_ID
      final ytWatch = RegExp(r'https?:\/\/(?:www\.)?youtube\.com\/watch\?v=([A-Za-z0-9_-]{6,})', caseSensitive: false);
      final youtuBe = RegExp(r'https?:\/\/(?:www\.)?youtu\.be\/([A-Za-z0-9_-]{6,})', caseSensitive: false);

      String withEmbeds = html.replaceAllMapped(ytWatch, (m) {
        final id = m.group(1);
        return '<div class="video-wrapper"><iframe src="https://www.youtube.com/embed/$id" allowfullscreen></iframe></div>';
      });
      withEmbeds = withEmbeds.replaceAllMapped(youtuBe, (m) {
        final id = m.group(1);
        return '<div class="video-wrapper"><iframe src="https://www.youtube.com/embed/$id" allowfullscreen></iframe></div>';
      });

      // If there are existing iframes, ensure they are wrapped for responsiveness
      final iframeTag = RegExp("<iframe[^>]*src=[\"']([^\"']+)[\"'][^>]*><\\/iframe>", caseSensitive: false);
      withEmbeds = withEmbeds.replaceAllMapped(iframeTag, (m) {
        final tag = m.group(0) ?? '';
        if (tag.contains('video-wrapper')) return tag;
        return '<div class="video-wrapper">$tag</div>';
      });

      return withEmbeds;
    } catch (_) {
      return html;
    }
  }

  void _handleInternalLink(String url) async {
    try {
      Uri uri = Uri.parse(url);
      if (uri.host.contains('darasahuru.ac.tz')) {
        // Check if it's a category link
        if (_isCategoryLink(uri)) {
          final categorySlug = _extractCategorySlugFromUri(uri);
          if (categorySlug.isNotEmpty) {
            await _openCategoryBySlug(categorySlug);
            return;
          }
        }
        
        // Check if it's a post with ID
        final p = uri.queryParameters['p'];
        if (p != null) {
          final id = int.tryParse(p);
          if (id != null) {
            await _openInternalPostById(id);
            return;
          }
        }
        
        // Try to open as post by slug
        final slug = _extractSlugFromUri(uri);
        if (slug.isNotEmpty) {
          await _openInternalPostBySlug(slug);
        }
      }
    } catch (_) {
      // Ignore errors for internal link handling
    }
  }

  String _extractSlugFromUri(Uri uri) {
    try {
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isEmpty) return '';
      String slug = segments.last;
      slug = slug.replaceAll('/', '');
      return slug;
    } catch (_) {
      return '';
    }
  }

  Future<bool> _openInternalPostBySlug(String slug) async {
    try {
      final postResp = await http.get(
        Uri.parse('https://darasahuru.ac.tz/wp-json/wp/v2/posts?slug=$slug&_embed=1'),
      );
      if (postResp.statusCode == 200) {
        final List<dynamic> items = json.decode(postResp.body);
        if (items.isNotEmpty) {
          final item = items[0];
          final rawTitle = item['title']?['rendered'] ?? 'Post';
          final title = HtmlUnescape().convert(rawTitle);
          final content = item['content']?['rendered'] ?? '';
          final catId = (item['categories'] is List && (item['categories'] as List).isNotEmpty)
              ? (item['categories'][0] as int)
              : null;
          final link = item['link'] as String?;
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PostDetailScreen(
                  title: title,
                  htmlContent: content,
                  categoryId: catId,
                  postUrl: link,
                ),
              ),
            );
          }
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  bool _isCategoryLink(Uri uri) {
    try {
      if (uri.host.contains('darasahuru.ac.tz')) {
        final path = uri.path.toLowerCase();
        return path.contains('/category/');
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  String _extractCategorySlugFromUri(Uri uri) {
    try {
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isEmpty) return '';
      
      // Find the index of 'category' in the segments
      final catIndex = segments.indexOf('category');
      if (catIndex >= 0 && catIndex < segments.length - 1) {
        // Return the last segment after 'category' (could be parent/child structure)
        return segments.last;
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  Future<bool> _openCategoryBySlug(String slug) async {
    try {
      final catResp = await http.get(
        Uri.parse('https://darasahuru.ac.tz/wp-json/wp/v2/categories?slug=$slug'),
      );
      if (catResp.statusCode == 200) {
        final List<dynamic> items = json.decode(catResp.body);
        if (items.isNotEmpty) {
          final item = items[0];
          final rawName = item['name'] ?? 'Category';
          final categoryName = HtmlUnescape().convert(rawName);
          final categoryId = item['id'] as int;
          
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NewsPostsListScreen(
                  title: categoryName,
                  categoryId: categoryId,
                  slug: slug,
                ),
              ),
            );
          }
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  void _handleLinkTap(String url) async {
    try {
      Uri uri = Uri.parse(url);
      if (uri.scheme == 'tel' || uri.scheme == 'mailto') {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      }
      if (!uri.hasScheme) {
        uri = Uri.parse('https://darasahuru.ac.tz').resolveUri(uri);
      }

      // PDFs and Google Drive links: open externally
      if (_isPdfOrDrive(uri)) {
        await _openExternal(uri);
        return;
      }

      if (uri.host.contains('darasahuru.ac.tz')) {
        // Check if it's a category link
        if (_isCategoryLink(uri)) {
          final categorySlug = _extractCategorySlugFromUri(uri);
          if (categorySlug.isNotEmpty) {
            final opened = await _openCategoryBySlug(categorySlug);
            if (opened) return;
          }
        }
        
        // Check if it's a post with ID
        final p = uri.queryParameters['p'];
        if (p != null) {
          final id = int.tryParse(p);
          if (id != null) {
            await _openInternalPostById(id);
            return;
          }
        }
        
        // Try to open as post by slug
        final slug = _extractSlugFromUri(uri);
        if (slug.isNotEmpty) {
          await _openInternalPostBySlug(slug);
          return;
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Content not found for this link.')),
        );
        return;
      }

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid link.')),
      );
    }
  }

  bool _isPdfOrDrive(Uri uri) {
    final path = uri.path.toLowerCase();
    final host = (uri.host).toLowerCase();
    if (path.endsWith('.pdf')) return true;
    if (host.contains('drive.google.com') || host.contains('docs.google.com')) return true;
    if (uri.queryParameters['export'] == 'download' && path.contains('uc')) return true; // drive export links
    return false;
  }

  Future<void> _openExternal(Uri uri) async {
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    try {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot open link.')),
        );
      }
    }
  }

  void _showImageDialog(String imageUrl, String alt) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (alt.isNotEmpty)
                  Text(
                    alt,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                if (alt.isNotEmpty) const SizedBox(height: 8),
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  placeholder: (context, url) => const CircularProgressIndicator(),
                  errorWidget: (context, url, error) => const Icon(Icons.broken_image),
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getPostTime(dynamic post) {
    try {
      final dateStr = post['date'];
      final dateGmtStr = post['date_gmt'];

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

  String _prepareHtmlForImages(String html) {
    try {
      // Wrap images in anchor tags so they can be clicked
      final imgRegex = RegExp(r'<img([^>]+)>', multiLine: true);
      html = html.replaceAllMapped(imgRegex, (match) {
        final imgTag = match.group(0) ?? '';
        final imgAttributes = match.group(1) ?? '';

        // Extract src and alt attributes
        final srcMatch = RegExp(r'''src=["']([^"']+)["']''').firstMatch(imgAttributes);
        final altMatch = RegExp(r'''alt=["']([^"']+)["']''').firstMatch(imgAttributes);

        final src = _normalizeImageUrl(srcMatch?.group(1) ?? '');
        final alt = altMatch?.group(1) ?? '';

        if (src.isNotEmpty) {
          return '<a href="#image:$src" alt="$alt">$imgTag</a>';
        }
        return imgTag;
      });

      return html;
    } catch (_) {
      return html;
    }
  }

  // Choose best candidate from srcset string near a target width (in px)
  String? _pickBestFromSrcset(String srcset, int? targetPx) {
    try {
      final parts = srcset.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      if (parts.isEmpty) return null;
      if (targetPx == null) {
        // pick the last (usually largest)
        final last = parts.last.split(' ').first;
        return last;
      }
      // Parse descriptors like "url 300w"
      int bestDiff = 1 << 30;
      String? bestUrl;
      for (final p in parts) {
        final segs = p.split(RegExp(r'\s+'));
        if (segs.isEmpty) continue;
        final url = segs[0];
        int? width;
        if (segs.length > 1 && segs[1].endsWith('w')) {
          width = int.tryParse(segs[1].substring(0, segs[1].length - 1));
        }
        width ??= int.tryParse(RegExp(r'(\d+)').firstMatch(p)?.group(1) ?? '');
        if (width != null) {
          final diff = (width - targetPx).abs();
          if (diff < bestDiff) {
            bestDiff = diff;
            bestUrl = url;
          }
        } else {
          bestUrl ??= url; // fallback
        }
      }
      return bestUrl ?? parts.last.split(' ').first;
    } catch (_) {
      return null;
    }
  }

  // Normalize image URLs: handle relative paths and protocol-relative
  String _normalizeImageUrl(String src) {
    try {
      if (src.isEmpty) return src;
      String s = src.trim();
      if (s.startsWith('//')) {
        s = 'https:' + s;
      } else if (s.startsWith('/')) {
        s = Uri.parse('https://darasahuru.ac.tz').resolve(s).toString();
      } else if (!s.startsWith('http')) {
        // Some themes may emit relative paths without leading slash
        s = Uri.parse('https://darasahuru.ac.tz').resolve('/' + s).toString();
      }
      return s;
    } catch (_) {
      return src;
    }
  }

  void _sharePost() async {
    try {
      final String link = widget.postUrl ?? _extractFirstLink(widget.htmlContent) ?? 'https://darasahuru.ac.tz';
      final String shareText = '${widget.title}\n\n$link';

      // Use the share_plus package if available, otherwise fall back to url_launcher
      try {
        // Try to use share_plus for native sharing
        await Share.share(shareText, subject: widget.title);
      } catch (e) {
        // Fallback: try opening share sheet via URL if needed
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sharing not available on this device.')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to share post')),
      );
    }
  }

  String? _extractFirstLink(String html) {
    try {
      final reg = RegExp(r'''href=["']([^"']+)["']''', caseSensitive: false);
      final m = reg.firstMatch(html);
      if (m != null) {
        final href = m.group(1);
        if (href != null && href.isNotEmpty) {
          return href;
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    try {
      if (_useWebView) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            elevation: 0,
            actions: [
              IconButton(
                tooltip: 'Smaller text',
                icon: const Icon(Icons.text_decrease),
                onPressed: () => _adjustTextScale(-0.1),
              ),
              IconButton(
                tooltip: 'Larger text',
                icon: const Icon(Icons.text_increase),
                onPressed: () => _adjustTextScale(0.1),
              ),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
                onPressed: _reloadWebView,
              ),
            ],
          ),
          body: _wrapWithBackground(_buildWebViewContent()),
        );
      }

      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          elevation: 0,
          actions: const [],
        ),
        body: _wrapWithBackground(
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Full-width content without margins/decoration
                _buildFlutterHtmlContent(),

                // Recommended posts
                if (_recommendedPosts.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Text(
                      'Recommended Posts',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: min(_recommendedPosts.length, 4),
                      itemBuilder: (context, index) {
                        final post = _recommendedPosts[index];
                        final rawTitle = post['title']?['rendered'] ?? 'No Title';
                        final title = HtmlUnescape().convert(rawTitle);
                        final imgUrl = _getFeaturedImage(post);
                        final time = _getPostTime(post);
                        final catId = (post['categories'] is List && (post['categories'] as List).isNotEmpty)
                            ? (post['categories'][0] as int)
                            : null;
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: imgUrl != null
                                  ? Image.network(
                                      imgUrl,
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 60,
                                        height: 60,
                                        color: Colors.grey.shade200,
                                        child: const Icon(Icons.image, color: Colors.grey),
                                      ),
                                    )
                                  : Container(
                                      width: 60,
                                      height: 60,
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
                            subtitle: time.isNotEmpty
                                ? Text(
                                    time,
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  )
                                : null,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PostDetailScreen(
                                    title: title,
                                    htmlContent: post['content']?['rendered'] ?? '',
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
                ] else if (_isLoadingRecommendations) ...[
                  Container(
                    margin: const EdgeInsets.all(16.0),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
        ),
        body: Center(
          child: Text('An error occurred: $e'),
        ),
      );
    }
  }
}

class _WebPImageWidget extends StatefulWidget {
  final String imageUrl;
  final String alt;

  const _WebPImageWidget({
    required this.imageUrl,
    required this.alt,
  });

  @override
  State<_WebPImageWidget> createState() => _WebPImageWidgetState();
}

class _WebPImageWidgetState extends State<_WebPImageWidget> {
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'Image failed to load',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            if (widget.alt.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  widget.alt,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final maxWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : MediaQuery.of(ctx).size.width;
        final dpr = MediaQuery.of(ctx).devicePixelRatio;
        final targetCacheWidth = (maxWidth.isFinite && maxWidth > 0) ? (maxWidth * dpr).round() : null;
        final key = ValueKey('${widget.imageUrl}@$targetCacheWidth');

        return CachedNetworkImage(
          key: key,
          imageUrl: widget.imageUrl,
          fit: BoxFit.fitWidth,
          memCacheWidth: targetCacheWidth,
          alignment: Alignment.topLeft,
          fadeInDuration: const Duration(milliseconds: 0),
          fadeOutDuration: const Duration(milliseconds: 0),
          useOldImageOnUrlChange: true,
          httpHeaders: const {
            'Accept': 'image/webp,image/*,*/*;q=0.8',
          },
          placeholder: (context, url) => Container(
            height: 200,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(),
          ),
          errorWidget: (context, url, error) {
            // If it's a WEBP image and failed to load, try alternative handling
            if (widget.imageUrl.toLowerCase().contains('.webp')) {
              return _buildWebPFallback();
            }
            return _buildErrorWidget();
          },
          imageBuilder: (context, imageProvider) => Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: imageProvider,
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWebPFallback() {
    // For WEBP images that fail to load, we'll show a placeholder with options
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            'WEBP Image',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Preview not available',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => _openImageInBrowser(widget.imageUrl),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade100,
              foregroundColor: Colors.blue.shade800,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            child: const Text('View Image'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            'Image failed to load',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          if (widget.alt.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                widget.alt,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  void _openImageInBrowser(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot open image')),
      );
    }
  }
}
