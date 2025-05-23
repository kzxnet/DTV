import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '苹果CMS电影播放器',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0066FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(const TextTheme(
          displayLarge: TextStyle(
              fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5),
          displayMedium: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: -0.5),
          displaySmall: TextStyle(
              fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.5),
          headlineMedium: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.5),
          headlineSmall: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.5),
          titleLarge: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.5),
          bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        )).apply(
          displayColor: Colors.white,
          bodyColor: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          scrolledUnderElevation: 4,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          surfaceTintColor: Colors.transparent,
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
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
          SnackBar(
            content: Text('搜索失败: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '电影搜索',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              if (_searchController.text.trim().isNotEmpty) {
                _searchMovies(_searchController.text.trim());
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: InputDecoration(
                  hintText: '输入电影名称...',
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search, color: colorScheme.onSurface),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                    icon: Icon(Icons.clear, color: colorScheme.onSurface),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _movies = [];
                      });
                    },
                  )
                      : null,
                ),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    _searchMovies(value.trim());
                  }
                },
              ),
            ),
          ),

          // Content area
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _isLoading
                  ? const Center(
                child: CircularProgressIndicator(strokeWidth: 3),
              )
                  : _movies.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.movie_creation_outlined,
                      size: 64,
                      color: colorScheme.onSurface.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _searchController.text.isEmpty
                          ? '搜索您想看的电影'
                          : '没有找到相关影片',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium!
                          .copyWith(
                        color: colorScheme.onSurface
                            .withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              )
                  : GridView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.65,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _movies.length,
                itemBuilder: (context, index) {
                  final movie = _movies[index];
                  return Focus(
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent) {
                        if (event.logicalKey ==
                            LogicalKeyboardKey.select ||
                            event.logicalKey ==
                                LogicalKeyboardKey.enter) {
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
                      clipBehavior: Clip.antiAlias,
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
                          crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Hero(
                                tag: 'poster-${movie['vod_id']}',
                                child: ClipRRect(
                                  borderRadius:
                                  const BorderRadius.vertical(
                                      top: Radius.circular(12)),
                                  child: CachedNetworkImage(
                                    imageUrl: movie['vod_pic'] ?? '',
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) =>
                                        Container(
                                          color: colorScheme.surface,
                                          child: const Center(
                                            child:
                                            CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                                    errorWidget:
                                        (context, url, error) =>
                                        Container(
                                          color: colorScheme.surface,
                                          child: const Center(
                                            child: Icon(
                                              Icons.error_outline,
                                              size: 32,
                                            ),
                                          ),
                                        ),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
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
                                        .bodyMedium!
                                        .copyWith(
                                      color: colorScheme.onSurface
                                          .withOpacity(0.7),
                                    ),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.movie['vod_name'] ?? '未知标题',
          style: Theme.of(context).textTheme.displaySmall,
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Movie header
            Container(
              height: 240,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colorScheme.surface.withOpacity(0.8),
                    colorScheme.surface,
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Hero(
                      tag: 'poster-${widget.movie['vod_id']}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: widget.movie['vod_pic'] ?? '',
                          width: 120,
                          height: 180,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: colorScheme.surface,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: colorScheme.surface,
                            child: const Center(
                              child: Icon(Icons.error_outline, size: 32),
                            ),
                          ),
                        ),
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
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (widget.movie['vod_year'] != null)
                                Chip(
                                  label: Text(widget.movie['vod_year']!),
                                  visualDensity: VisualDensity.compact,
                                ),
                              if (widget.movie['type_name'] != null)
                                Chip(
                                  label: Text(widget.movie['type_name']!),
                                  visualDensity: VisualDensity.compact,
                                ),
                              if (widget.movie['vod_remarks'] != null)
                                Chip(
                                  label: Text(widget.movie['vod_remarks']!),
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
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
            ),

            // Description
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '剧情简介',
                    style: Theme.of(context).textTheme.headlineMedium,
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  '选集',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: Focus(
                  focusNode: _episodesFocusNode,
                  child: ListView.builder(
                    controller: _episodesScrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _episodes.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 12.0),
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
                          child: FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                            onPressed: () => _playEpisode(index),
                            child: Text(
                              _episodes[index]['title']!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge!
                                  .copyWith(
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
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
        _controlWakelock(isPlaying); // 统一控制
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
    _controller.removeListener(() {});
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
    // 边界检查
    if (widget.episodes.isEmpty) return;
    if (index < 0 || index >= widget.episodes.length) return;
    if (index == _currentEpisodeIndex) {
      setState(() {
        _showEpisodeMenu = false;
      });
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

    // 释放旧资源
    try {
      await _controller?.pause();
      await _controller?.dispose();
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
      // 初始化新控制器
      _controller = VideoPlayerController.network(url);
      await _controller.initialize();
      _setupWakelockListener();

      _chewieController = ChewieController(
        videoPlayerController: _controller,
        autoPlay: true,
        looping: false,
        // 其他配置...
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
      debugPrint('初始化播放器错误: $e');
    }

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
    final colorScheme = Theme.of(context).colorScheme;

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
                        // Progress bar
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
                                      size: 28,
                                    ),
                                    onPressed: _togglePlayPause,
                                  ),
                                  const SizedBox(width: 16),
                                  IconButton(
                                    icon: const Icon(Icons.skip_previous,
                                        color: Colors.white, size: 24),
                                    onPressed: _currentEpisodeIndex > 0
                                        ? () => _changeEpisode(
                                        _currentEpisodeIndex - 1)
                                        : null,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.skip_next,
                                        color: Colors.white, size: 24),
                                    onPressed: _currentEpisodeIndex <
                                        widget.episodes.length - 1
                                        ? () => _changeEpisode(
                                        _currentEpisodeIndex + 1)
                                        : null,
                                  ),
                                ],
                              ),
                              // Right side controls
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
                                _episodeMenuScrollController.position
                                    .maxScrollExtent,
                              ),
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          }
                          return KeyEventResult.handled;
                        } else if (event.logicalKey ==
                            LogicalKeyboardKey.arrowDown) {
                          // Scroll down in episode list
                          if (_currentEpisodeIndex <
                              widget.episodes.length - 1) {
                            setState(() {
                              _currentEpisodeIndex++;
                            });
                            _episodeMenuScrollController.animateTo(
                              (_currentEpisodeIndex * 56.0).clamp(
                                0.0,
                                _episodeMenuScrollController.position
                                    .maxScrollExtent,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.white),
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
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Material(
                                  color: _currentEpisodeIndex == index
                                      ? const Color(0xFF0066FF)
                                      .withOpacity(0.2)
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
                                                color: _currentEpisodeIndex ==
                                                    index
                                                    ? const Color(0xFF0066FF)
                                                    : Colors.white,
                                                fontWeight:
                                                _currentEpisodeIndex == index
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