import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D1B2A), Color(0xFF1B263B), Color(0xFF415A77)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.1),
                          Colors.white.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSection(
                          'Privacy Policy',
                          'Last updated: ${DateTime.now().year}',
                        ),
                        const SizedBox(height: 20),
                        _buildSection(
                          'Information Collection',
                          'Solitaire Universe is committed to protecting your privacy. This app does not collect, store, or share any personal information. All game data is stored locally on your device.',
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          'Data Storage',
                          'Game progress, settings, and statistics are stored locally on your device and are not transmitted to any external servers. You maintain full control over your data.',
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          'Third-Party Services',
                          'This app does not use any third-party analytics, advertising, or tracking services.',
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          'Children\'s Privacy',
                          'This app is suitable for all ages. We do not knowingly collect any information from children or any users.',
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          'Changes to This Policy',
                          'We may update this Privacy Policy from time to time. Any changes will be reflected in the app with an updated revision date.',
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          'Contact Us',
                          'If you have any questions about this Privacy Policy, please contact us through the App Store.',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Text(
            'Privacy Policy',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.8),
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
