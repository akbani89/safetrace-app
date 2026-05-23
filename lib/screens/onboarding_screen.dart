import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import '../core/api_client.dart';
import '../core/local_storage.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;
  bool _isCreating = false;

  final List<_OnboardPage> _pages = [
    _OnboardPage(
      icon: Icons.shield_outlined,
      title: AppStrings.onboard1Title,
      body: AppStrings.onboard1Body,
      color: AppColors.primary,
    ),
    _OnboardPage(
      icon: Icons.lock_outline_rounded,
      title: AppStrings.onboard2Title,
      body: AppStrings.onboard2Body,
      color: AppColors.accent,
    ),
    _OnboardPage(
      icon: Icons.favorite_border_rounded,
      title: AppStrings.onboard3Title,
      body: AppStrings.onboard3Body,
      color: AppColors.primaryLight,
    ),
  ];

  Future<void> _startAnonymously() async {
    setState(() => _isCreating = true);
    try {
      final result = await ApiClient().createAnonymousUser();
      await LocalStorage().saveSession(
        adid: result['adid'],
        token: result['access_token'],
      );
      await LocalStorage().markOnboardingSeen();

      if (!mounted) return;

      // Show recovery code ONCE
      await _showRecoveryCode(result['recovery_code']);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: AppColors.alert),
      );
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _showRecoveryCode(String recoveryCode) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Save Your Recovery Code',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This code is shown ONCE. If you lose access to your device, '
              'use this code to recover your cases.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary, width: 2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      recoveryCode,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: AppColors.primary),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: recoveryCode));
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '⚠️ Screenshot this or write it down. We cannot recover it.',
              style: TextStyle(fontSize: 12, color: AppColors.alert),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              await LocalStorage().markRecoveryCodeSeen();
              Navigator.of(ctx).pop();
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                );
              }
            },
            child: const Text('I\'ve saved it — Continue'),
          ),
        ],
      ),
    );
  }

  Future<void> _recover() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recover Account'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'XXXXXX-XXXXXX-XXXXXX',
            labelText: 'Recovery Code',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                final result = await ApiClient().recoverUser(controller.text.trim());
                await LocalStorage().saveSession(
                  adid: result['adid'],
                  token: result['access_token'],
                );
                if (mounted) {
                  Navigator.pop(ctx);
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                  );
                }
              } catch (_) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Recovery code not found.')),
                );
              }
            },
            child: const Text('Recover'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Pages
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) => _OnboardPageView(page: _pages[i]),
              ),
            ),

            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentPage == i ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentPage == i ? AppColors.primary : AppColors.divider,
                  borderRadius: BorderRadius.circular(4),
                ),
              )),
            ),

            const SizedBox(height: 32),

            // CTA
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isCreating
                          ? null
                          : () {
                              if (_currentPage < _pages.length - 1) {
                                _controller.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              } else {
                                _startAnonymously();
                              }
                            },
                      child: _isCreating
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white,
                              ),
                            )
                          : Text(
                              _currentPage < _pages.length - 1
                                  ? 'Next'
                                  : 'Start Anonymously — No Signup',
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _recover,
                    child: const Text(
                      'Already have an account? Recover',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _OnboardPage {
  final IconData icon;
  final String title;
  final String body;
  final Color color;
  const _OnboardPage({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });
}

class _OnboardPageView extends StatelessWidget {
  final _OnboardPage page;
  const _OnboardPageView({required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: page.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(60),
            ),
            child: Icon(page.icon, size: 60, color: page.color),
          ),
          const SizedBox(height: 40),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            page.body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
