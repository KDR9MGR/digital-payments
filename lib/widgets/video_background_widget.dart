import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../services/video_player_service.dart';

class VideoBackgroundWidget extends StatefulWidget {
  final Widget child;
  final String videoUrl;
  final bool autoPlay;

  const VideoBackgroundWidget({
    super.key,
    required this.child,
    this.videoUrl = 'https://youtu.be/TVIxF-SZFlo',
    this.autoPlay = false,
  });

  @override
  State<VideoBackgroundWidget> createState() => _VideoBackgroundWidgetState();
}

class _VideoBackgroundWidgetState extends State<VideoBackgroundWidget> {
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
  }

  void _listener() {
    if (_isPlayerReady && mounted) {
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
    return Stack(
      children: [
        // Background video
        Positioned.fill(
          child: YoutubePlayer(
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
          ),
        ),
        // Overlay content
        widget.child,
      ],
    );
  }
}

class ResponsiveVideoWidget extends StatefulWidget {
  final String videoUrl;
  final double aspectRatio;
  final BorderRadius? borderRadius;

  const ResponsiveVideoWidget({
    super.key,
    this.videoUrl = 'https://youtu.be/TVIxF-SZFlo',
    this.aspectRatio = 16 / 9,
    this.borderRadius,
  });

  @override
  State<ResponsiveVideoWidget> createState() => _ResponsiveVideoWidgetState();
}

class _ResponsiveVideoWidgetState extends State<ResponsiveVideoWidget> {
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
  }

  void _listener() {
    if (_isPlayerReady && mounted) {
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
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: ClipRRect(
        borderRadius: widget.borderRadius ?? BorderRadius.zero,
        child: YoutubePlayer(
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
        ),
      ),
    );
  }
}

class CompactVideoWidget extends StatefulWidget {
  final String videoUrl;
  final double height;
  final VoidCallback? onTap;

  const CompactVideoWidget({
    super.key,
    this.videoUrl = 'https://youtu.be/TVIxF-SZFlo',
    this.height = 200,
    this.onTap,
  });

  @override
  State<CompactVideoWidget> createState() => _CompactVideoWidgetState();
}

class _CompactVideoWidgetState extends State<CompactVideoWidget> {
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
  }

  void _listener() {
    if (_isPlayerReady && mounted) {
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
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: YoutubePlayer(
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
        ),
      ),
    );
  }
}