import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://darasahuru.ac.tz/wp-json/wp/v2';

  // Simple cache for API responses
  static final Map<String, dynamic> _cache = {};
  static final Map<String, DateTime> _cacheTime = {};
  static const Duration _ttl = Duration(minutes: 3);

  // Shared HTTP client
  static final http.Client _client = http.Client();

  static Future<dynamic> _getJson(String url, {bool useCache = true}) async {
    try {
      if (useCache && _cache.containsKey(url)) {
        final t = _cacheTime[url];
        if (t != null && DateTime.now().difference(t) < _ttl) {
          return _cache[url];
        }
      }
      final uri = Uri.parse(url);
      final resp = await _client.get(
        uri,
        headers: const {
          'Accept': 'application/json',
          'Accept-Encoding': 'gzip',
          'Connection': 'keep-alive',
          'User-Agent': 'DarasaHuruApp/1.0 (+flutter)'
        },
      );
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (useCache) {
          _cache[url] = data;
          _cacheTime[url] = DateTime.now();
        }
        return data;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Fetch a page by slug with caching
  static Future<String?> fetchPageContent(String slug) async {
    final url = '$baseUrl/pages?slug=$slug';
    final pages = await _getJson(url) as List<dynamic>?;
    if (pages != null && pages.isNotEmpty) {
      return pages[0]['content']?['rendered'] as String?;
    }
    return null;
  }

  /// Fetch all pages with caching
  static Future<List<dynamic>?> fetchPages() async {
    final url = '$baseUrl/pages';
    final pages = await _getJson(url) as List<dynamic>?;
    return pages;
  }

  /// Load category data with caching
  static Future<Map<String, dynamic>> loadCategoryForUI(int id) async {
    final cacheKey = 'category_$id';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }
    try {
      // First, fetch subcategories
      final subcats = await _getJson('$baseUrl/categories?parent=$id&per_page=100') as List<dynamic>?;
      if (subcats != null) {
        print('Parsed subcategories: ${subcats.length} items');
        if (subcats.isNotEmpty) {
          final result = {'type': 'subcats', 'data': subcats};
          _cache[cacheKey] = result;
          return result;
        } else {
          print('No subcategories found for ID: $id');
          // If no subcategories, fetch posts
          final posts = await _getJson('$baseUrl/posts?categories=$id&per_page=30&_embed=1') as List<dynamic>?;
          if (posts != null) {
            print('Parsed posts: ${posts.length} items');
            final result = {'type': 'posts', 'data': posts};
            _cache[cacheKey] = result;
            // Prefetch next page in background (warm cache)
            // ignore: unawaited_futures
            _getJson('$baseUrl/posts?categories=$id&per_page=30&page=2&_embed=1');
            return result;
          } else {
            return {'type': 'error', 'message': 'Failed to load posts'};
          }
        }
      } else {
        return {'type': 'error', 'message': 'Failed to load subcategories'};
      }
    } catch (e) {
      print('Exception in loadCategoryForUI: $e');
      return {'type': 'error', 'message': 'Error: $e'};
    }
  }

  /// Clear cache if needed (e.g., for refresh)
  static void clearCache() {
    _cache.clear();
  }
}
