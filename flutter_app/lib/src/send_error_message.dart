import 'package:flutter/services.dart';

import 'agent_exception.dart';

String? sendErrorMessage(Object error) {
  return switch (error) {
    AgentException(:final message) => message,
    MissingPluginException() =>
      'This device cannot use the built-in assistant yet.',
    PlatformException(:final message) =>
      message ?? 'The assistant could not complete this request.',
    FormatException() => 'Cloud response could not be read.',
    _ => null,
  };
}
