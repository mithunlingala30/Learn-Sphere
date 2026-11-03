/// Address of the deployed FastAPI backend (Render).
///
/// Override at build/run time, e.g. to test against a local server:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
const String _envBase = String.fromEnvironment('API_BASE_URL');
const String _deployed = 'https://learn-sphere-backend-bygr.onrender.com';

String get apiBaseUrl => _envBase.isNotEmpty ? _envBase : _deployed;
