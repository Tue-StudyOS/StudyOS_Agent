import 'package:flutter/services.dart';

import 'cloud_agent_client.dart';

String? sendErrorMessage(Object error) {
  return switch (error) {
    CloudAgentException(:final message) => message,
    MissingPluginException() =>
      'Native bridge is not implemented on this target.',
    PlatformException(:final message) => 'Native bridge error: $message',
    FormatException() => 'Cloud response could not be read.',
    _ => null,
  };
}
