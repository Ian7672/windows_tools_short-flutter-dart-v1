import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart' as win32;

import '../models/tool_definition.dart';

const int _serviceNoChange = 0xFFFFFFFF;
const int _serviceQueryConfig = 0x0001;
const int _serviceChangeConfig = 0x0002;
const int _servicePauseContinue = 0x0040;
const int _serviceInterrogate = 0x0080;

final DynamicLibrary _advapi32 = DynamicLibrary.open('advapi32.dll');

typedef _ChangeServiceConfigNative = Int32 Function(
  IntPtr hService,
  Uint32 dwServiceType,
  Uint32 dwStartType,
  Uint32 dwErrorControl,
  Pointer<Utf16> lpBinaryPathName,
  Pointer<Utf16> lpLoadOrderGroup,
  Pointer<Uint32> lpdwTagId,
  Pointer<Utf16> lpDependencies,
  Pointer<Utf16> lpServiceStartName,
  Pointer<Utf16> lpPassword,
  Pointer<Utf16> lpDisplayName,
);
typedef _ChangeServiceConfigDart = int Function(
  int hService,
  int dwServiceType,
  int dwStartType,
  int dwErrorControl,
  Pointer<Utf16> lpBinaryPathName,
  Pointer<Utf16> lpLoadOrderGroup,
  Pointer<Uint32> lpdwTagId,
  Pointer<Utf16> lpDependencies,
  Pointer<Utf16> lpServiceStartName,
  Pointer<Utf16> lpPassword,
  Pointer<Utf16> lpDisplayName,
);

final _ChangeServiceConfigDart _changeServiceConfig = _advapi32
    .lookupFunction<_ChangeServiceConfigNative, _ChangeServiceConfigDart>(
  'ChangeServiceConfigW',
);

class ServiceSnapshot {
  ServiceSnapshot({
    required this.name,
    required this.startType,
    required this.state,
  });

  final String name;
  final ServiceStartType startType;
  final int state;

  Map<String, dynamic> toJson() => {
        'name': name,
        'startType': startType.name,
        'state': state,
      };
}

class ServiceInfo {
  ServiceInfo({required this.name, required this.displayName});

  final String name;
  final String displayName;
}

class ServiceOperationResult {
  ServiceOperationResult(this.success, this.message, this.errorCode);

  final bool success;
  final String message;
  final int errorCode;
}

class WindowsServiceController {
  const WindowsServiceController();

  Future<List<ServiceInfo>> findServicesByPattern({
    String namePrefix = '',
    String nameContains = '',
    String displayContains = '',
  }) async {
    final matches = <ServiceInfo>[];
    final scm = win32.OpenSCManager(
      nullptr,
      nullptr,
      win32.SC_MANAGER_ENUMERATE_SERVICE,
    );
    if (scm == 0) {
      return matches;
    }
    final bytesNeeded = calloc<Uint32>();
    final servicesReturned = calloc<Uint32>();
    final resumeHandle = calloc<Uint32>();
    const serviceType = win32.SERVICE_WIN32;
    const serviceState = win32.SERVICE_STATE_ALL;

    try {
      win32.EnumServicesStatusEx(
        scm,
        win32.SC_STATUS_PROCESS_INFO,
        serviceType,
        serviceState,
        nullptr,
        0,
        bytesNeeded,
        servicesReturned,
        resumeHandle,
        nullptr,
      );
      if (bytesNeeded.value == 0) {
        return matches;
      }
      final buffer = calloc<Uint8>(bytesNeeded.value);
      resumeHandle.value = 0;
      final success = win32.EnumServicesStatusEx(
        scm,
        win32.SC_STATUS_PROCESS_INFO,
        serviceType,
        serviceState,
        buffer,
        bytesNeeded.value,
        bytesNeeded,
        servicesReturned,
        resumeHandle,
        nullptr,
      );
      if (success == 0) {
        calloc.free(buffer);
        return matches;
      }
      final servicesPtr =
          buffer.cast<win32.ENUM_SERVICE_STATUS_PROCESS>();
      final count = servicesReturned.value;
      final prefix = namePrefix.toLowerCase();
      final nameNeedle = nameContains.toLowerCase();
      final displayNeedle = displayContains.toLowerCase();
      for (var i = 0; i < count; i++) {
        final entry = servicesPtr[i];
        final name = entry.lpServiceName.toDartString();
        final display = entry.lpDisplayName.toDartString();
        final lowerName = name.toLowerCase();
        final lowerDisplay = display.toLowerCase();
        var match = false;
        if (prefix.isNotEmpty && lowerName.startsWith(prefix)) {
          match = true;
        }
        if (!match &&
            nameNeedle.isNotEmpty &&
            lowerName.contains(nameNeedle)) {
          match = true;
        }
        if (displayNeedle.isNotEmpty &&
            lowerDisplay.contains(displayNeedle)) {
          match = true;
        }
        if (match) {
          matches.add(ServiceInfo(name: name, displayName: display));
        }
      }
      calloc.free(buffer);
      return matches;
    } finally {
      calloc.free(bytesNeeded);
      calloc.free(servicesReturned);
      calloc.free(resumeHandle);
      win32.CloseServiceHandle(scm);
    }
  }

  int _toStartType(ServiceStartType type) {
    if (type == ServiceStartType.disabled) {
      return win32.SERVICE_DISABLED;
    }
    if (type == ServiceStartType.manual) {
      return win32.SERVICE_DEMAND_START;
    }
    return win32.SERVICE_AUTO_START;
  }

  ServiceStartType _fromStartType(int value) {
    switch (value) {
      case win32.SERVICE_DISABLED:
        return ServiceStartType.disabled;
      case win32.SERVICE_DEMAND_START:
        return ServiceStartType.manual;
      case win32.SERVICE_AUTO_START:
        return ServiceStartType.automatic;
      default:
        return ServiceStartType.automatic;
    }
  }

  Future<ServiceSnapshot?> snapshot(String serviceName) async {
    final handle = _openService(serviceName);
    if (handle == null) return null;

    try {
      final bytesNeeded = calloc<Uint32>();
      win32.QueryServiceConfig(handle, nullptr, 0, bytesNeeded);
      final buffer = calloc<Uint8>(bytesNeeded.value);
      final config = buffer.cast<win32.QUERY_SERVICE_CONFIG>();
      final result = win32.QueryServiceConfig(
        handle,
        config,
        bytesNeeded.value,
        bytesNeeded,
      );
      if (result == 0) {
        calloc.free(bytesNeeded);
        calloc.free(buffer);
        return null;
      }
      final statusInfo = calloc<win32.SERVICE_STATUS_PROCESS>();
      final needed = calloc<Uint32>();
      win32.QueryServiceStatusEx(
        handle,
        win32.SC_STATUS_PROCESS_INFO,
        statusInfo.cast(),
        sizeOf<win32.SERVICE_STATUS_PROCESS>(),
        needed,
      );
      final snapshot = ServiceSnapshot(
        name: serviceName,
        startType: _fromStartType(config.ref.dwStartType),
        state: statusInfo.ref.dwCurrentState,
      );
      calloc.free(bytesNeeded);
      calloc.free(buffer);
      calloc.free(statusInfo);
      calloc.free(needed);
      return snapshot;
    } finally {
      win32.CloseServiceHandle(handle);
    }
  }

  Future<ServiceOperationResult> applyAction(ServiceAction action) async {
    final handle = _openService(action.serviceName);
    if (handle == null) {
      final error = win32.GetLastError();
      if (error == win32.ERROR_SERVICE_DOES_NOT_EXIST) {
        return ServiceOperationResult(
          true,
          '${action.serviceName} not found (skipped).',
          0,
        );
      }
      return ServiceOperationResult(
        false,
        'Failed to open ${action.serviceName}',
        error,
      );
    }

    try {
      if (action.targetStartType != null) {
        final type = _toStartType(action.targetStartType!);
        final result = _changeServiceConfig(
          handle,
          _serviceNoChange,
          type,
          _serviceNoChange,
          nullptr,
          nullptr,
          nullptr.cast<Uint32>(),
          nullptr,
          nullptr,
          nullptr,
          nullptr,
        );
        if (result == 0) {
          final error = win32.GetLastError();
          return ServiceOperationResult(
            false,
            'Failed to set start type: $error',
            error,
          );
        }
      }

      if (action.stopService) {
        final stopResult = _controlService(handle, win32.SERVICE_CONTROL_STOP);
        if (!stopResult.success) {
          return stopResult;
        }
      }

      if (action.startService) {
        final startResult = _startService(handle);
        if (!startResult.success) {
          return startResult;
        }
      }

      return ServiceOperationResult(true, 'Service updated', 0);
    } finally {
      win32.CloseServiceHandle(handle);
    }
  }

  Future<ServiceOperationResult> restore(ServiceSnapshot snapshot) async {
    final handle = _openService(snapshot.name);
    if (handle == null) {
      final error = win32.GetLastError();
      if (error == win32.ERROR_SERVICE_DOES_NOT_EXIST) {
        return ServiceOperationResult(
          true,
          '${snapshot.name} missing, nothing to restore.',
          0,
        );
      }
      return ServiceOperationResult(false, 'Failed to open ${snapshot.name}', error);
    }
    try {
      final result = _changeServiceConfig(
        handle,
        _serviceNoChange,
        _toStartType(snapshot.startType),
        _serviceNoChange,
        nullptr,
        nullptr,
        nullptr.cast<Uint32>(),
        nullptr,
        nullptr,
        nullptr,
        nullptr,
      );
      if (result == 0) {
        final error = win32.GetLastError();
        return ServiceOperationResult(
          false,
          'Failed to restore start type: $error',
          error,
        );
      }

      if (snapshot.state == win32.SERVICE_RUNNING) {
        final start = _startService(handle);
        if (!start.success) {
          return start;
        }
      } else if (snapshot.state == win32.SERVICE_STOPPED) {
        final stop = _controlService(handle, win32.SERVICE_CONTROL_STOP);
        if (!stop.success) {
          return stop;
        }
      }

      return ServiceOperationResult(true, 'Service restored', 0);
    } finally {
      win32.CloseServiceHandle(handle);
    }
  }

  int? _openService(String serviceName) {
    final accessMask = win32.SERVICE_QUERY_STATUS |
        _serviceQueryConfig |
        _serviceChangeConfig |
        win32.SERVICE_START |
        win32.SERVICE_STOP |
        _servicePauseContinue |
        _serviceInterrogate |
        win32.SERVICE_ENUMERATE_DEPENDENTS;
    final scm = win32.OpenSCManager(
      nullptr,
      nullptr,
      win32.SC_MANAGER_ALL_ACCESS,
    );
    if (scm == 0) {
      return null;
    }
    final servicePtr = win32.TEXT(serviceName);
    final handle = win32.OpenService(
      scm,
      servicePtr,
      accessMask,
    );
    calloc.free(servicePtr);
    win32.CloseServiceHandle(scm);
    if (handle == 0) {
      return null;
    }
    return handle;
  }

  ServiceOperationResult _controlService(int handle, int control) {
    final status = calloc<win32.SERVICE_STATUS>();
    final result = win32.ControlService(handle, control, status);
    if (result == 0) {
      final error = win32.GetLastError();
      calloc.free(status);
      final alreadyStopped = error == win32.ERROR_SERVICE_NOT_ACTIVE;
      if (error == 0) {
        // ControlService occasionally reports failure with ERROR_SUCCESS.
        return ServiceOperationResult(true, 'Service control applied', 0);
      }
      if (control == win32.SERVICE_CONTROL_STOP && alreadyStopped) {
        return ServiceOperationResult(true, 'Service already stopped', 0);
      }
      return ServiceOperationResult(false, 'Control service failed: $error', error);
    }
    calloc.free(status);
    return ServiceOperationResult(true, 'Service control applied', 0);
  }

  ServiceOperationResult _startService(int handle) {
    final result = win32.StartService(handle, 0, nullptr);
    if (result == 0) {
      final error = win32.GetLastError();
      if (error == win32.ERROR_SERVICE_ALREADY_RUNNING) {
        return ServiceOperationResult(true, 'Service already running', 0);
      }
      return ServiceOperationResult(false, 'Failed to start service: $error', error);
    }
    return ServiceOperationResult(true, 'Service started', 0);
  }
}
