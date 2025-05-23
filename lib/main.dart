import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '苹果CMS电影播放器',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        textTheme: TextTheme(
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
      home: SearchPage(),
    );
  }
}

class SearchPage extends StatefulWidget {
  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final Dio _dio = Dio();
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _movies = [];
  bool _isLoading = false;
  FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus) {
        // 当搜索框获得焦点时，可以添加额外逻辑
      }
    });
  }

  @override
  void dispose() {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('搜索失败: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
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
          // 搜索区域
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
                      decoration: InputDecoration(
                        hintText: '输入电影名称',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Container(
                  width: 80,
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      if (_searchController.text.trim().isNotEmpty) {
                        _searchMovies(_searchController.text.trim());
                      }
                    },
                    child: Icon(Icons.search, size: 30),
                  ),
                ),
              ],
            ),
          ),

          // 内容区域
          _isLoading
              ? Expanded(child: Center(child: CircularProgressIndicator(strokeWidth: 4)))
              : _movies.isEmpty
              ? Expanded(
            child: Center(
              child: Text(
                _searchController.text.isEmpty
                    ? '请输入搜索关键词'
                    : '没有找到相关影片',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          )
              : Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.7,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              padding: EdgeInsets.all(16),
              itemCount: _movies.length,
              itemBuilder: (context, index) {
                final movie = _movies[index];
                return Focus(
                  onKey: (node, event) {
                    if (event is RawKeyDownEvent) {
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
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(12)),
                              child: CachedNetworkImage(
                                imageUrl: movie['vod_pic'] ?? '',
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Center(
                                    child: CircularProgressIndicator()),
                                errorWidget: (context, url, error) =>
                                    Icon(Icons.error, size: 40),
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
                                SizedBox(height: 4),
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

  const MovieDetailPage({Key? key, required this.movie}) : super(key: key);

  @override
  _MovieDetailPageState createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends State<MovieDetailPage> {
  late VideoPlayerController _controller;
  ChewieController? _chewieController;
  int _selectedEpisode = 0;
  List<Map<String, String>> _episodes = [];
  bool _isLoading = true;
  String? _errorMessage;
  FocusNode _playbackFocusNode = FocusNode();
  FocusNode _episodesFocusNode = FocusNode();
  ScrollController _episodesScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _parseEpisodes();
    if (_episodes.isNotEmpty) {
      _initializePlayer(_episodes[0]['url']!);
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = '暂无播放资源';
      });
    }

    _playbackFocusNode.addListener(() {
      if (_playbackFocusNode.hasFocus) {
        // 播放器获得焦点时的逻辑
      }
    });

    _episodesFocusNode.addListener(() {
      if (_episodesFocusNode.hasFocus) {
        // 选集列表获得焦点时的逻辑
      }
    });
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
  }

  Future<void> _initializePlayer(String url) async {
    try {
      _controller = VideoPlayerController.network(url);
      await _controller.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _controller,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowedScreenSleep: false,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.blue,
          handleColor: Colors.blue,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.grey[300]!,
        ),
        customControls: const TVChewieControls(),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              errorMessage,
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
          );
        },
      );

      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '播放失败: ${e.toString()}';
      });
    }
  }

  void _changeEpisode(int index) async {
    if (index == _selectedEpisode) return;

    setState(() {
      _selectedEpisode = index;
      _isLoading = true;
      _errorMessage = null;
    });

    await _controller.dispose();
    _chewieController?.dispose();
    await _initializePlayer(_episodes[index]['url']!);
  }

  @override
  void dispose() {
    _controller.dispose();
    _chewieController?.dispose();
    _playbackFocusNode.dispose();
    _episodesFocusNode.dispose();
    _episodesScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.movie['vod_name'] ?? '未知标题', style: Theme.of(context).textTheme.displaySmall),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 播放器区域
            Focus(
              focusNode: _playbackFocusNode,
              child: Container(
                color: Colors.black,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _isLoading
                      ? Center(child: CircularProgressIndicator(strokeWidth: 4))
                      : _errorMessage != null
                      ? Center(
                    child: Text(
                      _errorMessage!,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium!
                          .copyWith(color: Colors.white),
                    ),
                  )
                      : _chewieController != null
                      ? Chewie(controller: _chewieController!)
                      : Container(),
                ),
              ),
            ),

            // 影片信息
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.movie['vod_name'] ?? '未知标题',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  SizedBox(height: 12),
                  Text(
                    '${widget.movie['vod_year'] ?? ''} · ${widget.movie['type_name'] ?? ''} · ${widget.movie['vod_remarks'] ?? ''}',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  SizedBox(height: 24),
                  Text(
                    '主演: ${widget.movie['vod_actor'] ?? '未知'}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  SizedBox(height: 12),
                  Text(
                    '导演: ${widget.movie['vod_director'] ?? '未知'}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  SizedBox(height: 24),
                  Text(
                    '剧情简介',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  SizedBox(height: 12),
                  Text(
                    widget.movie['vod_content'] ?? widget.movie['vod_blurb'] ?? '暂无简介',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),

                  // 选集
                  if (_episodes.isNotEmpty) ...[
                    SizedBox(height: 24),
                    Text(
                      '选集',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    SizedBox(height: 12),
                    Focus(
                      focusNode: _episodesFocusNode,
                      child: Container(
                        height: 60,
                        child: ListView.builder(
                          controller: _episodesScrollController,
                          scrollDirection: Axis.horizontal,
                          itemCount: _episodes.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 16.0),
                              child: Focus(
                                onKey: (node, event) {
                                  if (event is RawKeyDownEvent) {
                                    if (event.logicalKey ==
                                        LogicalKeyboardKey.select) {
                                      _changeEpisode(index);
                                      return KeyEventResult.handled;
                                    }
                                  }
                                  return KeyEventResult.ignored;
                                },
                                child: ChoiceChip(
                                  label: Text(
                                    _episodes[index]['title']!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge!
                                        .copyWith(
                                        color: _selectedEpisode == index
                                            ? Colors.white
                                            : null),
                                  ),
                                  selected: _selectedEpisode == index,
                                  onSelected: (_) => _changeEpisode(index),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 8),
                                  selectedColor: Colors.blue,
                                  labelPadding: EdgeInsets.zero,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TVChewieControls extends StatelessWidget {
  const TVChewieControls({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ChewieController chewieController = ChewieController.of(context);
    final VideoPlayerController videoPlayerController =
        chewieController.videoPlayerController;

    return Stack(
      children: [
        Center(
          child: IconButton(
            iconSize: 60,
            icon: Icon(
              videoPlayerController.value.isPlaying
                  ? Icons.pause
                  : Icons.play_arrow,
              color: Colors.white,
            ),
            onPressed: () {
              videoPlayerController.value.isPlaying
                  ? videoPlayerController.pause()
                  : videoPlayerController.play();
            },
          ),
        ),

        Positioned(
          left: 0,
          right: 0,
          bottom: 40,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: VideoProgressIndicator(
              videoPlayerController,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: Colors.blue,
                bufferedColor: Colors.grey,
                backgroundColor: Colors.grey[600]!,
              ),
            ),
          ),
        ),

        Positioned(
          right: 16,
          bottom: 16,
          child: IconButton(
            iconSize: 40,
            icon: Icon(
              chewieController.isFullScreen
                  ? Icons.fullscreen_exit
                  : Icons.fullscreen,
              color: Colors.white,
            ),
            onPressed: () {
              chewieController.toggleFullScreen();
            },
          ),
        ),
      ],
    );
  }
}