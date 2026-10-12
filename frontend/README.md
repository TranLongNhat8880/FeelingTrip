# frontend

A new Flutter project.

## Local map configuration

Run the following commands from the `frontend` directory:

```powershell
Copy-Item .env.example .env
```

Only copy the template if `.env` does not already exist. Fill in
`GEOAPIFY_API_KEY` in `.env` with a Geoapify client API key, then run:

```powershell
flutter pub get
flutter run -d edge --dart-define=API_BASE_URL=http://localhost:5000/api/v1
```

No `--dart-define=GEOAPIFY_API_KEY=...` argument is needed. Restart the app
after changing `.env`; hot reload is not enough to reload the configuration.

The root `.gitignore` excludes `.env`. Commit `.env.example`, not the real
key. Each teammate must create their own `frontend/.env`. This is separate
from `backend/.env`; never copy backend secrets into the Flutter asset.

### Build and deployment

Before building locally or in CI, create `frontend/.env` with the client key.
The file is a required Flutter asset, so builds need it even when the map
feature is not used. An empty `GEOAPIFY_API_KEY=` allows the rest of the app
to run, but the map picker will show a configuration message.

Use the deployed backend URL instead of localhost for release builds, for example:

```powershell
flutter build apk --dart-define=API_BASE_URL=https://YOUR_BACKEND_HOST/api/v1
flutter build web --dart-define=API_BASE_URL=https://YOUR_BACKEND_HOST/api/v1
```

End users do not need to create an environment file. Flutter bundles `.env`
into the app, which makes its contents publicly extractable. Only put public
client configuration in this file, restrict the key using Geoapify's supported
controls, and monitor usage. Keep real secrets on the backend.

For web hosting, ensure the deployed server serves `assets/.env`. Some hosts
block dotfiles; if so, rename the local config asset to `config.env`, update
both `pubspec.yaml` and the `dotenv.load` path, and ignore the renamed file.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
