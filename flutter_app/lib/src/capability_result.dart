enum CapabilityState {
  fresh,
  stale,
  empty,
  unavailable,
  permissionDenied,
  authenticationRequired,
  failed,
}

enum CapabilityPrivacy { publicExternal, privateLocal }

enum CapabilityEffect { readOnly, userApproved }

class CapabilityPolicy {
  const CapabilityPolicy({required this.privacy, required this.effect});

  static const publicRead = CapabilityPolicy(
    privacy: CapabilityPrivacy.publicExternal,
    effect: CapabilityEffect.readOnly,
  );

  static const privateRead = CapabilityPolicy(
    privacy: CapabilityPrivacy.privateLocal,
    effect: CapabilityEffect.readOnly,
  );

  final CapabilityPrivacy privacy;
  final CapabilityEffect effect;

  Map<String, Object?> toJson() => <String, Object?>{
    'privacy': _snakeCase(privacy.name),
    'effect': _snakeCase(effect.name),
  };
}

class CapabilityFailure {
  const CapabilityFailure({required this.source, required this.message});

  final String source;
  final String message;

  Map<String, Object?> toJson() => <String, Object?>{
    'source': source,
    'message': message,
  };
}

class CapabilitySource {
  const CapabilitySource({
    required this.id,
    required this.label,
    required this.url,
    this.reliability = 'live',
  });

  final String id;
  final String label;
  final String url;
  final String reliability;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'label': label,
    'url': url,
    'reliability': reliability,
  };
}

class CapabilityResult<T> {
  const CapabilityResult({
    required this.state,
    required this.policy,
    required this.source,
    required this.fetchedAt,
    this.expiresAt,
    this.data,
    this.message,
    this.failures = const <CapabilityFailure>[],
  });

  final CapabilityState state;
  final CapabilityPolicy policy;
  final CapabilitySource source;
  final DateTime fetchedAt;
  final DateTime? expiresAt;
  final T? data;
  final String? message;
  final List<CapabilityFailure> failures;

  Map<String, Object?> toJson(
    Object? Function(T value) encodeData,
  ) => <String, Object?>{
    'state': state.name,
    'policy': policy.toJson(),
    'source': source.toJson(),
    'fetched_at': fetchedAt.toUtc().toIso8601String(),
    if (expiresAt != null) 'expires_at': expiresAt!.toUtc().toIso8601String(),
    if (data != null) 'data': encodeData(data as T),
    if (message != null) 'message': message,
    if (failures.isNotEmpty)
      'failures': failures.map((failure) => failure.toJson()).toList(),
  };
}

String boundedCapabilityMessage(Object error, {int maxLength = 240}) {
  final text = error
      .toString()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceAllMapped(
        RegExp(
          r'(password|authorization|cookie|token|api[_-]?key|secret)=[^\s]+',
          caseSensitive: false,
        ),
        (match) => '${match.group(1)}=[redacted]',
      )
      .replaceAllMapped(
        RegExp(r'Bearer\s+[^\s]+', caseSensitive: false),
        (_) => 'Bearer [redacted]',
      );
  if (text.isEmpty) return 'The live data source failed.';
  return text.length <= maxLength ? text : '${text.substring(0, maxLength)}…';
}

String _snakeCase(String value) => value.replaceAllMapped(
  RegExp(r'([a-z0-9])([A-Z])'),
  (match) => '${match.group(1)}_${match.group(2)!.toLowerCase()}',
);
