import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '苹果CMS电影播放器',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          bodyLarge: TextStyle(fontSize: 16),
          bodyMedium: TextStyle(fontSize: 14),
        ),
      ),
      home: const SearchPage(),
    );
  }
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final Dio _dio = Dio();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<dynamic> _movies = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus) {
        // Handle focus changes
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _searchMovies(String keyword) async {
    setState(() {
      _isLoading = true;
      _movies = [];
    });

    try {
      final response = await _dio.get(
        'https://cms-api.aini.us.kg/api/search',
        queryParameters: {
          'wd': keyword,
          'limit': 100,
        },
      );

      if (response.statusCode == 200 && response.data['code'] == 1) {
        setState(() {
          _movies = response.data['list'] ?? [];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('搜索失败: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('电影搜索', style: Theme.of(context).textTheme.displaySmall),
      ),
      body: Column(
        children: [
          // Search area
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      style: Theme.of(context).textTheme.bodyLarge,
                      decoration: const InputDecoration(
                        hintText: '输入电影名称',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onSubmitted: (value) {
                        if (value.trim().isNotEmpty) {
                          _searchMovies(value.trim());
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 80,
                  height: 60,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      if (_searchController.text.trim().isNotEmpty) {
                        _searchMovies(_searchController.text.trim());
                      }
                    },
                    child: const Icon(Icons.search, size: 30),
                  ),
                ),
              ],
            ),
          ),

          // Content area
          if (_isLoading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 4),
              ),
            )
          else if (_movies.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  _searchController.text.isEmpty
                      ? '请输入搜索关键词'
                      : '没有找到相关影片',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            )
          else
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.7,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                padding: const EdgeInsets.all(16),
                itemCount: _movies.length,
                itemBuilder: (context, index) {
                  final movie = _movies[index];
                  return Focus(
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent) {
                        if (event.logicalKey == LogicalKeyboardKey.select ||
                            event.logicalKey == LogicalKeyboardKey.enter) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MovieDetailPage(
                                movie: movie,
                              ),
                            ),
                          );
                          return KeyEventResult.handled;
                        }
                      }
                      return KeyEventResult.ignored;
                    },
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MovieDetailPage(
                                movie: movie,
                              ),
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(12)),
                                child: CachedNetworkImage(
                                  imageUrl: movie['vod_pic'] ?? '',
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Center(
                                      child: CircularProgressIndicator()),
                                  errorWidget: (context, url, error) =>
                                  const Icon(Icons.error, size: 40),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    movie['vod_name'] ?? '未知标题',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${movie['vod_year'] ?? ''} · ${movie['type_name'] ?? ''}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class MovieDetailPage extends StatefulWidget {
  final dynamic movie;

  const MovieDetailPage({super.key, required this.movie});

  @override
  State<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends State<MovieDetailPage> {
  List<Map<String, String>> _episodes = [];
  final FocusNode _episodesFocusNode = FocusNode();
  final ScrollController _episodesScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _parseEpisodes();
    _episodesFocusNode.addListener(() {
      if (_episodesFocusNode.hasFocus) {
        // Handle episodes list focus
      }
    });
  }

  @override
  void dispose() {
    _episodesFocusNode.dispose();
    _episodesScrollController.dispose();
    super.dispose();
  }

  void _parseEpisodes() {
    final playUrl = widget.movie['vod_play_url'];
    if (playUrl != null && playUrl is String) {
      final parts = playUrl.split('#');
      for (var part in parts) {
        final episodeParts = part.split('\$');
        if (episodeParts.length == 2) {
          _episodes.add({
            'title': episodeParts[0],
            'url': episodeParts[1],
          });
        }
      }
    }
    setState(() {});
  }

  void _playEpisode(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenPlayerPage(
          movie: widget.movie,
          episodes: _episodes,
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.movie['vod_name'] ?? '未知标题',
            style: Theme.of(context).textTheme.displaySmall),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Movie poster and basic info
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: widget.movie['vod_pic'] ?? '',
                      width: 120,
                      height: 180,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator()),
                      errorWidget: (context, url, error) =>
                      const Icon(Icons.error, size: 40),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.movie['vod_name'] ?? '未知标题',
                          style: Theme.of(context).textTheme.displayMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${widget.movie['vod_year'] ?? ''} · ${widget.movie['type_name'] ?? ''} · ${widget.movie['vod_remarks'] ?? ''}',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '主演: ${widget.movie['vod_actor'] ?? '未知'}',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '导演: ${widget.movie['vod_director'] ?? '未知'}',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '剧情简介',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.movie['vod_content'] ??
                        widget.movie['vod_blurb'] ??
                        '暂无简介',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),

            // Episodes
            if (_episodes.isNotEmpty) ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  '选集',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ),
              const SizedBox(height: 12),
              Focus(
                focusNode: _episodesFocusNode,
                child: SizedBox(
                  height: 60,
                  child: ListView.builder(
                    controller: _episodesScrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _episodes.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 16.0),
                        child: Focus(
                          onKeyEvent: (node, event) {
                            if (event is KeyDownEvent) {
                              if (event.logicalKey ==
                                  LogicalKeyboardKey.select) {
                                _playEpisode(index);
                                return KeyEventResult.handled;
                              }
                            }
                            return KeyEventResult.ignored;
                          },
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.blue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () => _playEpisode(index),
                            child: Text(
                              _episodes[index]['title']!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge!
                                  .copyWith(color: Colors.white),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
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

  _FullScreenPlayerPageState() : _currentEpisodeIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentEpisodeIndex = widget.initialIndex;
    _initializePlayer(widget.episodes[_currentEpisodeIndex]['url']!);

    _playerFocusNode.addListener(() {
      if (_playerFocusNode.hasFocus) {
        setState(() {
          _showControls = true;
        });
        // Auto-hide controls after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && !_showEpisodeMenu) {
            setState(() {
              _showControls = false;
            });
          }
        });
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

  @override
  void dispose() {
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

      _chewieController = ChewieController(
        videoPlayerController: _controller,
        autoPlay: true,
        looping: false,
        allowFullScreen: false,
        allowedScreenSleep: false,
        showControls: false,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.blue,
          handleColor: Colors.blue,
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
        setState(() {
          _isLoading = false;
        });
      }
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
    if (index == _currentEpisodeIndex) {
      setState(() {
        _showEpisodeMenu = false;
        _playerFocusNode.requestFocus();
      });
      return;
    }

    setState(() {
      _currentEpisodeIndex = index;
      _isLoading = true;
      _errorMessage = null;
      _showEpisodeMenu = false;
    });

    await _controller.dispose();
    _chewieController?.dispose();
    await _initializePlayer(widget.episodes[index]['url']!);

    // Return focus to player after changing episode
    _playerFocusNode.requestFocus();
  }

  void _togglePlayPause() {
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
  }

  void _seekForward() {
    final newPosition = _controller.value.position + const Duration(seconds: 10);
    _controller.seekTo(newPosition > _controller.value.duration
        ? _controller.value.duration
        : newPosition);
  }

  void _seekBackward() {
    final newPosition = _controller.value.position - const Duration(seconds: 10);
    _controller.seekTo(newPosition < Duration.zero ? Duration.zero : newPosition);
  }

  void _increaseVolume() {
    _controller.setVolume(_controller.value.volume + 0.1);
  }

  void _decreaseVolume() {
    _controller.setVolume(_controller.value.volume - 0.1);
  }

  void _toggleEpisodeMenu() {
    setState(() {
      _showEpisodeMenu = !_showEpisodeMenu;
      if (_showEpisodeMenu) {
        _episodeMenuFocusNode.requestFocus();
      } else {
        _playerFocusNode.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Shortcuts(
        shortcuts: {
          const SingleActivator(LogicalKeyboardKey.select): const ActivateIntent(),
          const SingleActivator(LogicalKeyboardKey.arrowUp): const UpIntent(),
          const SingleActivator(LogicalKeyboardKey.arrowDown): const DownIntent(),
          const SingleActivator(LogicalKeyboardKey.arrowLeft): const LeftIntent(),
          const SingleActivator(LogicalKeyboardKey.arrowRight): const RightIntent(),
          const SingleActivator(LogicalKeyboardKey.contextMenu): const MenuIntent(),
          const SingleActivator(LogicalKeyboardKey.escape): const BackIntent(),
        },
        child: Actions(
          actions: {
            BackIntent: CallbackAction<BackIntent>(
              onInvoke: (intent) {
                if (_showEpisodeMenu) {
                  setState(() {
                    _showEpisodeMenu = false;
                    _playerFocusNode.requestFocus();
                  });
                } else {
                  Navigator.pop(context);
                }
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
                  if (event is KeyDownEvent) {
                    if (event.logicalKey == LogicalKeyboardKey.select) {
                      _togglePlayPause();
                      return KeyEventResult.handled;
                    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                      _seekForward();
                      return KeyEventResult.handled;
                    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                      _seekBackward();
                      return KeyEventResult.handled;
                    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                      _increaseVolume();
                      return KeyEventResult.handled;
                    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                      _decreaseVolume();
                      return KeyEventResult.handled;
                    } else if (event.logicalKey == LogicalKeyboardKey.contextMenu) {
                      _toggleEpisodeMenu();
                      return KeyEventResult.handled;
                    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                      Navigator.pop(context);
                      return KeyEventResult.handled;
                    }
                  }
                  return KeyEventResult.ignored;
                },
                child: Center(
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : _errorMessage != null
                      ? Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.white),
                  )
                      : Chewie(controller: _chewieController!),
                ),
              ),

              // Bottom controls overlay
              if (_showControls && !_showEpisodeMenu)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 100,
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
                      children: [
                        // Progress bar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: VideoProgressIndicator(
                            _controller,
                            allowScrubbing: true,
                            colors: VideoProgressColors(
                              playedColor: Colors.blue,
                              bufferedColor: Colors.grey,
                              backgroundColor: Colors.grey[600]!,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Control buttons
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Left side controls
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      _controller.value.isPlaying
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                      color: Colors.white,
                                    ),
                                    onPressed: _togglePlayPause,
                                  ),
                                  const SizedBox(width: 16),
                                  IconButton(
                                    icon: const Icon(Icons.skip_previous,
                                        color: Colors.white),
                                    onPressed: _currentEpisodeIndex > 0
                                        ? () => _changeEpisode(
                                        _currentEpisodeIndex - 1)
                                        : null,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.skip_next,
                                        color: Colors.white),
                                    onPressed: _currentEpisodeIndex <
                                        widget.episodes.length - 1
                                        ? () => _changeEpisode(
                                        _currentEpisodeIndex + 1)
                                        : null,
                                  ),
                                ],
                              ),
                              // Right side controls
                              IconButton(
                                icon: const Icon(Icons.list, color: Colors.white),
                                onPressed: _toggleEpisodeMenu,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Right-side episode menu
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                right: _showEpisodeMenu ? 0 : -300,
                top: 0,
                bottom: 0,
                child: Focus(
                  focusNode: _episodeMenuFocusNode,
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent) {
                      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                        // Scroll up in episode list
                        if (_currentEpisodeIndex > 0) {
                          setState(() {
                            _currentEpisodeIndex--;
                          });
                          _episodeMenuScrollController.animateTo(
                            (_currentEpisodeIndex * 56.0).clamp(
                              0.0,
                              _episodeMenuScrollController.position.maxScrollExtent,
                            ),
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                        }
                        return KeyEventResult.handled;
                      } else if (event.logicalKey ==
                          LogicalKeyboardKey.arrowDown) {
                        // Scroll down in episode list
                        if (_currentEpisodeIndex < widget.episodes.length - 1) {
                          setState(() {
                            _currentEpisodeIndex++;
                          });
                          _episodeMenuScrollController.animateTo(
                            (_currentEpisodeIndex * 56.0).clamp(
                              0.0,
                              _episodeMenuScrollController.position.maxScrollExtent,
                            ),
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                        }
                        return KeyEventResult.handled;
                      } else if (event.logicalKey ==
                          LogicalKeyboardKey.select) {
                        // Select current highlighted episode
                        _changeEpisode(_currentEpisodeIndex);
                        return KeyEventResult.handled;
                      } else if (event.logicalKey ==
                          LogicalKeyboardKey.contextMenu) {
                        // Close episode menu
                        _toggleEpisodeMenu();
                        return KeyEventResult.handled;
                      } else if (event.logicalKey ==
                          LogicalKeyboardKey.escape) {
                        // Close episode menu
                        _toggleEpisodeMenu();
                        return KeyEventResult.handled;
                      }
                    }
                    return KeyEventResult.ignored;
                  },
                  child: Container(
                    width: 300,
                    color: Colors.black.withOpacity(0.9),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            '选集 (${_currentEpisodeIndex + 1}/${widget.episodes.length})',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            controller: _episodeMenuScrollController,
                            itemCount: widget.episodes.length,
                            itemBuilder: (context, index) {
                              return ListTile(
                                title: Text(
                                  widget.episodes[index]['title']!,
                                  style: TextStyle(
                                    color: _currentEpisodeIndex == index
                                        ? Colors.blue
                                        : Colors.white,
                                    fontWeight: _currentEpisodeIndex == index
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                selected: _currentEpisodeIndex == index,
                                onTap: () => _changeEpisode(index),
                              );
                            },
                          ),
                        ),
                      ],
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