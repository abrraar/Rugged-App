// lib/features/tracker/supplement/presentation/screens/supplement_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/features/main_wrapper.dart';
import 'package:rugged/features/tracker/supplement/widgets/cards/supplement_item_card.dart';
import 'package:rugged/features/tracker/supplement/widgets/cards/library_card.dart';
import 'package:rugged/features/tracker/supplement/widgets/cards/stacker_card.dart';
import 'package:rugged/features/tracker/supplement/widgets/sheets/intake_sheet.dart';
import 'package:rugged/features/tracker/supplement/widgets/sheets/notification_sheet.dart';
import 'package:rugged/features/tracker/supplement/widgets/sheets/quick_log_sheet.dart';
import 'package:rugged/core/widgets/elite_refresh_indicator.dart';
import 'package:rugged/core/widgets/elite_confirm_dialog.dart';
import 'package:rugged/core/widgets/elite_snackbar.dart';
import 'package:rugged/features/tracker/supplement/widgets/sheets/stack_form_sheet.dart';
import 'package:rugged/features/tracker/supplement/widgets/sheets/supplement_form_sheet.dart';
import 'package:rugged/core/utils/adaptive_utils.dart';

import 'package:rugged/features/tracker/calorie/provider/calorie_provider.dart';
import 'package:provider/provider.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:intl/intl.dart';

import 'model/supplement.dart';
import 'model/supplement_item.dart';
import 'model/supplement_stack.dart';
import 'provider/supplement_provider.dart';
import 'package:rugged/core/constants/dimensions.dart';
import 'widgets/cards/tracker_card.dart';

class _HistoryFilter {
  bool isDescending;
  String searchQuery;
  String type; // "ALL", "INTAKE", "RESTOCK"
  Set<String> sources; // "MEAL", "QUICK", "STACK", "NOTIF", "MANUAL"

  _HistoryFilter({
    this.isDescending = true,
    this.searchQuery = "",
    this.type = "ALL",
    Set<String>? sources,
  }) : sources = sources ?? {"MEAL", "QUICK", "STACK", "NOTIF", "MANUAL"};

  bool get isInitial =>
      isDescending &&
      searchQuery.isEmpty &&
      type == "ALL" &&
      sources.length == 5;

  _HistoryFilter copyWith({
    bool? isDescending,
    String? searchQuery,
    String? type,
    Set<String>? sources,
  }) {
    return _HistoryFilter(
      isDescending: isDescending ?? this.isDescending,
      searchQuery: searchQuery ?? this.searchQuery,
      type: type ?? this.type,
      sources: sources ?? this.sources,
    );
  }
}

class SupplementScreen extends StatefulWidget {
  final int initialTabIndex;
  const SupplementScreen({super.key, this.initialTabIndex = 0});

  @override
  State<SupplementScreen> createState() => _SupplementScreenState();
}

class _SupplementScreenState extends State<SupplementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late PageController _pageController;
  final TextEditingController _searchController = TextEditingController();

  _HistoryFilter _historyFilter = _HistoryFilter();

  DateTime _selectedHistoryDate = DateTime.now();
  DateTime _displayedMonth = DateTime.now();
  bool _isCalendarExpanded = false;

  @override
  void initState() {
    super.initState();
    activeSettingsContext.value = "supplement";
    _tabController = TabController(
      length: 4, 
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _pageController = PageController(
      viewportFraction: 0.2,
      initialPage: 0,
    );
    _displayedMonth = DateTime(_selectedHistoryDate.year, _selectedHistoryDate.month);
  }

  @override
  void dispose() {
    activeSettingsContext.value = "";
    _tabController.dispose();
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool isCompact = width < kMobileBreakpoint;
        final double hPad = !isCompact
            ? (width - kMaxContentWidth).clamp(24.0, double.infinity) / 2
            : 8.w;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: null,
          body: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: isCompact ? 24.h : 20.0),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: AppColors.white,
                                size: isCompact ? 24.r : 20.0,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                            Expanded(
                              child: Text(
                                'SUPPLEMENT TRACKER',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.h2.adaptive(context).copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.info_outline_rounded,
                                color: isCompact ? Colors.transparent : AppColors.white,
                                size: isCompact ? 24.r : 20.0,
                              ),
                              onPressed: isCompact ? null : () {
                                // Add instructions dialog if needed, similar to sleep screen
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    TabBar(
                      controller: _tabController,
                      isScrollable: false,
                      indicatorColor: AppColors.crimson,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicatorWeight: 3,
                      labelPadding: EdgeInsets.zero,
                      labelStyle: AppTextStyles.labelMedium.adaptive(context).copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      unselectedLabelColor: AppColors.textSecondary.withValues(
                        alpha: 0.4,
                      ),
                      labelColor: AppColors.crimson,
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(text: "TRACKER"),
                        Tab(text: "STACKER"),
                        Tab(text: "LIBRARY"),
                        Tab(text: "LOGS"),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTrackerTab(isCompact),
                    _buildStackerTab(isCompact),
                    _buildLibraryTab(isCompact),
                    _buildHistoryTab(isCompact),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- TAB BUILDERS ---

  Widget _buildTrackerTab(bool isCompact) {
    return Consumer<SupplementProvider>(
      builder: (context, provider, _) {
        final active = provider.activeSupplements;
        if (active.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => provider.forceRefresh(),
            color: AppColors.crimson,
            backgroundColor: AppColors.surface,
            child: LayoutBuilder(
              builder: (context, constraints) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  SizedBox(
                    height: constraints.maxHeight,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildEmptyState("NO ACTIVE SUPPLEMENTS", isCompact),
                          SizedBox(height: isCompact ? 16.h : 12.0),
                          GestureDetector(
                            onTap: () => _tabController.animateTo(2),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isCompact ? 24.w : 20.0,
                                vertical: isCompact ? 12.h : 10.0,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.crimson.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
                                border: Border.all(color: AppColors.crimson),
                              ),
                              child: Text(
                                "OPEN LIBRARY",
                                style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                  color: AppColors.crimson,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return EliteRefreshIndicator(
          onRefresh: () => provider.forceRefresh(),
          color: AppColors.crimson,
          backgroundColor: AppColors.surface,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool isWide = constraints.maxWidth > 700;
              if (isWide) {
                final leftItems = <Supplement>[];
                final rightItems = <Supplement>[];
                for (int i = 0; i < active.length; i++) {
                  if (i % 2 == 0) {
                    leftItems.add(active[i]);
                  } else {
                    rightItems.add(active[i]);
                  }
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20.0),
                        itemCount: leftItems.length,
                        itemBuilder: (context, index) => TrackerCard(
                          supplement: leftItems[index],
                          isCompact: false,
                          onLogTap: () => _openIntakeSheet(context, leftItems[index]),
                          onNotificationTap: () =>
                              _openNotificationSheet(context, leftItems[index]),
                          onQuickLogTap: () => _openQuickLogSheet(context, leftItems[index]),
                        ),
                      ),
                    ),
                    VerticalDivider(color: AppColors.white.withValues(alpha: 0.05), width: 1),
                    Expanded(
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20.0),
                        itemCount: rightItems.length,
                        itemBuilder: (context, index) => TrackerCard(
                          supplement: rightItems[index],
                          isCompact: false,
                          onLogTap: () => _openIntakeSheet(context, rightItems[index]),
                          onNotificationTap: () =>
                              _openNotificationSheet(context, rightItems[index]),
                          onQuickLogTap: () => _openQuickLogSheet(context, rightItems[index]),
                        ),
                      ),
                    ),
                  ],
                );
              }
              return ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                itemCount: active.length,
                itemBuilder: (context, index) => TrackerCard(
                  supplement: active[index],
                  isCompact: isCompact,
                  onLogTap: () => _openIntakeSheet(context, active[index]),
                  onNotificationTap: () =>
                      _openNotificationSheet(context, active[index]),
                  onQuickLogTap: () => _openQuickLogSheet(context, active[index]),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildStackerTab(bool isCompact) {
    return Consumer<SupplementProvider>(
      builder: (context, provider, _) {
        final activeCount = provider.activeSupplements.length;
        final stacks = provider.supplementStacks;

        return EliteRefreshIndicator(
          onRefresh: () => provider.forceRefresh(),
          color: AppColors.crimson,
          backgroundColor: AppColors.surface,
          child: Column(
            children: [
              Expanded(
                child: stacks.isEmpty
                    ? LayoutBuilder(
                        builder: (context, constraints) => ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          children: [
                            SizedBox(
                              height: constraints.maxHeight,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.layers_rounded,
                                      size: isCompact ? 48.r : 40.0,
                                      color: AppColors.textSecondary.withValues(alpha: 0.3),
                                    ),
                                    SizedBox(height: isCompact ? 16.h : 12.0),
                                    Text(
                                      "SUPPLEMENT STACKING",
                                      textAlign: TextAlign.center,
                                      style: AppTextStyles.h3.adaptive(context).copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isCompact ? 40.w : 24.0,
                                        vertical: isCompact ? 8.h : 6.0,
                                      ),
                                      child: Text(
                                        activeCount < 2
                                            ? "Activate at least 2 supplements from your library to create a stack."
                                            : "Bundle your active supplements for faster logging.",
                                        textAlign: TextAlign.center,
                                        style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                          color: AppColors.textSecondary.withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final bool isWide = constraints.maxWidth > 700;
                          if (isWide) {
                            final leftStacks = <SupplementStack>[];
                            final rightStacks = <SupplementStack>[];
                            for (int i = 0; i < stacks.length; i++) {
                              if (i % 2 == 0) {
                                leftStacks.add(stacks[i]);
                              } else {
                                rightStacks.add(stacks[i]);
                              }
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ListView.builder(
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    padding: const EdgeInsets.all(20.0),
                                    itemCount: leftStacks.length,
                                    itemBuilder: (context, index) => StackerCard(
                                      stack: leftStacks[index],
                                      isCompact: false,
                                    ),
                                  ),
                                ),
                                VerticalDivider(color: AppColors.white.withValues(alpha: 0.05), width: 1),
                                Expanded(
                                  child: ListView.builder(
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    padding: const EdgeInsets.all(20.0),
                                    itemCount: rightStacks.length,
                                    itemBuilder: (context, index) => StackerCard(
                                      stack: rightStacks[index],
                                      isCompact: false,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }
                          return ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                            itemCount: stacks.length,
                            itemBuilder: (context, index) {
                              final stack = stacks[index];
                              return StackerCard(
                                stack: stack,
                                isCompact: isCompact,
                              );
                            },
                          );
                        },
                      ),
              ),
              if (activeCount >= 2)
                _buildActionBtn(
                  "CREATE NEW STACK",
                  () => _openStackFormSheet(context),
                  isCompact,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLibraryTab(bool isCompact) {
    return Consumer<SupplementProvider>(
      builder: (context, provider, _) {
        if (provider.library.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => provider.forceRefresh(),
            color: AppColors.crimson,
            backgroundColor: AppColors.surface,
            child: LayoutBuilder(
              builder: (context, constraints) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  SizedBox(
                    height: constraints.maxHeight,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildEmptyState("YOUR LIBRARY IS EMPTY", isCompact),
                          SizedBox(height: isCompact ? 12.h : 10.0),
                          Text(
                            "Click the button below to add your first supplement",
                            textAlign: TextAlign.center,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textSecondary.withValues(alpha: 0.6),
                              fontSize: isCompact ? 12.sp : 11.0,
                            ),
                          ),
                          SizedBox(height: isCompact ? 24.h : 20.0),
                          Icon(
                            Icons.arrow_downward_rounded,
                            color: AppColors.crimson.withValues(alpha: 0.5),
                            size: isCompact ? 24.r : 20.0,
                          ),
                          _buildActionBtn(
                            "CREATE NEW SUPPLEMENT",
                            () => _openFormSheet(context),
                            isCompact,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return EliteRefreshIndicator(
          onRefresh: () => provider.forceRefresh(),
          color: AppColors.crimson,
          backgroundColor: AppColors.surface,
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isWide = constraints.maxWidth > 700;
                    if (isWide) {
                      final leftItems = <MapEntry<int, Supplement>>[];
                      final rightItems = <MapEntry<int, Supplement>>[];
                      for (int i = 0; i < provider.library.length; i++) {
                        if (i % 2 == 0) {
                          leftItems.add(MapEntry(i, provider.library[i]));
                        } else {
                          rightItems.add(MapEntry(i, provider.library[i]));
                        }
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(20.0),
                              itemCount: leftItems.length,
                              itemBuilder: (context, idx) {
                                final entry = leftItems[idx];
                                return LibraryCard(
                                  item: entry.value,
                                  provider: provider,
                                  index: entry.key,
                                  isCompact: false,
                                  onEdit: () {
                                    _openFormSheet(context, existingItem: entry.value, index: entry.key);
                                  },
                                  onDelete: () => _handleDeleteSupplement(context, provider, entry.value),
                                );
                              },
                            ),
                          ),
                          VerticalDivider(color: AppColors.white.withValues(alpha: 0.05), width: 1),
                          Expanded(
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(20.0),
                              itemCount: rightItems.length,
                              itemBuilder: (context, idx) {
                                final entry = rightItems[idx];
                                return LibraryCard(
                                  item: entry.value,
                                  provider: provider,
                                  index: entry.key,
                                  isCompact: false,
                                  onEdit: () {
                                    _openFormSheet(context, existingItem: entry.value, index: entry.key);
                                  },
                                  onDelete: () => _handleDeleteSupplement(context, provider, entry.value),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    }
                    return ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.all(20.r),
                      itemCount: provider.library.length,
                      itemBuilder: (context, index) {
                        final item = provider.library[index];
                        return LibraryCard(
                          item: item,
                          provider: provider,
                          index: index,
                          onEdit: () {
                            _openFormSheet(context, existingItem: item, index: index);
                          },
                          onDelete: () async {
                            final calorieProvider = context.read<CalorieProvider>();
                            final confirmed = await _showDeletePrompt(
                              context,
                              item.name,
                            );
                            if (confirmed == true) {
                              provider.deleteSupplement(
                                item.id,
                                onDeactivated: (id, cals, pro, cho, fat) {
                                  calorieProvider.removeSupplementFromAllMeals(id, cals, pro, cho, fat);
                                }
                              );
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              _buildActionBtn(
                "CREATE NEW SUPPLEMENT",
                () => _openFormSheet(context),
                isCompact,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab(bool isCompact) {
    return Consumer<SupplementProvider>(
      builder: (context, provider, _) {
        final Set<DateTime> dateSet = provider.history.map((h) => 
          DateTime(h.timestamp.year, h.timestamp.month, h.timestamp.day)
        ).toSet();
        
        final now = DateTime.now();
        dateSet.add(DateTime(now.year, now.month, now.day));

        var displayedHistory = provider.history.where((h) {
          final bool matchesDate = h.timestamp.year == _selectedHistoryDate.year &&
                 h.timestamp.month == _selectedHistoryDate.month &&
                 h.timestamp.day == _selectedHistoryDate.day;
          if (!matchesDate) return false;

          if (_historyFilter.searchQuery.isNotEmpty) {
            if (!h.supplementName.toLowerCase().contains(_historyFilter.searchQuery.toLowerCase())) {
              return false;
            }
          }

          if (_historyFilter.type != "ALL") {
            if (h.type.toUpperCase() != _historyFilter.type) return false;
          }

          final String details = h.details.toUpperCase();
          String source = "MANUAL";
          if (details.startsWith("MEAL LOG:")) {
            source = "MEAL";
          } else if (details.contains("NOTIFICATION")) {
            source = "NOTIF";
          } else if (details.contains("QUICK LOG") || details.contains("QUICK RESTOCK")) {
            source = "QUICK";
          } else if (details.contains("STACK LOG")) {
            source = "STACK";
          }

          if (!_historyFilter.sources.contains(source)) return false;

          return true;
        }).toList();

        displayedHistory.sort((a, b) {
          return _historyFilter.isDescending
              ? b.timestamp.compareTo(a.timestamp)
              : a.timestamp.compareTo(b.timestamp);
        });

        return LayoutBuilder(
          builder: (context, constraints) {
            final bool isWide = constraints.maxWidth > 700;

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- LEFT COLUMN: CALENDAR ---
                  Expanded(
                    flex: 5,
                    child: Container(
                      color: AppColors.background,
                      child: Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(vertical: 20.0),
                              child: _buildCustomExpandedCalendar(dateSet, isCompact),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  VerticalDivider(color: AppColors.white.withValues(alpha: 0.05), width: 1),
                  // --- RIGHT COLUMN: SLIDER + LOGS ---
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        _buildHorizontalCalendar(dateSet, isCompact),
                        const Divider(color: Colors.white10, height: 1),
                        Expanded(
                          child: EliteRefreshIndicator(
                            onRefresh: () => provider.forceRefresh(),
                            color: AppColors.crimson,
                            backgroundColor: AppColors.surface,
                            child: Column(
                              children: [
                                _buildHistoryHeader(context, provider, isCompact),
                                Expanded(
                                  child: displayedHistory.isEmpty
                                      ? Center(
                                          child: _buildEmptyState("No logs for this date.", isCompact),
                                        )
                                      : ListView.builder(
                                          physics: const AlwaysScrollableScrollPhysics(),
                                          padding: const EdgeInsets.all(20.0),
                                          itemCount: displayedHistory.length,
                                          itemBuilder: (context, index) {
                                            final entry = displayedHistory[index];
                                            return _buildHistoryItem(entry, provider, false);
                                          },
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            // --- MOBILE: SINGLE COLUMN ---
            if (_isCalendarExpanded) {
              return Container(
                color: AppColors.background,
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: _buildCustomExpandedCalendar(dateSet, isCompact),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() => _isCalendarExpanded = false);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          final now = DateTime.now();
                          final today = DateTime(now.year, now.month, now.day);
                          final target = DateTime(_selectedHistoryDate.year, _selectedHistoryDate.month, _selectedHistoryDate.day);
                          final int dayDiff = today.difference(target).inDays;
                          if (dayDiff >= 0 && dayDiff < 365) {
                            if (_pageController.hasClients) {
                              _pageController.animateToPage(
                                dayDiff, 
                                duration: const Duration(milliseconds: 300), 
                                curve: Curves.easeInOut
                              );
                            }
                          }
                        });
                      },
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        color: Colors.transparent,
                        child: Icon(
                          Icons.keyboard_arrow_up_rounded,
                          color: AppColors.textSecondary.withValues(alpha: 0.4),
                          size: 24.r,
                        ),
                      ),
                    ),
                    SizedBox(height: 20.h),
                  ],
                ),
              );
            }

            return Column(
              children: [
                _buildHorizontalCalendar(dateSet, isCompact),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isCalendarExpanded = true;
                      _displayedMonth = DateTime(_selectedHistoryDate.year, _selectedHistoryDate.month);
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 4.h),
                    color: Colors.transparent,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary.withValues(alpha: 0.4),
                      size: 24.r,
                    ),
                  ),
                ),
                const Divider(color: Colors.white10, height: 1),
                Expanded(
                  child: EliteRefreshIndicator(
                    onRefresh: () => provider.forceRefresh(),
                    color: AppColors.crimson,
                    backgroundColor: AppColors.surface,
                    child: Column(
                      children: [
                        _buildHistoryHeader(context, provider, isCompact),
                        Expanded(
                          child: displayedHistory.isEmpty
                              ? LayoutBuilder(
                                  builder: (context, constraints) => ListView(
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    padding: EdgeInsets.zero,
                                    children: [
                                      SizedBox(
                                        height: constraints.maxHeight,
                                        child: Center(
                                          child: _buildEmptyState("No logs for this date.", isCompact),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: EdgeInsets.all(20.r),
                                  itemCount: displayedHistory.length,
                                  itemBuilder: (context, index) {
                                    final entry = displayedHistory[index];
                                    return _buildHistoryItem(entry, provider, isCompact);
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryItem(SupplementItem entry, SupplementProvider provider, bool isCompact) {
    return Dismissible(
      key: Key("hist_${entry.id}"),
      direction: DismissDirection.endToStart,
      background: _buildSwipeBg(
        AppColors.error,
        Icons.delete_outline_rounded,
        Alignment.centerRight,
        isCompact,
      ),
      confirmDismiss: (_) async {
        final bool? didConfirm = await _showDeletePrompt(
          context,
          "ENTRY: ${entry.supplementName.toUpperCase()}",
        );
        return didConfirm ?? false;
      },
      onDismissed: (_) {
        final calorieProvider = context.read<CalorieProvider>();
        
        provider.removeSupplementItem(
          entry.id, 
          onSourceRollback: (sourceId, suppId, amount) {
            final mealLogIndex = calorieProvider.logs.indexWhere((l) => l.id == sourceId);
            if (mealLogIndex != -1) {
              final log = calorieProvider.logs[mealLogIndex];
              final supplement = provider.library.firstWhere((s) => s.id == suppId, orElse: () => null as dynamic);
              
              final bool isStandaloneLog = entry.details.contains("| SUPPLEMENT |");
              final bool isStackLog = entry.details.contains("| STACK: ");
              
              String? targetStackId;
              if (isStackLog) {
                 final parts = entry.details.split('|');
                 if (parts.length > 1) {
                    final stackName = parts[1].replaceAll("STACK:", "").trim();
                    try {
                       targetStackId = provider.supplementStacks.firstWhere(
                          (s) => s.name.toUpperCase() == stackName.toUpperCase()
                       ).id;
                    } catch (_) {}
                 }
              }

              final double rollbackCals = ((supplement.caloriesPerUnit ?? 0.0) * amount);
              final double rollbackPro = (supplement.proteinPerUnit ?? 0.0) * amount;
              final double rollbackCho = (supplement.carbsPerUnit ?? 0.0) * amount;
              final double rollbackFat = (supplement.fatsPerUnit ?? 0.0) * amount;

              String? newSuppsJson = log.addedSupplementsJson;
              String? newStacksJson = log.addedStacksJson;

              if (isStandaloneLog && newSuppsJson != null) {
                try {
                  List<dynamic> list = jsonDecode(newSuppsJson);
                  list.removeWhere((item) => ((item is Map) ? item['id'] : item) == suppId);
                  newSuppsJson = list.isEmpty ? null : jsonEncode(list);
                } catch (_) {}
              }

              if (isStackLog && newStacksJson != null) {
                try {
                  List<dynamic> stacksList = jsonDecode(newStacksJson);
                  final List<dynamic> updatedStacksList = [];

                  for (var stackEntry in stacksList) {
                     if (stackEntry is Map && stackEntry['itemAmounts'] is Map) {
                        final String sId = stackEntry['id'];
                        if (targetStackId == null || sId == targetStackId) {
                           Map<String, dynamic> itemAmounts = Map<String, dynamic>.from(stackEntry['itemAmounts']);
                           if (itemAmounts.containsKey(suppId)) {
                              itemAmounts.remove(suppId);
                              if (itemAmounts.isNotEmpty) {
                                 final newEntry = Map<String, dynamic>.from(stackEntry);
                                 newEntry['itemAmounts'] = itemAmounts;
                                 updatedStacksList.add(newEntry);
                              }
                              continue;
                           }
                        }
                     }
                     updatedStacksList.add(stackEntry);
                  }
                  newStacksJson = updatedStacksList.isEmpty ? null : jsonEncode(updatedStacksList);
                } catch (_) {}
              }

              final double? newPro = log.protein != null ? (log.protein! - rollbackPro).clamp(0, 1000) : null;
              final double? newCarbs = log.carbs != null ? (log.carbs! - rollbackCho).clamp(0, 1000) : null;
              final double? newFats = log.fats != null ? (log.fats! - rollbackFat).clamp(0, 1000) : null;

              calorieProvider.addLog(log.copyWith(
                calories: (log.calories - rollbackCals).clamp(0.0, 9999.999),
                protein: newPro != null && newPro > 0 ? newPro : null,
                carbs: newCarbs != null && newCarbs > 0 ? newCarbs : null,
                fats: newFats != null && newFats > 0 ? newFats : null,
                addedSupplementsJson: newSuppsJson,
                clearSupplements: newSuppsJson == null,
                addedStacksJson: newStacksJson,
                clearStacks: newStacksJson == null,
              ));
                                                    }
          }
        );
      },
      child: SupplementItemCard(entry: entry, isCompact: isCompact),
    );
  }

  Widget _buildCustomExpandedCalendar(Set<DateTime> dateSet, bool isCompact) {
    final daysInMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;
    final firstDayOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month, 1).weekday;
    final isCurrentMonth = _displayedMonth.year == DateTime.now().year && _displayedMonth.month == DateTime.now().month;
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 16.w : 16.0, vertical: isCompact ? 10.h : 8.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
                onPressed: () => setState(() {
                  _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month - 1);
                }),
              ),
              GestureDetector(
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    useRootNavigator: true,
                    initialDate: _selectedHistoryDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    builder: (context, child) => Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: AppColors.crimson,
                              onPrimary: Colors.white,
                              surface: AppColors.surface,
                              onSurface: Colors.white,
                            ),
                          ),
                          child: child!,
                        ),
                      ),
                    ),
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedHistoryDate = picked;
                      _displayedMonth = DateTime(picked.year, picked.month);
                    });
                  }
                },
                child: Text(
                  DateFormat('MMMM yyyy').format(_displayedMonth).toUpperCase(),
                  style: AppTextStyles.labelMedium.adaptive(context).copyWith(
                    color: Colors.white, 
                    letterSpacing: 1.5,
                    fontSize: isCompact ? 14.0 : 16.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right_rounded, color: isCurrentMonth ? Colors.white.withValues(alpha: 0.1) : Colors.white),
                onPressed: isCurrentMonth ? null : () => setState(() {
                  _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1);
                }),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ["M", "T", "W", "T", "F", "S", "S"].map((d) => Expanded(
              child: Text(
                d, 
                textAlign: TextAlign.center, 
                style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                  fontSize: isCompact ? 11.0 : 13.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 8.0),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemCount: daysInMonth + (firstDayOfMonth - 1),
            itemBuilder: (context, index) {
              if (index < firstDayOfMonth - 1) return const SizedBox.shrink();
              
              final day = index - (firstDayOfMonth - 1) + 1;
              final date = DateTime(_displayedMonth.year, _displayedMonth.month, day);
              final isSelected = date.year == _selectedHistoryDate.year &&
                  date.month == _selectedHistoryDate.month &&
                  date.day == _selectedHistoryDate.day;
              final hasData = dateSet.contains(date);
              final isToday = date.year == DateTime.now().year &&
                  date.month == DateTime.now().month &&
                  date.day == DateTime.now().day;
              final isFuture = date.isAfter(DateTime.now());

              return GestureDetector(
                onTap: isFuture ? null : () {
                  setState(() {
                    _selectedHistoryDate = date;
                  });
                },
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.crimson : Colors.transparent,
                      shape: BoxShape.circle,
                      border: isToday && !isSelected 
                          ? Border.all(color: AppColors.crimson.withValues(alpha: 0.5))
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          day.toString(),
                          style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                            fontSize: isCompact ? 13.0 : 15.0,
                            color: isSelected 
                                ? Colors.white 
                                : (isFuture ? Colors.white.withValues(alpha: 0.05) : (hasData ? Colors.white : Colors.white.withValues(alpha: 0.2))),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2.0),
                        Container(
                          width: 4.0,
                          height: 4.0,
                          decoration: BoxDecoration(
                            color: (hasData && !isSelected) ? AppColors.crimson : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalCalendar(Set<DateTime> dateSet, bool isCompact) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Container(
      height: isCompact ? 90.h : 80.0,
      padding: EdgeInsets.symmetric(vertical: isCompact ? 10.h : 8.0),
      child: PageView.builder(
        controller: _pageController,
        padEnds: false,
        physics: const PageScrollPhysics(),
        itemCount: 365,
        itemBuilder: (context, index) {
          final dateOnly = today.subtract(Duration(days: index));
          
          final isSelected = dateOnly.year == _selectedHistoryDate.year &&
              dateOnly.month == _selectedHistoryDate.month &&
              dateOnly.day == _selectedHistoryDate.day;
          
          final isToday = dateOnly.day == today.day && 
                          dateOnly.month == today.month && 
                          dateOnly.year == today.year;
          
          final hasData = dateSet.contains(dateOnly);

          return GestureDetector(
            onTap: () {
              setState(() => _selectedHistoryDate = dateOnly);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.symmetric(horizontal: isCompact ? 6.w : 6.0),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.crimson : Colors.transparent,
                borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
                border: isToday && !isSelected 
                    ? Border.all(color: AppColors.crimson.withValues(alpha: 0.5))
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('EEE').format(dateOnly).toUpperCase(),
                    style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                      color: isSelected 
                          ? Colors.white 
                          : (hasData ? AppColors.textSecondary : AppColors.textSecondary.withValues(alpha: 0.2)),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: isCompact ? 4.h : 4.0),
                  Text(
                    dateOnly.day.toString(),
                    style: AppTextStyles.h3.adaptive(context).copyWith(
                      color: isSelected 
                          ? Colors.white 
                          : (hasData ? AppColors.white : AppColors.white.withValues(alpha: 0.15)),
                    ),
                  ),
                  if (hasData && !isSelected)
                    Container(
                      margin: EdgeInsets.only(top: isCompact ? 4.h : 4.0),
                      width: isCompact ? 4.r : 4.0,
                      height: isCompact ? 4.r : 4.0,
                      decoration: const BoxDecoration(
                        color: AppColors.crimson,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- SHEET OPENERS ---

  void _openStackFormSheet(BuildContext context) {
    AdaptiveUtils.showAdaptiveSheet(
      context: context,
      sheetBuilder: (sheetContext, isSideSheet) => StackFormSheet(isSideSheet: isSideSheet),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _openIntakeSheet(BuildContext context, Supplement supp) {
    AdaptiveUtils.showAdaptiveSheet(
      context: context,
      sheetBuilder: (sheetContext, isSideSheet) => IntakeSheet(
        isSideSheet: isSideSheet,
        supplement: supp,
        onConfirm:
            ({
              required bool recordIntake,
              required bool restockInventory,
              required double intakeVal,
              required double restockVal,
              required bool useServingsForIntake,
              required bool useServingsForRestock,
              required DateTime selectedTimestamp,
            }) {
              final provider = context.read<SupplementProvider>();

              double intakeWeight = useServingsForIntake
                  ? (intakeVal * supp.weightPerServing)
                  : intakeVal;

              double restockWeight = useServingsForRestock
                  ? (restockVal * supp.weightPerServing)
                  : restockVal;

              if (recordIntake) {
                provider.recordEntry(
                  supplement: supp,
                  isIntake: true,
                  isRestock: false,
                  weightAdjustment: -intakeWeight,
                  historyDetails:
                      "Intake: $intakeVal ${useServingsForIntake ? supp.servingUnit : supp.weightUnit}",
                  timestamp: selectedTimestamp,
                );
              }

              if (restockInventory) {
                provider.recordEntry(
                  supplement: supp,
                  isIntake: false,
                  isRestock: true,
                  weightAdjustment: restockWeight,
                  historyDetails:
                      "Restock: $restockVal ${useServingsForRestock ? supp.servingUnit : supp.weightUnit}",
                  timestamp: selectedTimestamp,
                );
              }

              if (mounted) {
                String msg = "${supp.name} RECORDED";
                if (restockInventory && !recordIntake) msg = "${supp.name} RESTOCKED";
                if (restockInventory && recordIntake) msg = "${supp.name} UPDATED";

                EliteSnackbar.show(
                  context, 
                  msg, 
                  onUndo: () => provider.deleteLastEntry()
                );
              }

              Navigator.pop(sheetContext);
            },
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _openFormSheet(
    BuildContext context, {
    Supplement? existingItem,
    int? index,
  }) {
    AdaptiveUtils.showAdaptiveSheet(
      context: context,
      sheetBuilder: (sheetContext, isSideSheet) => SupplementFormSheet(
        isSideSheet: isSideSheet,
        existingItem: existingItem,
        index: index,
        onSave: (item, idx) => context
            .read<SupplementProvider>()
            .addOrUpdateSupplement(item, index: idx),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _openNotificationSheet(BuildContext context, Supplement supp) {
    AdaptiveUtils.showAdaptiveSheet(
      context: context,
      sheetBuilder: (sheetContext, isSideSheet) => NotificationSheet(
        isSideSheet: isSideSheet,
        supplement: supp,
        initialReminders: supp.reminders,
        initialEnabled: supp.notificationsEnabled,
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _openQuickLogSheet(BuildContext context, Supplement supp) {
    AdaptiveUtils.showAdaptiveSheet(
      context: context,
      sheetBuilder: (sheetContext, isSideSheet) => QuickLogSheet(
        isSideSheet: isSideSheet,
        supplement: supp,
        onSave:
            ({
              required bool isPinned,
              required double intakeVal,
              required bool useServingsIntake,
              required double restockVal,
              required bool useServingsRestock,
            }) {
              context.read<SupplementProvider>().updateShortcutSettings(
                id: supp.id,
                isPinned: isPinned,
                intakeAmount: intakeVal,
                useServingsIntake: useServingsIntake,
                restockAmount: restockVal,
                useServingsRestock: useServingsRestock,
              );
            },
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  // --- SHARED UI HELPERS ---

  Widget _buildSectionHeader(String title, bool isCompact) {
    return Row(
      children: [
        Container(
          width: 2.5,
          height: 12.0,
          decoration: BoxDecoration(
            color: AppColors.crimson,
            borderRadius: BorderRadius.circular(2.0),
          ),
        ),
        const SizedBox(width: 6.0),
        Text(
          title,
          style: AppTextStyles.labelSmall.adaptive(context).copyWith(
            color: AppColors.textSecondary.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryHeader(BuildContext context, SupplementProvider provider, bool isCompact) {
    return Container(
      padding: EdgeInsets.fromLTRB(isCompact ? 20.r : 20.0, 0, isCompact ? 20.r : 20.0, isCompact ? 12.h : 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildSectionHeader("SUPPLEMENT LOGS", isCompact),
          IconButton(
            onPressed: () => _openFilterSheet(provider),
            icon: Icon(
              _historyFilter.isInitial 
                  ? Icons.filter_list_rounded 
                  : Icons.filter_list_off_rounded,
              color: _historyFilter.isInitial ? AppColors.crimson : Colors.orangeAccent,
              size: isCompact ? 20.r : 18.0,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: "Filter Logs",
          ),
        ],
      ),
    );
  }

  void _openFilterSheet(SupplementProvider provider) {
    AdaptiveUtils.showAdaptiveSheet(
      context: context,
      sheetBuilder: (sheetContext, isSideSheet) => _SupplementHistoryFilterSheet(
        isSideSheet: isSideSheet,
        initialFilter: _historyFilter,
        onApply: (newFilter) => setState(() => _historyFilter = newFilter),
      ),
    );
  }

  Future<bool?> _showDeletePrompt(BuildContext context, String title) {
    return EliteConfirmDialog.show(
      context,
      title: "DELETE ${title.toUpperCase()}",
      message: "Are you sure you want to permanently delete this item? This action cannot be undone.",
    );
  }

  Future<void> _handleDeleteSupplement(
    BuildContext context, 
    SupplementProvider provider, 
    Supplement item
  ) async {
    final calorieProvider = context.read<CalorieProvider>();
    final confirmed = await _showDeletePrompt(
      context,
      item.name,
    );
    if (confirmed == true) {
      provider.deleteSupplement(
        item.id,
        onDeactivated: (id, cals, pro, cho, fat) {
          calorieProvider.removeSupplementFromAllMeals(id, cals, pro, cho, fat);
        }
      );
    }
  }

  Widget _buildSwipeBg(Color c, IconData i, Alignment a, bool isCompact) => Container(
    margin: EdgeInsets.only(bottom: isCompact ? 12.h : 10.0),
    padding: EdgeInsets.symmetric(horizontal: isCompact ? 24.w : 20.0),
    alignment: a,
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0),
    ),
    child: Icon(i, color: c, size: isCompact ? 28.r : 24.0),
  );

  Widget _buildEmptyState(String m, bool isCompact) => Center(
    child: Text(
      m,
      textAlign: TextAlign.center,
      style: AppTextStyles.labelSmall.adaptive(context).copyWith(
        color: AppColors.textSecondary,
      ),
    ),
  );

  Widget _buildActionBtn(String l, VoidCallback o, bool isCompact) => Padding(
    padding: EdgeInsets.all(isCompact ? 20.r : 16.0),
    child: GestureDetector(
      onTap: o,
      child: Container(
        height: isCompact ? 56.h : 48.0,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.crimson.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
          border: Border.all(color: AppColors.crimson),
        ),
        alignment: Alignment.center,
        child: Text(
          l,
          style: AppTextStyles.buttonPrimary.adaptive(context).copyWith(
            color: AppColors.crimson,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ),
  );
}

class _SupplementHistoryFilterSheet extends StatefulWidget {
  final _HistoryFilter initialFilter;
  final Function(_HistoryFilter) onApply;
  final bool isSideSheet;

  const _SupplementHistoryFilterSheet({
    required this.initialFilter,
    required this.onApply,
    this.isSideSheet = false,
  });

  @override
  State<_SupplementHistoryFilterSheet> createState() => _SupplementHistoryFilterSheetState();
}

class _SupplementHistoryFilterSheetState extends State<_SupplementHistoryFilterSheet> {
  late _HistoryFilter _currentFilter;

  @override
  void initState() {
    super.initState();
    _currentFilter = _HistoryFilter(
      isDescending: widget.initialFilter.isDescending,
      searchQuery: widget.initialFilter.searchQuery,
      type: widget.initialFilter.type,
      sources: Set<String>.from(widget.initialFilter.sources),
    );
  }

  void _updateFilter(_HistoryFilter newFilter) {
    setState(() => _currentFilter = newFilter);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 600 && !widget.isSideSheet;
        final double sheetWidth = widget.isSideSheet ? constraints.maxWidth : (isCompact ? constraints.maxWidth : 500.0);

        return Center(
          child: SizedBox(
            width: sheetWidth,
            child: Container(
              height: widget.isSideSheet ? double.infinity : null,
              padding: EdgeInsets.fromLTRB(
                isCompact ? 24.w : 24.0, 
                widget.isSideSheet ? 0 : (isCompact ? 12.h : 12.0), 
                isCompact ? 24.w : 24.0, 
                isCompact ? 40.h : 30.0
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: widget.isSideSheet 
                  ? const BorderRadius.horizontal(left: Radius.circular(24.0))
                  : BorderRadius.vertical(top: Radius.circular(isCompact ? 32.r : 24.0)),
                border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                mainAxisSize: widget.isSideSheet ? MainAxisSize.max : MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.isSideSheet) SizedBox(height: 24.0),
                  if (!widget.isSideSheet)
                    Center(
                      child: Container(
                        margin: EdgeInsets.only(bottom: isCompact ? 16.h : 12.0),
                        width: isCompact ? 40.w : 40.0,
                        height: isCompact ? 4.h : 4.0,
                        decoration: BoxDecoration(
                          color: AppColors.textSecondary.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2.r),
                        ),
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "FILTER HISTORY", 
                        style: AppTextStyles.h3.adaptive(context)
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => setState(() => _currentFilter = _HistoryFilter()),
                            child: Text(
                              "RESET",
                              style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                color: AppColors.crimson,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (widget.isSideSheet)
                            IconButton(
                              icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                              onPressed: () => Navigator.pop(context),
                            ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: isCompact ? 24.h : 20.0),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionLabel("SORT ORDER", isCompact),
                          Row(
                            children: [
                              _buildToggleButton(
                                label: "NEWEST FIRST",
                                isSelected: _currentFilter.isDescending,
                                isCompact: isCompact,
                                onTap: () => _updateFilter(_currentFilter.copyWith(isDescending: true)),
                              ),
                              SizedBox(width: isCompact ? 12.w : 12.0),
                              _buildToggleButton(
                                label: "OLDEST FIRST",
                                isSelected: !_currentFilter.isDescending,
                                isCompact: isCompact,
                                onTap: () => _updateFilter(_currentFilter.copyWith(isDescending: false)),
                              ),
                            ],
                          ),
                          SizedBox(height: isCompact ? 24.h : 20.0),
                          _buildSectionLabel("LOG TYPE", isCompact),
                          Row(
                            children: [
                              _buildToggleButton(
                                label: "ALL",
                                isSelected: _currentFilter.type == "ALL",
                                isCompact: isCompact,
                                onTap: () => _updateFilter(_currentFilter.copyWith(type: "ALL")),
                              ),
                              SizedBox(width: isCompact ? 8.w : 8.0),
                              _buildToggleButton(
                                label: "INTAKE",
                                isSelected: _currentFilter.type == "INTAKE",
                                isCompact: isCompact,
                                onTap: () => _updateFilter(_currentFilter.copyWith(type: "INTAKE")),
                              ),
                              SizedBox(width: isCompact ? 8.w : 8.0),
                              _buildToggleButton(
                                label: "RESTOCK",
                                isSelected: _currentFilter.type == "RESTOCK",
                                isCompact: isCompact,
                                onTap: () => _updateFilter(_currentFilter.copyWith(type: "RESTOCK")),
                              ),
                            ],
                          ),
                          SizedBox(height: isCompact ? 24.h : 20.0),
                          _buildSectionLabel("SOURCE FILTERS", isCompact),
                          Wrap(
                            spacing: isCompact ? 8.w : 8.0,
                            runSpacing: isCompact ? 8.h : 8.0,
                            children: [
                              _buildSourceChip("MEAL", "MEAL LOGS", isCompact),
                              _buildSourceChip("NOTIF", "NOTIFICATIONS", isCompact),
                              _buildSourceChip("QUICK", "QUICK LOGS", isCompact),
                              _buildSourceChip("STACK", "STACK LOGS", isCompact),
                              _buildSourceChip("MANUAL", "MANUAL ENTRY", isCompact),
                            ],
                          ),
                          SizedBox(height: isCompact ? 32.h : 24.0),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                widget.onApply(_currentFilter);
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.crimson,
                                padding: EdgeInsets.symmetric(vertical: isCompact ? 16.h : 14.0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
                                ),
                              ),
                              child: Text(
                                "APPLY FILTERS",
                                style: AppTextStyles.buttonPrimary.adaptive(context).copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ),
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
      },
    );
  }

  Widget _buildSectionLabel(String label, bool isCompact) {
    return Padding(
      padding: EdgeInsets.only(bottom: isCompact ? 12.h : 10.0),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.adaptive(context).copyWith(
          color: AppColors.textSecondary.withValues(alpha: 0.5),
          letterSpacing: 1.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildToggleButton({required String label, required bool isSelected, required VoidCallback onTap, required bool isCompact}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: isCompact ? 12.h : 12.0),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.crimson.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
            border: Border.all(
              color: isSelected ? AppColors.crimson : AppColors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                color: isSelected ? AppColors.crimson : AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSourceChip(String source, String label, bool isCompact) {
    final bool isSelected = _currentFilter.sources.contains(source);
    return GestureDetector(
      onTap: () {
        final sources = Set<String>.from(_currentFilter.sources);
        if (isSelected) {
          sources.remove(source);
        } else {
          sources.add(source);
        }
        _updateFilter(_currentFilter.copyWith(sources: sources));
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 12.w : 12.0, 
          vertical: isCompact ? 8.h : 8.0
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.crimson.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(isCompact ? 8.r : 6.0),
          border: Border.all(
            color: isSelected ? AppColors.crimson : AppColors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label.toUpperCase(),
          style: AppTextStyles.labelSmall.adaptive(context).copyWith(
            color: isSelected ? AppColors.crimson : AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
