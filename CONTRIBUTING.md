# Contributing to Zurtex Global

Thank you for your interest in contributing to Zurtex Global! We welcome contributions from the community.

## How to Contribute

### Reporting Bugs

If you find a bug, please open an issue on GitHub with:
- A clear, descriptive title
- Steps to reproduce the issue
- Expected behavior vs actual behavior
- Your device information (Android version, device model)
- Screenshots if applicable

### Suggesting Features

Feature requests are welcome! Please open an issue with:
- A clear description of the feature
- Why it would be useful
- How it should work

### Code Contributions

1. **Fork the Repository**
   ```bash
   git clone https://github.com/AH96HSQ/Zurtex-Global.git
   cd Zurtex-Global
   ```

2. **Create a Branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make Your Changes**
   - Follow the existing code style
   - Add comments for complex logic
   - Test your changes thoroughly

4. **Test**
   ```bash
   flutter test
   flutter build apk --release
   ```

5. **Commit Your Changes**
   ```bash
   git add .
   git commit -m "Add feature: your feature description"
   ```

6. **Push and Create Pull Request**
   ```bash
   git push origin feature/your-feature-name
   ```
   Then open a Pull Request on GitHub.

## Code Style Guidelines

- Follow Dart's official [style guide](https://dart.dev/guides/language/effective-dart/style)
- Use meaningful variable and function names
- Keep functions small and focused
- Add documentation comments for public APIs
- Format code with `dart format .`

## Pull Request Process

1. Ensure your code builds without errors
2. Update documentation if needed
3. Add yourself to the contributors list if you'd like
4. Wait for review from maintainers
5. Address any requested changes

## Development Setup

### Prerequisites
- Flutter SDK 3.8.1+
- Android Studio or VS Code
- Git

### Environment Configuration
Create a `.env` file with your backend URLs:
```env
BACKEND_BASE_URL=your_backend_url
BACKEND_BACKUP_URL=your_backup_url
```

For backend development, see `Backend/.env.example` for required variables.

## Testing

Run tests before submitting:
```bash
flutter test
flutter analyze
```

## License

By contributing to Zurtex Global, you agree that your contributions will be licensed under the GPL-3.0-or-later license.

## Questions?

Feel free to open an issue or contact us at support@zurtex.com

Thank you for helping make Zurtex Global better! 🚀
