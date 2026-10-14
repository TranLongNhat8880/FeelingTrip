# frontend

A new Flutter project.

## Local map configuration

Configure GEOAPIFY_API_KEY in backend/.env and restart the backend.
Search, reverse geocoding and map tiles go through authenticated admin APIs.
Flutter does not load an environment asset or receive the Geoapify key.

Run from the frontend directory:

```powershell
flutter pub get
flutter run -d edge --dart-define=API_BASE_URL=http://localhost:5000/api/v1
```

For deployment, set the map key on the backend host and build Flutter with
API_BASE_URL pointing to that backend. No frontend/.env is needed.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
