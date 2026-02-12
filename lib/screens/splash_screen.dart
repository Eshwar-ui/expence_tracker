import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:expence_tracker/utils/app_design_system.dart';
import 'dart:async';

import 'package:expence_tracker/widgets/auth_wrapper.dart';

class VideoSplashScreen extends StatefulWidget {
  const VideoSplashScreen({super.key});

  @override
  State<VideoSplashScreen> createState() => _VideoSplashScreenState();
}

class _VideoSplashScreenState extends State<VideoSplashScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.asset(
      'assets/animations/Prompt_create_a_1080p_202602111600.mp4',
    );

    try {
      await _controller.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _controller.play();

        // Trim to 5 seconds for a snappier premium experience
        const trimDuration = Duration(seconds: 5);
        final videoDuration = _controller.value.duration;
        final finalDuration =
            videoDuration > trimDuration ? trimDuration : videoDuration;

        Timer(finalDuration, _navigateToMainApp);
      }
    } catch (e) {
      debugPrint("Error initializing splash video: $e");
      _navigateToMainApp();
    }
  }

  void _navigateToMainApp() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const AuthWrapper(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 1000),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.darkBg,
      body: Stack(
        children: [
          if (_isInitialized)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              ),
            ),
          if (!_isInitialized)
            const Center(
              child: CircularProgressIndicator(
                color: AppDesignSystem.brandPrimary,
              ),
            ),
        ],
      ),
    );
  }
}
