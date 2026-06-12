import 'package:flutter/services.dart';

import 'cloud_agent_client.dart';

String? sendErrorMessage(Object error) {
  return switch (error) {
    CloudAgentException(:final message) => message,
    MissingPluginException() =>
      'This device cannot use the built-in assistant yet.',
    PlatformException(:final message) =>
      message ?? 'The assistant could not complete this request.',
    FormatException() => 'Cloud response could not be read.',
    _ => null,
  };
}
