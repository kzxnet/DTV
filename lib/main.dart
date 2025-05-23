import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';

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

  Future<void> _searchMovies(String keyword) async {
    setState(() {
      _isLoading = true;
      _movies = [];
    });

    try {
      final response = await _dio.get(
        "https://bfzyapi.com/api.php/provide/vod",
        queryParameters: {'ac': 'videolist', 'wd': keyword},
      );

      if (response.data['code'] == 1) {
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
      appBar: AppBar(title: Text('电影搜索')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '输入电影名称',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.search),
                  onPressed: () {
                    if (_searchController.text.trim().isNotEmpty) {
                      _searchMovies(_searchController.text.trim());
                    }
                  },
                ),
              ],
            ),
          ),
          _isLoading
              ? Expanded(child: Center(child: CircularProgressIndicator()))
              : _movies.isEmpty
              ? Expanded(
            child: Center(
              child: Text(
                _searchController.text.isEmpty
                    ? '请输入搜索关键词'
                    : '没有找到相关影片',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          )
              : Expanded(
            child: ListView.builder(
              itemCount: _movies.length,
              itemBuilder: (context, index) {
                final movie = _movies[index];
                return Card(
                  margin: EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  child: ListTile(
                    leading: CachedNetworkImage(
                      imageUrl: movie['vod_pic'],
                      width: 60,
                      height: 80,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Center(
                          child: CircularProgressIndicator()),
                      errorWidget: (context, url, error) =>
                          Icon(Icons.error),
                    ),
                    title: Text(movie['vod_name']),
                    subtitle: Text(
                        '${movie['vod_year']} · ${movie['type_name']}'),
                    trailing: Icon(Icons.chevron_right),
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
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              errorMessage,
              style: TextStyle(color: Colors.white),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.movie['vod_name'])),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 播放器区域
            if (_isLoading)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Center(
                  child: Text(
                    _errorMessage!,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              )
            else if (_chewieController != null)
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Chewie(controller: _chewieController!),
                ),

            // 影片信息
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.movie['vod_name'],
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  SizedBox(height: 8),
                  Text(
                    '${widget.movie['vod_year']} · ${widget.movie['type_name']} · ${widget.movie['vod_remarks']}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SizedBox(height: 16),
                  Text(
                    '主演: ${widget.movie['vod_actor']}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  SizedBox(height: 8),
                  Text(
                    '导演: ${widget.movie['vod_director']}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  SizedBox(height: 16),
                  Text(
                    '剧情简介',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  SizedBox(height: 8),
                  Text(
                    widget.movie['vod_content'],
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),

                  // 选集
                  if (_episodes.isNotEmpty) ...[
                    SizedBox(height: 16),
                    Text(
                      '选集',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(_episodes.length, (index) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(_episodes[index]['title']!),
                              selected: _selectedEpisode == index,
                              onSelected: (_) => _changeEpisode(index),
                            ),
                          );
                        }),
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