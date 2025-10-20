import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinished;
  const OnboardingScreen({super.key, required this.onFinished});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _current = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_current < 2) {
      _pageController.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
    } else {
      widget.onFinished();
    }
  }

  void _skip() {
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            // Animated background shapes
            _AnimatedBackground(index: _current),

            // Content
            Column(
              children: [
                // Top actions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(Icons.school, color: theme.colorScheme.primary),
                      TextButton(onPressed: _skip, child: const Text('Skip')),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _current = i),
                    children: const [
                      _OnboardPage(
                        title: 'Discover Notes',
                        subtitle: 'Explore A level, O level, Primary and more in beautifully organized categories.',
                        icon: Icons.menu_book,
                        accent: Colors.blue,
                      ),
                      _OnboardPage(
                        title: 'Stay Updated',
                        subtitle: 'Read the latest news and info with clean, fast loading lists and rich previews.',
                        icon: Icons.article,
                        accent: Colors.purple,
                      ),
                      _OnboardPage(
                        title: 'Ace Your Exams',
                        subtitle: 'Practice with past papers and resources, all in one place.',
                        icon: Icons.workspace_premium,
                        accent: Colors.teal,
                      ),
                    ],
                  ),
                ),
                // Pager + CTA
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Row(
                    children: [
                      Expanded(child: _Dots(count: 3, index: _current)),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _next,
                        icon: Icon(_current == 2 ? Icons.check : Icons.arrow_forward),
                        label: Text(_current == 2 ? 'Get Started' : 'Next'),
                      )
                    ],
                  ),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int index;
  const _Dots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final selected = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 10,
          width: selected ? 26 : 10,
          decoration: BoxDecoration(
            color: selected ? primary : primary.withOpacity(0.25),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

class _OnboardPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  const _OnboardPage({required this.title, required this.subtitle, required this.icon, required this.accent});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated icon container
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.9, end: 1.0),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [accent.withOpacity(0.15), accent.withOpacity(0.35)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(icon, size: 72, color: accent.withOpacity(0.9)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            AnimatedOpacity(
              opacity: 1,
              duration: const Duration(milliseconds: 600),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedBackground extends StatelessWidget {
  final int index;
  const _AnimatedBackground({required this.index});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final secondary = Theme.of(context).colorScheme.secondary;
    final tertiary = Theme.of(context).colorScheme.tertiaryContainer;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      child: Stack(
        children: [
          _Blob(
            color: primary.withOpacity(0.08 + 0.02 * index),
            size: 220 + 10.0 * index,
            alignment: const Alignment(-1.1, -1.1),
            rotate: 0.2 * index,
          ),
          _Blob(
            color: secondary.withOpacity(0.08 + 0.02 * (2 - index)),
            size: 260 - 8.0 * index,
            alignment: const Alignment(1.1, -1.0),
            rotate: -0.15 * index,
          ),
          _Blob(
            color: tertiary.withOpacity(0.08 + 0.03 * (index == 1 ? 1 : 0)),
            size: 280,
            alignment: const Alignment(0.0, 1.2),
            rotate: 0.1,
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double size;
  final Alignment alignment;
  final double rotate;
  const _Blob({required this.color, required this.size, required this.alignment, required this.rotate});

  @override
  Widget build(BuildContext context) {
    return AnimatedAlign(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      alignment: alignment,
      child: Transform.rotate(
        angle: rotate,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(size),
          ),
        ),
      ),
    );
  }
}
