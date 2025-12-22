# Canteen Queue Management System

A real-time canteen order management system built with Flutter and Firebase. Streamlines food ordering, pickup slot booking, and order tracking for college/office canteens.

## Features

### Student App
- 📱 Browse available menu items
- 🛒 Add items to cart with quantity selection
- ⏰ Select pickup time slots
- 📦 Track order status in real-time
- 🔔 View order history

### Admin Dashboard
- 📊 Live order queue with real-time updates
- ✅ Update order status (Pending → Preparing → Ready → Completed)
- 🍽️ Manage menu items (Add/Edit/Delete dishes)
- ⏱️ Slot management with auto-generation
- 📈 Order statistics and filtering

## Tech Stack

- **Frontend**: Flutter (Web + Mobile support)
- **Backend**: Firebase
  - Authentication (Email/Password)
  - Cloud Firestore (Real-time database)
  - Cloud Functions (Auto slot generation)
- **State Management**: StatefulWidget with StreamBuilder
- **UI**: Material Design 3

## Prerequisites

Before you begin, ensure you have the following installed:

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.0 or higher)
- [Node.js](https://nodejs.org/) (v16 or higher) - for Firebase Functions
- [Git](https://git-scm.com/downloads)
- A code editor ([VS Code](https://code.visualstudio.com/) recommended)
- Firebase CLI: `npm install -g firebase-tools`

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/rushikesh-geek/canteen-online.git
cd canteen-online
```

### 2. Flutter App Setup

```bash
cd canteen_app
flutter pub get
```

### 3. Firebase Setup

#### 3.1 Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add Project"
3. Enter project name: `canteen-online`
4. Enable Google Analytics (optional)
5. Create project

#### 3.2 Enable Firebase Services

**Authentication:**
1. Go to Authentication → Sign-in method
2. Enable "Email/Password" provider
3. Click Save

**Firestore Database:**
1. Go to Firestore Database
2. Click "Create database"
3. Start in **Test mode** (for development)
4. Choose your region
5. Click Enable

#### 3.3 Create Firestore Collections

Create the following collections manually or they will be auto-created on first use:

- `users` - User profiles
- `menu` - Food items
- `orders` - Order records
- `orderSlots` - Pickup time slots
- `globalSettings` - App configuration

#### 3.4 Create Required Firestore Indexes

Go to Firestore → Indexes → Composite and create these indexes:

**Index 1: orders (for admin dashboard)**
- Collection: `orders`
- Fields: `placedAt` (Descending), `status` (Ascending)

**Index 2: orders (for user orders)**
- Collection: `orders`
- Fields: `userId` (Ascending), `placedAt` (Descending)

**Index 3: orderSlots (for slot management)**
- Collection: `orderSlots`
- Fields: `date` (Ascending), `isActive` (Ascending), `startTime` (Ascending)

**Index 4: menu (for available items)**
- Collection: `menu`
- Fields: `isAvailable` (Ascending), `name` (Ascending)

#### 3.5 Add Firebase Config to Flutter App

1. Go to Project Settings → Your apps
2. Click "Add app" → Select Web (for web deployment) or Android/iOS
3. Register app with package name: `com.canteen.app`
4. Download `google-services.json` (Android) or `GoogleService-Info.plist` (iOS)
5. For Web, copy the Firebase config

**For Web:**
Open `canteen_app/web/index.html` and replace the Firebase configuration:

```html
<script type="module">
  import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.7.0/firebase-app.js';
  
  const firebaseConfig = {
    apiKey: "YOUR_API_KEY",
    authDomain: "YOUR_PROJECT_ID.firebaseapp.com",
    projectId: "YOUR_PROJECT_ID",
    storageBucket: "YOUR_PROJECT_ID.appspot.com",
    messagingSenderId: "YOUR_SENDER_ID",
    appId: "YOUR_APP_ID"
  };
  
  initializeApp(firebaseConfig);
</script>
```

**For Android:**
Place `google-services.json` in `canteen_app/android/app/`

**For iOS:**
Place `GoogleService-Info.plist` in `canteen_app/ios/Runner/`

### 4. Create Initial Users

In Firebase Console → Authentication → Users:

**Admin User:**
- Email: (your admin email)
- Password: (set a secure password)
- Note: Admin detection is based on email containing "admin"

**Student User:**
- Email: (your student email)
- Password: (set a secure password)

### 5. Add Sample Menu Items

In Firestore Database → menu collection, add documents:

```javascript
{
  name: "Vada",
  price: 20,
  isAvailable: true,
  createdAt: <Timestamp>
}

{
  name: "Idli",
  price: 30,
  isAvailable: true,
  createdAt: <Timestamp>
}
```

Or use the admin panel "Menu Management" feature after logging in.

## Running the App

### Run on Web (Chrome)

```bash
cd canteen_app
flutter run -d chrome --web-port=58122
```

### Run on Android Emulator

```bash
flutter run -d emulator-5554
```

### Run on Physical Device

```bash
flutter devices  # List available devices
flutter run -d <device-id>
```

### Build for Production

**Web:**
```bash
flutter build web --release
```
Output: `canteen_app/build/web/`

**Android APK:**
```bash
flutter build apk --release
```
Output: `canteen_app/build/app/outputs/flutter-apk/app-release.apk`

**iOS:**
```bash
flutter build ios --release
```

## Project Structure

```
canteen_online/
├── canteen_app/              # Flutter application
│   ├── lib/
│   │   ├── main.dart        # App entry point
│   │   └── screens/
│   │       ├── admin/       # Admin screens
│   │       │   ├── admin_dashboard.dart
│   │       │   └── slot_management.dart
│   │       └── student/     # Student screens
│   │           └── student_screens.dart
│   ├── web/                 # Web-specific files
│   ├── android/             # Android-specific files
│   ├── ios/                 # iOS-specific files
│   └── pubspec.yaml         # Dependencies
│
└── functions/               # Firebase Cloud Functions
    ├── index.js            # Cloud Function entry point
    └── package.json        # Node.js dependencies
```

## Firestore Data Model

### users Collection
```javascript
{
  userId: "string",
  email: "string",
  role: "admin" | "student",
  createdAt: Timestamp
}
```

### menu Collection
```javascript
{
  name: "string",
  price: number,
  isAvailable: boolean,
  createdAt: Timestamp
}
```

### orders Collection
```javascript
{
  userId: "string",
  userName: "string",
  items: [{ name: "string", price: number, quantity: number }],
  totalAmount: number,
  status: "pending" | "preparing" | "ready" | "completed",
  placedAt: Timestamp,
  estimatedPickupTime: Timestamp,
  slotId: "string"
}
```

### orderSlots Collection
```javascript
{
  date: "YYYY-MM-DD",
  startTime: Timestamp,
  endTime: Timestamp,
  capacity: number,
  bookedCount: number,
  isActive: boolean,
  autoGenerated: boolean,
  createdAt: Timestamp
}
```

## Usage Guide

### For Students

1. **Login** with student credentials
2. **Browse menu** and add items to cart
3. **Proceed to checkout** and select pickup time slot
4. **Place order** and receive confirmation
5. **Track order status** in real-time from "My Orders"

### For Admins

1. **Login** with admin credentials
2. **View live order queue** on dashboard
3. **Update order status** by clicking status buttons
4. **Manage menu**:
   - Click "Menu" icon → Add/Edit/Delete dishes
   - Toggle availability
5. **Manage slots**:
   - Click "Slot" icon → Auto-generate or add manually
   - Edit capacity or delete slots

## Troubleshooting

### Common Issues

**1. Index Errors:**
- Click the error link to auto-create the required index
- Wait 1-2 minutes for index to build

**2. Firebase Connection Errors:**
- Verify `google-services.json` / `GoogleService-Info.plist` is in correct location
- Check Firebase config in `web/index.html`

**3. "No slots available":**
- Admin must create slots for the current date
- Use "Auto-Generate Slots" button in Slot Management

**4. Hot reload not working:**
- Press `R` (capital R) for hot restart
- Or stop and run `flutter run` again

## Security Rules

For production, update Firestore Security Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Users can read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
    }
    
    // Menu is readable by all, writable by admin
    match /menu/{menuId} {
      allow read: if request.auth != null;
      allow write: if request.auth.token.email.matches('.*admin.*');
    }
    
    // Orders readable by owner or admin, writable by owner
    match /orders/{orderId} {
      allow read: if request.auth.uid == resource.data.userId 
                  || request.auth.token.email.matches('.*admin.*');
      allow create: if request.auth.uid == request.resource.data.userId;
      allow update: if request.auth.token.email.matches('.*admin.*');
    }
    
    // Slots readable by all, writable by admin
    match /orderSlots/{slotId} {
      allow read: if request.auth != null;
      allow write: if request.auth.token.email.matches('.*admin.*');
    }
  }
}
```

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues or questions:
- Open an issue on GitHub
- Check existing issues for solutions



**Built with ❤️ using Flutter & Firebase**
