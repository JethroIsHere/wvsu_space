import 'package:flutter/material.dart';

class CommunityGuidelinesScreen extends StatelessWidget {
  const CommunityGuidelinesScreen({super.key});

  Widget _sectionCard({
    required Widget leading,
    required String title,
    required List<String> bullets,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Reserve a fixed width for the leading so titles align consistently
                SizedBox(width: 44, height: 44, child: Center(child: leading)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...bullets.map(
              (b) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '•',
                      style: TextStyle(fontSize: 14, height: 1.4),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        b,
                        style: const TextStyle(fontSize: 14, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Community Guidelines',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 22,
            color: Colors.black87,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  'Welcome to WVSU Space\n\nGuidelines for a safe, supportive environment for all WVSU students.',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),

            _sectionCard(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.shade50,
                child: const Icon(Icons.favorite, color: Colors.blue),
              ),
              title: 'Be Respectful',
              bullets: [
                "Treat all community members with kindness and respect. Remember there's a real person behind every message.",
                'Use inclusive and welcoming language',
                'Respect different opinions and perspectives',
                'Avoid personal attacks or harassment',
              ],
            ),

            const SizedBox(height: 12),

            _sectionCard(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.shade50,
                child: const Icon(Icons.shield_outlined, color: Colors.blue),
              ),
              title: 'Keep it Safe',
              bullets: [
                'Help us maintain a safe environment for all WVSU students to connect and learn.',
                'No sharing of personal information',
                'Report inappropriate behavior immediately',
                "Don't share harmful or explicit content",
              ],
            ),

            const SizedBox(height: 12),

            _sectionCard(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.shade50,
                child: const Icon(Icons.group, color: Colors.blue),
              ),
              title: 'Foster Community',
              bullets: [
                "WVSU Space is about building connections and supporting each other's academic journey.",
                'Help fellow students when possible',
                'Share knowledge and study resources',
                'Encourage positive interactions',
              ],
            ),

            const SizedBox(height: 12),

            _sectionCard(
              leading: CircleAvatar(
                backgroundColor: Colors.red.shade50,
                child: const Icon(Icons.report_problem, color: Colors.red),
              ),
              title: 'Zero Tolerance',
              bullets: [
                'These behaviors will result in immediate action against your account.',
                'Bullying, harassment, or discrimination',
                "Sharing inappropriate or explicit content",
                'Spam or promotional content',
              ],
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
