// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:devtools_shared/devtools_server.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:vm_service/vm_service.dart';

import '../../devtools_server.dart';
import 'utils.dart';

class MachineModeCommandHandler {
  static const launchDevToolsService = 'launchDevTools';
  static const errorLaunchingBrowserCode = 500;
  static const bool machineMode = true;

  MachineModeCommandHandler({required this.server});
  DevToolsServer server;

  Future<void> initialize({
    required String devToolsUrl,
    required bool headlessMode,
  }) async {
    final Stream<Map<String, dynamic>> _stdinCommandStream = stdin
        .transform<String>(utf8.decoder)
        .transform<String>(const LineSplitter())
        .where((String line) => line.startsWith('{') && line.endsWith('}'))
        .map<Map<String, dynamic>>((String line) {
      return json.decode(line) as Map<String, dynamic>;
    });

    // Example input:
    // {
    //   "id":0,
    //   "method":"vm.register",
    //   "params":{
    //     "uri":"<vm-service-uri-here>",
    //   }
    // }
    _stdinCommandStream.listen((Map<String, dynamic> json) async {
      // ID can be String, int or null
      final dynamic id = json['id'];
      final Map<String, dynamic> params = json['params'];
      switch (json['method']) {
        case 'vm.register':
          await _handleVmRegister(
            id,
            params,
            headlessMode,
            devToolsUrl,
          );
          break;
        case 'devTools.launch':
          await _handleDevToolsLaunch(
            id,
            params,
            headlessMode,
            devToolsUrl,
          );
          break;
        case 'client.list':
          await _handleClientsList(id, params);
          break;
        case 'devTools.survey':
          _devToolsUsage ??= DevToolsUsage();
          final String surveyRequest = params['surveyRequest'];
          final String value = params['value'];
          switch (surveyRequest) {
            case 'copyAndCreateDevToolsFile':
              // Backup and delete ~/.devtools file.
              if (backupAndCreateDevToolsStore()) {
                _devToolsUsage = null;
                DevToolsUtils.printOutput(
                  'DevTools Survey',
                  {
                    'id': id,
                    'result': {
                      'sucess': true,
                    },
                  },
                  machineMode: machineMode,
                );
              }
              break;
            case 'restoreDevToolsFile':
              _devToolsUsage = null;
              final content = restoreDevToolsStore();
              if (content != null) {
                DevToolsUtils.printOutput(
                  'DevTools Survey',
                  {
                    'id': id,
                    'result': {
                      'sucess': true,
                      'content': content,
                    },
                  },
                  machineMode: machineMode,
                );

                _devToolsUsage = null;
              }
              break;
            case apiSetActiveSurvey:
              _devToolsUsage!.activeSurvey = value;
              DevToolsUtils.printOutput(
                'DevTools Survey',
                {
                  'id': id,
                  'result': {
                    'sucess': _devToolsUsage!.activeSurvey == value,
                    'activeSurvey': _devToolsUsage!.activeSurvey,
                  },
                },
                machineMode: machineMode,
              );
              break;
            case apiGetSurveyActionTaken:
              DevToolsUtils.printOutput(
                'DevTools Survey',
                {
                  'id': id,
                  'result': {
                    'activeSurvey': _devToolsUsage!.activeSurvey,
                    'surveyActionTaken': _devToolsUsage!.surveyActionTaken,
                  },
                },
                machineMode: machineMode,
              );
              break;
            case apiSetSurveyActionTaken:
              _devToolsUsage!.surveyActionTaken = jsonDecode(value);
              DevToolsUtils.printOutput(
                'DevTools Survey',
                {
                  'id': id,
                  'result': {
                    'activeSurvey': _devToolsUsage!.activeSurvey,
                    'surveyActionTaken': _devToolsUsage!.surveyActionTaken,
                  },
                },
                machineMode: machineMode,
              );
              break;
            case apiGetSurveyShownCount:
              DevToolsUtils.printOutput(
                'DevTools Survey',
                {
                  'id': id,
                  'result': {
                    'activeSurvey': _devToolsUsage!.activeSurvey,
                    'surveyShownCount': _devToolsUsage!.surveyShownCount,
                  },
                },
                machineMode: machineMode,
              );
              break;
            case apiIncrementSurveyShownCount:
              _devToolsUsage!.incrementSurveyShownCount();
              DevToolsUtils.printOutput(
                'DevTools Survey',
                {
                  'id': id,
                  'result': {
                    'activeSurvey': _devToolsUsage!.activeSurvey,
                    'surveyShownCount': _devToolsUsage!.surveyShownCount,
                  },
                },
                machineMode: machineMode,
              );
              break;
            default:
              DevToolsUtils.printOutput(
                'Unknown DevTools Survey Request $surveyRequest',
                {
                  'id': id,
                  'result': {
                    'activeSurvey': _devToolsUsage!.activeSurvey,
                    'surveyActionTaken': _devToolsUsage!.surveyActionTaken,
                    'surveyShownCount': _devToolsUsage!.surveyShownCount,
                  },
                },
                machineMode: machineMode,
              );
          }
          break;
        default:
          DevToolsUtils.printOutput(
            'Unknown method ${json['method']}',
            {
              'id': id,
              'error': 'Unknown method ${json['method']}',
            },
            machineMode: machineMode,
          );
      }
    });
  }

  Future<void> _handleVmRegister(
    dynamic id,
    Map<String, dynamic> params,
    bool headlessMode,
    String devToolsUrl,
  ) async {
    if (!params.containsKey('uri')) {
      DevToolsUtils.printOutput(
        'Invalid input: $params does not contain the key \'uri\'',
        {
          'id': id,
          'error': 'Invalid input: $params does not contain the key \'uri\'',
        },
        machineMode: machineMode,
      );
    }

    // params['uri'] should contain a vm service uri.
    final uri = Uri.tryParse(params['uri']);

    if (_isValidVmServiceUri(uri)) {
      await registerLaunchDevToolsService(
        uri!,
        id,
        devToolsUrl,
        headlessMode,
      );
    } else {
      DevToolsUtils.printOutput(
        'Uri must be absolute with a http, https, ws or wss scheme',
        {
          'id': id,
          'error': 'Uri must be absolute with a http, https, ws or wss scheme',
        },
        machineMode: machineMode,
      );
    }
  }

  Future<void> _handleDevToolsLaunch(
    dynamic id,
    Map<String, dynamic> params,
    bool headlessMode,
    String devToolsUrl,
  ) async {
    if (!params.containsKey('vmServiceUri')) {
      DevToolsUtils.printOutput(
        'Invalid input: $params does not contain the key \'vmServiceUri\'',
        {
          'id': id,
          'error':
              'Invalid input: $params does not contain the key \'vmServiceUri\'',
        },
        machineMode: machineMode,
      );
    }

    // params['vmServiceUri'] should contain a vm service uri.
    final vmServiceUri = Uri.tryParse(params['vmServiceUri'])!;

    if (_isValidVmServiceUri(vmServiceUri)) {
      try {
        final result = await server.launchDevTools(
          params,
          vmServiceUri,
          devToolsUrl,
          headlessMode,
          machineMode,
        );
        DevToolsUtils.printOutput(
          'DevTools launched',
          {'id': id, 'result': result},
          machineMode: machineMode,
        );
      } catch (e, s) {
        DevToolsUtils.printOutput(
          'Failed to launch browser: $e\n$s',
          {'id': id, 'error': 'Failed to launch browser: $e\n$s'},
          machineMode: machineMode,
        );
      }
    } else {
      DevToolsUtils.printOutput(
        'VM Service URI must be absolute with a http, https, ws or wss scheme',
        {
          'id': id,
          'error':
              'VM Service Uri must be absolute with a http, https, ws or wss scheme',
        },
        machineMode: machineMode,
      );
    }
  }

  Future<void> _handleClientsList(
      dynamic id, Map<String, dynamic> params) async {
    // TODO(bkonyi): implement
    return;
    /*
  final connectedClients = clients.allClients;
  printOutput(
    connectedClients.map((c) {
      return '${c.hasConnection.toString().padRight(5)} '
          '${c.currentPage?.padRight(12)} ${c.vmServiceUri.toString()}';
    }).join('\n'),
    {
      'id': id,
      'result': {
        'clients': connectedClients
            .map((c) => {
                  'hasConnection': c.hasConnection,
                  'currentPage': c.currentPage,
                  'embedded': c.embedded,
                  'vmServiceUri': c.vmServiceUri?.toString(),
                })
            .toList()
      },
    },
    machineMode: machineMode,
  );  
  */
  }

  // Only used for testing DevToolsUsage (used by survey).
  DevToolsUsage? _devToolsUsage;

  File? _devToolsBackup;

  bool backupAndCreateDevToolsStore() {
    assert(_devToolsBackup == null);
    final devToolsStore = File(LocalFileSystem.devToolsStoreLocation());
    if (devToolsStore.existsSync()) {
      _devToolsBackup = devToolsStore
          .copySync('${LocalFileSystem.devToolsDir()}/.devtools_backup_test');
      devToolsStore.deleteSync();
    }

    return true;
  }

  String? restoreDevToolsStore() {
    if (_devToolsBackup != null) {
      // Read the current ~/.devtools file
      LocalFileSystem.maybeMoveLegacyDevToolsStore();

      final devToolsStore = File(LocalFileSystem.devToolsStoreLocation());
      final content = devToolsStore.readAsStringSync();

      // Delete the temporary ~/.devtools file
      devToolsStore.deleteSync();
      if (_devToolsBackup!.existsSync()) {
        // Restore the backup ~/.devtools file we created in
        // backupAndCreateDevToolsStore.
        _devToolsBackup!.copySync(LocalFileSystem.devToolsStoreLocation());
        _devToolsBackup!.deleteSync();
        _devToolsBackup = null;
      }
      return content;
    }

    return null;
  }

  Future<void> registerLaunchDevToolsService(
    Uri vmServiceUri,
    dynamic id,
    String devToolsUrl,
    bool headlessMode,
  ) async {
    try {
      // Connect to the vm service and register a method to launch DevTools in
      // chrome.
      final VmService? service =
          await DevToolsUtils.connectToVmService(vmServiceUri);
      if (service == null) return;

      service.registerServiceCallback(launchDevToolsService, (params) async {
        try {
          await server.launchDevTools(
            params,
            vmServiceUri,
            devToolsUrl,
            headlessMode,
            machineMode,
          );
          return {'result': Success().toJson()};
        } catch (e, s) {
          // Note: It's critical that we return responses in exactly the right format
          // or the VM will unregister the service. The objects must match JSON-RPC
          // however a successful response must also have a "type" field in its result.
          // Otherwise, we can return an error object (instead of result) that includes
          // code + message.
          return {
            'error': {
              'code': errorLaunchingBrowserCode,
              'message': 'Failed to launch browser: $e\n$s',
            },
          };
        }
      });

      final registerServiceMethodName = 'registerService';
      await service.callMethod(registerServiceMethodName, args: {
        'service': launchDevToolsService,
        'alias': 'DevTools Server',
      });

      DevToolsUtils.printOutput(
        'Successfully registered launchDevTools service',
        {
          'id': id,
          'result': {'success': true},
        },
        machineMode: machineMode,
      );
    } catch (e) {
      DevToolsUtils.printOutput(
        'Unable to connect to VM service at $vmServiceUri: $e',
        {
          'id': id,
          'error': 'Unable to connect to VM service at $vmServiceUri: $e',
        },
        machineMode: machineMode,
      );
    }
  }

  bool _isValidVmServiceUri(Uri? uri) {
    // Lots of things are considered valid URIs (including empty strings and
    // single letters) since they can be relative, so we need to do some extra
    // checks.
    return uri != null &&
        uri.isAbsolute &&
        (uri.isScheme('ws') ||
            uri.isScheme('wss') ||
            uri.isScheme('http') ||
            uri.isScheme('https'));
  }
}
