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
  late final AnimationController _pulseController;
  late final AnimationController _shimmerController;
  bool _showButton = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();

    _wavesController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 10000),
    )..repeat();

    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    // Reveal button after a brief splash
    Future.delayed(const Duration(milliseconds: 2800), () {
      if (mounted) setState(() => _showButton = true);
    });
    _checkAndRouteSession();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _wavesController.dispose();
    _dotsController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
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

    final gradient = LinearGradient(
      colors: [
        const Color(0xFFE8F4FD),
        const Color(0xFFB3E5FC),
        const Color(0xFF81D4FA),
        const Color(0xFF3F68A8),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      stops: const [0.0, 0.3, 0.7, 1.0],
    );

    final logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    final logoFade = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeOut));

    final pulseScale = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    final shimmerOffset = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

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
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: pulseScale.value,
                      child: Container(
                        width: isMobile ? 140 : 180,
                        height: isMobile ? 140 : 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF3F68A8),
                              Color(0xFF3F68A8),
                              Color(0xFF3F68A8),
                              Color(0xFF3F68A8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            stops: [0.0, 0.3, 0.7, 1.0],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF3F68A8,
                              ).withValues(alpha: 0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: const Color(
                                0xFF3F68A8,
                              ).withValues(alpha: 0.1),
                              blurRadius: 40,
                              spreadRadius: 10,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // Shimmer effect
                            AnimatedBuilder(
                              animation: _shimmerController,
                              builder: (context, child) {
                                return ClipOval(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.transparent,
                                          Colors.white.withValues(alpha: 0.3),
                                          Colors.transparent,
                                        ],
                                        stops: [
                                          (shimmerOffset.value - 0.3).clamp(
                                            0.0,
                                            1.0,
                                          ),
                                          shimmerOffset.value.clamp(0.0, 1.0),
                                          (shimmerOffset.value + 0.3).clamp(
                                            0.0,
                                            1.0,
                                          ),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            // Icon
                            Center(
                              child: Icon(
                                Icons.directions_boat,
                                size: isMobile ? 80 : 100,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
                AnimatedBuilder(
                  animation: _logoController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, 10 * (1 - _logoController.value)),
                      child: Opacity(
                        opacity: _logoController.value,
                        child: Column(
                          children: [
                            Text(
                              'FISH PRODUCT',
                              style: GoogleFonts.poppins(
                                fontSize: isMobile ? 28 : 36,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF3F68A8),
                                letterSpacing: 2.0,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    offset: const Offset(0, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'MONITORING',
                              style: GoogleFonts.poppins(
                                fontSize: isMobile ? 26 : 34,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF3F68A8),
                                letterSpacing: 2.0,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    offset: const Offset(0, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Quality Fish Products',
                              style: GoogleFonts.poppins(
                                fontSize: isMobile ? 14 : 16,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF3F68A8),
                                letterSpacing: 1.2,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Enhanced loading animation
        AnimatedBuilder(
          animation: _dotsController,
          builder: (context, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (i) {
                    final t = (_dotsController.value + i * .15) % 1.0;
                    final y = math.sin(t * 2 * math.pi);
                    final scale = 0.8 + 0.4 * math.sin(t * 2 * math.pi);
                    return Transform.translate(
                      offset: Offset(0, -8 * y),
                      child: Transform.scale(
                        scale: scale,
                        child: Container(
                          width: isMobile ? 12 : 14,
                          height: isMobile ? 12 : 14,
                          margin: EdgeInsets.symmetric(
                            horizontal: isMobile ? 4 : 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF3F68A8),
                                const Color(0xFF3F68A8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF3F68A8,
                                ).withValues(alpha: 0.3),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading your fish monitoring dashboard...',
                  style: GoogleFonts.poppins(
                    fontSize: isMobile ? 12 : 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF3F68A8),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            );
          },
        ),
        if (isMobile) const Spacer(),
        AnimatedOpacity(
          opacity: _showButton ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 800),
          child: Transform.translate(
            offset: Offset(0, _showButton ? 0 : 20),
            child: Padding(
              padding: EdgeInsets.only(
                top: isMobile ? 0 : 40,
                bottom: isMobile ? 32 : 0,
                left: 24,
                right: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SizedBox(
                  width: double.infinity,
                  height: isMobile ? 52 : 60,
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF3F68A8),
                              Color(0xFF3F68A8),
                              Color(0xFF3F68A8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF3F68A8,
                              ).withValues(alpha: 0.4),
                              blurRadius: 15,
                              spreadRadius: 2,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
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
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          behavior: SnackBarBehavior.floating,
                                          backgroundColor: colorScheme.error,
                                          content: const Text(
                                            'Failed to sign in',
                                          ),
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                          child: Text(
                            'SIGN IN',
                            style: GoogleFonts.poppins(
                              fontSize: isMobile ? 16 : 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  offset: const Offset(0, 1),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
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
            // Animated fish and bubbles background
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _wavesController,
                builder:
                    (context, _) => CustomPaint(
                      painter: _FishBubblesPainter(
                        animationValue: _wavesController.value,
                        isMobile: isMobile,
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

class _FishBubblesPainter extends CustomPainter {
  _FishBubblesPainter({required this.animationValue, required this.isMobile});

  final double animationValue;
  final bool isMobile;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw floating bubbles
    _drawBubbles(canvas, size);

    // Draw subtle fish silhouettes
    _drawFish(canvas, size);

    // Draw gentle water particles
    _drawWaterParticles(canvas, size);
  }

  void _drawBubbles(Canvas canvas, Size size) {
    final bubblePaint =
        Paint()
          ..color = const Color(0xFF3F68A8).withValues(alpha: 0.15)
          ..style = PaintingStyle.fill;

    for (int i = 0; i < 8; i++) {
      final x = (size.width * 0.1 + i * size.width * 0.1) % size.width;
      final y = size.height - (animationValue * size.height * 2) + (i * 50);
      final radius = 3.0 + (i % 3) * 2.0;

      if (y > -50 && y < size.height + 50) {
        canvas.drawCircle(Offset(x, y), radius, bubblePaint);
      }
    }
  }

  void _drawFish(Canvas canvas, Size size) {
    final fishPaint =
        Paint()
          ..color = const Color(0xFF3F68A8).withValues(alpha: 0.08)
          ..style = PaintingStyle.fill;

    // Draw 3 fish silhouettes
    for (int i = 0; i < 3; i++) {
      final x =
          (size.width * 0.2 + i * size.width * 0.3) +
          math.sin(animationValue * 2 * math.pi + i) * 20;
      final y = size.height * 0.3 + i * size.height * 0.2;

      _drawFishSilhouette(canvas, Offset(x, y), fishPaint);
    }
  }

  void _drawFishSilhouette(Canvas canvas, Offset center, Paint paint) {
    final path = Path();
    final fishSize = isMobile ? 15.0 : 20.0;

    // Fish body (oval)
    path.addOval(
      Rect.fromCenter(center: center, width: fishSize * 2, height: fishSize),
    );

    // Fish tail
    path.moveTo(center.dx - fishSize, center.dy);
    path.lineTo(center.dx - fishSize * 1.5, center.dy - fishSize * 0.3);
    path.lineTo(center.dx - fishSize * 1.5, center.dy + fishSize * 0.3);
    path.close();

    canvas.drawPath(path, paint);
  }

  void _drawWaterParticles(Canvas canvas, Size size) {
    final particlePaint =
        Paint()
          ..color = const Color(0xFF3F68A8).withValues(alpha: 0.05)
          ..style = PaintingStyle.fill;

    for (int i = 0; i < 20; i++) {
      final x = (i * 37.0) % size.width;
      final y =
          (size.height * 0.8) +
          math.sin(animationValue * 3 * math.pi + i * 0.5) * 10;
      final radius = 1.0 + (i % 2);

      canvas.drawCircle(Offset(x, y), radius, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FishBubblesPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.isMobile != isMobile;
  }
}
