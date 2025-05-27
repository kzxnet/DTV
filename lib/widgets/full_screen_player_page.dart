import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:keyboard_dismisser/keyboard_dismisser.dart';

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

  void _togglePlayPause() {
    setState(() => _showControls = true);
    _startControlsAutoHideTimer();
    _controller.value.isPlaying ? _controller.pause() : _controller.play();
  }

  void _seekForward() => _handleSeek(const Duration(seconds: 10));
  void _seekBackward() => _handleSeek(const Duration(seconds: -10));

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
    return KeyboardDismisser(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Shortcuts(
          shortcuts: {
            const SingleActivator(LogicalKeyboardKey.select): const ActivateIntent(),
            const SingleActivator(LogicalKeyboardKey.enter): const ActivateIntent(),
            const SingleActivator(LogicalKeyboardKey.arrowUp): const UpIntent(),
            const SingleActivator(LogicalKeyboardKey.arrowDown): const DownIntent(),
            const SingleActivator(LogicalKeyboardKey.arrowLeft): const LeftIntent(),
            const SingleActivator(LogicalKeyboardKey.arrowRight): const RightIntent(),
            const SingleActivator(LogicalKeyboardKey.contextMenu): const MenuIntent(),
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
                          _seekForward();
                          return KeyEventResult.handled;
                        case LogicalKeyboardKey.arrowLeft:
                          _seekBackward();
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
                      height: 120,
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
                          const SizedBox(height: 12),
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
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  right: _showEpisodeMenu ? 0 : -320,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 320,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.85),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 16,
                          offset: const Offset(-8, 0),
                        ),
                      ],
                    ),
                    child: Focus(
                      focusNode: _episodeMenuFocusNode,
                      skipTraversal: false,
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent) {
                          switch (event.logicalKey) {
                            case LogicalKeyboardKey.arrowUp:
                              if (_currentEpisodeIndex > 0) {
                                setState(() => _currentEpisodeIndex--);
                                _scrollToCurrentItem();
                              }
                              return KeyEventResult.handled;
                            case LogicalKeyboardKey.arrowDown:
                              if (_currentEpisodeIndex < widget.episodes.length - 1) {
                                setState(() => _currentEpisodeIndex++);
                                _scrollToCurrentItem();
                              }
                              return KeyEventResult.handled;
                            case LogicalKeyboardKey.select:
                            case LogicalKeyboardKey.enter:
                              _changeEpisode(_currentEpisodeIndex);
                              return KeyEventResult.handled;
                            case LogicalKeyboardKey.contextMenu:
                            case LogicalKeyboardKey.escape:
                              _toggleEpisodeMenu();
                              return KeyEventResult.handled;
                            default:
                              return KeyEventResult.handled;
                          }
                        }
                        return KeyEventResult.handled;
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white),
                                  onPressed: _toggleEpisodeMenu,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '选集',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium!
                                      .copyWith(color: Colors.white),
                                ),
                                const Spacer(),
                                Text(
                                  '${_currentEpisodeIndex + 1}/${widget.episodes.length}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge!
                                      .copyWith(
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              controller: _episodeMenuScrollController,
                              padding: const EdgeInsets.only(bottom: 16),
                              itemCount: widget.episodes.length,
                              itemBuilder: (context, index) {
                                return Focus(
                                  autofocus: index == _currentEpisodeIndex,
                                  onKeyEvent: (node, event) {
                                    if (event is KeyDownEvent) {
                                      if (event.logicalKey == LogicalKeyboardKey.select ||
                                          event.logicalKey == LogicalKeyboardKey.enter) {
                                        _changeEpisode(index);
                                        return KeyEventResult.handled;
                                      }
                                    }
                                    return KeyEventResult.ignored;
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    child: Material(
                                      color: _currentEpisodeIndex == index
                                          ? const Color(0xFF0066FF).withOpacity(0.2)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () => _changeEpisode(index),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Row(
                                            children: [
                                              if (_currentEpisodeIndex == index)
                                                const Icon(
                                                  Icons.play_arrow,
                                                  color: Color(0xFF0066FF),
                                                  size: 20,
                                                ),
                                              if (_currentEpisodeIndex == index)
                                                const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  widget.episodes[index]['title']!,
                                                  style: TextStyle(
                                                    color: _currentEpisodeIndex == index
                                                        ? const Color(0xFF0066FF)
                                                        : Colors.white,
                                                    fontWeight: _currentEpisodeIndex == index
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
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
                ),

                // Fast seeking indicator
                if (_isFastSeeking)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 120,
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