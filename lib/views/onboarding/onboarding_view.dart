import 'package:flutter/material.dart';
import 'package:resq/utils/constants/theme_constants.dart';
import 'package:resq/views/auth/registrationWiz_view.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _onboardingData = [
    {
      'title': 'Find a Request',
      'subtitle': 'Every Drop Counts\nYour donation journey in 4 simple steps.',
      'description': 'Blood-bank post real-time urgent blood needs in your area.',
    },
    {
      'title': 'Join the Queue',
      'subtitle': '',
      'description': 'Accept the request to secure your donation slot instantly.',
    },
    {
      'title': 'Smart Routing',
      'subtitle': '',
      'description': 'Get live location routing directly to the medical facility.',
    },
    {
      'title': 'Save a Life',
      'subtitle': '',
      'description': 'Donate, complete the queue track, and see your real-time impact.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ResQTheme.bgOffWhite,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: _onboardingData.length,
            itemBuilder: (context, index) {
              return OnboardingPage(
                data: _onboardingData[index],
                isFirst: index == 0,
                onBack: () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                  );
                },
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
                      width: _currentPage == index ? 24 : 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index 
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
                    if (_currentPage < _onboardingData.length - 1) {
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
                    _currentPage == _onboardingData.length - 1 ? 'CONTINUE' : 'NEXT',
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
  final VoidCallback onBack;

  const OnboardingPage({
    super.key,
    required this.data,
    required this.isFirst,
    required this.onBack,
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
              GestureDetector(
                onTap: isFirst ? null : onBack,
                child: Row(
                  children: [
                    if (!isFirst) 
                      const Padding(
                        padding: EdgeInsets.only(right: 8.0),
                        child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: ResQTheme.textDark),
                      ),
                    Text(
                      'How ResQ Works',
                      style: ResQTheme.heading2.copyWith(
                        color: ResQTheme.textDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
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
        
        // Wavy Illustration Area
        Stack(
          alignment: Alignment.center,
          children: [
            // Wavy Background Band
            ClipPath(
              clipper: WavyClipper(),
              child: Container(
                height: 240,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: ResQTheme.howItWorksGradient,
                ),
              ),
            ),
            
            // Illustration Container with Soft Glow
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: ResQTheme.primaryCrimson.withOpacity(0.15),
                    blurRadius: 30,
                    spreadRadius: 5,
                    offset: const Offset(0, 15),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _getIconForTitle(data['title']!),
                      size: 70,
                      color: ResQTheme.primaryCrimson,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Stage ${isFirst ? 1 : 2 /* Simple logic for demo */}',
                      style: ResQTheme.subText.copyWith(
                        fontWeight: FontWeight.bold,
                        color: ResQTheme.primaryCrimson.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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

  IconData _getIconForTitle(String title) {
    switch (title) {
      case 'Find a Request':
        return Icons.search_rounded;
      case 'Join the Queue':
        return Icons.format_list_bulleted_rounded;
      case 'Smart Routing':
        return Icons.map_rounded;
      case 'Save a Life':
        return Icons.favorite_rounded;
      default:
        return Icons.volunteer_activism_rounded;
    }
  }
}

class WavyClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    double h = size.height;
    double w = size.width;

    path.moveTo(0, h * 0.4);
    
    // Smooth S-curve top
    path.cubicTo(
      w * 0.3, h * 0.1, 
      w * 0.7, h * 0.6, 
      w, h * 0.3
    );
    
    // Right side down
    path.lineTo(w, h * 0.7);
    
    // Smooth S-curve bottom
    path.cubicTo(
      w * 0.7, h, 
      w * 0.3, h * 0.5, 
      0, h * 0.8
    );
    
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
