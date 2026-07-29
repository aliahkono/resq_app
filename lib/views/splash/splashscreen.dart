import 'package:flutter/material.dart';
import 'package:resq/utils/constants/theme_constants.dart';
import 'package:resq/views/onboarding/onboarding_view.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  // Animations for different phases
  late Animation<double> _logoSlideDown;
  late Animation<double> _logoScale;
  late Animation<double> _logoShiftLeft;
  late Animation<double> _bgTransition;
  late Animation<double> _logoCrossFade;
  late Animation<double> _textOpacity;
  late Animation<double> _textSlide;
  late Animation<double> _finalFadeOut;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5500), // Slightly longer for better pacing
    );

    // Phase 2: Logo slides from top (0.10 - 0.30)
    _logoSlideDown = Tween<double>(begin: -300, end: 0).animate(
      CurvedAnimation(
        parent: _controller, 
        curve: const Interval(0.10, 0.30, curve: Curves.easeOutBack)
      ),
    );

    // Phase 3: BG Transition, Logo Shrink, Logo Crossfade (0.30 - 0.50)
    _bgTransition = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller, 
        curve: const Interval(0.30, 0.50, curve: Curves.easeInOut)
      ),
    );
    _logoScale = Tween<double>(begin: 1.0, end: 0.35).animate(
      CurvedAnimation(
        parent: _controller, 
        curve: const Interval(0.30, 0.50, curve: Curves.easeInOut)
      ),
    );
    _logoCrossFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller, 
        curve: const Interval(0.30, 0.40, curve: Curves.linear)
      ),
    );

    // Phase 4: Logo shifts left, Slogan slides out (0.50 - 0.85)
    _logoShiftLeft = Tween<double>(begin: 0.0, end: -110).animate(
      CurvedAnimation(
        parent: _controller, 
        curve: const Interval(0.55, 0.75, curve: Curves.easeInOutCubic)
      ),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller, 
        curve: const Interval(0.60, 0.85, curve: Curves.easeIn)
      ),
    );
    _textSlide = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(
        parent: _controller, 
        curve: const Interval(0.60, 0.85, curve: Curves.easeOutCubic)
      ),
    );

    // Phase 5: Pause and Final fade out (0.90 - 1.0)
    _finalFadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller, 
        curve: const Interval(0.92, 1.0, curve: Curves.easeOut)
      ),
    );

    _controller.forward().then((_) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const OnboardingView(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 1000),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final bgColor = Color.lerp(
            ResQTheme.logoDeepMaroon, 
            ResQTheme.bgOffWhite, 
            _bgTransition.value
          );

          return Container(
            color: bgColor,
            width: double.infinity,
            height: double.infinity,
            child: Opacity(
              opacity: _finalFadeOut.value,
              child: Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // The combined unit (Logo + Slogan)
                    Transform.translate(
                      offset: Offset(_logoShiftLeft.value, _logoSlideDown.value),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo Unit
                          Transform.scale(
                            scale: _logoScale.value,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Opacity(
                                  opacity: (1.0 - _logoCrossFade.value).clamp(0.0, 1.0),
                                  child: Image.asset(
                                    'assets/images/rq_logo_white.png',
                                    width: 200,
                                  ),
                                ),
                                Opacity(
                                  opacity: _logoCrossFade.value.clamp(0.0, 1.0),
                                  child: Image.asset(
                                    'assets/images/rq_coloredLogo.png',
                                    width: 200,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Slogan Text (Slide out from behind the logo)
                          if (_controller.value > 0.50)
                            Opacity(
                              opacity: _textOpacity.value,
                              child: Transform.translate(
                                offset: Offset(_textSlide.value, 0),
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: SizedBox(
                                    width: 220,
                                    child: RichText(
                                      text: TextSpan(
                                        children: [
                                          TextSpan(
                                            text: 'ResQ ',
                                            style: ResQTheme.heading2.copyWith(
                                              color: ResQTheme.primaryCrimson,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          TextSpan(
                                            text: '| Real-Time Blood Query, Queue, & Resource Management',
                                            style: ResQTheme.bodyText.copyWith(
                                              color: ResQTheme.textDark,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
