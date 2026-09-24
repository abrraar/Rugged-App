# Rugged App: In-App Paywall & Subscription Implementation Checklist

This checklist tracks all code-level changes required to implement multi-tier subscriptions (1M, 3M, 6M, 1Y), regional pricing loading, cloud sync gating, and feature paywalls within the Flutter application codebase.

---

## 1. In-App Purchase Provider (`lib/core/providers/iap_provider.dart`)
- [x] Update Product IDs to match new subscription tiers:
  - `rugged_pro_1m` (Monthly)
  - `rugged_pro_3m` (3-Month)
  - `rugged_pro_6m` (6-Month)
  - `rugged_pro_1y` (Annual)
- [x] Update `_loadProducts()` to query all 4 subscription product details simultaneously from Google Play / App Store.
- [x] Implement subscription purchase handler (`buySubscription(ProductDetails product)`).
- [x] Implement `restorePurchases()` verification logic with `AuthProvider` to update Supabase profile status.
- [x] Store `proExpiresAt` timestamp locally and in Supabase to track subscription validity.

---

## 2. Paywall UI Screen (`lib/features/pro/pro_upgrade_screen.dart`)
- [x] Redesign paywall modal sheet to dynamically display 4 subscription tier cards:
  - **1-Month Plan**: Base price
  - **3-Month Plan**: Effective rate + **"SAVE 17%"** badge
  - **6-Month Plan**: Effective rate + **"SAVE 25%"** badge
  - **1-Year Plan**: Effective rate + **"SAVE 51% - BEST VALUE"** badge
- [x] Bind price text to localized currency strings fetched automatically via `IAPProvider`.
- [x] Add Pro feature list checklist (Cloud Auto-Backup, Multi-Device Sync, Ad-Free Experience, Web Share Links, Advanced Analytics).
- [x] Connect subscription selection buttons to trigger Google Play / Apple checkout flow.

---

## 3. Cloud Sync Gating (Repositories & Providers)
*Gate Supabase Cloud writes & Realtime channels behind `authProvider.isPro` while keeping local SQLite 100% active for free users:*

- [x] **Workout & Exercises**:
  - `lib/features/exercise/data/exercise_cloud_repository.dart`
  - `lib/features/exercise/provider/exercise_provider.dart` *(Realtime channel `public:exercise_sync`)*
- [x] **Body Composition**:
  - `lib/features/tracker/body_composition/data/body_comp_cloud_repository.dart`
  - `lib/features/tracker/body_composition/provider/body_comp_provider.dart`
- [x] **Calorie & Nutrition**:
  - `lib/features/tracker/calorie/provider/calorie_provider.dart`
- [x] **Cycle Tracker**:
  - `lib/features/tracker/cycle_tracker/provider/cycle_provider.dart`
- [x] **Supplements & Stacks**:
  - `lib/features/tracker/supplement/provider/supplement_provider.dart`
- [x] **Affirmations**:
  - `lib/features/affirmation/data/affirmation_cloud_repository.dart`
  - `lib/features/affirmation/provider/affirmation_provider.dart` *(Realtime channel `public:affirmations_sync`)*
- [x] **UI Settings**:
  - `lib/core/data/ui_cloud_repository.dart`

---

## 4. Web Share Link Paywall Interceptor
- [x] Intercept "Share Link" action in `exercise_provider.dart` for non-Pro users and pop `ProUpgradeScreen`.
- [x] Intercept "Share Link" action in `calorie_provider.dart` for non-Pro users.
- [x] Intercept "Share Link" action in `cycle_provider.dart` for non-Pro users.
- [x] Intercept "Share Link" action in `supplement_provider.dart` for non-Pro users.

---

## 5. Advanced Analytics & Charting Paywall
- [x] Update `lib/core/ads/locked_analytics_overlay.dart` to trigger `ProUpgradeScreen` paywall.

---

## 6. Settings & Navigation Entries
- [x] Update `lib/features/settings/settings_screen.dart` banner to show active subscription status or "UPGRADE TO RUGGED PRO".
