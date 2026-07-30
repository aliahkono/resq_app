import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:resq/utils/constants/theme_constants.dart';
import 'package:resq/views/auth/registrationWiz_view.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  late AnimationController _waveController;
  double _currentPageValue = 0.0;

  final List<Map<String, String>> _onboardingData = [
    {
      'title': 'Find a Request',
      'subtitle': 'Every Drop Counts\nYour donation journey in 4 simple steps.',
      'description': 'Blood-bank post real-time urgent blood needs in your area.',
      'image': 'assets/images/FindARequest.png',
    },
    {
      'title': 'Join the Queue',
      'subtitle': '',
      'description': 'Accept the request to secure your donation slot instantly.',
      'image': 'assets/images/JoinTheQueue.png',
    },
    {
      'title': 'Smart Routing',
      'subtitle': '',
      'description': 'Get live location routing directly to the medical facility.',
      'image': 'assets/images/SmartRouting.png',
    },
    {
      'title': 'Save a Life',
      'subtitle': '',
      'description': 'Donate, complete the queue track, and see your real-time impact.',
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
      body: Stack(
        children: [
          // Dynamic Animated Background Wave
          AnimatedBuilder(
            animation: _waveController,
            builder: (context, child) {
              // Calculate parallax offset based on page scroll
              // Each page shifts the wave by a portion of the screen width
              double parallaxOffset = -_currentPageValue * (screenWidth * 0.3);
              
              // Calculate oscillation offset (breathing motion)
              double oscillationOffset = math.sin(_waveController.value * 2 * math.pi) * 30;
              
              return Positioned(
                left: parallaxOffset + oscillationOffset - 100, // -100 to ensure margin for movement
                top: MediaQuery.of(context).size.height * 0.3,
                child: Image.asset(
                  'assets/images/GradientWave.png',
                  height: 350,
                  fit: BoxFit.fitHeight,
                  // Ensure the image is wide enough to cover all pages
                  // If the asset is small, we might need to repeat it or use a very wide version
                ),
              );
            },
          ),

          // Main Content
          PageView.builder(
            controller: _pageController,
            itemCount: _onboardingData.length,
            itemBuilder: (context, index) {
              return OnboardingPage(
                data: _onboardingData[index],
                isFirst: index == 0,
              );
            },
          ),
          
          // Bottom Navigation Controls
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Skip Button
                TextButton(
                  onPressed: () => _navigateToLogin(),
                  child: Text(
                    'SKIP',
                    style: ResQTheme.subText.copyWith(
                      color: ResQTheme.textMuted,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                
                // Page Indicator
                Row(
                  children: List.generate(
                    _onboardingData.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 8,
                      width: _currentPageValue.round() == index ? 24 : 8,
                      decoration: BoxDecoration(
                        color: _currentPageValue.round() == index 
                            ? ResQTheme.primaryCrimson 
                            : ResQTheme.lightBorder,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),

                // Next / Continue Button
                ElevatedButton(
                  onPressed: () {
                    if (_currentPageValue < _onboardingData.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      _navigateToLogin();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ResQTheme.primaryCrimson,
                    minimumSize: const Size(120, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _currentPageValue.round() == _onboardingData.length - 1 ? 'CONTINUE' : 'NEXT',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToLogin() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const RegistrationWizView(),
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
  final bool isFirst;

  const OnboardingPage({
    super.key,
    required this.data,
    required this.isFirst,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 60),
        
        // Header Text
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isFirst) ...[
                const SizedBox(height: 4),
                Text(
                  'Every Drop Counts',
                  style: ResQTheme.heading3.copyWith(
                    color: ResQTheme.textDark, 
                    fontSize: 15,
                  ),
                ),
                Text(
                  'Your donation journey in 4 simple steps.',
                  style: ResQTheme.subText.copyWith(
                    fontSize: 11,
                    color: ResQTheme.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        
        const Spacer(),
        
        // Illustration Area
        Center(
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.4), // Semi-transparent to let wave show through slightly
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: ResQTheme.primaryCrimson.withOpacity(0.1),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                data['image']!,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        
        const Spacer(),
        
        // Bottom Text
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Column(
            children: [
              Text(
                data['title']!,
                textAlign: TextAlign.center,
                style: ResQTheme.heading1.copyWith(
                  fontSize: 22,
                  color: ResQTheme.textDark,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                data['description']!,
                textAlign: TextAlign.center,
                style: ResQTheme.bodyText.copyWith(
                  fontSize: 13,
                  color: ResQTheme.textMuted,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 140), 
      ],
    );
  }
}
