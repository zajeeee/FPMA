import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:toastification/toastification.dart';
import '../../widgets/responsive_dashboard_wrapper.dart';
import '../../services/activity_log_service.dart';
import '../../services/user_service.dart';
import 'dart:math' as math;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late AnimationController _backgroundController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 10000),
    )..repeat();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (response.user != null) {
        // Log login activity
        try {
          final userRole = await UserService.getUserRole(response.user!.id);
          if (userRole != null) {
            await ActivityLogService.logActivity(
              userId: response.user!.id,
              userRole: userRole.name,
              action: 'login',
              description: 'User successfully logged in',
              metadata: {
                'timestamp': DateTime.now().toIso8601String(),
                'ip_address': 'unknown',
              },
            );
          }
        } catch (e) {
          // Don't fail login if activity logging fails
          debugPrint('Failed to log login activity: $e');
        }

        if (mounted) {
          toastification.show(
            context: context,
            type: ToastificationType.success,
            style: ToastificationStyle.flat,
            title: const Text('Login Successful'),
            description: const Text('Welcome to FPM Libasport!'),
            alignment: Alignment.topRight,
            autoCloseDuration: const Duration(seconds: 3),
          );

          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder:
                  (context, animation, secondaryAnimation) =>
                      const ResponsiveDashboardWrapper(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
        }
      }
    } on AuthException catch (error) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.flat,
          title: const Text('Login Failed'),
          description: Text(error.message),
          alignment: Alignment.topRight,
          autoCloseDuration: const Duration(seconds: 4),
        );
      }
    } catch (error) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.flat,
          title: const Text('Error'),
          description: const Text('An unexpected error occurred'),
          alignment: Alignment.topRight,
          autoCloseDuration: const Duration(seconds: 4),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        // Left side - Branding
        Expanded(
          flex: 1,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.directions_boat,
                  size: 80,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'FPM Libasport',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Fish Product Monitoring',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.security,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Secure & Reliable',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Role-based access control with comprehensive audit trails',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 48),
        // Right side - Login Form
        Expanded(flex: 1, child: _buildLoginForm()),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Logo and Title
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.directions_boat,
            size: 60,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'FPM Libasport',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Fish Product Monitoring',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 48),
        // Login Form
        _buildLoginForm(),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Sign In',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Email Field
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!RegExp(
                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                  ).hasMatch(value)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Password Field
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Sign In Button
              FilledButton(
                onPressed: _isLoading ? null : _signIn,
                child:
                    _isLoading
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text('Sign In'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              Theme.of(context).colorScheme.secondary.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Animated fish and bubbles background
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _backgroundController,
                builder:
                    (context, _) => CustomPaint(
                      painter: _FishBubblesPainter(
                        animationValue: _backgroundController.value,
                        isMobile: MediaQuery.of(context).size.width < 800,
                      ),
                    ),
              ),
            ),
            // Content
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isWideScreen = constraints.maxWidth > 800;
                          return isWideScreen
                              ? _buildWideLayout()
                              : _buildNarrowLayout();
                        },
                      ),
                    ),
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
