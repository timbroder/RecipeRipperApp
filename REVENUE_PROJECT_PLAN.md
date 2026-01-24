# RecipeRipper Revenue & Subscription Plan

## Overview

This document outlines the implementation plan for adding subscription-based monetization to RecipeRipper using RevenueCat.

## Subscription Model

### Free Tier
- **2 videos per month** for the first **6 months** from install
- After 6 months: **0 videos** (must subscribe to continue)
- Full feature access during free period (no feature gating)
- Cloud sync included in free tier

### Basic Subscription ($2/month)
- **Unlimited** video processing
- All current features
- Priority support (future)

### Annual Option ($20/year)
- Same as Basic, 17% savings
- Billed annually

### Future: Premium Tier ($5/month) - Phase 2
- Everything in Basic
- Hosted ML models (faster, more accurate)
- Long video support (>30 min)
- Nutrition extraction
- Meal planning integrations

---

## Technical Architecture

### RevenueCat Integration

```
┌─────────────────────────────────────────────────────────┐
│                      Flutter App                         │
├─────────────────────────────────────────────────────────┤
│  SubscriptionProvider                                    │
│  ├── Check entitlements                                  │
│  ├── Track video usage                                   │
│  ├── Manage trial period                                 │
│  └── Handle paywall display                              │
├─────────────────────────────────────────────────────────┤
│  SubscriptionService                                     │
│  ├── RevenueCat SDK wrapper                              │
│  ├── Purchase handling                                   │
│  ├── Restore purchases                                   │
│  └── Subscription status                                 │
├─────────────────────────────────────────────────────────┤
│  UsageTrackingService                                    │
│  ├── Track videos processed                              │
│  ├── Track install date                                  │
│  ├── Calculate remaining quota                           │
│  └── Persist usage data locally                          │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│                    RevenueCat Backend                    │
│  ├── Entitlements: "pro"                                 │
│  ├── Products: monthly, annual                           │
│  └── Customer management                                 │
└─────────────────────────────────────────────────────────┘
```

### Data Model

```dart
// Subscription status
class SubscriptionStatus {
  final bool isSubscribed;
  final String? productId;
  final DateTime? expirationDate;
  final bool willRenew;
}

// Usage tracking (stored locally)
class UsageData {
  final DateTime installDate;
  final int videosProcessedThisMonth;
  final DateTime monthStartDate;
  final int totalVideosProcessed;
}

// Quota calculation
class QuotaInfo {
  final int videosRemaining;  // This month
  final int videosAllowed;    // Per month (2 or unlimited)
  final bool isInTrialPeriod; // First 6 months
  final int trialMonthsRemaining;
  final bool requiresSubscription;
}
```

### Paywall Triggers

1. **Before processing** - Check quota, show paywall if exceeded
2. **Settings screen** - "Upgrade" section always visible
3. **Home screen** - Subtle banner showing remaining videos
4. **After trial ends** - Full-screen paywall on app open

---

## Implementation Sprints

### Sprint R1: RevenueCat Setup & Foundation (Week 1)

#### Tasks
- [ ] Create RevenueCat account and project
- [ ] Configure App Store Connect products
  - [ ] `reciperippper_monthly` - $1.99/month
  - [ ] `reciperipper_annual` - $19.99/year
- [ ] Configure Google Play Console products
  - [ ] Same product IDs as iOS
- [ ] Set up RevenueCat entitlements
  - [ ] `pro` entitlement for subscribers
- [ ] Add RevenueCat SDK to Flutter project
  - [ ] `purchases_flutter` package
- [ ] Create `SubscriptionService` class
  - [ ] Initialize RevenueCat with API keys
  - [ ] Configure user identification
  - [ ] Get current offerings
  - [ ] Check subscription status
  - [ ] Purchase product
  - [ ] Restore purchases

#### Files to Create/Modify
- `lib/services/subscription_service.dart` - RevenueCat wrapper
- `lib/models/subscription_status.dart` - Status model
- `pubspec.yaml` - Add purchases_flutter
- `ios/Runner/Info.plist` - Add StoreKit config if needed
- `android/app/build.gradle` - Billing dependency (auto via package)

#### Acceptance Criteria
- [ ] RevenueCat dashboard shows test purchases
- [ ] Can fetch offerings from both platforms
- [ ] Can complete sandbox/test purchases
- [ ] Subscription status correctly reflects purchases

---

### Sprint R2: Usage Tracking & Quota System (Week 2)

#### Tasks
- [ ] Create `UsageTrackingService`
  - [ ] Track install date (first launch)
  - [ ] Track videos processed per month
  - [ ] Calculate trial months remaining
  - [ ] Calculate videos remaining this month
  - [ ] Reset monthly counter on month boundary
- [ ] Create `UsageData` model
- [ ] Create `QuotaInfo` model
- [ ] Store usage data in SharedPreferences
- [ ] Integrate with `ProcessingService`
  - [ ] Check quota before processing
  - [ ] Increment counter after successful processing
- [ ] Add migration for existing users
  - [ ] Set install date to "now" for existing installs
  - [ ] Or backdate based on first recipe creation date

#### Files to Create/Modify
- `lib/services/usage_tracking_service.dart` - Usage tracking
- `lib/models/usage_data.dart` - Usage model
- `lib/models/quota_info.dart` - Quota model
- `lib/services/processing_service.dart` - Add quota check
- `lib/services/database_service.dart` - Add first recipe date query

#### Acceptance Criteria
- [ ] Install date persists across app restarts
- [ ] Video count increments after processing
- [ ] Monthly counter resets on new month
- [ ] Quota correctly calculates based on trial period
- [ ] Existing users get reasonable install date

---

### Sprint R3: Subscription Provider & State Management (Week 3)

#### Tasks
- [ ] Create `SubscriptionProvider`
  - [ ] Combine subscription status + usage tracking
  - [ ] Expose `canProcessVideo` boolean
  - [ ] Expose `quotaInfo` for UI
  - [ ] Expose `subscriptionStatus` for UI
  - [ ] Handle subscription changes (listen to RevenueCat)
- [ ] Add provider to app
- [ ] Create quota check flow
  - [ ] Return true if subscribed
  - [ ] Return true if in trial + under quota
  - [ ] Return false otherwise
- [ ] Write comprehensive unit tests

#### Files to Create/Modify
- `lib/providers/subscription_provider.dart` - Main provider
- `lib/main.dart` - Add provider to tree
- `test/providers/subscription_provider_test.dart` - Tests

#### Acceptance Criteria
- [ ] Provider correctly reflects subscription state
- [ ] `canProcessVideo` logic handles all cases
- [ ] State updates when subscription purchased
- [ ] Tests cover edge cases (month boundaries, trial end, etc.)

---

### Sprint R4: Paywall UI (Week 4)

#### Tasks
- [ ] Create `PaywallScreen`
  - [ ] Show current plan/status
  - [ ] Display monthly and annual options
  - [ ] Show savings for annual
  - [ ] Handle loading states
  - [ ] Handle errors
  - [ ] Restore purchases button
  - [ ] Terms of service / Privacy policy links
- [ ] Create `UpgradeBanner` widget
  - [ ] Shows remaining videos
  - [ ] Subtle design, not intrusive
  - [ ] Tappable to open paywall
- [ ] Create `QuotaExceededDialog`
  - [ ] Shown when trying to process without quota
  - [ ] Options: Upgrade, Maybe Later
- [ ] Style paywall with app theme

#### Files to Create/Modify
- `lib/screens/paywall_screen.dart` - Full paywall
- `lib/widgets/upgrade_banner.dart` - Home screen banner
- `lib/widgets/quota_exceeded_dialog.dart` - Blocking dialog

#### Acceptance Criteria
- [ ] Paywall displays offerings correctly
- [ ] Purchases complete successfully
- [ ] Restore works for previous subscribers
- [ ] UI matches app design language
- [ ] Loading and error states handled

---

### Sprint R5: Integration & User Flows (Week 5)

#### Tasks
- [ ] Integrate quota check into video processing flow
  - [ ] Check before starting processing
  - [ ] Show dialog if quota exceeded
  - [ ] Proceed if allowed
- [ ] Add upgrade banner to home screen
  - [ ] Show only for free users
  - [ ] Display remaining videos / days
- [ ] Add subscription section to settings
  - [ ] Current plan display
  - [ ] Manage subscription link (opens app store)
  - [ ] Upgrade button for free users
- [ ] Handle trial expiration
  - [ ] Show paywall on app open if trial expired and not subscribed
  - [ ] Allow browsing existing recipes (read-only for processing)
- [ ] Add "Pro" badge to UI when subscribed

#### Files to Create/Modify
- `lib/screens/home_screen.dart` - Add banner
- `lib/screens/settings_screen.dart` - Add subscription section
- `lib/screens/video_preview_screen.dart` - Check quota before process
- `lib/screens/processing_screen.dart` - Handle quota error

#### Acceptance Criteria
- [ ] Cannot process video when quota exceeded
- [ ] Clear upgrade path presented
- [ ] Settings shows subscription status
- [ ] Trial expiration handled gracefully
- [ ] Existing recipes remain accessible

---

### Sprint R6: Testing & Polish (Week 6)

#### Tasks
- [ ] End-to-end testing of purchase flows
  - [ ] iOS sandbox testing
  - [ ] Android test purchases
- [ ] Test edge cases
  - [ ] Subscription expires mid-month
  - [ ] Subscription renewed
  - [ ] Refund handling (RevenueCat webhook)
  - [ ] Family sharing (iOS)
  - [ ] Restore on new device
- [ ] Test trial period logic
  - [ ] New install gets 6 months
  - [ ] Month boundary handling
  - [ ] Quota reset timing
- [ ] Add analytics events
  - [ ] Paywall viewed
  - [ ] Purchase initiated
  - [ ] Purchase completed
  - [ ] Purchase failed
  - [ ] Quota exceeded
- [ ] App Store / Play Store preparation
  - [ ] Subscription description text
  - [ ] Screenshots with subscription UI
  - [ ] Review notes for testers

#### Files to Create/Modify
- `integration_test/subscription_test.dart` - E2E tests
- Various files for analytics integration

#### Acceptance Criteria
- [ ] All purchase flows work on both platforms
- [ ] Edge cases handled correctly
- [ ] Analytics tracking in place
- [ ] Ready for app store review

---

## RevenueCat Configuration

### Products

| Product ID | Type | Price | Description |
|------------|------|-------|-------------|
| `reciperipper_monthly` | Auto-renewable | $1.99/mo | Monthly unlimited access |
| `reciperipper_annual` | Auto-renewable | $19.99/yr | Annual unlimited access (save 17%) |

### Entitlements

| Entitlement ID | Description | Products |
|----------------|-------------|----------|
| `pro` | Full unlimited access | monthly, annual |

### Offerings

| Offering ID | Description | Packages |
|-------------|-------------|----------|
| `default` | Standard offering | monthly, annual |

---

## Quota Logic Pseudocode

```dart
QuotaInfo calculateQuota(UsageData usage, SubscriptionStatus subscription) {
  // Subscribers always have unlimited
  if (subscription.isSubscribed) {
    return QuotaInfo(
      videosRemaining: unlimited,
      videosAllowed: unlimited,
      isInTrialPeriod: false,
      trialMonthsRemaining: 0,
      requiresSubscription: false,
    );
  }

  // Calculate trial status
  final monthsSinceInstall = monthsBetween(usage.installDate, now);
  final isInTrial = monthsSinceInstall < 6;
  final trialMonthsRemaining = max(0, 6 - monthsSinceInstall);

  // Calculate monthly quota
  final videosAllowed = isInTrial ? 2 : 0;
  final videosRemaining = max(0, videosAllowed - usage.videosProcessedThisMonth);

  return QuotaInfo(
    videosRemaining: videosRemaining,
    videosAllowed: videosAllowed,
    isInTrialPeriod: isInTrial,
    trialMonthsRemaining: trialMonthsRemaining,
    requiresSubscription: !isInTrial || videosRemaining == 0,
  );
}
```

---

## UI Copy

### Paywall Headlines
- **During trial**: "Unlock Unlimited Recipes"
- **Trial expired**: "Your Free Trial Has Ended"
- **Quota exceeded**: "You've Used Your Free Videos This Month"

### Upgrade Banner (Home Screen)
- During trial: "2 free videos left this month • Upgrade for unlimited"
- Trial ending soon: "Trial ends in X days • Upgrade now"
- Trial expired: "Subscribe to process more videos"

### Settings Section
- Subscribed: "RecipeRipper Pro • Unlimited Processing"
- Free/Trial: "Free Plan • 2 videos/month"

---

## Analytics Events

| Event | Properties | Trigger |
|-------|------------|---------|
| `paywall_viewed` | `source`, `trial_remaining` | Paywall opened |
| `purchase_started` | `product_id` | User taps buy |
| `purchase_completed` | `product_id`, `price` | Purchase succeeds |
| `purchase_failed` | `product_id`, `error` | Purchase fails |
| `purchase_restored` | `product_id` | Restore succeeds |
| `quota_exceeded` | `videos_processed` | Processing blocked |
| `trial_expired` | `total_videos` | Trial period ends |

---

## Future Considerations (Phase 2)

### Premium Tier
- Higher price point ($4.99/month)
- Hosted ML models via API
- Requires backend infrastructure
- Separate entitlement in RevenueCat

### Lifetime Purchase
- One-time $39.99 purchase
- Non-consumable product
- Maps to `pro` entitlement
- Consider for v2.0

### Promotional Offers
- RevenueCat supports intro offers
- Consider 7-day free trial of Pro
- Winback offers for churned subscribers

### Family Sharing
- iOS supports family sharing for subscriptions
- Enable in App Store Connect
- RevenueCat handles automatically

---

## Dependencies

```yaml
# pubspec.yaml additions
dependencies:
  purchases_flutter: ^8.0.0  # RevenueCat SDK
```

---

## Timeline Summary

| Sprint | Focus | Duration |
|--------|-------|----------|
| R1 | RevenueCat Setup | Week 1 |
| R2 | Usage Tracking | Week 2 |
| R3 | State Management | Week 3 |
| R4 | Paywall UI | Week 4 |
| R5 | Integration | Week 5 |
| R6 | Testing & Polish | Week 6 |

**Total: 6 weeks to subscription MVP**

---

## Success Metrics

- **Conversion rate**: Target 5-10% of trial users converting
- **Trial completion**: Track how many users hit quota vs. upgrade early
- **Churn rate**: Monthly subscription cancellations
- **LTV**: Lifetime value per subscriber
- **ARPU**: Average revenue per user

---

**Last Updated**: 2026-01-23
**Status**: Planning Complete - Ready for Implementation
