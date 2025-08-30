# 🤝 Contributing to XPay Flutter Payment App

Thank you for your interest in contributing to XPay! We welcome contributions from developers of all skill levels. This guide will help you get started with contributing to our modern Flutter payment application.

## 📋 Table of Contents

- [Code of Conduct](#-code-of-conduct)
- [Getting Started](#-getting-started)
- [Development Setup](#-development-setup)
- [How to Contribute](#-how-to-contribute)
- [Coding Standards](#-coding-standards)
- [Pull Request Process](#-pull-request-process)
- [Issue Guidelines](#-issue-guidelines)
- [Design Guidelines](#-design-guidelines)

## 🤝 Code of Conduct

This project and everyone participating in it is governed by our Code of Conduct. By participating, you are expected to uphold this code. Please report unacceptable behavior to [conduct@xpay.com](mailto:conduct@xpay.com).

### Our Standards

- **Be respectful** and inclusive to all contributors
- **Be constructive** in discussions and code reviews
- **Focus on what's best** for the community and project
- **Show empathy** towards other community members

## 🚀 Getting Started

### Prerequisites

Before you begin, ensure you have the following installed:

- **Flutter SDK** (3.0 or higher)
- **Dart SDK** (2.17 or higher)
- **Git** for version control
- **Android Studio** or **VS Code** with Flutter extensions
- **Firebase CLI** for backend integration

### Development Environment

1. **Fork the repository**
   ```bash
   git clone https://github.com/yourusername/xpay-flutter.git
   cd xpay-flutter
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

## 🛠️ Development Setup

### Firebase Configuration

1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Enable Authentication and Firestore Database
3. Download configuration files:
   - `google-services.json` for Android
   - `GoogleService-Info.plist` for iOS
4. Place them in the appropriate directories

### IDE Setup

#### VS Code Extensions
- Flutter
- Dart
- Firebase for VS Code
- GitLens
- Error Lens

#### Android Studio Plugins
- Flutter
- Dart
- Firebase Tools

## 🎯 How to Contribute

### Types of Contributions

1. **🐛 Bug Fixes** - Fix issues and improve stability
2. **✨ New Features** - Add new payment features or UI components
3. **🎨 UI/UX Improvements** - Enhance the design and user experience
4. **📚 Documentation** - Improve docs, comments, and examples
5. **🧪 Testing** - Add or improve tests
6. **⚡ Performance** - Optimize app performance

### Contribution Workflow

1. **Check existing issues** or create a new one
2. **Fork the repository** and create a feature branch
3. **Make your changes** following our coding standards
4. **Test thoroughly** on different devices
5. **Submit a pull request** with clear description

## 📝 Coding Standards

### Dart/Flutter Standards

#### Code Style
```dart
// ✅ Good: Use meaningful names
class PaymentController extends GetxController {
  final RxDouble walletBalance = 0.0.obs;
  
  Future<void> processPayment(double amount) async {
    // Implementation
  }
}

// ❌ Bad: Unclear naming
class PC extends GetxController {
  final RxDouble wb = 0.0.obs;
  
  Future<void> pp(double a) async {
    // Implementation
  }
}
```

#### Widget Structure
```dart
// ✅ Good: Organized widget structure
class ModernPaymentCard extends StatelessWidget {
  const ModernPaymentCard({
    Key? key,
    required this.title,
    required this.amount,
    this.onTap,
  }) : super(key: key);

  final String title;
  final double amount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _buildCardDecoration(),
      child: _buildCardContent(),
    );
  }

  BoxDecoration _buildCardDecoration() {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          CustomColor.primaryColor.withOpacity(0.9),
          CustomColor.primaryColor.withOpacity(0.7),
        ],
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 15,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  Widget _buildCardContent() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: CustomStyle.headingStyle),
          const SizedBox(height: 12),
          Text('\$${amount.toStringAsFixed(2)}', 
               style: CustomStyle.amountStyle),
        ],
      ),
    );
  }
}
```

### Design System Compliance

#### Colors
```dart
// ✅ Use predefined colors from CustomColor
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [
        CustomColor.primaryColor,
        CustomColor.appBarColor,
      ],
    ),
  ),
)

// ❌ Don't use hardcoded colors
Container(
  color: Color(0xFF0854F8), // Avoid this
)
```

#### Spacing
```dart
// ✅ Use consistent spacing
const EdgeInsets.all(20)           // Standard padding
const SizedBox(height: 16)         // Standard spacing
BorderRadius.circular(20)          // Standard border radius

// ❌ Avoid random values
const EdgeInsets.all(17)           // Inconsistent
const SizedBox(height: 13)         // Random spacing
```

### File Organization

```
lib/
├── controller/
│   ├── payment_controller.dart
│   └── auth_controller.dart
├── views/
│   ├── dashboard/
│   │   ├── dashboard_screen.dart
│   │   └── widgets/
│   └── payment/
├── widgets/
│   ├── buttons/
│   ├── inputs/
│   └── cards/
└── utils/
    ├── custom_color.dart
    ├── custom_style.dart
    └── dimensions.dart
```

## 🔄 Pull Request Process

### Before Submitting

1. **Update documentation** if needed
2. **Add tests** for new features
3. **Run tests** to ensure nothing breaks
4. **Check code formatting** with `dart format`
5. **Analyze code** with `flutter analyze`

### PR Template

```markdown
## 📝 Description
Brief description of changes made

## ✨ Features Added
- Feature 1
- Feature 2

## 🐛 Bugs Fixed
- Bug fix 1
- Bug fix 2

## 🧪 Testing
- [ ] Unit tests added/updated
- [ ] Integration tests passed
- [ ] Manual testing completed

## 📱 Screenshots
[Add screenshots for UI changes]

## 🔗 Related Issues
Closes #123
```

### Review Process

1. **Automated checks** must pass
2. **Code review** by maintainers
3. **Testing** on multiple devices
4. **Documentation** review if applicable
5. **Merge** after approval

## 🐛 Issue Guidelines

### Bug Reports

Use the bug report template:

```markdown
## 🐛 Bug Description
Clear description of the bug

## 🔄 Steps to Reproduce
1. Go to '...'
2. Click on '...'
3. See error

## ✅ Expected Behavior
What should happen

## ❌ Actual Behavior
What actually happens

## 📱 Environment
- Device: [e.g. iPhone 12, Pixel 5]
- OS: [e.g. iOS 15, Android 12]
- App Version: [e.g. 2.0.0]

## 📸 Screenshots
[Add screenshots if applicable]
```

### Feature Requests

```markdown
## ✨ Feature Description
Clear description of the proposed feature

## 🎯 Problem Statement
What problem does this solve?

## 💡 Proposed Solution
How should this feature work?

## 🎨 Design Mockups
[Add mockups if available]

## 📱 Platform
- [ ] Android
- [ ] iOS
- [ ] Web
```

## 🎨 Design Guidelines

### Material 3 Compliance

- Follow Material 3 design principles
- Use glassmorphism effects consistently
- Maintain proper color contrast ratios
- Ensure accessibility standards

### Animation Standards

```dart
// ✅ Standard animation duration
AnimationController(
  duration: const Duration(milliseconds: 1000),
  vsync: this,
)

// ✅ Standard curves
CurvedAnimation(
  parent: controller,
  curve: Curves.easeInOut,
)
```

### Responsive Design

```dart
// ✅ Responsive padding
EdgeInsets.symmetric(
  horizontal: MediaQuery.of(context).size.width * 0.05,
  vertical: 20,
)

// ✅ Responsive font sizes
TextStyle(
  fontSize: MediaQuery.of(context).size.width > 600 ? 18 : 16,
)
```

## 🧪 Testing Guidelines

### Unit Tests
```dart
// Example unit test
void main() {
  group('PaymentController Tests', () {
    late PaymentController controller;

    setUp(() {
      controller = PaymentController();
    });

    test('should calculate payment fee correctly', () {
      final fee = controller.calculateFee(100.0);
      expect(fee, equals(3.0));
    });
  });
}
```

### Widget Tests
```dart
// Example widget test
void main() {
  testWidgets('PaymentCard displays amount correctly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PaymentCard(amount: 100.0),
      ),
    );

    expect(find.text('\$100.00'), findsOneWidget);
  });
}
```

## 🏆 Recognition

Contributors will be recognized in:
- README.md contributors section
- Release notes
- Discord community highlights
- Annual contributor awards

## 📞 Getting Help

- 💬 **Discord**: [Join our community](https://discord.gg/xpay)
- 📧 **Email**: [digitalpayments@usa.com](mailto:digitalpayments@usa.com)
- 🐛 **Issues**: [GitHub Issues](https://github.com/yourusername/xpay-flutter/issues)
- 📖 **Docs**: [Developer Documentation](https://docs.xpay.com)

## 📄 License

By contributing to XPay, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to XPay! Together, we're building the future of digital payments. 🚀