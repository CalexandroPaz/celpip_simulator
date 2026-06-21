/// Jerarquía de fallos de dominio — sin dependencias de Flutter.
sealed class Failure {
  const Failure(this.message);
  final String message;
}

final class AssetLoadFailure extends Failure {
  const AssetLoadFailure(super.message);
}

final class AudioFailure extends Failure {
  const AudioFailure(super.message);
}

final class RecordingFailure extends Failure {
  const RecordingFailure(super.message);
}

final class PermissionFailure extends Failure {
  const PermissionFailure(super.message);
}

final class RemoteFailure extends Failure {
  const RemoteFailure(super.message);
}

final class SessionFailure extends Failure {
  const SessionFailure(super.message);
}
