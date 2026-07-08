import 'package:flutter/material.dart';
import 'package:rana/features/camera/widgets/rana_styles_controls.dart';
import 'package:rana/features/preset/model/preset_model.dart';
import 'package:rana/features/preset/model/saved_rana_style.dart';

class BrandGroup {
  final String name;
  final List<PresetModel> presets;
  BrandGroup(this.name, this.presets);
}

/// A premium, horizontal-swipe, brand-grouped preset selector panel.
class PresetSelectorPanel extends StatefulWidget {
  /// Main constructor.
  const PresetSelectorPanel({
    required this.presets,
    required this.activePresetId,
    required this.onPresetSelected,
    this.onDeletePreset,
    super.key,
  });

  /// All loaded presets.
  final List<PresetModel> presets;

  /// Currently active preset ID.
  final String? activePresetId;

  /// Callback when a preset is selected.
  final ValueChanged<PresetModel> onPresetSelected;

  /// Optional callback to delete a user style preset.
  final ValueChanged<PresetModel>? onDeletePreset;

  @override
  State<PresetSelectorPanel> createState() => _PresetSelectorPanelState();
}

class _PresetSelectorPanelState extends State<PresetSelectorPanel> {
  late PageController _pageController;
  late ScrollController _tabScrollController;
  final List<GlobalKey> _tabKeys = [];
  final GlobalKey _tabBarKey = GlobalKey();
  int _currentPage = 0;
  List<BrandGroup> _groups = [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _tabScrollController = ScrollController();
    _groupPresets();
    _determineInitialPage();
  }

  @override
  void didUpdateWidget(PresetSelectorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.presets != oldWidget.presets || widget.activePresetId != oldWidget.activePresetId) {
      _groupPresets();
      _determineInitialPage();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tabScrollController.dispose();
    super.dispose();
  }

  void _groupPresets() {
    final myStyles = <PresetModel>[];
    final rana = <PresetModel>[];
    final kodak = <PresetModel>[];
    final fuji = <PresetModel>[];
    final agfa = <PresetModel>[];
    final lomography = <PresetModel>[];
    final cinestill = <PresetModel>[];
    final ilford = <PresetModel>[];
    final defaults = <PresetModel>[];
    final others = <PresetModel>[];

    for (final preset in widget.presets) {
      if (preset.id == 'placeholder') continue;

      final nameLower = preset.name.toLowerCase();
      final idLower = preset.id.toLowerCase();
      final isSavedStyle = SavedRanaStyle.isSavedStylePresetId(preset.id);

      if (isSavedStyle) {
        myStyles.add(preset);
      } else if (idLower == 'normal') {
        defaults.add(preset);
      } else if (nameLower.contains('rana') || idLower.startsWith('rana')) {
        rana.add(preset);
      } else if (nameLower.contains('kodak') ||
          idLower.startsWith('kodak') ||
          idLower.contains('ektar') ||
          idLower.contains('gold') ||
          idLower.contains('portra') ||
          idLower.contains('tri_x') ||
          idLower.contains('vision3')) {
        kodak.add(preset);
      } else if (nameLower.contains('fujifilm') ||
          nameLower.contains('fuji') ||
          idLower.startsWith('fuji') ||
          idLower.contains('pro_400h') ||
          idLower.contains('velvia') ||
          idLower.contains('superia') ||
          idLower.contains('natura') ||
          idLower.contains('quicksnap')) {
        fuji.add(preset);
      } else if (nameLower.contains('agfa') || idLower.startsWith('agfa')) {
        agfa.add(preset);
      } else if (nameLower.contains('lomo') || idLower.startsWith('lomo')) {
        lomography.add(preset);
      } else if (nameLower.contains('cinestill') ||
          idLower.startsWith('cinestill')) {
        cinestill.add(preset);
      } else if (nameLower.contains('ilford') ||
          idLower.startsWith('ilford') ||
          idLower.contains('hp5')) {
        ilford.add(preset);
      } else {
        others.add(preset);
      }
    }

    final tempGroups = <BrandGroup>[];
    if (defaults.isNotEmpty) tempGroups.add(BrandGroup('DEFAULT', defaults));
    if (rana.isNotEmpty) tempGroups.add(BrandGroup('RANA', rana));
    if (kodak.isNotEmpty) tempGroups.add(BrandGroup('KODAK', kodak));
    if (fuji.isNotEmpty) tempGroups.add(BrandGroup('FUJIFILM', fuji));
    if (agfa.isNotEmpty) tempGroups.add(BrandGroup('AGFA', agfa));
    if (lomography.isNotEmpty) tempGroups.add(BrandGroup('LOMOGRAPHY', lomography));
    if (cinestill.isNotEmpty) tempGroups.add(BrandGroup('CINESTILL', cinestill));
    if (ilford.isNotEmpty) tempGroups.add(BrandGroup('ILFORD', ilford));
    if (myStyles.isNotEmpty) tempGroups.add(BrandGroup('MY STYLES', myStyles));
    if (others.isNotEmpty) tempGroups.add(BrandGroup('OTHERS', others));

    _groups = tempGroups;
    _tabKeys.clear();
    for (var i = 0; i < _groups.length; i++) {
      _tabKeys.add(GlobalKey());
    }
  }

  void _determineInitialPage() {
    if (widget.activePresetId == null) {
      _currentPage = 0;
      return;
    }

    for (var i = 0; i < _groups.length; i++) {
      final hasActive = _groups[i].presets.any((p) => p.id == widget.activePresetId);
      if (hasActive) {
        _currentPage = i;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(i);
          }
          _scrollToTab(i);
        });
        break;
      }
    }
  }

  void _scrollToTab(int index) {
    if (!_tabScrollController.hasClients || index >= _tabKeys.length) return;

    final context = _tabKeys[index].currentContext;
    if (context == null) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final tabBarContext = _tabBarKey.currentContext;
    if (tabBarContext == null) return;

    final tabBarRenderBox = tabBarContext.findRenderObject() as RenderBox?;
    if (tabBarRenderBox == null) return;

    final tabWidth = renderBox.size.width;
    final tabPosition = renderBox.localToGlobal(Offset.zero, ancestor: tabBarRenderBox);
    final tabOffset = tabPosition.dx;
    final viewportWidth = tabBarRenderBox.size.width;
    final currentScrollOffset = _tabScrollController.offset;

    // Center the tab
    final targetScrollOffset = currentScrollOffset + tabOffset - (viewportWidth / 2) + (tabWidth / 2);
    final maxScroll = _tabScrollController.position.maxScrollExtent;
    final minScroll = _tabScrollController.position.minScrollExtent;

    _tabScrollController.animateTo(
      targetScrollOffset.clamp(minScroll, maxScroll),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentPage = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    _scrollToTab(index);
  }

  @override
  Widget build(BuildContext context) {
    if (_groups.isEmpty) {
      return const SizedBox.shrink();
    }

    return CustomPaint(
      painter: StylesPanelBackgroundPainter(),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 180,
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Brand Tab Bar
              SizedBox(
                key: _tabBarKey,
                height: 38,
                child: ListView.builder(
                  controller: _tabScrollController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _groups.length,
                  itemBuilder: (context, index) {
                    final group = _groups[index];
                    final isSelected = _currentPage == index;

                    return Padding(
                      key: _tabKeys[index],
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: GestureDetector(
                        onTap: () => _onTabTapped(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFF39C12).withValues(alpha: 0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFF39C12).withValues(alpha: 0.3)
                                  : Colors.white.withValues(alpha: 0.05),
                              width: 1.0,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              group.name,
                              style: TextStyle(
                                color: isSelected ? const Color(0xFFF39C12) : Colors.white60,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              // Separator
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: Colors.white.withValues(alpha: 0.06),
              ),
              // Preset List PageView
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                    _scrollToTab(index);
                  },
                  itemCount: _groups.length,
                  itemBuilder: (context, pageIndex) {
                    final group = _groups[pageIndex];
                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      itemCount: group.presets.length,
                      itemBuilder: (context, index) {
                        final preset = group.presets[index];
                        final isSelected = widget.activePresetId == preset.id;

                        // Clean up brand name prefixes
                        var displayName = preset.name.toUpperCase();
                        if (displayName.startsWith('KODAK ')) {
                          displayName = displayName.replaceFirst('KODAK ', '');
                        } else if (displayName.startsWith('FUJIFILM ')) {
                          displayName = displayName.replaceFirst('FUJIFILM ', '');
                        } else if (displayName.startsWith('RANA ')) {
                          displayName = displayName.replaceFirst('RANA ', '');
                        } else if (displayName.startsWith('ILFORD ')) {
                          displayName = displayName.replaceFirst('ILFORD ', '');
                        } else if (displayName.startsWith('AGFA ')) {
                          displayName = displayName.replaceFirst('AGFA ', '');
                        } else if (displayName.startsWith('LOMOGRAPHY ')) {
                          displayName = displayName.replaceFirst('LOMOGRAPHY ', '');
                        }

                        final isSavedStyle = SavedRanaStyle.isSavedStylePresetId(preset.id);

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: GestureDetector(
                            onTap: () => widget.onPresetSelected(preset),
                            child: SizedBox(
                              width: 76,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Icon Container
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? const Color(0xFFF39C12).withValues(alpha: 0.12)
                                              : const Color(0xFF16161A),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: isSelected
                                                ? const Color(0xFFF39C12)
                                                : Colors.white.withValues(alpha: 0.05),
                                            width: isSelected ? 2.0 : 1.0,
                                          ),
                                          boxShadow: isSelected
                                              ? [
                                                  BoxShadow(
                                                    color: const Color(0xFFF39C12).withValues(alpha: 0.15),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: Icon(
                                          Icons.photo_camera_back_outlined,
                                          size: 20,
                                          color: isSelected
                                              ? const Color(0xFFF39C12)
                                              : Colors.white54,
                                        ),
                                      ),
                                      if (isSavedStyle && widget.onDeletePreset != null)
                                        Positioned(
                                          top: -4,
                                          right: -4,
                                          child: GestureDetector(
                                            onTap: () => widget.onDeletePreset!(preset),
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: const BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.close_rounded,
                                                size: 10,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  // Text Label
                                  Text(
                                    displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: isSelected ? const Color(0xFFF39C12) : Colors.white70,
                                      fontSize: 8.5,
                                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                                      letterSpacing: 0.5,
                                      height: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
