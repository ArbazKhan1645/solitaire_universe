import 'package:flutter/material.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({Key? key}) : super(key: key);

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
                          'Terms and Conditions',
                          'Last updated: ${DateTime.now().year}',
                        ),
                        const SizedBox(height: 20),
                        _buildSection(
                          'Acceptance of Terms',
                          'By downloading, installing, or using Solitaire Universe, you agree to be bound by these Terms and Conditions. If you do not agree to these terms, please do not use the app.',
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          'License',
                          'We grant you a limited, non-exclusive, non-transferable, revocable license to use Solitaire Universe for personal, non-commercial purposes.',
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          'User Conduct',
                          'You agree to use the app only for lawful purposes and in accordance with these Terms. You must not use the app in any way that violates any applicable laws or regulations.',
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          'Intellectual Property',
                          'All content, features, and functionality of Solitaire Universe are owned by us and are protected by international copyright, trademark, and other intellectual property laws.',
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          'Disclaimer',
                          'Solitaire Universe is provided "as is" without any warranties, expressed or implied. We do not guarantee that the app will be error-free or uninterrupted.',
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          'Limitation of Liability',
                          'In no event shall we be liable for any indirect, incidental, special, consequential, or punitive damages arising out of your use of the app.',
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          'Changes to Terms',
                          'We reserve the right to modify these Terms and Conditions at any time. Your continued use of the app after changes constitutes acceptance of the modified terms.',
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          'Termination',
                          'We may terminate or suspend your access to the app at any time, without prior notice, for any reason, including breach of these Terms.',
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          'Governing Law',
                          'These Terms shall be governed by and construed in accordance with the laws of the jurisdiction in which we operate.',
                        ),
                        const SizedBox(height: 16),
                        _buildSection(
                          'Contact Information',
                          'If you have any questions about these Terms and Conditions, please contact us through the App Store.',
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
            'Terms & Conditions',
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
