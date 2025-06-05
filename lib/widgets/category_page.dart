import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:libretv_app/widgets/search_page.dart';

class MovieHomePage extends StatefulWidget {
  const MovieHomePage({super.key});

  @override
  State<MovieHomePage> createState() => _MovieHomePageState();
}

class _MovieHomePageState extends State<MovieHomePage> {
  final Dio _dio = Dio();
  int _selectedTab = 0;
  bool _isLoading = false;
  List<String> _tabs = ['加载中...']; // Initialize with loading state
  List<Movie> _movies = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await _fetchTags(); // First fetch tags
    if (_tabs.isNotEmpty && _tabs[0] != '加载中...') {
      await _fetchMovies(_tabs[_selectedTab]);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _fetchTags() async {
    try {
      final response = await _dio.get(
        'http://localhost:8023/api/tags', // Replace with your actual API URL
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> tags = response.data;
        setState(() {
          _tabs = tags.map((tag) => tag['name'].toString()).toList();
        });
      }
    } catch (e) {
      debugPrint('获取标签失败: $e');
      setState(() {
        _tabs = ['获取标签失败'];
      });
    }
  }

  Future<void> _fetchMovies(String tag) async {
    try {
      setState(() => _isLoading = true);

      final response = await _dio.get(
        'https://movie.douban.com/j/search_subjects',
        queryParameters: {
          'type': 'movie',
          'tag': tag,
          'sort': 'recommend',
          'page_limit': '20',
          'page_start': '0',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> subjects = response.data['subjects'] ?? [];
        final List<Movie> movies = subjects.map((subject) {
          print(subject['cover']);
          return Movie(
            id: subject['id'],
            title: subject['title'],
            year: _extractYearFromTitle(subject['title']),
            rating: double.tryParse(subject['rate'] ?? '0') ?? 0,
            coverUrl: subject['cover'],
            playable: subject['playable'] ?? false,
            isNew: subject['is_new'] ?? false,
            url: "https://img3.doubanio.com/view/photo/s_ratio_poster/public/p2897743122.jpg",
          );
        }).toList();

        setState(() {
          _movies = movies;
        });
      }
    } catch (e) {
      debugPrint('获取电影失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  int _extractYearFromTitle(String title) {
    try {
      // 尝试从标题中提取年份，例如 "电影名 (2023)"
      final match = RegExp(r'$(\d{4})$').firstMatch(title);
      if (match != null) {
        return int.parse(match.group(1)!);
      }
      return DateTime.now().year;
    } catch (e) {
      return DateTime.now().year;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            _buildTabBar(),
            if (_isLoading)
              Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_movies.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    _tabs[0] == '获取标签失败'
                        ? '无法加载标签，请检查网络连接'
                        : '没有找到电影数据',
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                ),
              )
            else
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: _buildMovieGrid(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<String> _getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            return addr.address;
          }
        }
      }
      return '127.0.0.1';
    } catch (e) {
      debugPrint('获取IP失败: $e');
      return '127.0.0.1';
    }
  }

  void _showQRCodeDialog() async {
    final ip = await _getLocalIp();
    final url = 'http://$ip:8023';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text('扫描二维码管理', style: TextStyle(color: Colors.white,),textAlign: TextAlign.center,),
        content: Container(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(
                data: url,
                version: QrVersions.auto,
                size: 200.0,
                backgroundColor: Colors.white,
              ),
              SizedBox(height: 16),
              Text(url, style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('关闭', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.only(top: 5,right: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            icon: Icon(Icons.search, size: 20),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SearchPage()),
              );
            },
            focusColor: Colors.red,
          ),
          SizedBox(width: 10),
          IconButton(
            icon: Icon(Icons.settings, size: 20),
            onPressed: _showQRCodeDialog,
            focusColor: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 70,
      padding: EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 30),
        itemCount: _tabs.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Focus(
              autofocus: index == _selectedTab,
              onFocusChange: (hasFocus) {
                if (hasFocus) {
                  setState(() => _selectedTab = index);
                  _fetchMovies(_tabs[index]);
                }
              },
              child: Builder(
                builder: (context) {
                  final isFocused = Focus.of(context).hasFocus;
                  return AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    constraints: BoxConstraints(
                      minWidth: 100,
                    ),
                    decoration: BoxDecoration(
                      color: _selectedTab == index
                          ? Colors.red
                          : Color(0xFF333333),
                      borderRadius: BorderRadius.circular(35),
                      border: isFocused
                          ? Border.all(color: Colors.white, width: 2)
                          : null,
                    ),
                    child: SizedBox(
                      height: double.infinity,
                      child: Center(
                        child: Text(
                          _tabs[index],
                          style: TextStyle(
                            color: _selectedTab == index
                                ? Colors.white
                                : Colors.grey,
                            fontSize: 20,
                            height: 1.0,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMovieGrid() {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 0.65,
        mainAxisSpacing: 30,
        crossAxisSpacing: 30,
      ),
      itemCount: _movies.length,
      itemBuilder: (context, index) {
        return FocusableMovieCard(movie: _movies[index]);
      },
      padding: EdgeInsets.only(left: 20,top: 20,right: 20),
    );
  }
}

class Movie {
  final String id;
  final String title;
  final int year;
  final double rating;
  final String? coverUrl;
  final bool playable;
  final bool isNew;
  final String url;

  Movie({
    required this.id,
    required this.title,
    required this.year,
    required this.rating,
    this.coverUrl,
    required this.playable,
    required this.isNew,
    required this.url,
  });
}

class FocusableMovieCard extends StatefulWidget {
  final Movie movie;

  const FocusableMovieCard({super.key, required this.movie});

  @override
  State<FocusableMovieCard> createState() => _FocusableMovieCardState();
}

class _FocusableMovieCardState extends State<FocusableMovieCard> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SearchPage(initialQuery: widget.movie.title),
            ),
          );
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      onFocusChange: (hasFocus) {
        setState(() => _isFocused = hasFocus);
      },
      child: AnimatedScale(
        duration: Duration(milliseconds: 150),
        scale: _isFocused ? 1.02 : 1.0,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: _isFocused
                ? Border.all(
              color: Colors.white,
              width: 2.0,
            )
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 4, // Increased flex to give more space to the image
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Color(0xFF262626),
                    ),
                    child: widget.movie.coverUrl != null
                        ? CachedNetworkImage(
                      imageUrl: widget.movie.coverUrl!,
                      httpHeaders: {
                        'User-Agent':
                        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                        'Accept':
                        'image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
                      },
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (context, url) => Container(
                        color: Color(0xFF333333),
                        child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 3.0,
                            )),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Color(0xFF333333),
                        child: Center(
                            child: Icon(Icons.broken_image,
                                color: Colors.grey, size: 36)),
                      ),
                    )
                        : Container(
                      color: Color(0xFF333333),
                      child: Center(
                        child: Text(
                          widget.movie.title.split(' ').first,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Container( // Changed from Expanded to Container with fixed height
                height: 70, // Fixed height for the bottom section
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Color(0xFF262626),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, // This will push content to top and bottom
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.movie.title,
                      style: TextStyle(
                        fontSize: 18, // Slightly smaller font
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${widget.movie.year}',
                          style: TextStyle(
                            fontSize: 16, // Slightly smaller font
                            color: Colors.grey,
                          ),
                        ),
                        Row(
                          children: [
                            Icon(Icons.star, size: 16, color: Colors.amber), // Smaller icon
                            SizedBox(width: 4), // Reduced spacing
                            Text(
                              '${widget.movie.rating}',
                              style: TextStyle(
                                fontSize: 16, // Slightly smaller font
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}