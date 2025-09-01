# 🎯 Habit Forge App

A comprehensive habit tracking application built with Flutter, featuring GitHub-style progress visualization, daily reminders, and a clean Material 3 design.

## ✨ Features

### 🏠 Dashboard
- **Interactive Habit Cards** - Visual representation of each habit with progress indicators
- **Streak Counters** - Current streak display with completion status
- **Progress Visualization** - 7-day grid chart showing recent completions
- **Quick Actions** - Tap to mark habits complete or view detailed progress

### 📅 Calendar View
- **GitHub-Style Visualization** - Color-coded contribution graph
- **Monthly Overview** - Full calendar with navigation
- **Interactive Days** - Tap any day to view/edit completions
- **Progress Markers** - Colored dots indicating completed habits

### 🔔 Smart Notifications
- **Daily Reminders** - Customizable notification times
- **Intelligent Scheduling** - Only notifies for incomplete habits
- **Overdue Alerts** - In-app banners for missed habits
- **Permission Handling** - Proper Android/iOS permission management

### 🎨 Modern UI/UX
- **Material 3 Design** - Latest Material Design components
- **Dark/Light Theme** - System-aware theme switching
- **Responsive Layout** - Optimized for mobile devices
- **Smooth Animations** - Fade transitions and interactive feedback

### 💾 Data Management
- **Local Storage** - SharedPreferences for data persistence
- **Habit Categories** - Custom icons and colors
- **Progress Tracking** - Detailed completion history
- **Data Export** - JSON-based storage format

## 🏗️ Architecture

```
lib/
├── main.dart              # App entry point & initialization
├── theme.dart             # Material 3 theme configuration
├── models/                # Data models
│   ├── habit.dart         # Habit entity with completion tracking
│   └── habit_storage.dart # Local storage service
├── services/              # Business logic services
│   └── notification_service.dart # Push notifications
├── screens/               # App screens/pages
│   ├── add_habit_screen.dart    # Create/edit habits
│   └── calendar_screen.dart     # Calendar visualization
└── widgets/               # Reusable UI components
    ├── habit_card.dart    # Habit display card
    ├── habit_grid.dart    # Calendar grid component
    └── habit_grid_example.dart # Demo component
```

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.0+)
- Android Studio or VS Code
- Android/iOS device or emulator

### Installation

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd habit_forge_app
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the app:**
   ```bash
   flutter run
   ```

### Building for Production

#### Android APK:
```bash
flutter build apk --release
```

#### iOS (requires macOS):
```bash
flutter build ios --release
```

## 📱 Usage Guide

### Creating a New Habit
1. Tap the **+ button** in the top-right corner
2. Fill in habit name and description
3. Choose an icon from the available options
4. Select a color from the palette
5. Set reminder time (optional)
6. Tap **"Create Habit"**

### Tracking Progress
1. **Daily Completion**: Tap the checkmark on any habit card
2. **Calendar View**: Access via calendar icon to see progress over time
3. **Streak Tracking**: View current streaks on habit cards

### Managing Notifications
1. **Enable Reminders**: Set time during habit creation
2. **Daily Alerts**: Receive notifications at specified times
3. **Overdue Notices**: Get in-app alerts for missed habits

## 🛠️ Development

### Code Quality
- **Linting**: `flutter analyze`
- **Testing**: `flutter test`
- **Formatting**: `flutter format .`

### Project Structure
- **Clean Architecture** with separation of concerns
- **Modular Components** for reusability
- **Error Boundaries** for robust error handling
- **Performance Optimized** with efficient state management

### Key Technologies
- **Flutter** - Cross-platform UI framework
- **Material 3** - Modern design system
- **SharedPreferences** - Local data persistence
- **Table Calendar** - Calendar visualization
- **Flutter Local Notifications** - Push notifications
- **Timezone** - Time zone handling

## 📊 Features Overview

| Feature | Status | Description |
|---------|--------|-------------|
| ✅ Habit Creation | Complete | Full CRUD operations with validation |
| ✅ Progress Tracking | Complete | Daily completion with streak counting |
| ✅ Calendar View | Complete | GitHub-style contribution graph |
| ✅ Notifications | Complete | Daily reminders with smart scheduling |
| ✅ Dark Mode | Complete | System-aware theme switching |
| ✅ Data Persistence | Complete | Local storage with JSON serialization |
| ✅ Responsive UI | Complete | Mobile-optimized design |
| ✅ Error Handling | Complete | Comprehensive error boundaries |

## 🔧 Configuration

### Notification Permissions
The app automatically requests notification permissions on first launch. For Android, additional permissions are configured in `android/app/src/main/AndroidManifest.xml`.

### Theme Customization
Colors and themes can be modified in `lib/theme.dart`:
- **Primary Colors**: App accent colors
- **Habit Colors**: Available color palette for habits
- **Typography**: Custom font configurations

### Storage Configuration
Data persistence settings in `lib/models/habit_storage.dart`:
- **Storage Key**: `habits` (SharedPreferences)
- **Data Format**: JSON serialization
- **Migration**: Automatic data format updates

## 🐛 Troubleshooting

### Common Issues

#### App Stuck on Splash Screen
```bash
# Check console logs
flutter logs

# Clear app data
adb shell pm clear com.example.habit_forge_app
```

#### Notification Issues
```bash
# Check notification permissions
adb shell dumpsys notification

# Restart notification service
flutter clean && flutter run
```

#### Build Issues
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter build apk --debug
```

### Debug Mode
Enable debug logging in `lib/main.dart`:
```dart
debugPrint('Debug message here');
```

## 📈 Future Enhancements

- [ ] **Cloud Sync** - Google Drive/iCloud integration
- [ ] **Habit Templates** - Pre-built habit categories
- [ ] **Analytics** - Progress statistics and insights
- [ ] **Social Features** - Habit sharing and challenges
- [ ] **Widgets** - Home screen widgets for quick access
- [ ] **Backup/Restore** - Data export/import functionality

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 Support

For support and questions:
- Create an issue in the repository
- Check the troubleshooting section above
- Review the code documentation in each file

---

**Built with ❤️ using Flutter**