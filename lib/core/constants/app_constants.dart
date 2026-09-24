// lib/core/constants/app_constants.dart

class AppConstants {
  // Private constructor to prevent instantiation
  AppConstants._();

  // Supabase Configuration Keys
  static const String supabaseUrl = 'https://fmudyebwpvpgqbnrjtpi.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZtdWR5ZWJ3cHZwZ3FibnJqdHBpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkzNzkwMzEsImV4cCI6MjA5NDk1NTAzMX0.M7ei86dMS28jSQVJzPZmb1pHACHvtyRM3axRmXE6Ioo';
  
  // You can also add other global constants here later, like API timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
}
