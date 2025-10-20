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
  bool _useWebView = false; // Use flutter_html by default to avoid clipping
  late WebViewController _webViewController;
  bool _isWebViewLoading = true;
  String? _webViewError;

  @override
  void initState() {
    super.initState();
    _fetchRecommendedPosts();
    if (_useWebView) {
      _webViewController = _createWebViewController();
    }
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
      } else {
        setState(() {
          _isLoadingRecommendations = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingRecommendations = false;
      });
    }
  }

  WebViewController _createWebViewController() {
    final htmlContent = _prepareHtmlForWebView(widget.htmlContent);
    final webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
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
            setState(() {
              _isWebViewLoading = false;
              _webViewError = 'Failed to load content: ${error.description}';
            });
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

  Widget _buildWebViewContent() {
    return _isWebViewLoading
      ? const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
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
          if (src.isEmpty && srcset.isNotEmpty) {
            final set = srcset.split(",");
            if (set.isNotEmpty) {
              src = set.first.trim().split(" ").first;
            }
          }

          // If we still don't have a source, render nothing to avoid flicker
          if (src.isEmpty) {
            return const SizedBox.shrink();
          }

          return LayoutBuilder(builder: (ctx, constraints) {
            final maxWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : double.infinity;
            final dpr = MediaQuery.of(ctx).devicePixelRatio;
            final targetCacheWidth = maxWidth.isFinite && maxWidth > 0 ? (maxWidth * dpr).round() : null;

            if (src.toLowerCase().endsWith('.webp')) {
              return SizedBox(
                width: maxWidth.isFinite ? maxWidth : null,
                child: _WebPImageWidget(imageUrl: src, alt: alt),
              );
            }

            return SizedBox(
              width: maxWidth.isFinite ? maxWidth : null,
              child: CachedNetworkImage(
                imageUrl: src,
                fit: BoxFit.fitWidth,
                memCacheWidth: targetCacheWidth,
                alignment: Alignment.topLeft,
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
      ],
    );
  }

  String _prepareHtmlForWebView(String html) {
    final transformed = _transformMediaEmbeds(html);
    return '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            color: #333;
            padding: 16px;
            margin: 0;
          }
          h1, h2, h3, h4, h5, h6 {
            margin-top: 24px;
            margin-bottom: 12px;
            font-weight: 600;
          }
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
        </style>
      </head>
      <body>
        <div class="content-wrapper">
          ${transformed}
        </div>
      </body>
      </html>
    ''';
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
        final p = uri.queryParameters['p'];
        if (p != null) {
          final id = int.tryParse(p);
          if (id != null) {
            await _openInternalPostById(id);
          }
        }
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
        final p = uri.queryParameters['p'];
        if (p != null) {
          final id = int.tryParse(p);
          if (id != null) {
            await _openInternalPostById(id);
            return;
          }
        }
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

        final src = srcMatch?.group(1) ?? '';
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
            actions: const [],
          ),
          body: Container(
            margin: const EdgeInsets.all(16.0),
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: _buildWebViewContent(),
          ),
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
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Content section in a card (grows with content)
              Container(
                margin: const EdgeInsets.all(16.0),
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: _buildFlutterHtmlContent(),
              ),

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

    return CachedNetworkImage(
      imageUrl: widget.imageUrl,
      placeholder: (context, url) => Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
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
