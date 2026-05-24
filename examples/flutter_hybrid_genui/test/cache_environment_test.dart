import 'package:flutter_hybrid_genui/src/runtime/cache_environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('non-empty overrides replace environment values', () {
    final environment = environmentWithOverrides(
      const <String, String>{
        'GENUI_AI_ROUTE': 'local',
        'LLAMADART_GENUI_MODEL_SOURCE': '/old/model.gguf',
      },
      const <String, String>{
        'GENUI_AI_ROUTE': 'backend',
        'LLAMADART_GENUI_MODEL_SOURCE': '/new/model.gguf',
      },
    );

    expect(environment['GENUI_AI_ROUTE'], 'backend');
    expect(environment['LLAMADART_GENUI_MODEL_SOURCE'], '/new/model.gguf');
  });

  test('empty overrides are ignored', () {
    final environment = environmentWithOverrides(
      const <String, String>{'GENUI_AI_ROUTE': 'local'},
      const <String, String>{'GENUI_AI_ROUTE': ''},
    );

    expect(environment['GENUI_AI_ROUTE'], 'local');
  });

  test('mobile environment gets persistent app support cache directory', () {
    final environment = environmentWithAppSupportModelCache(
      const <String, String>{},
      applicationSupportPath: '/data/user/0/app/files',
      isMobile: true,
    );

    expect(
      environment['LLAMADART_GENUI_CACHE_DIR'],
      '/data/user/0/app/files/llamadart/genui',
    );
  });

  test('explicit cache directory is preserved', () {
    final environment = environmentWithAppSupportModelCache(
      const <String, String>{'LLAMADART_GENUI_CACHE_DIR': '/models/cache'},
      applicationSupportPath: '/data/user/0/app/files',
      isMobile: true,
    );

    expect(environment['LLAMADART_GENUI_CACHE_DIR'], '/models/cache');
  });

  test('desktop environment is not changed', () {
    final environment = environmentWithAppSupportModelCache(
      const <String, String>{'HOME': '/Users/test'},
      applicationSupportPath: '/Users/test/Library/Application Support/app',
      isMobile: false,
    );

    expect(environment, const <String, String>{'HOME': '/Users/test'});
  });
}
