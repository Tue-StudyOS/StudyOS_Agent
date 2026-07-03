import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/local_model_catalog.dart';

void main() {
  test('default local model catalog uses downloadable entries', () {
    final defaults = localModelCatalog.where((model) => model.id != 'custom');

    expect(defaults, isNotEmpty);
    expect(
      defaults.every((model) => model.downloadUrl.startsWith('https://')),
      isTrue,
    );
    // lfm2.5 has no available LiteRT checkpoint, so it must stay out of defaults.
    expect(
      localModelCatalog.map((model) => model.id),
      isNot(contains('lfm2-5-1-2b')),
    );
    expect(
      defaults.every((model) => model.fileName.endsWith('.litertlm')),
      isTrue,
    );
  });
}
