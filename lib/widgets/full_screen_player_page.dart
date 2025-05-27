import 'dart:async';
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
  bool _showEpisodeMenu = false;
  final FocusNode _playerFocusNode = FocusNode();
  final FocusNode _episodeMenuFocusNode = FocusNode();
  final ScrollController _episodeMenuScrollController = ScrollController();
  DateTime? _lastKeyEventTime;
  bool _isFastSeeking = false;
  Duration _seekStep = const Duration(seconds: 10);
  Timer? _seekTimer;
  bool _isLongPressing = false;

  _FullScreenPlayerPageState() : _currentEpisodeIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentEpisodeIndex = widget.initialIndex;
    _initializePlayer(widget.episodes[_currentEpisodeIndex]['url']!);

    _playerFocusNode.addListener(() {
      if (_playerFocusNode.hasFocus) {
        setState(() => _showControls = true);
        _startControlsAutoHideTimer();
      }
    });

    _episodeMenuFocusNode.addListener(() {
      if (_episodeMenuFocusNode.hasFocus) {
        setState(() {
          _showControls = true;
          _showEpisodeMenu = true;
        });
      }
    });
  }

  void _startControlsAutoHideTimer() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && !_showEpisodeMenu && _playerFocusNode.hasFocus) {
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
    bool _wasPlaying = false;
    _controller.addListener(() {
      final isPlaying = _controller.value.isPlaying;
      if (_wasPlaying != isPlaying) {
        _wasPlaying = isPlaying;
        _controlWakelock(isPlaying);
      }
    });
  }

  @override
  void dispose() {
    _seekTimer?.cancel();
    WakelockPlus.disable().catchError((e) => debugPrint(e.toString()));
    _controller.dispose();
    _chewieController?.dispose();
    _playerFocusNode.dispose();
    _episodeMenuFocusNode.dispose();
    _episodeMenuScrollController.dispose();
    super.dispose();
  }

  Future<void> _initializePlayer(String url) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _controller = VideoPlayerController.network(url);
      await _controller.initialize();
      _setupWakelockListener();

      // 添加播放完成监听
      _controller.addListener(() {
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
      setState(() => _showEpisodeMenu = false);
      _playerFocusNode.requestFocus();
      return;
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
      _showEpisodeMenu = false;
    });

    try {
      _controller = VideoPlayerController.network(url);
      await _controller.initialize();
      _setupWakelockListener();

      // 重新添加播放完成监听
      _controller.addListener(() {
        if (_controller.value.position >= _controller.value.duration &&
            !_controller.value.isLooping) {
          _playNextEpisode();
        }
      });

      _chewieController = ChewieController(
        videoPlayerController: _controller,
        autoPlay: true,
        looping: false,
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

    _playerFocusNode.requestFocus();
  }

  void _playNextEpisode() {
    if (_currentEpisodeIndex < widget.episodes.length - 1) {
      _changeEpisode(_currentEpisodeIndex + 1);
    } else {
      // 如果是最后一集，暂停播放
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
    _seekTimer?.cancel();
    _seekTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (_isLongPressing) {
        _handleSeek(step);
      } else {
        timer.cancel();
      }
    });
  }

  void _stopSeek() {
    _isLongPressing = false;
    _seekTimer?.cancel();
    _seekTimer = null;
  }

  void _handleSeek(Duration duration) {
    setState(() {
      _showControls = true;
      _isFastSeeking = true;
    });
    _startControlsAutoHideTimer();

    final newPosition = _controller.value.position + duration;
    _controller.seekTo(newPosition.clamp(
      Duration.zero,
      _controller.value.duration,
    ));

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _isFastSeeking = false);
    });
  }

  void _increaseVolume() {
    setState(() => _showControls = true);
    _startControlsAutoHideTimer();
    _controller.setVolume((_controller.value.volume + 0.1).clamp(0.0, 1.0));
  }

  void _decreaseVolume() {
    setState(() => _showControls = true);
    _startControlsAutoHideTimer();
    _controller.setVolume((_controller.value.volume - 0.1).clamp(0.0, 1.0));
  }

  void _toggleEpisodeMenu() {
    setState(() {
      _showControls = true;
      _showEpisodeMenu = !_showEpisodeMenu;
    });

    if (_showEpisodeMenu) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _episodeMenuFocusNode.requestFocus();
          _scrollToCurrentItem();
        }
      });
    } else {
      _playerFocusNode.requestFocus();
    }

    _startControlsAutoHideTimer();
  }

  void _scrollToCurrentItem() {
    _episodeMenuScrollController.animateTo(
      (_currentEpisodeIndex * 56.0).clamp(
        0.0,
        _episodeMenuScrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _handleKeyRepeat(KeyEvent event) {
    final now = DateTime.now();
    if (_lastKeyEventTime != null &&
        now.difference(_lastKeyEventTime!) < const Duration(milliseconds: 200)) {
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
          const SingleActivator(LogicalKeyboardKey.select): const ActivateIntent(),
          const SingleActivator(LogicalKeyboardKey.enter): const ActivateIntent(),
          const SingleActivator(LogicalKeyboardKey.arrowUp): const UpIntent(),
          const SingleActivator(LogicalKeyboardKey.arrowDown): const DownIntent(),
          const SingleActivator(LogicalKeyboardKey.arrowLeft): const LeftIntent(),
          const SingleActivator(LogicalKeyboardKey.arrowRight): const RightIntent(),
          const SingleActivator(LogicalKeyboardKey.escape): const BackIntent(),
          const SingleActivator(LogicalKeyboardKey.mediaPlayPause): const PlayPauseIntent(),
        },
        child: Actions(
          actions: {
            BackIntent: CallbackAction<BackIntent>(
              onInvoke: (intent) {
                if (_showEpisodeMenu) {
                  setState(() => _showEpisodeMenu = false);
                  _playerFocusNode.requestFocus();
                } else {
                  Navigator.pop(context);
                }
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
              // Video player area
              Focus(
                autofocus: true,
                focusNode: _playerFocusNode,
                onKeyEvent: (node, event) {
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
                        _startSeek(_seekStep); // 开始快进
                        return KeyEventResult.handled;
                      case LogicalKeyboardKey.arrowLeft:
                        _startSeek(-_seekStep); // 开始快退
                        return KeyEventResult.handled;
                      case LogicalKeyboardKey.arrowUp:
                        _increaseVolume();
                        return KeyEventResult.handled;
                      case LogicalKeyboardKey.arrowDown:
                        _decreaseVolume();
                        return KeyEventResult.handled;
                      case LogicalKeyboardKey.contextMenu:
                        _toggleEpisodeMenu();
                        return KeyEventResult.handled;
                      case LogicalKeyboardKey.escape:
                        Navigator.pop(context);
                        return KeyEventResult.handled;
                      case LogicalKeyboardKey.mediaPlayPause:
                        _togglePlayPause();
                        return KeyEventResult.handled;
                      default:
                        return KeyEventResult.ignored;
                    }
                  } else if (event is KeyUpEvent) {
                    switch (event.logicalKey) {
                      case LogicalKeyboardKey.arrowRight:
                      case LogicalKeyboardKey.arrowLeft:
                        _stopSeek(); // 停止快进/快退
                        return KeyEventResult.handled;
                    }
                  }
                  return KeyEventResult.ignored;
                },
                child: Center(
                  child: _isLoading
                      ? const CircularProgressIndicator(strokeWidth: 3)
                      : _errorMessage != null
                      ? Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.white),
                  )
                      : Chewie(controller: _chewieController!),
                ),
              ),

              // Top gradient overlay
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
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

              // Bottom controls overlay
              if (_showControls && !_showEpisodeMenu)
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
                        colors: [
                          Colors.black.withOpacity(0.8),
                          Colors.transparent,
                        ],
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
                                    icon: const Icon(Icons.skip_previous,
                                        color: Colors.white, size: 24),
                                    onPressed: _currentEpisodeIndex > 0
                                        ? () => _changeEpisode(_currentEpisodeIndex - 1)
                                        : null,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.skip_next,
                                        color: Colors.white, size: 24),
                                    onPressed: _currentEpisodeIndex < widget.episodes.length - 1
                                        ? () => _changeEpisode(_currentEpisodeIndex + 1)
                                        : null,
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.volume_up,
                                        color: Colors.white, size: 24),
                                    onPressed: () {},
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.list,
                                        color: Colors.white, size: 24),
                                    onPressed: _toggleEpisodeMenu,
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

              // Right-side episode menu
              // 在_build方法中找到选集组件部分，修改如下：
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                right: _showEpisodeMenu ? 0 : -320,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 320,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.9),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.7),
                        blurRadius: 16,
                        offset: const Offset(-8, 0),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white, size: 28),
                              onPressed: _toggleEpisodeMenu,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '选集 (${_currentEpisodeIndex + 1}/${widget.episodes.length})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(
                        color: Colors.white24,
                        height: 1,
                        thickness: 1,
                        indent: 16,
                        endIndent: 16,
                      ),
                      Expanded(
                        child: widget.episodes.isEmpty
                            ? const Center(
                            child: Text(
                              '暂无选集数据',
                              style: TextStyle(color: Colors.white54),
                            ),
                          )
                          : ListView.builder(
                              controller: _episodeMenuScrollController,
                              padding: const EdgeInsets.only(top: 8, bottom: 24),
                              itemCount: widget.episodes.length,
                              itemBuilder: (context, index) {
                                final episode = widget.episodes[index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  child: Material(
                                    color: _currentEpisodeIndex == index
                                        ? const Color(0xFF0066FF).withOpacity(0.3)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () => _changeEpisode(index),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 24,
                                              height: 24,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: _currentEpisodeIndex == index
                                                    ? const Color(0xFF0066FF)
                                                    : Colors.white24,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Text(
                                                '${index + 1}',
                                                style: TextStyle(
                                                  color: _currentEpisodeIndex == index
                                                      ? Colors.white
                                                      : Colors.white70,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                episode['title'] ?? '第${index + 1}集',
                                                style: TextStyle(
                                                  color: _currentEpisodeIndex == index
                                                      ? const Color(0xFF0066FF)
                                                      : Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: _currentEpisodeIndex == index
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (_currentEpisodeIndex == index)
                                              const Icon(
                                                Icons.play_arrow,
                                                color: Color(0xFF0066FF),
                                                size: 20,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                      ),
                    ],
                  ),
                ),
              ),

              // Fast seeking indicator
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
                        color: Colors.black.withOpacity(0.7),
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

// Custom Intents
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

class MenuIntent extends Intent {
  const MenuIntent();
}

class BackIntent extends Intent {
  const BackIntent();
}

class PlayPauseIntent extends Intent {
  const PlayPauseIntent();
}