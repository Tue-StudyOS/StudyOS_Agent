/// A failure the assistant wants to surface to the user with a readable
/// message. Thrown by both the cloud and local agent paths; consumers render
/// [message] directly rather than branching on the provider.
class AgentException implements Exception {
  const AgentException(this.message);

  final String message;

  @override
  String toString() => message;
}
