import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:libretv_app/widgets/search_page.dart';

class MovieHomePage extends StatefulWidget {
  @override
  _MovieHomePageState createState() => _MovieHomePageState();
}

class _MovieHomePageState extends State<MovieHomePage> {
  final Dio _dio = Dio();
  int _selectedTab = 0;
  bool _isLoading = false;
  final List<String> _tabs = ['动作', '喜剧', '科幻', '恐怖', '爱情', '悬疑', '动画', '纪录片', '战争', '港剧'
  ];
  List<Movie> _movies = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await _fetchMovies(_tabs[_selectedTab]);
    setState(() => _isLoading = false);
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
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5, vertical: 10),
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
      height: 70, // 进一步增加高度
      padding: EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 30), // 增加水平内边距
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
                      horizontal: 24, // 增加水平内边距
                      vertical: 12,  // 增加垂直内边距
                    ),
                    constraints: BoxConstraints(
                      minWidth: 100, // 设置最小宽度
                    ),
                    decoration: BoxDecoration(
                      color: _selectedTab == index
                          ? Colors.red
                          : Color(0xFF333333),
                      borderRadius: BorderRadius.circular(35), // 增大圆角
                      border: isFocused
                          ? Border.all(color: Colors.white, width: 2) // 加粗边框
                          : null,
                      boxShadow: isFocused
                          ? [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.4),
                          blurRadius: 15,
                          spreadRadius: 3,
                        )
                      ]
                          : [],
                    ),
                    child: Center(
                      child: Text(
                        _tabs[index],
                        style: TextStyle(
                          color: _selectedTab == index
                              ? Colors.white
                              : Colors.grey,
                          fontWeight: _selectedTab == index
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 20, // 进一步增大字体
                          height: 1.2, // 调整行高
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.visible, // 确保文本不会被裁剪
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
        childAspectRatio: 0.65, // 调整为更适合电视的宽高比
        mainAxisSpacing: 30, // 增加行间距
        crossAxisSpacing: 30, // 增加列间距
      ),
      itemCount: _movies.length,
      itemBuilder: (context, index) {
        return FocusableMovieCard(movie: _movies[index]);
      },
      padding: EdgeInsets.all(10),
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

  const FocusableMovieCard({Key? key, required this.movie}) : super(key: key);

  @override
  _FocusableMovieCardState createState() => _FocusableMovieCardState();
}

class _FocusableMovieCardState extends State<FocusableMovieCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) {
        setState(() => _isFocused = hasFocus);
      },
      child: AnimatedScale(
        duration: Duration(milliseconds: 150),
        scale: _isFocused ? 1.02 : 1.0, // 增大焦点时的缩放比例
        child: AnimatedContainer(
          duration: Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12), // 增大圆角
            boxShadow: _isFocused
                ? [
              BoxShadow(
                color: Colors.white.withOpacity(0.5), // 更亮的阴影
                blurRadius: 20, // 更大的模糊半径
                spreadRadius: 4, // 更大的扩散半径
              )
            ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 图片部分
              Expanded(
                flex: 3, // 调整比例，给信息部分更多空间
                child: ClipRRect(
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
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
                              strokeWidth: 3.0, // 更粗的进度指示器
                            )),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Color(0xFF333333),
                        child: Center(
                            child: Icon(Icons.broken_image,
                                color: Colors.grey, size: 36)), // 更大的图标
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
                              fontSize: 24, // 更大的字体
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // 信息部分
              Expanded(
                flex: 1, // 信息部分比例不变
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), // 更大的内边距
                  decoration: BoxDecoration(
                    color: Color(0xFF262626),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.movie.title,
                        style: TextStyle(
                          fontSize: 20, // 更大的标题字体
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 6), // 更大的间距
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${widget.movie.year}',
                            style: TextStyle(
                              fontSize: 18, // 更大的年份字体
                              color: Colors.grey,
                            ),
                          ),
                          Row(
                            children: [
                              Icon(Icons.star, size: 20, color: Colors.amber), // 更大的星标
                              SizedBox(width: 8), // 更大的间距
                              Text(
                                '${widget.movie.rating}',
                                style: TextStyle(
                                  fontSize: 18, // 更大的评分字体
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold, // 加粗评分
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
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