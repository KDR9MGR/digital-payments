# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Build & Run
```bash
# Get dependencies
flutter pub get

# Run the app in debug mode
flutter run

# Build APK for Android
flutter build apk

# Build iOS (requires Xcode)
flutter build ios

# Run tests
flutter test

# Analyze code
flutter analyze

# Format code
dart format .
```

### Testing
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/widget_test.dart

# Run tests with coverage
flutter test --coverage
```

## Architecture Overview

### State Management Strategy
- **GetX**: Primary state management framework for reactive programming and dependency injection
- **Provider**: Used for user authentication state (`UserProvider`, `LoginViewModel`, `WalletViewModel`)
- **Observable Controllers**: Each feature has its own GetX controller (23 controllers total)

### Core Architecture Patterns
- **MVC Pattern**: Controllers handle business logic, Views handle UI, Models define data structures
- **Repository Pattern**: Services layer (`MoovService`, `StripeService`, `PlatformPaymentService`) abstracts payment providers
- **Route-based Navigation**: Centralized routing through `Routes` class with 50+ named routes

### Project Structure
```
lib/
├── controller/        # GetX controllers for business logic (23 controllers)
├── data/             # Data models (UserModel, TransactionModel, etc.)
├── routes/           # Centralized route definitions 
├── services/         # External service integrations (payments, Firebase)
├── utils/            # Utilities, themes, constants, localization
├── views/            # UI screens organized by feature
├── widgets/          # Reusable UI components
└── binding/          # GetX dependency injection bindings
```

### Key Controllers
- `AuthController`: Authentication flow management
- `DashboardController`: Main dashboard state
- `SubscriptionController`: Payment subscription handling
- Feature controllers: `AddMoneyController`, `TransferMoneyController`, `WithdrawController`, etc.

## Payment Integration Architecture

### Multi-Provider Strategy
The app uses a **primary + fallback** approach for payment processing:

1. **MoovService** - Primary payment backend
2. **PlatformPaymentService** - Primary for subscription payments (Apple Pay, Google Pay)
3. **StripeService** - Fallback payment processor

### Initialization Flow
Payment services are initialized sequentially in `main.dart` with error handling. The app continues to function even if some services fail to initialize.

## Material 3 Design System

### Theme Configuration
- **Material 3** design system with dark theme
- **Custom color scheme** defined in `CustomColor` class
- **Typography**: Google Fonts (Josefin Sans) with consistent text scaling
- **Responsive design** using `flutter_screenutil` package

### Design Principles
- Dark theme with gradient backgrounds (`#000E19` to `#001A2E`)
- Neon blue accent colors (`#0854F8`, `#465ACA`)
- Glassmorphism effects with transparent cards
- Consistent 16px border radius for cards and buttons

## Localization

### Multi-language Support
- **Supported languages**: English (primary), Arabic, Spanish
- **Implementation**: Custom `LocalString` class extending GetX translations
- **RTL support**: Included for Arabic language
- **Language files**: Located in `lib/utils/language/`

### Usage
```dart
// Access translations
Text('key'.tr)

// Change language
Get.updateLocale(Locale('ar', 'SA'));
```

## Firebase Integration

### Services Used
- **Firebase Auth**: User authentication
- **Cloud Firestore**: Database for user data and transactions
- **Firebase Storage**: Profile photos and documents
- **Cloud Functions**: Backend logic processing
- **Firebase Analytics**: User behavior tracking
- **Firebase Crashlytics**: Error reporting

### Configuration
- Android: `google-services.json` in `android/app/`
- iOS: `GoogleService-Info.plist` in `ios/Runner/`

## Feature Modules

### Core Features
- **Wallet Management**: Multi-currency wallet with real-time balance
- **Money Transfer**: P2P transfers with QR code scanning
- **Add Money**: Multiple funding sources (cards, bank accounts)
- **Money Out**: Agent network withdrawals
- **Invoice System**: Create and manage invoices
- **Voucher System**: Create and redeem vouchers
- **Currency Exchange**: Real-time conversion rates
- **Subscription Management**: Premium features with payment integration

### UI Components
- **Custom Buttons**: Located in `widgets/buttons/`
- **Form Inputs**: Located in `widgets/inputs/`
- **Reusable Widgets**: Wallet info, transaction widgets, etc.

## Development Guidelines

### Code Organization
- Each feature has its own controller in `controller/`
- UI screens organized by feature in `views/`
- Shared widgets in `widgets/` with subfolders by type
- Models in `data/` directory

### Navigation Pattern
- Uses GetX named routes defined in `Routes` class
- Route names use camelCase convention
- Deep linking support through route parameters

### Error Handling
- Payment service initialization includes comprehensive error handling
- App continues to function with degraded features if services fail
- User-friendly error screens for critical failures

## Common Development Tasks

### Adding a New Feature
1. Create controller in `controller/`
2. Define data model in `data/` if needed
3. Create UI screens in `views/feature_name/`
4. Add routes to `Routes` class
5. Create reusable widgets in `widgets/` if applicable

### Payment Integration
- Use existing service abstractions (`MoovService`, `StripeService`)
- Follow the primary + fallback pattern for reliability
- Handle initialization errors gracefully

### Styling Guidelines
- Use `CustomColor` class for consistent theming
- Follow Material 3 design patterns
- Use `ScreenUtil` for responsive dimensions
- Implement dark theme variants for all components