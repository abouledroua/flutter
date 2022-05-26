// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';
import 'common/test_helper.dart';

void main() {
  late Process process;

  setUp(() async {
    process = await spawnDartProcess(
      'get_cached_cpu_samples_script.dart',
    );
  });

  tearDown(() {
    process.kill();
  });

  test(
    'Cache CPU samples for provided UserTag name',
    () async {
      final service = await vmServiceConnectUri(remoteVmServiceUri.toString());
      final otherService = await vmServiceConnectUri(remoteVmServiceUri.toString());

      IsolateRef isolate;
      while (true) {
        final vm = await service.getVM();
        if (vm.isolates!.isNotEmpty) {
          isolate = vm.isolates!.first;
          try {
            isolate = await service.getIsolate(isolate.id!);
            if ((isolate as Isolate).runnable!) {
              break;
            }
          } on SentinelException {
            // ignore
          }
        }
        await Future.delayed(const Duration(seconds: 1));
      }
      expect(isolate, isNotNull);

      final expectedUserTags = <String>{};

      Future<void> listenForSamples() {
        late StreamSubscription sub;
        final completer = Completer<void>();
        int i = 0;
        sub = service.onProfilerEvent.listen(
          (event) async {
            if (event.kind == EventKind.kCpuSamples &&
                event.isolate!.id! == isolate.id!) {
              expect(expectedUserTags.isNotEmpty, true);
              ++i;
              if (i > 3) {
                if (!completer.isCompleted) {
                  await sub.cancel();
                  completer.complete();
                }
                return;
              }
              expect(event.cpuSamples, isNotNull);
              final sampleCount = event.cpuSamples!.samples!
                  .where((e) => expectedUserTags.contains(e.userTag))
                  .length;
              expect(sampleCount, event.cpuSamples!.samples!.length);
            }
          },
        );
        if (expectedUserTags.isEmpty) {
          return Future.delayed(const Duration(seconds: 2)).then(
            (_) async => await sub.cancel(),
          );
        }
        return completer.future;
      }

      await service.streamListen(EventStreams.kProfiler);
      Future<void> subscription = listenForSamples();
      await service.resume(isolate.id!);
      await subscription;
      await service.pause(isolate.id!);

      expectedUserTags.add('Testing');
      await service.streamCpuSamplesWithUserTag(expectedUserTags.toList());
      subscription = listenForSamples();
      await service.resume(isolate.id!);
      await subscription;
      await service.pause(isolate.id!);

      expectedUserTags.add('Baz');
      await service.streamCpuSamplesWithUserTag(expectedUserTags.toList());
      subscription = listenForSamples();
      await service.resume(isolate.id!);
      await subscription;
      await service.pause(isolate.id!);

      expectedUserTags.clear();
      await service.streamCpuSamplesWithUserTag(expectedUserTags.toList());
      subscription = listenForSamples();
      await service.resume(isolate.id!);
      await subscription;
      await service.pause(isolate.id!);
    },
    timeout: Timeout.none,
  );
}
