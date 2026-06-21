/// Configuración del backend FastAPI.
///
/// La URL base se inyecta en tiempo de compilación via --dart-define:
///   flutter run \
///     --dart-define=API_BASE_URL=http://192.168.1.100:8000
///
/// Si no se define, se usa el localhost del emulador Android (10.0.2.2).
/// Para iOS Simulator el equivalente es 127.0.0.1.
///
/// Para activar el cliente real (desactivar el mock):
///   flutter run --dart-define=USE_MOCK_API=false
abstract final class ApiConfig {
  /// URL base del servidor FastAPI, sin barra final.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  /// Endpoint de scoring para Listening, Reading y Writing (JSON).
  static const String scoreEndpoint = '/api/v1/score';

  /// Endpoint exclusivo para Speaking (multipart/form-data con audio).
  static const String speakingScoreEndpoint = '/api/v1/score/speaking';

  /// Timeout para peticiones JSON (scoring automático).
  static const Duration jsonTimeout = Duration(seconds: 15);

  /// Timeout para subida de audio Speaking (archivos de hasta ~2 MB).
  static const Duration uploadTimeout = Duration(seconds: 60);

  /// Si es true, usa ExamRemoteDataSourceMock en vez del cliente HTTP real.
  /// Desactivar con: --dart-define=USE_MOCK_API=false
  static const bool useMockApi = bool.fromEnvironment(
    'USE_MOCK_API',
    defaultValue: true,
  );
}
