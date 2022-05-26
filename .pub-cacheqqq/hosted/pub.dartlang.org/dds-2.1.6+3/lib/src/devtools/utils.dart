import 'dart:convert';

import 'dart:io';

import 'package:vm_service/utils.dart';
import 'package:vm_service/vm_service.dart';

abstract class DevToolsUtils {
  static void printOutput(
    String? message,
    Object json, {
    required bool machineMode,
  }) {
    final output = machineMode ? jsonEncode(json) : message;
    if (output != null) {
      print(output);
    }
  }

    static Future<VmService?> connectToVmService(Uri theUri) async {
    // Fix up the various acceptable URI formats into a WebSocket URI to connect.
    final uri = convertToWebSocketUrl(serviceProtocolUrl: theUri);

    try {
      final WebSocket ws = await WebSocket.connect(uri.toString());

      final VmService service = VmService(
        ws.asBroadcastStream(),
        (String message) => ws.add(message),
      );

      return service;
    } catch (_) {
      print('ERROR: Unable to connect to VMService $theUri');
      return null;
    }
  }
}
