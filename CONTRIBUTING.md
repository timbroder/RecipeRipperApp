# Contributing to Recipe Ripper Mobile

Thank you for considering contributing to Recipe Ripper Mobile! This document provides guidelines and instructions for contributing.

## Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment for everyone.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues to avoid duplicates. When creating a bug report, include:

- **Clear title and description**
- **Steps to reproduce**
- **Expected vs actual behavior**
- **Screenshots** (if applicable)
- **Device information** (iOS/Android version, device model)
- **App version**

### Suggesting Features

Feature suggestions are welcome! Please:

- Check the [PROJECT_PLAN.md](PROJECT_PLAN.md) to see if it's already planned
- Search existing issues for similar suggestions
- Provide clear use cases and benefits
- Consider implementation complexity

### Pull Requests

1. **Fork the repository** and create your branch from `develop`
2. **Follow the sprint plan** - check [PROJECT_PLAN.md](PROJECT_PLAN.md) for current priorities
3. **Write clear commit messages** following our conventions (see below)
4. **Add tests** for new functionality
5. **Update documentation** if needed
6. **Run the full test suite** before submitting
7. **Submit the PR** with a clear description

## Development Setup

### Prerequisites

- Flutter SDK 3.16+
- Dart 3.0+
- Xcode 15+ (for iOS)
- Android Studio with SDK 26+ (for Android)
- Git

### Initial Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/RecipeRipperApp.git
cd RecipeRipperApp

# Add upstream remote
git remote add upstream https://github.com/timbroder/RecipeRipperApp.git

# Install dependencies
flutter pub get

# Verify setup
flutter doctor
```

## Development Workflow

### Branch Naming

- `feature/short-description` - New features
- `fix/short-description` - Bug fixes
- `refactor/short-description` - Code refactoring
- `docs/short-description` - Documentation updates
- `test/short-description` - Test additions/updates

### Commit Message Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Formatting, missing semicolons, etc.
- `refactor`: Code restructuring
- `test`: Adding or updating tests
- `chore`: Build tasks, package updates, etc.

**Examples:**
```
feat(parsing): Add support for fractional ingredient quantities

Implemented fraction parsing for ingredients like "1/2 cup" and "2 1/4 tsp"

Closes #42
```

```
fix(database): Prevent duplicate recipe entries

Added unique constraint on recipe source_url to prevent duplicates when
processing the same video twice.

Fixes #38
```

### Coding Standards

#### Dart/Flutter Style

Follow the official [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style) and [Flutter Style Guide](https://github.com/flutter/flutter/wiki/Style-guide-for-Flutter-repo).

**Key points:**
- Use `dart format` before committing
- Prefer `const` constructors where possible
- Use trailing commas for better formatting
- Add meaningful comments for complex logic
- Document public APIs with `///` doc comments
- Avoid `print()` statements (use proper logging)

**Example:**
```dart
/// Parses an ingredient string into structured components.
///
/// Returns an [Ingredient] with quantity, unit, and item extracted
/// from [text]. Returns null if the text cannot be parsed.
Ingredient? parseIngredient(String text) {
  // Implementation...
}
```

#### File Organization

- One class per file (exceptions for small helper classes)
- Group imports: dart, flutter, package, relative
- Use relative imports for local files
- Alphabetize imports within groups

**Example:**
```dart
// Dart imports
import 'dart:async';
import 'dart:io';

// Flutter imports
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Package imports
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

// Relative imports
import '../models/recipe.dart';
import '../services/database_service.dart';
```

### Testing

#### Running Tests

```bash
# All tests
flutter test

# Specific test file
flutter test test/models/recipe_test.dart

# With coverage
flutter test --coverage

# Widget tests only
flutter test test/widgets

# Integration tests
flutter test integration_test/
```

#### Writing Tests

- Write tests for all new features
- Aim for >80% code coverage
- Use descriptive test names
- Group related tests
- Mock external dependencies

**Example:**
```dart
group('Recipe', () {
  test('toJson() serializes correctly', () {
    final recipe = Recipe(
      title: 'Test Recipe',
      ingredients: [
        Ingredient(item: 'flour', quantity: 2, unit: 'cups'),
      ],
    );

    final json = recipe.toJson();

    expect(json['title'], equals('Test Recipe'));
    expect(json['ingredients'], hasLength(1));
  });

  test('fromJson() deserializes correctly', () {
    final json = {
      'title': 'Test Recipe',
      'ingredients': [
        {'item': 'flour', 'quantity': 2.0, 'unit': 'cups'},
      ],
    };

    final recipe = Recipe.fromJson(json);

    expect(recipe.title, equals('Test Recipe'));
    expect(recipe.ingredients, hasLength(1));
    expect(recipe.ingredients.first.item, equals('flour'));
  });
});
```

### Native Code (iOS/Android)

#### iOS (Swift)

- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use `guard` for early returns
- Prefer `let` over `var`
- Document public methods

#### Android (Kotlin)

- Follow [Kotlin Coding Conventions](https://kotlinlang.org/docs/coding-conventions.html)
- Use nullable types appropriately
- Prefer `val` over `var`
- Document public methods

## Pull Request Process

1. **Update your fork**:
   ```bash
   git fetch upstream
   git checkout develop
   git merge upstream/develop
   ```

2. **Create feature branch**:
   ```bash
   git checkout -b feature/my-feature
   ```

3. **Make changes and commit**:
   ```bash
   git add .
   git commit -m "feat: Add my feature"
   ```

4. **Push to your fork**:
   ```bash
   git push origin feature/my-feature
   ```

5. **Create Pull Request** on GitHub:
   - Base: `timbroder/RecipeRipperApp:develop`
   - Compare: `your-username/RecipeRipperApp:feature/my-feature`
   - Fill out the PR template
   - Link related issues

6. **Address review feedback**:
   - Make requested changes
   - Push additional commits
   - Request re-review when ready

7. **After approval**:
   - Squash commits if requested
   - Merge will be performed by maintainers

## Code Review Guidelines

### For Authors

- Keep PRs focused and reasonably sized
- Write clear PR descriptions
- Respond to feedback promptly
- Be open to suggestions

### For Reviewers

- Be respectful and constructive
- Explain reasoning behind suggestions
- Approve when satisfied
- Use "Request Changes" for blocking issues

## Project Structure Guidelines

### Adding New Features

1. **Models**: Add to `lib/models/`
2. **Services**: Add to `lib/services/`
3. **Screens**: Add to `lib/screens/`
4. **Widgets**: Add to `lib/widgets/`
5. **Tests**: Mirror structure in `test/`

### Database Changes

- Update schema in `database_service.dart`
- Increment database version
- Add migration logic in `_onUpgrade`
- Test migrations thoroughly

### Adding Dependencies

- Check if the package is maintained
- Consider bundle size impact
- Add to appropriate section in `pubspec.yaml`
- Run `flutter pub get`
- Update documentation if needed

## Documentation

### When to Update Docs

- New features or APIs
- Breaking changes
- Configuration changes
- Architecture changes

### Where to Update

- `README.md` - User-facing features
- `CLAUDE.md` - Developer/AI context
- `PROJECT_PLAN.md` - Sprint planning
- Code comments - Complex logic
- API docs - Public methods

## Getting Help

- **Questions**: Open a [Discussion](https://github.com/timbroder/RecipeRipperApp/discussions)
- **Bugs**: Open an [Issue](https://github.com/timbroder/RecipeRipperApp/issues)
- **Ideas**: Start a [Discussion](https://github.com/timbroder/RecipeRipperApp/discussions)

## Recognition

Contributors will be acknowledged in:
- README.md contributors section
- Release notes
- Commit history

Thank you for contributing to Recipe Ripper Mobile! 🎉
