import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:libretv_app/widgets/full_screen_player_page.dart';

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
  int _focusedIndex = 0;
  final FocusNode _mainContentFocusNode = FocusNode();
  bool _isEpisodesFocused = false;

  @override
  void initState() {
    super.initState();
    _parseEpisodes();
    _mainContentFocusNode.requestFocus();

    _episodesFocusNode.addListener(() {
      setState(() {
        _isEpisodesFocused = _episodesFocusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _episodesFocusNode.dispose();
    _episodesScrollController.dispose();
    _mainContentFocusNode.dispose();
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
    final isDark = colorScheme.brightness == Brightness.dark;

    return Scaffold(
      body: Focus(
        focusNode: _mainContentFocusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          // 处理遥控器方向键
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
                !_isEpisodesFocused && _episodes.isNotEmpty) {
              _episodesFocusNode.requestFocus();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowUp && _isEpisodesFocused) {
              _mainContentFocusNode.requestFocus();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Column(
          children: [
            // Scrollable content (header and description)
            Expanded(
              child: SingleChildScrollView(
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

                    // Description with flexible height
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
                  ],
                ),
              ),
            ),

            // Episodes section fixed at bottom
            if (_episodes.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        '选集',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 56,
                      child: Focus(
                        focusNode: _episodesFocusNode,
                        autofocus: false,
                        onKeyEvent: (node, event) {
                          // 处理遥控器左右方向键
                          if (event is KeyDownEvent) {
                            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                              if (_focusedIndex > 0) {
                                setState(() {
                                  _focusedIndex--;
                                });
                                // 滚动到可见区域
                                _episodesScrollController.animateTo(
                                  (_focusedIndex * 72.0).clamp(
                                    0.0,
                                    _episodesScrollController.position.maxScrollExtent,
                                  ),
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                                return KeyEventResult.handled;
                              }
                            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                              if (_focusedIndex < _episodes.length - 1) {
                                setState(() {
                                  _focusedIndex++;
                                });
                                // 滚动到可见区域
                                _episodesScrollController.animateTo(
                                  (_focusedIndex * 72.0 - 100.0).clamp(
                                    0.0,
                                    _episodesScrollController.position.maxScrollExtent,
                                  ),
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                                return KeyEventResult.handled;
                              }
                            } else if (event.logicalKey == LogicalKeyboardKey.select ||
                                event.logicalKey == LogicalKeyboardKey.enter ||
                                event.physicalKey == PhysicalKeyboardKey.select ||
                                event.physicalKey == PhysicalKeyboardKey.enter) {
                              _playEpisode(_focusedIndex);
                              return KeyEventResult.handled;
                            } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                              _mainContentFocusNode.requestFocus();
                              return KeyEventResult.handled;
                            }
                          }
                          return KeyEventResult.ignored;
                        },
                        child: ListView.builder(
                          controller: _episodesScrollController,
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _episodes.length,
                          itemBuilder: (context, index) {
                            final isFocused = _isEpisodesFocused && _focusedIndex == index;
                            return Padding(
                              padding: const EdgeInsets.only(right: 12.0),
                              child: Focus(
                                onFocusChange: (hasFocus) {
                                  if (hasFocus) {
                                    setState(() {
                                      _focusedIndex = index;
                                    });
                                  }
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
                                    backgroundColor: isFocused
                                        ? colorScheme.primaryContainer
                                        : colorScheme.surfaceVariant,
                                    foregroundColor: isFocused
                                        ? colorScheme.onPrimaryContainer
                                        : colorScheme.onSurfaceVariant,
                                    elevation: isFocused ? 4 : 0,
                                    side: BorderSide(
                                      color: isFocused
                                          ? colorScheme.primary
                                          : Colors.transparent,
                                      width: isFocused ? 2 : 0,
                                    ),
                                  ),
                                  onPressed: () => _playEpisode(index),
                                  child: Text(
                                    _episodes[index]['title']!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge!
                                        .copyWith(
                                      fontWeight: isFocused
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: isFocused ? 18 : 16,
                                    ),
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
              ),
            ],
          ],
        ),
      ),
    );
  }
}