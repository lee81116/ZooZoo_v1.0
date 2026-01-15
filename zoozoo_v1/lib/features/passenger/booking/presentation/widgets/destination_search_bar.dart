import 'package:flutter/material.dart';

import '../../../../../core/services/map/map_models.dart';
import '../../../../../core/theme/app_colors.dart';

/// Destination search bar widget
class DestinationSearchBar extends StatefulWidget {
  final Function(AppLatLng latLng, String name) onPlaceSelected;

  const DestinationSearchBar({
    super.key,
    required this.onPlaceSelected,
  });

  @override
  State<DestinationSearchBar> createState() => _DestinationSearchBarState();
}

class _DestinationSearchBarState extends State<DestinationSearchBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<_SearchResult> _searchResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    // Mock search results (in real app, use geocoding API)
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _controller.text == query) {
        setState(() {
          _searchResults = _getMockResults(query);
          _isSearching = false;
        });
      }
    });
  }

  List<_SearchResult> _getMockResults(String query) {
    // Mock search results for Taipei
    final allResults = [
      _SearchResult('台北101', '台北市信義區信義路五段7號', const AppLatLng(25.0330, 121.5654)),
      _SearchResult('台北車站', '台北市中正區北平西路3號', const AppLatLng(25.0478, 121.5170)),
      _SearchResult('西門町', '台北市萬華區', const AppLatLng(25.0421, 121.5081)),
      _SearchResult('信義威秀', '台北市信義區松壽路20號', const AppLatLng(25.0360, 121.5670)),
      _SearchResult('國父紀念館', '台北市信義區仁愛路四段505號', const AppLatLng(25.0400, 121.5600)),
      _SearchResult('松山機場', '台北市松山區敦化北路340號', const AppLatLng(25.0694, 121.5525)),
      _SearchResult('饒河夜市', '台北市松山區饒河街', const AppLatLng(25.0510, 121.5775)),
      _SearchResult('士林夜市', '台北市士林區', const AppLatLng(25.0880, 121.5240)),
    ];

    return allResults
        .where((r) => r.name.contains(query) || r.address.contains(query))
        .take(5)
        .toList();
  }

  void _selectResult(_SearchResult result) {
    _controller.text = result.name;
    _focusNode.unfocus();
    setState(() => _searchResults = []);
    widget.onPlaceSelected(result.latLng, result.name);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search input
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: '搜尋地點或地址',
              hintStyle: const TextStyle(color: AppColors.textHint),
              prefixIcon: const Icon(Icons.search, color: AppColors.primary),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AppColors.textHint),
                      onPressed: () {
                        _controller.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
        // Search results
        if (_searchResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _searchResults.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final result = _searchResults[index];
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.location_on,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    result.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    result.address,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  onTap: () => _selectResult(result),
                );
              },
            ),
          ),
        // Loading indicator
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 2,
            ),
          ),
      ],
    );
  }
}

class _SearchResult {
  final String name;
  final String address;
  final AppLatLng latLng;

  _SearchResult(this.name, this.address, this.latLng);
}
