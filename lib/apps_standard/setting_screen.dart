import 'package:flutter/material.dart';
import 'package:solitaire_universe/apps_standard/about_us.dart';
import 'package:solitaire_universe/apps_standard/privacy_policy.dart';
import 'package:solitaire_universe/apps_standard/term_and_conditions.dart';
import 'package:solitaire_universe/service/audio_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _musicEnabled = true;
  bool _soundEffectsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _musicEnabled = AudioService.instance.isMusicEnabled;
      _soundEffectsEnabled = AudioService.instance.areSoundEffectsEnabled;
    });
  }

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
              _buildHeader(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildSectionTitle('Audio Settings'),
                    const SizedBox(height: 12),
                    _buildSettingCard(
                      icon: Icons.music_note,
                      title: 'Background Music',
                      subtitle: 'Play music in the background',
                      trailing: Switch(
                        value: _musicEnabled,
                        onChanged: (value) async {
                          setState(() => _musicEnabled = value);
                          await AudioService.instance.toggleMusic(value);
                        },
                        activeColor: const Color(0xFF4A90E2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSettingCard(
                      icon: Icons.volume_up,
                      title: 'Sound Effects',
                      subtitle: 'Play sound effects during gameplay',
                      trailing: Switch(
                        value: _soundEffectsEnabled,
                        onChanged: (value) async {
                          setState(() => _soundEffectsEnabled = value);
                          await AudioService.instance.toggleSoundEffects(value);
                        },
                        activeColor: const Color(0xFF4A90E2),
                      ),
                    ),
                    const SizedBox(height: 30),
                    _buildSectionTitle('Information'),
                    const SizedBox(height: 12),
                    _buildSettingCard(
                      icon: Icons.info_outline,
                      title: 'About',
                      subtitle: 'App version and information',
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white70,
                        size: 18,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AboutScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildSettingCard(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy Policy',
                      subtitle: 'Read our privacy policy',
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white70,
                        size: 18,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PrivacyPolicyScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildSettingCard(
                      icon: Icons.description_outlined,
                      title: 'Terms & Conditions',
                      subtitle: 'Read our terms and conditions',
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white70,
                        size: 18,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TermsConditionsScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 30),
                    _buildSectionTitle('Support'),
                    const SizedBox(height: 12),
                    _buildSettingCard(
                      icon: Icons.star_outline,
                      title: 'Rate Us',
                      subtitle: 'Rate us on the App Store',
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white70,
                        size: 18,
                      ),
                      onTap: () {
                        _showRateDialog();
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildSettingCard(
                      icon: Icons.share,
                      title: 'Share App',
                      subtitle: 'Share with friends and family',
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white70,
                        size: 18,
                      ),
                      onTap: () {
                        _showShareDialog();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
            'Settings',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white.withOpacity(0.6),
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  void _showRateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B263B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Rate Solitaire Universe',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'If you enjoy playing Solitaire Universe, please take a moment to rate us on the App Store!',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Add your App Store URL here
              // launchUrl(Uri.parse('YOUR_APP_STORE_URL'));
            },
            child: const Text(
              'Rate Now',
              style: TextStyle(color: Color(0xFF4A90E2)),
            ),
          ),
        ],
      ),
    );
  }

  void _showShareDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B263B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Share Solitaire Universe',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Thank you for sharing Solitaire Universe with your friends!',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Add share functionality here
            },
            child: const Text(
              'Share',
              style: TextStyle(color: Color(0xFF4A90E2)),
            ),
          ),
        ],
      ),
    );
  }
}
