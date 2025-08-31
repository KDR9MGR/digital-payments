import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../services/video_player_service.dart';
import '../services/video_settings_service.dart';

class YouTubeVideoWidget extends StatefulWidget {
  final double height;
  final BorderRadius? borderRadius;
  final String videoUrl;

  const YouTubeVideoWidget({
    super.key,
    required this.height,
    this.borderRadius,
    this.videoUrl = 'https://youtu.be/TVIxF-SZFlo', // Default video
  });

  @override
  State<YouTubeVideoWidget> createState() => _YouTubeVideoWidgetState();
}

class _YouTubeVideoWidgetState extends State<YouTubeVideoWidget> {
  late YoutubePlayerController _controller;
  bool _isPlayerReady = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  void _initializePlayer() {
    _controller = VideoPlayerService.initializeYouTubePlayer(widget.videoUrl);
    _controller.addListener(_listener);
    
    // Listen to mute setting changes
    final videoSettingsService = Get.find<VideoSettingsService>();
    videoSettingsService.isVideoMutedStream.listen((isMuted) {
      if (mounted && _controller.value.isReady) {
        if (isMuted) {
          _controller.mute();
        } else {
          _controller.unMute();
        }
      }
    });
  }

  void _listener() {
    if (_isPlayerReady && mounted && _controller.value.isFullScreen) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    VideoPlayerService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.zero,
      child: SizedBox(
        height: widget.height,
        child: YoutubePlayerBuilder(
          onExitFullScreen: () {
            // Handle exit fullscreen
          },
          player: YoutubePlayer(
            controller: _controller,
            showVideoProgressIndicator: false,
            progressIndicatorColor: Colors.transparent, // Hide progress indicator
            topActions: const <Widget>[], // No top actions for non-interactive experience
            bottomActions: const <Widget>[], // No bottom actions for non-interactive experience
            onReady: () {
              _isPlayerReady = true;
              _controller.setPlaybackRate(2.0); // Set 2x playback speed
              _controller.mute(); // Ensure muted
            },
            onEnded: (data) {
              // Video will auto-loop, no action needed
            },
          ),
          builder: (context, player) => Scaffold(
            body: ListView(
              children: [
                player,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final double height;
  final BorderRadius? borderRadius;
  final String videoUrl;

  const VideoPlayerWidget({
    super.key,
    required this.height,
    this.borderRadius,
    this.videoUrl = 'https://youtu.be/TVIxF-SZFlo',
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerService.initializeYouTubePlayer(widget.videoUrl);
    _controller.addListener(() {
      if (_controller.value.isReady) {
        _controller.setPlaybackRate(2.0); // Set 2x playback speed
        _controller.mute(); // Ensure always muted for non-interactive experience
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
    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.zero,
      child: SizedBox(
        height: widget.height,
        child: YoutubePlayer(
          controller: _controller,
          showVideoProgressIndicator: false,
          progressIndicatorColor: Colors.transparent, // Hide progress indicator
          topActions: const <Widget>[], // No top actions for non-interactive experience
          bottomActions: const <Widget>[], // No bottom actions for non-interactive experience
          onReady: () {
            _controller.setPlaybackRate(2.0); // Set 2x playback speed
            _controller.mute(); // Ensure muted
          },
        ),
      ),
    );
  }
}