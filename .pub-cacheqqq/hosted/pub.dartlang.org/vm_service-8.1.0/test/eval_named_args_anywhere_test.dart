// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:developer';
import 'package:test/test.dart';
import 'package:vm_service/vm_service.dart';
import 'common/service_test_common.dart';
import 'common/test_helper.dart';

int foo(int a, {required int b}) {
  return a - b;
}

class _MyClass {
  int foo(int a, {required int b}) {
    return a - b;
  }
}

void testFunction() {
  debugger();
/*  int i = 0;
  while (true) {
    if (++i % 100000000 == 0) {
      (_MyClass()).foo();
    }
  }*/
}

final tests = <IsolateTest>[
  hasStoppedAtBreakpoint,
  (VmService service, IsolateRef isolateRef) async {
    final isolateId = isolateRef.id!;
    final isolate = await service.getIsolate(isolateId);

    final rootLib =
        await service.getObject(isolateId, isolate.rootLib!.id!) as Library;
    print(rootLib.functions);
    final InstanceRef result = await service.evaluate(
        isolateId, rootLib.id!, "foo(b: 10, 50)") as InstanceRef;
    print(result);
    expect(result.valueAsString, "40");
  }
];

expectError(func) async {
  bool gotException = false;
  dynamic result;
  try {
    result = await func();
    fail('Failed to throw');
  } on RPCError catch (e) {
    expect(e.code, 113); // Compile time error.
    gotException = true;
  }
  if (result?.type != 'Error') {
    expect(gotException, true); // dart2 semantics
  }
}

main([args = const <String>[]]) => runIsolateTests(
      args,
      tests,
      'eval_named_args_anywhere_test.dart',
      testeeConcurrent: testFunction,
      experiments: ['named-arguments-anywhere'],
    );
