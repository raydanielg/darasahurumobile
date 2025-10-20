import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://darasahuru.ac.tz/wp-json/wp/v2';

  // Simple cache for API responses
  static final Map<String, dynamic> _cache = {};

  /// Fetch a page by slug with caching
  static Future<String?> fetchPageContent(String slug) async {
    final cacheKey = 'page_$slug';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/pages?slug=$slug'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> pages = json.decode(response.body);
        if (pages.isNotEmpty) {
          final content = pages[0]['content']['rendered'] as String?;
          _cache[cacheKey] = content;
          return content;
        }
      }
      return null;
    } catch (e) {
      print('Error fetching page: $e');
      return null;
    }
  }

  /// Fetch all pages with caching
  static Future<List<dynamic>?> fetchPages() async {
    const cacheKey = 'pages';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/pages'),
      );
      if (response.statusCode == 200) {
        final pages = json.decode(response.body) as List<dynamic>?;
        _cache[cacheKey] = pages;
        return pages;
      }
      return null;
    } catch (e) {
      print('Error fetching pages: $e');
      return null;
    }
  }

  /// Load category data with caching
  static Future<Map<String, dynamic>> loadCategoryForUI(int id) async {
    final cacheKey = 'category_$id';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }
    try {
      // First, fetch subcategories
      final subcatsResponse = await http.get(
        Uri.parse('$baseUrl/categories?parent=$id'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        },
      );
      print('Subcategories API Status: ${subcatsResponse.statusCode}');
      print('Subcategories Response Body: ${subcatsResponse.body}');
      if (subcatsResponse.statusCode == 200) {
        final List<dynamic> subcats = json.decode(subcatsResponse.body);
        print('Parsed subcategories: ${subcats.length} items');
        if (subcats.isNotEmpty) {
          final result = {'type': 'subcats', 'data': subcats};
          _cache[cacheKey] = result;
          return result;
        } else {
          print('No subcategories found for ID: $id');
          // If no subcategories, fetch posts
          final postsResponse = await http.get(
            Uri.parse('$baseUrl/posts?categories=$id&_embed=1'),
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
            },
          );
          print('Posts API Status: ${postsResponse.statusCode}');
          print('Posts Response Body: ${postsResponse.body}');
          if (postsResponse.statusCode == 200) {
            final List<dynamic> posts = json.decode(postsResponse.body);
            print('Parsed posts: ${posts.length} items');
            final result = {'type': 'posts', 'data': posts};
            _cache[cacheKey] = result;
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
