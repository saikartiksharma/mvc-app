// lib/screens/feed_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';


class FeedScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const FeedScreen({Key? key, required this.userData}) : super(key: key);

  @override
  _FeedScreenState createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<Map<String, dynamic>> _allFeedData = [];
  List<Map<String, dynamic>> _filteredFeedData = [];
  bool _isLoading = true;
  String _errorMessage = '';

  static const String _feedCacheKey = 'cached_feed_data';
  static const Duration _cacheDuration = Duration(hours: 1);

  static const String _databaseURL = 'https://health-tracker-6e37d-default-rtdb.asia-southeast1.firebasedatabase.app';

  final FirebaseDatabase _database = FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: _databaseURL);
  late DatabaseReference _feedRef;

  StreamSubscription<DatabaseEvent>? _feedSubscription;

  final List<String> _alwaysShowKeywords = ['general wellness', 'nutrition fundamentals'];
  Set<String> _interestedItemIds = {};
  Set<String> _expandedFeedItemIds = {};

  @override
  void initState() {
    super.initState();
    // Assuming your feed data (the list) is directly at the root of this database instance
    _feedRef = _database.ref();
    // If your list of items is under a specific path, e.g., "feedItems", then:
    // _feedRef = _database.ref('feedItems');

    _loadInitialFeedAndSubscribe(); // <<< CORRECTED METHOD CALL HERE
  }

  // ... (The rest of the FeedScreen code remains the same as the previous fully corrected version) ...
  @override
  void dispose() {
    _feedSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialFeedAndSubscribe() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final String? cachedFeedString = prefs.getString(_feedCacheKey);
    if (cachedFeedString == null && mounted) {
      setState(() => _isLoading = true);
    }

    await _loadInterestedItems();
    bool cacheLoaded = await _loadFeedFromCache();

    if (cacheLoaded) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
    _subscribeToFeedUpdates(isInitialLoad: !cacheLoaded);
  }

  Future<bool> _loadFeedFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final String? cachedFeedString = prefs.getString(_feedCacheKey);
    final int? cacheTimestamp = prefs.getInt('${_feedCacheKey}_timestamp');

    if (cachedFeedString != null && cacheTimestamp != null) {
      final DateTime cacheDate = DateTime.fromMillisecondsSinceEpoch(cacheTimestamp);
      if (DateTime.now().difference(cacheDate) < _cacheDuration || _allFeedData.isEmpty) {
        try {
          final List<dynamic> jsonData = jsonDecode(cachedFeedString);
          if (mounted) {
            _allFeedData = List<Map<String, dynamic>>.from(
                jsonData.map((item) {
                  if (item is Map) return Map<String, dynamic>.from(item);
                  return {};
                }).where((item) => item.isNotEmpty)
            );
            _applyFilters();
            if (kDebugMode) print("Feed loaded from cache. Items: ${_allFeedData.length}");
            return true;
          }
        } catch (e) {
          if (kDebugMode) print("Error decoding cached feed: $e");
          await prefs.remove(_feedCacheKey);
          await prefs.remove('${_feedCacheKey}_timestamp');
        }
      }
    }
    return false;
  }

  Future<void> _saveFeedToCache(List<Map<String, dynamic>> feedData) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await prefs.setString(_feedCacheKey, jsonEncode(feedData));
      await prefs.setInt('${_feedCacheKey}_timestamp', DateTime.now().millisecondsSinceEpoch);
      if (kDebugMode) print("Feed saved to cache.");
    } catch (e) {
      if (kDebugMode) print("Error saving feed to cache: $e");
    }
  }

  void _subscribeToFeedUpdates({bool isInitialLoad = true}) {
    if (isInitialLoad && _allFeedData.isEmpty && mounted) {
      if (!_isLoading) setState(() => _isLoading = true);
    }

    _feedSubscription?.cancel();
    _feedSubscription = _feedRef.onValue.listen((DatabaseEvent event) { // Corrected usage
      if (!mounted) return;

      if (event.snapshot.value != null) {
        final data = event.snapshot.value;
        List<Map<String, dynamic>> networkFeedData = [];

        if (data is List) {
          for (var i = 0; i < data.length; i++) {
            var value = data[i];
            // Skip null items that can appear in RTDB lists if an index is missing
            if (value == null) continue;
            if (value is Map) {
              Map<String, dynamic> item = Map<String, dynamic>.from(value);
              var content = item['feed_content']?.toString() ?? '';
              item['id'] = item['id']?.toString() ?? '${_feedRef.path}_item_$i';
              item['title'] = _getTitleFromContent(content);
              item['instructions'] = _getInstructionsFromContent(content);
              if (item['keywords'] is List) {
                item['keywords'] = List<String>.from(item['keywords'].map((e) => e.toString()));
              } else {
                item['keywords'] = <String>[];
              }
              networkFeedData.add(item);
            }
          }
        } else if (data is Map) { // Fallback for Map<Key, Item> structure
          data.forEach((key, value) {
            if (value is Map) {
              Map<String, dynamic> item = Map<String, dynamic>.from(value);
              var content = item['feed_content']?.toString() ?? '';
              item['id'] = item['id']?.toString() ?? key;
              item['title'] = _getTitleFromContent(content);
              item['instructions'] = _getInstructionsFromContent(content);
              if (item['keywords'] is List) {
                item['keywords'] = List<String>.from(item['keywords'].map((e)=>e.toString()));
              } else {
                item['keywords'] = <String>[];
              }
              networkFeedData.add(item);
            }
          });
        }

        setState(() {
          _errorMessage = '';
          _allFeedData = networkFeedData;
          _applyFilters();
          _isLoading = false;
        });
        _saveFeedToCache(networkFeedData);
        if (kDebugMode) print("Feed updated from Firebase RTDB. Items: ${networkFeedData.length}");
      } else {
        if (kDebugMode) print("No data at Firebase RTDB path: ${_feedRef.path}");
        if(mounted) {
          setState(() {
            _allFeedData.clear();
            _filteredFeedData.clear();
            if (_allFeedData.isEmpty) _errorMessage = "No feed items found. Pull to refresh.";
            _isLoading = false;
          });
        }
      }
    }, onError: (Object error) {
      if (kDebugMode) print("Firebase Realtime Database error: $error");
      if (mounted) {
        setState(() {
          if (_allFeedData.isEmpty) _errorMessage = "Error fetching feed. Pull to refresh.";
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _loadInterestedItems() async {
    final prefs = await SharedPreferences.getInstance();
    final String todayKey = 'daily_progress_${DateFormat('yyyy-MM-dd').format(DateTime.now())}';
    final List<String>? interestedListJson = prefs.getStringList(todayKey);
    if (interestedListJson != null) {
      final Set<String> tempIds = {};
      for (String itemJson in interestedListJson) {
        try {
          final Map<String, dynamic> item = jsonDecode(itemJson);
          tempIds.add(item['id']?.toString() ?? item['title']?.toString() ?? (item['feed_content']?.toString() ?? ''));
        } catch(e) {
          if (kDebugMode) print("Error decoding interested item from prefs: $e");
        }
      }
      if (mounted) {
        setState(() {
          _interestedItemIds = tempIds;
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant FeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userData != oldWidget.userData && _allFeedData.isNotEmpty) {
      _applyFilters();
    }
  }

  String _getTitleFromContent(String content) {
    int periodIndex = content.indexOf('.');
    if (periodIndex != -1 && periodIndex < 80) {
      return content.substring(0, periodIndex + 1).trim();
    }
    int spaceIndex = content.indexOf(' ', min(content.length, 50));
    if (spaceIndex != -1 && spaceIndex < 80 ) {
      return '${content.substring(0, spaceIndex).trim()}...';
    }
    return content.length > 60 ? '${content.substring(0, 60).trim()}...' : content.trim();
  }

  List<String> _getInstructionsFromContent(String content) {
    String title = _getTitleFromContent(content);
    String instructionContent = content;
    if (title.endsWith('...')) {
      String originalTitleStart = title.substring(0, title.length - 3);
      if(content.startsWith(originalTitleStart)){
        int potentialTitleEnd = originalTitleStart.length;
        int nextBreak = content.indexOf(RegExp(r'[\.\s]'), potentialTitleEnd);
        if(nextBreak != -1 && nextBreak < (originalTitleStart.length + 30)){
          instructionContent = content.substring(nextBreak + 1).trim();
        } else if (content.length > originalTitleStart.length) {
          instructionContent = content.substring(originalTitleStart.length).trim();
        } else {
          instructionContent = "";
        }
      }
    } else if (content.startsWith(title)) {
      instructionContent = content.substring(title.length).trim();
    }

    if (instructionContent.isEmpty) return [];

    if (instructionContent.contains(RegExp(r'[\n•*-]'))) {
      return instructionContent.split(RegExp(r'[\n•*-]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    } else {
      return [instructionContent];
    }
  }

  void _applyFilters() {
    if (widget.userData == null && _allFeedData.isEmpty && mounted) {
      return;
    }
    final userDietaryPreference = widget.userData?['dietaryPreference']?.toLowerCase();
    final userAllergies = (widget.userData?['allergies'] as List<dynamic>?)
        ?.map((a) => a.toString().toLowerCase())
        .toList() ?? [];
    final hasDiabetes = widget.userData?['hasDiabetes'] ?? false;
    final hasProteinDeficiency = widget.userData?['hasProteinDeficiency'] ?? false;
    final isSkinnyFat = widget.userData?['isSkinnyFat'] ?? false;

    _filteredFeedData = _allFeedData.where((feedItem) {
      final feedKeywords = List<String>.from(feedItem['keywords']?.map((k) => k.toString().toLowerCase()) ?? []);
      final isAlwaysShowFeed = feedKeywords.any((keyword) => _alwaysShowKeywords.contains(keyword));

      bool itemHasAllergyConflict = userAllergies.any((allergy) => feedKeywords.contains(allergy));
      if (itemHasAllergyConflict) return false;

      if (isAlwaysShowFeed) return true;

      bool dietaryMatch = true;
      if (userDietaryPreference != null) {
        if (userDietaryPreference == 'vegetarian' && !(feedKeywords.contains('veg') || feedKeywords.contains('vegetarian') || feedKeywords.contains('vegan'))) dietaryMatch = false;
        else if (userDietaryPreference == 'vegan' && !feedKeywords.contains('vegan')) dietaryMatch = false;
      }
      if (!dietaryMatch) return false;

      bool itemIsGeneral = !feedKeywords.any((k) => ['diabetes', 'protein deficient', 'skinny fat'].contains(k));
      bool conditionMatch = false;
      if (hasDiabetes && feedKeywords.contains('diabetes')) conditionMatch = true;
      if (hasProteinDeficiency && feedKeywords.contains('protein deficient')) conditionMatch = true;
      if (isSkinnyFat && feedKeywords.contains('skinny fat')) conditionMatch = true;
      bool userHasAnyCondition = hasDiabetes || hasProteinDeficiency || isSkinnyFat;

      if (userHasAnyCondition) return itemIsGeneral || conditionMatch;
      else return itemIsGeneral;
    }).toList();
  }

  Future<void> _markAsInterested(Map<String, dynamic> feedItem) async {
    final prefs = await SharedPreferences.getInstance();
    final String todayKey = 'daily_progress_${DateFormat('yyyy-MM-dd').format(DateTime.now())}';
    List<String> interestedListJson = prefs.getStringList(todayKey) ?? [];
    String itemId = feedItem['id'].toString();

    if (_interestedItemIds.contains(itemId)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"${feedItem['title']}" is already in your daily tasks.')));
      return;
    }
    final taskData = {
      'id': itemId,
      'title': feedItem['title'],
      'timestamp': DateTime.now().toIso8601String(),
      'isDone': false,
      'type': 'feed',
    };
    interestedListJson.add(jsonEncode(taskData));
    await prefs.setStringList(todayKey, interestedListJson);
    if (mounted) setState(() { _interestedItemIds.add(itemId); });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added to daily tasks: "${feedItem['title']}"')),
    );
  }

  Widget _buildHealthTipCard(
      BuildContext context, {
        required String title,
        required String description,
        required IconData icon,
        required Color color,
        required List<String> tips,
      }) {
    return Card(
      key: ValueKey('healthTip_$title'),
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: ExpansionTile(
        key: PageStorageKey('expansionHealthTip_$title'),
        leading: Icon(icon, size: 36, color: color),
        title: Tooltip(
          message: title,
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        subtitle: Tooltip(
          message: description,
          child: Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16,0,16,16),
        children: [
          const Divider(height: 1, thickness: 0.5, indent: 0, endIndent: 0),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 0.0, bottom: 4.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Actionable Tips:',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color.withOpacity(0.85),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...tips.map((tip) => Padding(
            padding: const EdgeInsets.only(bottom: 6.0, left: 0.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Icon(Icons.check_circle_outline, size: 18, color: color.withOpacity(0.7)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(tip, style: Theme.of(context).textTheme.bodyMedium)),
              ],
            ),
          )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool showPersonalizedHealthTips = widget.userData != null;
    final String userName = widget.userData?['name']?.toString().split(' ').first ?? "User";

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Feed'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: (){
              _loadInterestedItems();
              _subscribeToFeedUpdates(isInitialLoad: _allFeedData.isEmpty);
            },
            tooltip: 'Refresh Feed',
          )
        ],
      ),
      body: _isLoading && _allFeedData.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _buildFeedContent(context, showPersonalizedHealthTips, userName),
    );
  }

  Widget _buildFeedContent(BuildContext context, bool showPersonalizedHealthTips, String userName) {
    if (_errorMessage.isNotEmpty && _allFeedData.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 48),
              const SizedBox(height: 16),
              Text('Oops! Something went wrong.', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(_errorMessage.contains("No feed items found") ? _errorMessage : "Could not load feed. Please check your connection.", textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
              const SizedBox(height: 20),
              ElevatedButton.icon(icon: const Icon(Icons.refresh), label: const Text('Try Again'), onPressed: () => _subscribeToFeedUpdates(isInitialLoad: true),)
            ],
          ),
        ),
      );
    }
    if (_allFeedData.isEmpty && _filteredFeedData.isEmpty && _errorMessage.isEmpty && !_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.hourglass_empty_outlined, size: 48, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
              const SizedBox(height: 16),
              Text('No feed items available right now. Pull to refresh.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadInterestedItems();
        _subscribeToFeedUpdates(isInitialLoad: _allFeedData.isEmpty);
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 16.0),
        children: [
          Padding(
            padding: const EdgeInsets.only(top:20.0, left: 16.0, right: 16.0, bottom: 10.0),
            child: Text(
              'Hi $userName! Here are some health tips for you.',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.normal),
            ),
          ),
          if (showPersonalizedHealthTips) ...[
            if (widget.userData!['hasDiabetes'] == true)
              _buildHealthTipCard(context, title: 'Managing Diabetes', description: 'Tips to help control blood sugar levels.', icon: Icons.healing_outlined, color: Theme.of(context).colorScheme.error,
                tips: ['Monitor blood glucose regularly', 'Follow a balanced, portion-controlled diet', 'Exercise regularly (30 mins/day)','Take medications as prescribed','Stay hydrated, limit alcohol'],),
            if (widget.userData!['hasProteinDeficiency'] == true)
              _buildHealthTipCard(context, title: 'Boosting Protein Intake', description: 'Ways to increase protein for health.', icon: Icons.restaurant_menu_outlined, color: Theme.of(context).colorScheme.primary,
                tips: ['Include lean meats, poultry, or eggs in your meals.', 'Add legumes (beans, lentils, chickpeas) to soups and salads.', 'Incorporate Greek yogurt, cottage cheese, or tofu as snacks.', 'Choose nuts, seeds, and nut butters in moderation.', 'Consider protein-rich grains like quinoa or amaranth.', 'If vegetarian/vegan, ensure diverse plant-based protein sources.'],),
            if (widget.userData!['isSkinnyFat'] == true)
              _buildHealthTipCard(context, title: 'Addressing "Skinny Fat"', description: 'Strategies to build muscle and reduce body fat.', icon: Icons.fitness_center_outlined, color: Theme.of(context).colorScheme.secondary,
                tips: ['Prioritize resistance training (weights, bodyweight) 2-4 times per week.', 'Focus on compound exercises like squats, deadlifts, presses, and rows.', 'Ensure adequate protein intake to support muscle growth.', 'Get sufficient rest and recovery between workouts.'],),
          ],
          _buildHealthTipCard(context, title: 'General Wellness Tips', description: 'Daily habits for better overall health.', icon: Icons.favorite_border_outlined, color: Colors.pink.shade400,
            tips: ['Aim for 7-8 hours of quality sleep','Stay hydrated (2-3 liters water/day)','Practice mindfulness or meditation','Take short breaks from prolonged sitting','Maintain social connections'],),
          _buildHealthTipCard(context, title: 'Nutrition Fundamentals', description: 'Basic principles for a balanced diet.', icon: Icons.set_meal_outlined, color: Colors.deepPurple.shade400,
            tips: ['Eat a variety of fruits and vegetables','Choose whole grains over refined carbs','Limit processed foods and added sugars','Include healthy fats (avocados, nuts)','Practice portion control'],),

          if (_allFeedData.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 24.0, left: 16.0, right: 16.0, bottom: 8.0),
              child: Text('Curated For You', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            ),
            if (_filteredFeedData.isEmpty && _errorMessage.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                child: Center( child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.dynamic_feed_outlined, size: 48, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text('No new feed items match your preferences right now.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
                ])),
              )
            else if (_filteredFeedData.isEmpty && _errorMessage.isNotEmpty && !_errorMessage.contains("No feed items found"))
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                  child: Center( child: Text(_errorMessage,  textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.error.withOpacity(0.8)))))
            else
              ..._filteredFeedData.map((feedItem) {
                String itemId = feedItem['id'].toString();
                bool isAlreadyInterested = _interestedItemIds.contains(itemId);
                String title = feedItem['title'] ?? 'Info';
                List<String> instructions = List<String>.from(feedItem['instructions'] ?? []);

                return Card(
                  key: ValueKey('curatedFeed_$itemId'),
                  margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  elevation: 2,
                  child: ExpansionTile(
                    key: PageStorageKey('expansionCurated_$itemId'),
                    onExpansionChanged: (isExpanded) {
                      setState(() {
                        if (isExpanded) _expandedFeedItemIds.add(itemId);
                        else _expandedFeedItemIds.remove(itemId);
                      });
                    },
                    initiallyExpanded: _expandedFeedItemIds.contains(itemId),
                    title: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    childrenPadding: const EdgeInsets.fromLTRB(16,0,16,16),
                    iconColor: Theme.of(context).colorScheme.primary,
                    collapsedIconColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    children: <Widget>[
                      const Divider(height:1),
                      const SizedBox(height: 10),
                      if (instructions.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom:8.0),
                          child: Text( "No further instructions available for this item.", style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
                        )
                      else
                        ...instructions.map((instruction) => Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Icon(Icons.check_circle_outline, size: 18, color: Theme.of(context).colorScheme.primary.withOpacity(0.8)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Text(instruction, style: Theme.of(context).textTheme.bodyMedium)),
                            ],
                          ),
                        )).toList(),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          icon: Icon(isAlreadyInterested ? Icons.check_circle_outline : Icons.add_task_outlined, size: 18),
                          label: Text(isAlreadyInterested ? 'Added' : 'Interested', style: const TextStyle(fontSize: 12)),
                          onPressed: isAlreadyInterested ? null : () => _markAsInterested(feedItem),
                          style: ElevatedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            backgroundColor: isAlreadyInterested ? Colors.grey.shade300 : Theme.of(context).colorScheme.secondaryContainer,
                            foregroundColor: isAlreadyInterested ? Colors.grey.shade700 : Theme.of(context).colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
          ],
        ],
      ),
    );
  }
}