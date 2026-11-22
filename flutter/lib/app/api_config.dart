/// Override for a deployed server with:
/// flutter run --dart-define=API_BASE_URL=https://your-domain.com/api/v1
const apiBaseUrl = String.fromEnvironment('API_BASE_URL',
    defaultValue: 'http://192.168.1.4:4000/api/v1');