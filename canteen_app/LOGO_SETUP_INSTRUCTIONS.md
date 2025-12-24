# 🎨 Logo Setup Instructions

## ✅ What's Been Configured:

1. **Assets folder created:** `assets/logo/`
2. **pubspec.yaml updated:**
   - Assets registered
   - flutter_launcher_icons package added
   - Icon generation configured
3. **Android app name changed:** "Canteen Queue System"
4. **Web title updated:** "Canteen Queue System"
5. **Web meta description updated**

---

## 📋 NEXT STEPS (Manual):

### 1️⃣ Place Your Logo File

**Copy your logo image to:**
```
d:\canteen_online\canteen_app\assets\logo\app_logo.png
```

**Requirements:**
- PNG format
- Minimum 512x512 pixels (1024x1024 recommended)
- Transparent background preferred
- Square aspect ratio

---

### 2️⃣ Generate Icons

After placing the logo, run:

```bash
# Navigate to project folder
cd d:\canteen_online\canteen_app

# Generate launcher icons for Android + Web
flutter pub run flutter_launcher_icons

# OR (newer syntax)
dart run flutter_launcher_icons
```

**Expected output:**
```
✓ Creating default icons Android
✓ Creating adaptive icons Android
✓ Creating web icons
```

---

### 3️⃣ Update Web Favicon (Optional)

Copy your logo to replace the default favicon:

```bash
# Backup original (optional)
Copy-Item web\favicon.png web\favicon.png.bak

# Copy your logo (resize to 32x32 if needed)
Copy-Item assets\logo\app_logo.png web\favicon.png
```

Or use an online tool to convert your logo to a proper favicon:
- https://favicon.io/favicon-converter/
- https://realfavicongenerator.net/

---

### 4️⃣ Verify Changes

#### Android:
```bash
flutter build apk --release
```

Then check:
- App icon on home screen
- App name: "Canteen Queue System"

#### Web:
```bash
flutter build web --release
```

Then check:
- Browser tab shows your favicon
- Page title: "Canteen Queue System"

---

## 📁 Files Modified:

- ✅ `pubspec.yaml` - Assets and dependencies
- ✅ `android/app/src/main/AndroidManifest.xml` - App name
- ✅ `web/index.html` - Title and meta tags

---

## 🎯 What Happens After Icon Generation:

### Android Icons Generated:
- `android/app/src/main/res/mipmap-hdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-mdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`

### Adaptive Icons:
- `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`
- `android/app/src/main/res/mipmap-hdpi/ic_launcher_foreground.png`
- `android/app/src/main/res/mipmap-hdpi/ic_launcher_background.png`
- (and all other densities)

### Web Icons:
- `web/icons/Icon-192.png`
- `web/icons/Icon-512.png`
- `web/icons/Icon-maskable-192.png`
- `web/icons/Icon-maskable-512.png`
- `web/favicon.png`

---

## 🚨 Troubleshooting:

### Issue: "Cannot open file"
**Solution:** Ensure logo is at exact path: `assets/logo/app_logo.png`

### Issue: Icons look pixelated
**Solution:** Use a higher resolution logo (1024x1024 minimum)

### Issue: Logo cut off on Android
**Solution:** Add padding around your logo image before generation

### Issue: Web favicon not updating
**Solution:** Clear browser cache or hard refresh (Ctrl+Shift+R)

---

## 🎨 Logo Best Practices:

1. **Transparent background** for better visual consistency
2. **Simple design** that's recognizable even at small sizes
3. **High contrast** between logo and background
4. **Square format** (avoid wide/tall logos)
5. **Test on both light and dark backgrounds**

---

## ✨ Optional: Add Splash Screen

If you want a splash screen with your logo:

```bash
# Add to pubspec.yaml dev_dependencies
flutter_native_splash: ^2.4.0
```

Configure in pubspec.yaml:
```yaml
flutter_native_splash:
  color: "#FFFFFF"
  image: assets/logo/app_logo.png
  android: true
  ios: false
  web: true
```

Then run:
```bash
dart run flutter_native_splash:create
```

---

**Need help?** Check the logo in `assets/logo/app_logo.png` and run the icon generation command!
