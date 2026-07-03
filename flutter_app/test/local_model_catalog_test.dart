import 'package:flutter_test/flutter_test.dart';
import 'package:studyos_agent/src/local_model_catalog.dart';

void main() {
  test('default local model catalog uses downloadable verified entries', () {
    final defaults = localModelCatalog.where((model) => model.id != 'custom');

    expect(defaults, isNotEmpty);
    expect(defaults.every((model) => model.downloadUrl.startsWith('https://')), isTrue);
    expect(defaults.every((model) => model.hasIntegrityCheck), isTrue);
    expect(
      localModelCatalog.map((model) => model.id),
      isNot(contains('lfm2-5-1-2b')),
    );
  });
}
