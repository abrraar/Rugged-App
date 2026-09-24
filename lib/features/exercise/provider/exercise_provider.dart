import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rugged/core/services/connectivity_service.dart';
import 'package:rugged/features/auth/provider/auth_provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';
import '../model/exercise_template.dart';
import '../data/exercise_local_repository.dart';
import '../data/exercise_cloud_repository.dart';

import 'package:rugged/core/providers/sync_provider.dart';

class ExerciseProvider with ChangeNotifier {
  ExerciseLocalRepository? _localRepo;
  ExerciseCloudRepository _cloudRepo = ExerciseCloudRepository();
  SupabaseClient get _supabase => Supabase.instance.client;
  RealtimeChannel? _realtimeChannel;

  void setRepositories({ExerciseLocalRepository? local, ExerciseCloudRepository? cloud}) {
    if (local != null) _localRepo = local;
    if (cloud != null) _cloudRepo = cloud;
  }

  List<ExerciseTemplate> _templates = [];
  bool _isLoading = false;
  
  // ELITE CACHE BUSTER: Incremented on refresh to force image re-downloads
  int _imageVersion = DateTime.now().millisecondsSinceEpoch;

  List<ExerciseTemplate> get templates => _templates.map((t) => _applyCacheBuster(t)).toList();
  List<ExerciseTemplate> get defaultTemplates => templates.where((t) => t.isDefault).toList();
  List<ExerciseTemplate> get customTemplates => templates.where((t) => !t.isDefault).toList();
  bool get isLoading => _isLoading;

  ExerciseTemplate _applyCacheBuster(ExerciseTemplate t) {
    if (t.imageUrl == null || !t.imageUrl!.startsWith('http')) return t;
    final separator = t.imageUrl!.contains('?') ? '&' : '?';
    return t.copyWith(imageUrl: '${t.imageUrl}${separator}v=$_imageVersion');
  }

  void initializeForUser(String userId) {
    _localRepo = ExerciseLocalRepository(userId: userId);
    _loadData();
    _setupRealtimeSubscription(userId);
    ConnectivityService().addReconnectListener(_onReconnect);
  }

  void _onReconnect() async {
    if (!AuthProvider().isPro) return;
    debugPrint("ExerciseProvider: Reconnected. Triggering sync...");
    await _syncWithCloud();
  }

  void _setupRealtimeSubscription(String userId) {
    if (!AuthProvider().isPro) return;
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = _supabase.channel('public:exercise_sync:$userId');

    _realtimeChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'exercise_templates',
      callback: (payload) async {
        debugPrint("Realtime Exercise Template Update: ${payload.eventType}");
        
        final String? recordUserId = payload.newRecord['user_id'] ?? payload.oldRecord['user_id'];
        if (recordUserId != userId) return;

        if (payload.newRecord.isNotEmpty) {
          final template = ExerciseTemplate.fromMap(payload.newRecord);
          
          final localTemplates = await _localRepo!.getAllTemplates();
          final localIdx = localTemplates.indexWhere((t) => t.id == template.id);

          if (localIdx == -1 || localTemplates[localIdx].isSynced == 1) {
            await _localRepo!.insertTemplate(template);
            
            // Seamless update: remove old version if exists and add new one
            _templates.removeWhere((t) => t.id == template.id);
            _templates.add(template);
            _templates.sort((a, b) => a.name.compareTo(b.name));
            notifyListeners();
          }
        } else if (payload.eventType == PostgresChangeEvent.delete) {
          final String? id = payload.oldRecord['id'];
          if (id != null) {
            await _localRepo!.deleteTemplate(id);
            _templates.removeWhere((t) => t.id == id);
            notifyListeners();
          }
        }
      },
    );

    _realtimeChannel!.subscribe((status, [error]) async {
      debugPrint("ExerciseProvider: Realtime Subscription Status: $status");
      if (error != null) {
        debugPrint("ExerciseProvider: Realtime Subscription Error: $error");
      }
      if (status == RealtimeSubscribeStatus.subscribed) {
        debugPrint("ExerciseProvider: Realtime Subscribed/Reconnected. Syncing...");
        await _syncWithCloud();
      }
    });
  }

  Future<void> _loadData() async {
    if (_localRepo == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      _templates = await _localRepo!.getAllTemplates();
      
      await _runSelfHealingCheck();

      // Auto-initialize Rugged default library if missing or if legacy citations exist
      final defaultCount = _templates.where((t) => t.isDefault).length;
      
      final flyes = _templates.firstWhere(
        (t) => t.name == 'Dumbbell Flyes', 
        orElse: () => ExerciseTemplate(name: 'Empty')
      );
      final hasLegacyCitation = flyes.aboutTheMovement != null && flyes.aboutTheMovement!.contains('Mentzer');

      if (defaultCount != 42 || hasLegacyCitation) {
        debugPrint("ExerciseProvider: [UPDATE] Syncing Rugged library versions...");
        await _initializeDefaults();
        _templates = await _localRepo!.getAllTemplates();
      }
      
      notifyListeners();
      _syncWithCloud();
    } catch (e) {
      debugPrint("ExerciseProvider Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// ELITE SELF-HEALING: Detects and cleans legacy default exercise mappings
  Future<void> _runSelfHealingCheck() async {
    final needsHealing = _templates.any((t) => 
      t.isDefault && (
        t.aboutTheMovement != null && t.aboutTheMovement!.contains('Mentzer')
      )
    );

    if (needsHealing) {
      debugPrint("ExerciseProvider: [SELF-HEALING] Detected legacy Mentzer references. Restoring Rugged defaults...");
      await _initializeDefaults();
      _templates = await _localRepo!.getAllTemplates();
      notifyListeners();
    }
  }

  Future<void> _syncWithCloud() async {
    if (_localRepo == null) return;
    if (!AuthProvider().isPro) return;

    final syncProv = SyncProvider();
    syncProv.startFeatureSync();

    try {
      final count = await _localRepo!.getUnsyncedCount();
      syncProv.addTotalItems(count);

      // 0. Push Deletions
      final pendingDeletions = await _localRepo!.getPendingDeletions();
      for (var del in pendingDeletions) {
        final id = del['id'] as String;
        try {
          await _cloudRepo.deleteTemplate(id);
          await _localRepo!.removeFromDeletionQueue(id);
          syncProv.incrementCompleted();
        } catch (_) {}
      }

      // 1. PUSH unsynced local templates to Cloud (MANDATORY BEFORE PULL)
      final unsynced = await _localRepo!.getUnsyncedTemplates();
      for (var t in unsynced) {
        if (!t.isDefault) {
          try {
            final success = await _cloudRepo.insertTemplate(t);
            if (success) {
              await _localRepo!.markTemplateSynced(t.id);
              syncProv.incrementCompleted();
            }
          } catch (_) {}
        }
      }

      // 2. PULL from Cloud
      final cloudTemplates = await _cloudRepo.getAllTemplates();
      final localTemplates = await _localRepo!.getAllTemplates();
      final cloudIds = cloudTemplates.map((t) => t.id).toSet();

      // Deletion Reconciliation: Remove local synced templates missing from cloud
      for (var localT in localTemplates) {
        if (localT.isSynced == 1 && !localT.isDefault && !cloudIds.contains(localT.id)) {
          await _localRepo!.deleteTemplate(localT.id);
        }
      }
      
      // SYNC: Add or Update templates from the cloud
      for (var t in cloudTemplates) {
        // SAFETY: Never pull default templates from cloud
        if (!t.isDefault) {
          await _localRepo!.insertTemplate(t.copyWith(isSynced: 1), isFromCloud: true);
        }
      }

      // 3. Final memory refresh
      _templates = await _localRepo!.getAllTemplates();
      notifyListeners();
    } catch (e) {
      debugPrint("Exercise Cloud Sync Error: $e");
    } finally {
      syncProv.endFeatureSync();
    }
  }

  Future<void> _initializeDefaults() async {
    // Purge existing defaults to avoid duplicates and ensure content update
    if (_localRepo != null) {
      final db = await DatabaseHelper.instance.getDatabaseForUser(_localRepo!.userId);
      await db.delete('exercise_templates', where: 'is_default = 1');
    }

    final List<ExerciseTemplate> defaults = [
      _create('Dumbbell Flyes', 'Chest', ExerciseType.isolation, 2, 'Position dumbbells directly above your chest with a subtle bend in your elbows. Lower the weights outward in an arc until your chest muscles are comfortably stretched, keeping elbow angle fixed throughout. Contract your pectorals to return to the starting position without letting the weights touch at the top.'),
      _create('Incline Presses', 'Chest, Triceps', ExerciseType.compound, 3, 'Set an incline bench and grip the barbell slightly wider than shoulder-width. Lower the bar smoothly toward your upper chest, pointing elbows outward to maximize pectoral stretch. Drive the weight vertically until arms are fully extended.'),
      _create('Straight-Arm Lat Machine Pulldowns', 'Back', ExerciseType.isolation, 2, 'Stand in front of a high pulley with a shoulder-width grip. Keeping your arms extended with a slight bend in the elbows, pull the bar down toward your upper thighs using your lats. Pause briefly at the bottom before returning under control.'),
      _create('Palms-Up Pulldowns', 'Back, Biceps', ExerciseType.compound, 3, 'Grasp the lat bar with a shoulder-width underhand grip. Pull the bar down toward your upper chest while driving your elbows down and back. Pause at full contraction, then slowly extend your arms back to the top.'),
      _create('Deadlifts', 'Back, Legs, Calf, Abdominals, Shoulder, Triceps', ExerciseType.compound, 5, 'Stand with feet hip-width apart beneath the bar. Hinge at the hips and bend knees to grip the bar. Drive through your heels, keeping your back straight and chest lifted as you pull the bar up along your body to a standing position. Lower under complete control.'),
      _create('Leg Extensions', 'Legs', ExerciseType.isolation, 2, 'Sit securely on the leg extension machine with pads positioned above your ankles. Extend your legs upward until your knees are locked, squeezing your quadriceps at full extension. Hold for a brief pause before lowering under control.'),
      _create('Leg Presses', 'Legs, Calf', ExerciseType.compound, 4, 'Position your feet shoulder-width apart on the leg press platform. Lower the weight smoothly by bending your knees until your thighs form a 90-degree angle, ensuring your lower back stays firmly against the seat pad. Press through your heels back to the top.'),
      _create('Standing Calf Raises', 'Calf', ExerciseType.isolation, 2, 'Place the balls of your feet on the calf block with heels hanging off the edge. Raise your heels as high as possible by contracting your calves at full extension. Pause at the top, then lower your heels below the block level for a deep stretch.'),
      _create('Sit-Ups', 'Abdominals', ExerciseType.isolation, 2, 'Lie on your back with knees bent at a 45-degree angle. Contract your abdominal muscles to raise your upper torso toward your thighs, pausing at peak contraction before lowering slowly under control.'),
      _create('Dumbbell Lateral Raises', 'Shoulder', ExerciseType.isolation, 2, 'Stand holding dumbbells at your sides. With a slight bend in your elbows, raise your arms laterally to shoulder height. Hold briefly at the top before lowering under control.'),
      _create('Bent-Over Dumbbell Laterals', 'Shoulder', ExerciseType.isolation, 2, 'Hinge forward at the hips until your torso is nearly parallel to the floor. Raise the dumbbells outward and upward until your upper arms are aligned with your shoulders, targeting the rear deltoids. Lower slowly.'),
      _create('Triceps Pressdowns', 'Triceps', ExerciseType.isolation, 2, 'Grasp the cable bar attachment with an overhand grip, keeping your elbows tucked against your torso. Extend your arms downward until your elbows are fully locked out. Hold for a moment before letting the bar return slowly to chest height.'),
      _create('Dips', 'Shoulder, Triceps, Chest', ExerciseType.compound, 4, 'Support your body weight on parallel dipping bars with arms extended. Lower your body smoothly until your upper arms are parallel to the floor, then push back up to the top position using your triceps and chest.'),
      _create('Cable Crossovers', 'Chest', ExerciseType.isolation, 2, 'Stand between high pulley cables, gripping a handle in each hand. Draw your arms down and across the front of your chest in a sweeping motion until your hands cross. Squeeze your pectorals at peak contraction before returning under control.'),
      _create('Pec Deck', 'Chest', ExerciseType.isolation, 2, 'Sit against the back pad with your forearms resting against the movement arms. Press the pads inward using your chest muscles until they meet in front of you. Pause briefly at the center before returning smoothly to the start.'),
      _create('Bench Press', 'Chest, Triceps', ExerciseType.compound, 4, 'Lie on a flat bench and grip the barbell shoulder-width apart. Lower the bar strictly to your mid-chest level, then press the weight straight up until arms are fully extended.'),
      _create('Dumbbell Pullovers', 'Back', ExerciseType.isolation, 2, 'Lie back on a flat bench holding a single dumbbell overhead with both hands. Lower the dumbbell behind your head in an arc while keeping arms straight, stretching your lats, then pull back up over your chest.'),
      _create('Nautilus Machine Pullovers', 'Back', ExerciseType.isolation, 2, 'Sit in the pullover machine with upper arms positioned against the movement pads. Drive your elbows down toward your hips to contract your lats. Hold peak contraction for a second before slowly letting arms return overhead.'),
      _create('Barbell Rows', 'Back', ExerciseType.isolation, 2, 'Hinge forward at the waist with your back flat and knees slightly bent. Pull the barbell up toward your lower ribcage, squeezing your shoulder blades together at the top before lowering under control.'),
      _create('One-Arm Dumbbell Rows', 'Back', ExerciseType.isolation, 2, 'Support one hand and knee on a flat bench while holding a dumbbell in the other hand. Pull the dumbbell upward toward your hip, keeping your elbow close to your side. Pause at the top and lower smoothly.'),
      _create('Rowing Machines', 'Back', ExerciseType.isolation, 2, 'Sit upright on the machine seat with chest against the support pad. Pull the handles toward your midsection, squeezing your back muscles at full contraction before extending back out.'),
      _create('Chin-Ups', 'Back, Biceps', ExerciseType.compound, 4, 'Grasp a pull-up bar with an underhand grip shoulder-width apart. Pull your body upward until your chin clears the bar, focusing on driving your elbows down. Lower yourself slowly to full extension.'),
      _create('Shrugs', 'Back', ExerciseType.isolation, 2, 'Hold a heavy barbell or dumbbells at arms length. Elevate your shoulders straight up toward your ears as high as possible without bending your elbows. Squeeze your upper traps at the top before lowering under control.'),
      _create('Leg Curls', 'Legs', ExerciseType.isolation, 2, 'Lie face down on the leg curl machine with the pad positioned above your heels. Curl your legs upward toward your glutes, squeezing your hamstrings at full contraction before lowering slowly.'),
      _create('Squats', 'Legs, Abdominals, Calf', ExerciseType.compound, 5, 'Position the barbell across your upper back. Squat down by flexing hips and knees until your thighs are parallel to the ground, keeping your chest upright and knees aligned. Press back up through your heels.'),
      _create('Toe Presses', 'Calf', ExerciseType.isolation, 2, 'Position the balls of your feet on the leg press platform with knees straight. Press the platform forward using your ankles to fully contract your calves, pause, then allow heels to stretch back under control.'),
      _create('Donkey Calf Raises', 'Calf', ExerciseType.isolation, 2, 'Hinge forward at the waist with forearms supported on a bench and balls of feet on a raised block. Elevate your heels as high as possible to contract your calves, hold peak position, and lower smoothly.'),
      _create('Hanging Leg Raises', 'Abdominals', ExerciseType.isolation, 2, 'Hang from a chin-up bar with arms fully extended. Raise your legs forward and upward until they are parallel to the floor, using your abdominal muscles to control the movement without swinging.'),
      _create('Nautilus Lateral Raises', 'Shoulder', ExerciseType.isolation, 2, 'Sit in the machine with arms resting against the side movement pads. Raise your elbows outward until they reach shoulder level, hold peak contraction, and lower slowly under control.'),
      _create('Bent-Over Cable Laterals', 'Shoulder', ExerciseType.isolation, 2, 'Stand between low pulleys, crossing handles across your body. Hinge forward at the waist and pull the cables upward and outward until your arms align with your shoulders, targeting the rear delts.'),
      _create('Upright Rows', 'Biceps, Back, Shoulder', ExerciseType.compound, 4, 'Grasp a barbell with a narrow to shoulder-width grip. Lift the bar straight up along your torso until elbows reach shoulder height, pause, and lower under complete control.'),
      _create('Press Behind Neck', 'Shoulder, Triceps', ExerciseType.compound, 4, 'Sit upright with a barbell supported across your upper traps behind your neck. Press the weight straight overhead until arms are extended, then lower under control back to the neck.'),
      _create('Machine Presses', 'Shoulder, Triceps', ExerciseType.compound, 4, 'Sit securely in the shoulder press machine and grip the handles. Press the handles overhead until your arms are extended, pausing at full overhead position before lowering to shoulder height.'),
      _create('Standing Barbell Curls', 'Biceps', ExerciseType.isolation, 2, 'Stand upright holding a barbell with an underhand grip. Curl the bar toward your chest while keeping your elbows stationary at your sides. Squeeze your biceps at peak contraction and lower under control.'),
      _create('Preacher Curls', 'Biceps', ExerciseType.isolation, 2, 'Rest your upper arms firmly on the preacher bench pad. Lower the barbell until your arms are fully extended, then curl the weight smoothly toward your shoulders without moving your elbows.'),
      _create('Concentration Curls', 'Biceps', ExerciseType.isolation, 2, 'Sit on a bench, resting your elbow against the inside of your inner thigh. Curl the dumbbell toward your chest, focusing strictly on biceps contraction, then lower under control.'),
      _create('Nautilus Machine Curls', 'Biceps', ExerciseType.isolation, 2, 'Sit in the machine with elbows resting on the pad. Curl the movement arms toward your shoulders, holding peak contraction at the top before lowering under control.'),
      _create('Lying Triceps Extensions', 'Triceps', ExerciseType.isolation, 2, 'Lie back on a flat bench holding an EZ bar overhead. Bend your elbows to lower the weight toward your forehead, keeping your upper arms stationary, then extend your forearms back to lockout.'),
      _create('Nautilus Triceps Extensions', 'Triceps', ExerciseType.isolation, 2, 'Sit in the machine with elbows supported on the pads. Extend your arms forward until fully locked out, squeezing your triceps before returning smoothly.'),
      _create('French Presses', 'Triceps', ExerciseType.isolation, 2, 'Hold a dumbbell overhead with both hands behind your head. Lower the dumbbell behind your neck by bending at the elbows, then extend back up overhead.'),
      _create('Close-Grip Bench Presses', 'Chest, Triceps', ExerciseType.compound, 4, 'Lie on a flat bench with a narrow hand placement on the barbell. Lower the bar to mid-chest while keeping elbows close to your torso, then press straight up to lockout using your triceps.'),
    ];

    for (var t in defaults) {
      await _localRepo!.insertTemplate(t);
    }
  }

  ExerciseTemplate _create(String name, String muscles, ExerciseType type, int intensity, [String? about]) {
    final String fileName = name.toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll('-', '_')
        .replaceAll('(', '')
        .replaceAll(')', '');
    
    final String fixedId = 'rugged_$fileName';

    return ExerciseTemplate(
      id: fixedId,
      name: name,
      targetMuscles: muscles,
      type: type,
      intensity: intensity,
      isDefault: true,
      aboutTheMovement: about,
      imageUrl: null, // No photo/image asset for default exercises
    );
  }

  Future<void> addTemplate(ExerciseTemplate template) async {
    if (_localRepo == null) return;
    
    // Add or Update in local list first for instant UI feedback
    final localTemplate = template.copyWith(
      name: template.name.trim().toUpperCase(),
      isSynced: 0
    );
    
    // Seamless update: remove old version if exists and add new one
    _templates.removeWhere((t) => t.id == localTemplate.id);
    _templates.add(localTemplate);
    _templates.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();

    try {
      await _localRepo!.insertTemplate(localTemplate);
      // Only sync to cloud if it is a custom exercise
      if (!localTemplate.isDefault) {
        await _syncTemplate(localTemplate);
      }
    } catch (e) {
      debugPrint("ExerciseProvider: Error adding template locally: $e");
    }
  }

  Future<void> _syncTemplate(ExerciseTemplate template) async {
    if (!AuthProvider().isPro) return;
    try {
      final success = await _cloudRepo.insertTemplate(template);
      if (success) {
        await _localRepo!.markTemplateSynced(template.id);
        
        // Update the sync status in memory without triggering a full re-sort if possible
        final idx = _templates.indexWhere((t) => t.id == template.id);
        if (idx != -1) {
          _templates[idx] = template.copyWith(isSynced: 1);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Background Sync Error (Exercise Template Add): $e");
    }
  }

  Future<void> deleteTemplate(String id) async {
    if (_localRepo == null) return;
    _templates.removeWhere((t) => t.id == id);
    notifyListeners();
    try {
      await _localRepo!.deleteTemplate(id);
      await _localRepo!.addToDeletionQueue(id);
      _syncTemplateDelete(id);
    } catch (e) {
      debugPrint("ExerciseProvider: Error deleting template locally: $e");
    }
  }

  Future<void> _syncTemplateDelete(String id) async {
    try {
      await _cloudRepo.deleteTemplate(id);
      await _localRepo!.removeFromDeletionQueue(id);
    } catch (e) {
      debugPrint("Background Sync Error (Exercise Template Delete): $e");
    }
  }

  Future<void> forceResetDefaults() async {
    if (_localRepo == null) return;
    _isLoading = true;
    notifyListeners();
    
    try {
      // 1. Delete all existing default templates
      final existing = await _localRepo!.getAllTemplates();
      for (var t in existing.where((t) => t.isDefault)) {
        await _localRepo!.deleteTemplate(t.id);
        // We don't delete from cloud to avoid affecting other devices, 
        // unless you want a total reset.
      }
      
      // 2. Re-initialize
      await _initializeDefaults();
      
      // 3. Re-load
      _templates = await _localRepo!.getAllTemplates();
      debugPrint("ExerciseProvider: Force reset complete. Loaded ${_templates.length} templates.");
    } catch (e) {
      debugPrint("ExerciseProvider: Force Reset Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> forceRefresh() async {
    if (_localRepo == null) return;
    _isLoading = true;
    notifyListeners();
    
    try {
      debugPrint("ExerciseProvider: FORCE REFRESH TRIGGERED");
      
      // Update Cache Buster to force re-download of all images
      _imageVersion = DateTime.now().millisecondsSinceEpoch;
      debugPrint("ExerciseProvider: Cache Buster updated to v=$_imageVersion");

      // 1. Run self-healing to fix any broken default URLs
      await _runSelfHealingCheck();
      
      // 2. Sync any local changes first
      await _syncWithCloud();
      
      // 3. Perform a fresh load from local
      _templates = await _localRepo!.getAllTemplates();
      debugPrint("ExerciseProvider: Force Refresh Complete.");
    } catch (e) {
      debugPrint("ExerciseProvider: Force Refresh Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Sharing Methods ---

  Future<String?> generateShareableLink(ExerciseTemplate template, String userName) async {
    if (!AuthProvider().isPro) {
      debugPrint("ExerciseProvider: Sharing skipped - Pro status required.");
      return null;
    }

    final Map<String, dynamic> shareData = {
      'type': 'exercise',
      'name': template.name,
      'target_muscles': template.targetMuscles,
      'intensity': template.intensity,
      'exercise_type': template.type.name,
      'about': template.aboutTheMovement,
      'image_url': template.imageUrl,
      'sender': userName,
    };

    try {
      final response = await _supabase.from('shared_data').insert({
        'data': shareData,
      }).select('id').single();

      final shareId = response['id'] as String;
      return "https://affulabs.com/rugged/app/share/exercise?id=$shareId&from=${Uri.encodeComponent(userName)}";
    } catch (e) {
      debugPrint("ExerciseProvider: Error generating share link: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchSharedExercise(String shareId) async {
    try {
      final response = await _supabase.from('shared_data').select().eq('id', shareId).single();
      final createdAt = DateTime.parse(response['created_at']);
      if (DateTime.now().difference(createdAt).inDays >= 7) return {'expired': true};
      return response['data'] as Map<String, dynamic>;
    } catch (e) {
      debugPrint("ExerciseProvider: Error fetching shared exercise: $e");
      return null;
    }
  }

  Future<void> importSharedExercise(Map<String, dynamic> data) async {
    final template = ExerciseTemplate(
      id: const Uuid().v4(),
      name: (data['name'] as String).toUpperCase(),
      targetMuscles: data['target_muscles'],
      intensity: data['intensity'] as int? ?? 3,
      type: ExerciseType.values.firstWhere(
        (e) => e.name == data['exercise_type'],
        orElse: () => ExerciseType.isolation,
      ),
      aboutTheMovement: data['about'],
      imageUrl: data['image_url'],
      sharedBy: data['sender'] as String?,
      isSynced: 0,
    );

    await addTemplate(template);
  }

  void clearUserData() {
    ConnectivityService().removeReconnectListener(_onReconnect);
    _realtimeChannel?.unsubscribe();
    _templates.clear();
    _localRepo = null;
    notifyListeners();
  }
}
