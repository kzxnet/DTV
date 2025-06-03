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
  bool _showControls = true;
  final FocusNode _playerFocusNode = FocusNode();
  bool _isFastSeeking = false;
  final Duration _seekStep = const Duration(seconds: 10);
  Timer? _seekTimer;
  bool _isLongPressing = false;
  DateTime? _lastKeyEventTime;
  // 新增：记录每一集的播放进度
  final Map<int, Duration> _episodeProgress = {};

  // 新增：快进/快退速度相关变量
  Duration _currentSeekSpeed = const Duration(seconds: 10);
  final Duration _minSeekSpeed = const Duration(seconds: 5);
  final Duration _maxSeekSpeed = const Duration(seconds: 30);
  final Duration _speedIncrement = const Duration(seconds: 5);
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
        setState(() => _showControls = true);
        _startControlsAutoHideTimer();
      }
    });
  }

  void _startControlsAutoHideTimer() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _playerFocusNode.hasFocus) {
        setState(() => _showControls = false);
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

  @override
  void dispose() {
    _seekTimer?.cancel();
    _speedIncreaseTimer?.cancel(); // 新增：释放速度增加定时器
    WakelockPlus.disable().catchError((e) => debugPrint(e.toString()));
    _controller.dispose();
    _chewieController?.dispose();
    _playerFocusNode.dispose();
    super.dispose();
  }

  Future<void> _initializePlayer(String url) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await _controller.initialize();
      _setupWakelockListener();

      // 新增：恢复当前剧集的播放进度
      if (_episodeProgress.containsKey(_currentEpisodeIndex)) {
        await _controller.seekTo(_episodeProgress[_currentEpisodeIndex]!);
      }

      _controller.addListener(() {
        // 新增：记录当前播放进度
        if (_controller.value.isPlaying) {
          _episodeProgress[_currentEpisodeIndex] = _controller.value.position;
        }

        if (_controller.value.position >= _controller.value.duration &&
            !_controller.value.isLooping) {
          _playNextEpisode();
        }
      });

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
        });
      }
    }
  }

  void _changeEpisode(int index) async {
    if (widget.episodes.isEmpty ||
        index < 0 ||
        index >= widget.episodes.length ||
        index == _currentEpisodeIndex) {
      return;
    }

    // 新增：保存当前剧集的播放进度
    if (_controller.value.isInitialized) {
      _episodeProgress[_currentEpisodeIndex] = _controller.value.position;
    }

    final url = widget.episodes[index]['url'];
    if (url == null || url.isEmpty) {
      setState(() {
        _errorMessage = '无效的视频URL';
        _isLoading = false;
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
    });

    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await _controller.initialize();
      _setupWakelockListener();

      // 新增：恢复新剧集的播放进度
      if (_episodeProgress.containsKey(_currentEpisodeIndex)) {
        await _controller.seekTo(_episodeProgress[_currentEpisodeIndex]!);
      }

      _controller.addListener(() {
        // 新增：记录当前播放进度
        if (_controller.value.isPlaying) {
          _episodeProgress[_currentEpisodeIndex] = _controller.value.position;
        }

        if (_controller.value.position >= _controller.value.duration &&
            !_controller.value.isLooping) {
          _playNextEpisode();
        }
      });

      _chewieController = _chewieController!.copyWith(
        videoPlayerController: _controller,
      );

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '播放失败: ${e.toString()}';
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
        setState(() {
          _showControls = true;
        });
      }
      _startControlsAutoHideTimer();
    }
  }

  void _togglePlayPause() {
    setState(() => _showControls = true);
    _startControlsAutoHideTimer();
    _controller.value.isPlaying ? _controller.pause() : _controller.play();
  }

  void _seekForward() => _handleSeek(_seekStep);
  void _seekBackward() => _handleSeek(-_seekStep);

  void _startSeek(Duration step) {
    _isLongPressing = true;
    _currentSeekSpeed = _seekStep; // 重置速度
    _seekTimer?.cancel();
    _seekTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (_isLongPressing) {
        _handleSeek(_currentSeekSpeed * step.inSeconds.sign);
      } else {
        timer.cancel();
      }
    });

    // 新增：速度逐步增加的定时器
    _speedIncreaseTimer?.cancel();
    _speedIncreaseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _currentSeekSpeed = (_currentSeekSpeed + _speedIncrement).clamp(
            _minSeekSpeed,
            _maxSeekSpeed
        );
      });
    });
  }


  void _stopSeek(Duration step) {
    _handleSeek(step);
    _isLongPressing = false;
    _seekTimer?.cancel();
    _seekTimer = null;

    // 新增：停止速度增加定时器
    _speedIncreaseTimer?.cancel();
    _speedIncreaseTimer = null;
    _currentSeekSpeed = _seekStep; // 重置速度
  }

  void _handleSeek(Duration duration) {
    setState(() {
      _showControls = true;
      _isFastSeeking = true;
    });
    _startControlsAutoHideTimer();

    final newPosition = _controller.value.position + duration;
    _controller.seekTo(
      newPosition.clamp(Duration.zero, _controller.value.duration),
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _isFastSeeking = false);
    });
  }

  // void _increaseVolume() {
  //   setState(() => _showControls = true);
  //   _startControlsAutoHideTimer();
  //   _controller.setVolume((_controller.value.volume + 0.1).clamp(0.0, 1.0));
  // }
  //
  // void _decreaseVolume() {
  //   setState(() => _showControls = true);
  //   _startControlsAutoHideTimer();
  //   _controller.setVolume((_controller.value.volume - 0.1).clamp(0.0, 1.0));
  // }

  void _handleKeyRepeat(KeyEvent event) {
    final now = DateTime.now();
    if (_lastKeyEventTime != null &&
        now.difference(_lastKeyEventTime!) <
            const Duration(milliseconds: 200)) {
      return;
    }
    _lastKeyEventTime = now;

    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _seekForward();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _seekBackward();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Shortcuts(
        shortcuts: {
          const SingleActivator(LogicalKeyboardKey.select):
              const ActivateIntent(),
          const SingleActivator(LogicalKeyboardKey.enter):
              const ActivateIntent(),
          const SingleActivator(LogicalKeyboardKey.arrowUp): const UpIntent(),
          const SingleActivator(LogicalKeyboardKey.arrowDown):
              const DownIntent(),
          const SingleActivator(LogicalKeyboardKey.arrowLeft):
              const LeftIntent(),
          const SingleActivator(LogicalKeyboardKey.arrowRight):
              const RightIntent(),
          const SingleActivator(LogicalKeyboardKey.mediaPlayPause):
              const PlayPauseIntent(),
          const SingleActivator(LogicalKeyboardKey.escape): const BackIntent(),
          // 注意：这里没有包含菜单键的快捷键
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
              Focus(
                autofocus: true,
                focusNode: _playerFocusNode,
                onKeyEvent: (node, KeyEvent event) {
                  log('onKeyEvent: $event');

                  if (event is KeyRepeatEvent) {
                    _handleKeyRepeat(event);
                    return KeyEventResult.handled;
                  }

                  if (event is KeyDownEvent) {
                    switch (event.logicalKey) {
                      case LogicalKeyboardKey.select:
                      case LogicalKeyboardKey.enter:
                        _togglePlayPause();
                        return KeyEventResult.handled;
                      case LogicalKeyboardKey.arrowRight:
                        _startSeek(_seekStep);
                        return KeyEventResult.handled;
                      case LogicalKeyboardKey.arrowLeft:
                        _startSeek(-_seekStep);
                        return KeyEventResult.handled;
                      case LogicalKeyboardKey.arrowUp:
                        // _increaseVolume();
                        _changeEpisode(_currentEpisodeIndex - 1);
                        return KeyEventResult.handled;
                      case LogicalKeyboardKey.arrowDown:
                        // _decreaseVolume();
                        _changeEpisode(_currentEpisodeIndex + 1);
                        return KeyEventResult.handled;
                      case LogicalKeyboardKey.escape:
                        Navigator.pop(context);
                        return KeyEventResult.handled;
                      case LogicalKeyboardKey.mediaPlayPause:
                        _togglePlayPause();
                        return KeyEventResult.handled;
                      // 明确忽略菜单键
                      case LogicalKeyboardKey.contextMenu:
                        return KeyEventResult.handled; // 直接处理掉，不做任何操作
                      default:
                        return KeyEventResult.ignored;
                    }
                  } else if (event is KeyUpEvent) {
                    switch (event.logicalKey) {
                      case LogicalKeyboardKey.arrowRight:
                        _stopSeek(_seekStep);
                        return KeyEventResult.handled;
                      case LogicalKeyboardKey.arrowLeft:
                        _stopSeek(-_seekStep);
                        return KeyEventResult.handled;
                    }
                  }
                  return KeyEventResult.ignored;
                },
                child: Center(
                  child:
                      _isLoading
                          ? const CircularProgressIndicator(strokeWidth: 3)
                          : _errorMessage != null
                          ? Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.white),
                          )
                          : Chewie(controller: _chewieController!),
                ),
              ),
              if (_showControls)
                Positioned(
                  top: 40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: AnimatedOpacity(
                      opacity:
                          _showControls && !_controller.value.isPlaying
                              ? 1.0
                              : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.episodes[_currentEpisodeIndex]['title'] ??
                              '当前剧集 ${_currentEpisodeIndex + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (_showControls)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 100,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black54, Colors.transparent],
                      ),
                    ),
                  ),
                ),

              if (_showControls)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 140,
                    decoration: BoxDecoration(
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
                                      _controller.value.isPlaying
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                    onPressed: _togglePlayPause,
                                  ),
                                  const SizedBox(width: 16),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.skip_previous,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    onPressed:
                                        () => _changeEpisode(
                                          _currentEpisodeIndex - 1,
                                        ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.skip_next,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    onPressed:
                                        () => _changeEpisode(
                                          _currentEpisodeIndex + 1,
                                        ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.volume_up,
                                      color: Colors.white,
                                      size: 24,
                                    ),
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
                ),

              if (_isFastSeeking)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 140,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
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
