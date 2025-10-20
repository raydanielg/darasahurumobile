import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../api/api_service.dart';
import '../apage_detail_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
        builder: (context, constraints) {
          final bool isWide = constraints.maxWidth >= 800;
          final double maxContentWidth = isWide ? 720 : double.infinity;
          final double horizontal = isWide ? 24 : 16;
          final bottomInset = MediaQuery.of(context).padding.bottom;
          final double avatarSize = isWide ? 72 : 56;

          return SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 16 + bottomInset),
                  children: [
          const SizedBox(height: 8),

          // Branded Header with logo
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/icon.png',
                      width: avatarSize,
                      height: avatarSize,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Darasa Huru',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Learn easily – past papers, notes and resources.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Social Media
          Text(
            'Social Media',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),

          _buildSettingItem(
            context,
            icon: Icons.chat,
            title: 'WhatsApp',
            subtitle: 'Join us on WhatsApp',
            onTap: () => _openWhatsAppChannel(),
          ),

          _buildSettingItem(
            context,
            icon: Icons.facebook,
            title: 'Facebook',
            subtitle: 'Like us on Facebook',
            onTap: () => _openFacebook(),
          ),

          _buildSettingItem(
            context,
            icon: Icons.music_note,
            title: 'TikTok',
            subtitle: 'Follow us on TikTok',
            onTap: () => _openTikTok(),
          ),

          _buildSettingItem(
            context,
            icon: Icons.alternate_email,
            title: 'Twitter (X)',
            subtitle: 'Follow us on X',
            onTap: () => _openTwitter(),
          ),

          _buildSettingItem(
            context,
            icon: Icons.ondemand_video,
            title: 'YouTube',
            subtitle: 'Watch our videos',
            onTap: () => _openYouTube(),
          ),

          _buildSettingItem(
            context,
            icon: Icons.camera_alt_outlined,
            title: 'Instagram',
            subtitle: 'Follow us on Instagram',
            onTap: () => _openInstagram(),
          ),

          const SizedBox(height: 24),

          // Contact section
          Text(
            'Contact',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),

          _buildSettingItem(
            context,
            icon: Icons.email_outlined,
            title: 'Email',
            subtitle: 'darasahuru@gmail.com',
            onTap: () => _sendEmail(context, 'darasahuru@gmail.com'),
          ),

          const SizedBox(height: 24),

          // App Info
          Text(
            'About App',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),

          _buildSettingItem(
            context,
            icon: Icons.star_rate_rounded,
            title: 'Rate this App',
            subtitle: 'Rate us on the Store',
            onTap: () => _rateApp(context),
          ),

          _buildSettingItem(
            context,
            icon: Icons.info,
            title: 'About Us',
            subtitle: 'Learn about Darasa Huru',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PageDetailScreen(
                    title: 'About Us',
                    slug: 'about-us-for-darasa-huru',
                  ),
                ),
              );
            },
          ),

          _buildSettingItem(
            context,
            icon: Icons.privacy_tip,
            title: 'Privacy Policy',
            subtitle: 'Read our privacy policy',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PageDetailScreen(
                    title: 'Privacy Policy',
                    slug: 'privacy-policy-for-darasa-huru',
                  ),
                ),
              );
            },
          ),

          _buildSettingItem(
            context,
            icon: Icons.miscellaneous_services,
            title: 'Our Services',
            subtitle: 'See the services we provide',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PageDetailScreen(
                    title: 'Our Services',
                    slug: 'our-services',
                  ),
                ),
              );
            },
          ),

          _buildSettingItem(
            context,
            icon: Icons.share,
            title: 'Share App',
            subtitle: 'Tell your friends',
            onTap: () => _shareApp(context),
          ),

          const SizedBox(height: 24),

          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 4),
            child: Center(
              child: Text(
                '© Darasa Huru • Developed by Darasa Huru Team',
                style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          );
        },
      );
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot open link. Please try again later.')),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error while opening link.')),
      );
    }
  }

  Future<void> _sendEmail(BuildContext context, String email) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Contact via Email', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.email_outlined),
                  const SizedBox(width: 8),
                  Expanded(child: Text(email, style: const TextStyle(fontWeight: FontWeight.w600))),
                  TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: email));
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Email copied to clipboard')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Send an email to this address without leaving the app.'),
            ],
          ),
        );
      },
    );
  }

  Future<void> _rateApp(BuildContext context) async {
    const url = 'https://play.google.com/store/search?q=Darasa+Huru&c=apps';
    await _openUrl(context, url);
  }

  Future<void> _shareApp(BuildContext context) async {
    const url = 'https://darasahuru.ac.tz/';
    await Share.share('Check out Darasa Huru app: $url');
  }

  // Preferred native-app opening with web fallback
  Future<void> _openPreferred(Uri nativeUri, Uri webUri) async {
    try {
      if (await canLaunchUrl(nativeUri)) {
        final ok = await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
        if (ok) return;
      }
    } catch (_) {
      // ignore and fallback to web
    }
    await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openWhatsAppChannel() async {
    // WhatsApp may not support deep linking to channels directly; open app generically then fallback to channel web URL
    final native = Uri.parse('whatsapp://open');
    final web = Uri.parse('https://www.whatsapp.com/channel/0029Va7ql6j17EmnCjamz53U');
    await _openPreferred(native, web);
  }

  Future<void> _openFacebook() async {
    final web = Uri.parse('https://www.facebook.com/darasahuru');
    final native = Uri.parse('fb://facewebmodal/f?href=${Uri.encodeComponent(web.toString())}');
    await _openPreferred(native, web);
  }

  Future<void> _openTwitter() async {
    final web = Uri.parse('https://twitter.com/darasahuru');
    final native = Uri.parse('twitter://user?screen_name=darasahuru');
    await _openPreferred(native, web);
  }

  Future<void> _openInstagram() async {
    final web = Uri.parse('https://www.instagram.com/darasahuru');
    final native = Uri.parse('instagram://user?username=darasahuru');
    await _openPreferred(native, web);
  }

  Future<void> _openTikTok() async {
    final web = Uri.parse('https://www.tiktok.com/@darasahuru');
    final native = Uri.parse('tiktok://user/@darasahuru');
    await _openPreferred(native, web);
  }

  Future<void> _openYouTube() async {
    final web = Uri.parse('https://youtube.com/@darasahuru');
    final native = Uri.parse('vnd.youtube://www.youtube.com/@darasahuru');
    await _openPreferred(native, web);
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    Widget? trailing,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: primary.withOpacity(0.12),
          child: Icon(icon, color: primary),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(subtitle),
        trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  String _getThemeText(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? 'Dark' : 'Light';
  }
}
