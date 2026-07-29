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

  const OnboardingPage({
    super.key,
    required this.data,
    required this.isFirst,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 80),
        
        // Header Text
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (!isFirst) 
                    const Icon(Icons.arrow_back_ios, size: 16, color: ResQTheme.textDark),
                  Text(
                    ' How ResQ Works',
                    style: ResQTheme.heading2.copyWith(color: ResQTheme.textDark),
                  ),
                ],
              ),
              if (isFirst) ...[
                const SizedBox(height: 8),
                Text(
                  'Every Drop Counts',
                  style: ResQTheme.heading3.copyWith(color: ResQTheme.textDark, fontSize: 16),
                ),
                Text(
                  'Your donation journey in 4 simple steps.',
                  style: ResQTheme.subText.copyWith(fontSize: 12),
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
            // Wavy Background (Simulating the wavy banner in Figma)
            ClipPath(
              clipper: WavyClipper(),
              child: Container(
                height: 280,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: ResQTheme.howItWorksGradient,
                ),
              ),
            ),
            
            // Illustration Placeholder Container
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _getIconForTitle(data['title']!),
                      size: 80,
                      color: ResQTheme.primaryCrimson,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '[ Illustration ]',
                      style: TextStyle(color: ResQTheme.textMuted, fontSize: 10),
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
                  fontSize: 28,
                  color: ResQTheme.textDark,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                data['description']!,
                textAlign: TextAlign.center,
                style: ResQTheme.bodyText.copyWith(
                  fontSize: 15,
                  color: ResQTheme.textMuted,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 160), // Space for buttons and indicator
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
    path.moveTo(0, size.height * 0.3);
    
    var firstControlPoint = Offset(size.width * 0.25, size.height * 0.1);
    var firstEndPoint = Offset(size.width * 0.5, size.height * 0.3);
    path.quadraticBezierTo(firstControlPoint.dx, firstControlPoint.dy,
        firstEndPoint.dx, firstEndPoint.dy);
    
    var secondControlPoint = Offset(size.width * 0.75, size.height * 0.5);
    var secondEndPoint = Offset(size.width, size.height * 0.35);
    path.quadraticBezierTo(secondControlPoint.dx, secondControlPoint.dy,
        secondEndPoint.dx, secondEndPoint.dy);
    
    path.lineTo(size.width, size.height * 0.7);
    
    var thirdControlPoint = Offset(size.width * 0.75, size.height * 0.9);
    var thirdEndPoint = Offset(size.width * 0.5, size.height * 0.7);
    path.quadraticBezierTo(thirdControlPoint.dx, thirdControlPoint.dy,
        thirdEndPoint.dx, thirdEndPoint.dy);
    
    var fourthControlPoint = Offset(size.width * 0.25, size.height * 0.5);
    var fourthEndPoint = Offset(0, size.height * 0.65);
    path.quadraticBezierTo(fourthControlPoint.dx, fourthControlPoint.dy,
        fourthEndPoint.dx, fourthEndPoint.dy);
    
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
