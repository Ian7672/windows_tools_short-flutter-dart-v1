import 'package:win32/win32.dart';
import 'package:win32_registry/win32_registry.dart';

import '../models/tool_definition.dart';

class RegistrySnapshot {
  RegistrySnapshot({
    required this.hive,
    required this.path,
    required this.valueName,
    required this.exists,
    required this.value,
  });

  final String hive;
  final String path;
  final String valueName;
  final bool exists;
  final Object? value;

  Map<String, dynamic> toJson() => {
        'hive': hive,
        'path': path,
        'valueName': valueName,
        'exists': exists,
        'value': value,
      };
}

class RegistryOperationResult {
  RegistryOperationResult(this.success, this.message);

  final bool success;
  final String message;
}

class RegistryService {
  const RegistryService();

  RegistryHive? _mapHive(String hive) {
    switch (hive.toUpperCase()) {
      case 'HKCU':
        return RegistryHive.currentUser;
      case 'HKLM':
        return RegistryHive.localMachine;
      default:
        return null;
    }
  }

  RegistryKey? _openForRead(RegistryAction action) {
    final hive = _mapHive(action.hive);
    if (hive == null) return null;
    try {
      return Registry.openPath(
        hive,
        path: action.path,
        desiredAccessRights: AccessRights.readOnly,
      );
    } on WindowsException {
      return null;
    }
  }

  RegistryKey? _openForWrite(String hive, String path) {
    final mapped = _mapHive(hive);
    if (mapped == null) return null;
    try {
      return Registry.openPath(
        mapped,
        path: path,
        desiredAccessRights: AccessRights.allAccess,
      );
    } on WindowsException {
      try {
        final root = Registry.openPath(
          mapped,
          path: '',
          desiredAccessRights: AccessRights.allAccess,
        );
        final created = root.createKey(path);
        root.close();
        return created;
      } on WindowsException {
        return null;
      }
    }
  }

  Future<RegistrySnapshot?> snapshot(RegistryAction action) async {
    final key = _openForRead(action);
    if (key == null) {
      return RegistrySnapshot(
        hive: action.hive,
        path: action.path,
        valueName: action.valueName,
        exists: false,
        value: null,
      );
    }
    try {
      final value = key.getValue(action.valueName);
      return RegistrySnapshot(
        hive: action.hive,
        path: action.path,
        valueName: action.valueName,
        exists: value != null,
        value: value?.data,
      );
    } finally {
      key.close();
    }
  }

  Future<RegistryOperationResult> apply(RegistryAction action) async {
    final key = _openForWrite(action.hive, action.path);
    if (key == null) {
      return RegistryOperationResult(false, 'Cannot open ${action.path}');
    }
    try {
      if (action.deleteValue) {
        try {
          key.deleteValue(action.valueName);
          return RegistryOperationResult(true, 'Deleted ${action.valueName}');
        } on WindowsException catch (e) {
          if (e.hr == HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND)) {
            return RegistryOperationResult(true, 'Value already absent.');
          }
          return RegistryOperationResult(false, 'Delete failed: $e');
        }
      }
      switch (action.valueKind) {
        case RegistryValueKind.dword:
          key.createValue(
            RegistryValue(
              action.valueName,
              RegistryValueType.int32,
              int.tryParse(action.data ?? '0') ?? 0,
            ),
          );
          break;
        case RegistryValueKind.qword:
          key.createValue(
            RegistryValue(
              action.valueName,
              RegistryValueType.int64,
              int.tryParse(action.data ?? '0') ?? 0,
            ),
          );
          break;
        case RegistryValueKind.string:
          key.createValue(
            RegistryValue(
              action.valueName,
              RegistryValueType.string,
              action.data ?? '',
            ),
          );
          break;
      }
      return RegistryOperationResult(true, 'Value updated');
    } catch (e) {
      return RegistryOperationResult(false, 'Write failed: $e');
    } finally {
      key.close();
    }
  }

  Future<RegistryOperationResult> restore(RegistrySnapshot snapshot) async {
    final key = _openForWrite(snapshot.hive, snapshot.path);
    if (key == null) {
      return RegistryOperationResult(false, 'Cannot open ${snapshot.path}');
    }
    try {
      if (!snapshot.exists) {
        try {
          key.deleteValue(snapshot.valueName);
          return RegistryOperationResult(true, 'Value removed');
        } on WindowsException catch (e) {
          if (e.hr == HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND)) {
            return RegistryOperationResult(true, 'Value already absent.');
          }
          return RegistryOperationResult(false, 'Remove failed: $e');
        }
      }
      final value = snapshot.value;
      if (value is int) {
        key.createValue(
          RegistryValue(
            snapshot.valueName,
            RegistryValueType.int32,
            value,
          ),
        );
      } else if (value is String) {
        key.createValue(
          RegistryValue(
            snapshot.valueName,
            RegistryValueType.string,
            value,
          ),
        );
      } else if (value is List<int>) {
        key.createValue(
          RegistryValue(
            snapshot.valueName,
            RegistryValueType.binary,
            value,
          ),
        );
      } else {
        key.deleteValue(snapshot.valueName);
      }
      return RegistryOperationResult(true, 'Value restored');
    } catch (e) {
      return RegistryOperationResult(false, 'Restore failed: $e');
    } finally {
      key.close();
    }
  }
}
