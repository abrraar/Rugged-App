// lib/core/database/database_helper.dart

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  
  DatabaseHelper._init();

  Future<Database> getDatabaseForUser(String userId) async {
    final dbName = 'user_${userId}_tracker_v1.db';
    return await _initDB(dbName);
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onConfigure: _onConfigure,
      onOpen: (db) async {
        try { await db.execute('ALTER TABLE profiles ADD COLUMN pro_plan_tier TEXT;'); } catch (_) {}
        try { await db.execute('ALTER TABLE profiles ADD COLUMN pro_start_date TEXT;'); } catch (_) {}
        try { await db.execute('ALTER TABLE profiles ADD COLUMN pro_expiry_date TEXT;'); } catch (_) {}
      },
    );
  }

  /// ELITE PURGE SYSTEM: Deletes the entire database file for a specific user.
  Future<void> deleteUserDatabase(String userId) async {
    final dbName = 'user_${userId}_tracker_v1.db';
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, dbName);
    
    if (await databaseExists(path)) {
      debugPrint("DatabaseHelper: PERMANENTLY ERASING DATABASE AT $path");
      await deleteDatabase(path);
    }
  }

  Future _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future _createDB(Database db, int version) async {
    // 1. Supplement Library Table (ss_supplements)
    await db.execute('''
      CREATE TABLE ss_supplements (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        name TEXT NOT NULL,
        description TEXT,
        serving_unit TEXT,
        weight_per_serving REAL,
        weight_unit TEXT,
        total_stock REAL,
        remaining_stock REAL,
        is_active INTEGER DEFAULT 1,
        notifications_enabled INTEGER DEFAULT 0,
        expiry_date TEXT,
        calories_per_unit REAL,
        protein_per_unit REAL DEFAULT 0.0,
        carbs_per_unit REAL DEFAULT 0.0,
        fats_per_unit REAL DEFAULT 0.0,
        shared_by TEXT,
        is_pinned_to_home INTEGER DEFAULT 0,
        pinned_intake_amount REAL DEFAULT 1.0,
        pinned_use_servings_intake INTEGER DEFAULT 1,
        pinned_restock_amount REAL DEFAULT 0.0,
        pinned_use_servings_restock INTEGER DEFAULT 1,
        reminders_json TEXT,
        ingredients_json TEXT,
        is_synced INTEGER DEFAULT 1,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 2. Stacks Table (ss_stack)
    await db.execute('''
      CREATE TABLE ss_stack (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        name TEXT NOT NULL,
        is_pinned INTEGER DEFAULT 0,
        is_pinned_to_home INTEGER DEFAULT 0,
        notifications_enabled INTEGER DEFAULT 0,
        reminders_json TEXT,
        shared_by TEXT,
        pinned_record_modes_json TEXT,
        pinned_use_servings_json TEXT,
        pinned_amounts_json TEXT,
        supplement_ids_json TEXT, 
        is_synced INTEGER DEFAULT 1,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 3. History Table (ss_records)
    await db.execute('''
      CREATE TABLE ss_records (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        supplement_id TEXT NOT NULL,
        supplement_name TEXT NOT NULL,
        type TEXT NOT NULL,
        details TEXT NOT NULL,
        weight_adjustment REAL NOT NULL,
        timestamp TEXT NOT NULL,
        source_id TEXT,
        is_synced INTEGER DEFAULT 0,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 4. Hydration Logs Table
    await db.execute('''
      CREATE TABLE hydration_logs (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        amount_ml INTEGER NOT NULL,
        amount_oz REAL NOT NULL,
        timestamp TEXT NOT NULL,
        is_synced INTEGER DEFAULT 1,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 5. Hydration Settings Table
    await db.execute('''
      CREATE TABLE hydration_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        user_id TEXT,
        daily_goal INTEGER DEFAULT 3500,
        unit TEXT DEFAULT 'ml',
        add_value INTEGER DEFAULT 250,
        minus_value INTEGER DEFAULT 250,
        reminders_enabled INTEGER DEFAULT 0,
        is_pinned_to_home INTEGER DEFAULT 1,
        reminders_json TEXT,
        is_synced INTEGER DEFAULT 1,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 6. Sleep Logs Table
    await db.execute('''
      CREATE TABLE sleep_logs (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        bedtime TEXT NOT NULL,
        wake_up_time TEXT NOT NULL,
        quality INTEGER NOT NULL,
        type TEXT NOT NULL,
        note TEXT,
        is_synced INTEGER DEFAULT 1,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 7. Sleep Alarm Settings Table
    await db.execute('''
      CREATE TABLE sleep_alarm_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        user_id TEXT,
        bedtime_enabled INTEGER DEFAULT 0,
        bedtime_hour INTEGER DEFAULT 22,
        bedtime_minute INTEGER DEFAULT 30,
        bedtime_audio_path TEXT,
        wake_up_enabled INTEGER DEFAULT 0,
        wake_up_hour INTEGER DEFAULT 6,
        wake_up_minute INTEGER DEFAULT 45,
        wake_up_audio_path TEXT,
        is_synced INTEGER DEFAULT 1,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 8. Calorie Logs Table (calorie_meal_logs)
    await db.execute('''
      CREATE TABLE calorie_meal_logs (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        meal_name TEXT NOT NULL,
        food_items TEXT NOT NULL,
        calories REAL NOT NULL,
        protein REAL DEFAULT 0.0,
        carbs REAL DEFAULT 0.0,
        fats REAL DEFAULT 0.0,
        timestamp TEXT NOT NULL,
        added_supplements_json TEXT,
        added_stacks_json TEXT,
        servings REAL DEFAULT 1.0,
        is_synced INTEGER DEFAULT 1,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 9. Calorie Settings Table
    await db.execute('''
      CREATE TABLE calorie_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        user_id TEXT,
        daily_calorie_goal INTEGER DEFAULT 2500,
        protein_percent INTEGER DEFAULT 25,
        carb_percent INTEGER DEFAULT 60,
        fat_percent INTEGER DEFAULT 15,
        track_macros BOOLEAN DEFAULT TRUE,
        show_remaining BOOLEAN DEFAULT TRUE,
        visible_metrics_json TEXT,
        is_synced INTEGER DEFAULT 1,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 10. Saved Meals Table (calorie_meals)
    await db.execute('''
      CREATE TABLE calorie_meals (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        name TEXT NOT NULL,
        food_items TEXT NOT NULL,
        calories REAL NOT NULL,
        protein REAL DEFAULT 0.0,
        carbs REAL DEFAULT 0.0,
        fats REAL DEFAULT 0.0,
        is_pinned_to_home INTEGER DEFAULT 0,
        notifications_enabled INTEGER DEFAULT 0,
        reminders_json TEXT,
        added_supplements_json TEXT,
        added_stacks_json TEXT,
        servings REAL DEFAULT 1.0,
        multiply_supps INTEGER DEFAULT 1,
        shared_by TEXT,
        is_synced INTEGER DEFAULT 1,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 11. Body Composition Tables
    await db.execute('''
      CREATE TABLE body_comp_weight_logs (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        value_kg REAL NOT NULL,
        value_lbs REAL NOT NULL,
        timestamp TEXT NOT NULL,
        unit TEXT DEFAULT 'kg',
        is_synced INTEGER DEFAULT 1,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    await db.execute('''
      CREATE TABLE body_comp_fats_logs (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        value_kg REAL NOT NULL,
        value_lbs REAL NOT NULL,
        timestamp TEXT NOT NULL,
        unit TEXT DEFAULT 'percentage',
        is_synced INTEGER DEFAULT 1,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    await db.execute('''
      CREATE TABLE body_comp_muscle_logs (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        value_kg REAL NOT NULL,
        value_lbs REAL NOT NULL,
        timestamp TEXT NOT NULL,
        unit TEXT DEFAULT 'kg',
        is_synced INTEGER DEFAULT 1,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 12. Training Cycles Table (hit_cycles)
    await db.execute('''
      CREATE TABLE hit_cycles (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        name TEXT NOT NULL,
        description TEXT,
        is_default INTEGER DEFAULT 0,
        status TEXT NOT NULL,
        started_at TEXT,
        completed_at TEXT,
        note TEXT,
        shared_by TEXT,
        is_synced INTEGER DEFAULT 1,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 13. Workouts Table (hit_workouts)
    await db.execute('''
      CREATE TABLE hit_workouts (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        cycle_id TEXT NOT NULL,
        name TEXT NOT NULL,
        workout_order INTEGER NOT NULL,
        status TEXT NOT NULL,
        completed_at TEXT,
        note TEXT,
        is_synced INTEGER DEFAULT 1,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (cycle_id) REFERENCES hit_cycles (id) ON DELETE CASCADE
      )
    ''');

    // 14. Exercises Table (hit_exercises)
    await db.execute('''
      CREATE TABLE hit_exercises (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        workout_id TEXT NOT NULL,
        name TEXT NOT NULL,
        exercise_order INTEGER NOT NULL,
        target_muscles TEXT,
        is_synced INTEGER DEFAULT 1,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (workout_id) REFERENCES hit_workouts (id) ON DELETE CASCADE
      )
    ''');

    // 15. Exercise Logs Table
    await db.execute('''
      CREATE TABLE exercise_logs (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        exercise_id TEXT NOT NULL,
        weight_kg REAL NOT NULL,
        weight_lbs REAL NOT NULL,
        positive_reps INTEGER NOT NULL,
        static_hold_seconds INTEGER DEFAULT 0,
        negative_reps INTEGER DEFAULT 0,
        forced_reps INTEGER DEFAULT 0,
        comment TEXT,
        timestamp TEXT NOT NULL,
        is_synced INTEGER DEFAULT 1,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 16. Exercise Templates Table
    await db.execute('''
      CREATE TABLE exercise_templates (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        name TEXT NOT NULL,
        target_muscles TEXT,
        intensity INTEGER DEFAULT 3,
        is_default INTEGER DEFAULT 0,
        type TEXT DEFAULT 'isolation',
        about_the_movement TEXT,
        image_url TEXT,
        shared_by TEXT,
        is_synced INTEGER DEFAULT 1,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 17. Cycle Settings Table (hit_settings)
    await db.execute('''
      CREATE TABLE hit_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        user_id TEXT,
        weight_unit TEXT DEFAULT 'lbs',
        visible_metrics_json TEXT,
        workout_reminders_enabled INTEGER DEFAULT 0,
        workout_reminder_interval INTEGER DEFAULT 2,
        smart_auto_date_enabled INTEGER DEFAULT 1,
        is_synced INTEGER DEFAULT 1,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 18. Sync Deletions Queue Table
    await db.execute('''
      CREATE TABLE pending_deletions (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        table_name TEXT NOT NULL,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 19. UI Settings Table (home_widget_settings)
    await db.execute('''
      CREATE TABLE home_widget_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        user_id TEXT,
        home_layout_json TEXT,
        is_synced INTEGER DEFAULT 1,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 20. Affirmations Table
    await db.execute('''
      CREATE TABLE affirmations (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        text TEXT NOT NULL,
        speaker TEXT,
        shared_by TEXT,
        display_order INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        is_synced INTEGER DEFAULT 1
      )
    ''');

    // 21. Affirmation Settings Table
    await db.execute('''
      CREATE TABLE affirmation_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        user_id TEXT,
        rotation_minutes INTEGER DEFAULT 60,
        rotation_mode TEXT DEFAULT 'random',
        order_direction TEXT DEFAULT 'asc',
        custom_order_json TEXT,
        is_synced INTEGER DEFAULT 1,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 22. User Emails Table
    await db.execute('''
      CREATE TABLE user_emails (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        email TEXT NOT NULL,
        is_verified INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 1,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 23. User Profile Table (Local Mirror of Supabase Profiles)
    await db.execute('''
      CREATE TABLE profiles (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        full_name TEXT,
        username TEXT UNIQUE,
        birthday TEXT,
        gender TEXT,
        height REAL,
        weight REAL,
        is_pro INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 1,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 24. Body Composition Settings Table
    await db.execute('''
      CREATE TABLE body_comp_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        user_id TEXT,
        weight_unit TEXT DEFAULT 'kgs',
        height_unit TEXT DEFAULT 'cm',
        weight_reminders_enabled INTEGER DEFAULT 0,
        weight_reminders_json TEXT,
        fat_reminders_enabled INTEGER DEFAULT 0,
        fat_reminders_json TEXT,
        muscle_reminders_enabled INTEGER DEFAULT 0,
        muscle_reminders_json TEXT,
        visible_metrics_json TEXT,
        is_synced INTEGER DEFAULT 1,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 25. Sleep Settings Table
    await db.execute('''
      CREATE TABLE sleep_settings (
        user_id TEXT PRIMARY KEY,
        use_24h_clock INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 1,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 26. Supplement Settings Table
    await db.execute('''
      CREATE TABLE ss_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        user_id TEXT,
        show_expired INTEGER DEFAULT 1,
        hide_empty_stock INTEGER DEFAULT 0,
        pinned_order_json TEXT,
        is_synced INTEGER DEFAULT 1,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

}
