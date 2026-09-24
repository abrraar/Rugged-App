import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../features/auth/provider/auth_provider.dart';

/// ELITE IAP PROVIDER
/// 
/// Manages the full lifecycle of Google Play & Apple App Store Billing transactions.
class IAPProvider with ChangeNotifier {
  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  // SUBSCRIPTION PRODUCT IDs
  static const String pro1mId = 'rugged_pro_1m';
  static const String pro3mId = 'rugged_pro_3m';
  static const String pro6mId = 'rugged_pro_6m';
  static const String pro1yId = 'rugged_pro_1y';

  static const Set<String> _productIds = {
    pro1mId,
    pro3mId,
    pro6mId,
    pro1yId,
  };

  Map<String, ProductDetails> _products = {};
  bool _isAvailable = false;
  bool _isLoading = true;
  String? _error;

  Map<String, ProductDetails> get products => _products;
  ProductDetails? get pro1m => _products[pro1mId];
  ProductDetails? get pro3m => _products[pro3mId];
  ProductDetails? get pro6m => _products[pro6mId];
  ProductDetails? get pro1y => _products[pro1yId];

  bool get isAvailable => _isAvailable;
  bool get isLoading => _isLoading;
  String? get error => _error;

  IAPProvider() {
    final purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription.cancel(),
      onError: (err) => debugPrint("IAPProvider: Error in stream: $err"),
    );
    _initialize();
  }

  Future<void> _initialize() async {
    _isAvailable = await _iap.isAvailable();
    if (_isAvailable) {
      await _loadProducts();
    } else {
      _isLoading = false;
      _error = "GOOGLE PLAY BILLING UNAVAILABLE";
      notifyListeners();
    }
  }

  Future<void> _loadProducts() async {
    try {
      final response = await _iap.queryProductDetails(_productIds);

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint("IAPProvider: Product IDs NOT FOUND in Console: ${response.notFoundIDs}");
      }

      if (response.productDetails.isNotEmpty) {
        _products = {
          for (var details in response.productDetails) details.id: details
        };
        for (var p in response.productDetails) {
          debugPrint("IAPProvider: Loaded Product: ${p.id} - ${p.title} - ${p.price}");
        }
      }
    } catch (e) {
      debugPrint("IAPProvider: Error loading products: $e");
    }
    
    _isLoading = false;
    notifyListeners();
  }

  /// Triggers checkout sheet for selected subscription
  Future<void> buySubscription(ProductDetails product) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  /// Triggers default / 1-year purchase
  Future<void> buyPro() async {
    final target = pro1y ?? pro1m;
    if (target != null) {
      await buySubscription(target);
    }
  }

  /// Restores previous purchases
  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (var purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
        _verifyAndEnable(purchase);
      } else if (purchase.status == PurchaseStatus.error) {
        debugPrint("IAPProvider: Purchase Error: ${purchase.error}");
        _error = purchase.error?.message;
        notifyListeners();
      }

      if (purchase.pendingCompletePurchase) {
        _iap.completePurchase(purchase);
      }
    }
  }

  void _verifyAndEnable(PurchaseDetails purchase) async {
    try {
      final authProv = AuthProvider();
      String tier = '1-Year Pro Pass';
      int days = 365;

      if (purchase.productID == pro1mId) {
        tier = '1-Month Pro Pass';
        days = 30;
      } else if (purchase.productID == pro3mId) {
        tier = '3-Month Pro Pass';
        days = 90;
      } else if (purchase.productID == pro6mId) {
        tier = '6-Month Pro Pass';
        days = 180;
      } else if (purchase.productID == pro1yId) {
        tier = '1-Year Pro Pass';
        days = 365;
      }

      await authProv.enableProAccess(tier: tier, durationDays: days);
      debugPrint("IAPProvider: SUCCESS. Pro access granted ($tier) via Google Play / Store.");
    } catch (e) {
      debugPrint("IAPProvider: Failed to update user profile after purchase: $e");
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

