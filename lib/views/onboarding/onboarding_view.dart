import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:resq/utils/constants/theme_constants.dart';
import 'package:resq/views/auth/auth_landing_view.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  late AnimationController _waveController;
  double _currentPageValue = 0.0;

  final List<Map<String, String>> _onboardingData = [
    {
      'headerTitle': 'How ResQ Works',
      'headerSubtitle': 'Every Drop Counts',
      'headerDetail': 'Your donation journey in 4 simple steps.',
      'title': 'Find a Request',
      'description':
      'Blood-bank post real-time urgent blood needs in your area.',
      'image': 'assets/images/FindARequest.png',
    },
    {
      'headerTitle': 'How ResQ Works',
      'headerSubtitle': 'Instant Reservation',
      'headerDetail': 'Secure your slot without long waiting times.',
      'title': 'Join the Queue',
      'description':
      'Accept the request to secure your donation slot instantly.',
      'image': 'assets/images/JoinTheQueue.png',
    },
    {
      'headerTitle': 'How ResQ Works',
      'headerSubtitle': 'Live Navigation',
      'headerDetail': 'Effortless directions to the blood facility.',
      'title': 'Smart Routing',
      'description':
      'Get live location routing directly to the medical facility.',
      'image': 'assets/images/SmartRouting.png',
    },
    {
      'headerTitle': 'How ResQ Works',
      'headerSubtitle': 'Direct Community Impact',
      'headerDetail': 'Track your blood unit from donation to delivery.',
      'title': 'Save a Life',
      'description':
      'Donate, complete the queue track, and see your real-time impact.',
      'image': 'assets/images/SaveALife.png',
    },
  ];

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _pageController.addListener(() {
      setState(() {
        _currentPageValue = _pageController.page ?? 0.0;
      });
    });
  }

  @override
  void dispose() {
    _waveController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: ResQTheme.bgOffWhite,
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Dynamic Parallax Background Wave
            AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                double parallaxOffset = -_currentPageValue * (screenWidth * 0.35);
                double oscillationOffset =
                    math.sin(_waveController.value * 2 * math.pi) * 20;

                return Positioned(
                  left: parallaxOffset + oscillationOffset - 80,
                  top: MediaQuery.of(context).size.height * 0.22,
                  child: Image.asset(
                    'assets/images/GradientWave.png',
                    height: 380,
                    fit: BoxFit.fitHeight,
                    errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
                  ),
                );
              },
            ),

            // 2. PageView Content
            PageView.builder(
              controller: _pageController,
              itemCount: _onboardingData.length,
              itemBuilder: (context, index) {
                return OnboardingPage(
                  data: _onboardingData[index],
                );
              },
            ),

            // 3. Bottom Control Bar (SKIP - Page Indicators - NEXT/CONTINUE)
            Positioned(
              bottom: 28,
              left: 24,
              right: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Skip Button
                  TextButton(
                    onPressed: _navigateToRegistration,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    child: Text(
                      'SKIP',
                      style: ResQTheme.subText.copyWith(
                        color: ResQTheme.textMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),

                  // Dot Indicators
                  Row(
                    children: List.generate(
                      _onboardingData.length,
                          (index) {
                        final isSelected =
                            _currentPageValue.round() == index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 8,
                          width: isSelected ? 24 : 8,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? ResQTheme.primaryCrimson
                                : ResQTheme.lightBorder,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      },
                    ),
                  ),

                  // Next / Get Started Button
                  ElevatedButton(
                    onPressed: () {
                      if (_currentPageValue < _onboardingData.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        _navigateToRegistration();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ResQTheme.primaryCrimson,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(110, 46),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      _currentPageValue.round() == _onboardingData.length - 1
                          ? 'GET STARTED'
                          : 'NEXT',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToRegistration() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
        const AuthLandingView(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }
}

class OnboardingPage extends StatelessWidget {
  final Map<String, String> data;

  const OnboardingPage({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),

          // Header Text Section
          Text(
            data['headerTitle']!,
            style: ResQTheme.heading1.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: ResQTheme.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            data['headerSubtitle']!,
            style: ResQTheme.heading3.copyWith(
              color: ResQTheme.primaryCrimson,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data['headerDetail']!,
            style: ResQTheme.subText.copyWith(
              fontSize: 13,
              color: ResQTheme.textMuted,
            ),
          ),

          const Spacer(),

          // Graphic / Asset Preview Area
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: ResQTheme.primaryCrimson.withValues(alpha: 0.08),
                    blurRadius: 32,
                    spreadRadius: 8,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipOval(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Image.asset(
                    data['image']!,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_outlined,
                          size: 56,
                          color: ResQTheme.primaryCrimson.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          data['title']!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: ResQTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          const Spacer(),

          // Bottom Feature Description Box
          Center(
            child: Column(
              children: [
                Text(
                  data['title']!,
                  textAlign: TextAlign.center,
                  style: ResQTheme.heading2.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: ResQTheme.textDark,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  data['description']!,
                  textAlign: TextAlign.center,
                  style: ResQTheme.bodyText.copyWith(
                    fontSize: 14,
                    color: ResQTheme.textMuted,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 110), // Clears space for fixed bottom controls
        ],
      ),
    );
  }
}