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
  late Animation<double> _textReveal;
  late Animation<double> _finalFadeOut;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    );

    // Phase 2: Logo slides from top to center (0.15 - 0.35)
    _logoSlideDown = Tween<double>(begin: -200, end: 0).animate(
      CurvedAnimation(
        parent: _controller, 
        curve: const Interval(0.15, 0.35, curve: Curves.easeOutBack)
      ),
    );

    // Phase 3: BG Transition, Logo Shrink, Logo Crossfade (0.35 - 0.55)
    _bgTransition = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller, 
        curve: const Interval(0.35, 0.55, curve: Curves.easeInOut)
      ),
    );
    _logoScale = Tween<double>(begin: 1.0, end: 0.4).animate(
      CurvedAnimation(
        parent: _controller, 
        curve: const Interval(0.35, 0.55, curve: Curves.easeInOut)
      ),
    );
    _logoCrossFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller, 
        curve: const Interval(0.35, 0.45, curve: Curves.linear)
      ),
    );

    // Phase 4: Logo shifts left, Text reveals (0.55 - 0.85)
    _logoShiftLeft = Tween<double>(begin: 0.0, end: -120).animate(
      CurvedAnimation(
        parent: _controller, 
        curve: const Interval(0.60, 0.80, curve: Curves.easeInOut)
      ),
    );
    _textReveal = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller, 
        curve: const Interval(0.65, 0.85, curve: Curves.easeIn)
      ),
    );

    // Phase 5: Final fade out (0.90 - 1.0)
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
            transitionDuration: const Duration(milliseconds: 800),
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
          // Background Color Interpolation
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
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Logo and Text Container
                  Transform.translate(
                    offset: Offset(_logoShiftLeft.value, _logoSlideDown.value),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo Widget (Crossfading)
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
                        
                        // Slogan Text (Reveals in Phase 4)
                        if (_controller.value > 0.55)
                          Opacity(
                            opacity: _textReveal.value,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 0.0),
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
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
