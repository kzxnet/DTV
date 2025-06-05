import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';

void main() {
  runApp(MovieHeavenApp());
}

class MovieHeavenApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    return MaterialApp(
      title: '电影天堂',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.black,
        scaffoldBackgroundColor: Color(0xFF1A1A1A),
        textTheme: TextTheme(
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          bodyMedium: TextStyle(fontSize: 14),
          bodySmall: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ),
      home: MovieHomePage(),
    );
  }
}

class MovieHomePage extends StatefulWidget {
  @override
  _MovieHomePageState createState() => _MovieHomePageState();
}

class _MovieHomePageState extends State<MovieHomePage> {
  final Dio _dio = Dio();
  int _selectedTab = 0;
  bool _isLoading = false;
  final List<String> _tabs = [
    '全部', '动作', '喜剧', '科幻', '恐怖', '爱情', '悬疑', '动画', '纪录片', '战争', '港剧'
  ];
  List<MovieCategory> _categories = [];

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
          'tag': tag == '全部' ? null : tag,
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
          _categories = [
            MovieCategory(
              title: '热门${tag == '全部' ? '电影' : tag}',
              movies: movies,
            ),
            MovieCategory(
              title: '最新上映',
              movies: movies.take(3).toList(), // 示例数据，实际应用中可能需要单独获取
            ),
          ];
        });
      }
    } catch (e) {
      debugPrint('获取电影失败: $e');
      // 使用模拟数据作为后备
      setState(() {
        _categories = [
          MovieCategory(
            title: '热门${tag == '全部' ? '电影' : tag}',
            movies: [
              Movie(
                id: '1',
                title: '${tag}电影1',
                year: 2023,
                rating: 8.0,
                coverUrl: 'https://img2.doubanio.com/view/photo/s_ratio_poster/public/p2889473373.webp',
                playable: true,
                isNew: true,
                url: 'https://movie.douban.com/subject/1/',
              ),
              Movie(
                id: '2',
                title: '${tag}电影2',
                year: 2023,
                rating: 7.5,
                coverUrl: 'https://img2.doubanio.com/view/photo/s_ratio_poster/public/p2889473373.webp',
                playable: false,
                isNew: false,
                url: 'https://movie.douban.com/subject/2/',
              ),
            ],
          ),
        ];
      });
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
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    return _buildMovieSection(_categories[index]);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5, vertical: 10),
      color: Color(0xFF0D0D0D),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            icon: Icon(Icons.search, size: 20),
            onPressed: () {},
            focusColor: Colors.red,
          ),
          SizedBox(width: 10),
          IconButton(
            icon: Icon(Icons.settings, size: 20),
            onPressed: () {},
            focusColor: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 10),
        itemCount: _tabs.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 5),
            child: Focus(
              onFocusChange: (hasFocus) {
                if (hasFocus) {
                  setState(() => _selectedTab = index);
                  _fetchMovies(_tabs[index]);
                }
              },
              child: ActionChip(
                label: Text(
                  _tabs[index],
                  style: TextStyle(
                    color: _selectedTab == index ? Colors.white : Colors.grey,
                    fontWeight: _selectedTab == index ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                backgroundColor: _selectedTab == index ? Colors.red : Color(0xFF333333),
                padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                shape: StadiumBorder(),
                onPressed: () {
                  setState(() => _selectedTab = index);
                  _fetchMovies(_tabs[index]);
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMovieSection(MovieCategory category) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  category.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Focus(
                  child: TextButton(
                    child: Row(
                      children: [
                        Text('更多', style: TextStyle(color: Colors.grey)),
                        Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                      ],
                    ),
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 300,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: category.movies.length,
              itemBuilder: (context, index) {
                final movie = category.movies[index];
                return Focus(
                  onFocusChange: (hasFocus) {
                    if (hasFocus) {
                      // 可以添加聚焦时的动画效果
                    }
                  },
                  child: Padding(
                    padding: EdgeInsets.only(right: 15),
                    child: _buildMovieCard(movie),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovieCard(Movie movie) {
    return Container(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
                // 左下和右下不设置圆角
                bottomLeft: Radius.zero,
                bottomRight: Radius.zero,
              ),
              child: movie.coverUrl != null
                  ? CachedNetworkImage(
                      httpHeaders: {
                        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                        'Accept': 'image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
                      },
                      imageUrl: movie.coverUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (context, url) => Container(
                        color: Color(0xFF333333),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Color(0xFF333333),
                        child: Center(
                          child: Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      ),
                    )
                : Container(
                    color: Color(0xFF333333),
                    child: Center(
                      child: Text(
                        movie.title.split(' ').first,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Reduced vertical padding
          color: Color(0xFF262626),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                movie.title,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 2), // Reduced spacing
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${movie.year}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Row(
                    children: [
                      Icon(Icons.star, size: 14, color: Colors.amber),
                      SizedBox(width: 2), // Reduced spacing
                      Text(
                        '${movie.rating}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.amber),
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
  );
  }
}

class MovieCategory {
  final String title;
  final List<Movie> movies;

  MovieCategory({required this.title, required this.movies});
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