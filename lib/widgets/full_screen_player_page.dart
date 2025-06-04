import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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
  late VideoPlayerController _controller;
  ChewieController? _chewieController;
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

  _FullScreenPlayerPageState() : _currentEpisodeIndex = 0;

  @override
  void initState() {
    super.initState();
    log('movie: ${jsonEncode(widget.movie)}');
    log('episodes: ${jsonEncode(widget.episodes)}');

    _currentEpisodeIndex = widget.initialIndex;
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

  void _setupWakelockListener() {
    bool wasPlaying = false;
    _controller.addListener(() {
      final isPlaying = _controller.value.isPlaying;
      if (wasPlaying != isPlaying) {
        wasPlaying = isPlaying;
        _controlWakelock(isPlaying);
      }
    });
  }

  void _controllerListener() {
    if (_controller.value.isPlaying) {
      _episodeProgress[_currentEpisodeIndex] = _controller.value.position;
    }

    if (_controller.value.position >= _controller.value.duration &&
        !_controller.value.isLooping) {
      _playNextEpisode();
    }
  }

  @override
  void dispose() {
    _seekTimer?.cancel();
    _speedIncreaseTimer?.cancel();
    _episodeProgress.clear();
    _controller.removeListener(_controllerListener);
    _controller.dispose();
    _chewieController?.dispose();
    _playerFocusNode.dispose();
    _controlsVisibility.dispose();
    _isSeeking.dispose();
    _isBuffering.dispose();
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
      _controller = VideoPlayerController.networkUrl(Uri.parse(url));

      // 添加缓冲状态监听
      _controller.addListener(() {
        if (_isBuffering.value != _controller.value.isBuffering) {
          _isBuffering.value = _controller.value.isBuffering;
        }
      });

      await _controller.initialize();
      _setupWakelockListener();
      _controller.addListener(_controllerListener);

      if (_episodeProgress.containsKey(_currentEpisodeIndex)) {
        await _controller.seekTo(_episodeProgress[_currentEpisodeIndex]!);
      }

      _chewieController = ChewieController(
        videoPlayerController: _controller,
        autoPlay: true,
        looping: false,
        allowFullScreen: false,
        allowedScreenSleep: false,
        showControls: false,
        draggableProgressBar: false,
        showControlsOnInitialize: false,
        showOptions: false,
        allowPlaybackSpeedChanging: false,
        useRootNavigator: false,
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFF0066FF),
          handleColor: const Color(0xFF0066FF),
          backgroundColor: Colors.grey,
          bufferedColor: Colors.grey[300]!,
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              errorMessage,
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
          );
        },
      );

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
      final preloadController = VideoPlayerController.networkUrl(Uri.parse(nextUrl));
      await preloadController.initialize();
      await preloadController.pause();
      await preloadController.setVolume(0);
      await preloadController.seekTo(Duration.zero);
      await preloadController.dispose();
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

    // 重置状态
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

    if (_controller.value.isInitialized) {
      _episodeProgress[_currentEpisodeIndex] = _controller.value.position;
    }

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
      await _controller.pause();
      await _controller.dispose();
      _chewieController?.dispose();
    } catch (e) {
      debugPrint('释放旧控制器错误: $e');
    }

    setState(() {
      _currentEpisodeIndex = index;
      _isLoading = true;
      _errorMessage = null;
      _isBuffering.value = true;
    });

    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(url));

      // 确保添加缓冲监听
      _controller.addListener(() {
        if (_isBuffering.value != _controller.value.isBuffering) {
          _isBuffering.value = _controller.value.isBuffering;
        }
      });

      await _controller.initialize();
      _setupWakelockListener();

      if (_episodeProgress.containsKey(_currentEpisodeIndex)) {
        await _controller.seekTo(_episodeProgress[_currentEpisodeIndex]!);
      }

      _controller.addListener(_controllerListener);

      _chewieController = ChewieController(
        videoPlayerController: _controller,
        autoPlay: true,
        looping: false,
        allowFullScreen: false,
        allowedScreenSleep: false,
        showControls: false,
        draggableProgressBar: false,
        showControlsOnInitialize: false,
        showOptions: false,
        allowPlaybackSpeedChanging: false,
        useRootNavigator: false,
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFF0066FF),
          handleColor: const Color(0xFF0066FF),
          backgroundColor: Colors.grey,
          bufferedColor: Colors.grey[300]!,
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              errorMessage,
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
          );
        },
      );

      if (mounted) setState(() => _isLoading = false);
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
      _controller.pause();
      if (mounted) {
        _toggleControlsVisibility(true);
      }
      _startControlsAutoHideTimer();
    }
  }

  void _togglePlayPause() {
    _toggleControlsVisibility(true);
    _controller.value.isPlaying ? _controller.pause() : _controller.play();
  }

  void _startSeek(Duration step) {
    if (_isLongPressing) return;

    _isLongPressing = true;
    _currentSeekSpeed = _seekStep;

    // Initial seek
    _handleSeek(step);

    // Start periodic seeking
    _seekTimer?.cancel();
    _seekTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (_isLongPressing) {
        _handleSeek(_currentSeekSpeed * step.inSeconds.sign);
      } else {
        timer.cancel();
      }
    });

    // Start speed increase timer
    _speedIncreaseTimer?.cancel();
    _speedIncreaseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _currentSeekSpeed = (_currentSeekSpeed + _speedIncrement).clamp(
          _minSeekSpeed,
          _maxSeekSpeed
      );
    });
  }

  void _stopSeek(Duration step) {
    _isLongPressing = false;
    _seekTimer?.cancel();
    _seekTimer = null;
    _speedIncreaseTimer?.cancel();
    _speedIncreaseTimer = null;
    _currentSeekSpeed = _seekStep;
  }

  void _handleSeek(Duration duration) {
    if (!_controller.value.isInitialized) return;

    _toggleControlsVisibility(true);
    _isSeeking.value = true;

    final newPosition = _controller.value.position + duration;
    _controller.seekTo(
      newPosition.clamp(Duration.zero, _controller.value.duration),
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _isSeeking.value = false;
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final now = DateTime.now();
    if (event is KeyRepeatEvent ||
        (_lastKeyEventTime != null &&
            now.difference(_lastKeyEventTime!) < const Duration(milliseconds: 50))) {
      return KeyEventResult.handled;
    }
    _lastKeyEventTime = now;

    if (event is KeyDownEvent) {
      return _handleKeyDown(event);
    } else if (event is KeyUpEvent) {
      return _handleKeyUp(event);
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleKeyDown(KeyDownEvent event) {
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
        _changeEpisode(_currentEpisodeIndex - 1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        _changeEpisode(_currentEpisodeIndex + 1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        Navigator.pop(context);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.contextMenu:
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  KeyEventResult _handleKeyUp(KeyUpEvent event) {
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowRight:
      case LogicalKeyboardKey.arrowLeft:
        _stopSeek(Duration.zero);
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
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
              // 缓冲指示器
              ValueListenableBuilder<bool>(
                valueListenable: _isBuffering,
                builder: (context, buffering, child) {
                  // Only show buffering indicator if video is initialized but buffering
                  if (!_controller.value.isInitialized) return const SizedBox();
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
              ValueListenableBuilder<bool>(
                valueListenable: _isSeeking,
                builder: (context, seeking, child) {
                  return Visibility(
                    visible: seeking,
                    child: _buildSeekIndicator(),
                  );
                },
              ),
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
        child: _isLoading && !_controller.value.isInitialized // Only show for initial load
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
            : Chewie(controller: _chewieController!),
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
          opacity: _controlsVisibility.value && !_controller.value.isPlaying ? 1.0 : 0.0,
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
              child: VideoProgressIndicator(
                _controller,
                allowScrubbing: true,
                colors: VideoProgressColors(
                  playedColor: const Color(0xFF0066FF),
                  bufferedColor: Colors.grey,
                  backgroundColor: Colors.grey[600]!,
                ),
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
                          _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
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
                        icon: const Icon(Icons.volume_up, color: Colors.white, size: 24),
                        onPressed: () {},
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
          child: Text(
            _controller.value.position.toString().split('.')[0],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
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