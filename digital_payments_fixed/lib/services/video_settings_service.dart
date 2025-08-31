import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VideoSettingsService extends GetxService {
  static VideoSettingsService get instance => Get.find<VideoSettingsService>();
  
  // Reactive variable for video mute state
  final RxBool _isVideoMuted = true.obs; // Default to muted
  
  // Getter for video mute state
  bool get isVideoMuted => _isVideoMuted.value;
  
  // Stream for listening to mute state changes
  RxBool get isVideoMutedStream => _isVideoMuted;
  
  // SharedPreferences key
  static const String _videoMuteKey = 'video_mute_preference';
  
  @override
  Future<void> onInit() async {
    super.onInit();
    await _loadVideoMutePreference();
  }
  
  /// Load video mute preference from SharedPreferences
  Future<void> _loadVideoMutePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMuteState = prefs.getBool(_videoMuteKey) ?? true; // Default to muted
      _isVideoMuted.value = savedMuteState;
    } catch (e) {
      // If there's an error loading preferences, default to muted
      _isVideoMuted.value = true;
    }
  }
  
  /// Toggle video mute state
  Future<void> toggleVideoMute() async {
    final newMuteState = !_isVideoMuted.value;
    await setVideoMute(newMuteState);
  }
  
  /// Set video mute state
  Future<void> setVideoMute(bool isMuted) async {
    try {
      _isVideoMuted.value = isMuted;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_videoMuteKey, isMuted);
    } catch (e) {
      // If saving fails, revert the state
      _isVideoMuted.value = !isMuted;
      rethrow;
    }
  }
  
  /// Get video mute state synchronously
  bool getVideoMuteState() {
    return _isVideoMuted.value;
  }
  
  /// Reset video settings to default (muted)
  Future<void> resetToDefault() async {
    await setVideoMute(true);
  }
}