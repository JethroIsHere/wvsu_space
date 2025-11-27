// WVSU Space — `lib/features/auth/terms_and_conditions.dart`
// A simple Terms & Conditions screen that returns true when the user
// accepts. This is presented during sign-up; the sign-up screen uses
// the returned boolean to mark the user as having accepted the terms.
import 'package:flutter/material.dart';

class TermsAndConditionsScreen extends StatefulWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  State<TermsAndConditionsScreen> createState() =>
      _TermsAndConditionsScreenState();
}

class _TermsAndConditionsScreenState extends State<TermsAndConditionsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Please read carefully',
                style: textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'By accepting, you agree to follow the community rules and our policies.',
                style: textTheme.bodySmall?.copyWith(
                    color:
                        colorScheme.onSurface.withAlpha((0.7 * 255).round())),
              ),
              const SizedBox(height: 16),

              // Boxed Terms area
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha((0.04 * 255).round()),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color:
                          colorScheme.onSurface.withAlpha((0.06 * 255).round()),
                    ),
                  ),
                  padding: const EdgeInsets.all(12.0),
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Title inside the boxed area
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              _termsTitle,
                              textAlign: TextAlign.center,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Body text, selectable and justified with bold section headings
                          SelectableText.rich(
                            TextSpan(
                              style:
                                  textTheme.bodyMedium?.copyWith(height: 1.45),
                              children: [
                                const TextSpan(
                                  text:
                                      'These Terms & Conditions explain how WVSU Space works and what we expect from everyone who creates an account.\n\n',
                                ),
                                TextSpan(
                                  text: 'Account and Access\n',
                                  style: textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const TextSpan(
                                  text:
                                      'You must sign up with your WVSU email. Keep your password secure and do not share your account with others. We may suspend or remove accounts that violate these terms.\n\n',
                                ),
                                TextSpan(
                                  text: 'Community Conduct\n',
                                  style: textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const TextSpan(
                                  text:
                                      'Be respectful. Do not post content that is illegal, harassing, hateful, or otherwise violates university policy. Content that breaks these rules may be removed and further steps may be taken against the account.\n\n',
                                ),
                                TextSpan(
                                  text: 'What data we collect\n',
                                  style: textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const TextSpan(
                                  text:
                                      'We collect the information you provide during sign-up (nickname and email), plus basic usage data to improve the service. We do not sell your personal data.\n\n',
                                ),
                                TextSpan(
                                  text: 'Account deletion\n',
                                  style: textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const TextSpan(
                                  text:
                                      'You are free to delete your account at any time from the app settings. For security, the deletion flow may require you to re-authenticate (prove your identity) before the removal is completed.\n\n',
                                ),
                                TextSpan(
                                  text: 'Changes to these terms\n',
                                  style: textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const TextSpan(
                                  text:
                                      'We may update these Terms & Conditions. If the terms change materially we will notify users and ask you to review the updated version.\n\n',
                                ),
                                const TextSpan(
                                  text:
                                      'By tapping "Accept & Continue" you confirm that you have read and agree to these Terms & Conditions.',
                                ),
                              ],
                            ),
                            textAlign: TextAlign.justify,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        side: BorderSide(
                          color: colorScheme.onSurface
                              .withAlpha((0.12 * 255).round()),
                          width: 1.5,
                        ),
                        foregroundColor: colorScheme.onSurface,
                      ),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// User-friendly Terms & Conditions placeholder. Replace with the official
// legal copy provided by your institution when available.
const String _termsTitle = 'Welcome to WVSU Space.';

// The body text is rendered directly as TextSpans in the widget to allow
// bold section headings and justified alignment. Keep the title constant,
// and keep the body editable in the widget for clarity.
