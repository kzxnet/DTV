import 'dart:developer';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
  List<dynamic> _displayedMovies = []; // Only shows current page items
  List<dynamic> _recommendations = [];
  bool _isLoading = false;
  bool _showSearchHint = true;
  int _currentPage = 1;
  int _itemsPerPage = 8;
  bool _hasMore = true;

  // Colors
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
    _fetchRecommendations();
  }

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
      _displayedMovies = [];
      _currentPage = 1;
      _hasMore = true;
    });

    try {
      final response = await _dio.get(
        'http://localhost:8023/api/search',
        queryParameters: {'wd': keyword, 'limit': 100},
        cancelToken: _cancelToken.isCancelled ? _cancelToken = CancelToken() : _cancelToken,
      );

      if (response.statusCode == 200 && response.data['code'] == 1) {
        setState(() {
          _movies = response.data['list'] ?? [];
          _updateDisplayedMovies();
        });
      }
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) return;
      _showError('搜索失败: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _updateDisplayedMovies() {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;

    if (startIndex >= _movies.length) {
      setState(() {
        _hasMore = false;
      });
      return;
    }

    setState(() {
      _displayedMovies = _movies.sublist(
        startIndex,
        endIndex > _movies.length ? _movies.length : endIndex,
      );
      _hasMore = endIndex < _movies.length;
    });
  }

  void _loadNextPage() {
    if (!_hasMore) return;

    setState(() {
      _currentPage++;
      _updateDisplayedMovies();
    });
  }

  void _loadPreviousPage() {
    if (_currentPage <= 1) return;

    setState(() {
      _currentPage--;
      _updateDisplayedMovies();
    });
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
            border: _searchFocusNode.hasFocus
                ? Border.all(color: _primaryColor, width: 3)
                : null,
            boxShadow: _searchFocusNode.hasFocus
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
                    focusNode: _searchFocusNode,
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
    return Row(
      children: [
        Focus(
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                (event.logicalKey == LogicalKeyboardKey.select ||
                    event.logicalKey == LogicalKeyboardKey.enter)) {
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
        ),
        Focus(
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                (event.logicalKey == LogicalKeyboardKey.select ||
                    event.logicalKey == LogicalKeyboardKey.enter)) {
              _showQRCodeDialog();
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
                      color: _primaryColor.withAlpha(255 ~/ 2),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                      : null,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => _showQRCodeDialog(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.settings, size: 32, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          '管理',
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
        ),
      ],
    );
  }

  final NetworkInfo _networkInfo = NetworkInfo();

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
        backgroundColor: _darkBackground,
        title: Text(
          '扫描二维码管理',
          style: TextStyle(color: _textColor),
        ),
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
              Text(
                url,
                style: TextStyle(color: _textColor),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '关闭',
              style: TextStyle(color: _primaryColor),
            ),
          ),
        ],
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
            Text(
              '热门推荐',
              style: TextStyle(
                fontSize: 24,
                color: _textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
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
          : Center(
        child: Column(
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
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (scrollNotification) {
              if (scrollNotification is ScrollEndNotification &&
                  scrollNotification.metrics.pixels ==
                      scrollNotification.metrics.maxScrollExtent &&
                  _hasMore) {
                _loadNextPage();
              }
              return false;
            },
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Text(
                          '搜索结果 (${_movies.length})',
                          style: TextStyle(
                            fontSize: 22,
                            color: _textColor.withAlpha((255 * 0.8).toInt()),
                          ),
                        ),
                        Spacer(),
                        Text(
                          '第 $_currentPage 页',
                          style: TextStyle(
                            fontSize: 18,
                            color: _hintColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 8),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 0.7,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        final movie = _displayedMovies[index];
                        return _buildMovieCard(movie);
                      },
                      childCount: _displayedMovies.length,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _buildPaginationControls(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Add this method to build the pagination controls
  Widget _buildPaginationControls() {
    final totalPages = (_movies.length / _itemsPerPage).ceil();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Text(
            '第 $_currentPage 页 / 共 $totalPages 页',
            style: TextStyle(
              fontSize: 18,
              color: _textColor.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // First Page Button
              Focus(
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent &&
                      (event.logicalKey == LogicalKeyboardKey.select ||
                          event.logicalKey == LogicalKeyboardKey.enter)) {
                    if (_currentPage > 1) {
                      setState(() {
                        _currentPage = 1;
                        _updateDisplayedMovies();
                      });
                    }
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: Builder(
                  builder: (context) {
                    final hasFocus = Focus.of(context).hasFocus;
                    final isEnabled = _currentPage > 1;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: isEnabled
                            ? (hasFocus ? _primaryColor : const Color(0xFF333333))
                            : const Color(0xFF222222),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: hasFocus && isEnabled
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
                        onTap: isEnabled
                            ? () {
                          setState(() {
                            _currentPage = 1;
                            _updateDisplayedMovies();
                          });
                        }
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.first_page,
                                  size: 24,
                                  color: isEnabled ? Colors.white : _hintColor),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Previous Page Button
              Focus(
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent &&
                      (event.logicalKey == LogicalKeyboardKey.select ||
                          event.logicalKey == LogicalKeyboardKey.enter)) {
                    _loadPreviousPage();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: Builder(
                  builder: (context) {
                    final hasFocus = Focus.of(context).hasFocus;
                    final isEnabled = _currentPage > 1;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: isEnabled
                            ? (hasFocus ? _primaryColor : const Color(0xFF333333))
                            : const Color(0xFF222222),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: hasFocus && isEnabled
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
                        onTap: isEnabled ? _loadPreviousPage : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.arrow_back,
                                  size: 24,
                                  color: isEnabled ? Colors.white : _hintColor),
                              const SizedBox(width: 8),
                              Text(
                                '上一页',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: isEnabled ? Colors.white : _hintColor,
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
              ),

              // Current Page Indicator (non-interactive)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _cardBackground,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  '$_currentPage',
                  style: TextStyle(
                    fontSize: 18,
                    color: _primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Next Page Button
              Focus(
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent &&
                      (event.logicalKey == LogicalKeyboardKey.select ||
                          event.logicalKey == LogicalKeyboardKey.enter)) {
                    _loadNextPage();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: Builder(
                  builder: (context) {
                    final hasFocus = Focus.of(context).hasFocus;
                    final isEnabled = _hasMore;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: isEnabled
                            ? (hasFocus ? _primaryColor : const Color(0xFF333333))
                            : const Color(0xFF222222),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: hasFocus && isEnabled
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
                        onTap: isEnabled ? _loadNextPage : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Text(
                                '下一页',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: isEnabled ? Colors.white : _hintColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.arrow_forward,
                                  size: 24,
                                  color: isEnabled ? Colors.white : _hintColor),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Last Page Button
              Focus(
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent &&
                      (event.logicalKey == LogicalKeyboardKey.select ||
                          event.logicalKey == LogicalKeyboardKey.enter)) {
                    if (_hasMore) {
                      final totalPages = (_movies.length / _itemsPerPage).ceil();
                      setState(() {
                        _currentPage = totalPages;
                        _updateDisplayedMovies();
                      });
                    }
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: Builder(
                  builder: (context) {
                    final hasFocus = Focus.of(context).hasFocus;
                    final isEnabled = _hasMore;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: isEnabled
                            ? (hasFocus ? _primaryColor : const Color(0xFF333333))
                            : const Color(0xFF222222),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: hasFocus && isEnabled
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
                        onTap: isEnabled
                            ? () {
                          final totalPages = (_movies.length / _itemsPerPage).ceil();
                          setState(() {
                            _currentPage = totalPages;
                            _updateDisplayedMovies();
                          });
                        }
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.last_page,
                                  size: 24,
                                  color: isEnabled ? Colors.white : _hintColor),
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
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(Map<String, dynamic> movie) {
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
              boxShadow: hasFocus
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
                side: hasFocus
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
                        httpHeaders: {
                          'User-Agent':
                          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                          'Accept':
                          'image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
                        },
                        imageUrl: movie['cover'] ?? '',
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(
                              _primaryColor,
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Center(
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
              boxShadow: hasFocus
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
                side: hasFocus
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
                            placeholder: (_, __) => Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  _primaryColor,
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Center(
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
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.max,
                        children: [
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
                          Row(
                            children: [
                              if (movie['vod_year']?.toString().isNotEmpty ?? false)
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
                              if (movie['type_name']?.toString().isNotEmpty ?? false) ...[
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
                              if (movie['vod_play_from']?.toString().isNotEmpty ?? false) ...[
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
      canPop: !_searchFocusNode.hasFocus && _searchController.text.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        log('Pop invoked with result: $didPop, $result');
        if (!didPop) {
          _cancelToken.cancel();
          if (_searchFocusNode.hasFocus) {
            _searchFocusNode.unfocus();
          } else if (_searchController.text.isNotEmpty) {
            setState(() {
              _movies.clear();
              _displayedMovies.clear();
              _searchController.clear();
              _currentPage = 1;
              _hasMore = true;
            });
          } else {
            Navigator.maybePop(context);
          }
        }
      },
      child: FocusScope(
        autofocus: true,
        child: Scaffold(
          appBar: PreferredSize(
            preferredSize: Size(double.infinity, 200),
            child: _buildSearchField(),
          ),
          backgroundColor: _darkBackground,
          body: _buildContent(),
        ),
      ),
    );
  }
}