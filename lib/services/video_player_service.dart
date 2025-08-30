import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class VideoPlayerService {
  static YoutubePlayerController initializeYouTubePlayer(String videoUrl) {
    final videoId = YoutubePlayer.convertUrlToId(videoUrl);

    return YoutubePlayerController(
      initialVideoId: videoId ?? '',
      flags: YoutubePlayerFlags(
        autoPlay: true,
        mute: true, // Always muted for non-interactive experience
        enableCaption: false,
        captionLanguage: 'en',
        showLiveFullscreenButton: false,
        disableDragSeek: true, // Prevent user interaction
        hideControls: true, // Hide all controls for non-interactive experience
        hideThumbnail: true,
        loop: true, // Continuous loop playback
        forceHD: false,
        useHybridComposition: true,
        // Additional flags for better non-interactive experience
        controlsVisibleAtStart: false,
        isLive: false,
      ),
    );
  }

  static void dispose() {
    // Cleanup logic if needed
  }
}
