import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import 'login_page.dart';
import '../../widgets/responsive_dashboard_wrapper.dart';

class LoadingHomePage extends StatefulWidget {
  const LoadingHomePage({super.key});

  @override
  State<LoadingHomePage> createState() => _LoadingHomePageState();
}

class _LoadingHomePageState extends State<LoadingHomePage>
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final AnimationController _wavesController;
  late final AnimationController _dotsController;
  bool _showButton = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _wavesController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();

    // Reveal button after a brief splash
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _showButton = true);
    });
    _checkAndRouteSession();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _wavesController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  Future<void> _checkAndRouteSession() async {
    try {
      final userResponse = await Supabase.instance.client.auth.getUser();
      if (userResponse.user != null) {
        // A tiny delay to let the splash animate
        await Future.delayed(const Duration(milliseconds: 1200));
        if (!mounted || _navigated) return;
        _navigated = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF2E7D32),
            content: const Text('Welcome back!'),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ResponsiveDashboardWrapper()),
        );
        return;
      }
    } on AuthException catch (e) {
      final message = e.message.toLowerCase();
      if (message.contains('refresh token not found') ||
          message.contains('invalid refresh token')) {
        await Supabase.instance.client.auth.signOut();
      }
    } catch (_) {
      // Ignore and stay on splash/login
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.of(context).size.width < 700;

    final gradient = const LinearGradient(
      colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );

    final logoScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );
    final logoFade = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeOut));

    final content = Column(
      mainAxisAlignment:
          isMobile ? MainAxisAlignment.start : MainAxisAlignment.center,
      children: [
        if (isMobile) const SizedBox(height: 72),
        // Logo + title
        FadeTransition(
          opacity: logoFade,
          child: ScaleTransition(
            scale: logoScale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: isMobile ? 120 : 160,
                  height: isMobile ? 120 : 160,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Color.fromARGB(255, 23, 96, 156),
                        Color(0xFF1976D2),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Image.asset(
                    'assets/R.png',
                    width: isMobile ? 70 : 92,
                    height: isMobile ? 70 : 92,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'FISH PRODUCT',
                  style: GoogleFonts.poppins(
                    fontSize: isMobile ? 24 : 32,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0D47A1),
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  'MONITORING',
                  style: GoogleFonts.poppins(
                    fontSize: isMobile ? 22 : 30,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0D47A1),
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Simple bouncing dots while we show the splash
        AnimatedBuilder(
          animation: _dotsController,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (i) {
                final t = (_dotsController.value + i * .12) % 1.0;
                final y = math.sin(t * 2 * math.pi);
                return Transform.translate(
                  offset: Offset(0, -6 * y),
                  child: Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        const Color(0xFF3F68A8),
                        const Color(0xFF3F68A8),
                        (i / 4),
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }),
            );
          },
        ),
        if (isMobile) const Spacer(),
        AnimatedOpacity(
          opacity: _showButton ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 600),
          child: Padding(
            padding: EdgeInsets.only(
              top: isMobile ? 0 : 32,
              bottom: isMobile ? 24 : 0,
              left: 24,
              right: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3F68A8),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed:
                      !_showButton
                          ? null
                          : () async {
                            try {
                              if (_navigated) return;
                              _navigated = true;
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const LoginPage(),
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: colorScheme.error,
                                  content: const Text('Failed to sign in'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                  child: Text(
                    'SIGN IN / LOG IN',
                    style: GoogleFonts.poppins(
                      fontSize: isMobile ? 16 : 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (isMobile) const SizedBox(height: 8),
      ],
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Animated waves background
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _wavesController,
                builder:
                    (context, _) => CustomPaint(
                      painter: _WavesPainter(
                        animationValue: _wavesController.value,
                      ),
                    ),
              ),
            ),
            // Content
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 16 : 32,
                    ),
                    child: content,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WavesPainter extends CustomPainter {
  _WavesPainter({required this.animationValue});

  final double animationValue;

  @override
  void paint(Canvas canvas, Size size) {
    final waveColors = [
      const Color(0x1A3F68A8), // 10% opacity
      const Color(0x263F68A8), // 15% opacity
      const Color(0x333F68A8), // 20% opacity
    ];

    final paints =
        waveColors
            .map(
              (c) =>
                  Paint()
                    ..color = c
                    ..style = PaintingStyle.fill,
            )
            .toList();

    final baseHeight = size.height;
    final width = size.width;

    for (int i = 0; i < paints.length; i++) {
      final path = Path();
      final amp = 10 + i * 8;
      final k = 2 + i;
      final phase = animationValue * 2 * math.pi * (1 + i * 0.3);

      path.moveTo(0, baseHeight * (0.60 + i * 0.08));

      for (double x = 0; x <= width; x += 8) {
        final y = math.sin((x / width) * k * 2 * math.pi + phase) * amp;
        path.lineTo(x, baseHeight * (0.60 + i * 0.08) + y);
      }

      path.lineTo(width, baseHeight);
      path.lineTo(0, baseHeight);
      path.close();
      canvas.drawPath(path, paints[i]);
    }
  }

  @override
  bool shouldRepaint(covariant _WavesPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
