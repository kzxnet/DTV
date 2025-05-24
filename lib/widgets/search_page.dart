import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
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
        child: Focus(
          focusNode: _searchFocusNode,
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.enter) {
              _searchMovies(_searchController.text.trim());
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              border: _searchFocusNode.hasFocus
                  ? Border.all(color: _primaryColor, width: 3)
                  : null,
              boxShadow: _searchFocusNode.hasFocus
                  ? [
                BoxShadow(
                  color: _primaryColor.withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                )
              ]
                  : null,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(
                        fontSize: 24,
                        color: _textColor,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: '搜索电影、电视剧...',
                        hintStyle: TextStyle(
                          fontSize: 22,
                          color: _hintColor,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                _buildSearchButton(),
              ],
            ),
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
              boxShadow: hasFocus
                  ? [
                BoxShadow(
                  color: _primaryColor.withOpacity(0.5),
                  blurRadius: 12,
                  spreadRadius: 2,
                )
              ]
                  : null,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => _searchMovies(_searchController.text.trim()),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
      return Expanded(
        child: Center(
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
                  color: _textColor.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_movies.isEmpty) {
      return Expanded(
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _showSearchHint
                ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.movie_creation,
                  size: 120,
                  color: _hintColor.withOpacity(0.3),
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
                    color: _hintColor.withOpacity(0.7),
                  ),
                ),
              ],
            )
                : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 120,
                  color: _hintColor.withOpacity(0.3),
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
                    color: _hintColor.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Expanded(
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
                    color: _textColor.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5, // 电视适合更宽的网格
                childAspectRatio: 0.65,
                crossAxisSpacing: 24,
                mainAxisSpacing: 24,
              ),
              itemCount: _movies.length,
              itemBuilder: (context, index) {
                final movie = _movies[index];
                return _buildMovieCard(movie);
              },
            ),
          ),
        ],
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
          return AnimatedScale(
            scale: hasFocus ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: hasFocus
                    ? [
                  BoxShadow(
                    color: _primaryColor.withOpacity(0.4),
                    blurRadius: 16,
                    spreadRadius: 4,
                  )
                ]
                    : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: hasFocus
                      ? BorderSide(color: _primaryColor, width: 3)
                      : BorderSide.none,
                ),
                elevation: hasFocus ? 8 : 4,
                color: _cardBackground,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _navigateToDetail(movie),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            CachedNetworkImage(
                              imageUrl: movie['vod_pic'] ?? '',
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                color: _darkBackground,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                    AlwaysStoppedAnimation(_primaryColor),
                                  ),
                                ),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: _darkBackground,
                                child: Center(
                                  child: Icon(
                                    Icons.broken_image,
                                    size: 48,
                                    color: _hintColor,
                                  ),
                                ),
                              ),
                            ),
                            if (hasFocus)
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 6,
                                  color: _primaryColor,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              movie['vod_name'] ?? '未知标题',
                              style: TextStyle(
                                fontSize: 20,
                                color: _textColor,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                if (movie['vod_year']?.toString().isNotEmpty ?? false)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _primaryColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      movie['vod_year'].toString(),
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: _primaryColor,
                                      ),
                                    ),
                                  ),
                                if (movie['type_name']?.toString().isNotEmpty ??
                                    false) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    movie['type_name'],
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: _hintColor,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
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
    );
  }

  void _navigateToDetail(Map<String, dynamic> movie) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: _darkBackground,
          body: Center(
            child: Text(
              '详情页: ${movie['vod_name']}',
              style: TextStyle(fontSize: 32, color: _textColor),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBackground,
      body: Column(
        children: [
          _buildSearchField(),
          _buildContent(),
        ],
      ),
    );
  }
}