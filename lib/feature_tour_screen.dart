import 'package:flutter/material.dart';

class FeatureTourScreen extends StatefulWidget {
  final VoidCallback onFinished;
  const FeatureTourScreen({super.key, required this.onFinished});

  @override
  State<FeatureTourScreen> createState() => _FeatureTourScreenState();
}

class _FeatureTourScreenState extends State<FeatureTourScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index < 3) {
      _controller.nextPage(duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
    } else {
      widget.onFinished();
    }
  }

  void _skip() => widget.onFinished();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    const Icon(Icons.tour, size: 20),
                    const SizedBox(width: 6),
                    Text('Quick Tour', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  ]),
                  TextButton(onPressed: _skip, child: const Text('Skip')),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                children: const [
                  _TourPage(
                    title: 'Home',
                    description: 'Browse all the latest posts across categories. Use Load More/Load All to see everything.',
                    icon: Icons.home,
                    color: Colors.indigo,
                  ),
                  _TourPage(
                    title: 'News',
                    description: 'Pick a news subcategory from the top menu and read posts right below.',
                    icon: Icons.article,
                    color: Colors.orange,
                  ),
                  _TourPage(
                    title: 'Notes',
                    description: 'Drill into study-notes categories. See subcategories first, then open notes.',
                    icon: Icons.note_alt,
                    color: Colors.green,
                  ),
                  _TourPage(
                    title: 'Exams',
                    description: 'Find past papers and resources organized for quick practice and revision.',
                    icon: Icons.assignment,
                    color: Colors.pink,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Row(
                children: [
                  Expanded(child: _Dots(count: 4, index: _index)),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _next,
                    icon: Icon(_index == 3 ? Icons.check : Icons.arrow_forward),
                    label: Text(_index == 3 ? 'Start' : 'Next'),
                  ),
                ],
              ),
            )
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

class _TourPage extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  const _TourPage({required this.title, required this.description, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.85, end: 1.0),
              duration: const Duration(milliseconds: 550),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
              child: Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color.withOpacity(0.15), color.withOpacity(0.35)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(icon, size: 68, color: color.withOpacity(0.9)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}
