import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class SubscriptionState {
  final bool isPremium;
  final CustomerInfo? customerInfo;
  final bool isLoading;

  const SubscriptionState({
    this.isPremium = false,
    this.customerInfo,
    this.isLoading = false,
  });
}

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  SubscriptionNotifier() : super(const SubscriptionState()) {
    _init();
  }

  static const _entitlementId = 'ad_free';

  Future<void> _init() async {
    try {
      await Purchases.configure(
        PurchasesConfiguration('YOUR_REVENUECAT_KEY')
          ..appUserID = null,
      );
      await refresh();
    } catch (_) {}
  }

  Future<void> refresh() async {
    try {
      final info = await Purchases.getCustomerInfo();
      final premium = info.entitlements.active.containsKey(_entitlementId);
      state = SubscriptionState(isPremium: premium, customerInfo: info);
    } catch (_) {}
  }

  Future<bool> purchaseYearly() async {
    state = SubscriptionState(isPremium: state.isPremium, isLoading: true);
    try {
      final offerings = await Purchases.getOfferings();
      final package = offerings.current?.annual;
      if (package == null) {
        state = SubscriptionState(isPremium: state.isPremium);
        return false;
      }
      final info = await Purchases.purchasePackage(package);
      final premium = info.customerInfo.entitlements.active.containsKey(_entitlementId);
      state = SubscriptionState(isPremium: premium, customerInfo: info.customerInfo);
      return premium;
    } catch (_) {
      state = SubscriptionState(isPremium: state.isPremium);
      return false;
    }
  }

  Future<void> restore() async {
    state = SubscriptionState(isPremium: state.isPremium, isLoading: true);
    try {
      final info = await Purchases.restorePurchases();
      final premium = info.entitlements.active.containsKey(_entitlementId);
      state = SubscriptionState(isPremium: premium, customerInfo: info);
    } catch (_) {
      state = SubscriptionState(isPremium: state.isPremium);
    }
  }
}

final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, SubscriptionState>(
  (_) => SubscriptionNotifier(),
);
