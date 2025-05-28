import 'dart:developer';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'movie_detail_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final Dio _dio = Dio()..interceptors.add(LogInterceptor());
  CancelToken _cancelToken = CancelToken();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<dynamic> _movies = [];
  List<dynamic> _recommendations = []; // 新增：推荐列表
  bool _isLoading = false;
  bool _showSearchHint = true;

  // 颜色方案
  final Color _primaryColor = const Color(0xFF00C8FF);
  final Color _darkBackground = const Color(0xFF121212);
  final Color _cardBackground = const Color(0xFF1E1E1E);
  final Color _textColor = Colors.white;
  final Color _hintColor = const Color(0xFFAAAAAA);

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_onFocusChange);
    _searchController.addListener(_onSearchTextChange);
    _fetchRecommendations(); // 新增：初始化时获取推荐
  }

  // 新增：获取推荐电影
  Future<void> _fetchRecommendations() async {
    try {
      final response = await _dio.get(
        'https://movie.douban.com/j/search_subjects',
        queryParameters: {
          'type': 'movie',
          'tag': '热门',
          'sort': 'recommend',
          'page_limit': '100',
          'page_start': '0',
        },
        cancelToken: _cancelToken.isCancelled ? _cancelToken = CancelToken() : _cancelToken,
      );

      log('获取推荐: ${response.data}');

      if (response.statusCode == 200) {
        setState(() {
          _recommendations = response.data['subjects'] ?? [];
        });
      }
    } catch (e) {
      debugPrint('获取推荐失败: $e');
    }
  }

  // 修改：点击推荐项进行搜索
  void _searchRecommendation(String title) {
    _searchController.text = title;
    _searchMovies(title);
  }

  void _onFocusChange() {
    setState(() {});
  }

  void _onSearchTextChange() {
    setState(() {
      _showSearchHint = _searchController.text.isEmpty;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _searchMovies(String keyword) async {
    if (keyword.isEmpty) return;

    setState(() {
      _isLoading = true;
      _movies = [];
    });

    try {
      final response = await _dio.get(
        'https://cms-api.aini.us.kg/api/search',
        queryParameters: {'wd': keyword, 'limit': 100},
        cancelToken: _cancelToken.isCancelled ? _cancelToken = CancelToken() : _cancelToken,
      );

      if (response.statusCode == 200 && response.data['code'] == 1) {
        setState(() {
          _movies = response.data['list'] ?? [];
        });
      }
    } catch (e) {
      _showError('搜索失败: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFFB00020),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 32, 48, 24),
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(32),
        color: _cardBackground,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            border:
                _searchFocusNode.hasFocus
                    ? Border.all(color: _primaryColor, width: 3)
                    : null,
            boxShadow:
                _searchFocusNode.hasFocus
                    ? [
                      BoxShadow(
                        color: _primaryColor.withAlpha((255 * 0.3).toInt()),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                    : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 24),
                  child: TextField(
                    focusNode: _searchFocusNode, // 关键：给TextField传递FocusNode
                    controller: _searchController,
                    style: TextStyle(
                      fontSize: 24,
                      color: _textColor,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: '搜索电影、电视剧...',
                      hintStyle: TextStyle(fontSize: 22, color: _hintColor),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (value) {
                      _searchMovies(value.trim());
                    },
                  ),
                ),
              ),
              _buildSearchButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchButton() {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.select) {
          _searchMovies(_searchController.text.trim());
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: hasFocus ? _primaryColor : const Color(0xFF333333),
              borderRadius: BorderRadius.circular(24),
              boxShadow:
                  hasFocus
                      ? [
                        BoxShadow(
                          color: _primaryColor.withAlpha(255 ~/ 2),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                      : null,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => _searchMovies(_searchController.text.trim()),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 32, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      '搜索',
                      style: TextStyle(
                        fontSize: 22,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              strokeWidth: 6,
              valueColor: AlwaysStoppedAnimation(Color(0xFF00C8FF)),
            ),
            const SizedBox(height: 32),
            Text(
              '正在搜索中...',
              style: TextStyle(
                fontSize: 24,
                color: _textColor.withAlpha((255 * 0.8).toInt()),
              ),
            ),
          ],
        ),
      );
    }

    if (_movies.isEmpty) {
      return _showSearchHint
          ? SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.movie_creation,
                  size: 120,
                  color: _hintColor.withAlpha((255 * 0.3).toInt()),
                ),
                const SizedBox(height: 32),
                Text(
                  '输入电影或电视剧名称',
                  style: TextStyle(
                    fontSize: 28,
                    color: _hintColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '使用遥控器方向键导航，确认键选择',
                  style: TextStyle(
                    fontSize: 20,
                    color: _hintColor.withAlpha((255 * 0.7).toInt()),
                  ),
                ),
                const SizedBox(height: 32),
                // 新增：推荐列表标题
                Text(
                  '热门推荐',
                  style: TextStyle(
                    fontSize: 24,
                    color: _textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                // 新增：推荐列表
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _recommendations.length,
                  itemBuilder: (context, index) {
                    final movie = _recommendations[index];
                    return _buildRecommendationCard(movie);
                  },
                ),
              ],
            ),
          )
          : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 120,
                color: _hintColor.withAlpha((255 * 0.3).toInt()),
              ),
              const SizedBox(height: 32),
              Text(
                '没有找到相关内容',
                style: TextStyle(
                  fontSize: 28,
                  color: _hintColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '尝试其他关键词',
                style: TextStyle(
                  fontSize: 20,
                  color: _hintColor.withAlpha((255 * 0.7).toInt()),
                ),
              ),
            ],
          );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
            child: Row(
              children: [
                Text(
                  '搜索结果 (${_movies.length})',
                  style: TextStyle(
                    fontSize: 22,
                    color: _textColor.withAlpha((255 * 0.8).toInt()),
                  ),
                ),
              ],
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, // 4 items per row
              childAspectRatio: 0.7, // Adjusted aspect ratio
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _movies.length,
            itemBuilder: (context, index) {
              final movie = _movies[index];
              return _buildMovieCard(movie);
            },
          ),
        ],
      ),
    );
  }

  // 新增：推荐卡片组件
  Widget _buildRecommendationCard(Map<String, dynamic> movie) {
    // log('${movie['cover']}');

    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          _searchRecommendation(movie['title']);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow:
                  hasFocus
                      ? [
                        BoxShadow(
                          color: _primaryColor.withAlpha((255 * 0.4).toInt()),
                          blurRadius: 16,
                          spreadRadius: 4,
                        ),
                      ]
                      : [
                        BoxShadow(
                          color: Colors.black.withAlpha((255 * 0.4).toInt()),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
            ),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side:
                    hasFocus
                        ? BorderSide(color: _primaryColor, width: 3)
                        : BorderSide.none,
              ),
              elevation: hasFocus ? 8 : 4,
              color: _cardBackground,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _searchRecommendation(movie['title']),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: CachedNetworkImage(
                        imageUrl: movie['cover'] ?? '',
                        fit: BoxFit.cover,
                        placeholder:
                            (_, __) => Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  _primaryColor,
                                ),
                              ),
                            ),
                        errorWidget:
                            (_, __, ___) => Center(
                              child: Icon(
                                Icons.broken_image,
                                size: 48,
                                color: _hintColor,
                              ),
                            ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        movie['title'] ?? '未知标题',
                        style: TextStyle(
                          fontSize: 16,
                          color: _textColor,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMovieCard(Map<String, dynamic> movie) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          _navigateToDetail(movie);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow:
                  hasFocus
                      ? [
                        BoxShadow(
                          color: _primaryColor.withAlpha((255 * 0.4).toInt()),
                          blurRadius: 16,
                          spreadRadius: 4,
                        ),
                      ]
                      : [
                        BoxShadow(
                          color: Colors.black.withAlpha((255 * 0.4).toInt()),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
            ),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side:
                    hasFocus
                        ? BorderSide(color: _primaryColor, width: 3)
                        : BorderSide.none,
              ),
              elevation: hasFocus ? 8 : 4,
              color: _cardBackground,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _navigateToDetail(movie),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Poster image (adaptive width)
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          color: _darkBackground,
                        ),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          child: CachedNetworkImage(
                            imageUrl: movie['vod_pic'] ?? '',
                            fit: BoxFit.cover,
                            placeholder:
                                (_, __) => Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                      _primaryColor,
                                    ),
                                  ),
                                ),
                            errorWidget:
                                (_, __, ___) => Center(
                                  child: Icon(
                                    Icons.broken_image,
                                    size: 48,
                                    color: _hintColor,
                                  ),
                                ),
                          ),
                        ),
                      ),
                    ),

                    // Movie details
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          // Title
                          Text(
                            movie['vod_name'] ?? '未知标题',
                            style: TextStyle(
                              fontSize: 16,
                              color: _textColor,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),

                          // Year, Type, and Source in one line
                          Row(
                            children: [
                              // Year
                              if (movie['vod_year']?.toString().isNotEmpty ??
                                  false)
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _primaryColor.withAlpha(
                                        (255 * 0.2).toInt(),
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      movie['vod_year'].toString(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _primaryColor,
                                      ),
                                    ),
                                  ),
                                ),

                              // Type
                              if (movie['type_name']?.toString().isNotEmpty ??
                                  false) ...[
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    movie['type_name'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _hintColor,
                                    ),
                                  ),
                                ),
                              ],

                              // Source (vod_play_from)
                              if (movie['vod_play_from']
                                      ?.toString()
                                      .isNotEmpty ??
                                  false) ...[
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    '| ${movie['vod_play_from']}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _hintColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Focus indicator
                    if (hasFocus)
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: _primaryColor,
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(12),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _navigateToDetail(Map<String, dynamic> movie) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MovieDetailPage(movie: movie)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        log('Pop invoked with result: $didPop, $result');
        if (!didPop) {
          _cancelToken.cancel();
          setState(() {
            _movies.clear();
            _searchController.clear();
          });
        }
      },
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: Size(double.infinity, 200),
          child: _buildSearchField(),
        ),
        backgroundColor: _darkBackground,
        body: FocusScope(autofocus: true, child: _buildContent()),
      ),
    );
  }
}
