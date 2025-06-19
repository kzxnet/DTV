import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

extension DurationClamp on Duration {
  Duration clamp(Duration min, Duration max) {
    if (this < min) return min;
    if (this > max) return max;
    return this;
  }
}

class FullScreenPlayerPage extends StatefulWidget {
  final dynamic movie;
  final List<Map<String, String>> episodes;
  final int initialIndex;

  const FullScreenPlayerPage({
    super.key,
    required this.movie,
    required this.episodes,
    required this.initialIndex,
  });

  @override
  State<FullScreenPlayerPage> createState() => _FullScreenPlayerPageState();
}

class _FullScreenPlayerPageState extends State<FullScreenPlayerPage> {
  late final Player _player;
  late final VideoController _videoController;
  int _currentEpisodeIndex;
  bool _isLoading = true;
  String? _errorMessage;
  final ValueNotifier<bool> _controlsVisibility = ValueNotifier(true);
  final FocusNode _playerFocusNode = FocusNode();
  final ValueNotifier<bool> _isSeeking = ValueNotifier(false);
  final ValueNotifier<bool> _isBuffering = ValueNotifier(false);
  final Duration _seekStep = const Duration(seconds: 10);
  Timer? _seekTimer;
  bool _isLongPressing = false;
  DateTime? _lastKeyEventTime;
  final Map<int, Duration> _episodeProgress = {};
  Duration _currentSeekSpeed = const Duration(seconds: 10);
  final Duration _minSeekSpeed = const Duration(seconds: 10);
  final Duration _maxSeekSpeed = const Duration(seconds: 300);
  final Duration _speedIncrement = const Duration(seconds: 10);
  Timer? _speedIncreaseTimer;
  Timer? _volumeHUDTimer;
  double _volume = 0.5;
  bool _showVolumeHUD = false;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _bufferingSubscription;
  final ValueNotifier<int> _seekDirection = ValueNotifier(0);
  final ValueNotifier<Duration?> _seekPosition = ValueNotifier<Duration?>(null);
  Timer? _seekHideTimer;
  final Duration _seekDisplayDuration = const Duration(seconds: 1);

  _FullScreenPlayerPageState() : _currentEpisodeIndex = 0;

  @override
  void initState() {
    super.initState();
    MediaKit.ensureInitialized();
    _currentEpisodeIndex = widget.initialIndex;
    _player = Player();
    _videoController = VideoController(_player);
    _initializePlayer(widget.episodes[_currentEpisodeIndex]['url']!);
    _playerFocusNode.addListener(() {
      if (_playerFocusNode.hasFocus) {
        _toggleControlsVisibility(true);
      }
    });
  }

  void _toggleControlsVisibility(bool visible) {
    _controlsVisibility.value = visible;
    if (visible) {
      _startControlsAutoHideTimer();
    }
  }

  void _startControlsAutoHideTimer() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _playerFocusNode.hasFocus) {
        _toggleControlsVisibility(false);
      }
    });
  }

  void _controlWakelock(bool enable) async {
    try {
      enable ? await WakelockPlus.enable() : await WakelockPlus.disable();
    } catch (e) {
      debugPrint('Wakelock控制失败: $e');
    }
  }

  void _setupPlayerListeners() {
    _playerStateSubscription = _player.stream.playing.listen((isPlaying) {
      _controlWakelock(isPlaying);
    });

    _bufferingSubscription = _player.stream.buffering.listen((isBuffering) {
      if (_isBuffering.value != isBuffering) {
        _isBuffering.value = isBuffering;
      }
    });

    _player.stream.completed.listen((completed) {
      if (completed) {
        _playNextEpisode();
      }
    });
  }

  void _cleanupSeek() {
    _isLongPressing = false;
    _seekTimer?.cancel();
    _seekTimer = null;
    _speedIncreaseTimer?.cancel();
    _speedIncreaseTimer = null;
    _currentSeekSpeed = _seekStep;
    _seekHideTimer?.cancel();
    _seekHideTimer = null;
    _isSeeking.value = false;
    _seekDirection.value = 0;
    _seekPosition.value = null;
  }

  @override
  void dispose() {
    _cleanupSeek();
    _episodeProgress.clear();
    _playerStateSubscription?.cancel();
    _bufferingSubscription?.cancel();
    _player.dispose();
    _playerFocusNode.dispose();
    _controlsVisibility.dispose();
    _isSeeking.dispose();
    _isBuffering.dispose();
    _seekDirection.dispose();
    _seekPosition.dispose();
    _volumeHUDTimer?.cancel();
    WakelockPlus.disable().ignore();
    super.dispose();
  }

  Future<void> _initializePlayer(String url) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isBuffering.value = true;
    });

    try {
      await _player.open(Media(url));
      _player.setVolume(_volume);
      _setupPlayerListeners();

      if (_episodeProgress.containsKey(_currentEpisodeIndex)) {
        await _player.seek(_episodeProgress[_currentEpisodeIndex]!);
      }

      if (mounted) {
        setState(() => _isLoading = false);
        _preloadNextEpisode();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '播放失败: ${e.toString()}';
          _isBuffering.value = false;
        });
      }
    }
  }

  void _preloadNextEpisode() async {
    if (_currentEpisodeIndex >= widget.episodes.length - 1) return;

    final nextUrl = widget.episodes[_currentEpisodeIndex + 1]['url'];
    if (nextUrl == null || nextUrl.isEmpty) return;

    try {
      final preloadPlayer = Player();
      await preloadPlayer.open(Media(nextUrl));
      await preloadPlayer.pause();
      await preloadPlayer.setVolume(0);
      await preloadPlayer.seek(Duration.zero);
      await preloadPlayer.dispose();
    } catch (e) {
      debugPrint('预加载下一集失败: $e');
    }
  }

  void _changeEpisode(int index) async {
    if (widget.episodes.isEmpty ||
        index < 0 ||
        index >= widget.episodes.length ||
        index == _currentEpisodeIndex) {
      return;
    }

    setState(() {
      _controlsVisibility.value = true;
      _isLoading = true;
      _errorMessage = null;
      _isBuffering.value = true;
    });

    _startControlsAutoHideTimer();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '正在加载: ${widget.episodes[index]['title'] ?? '第${index + 1}集'}',
            style: const TextStyle(color: Colors.white),
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.black54,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 100),
        ),
      );
    }

    _episodeProgress[_currentEpisodeIndex] = _player.state.position;

    final url = widget.episodes[index]['url'];
    if (url == null || url.isEmpty) {
      setState(() {
        _errorMessage = '无效的视频URL';
        _isLoading = false;
        _isBuffering.value = false;
      });
      return;
    }

    try {
      await _player.pause();
      await _player.open(Media(url));
          _player.setVolume(_volume);

      if (_episodeProgress.containsKey(index)) {
        await _player.seek(_episodeProgress[index]!);
      }

      setState(() {
        _currentEpisodeIndex = index;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '播放失败: ${e.toString()}';
          _isBuffering.value = false;
        });
      }
      debugPrint('初始化播放器错误: $e');
    }
  }

  void _playNextEpisode() {
    if (_currentEpisodeIndex < widget.episodes.length - 1) {
      _changeEpisode(_currentEpisodeIndex + 1);
    } else {
      _player.pause();
      if (mounted) {
        _toggleControlsVisibility(true);
      }
      _startControlsAutoHideTimer();
    }
  }

  void _togglePlayPause() {
    _toggleControlsVisibility(true);
    _player.state.playing ? _player.pause() : _player.play();
  }

  void _startSeek(Duration step) {
    if (_isLongPressing) return;

    _isLongPressing = true;
    _currentSeekSpeed = _seekStep;
    _seekDirection.value = step.inSeconds.sign;

    _updateSeekPosition(step);

    _resetSeekHideTimer();

    _seekTimer?.cancel();
    _seekTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (_isLongPressing) {
        _updateSeekPosition(_currentSeekSpeed * _seekDirection.value);
        _resetSeekHideTimer();
      } else {
        timer.cancel();
      }
    });

    _speedIncreaseTimer?.cancel();
    _speedIncreaseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _currentSeekSpeed = (_currentSeekSpeed + _speedIncrement).clamp(
          _minSeekSpeed,
          _maxSeekSpeed
      );
    });
  }

  void _resetSeekHideTimer() {
    _seekHideTimer?.cancel();
    _seekHideTimer = Timer(_seekDisplayDuration, () {
      if (!_isLongPressing) {
        _seekPosition.value = null;
        _isSeeking.value = false;
      }
    });
  }

  void _updateSeekPosition(Duration step) {
    final newPosition = (_player.state.position + step).clamp(
        Duration.zero,
        _player.state.duration
    );
    _seekPosition.value = newPosition;
    _isSeeking.value = true;
    _player.seek(newPosition);
  }

  void _stopSeek(Duration step) {
    _isLongPressing = false;
    _seekTimer?.cancel();
    _seekTimer = null;
    _speedIncreaseTimer?.cancel();
    _speedIncreaseTimer = null;
    _currentSeekSpeed = _seekStep;

    if (step != Duration.zero) {
      final newPosition = (_player.state.position + step).clamp(
          Duration.zero,
          _player.state.duration
      );
      _player.seek(newPosition);
    }

    _resetSeekHideTimer();
  }

  void _displayVolumeHUD(double volume) {
    setState(() {
      _volume = volume;
      _showVolumeHUD = true;
    });

    _volumeHUDTimer?.cancel();
    _volumeHUDTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showVolumeHUD = false;
        });
      }
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyRepeatEvent) {
      return KeyEventResult.handled;
    }

    if (event is KeyDownEvent) {
      return _handleKeyDown(event);
    } else if (event is KeyUpEvent) {
      return _handleKeyUp(event);
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleKeyDown(KeyDownEvent event) {
    final now = DateTime.now();
    if (_lastKeyEventTime != null &&
        now.difference(_lastKeyEventTime!) < Duration(milliseconds: 100)) {
      return KeyEventResult.handled;
    }
    _lastKeyEventTime = now;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.select:
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.mediaPlayPause:
        _togglePlayPause();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        _startSeek(_seekStep);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        _startSeek(-_seekStep);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        _stopSeek(Duration.zero);
        _changeEpisode(_currentEpisodeIndex - 1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        _stopSeek(Duration.zero);
        _changeEpisode(_currentEpisodeIndex + 1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        _stopSeek(Duration.zero);
        Navigator.pop(context);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.contextMenu:
        _stopSeek(Duration.zero);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.audioVolumeUp:
        final newVolume = (_volume + 0.05).clamp(0.0, 1.0);
        _player.setVolume(newVolume);
        _displayVolumeHUD(newVolume);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.audioVolumeDown:
        final newVolume = (_volume - 0.05).clamp(0.0, 1.0);
        _player.setVolume(newVolume);
        _displayVolumeHUD(newVolume);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.audioVolumeMute:
        final newVolume = _volume > 0 ? 0.0 : 0.5;
        _player.setVolume(newVolume);
        _displayVolumeHUD(newVolume);
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  KeyEventResult _handleKeyUp(KeyUpEvent event) {
    if (_isLongPressing) {
      _stopSeek(Duration.zero);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    return hours > 0
        ? '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}'
        : '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Shortcuts(
        shortcuts: {
          const SingleActivator(LogicalKeyboardKey.select): const ActivateIntent(),
          const SingleActivator(LogicalKeyboardKey.enter): const ActivateIntent(),
          const SingleActivator(LogicalKeyboardKey.arrowUp): const UpIntent(),
          const SingleActivator(LogicalKeyboardKey.arrowDown): const DownIntent(),
          const SingleActivator(LogicalKeyboardKey.arrowLeft): const LeftIntent(),
          const SingleActivator(LogicalKeyboardKey.arrowRight): const RightIntent(),
          const SingleActivator(LogicalKeyboardKey.mediaPlayPause): const PlayPauseIntent(),
          const SingleActivator(LogicalKeyboardKey.escape): const BackIntent(),
        },
        child: Actions(
          actions: {
            BackIntent: CallbackAction<BackIntent>(
              onInvoke: (intent) {
                Navigator.pop(context);
                return null;
              },
            ),
            PlayPauseIntent: CallbackAction<PlayPauseIntent>(
              onInvoke: (intent) {
                _togglePlayPause();
                return null;
              },
            ),
          },
          child: Stack(
            children: [
              _buildPlayerWidget(),
              ValueListenableBuilder<bool>(
                valueListenable: _isBuffering,
                builder: (context, buffering, child) {
                  return Visibility(
                    visible: buffering,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              '正在缓冲...',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              ValueListenableBuilder<bool>(
                valueListenable: _controlsVisibility,
                builder: (context, visible, child) {
                  return Visibility(
                    visible: visible,
                    child: _buildTopTitle(),
                  );
                },
              ),
              ValueListenableBuilder<bool>(
                valueListenable: _controlsVisibility,
                builder: (context, visible, child) {
                  return Visibility(
                    visible: visible,
                    child: _buildTopGradient(),
                  );
                },
              ),
              ValueListenableBuilder<bool>(
                valueListenable: _controlsVisibility,
                builder: (context, visible, child) {
                  return Visibility(
                    visible: visible,
                    child: _buildBottomControls(),
                  );
                },
              ),
              _buildSeekIndicator(),
              if (_showVolumeHUD) _buildVolumeHUD(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerWidget() {
    return Focus(
      autofocus: true,
      focusNode: _playerFocusNode,
      onKeyEvent: _handleKeyEvent,
      child: Center(
        child: _isLoading
            ? const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(strokeWidth: 3),
            SizedBox(height: 16),
            Text(
              '正在加载视频...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        )
            : _errorMessage != null
            ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _initializePlayer(widget.episodes[_currentEpisodeIndex]['url']!),
              child: const Text('重试'),
            ),
          ],
        )
            : Video(
          controller: _videoController,
          controls: null,
          wakelock: false,
        ),
      ),
    );
  }

  Widget _buildTopTitle() {
    return Positioned(
      top: 40,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedOpacity(
          opacity: _controlsVisibility.value && !_player.state.playing ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.episodes[_currentEpisodeIndex]['title'] ?? '当前剧集 ${_currentEpisodeIndex + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopGradient() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 100,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black54, Colors.transparent],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        height: 140,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: StreamBuilder<Duration>(
                stream: _player.stream.position,
                builder: (context, snapshot) {
                  final position = snapshot.data ?? Duration.zero;
                  final duration = _player.state.duration;
                  return LinearProgressIndicator(
                    value: duration.inMilliseconds > 0
                        ? position.inMilliseconds / duration.inMilliseconds
                        : 0,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0066FF)),
                    backgroundColor: Colors.grey[600],
                    minHeight: 4,
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '长按左右方向键可快进/快退',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _player.state.playing ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: _togglePlayPause,
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.skip_previous, color: Colors.white, size: 24),
                        onPressed: () => _changeEpisode(_currentEpisodeIndex - 1),
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next, color: Colors.white, size: 24),
                        onPressed: () => _changeEpisode(_currentEpisodeIndex + 1),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _volume == 0 ? Icons.volume_off : Icons.volume_up,
                          color: Colors.white,
                          size: 24,
                        ),
                        onPressed: () {
                          final newVolume = _volume > 0 ? 0.0 : 0.5;
                          _player.setVolume(newVolume);
                          _displayVolumeHUD(newVolume);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSeekIndicator() {
    return ValueListenableBuilder<Duration?>(
      valueListenable: _seekPosition,
      builder: (context, seekPos, child) {
        if (seekPos == null) return const SizedBox.shrink();

        return Positioned(
          left: 0,
          right: 0,
          bottom: 140,
          child: Center(
            child: ValueListenableBuilder<int>(
              valueListenable: _seekDirection,
              builder: (context, direction, child) {
                return AnimatedOpacity(
                  opacity: _isSeeking.value ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          direction > 0 ? Icons.fast_forward : Icons.fast_rewind,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDuration(seekPos),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          ' / ${_formatDuration(_player.state.duration)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        if (_currentSeekSpeed > _seekStep)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Text(
                              'x${(_currentSeekSpeed.inSeconds / _seekStep.inSeconds).toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildVolumeHUD() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 140,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _volume == 0 ? Icons.volume_off : Icons.volume_up,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 100,
                child: LinearProgressIndicator(
                  value: _volume,
                  backgroundColor: Colors.grey[600],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UpIntent extends Intent {
  const UpIntent();
}

class DownIntent extends Intent {
  const DownIntent();
}

class LeftIntent extends Intent {
  const LeftIntent();
}

class RightIntent extends Intent {
  const RightIntent();
}

class BackIntent extends Intent {
  const BackIntent();
}

class PlayPauseIntent extends Intent {
  const PlayPauseIntent();
}