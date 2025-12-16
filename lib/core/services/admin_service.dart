import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart' as win32;

class AdminService {
  const AdminService();

  bool isRunningAsAdmin() {
    final tokenHandle = calloc<IntPtr>();
    try {
      final opened = win32.OpenProcessToken(
        win32.GetCurrentProcess(),
        win32.TOKEN_QUERY,
        tokenHandle,
      );
      if (opened == 0) {
        return false;
      }
      final elevation = calloc<_TokenElevation>();
      final returnLength = calloc<Uint32>();
      final success = win32.GetTokenInformation(
        tokenHandle.value,
        win32.TokenElevation,
        elevation.cast(),
        sizeOf<_TokenElevation>(),
        returnLength,
      );
      win32.CloseHandle(tokenHandle.value);
      final isElevated = success != 0 && elevation.ref.tokenIsElevated != 0;
      calloc.free(elevation);
      calloc.free(returnLength);
      return isElevated;
    } finally {
      calloc.free(tokenHandle);
    }
  }

  Future<bool> restartAsAdministrator() async {
    final executable = Platform.resolvedExecutable;
    final arguments = Platform.executableArguments.join(' ');

    final exePtr = win32.TEXT(executable);
    final argsPtr = arguments.isEmpty ? nullptr : win32.TEXT(arguments);
    final opPtr = win32.TEXT('runas');

    final result = win32.ShellExecute(
      win32.NULL,
      opPtr,
      exePtr,
      argsPtr,
      nullptr,
      win32.SW_SHOWNORMAL,
    );

    calloc.free(exePtr);
    if (argsPtr != nullptr) {
      calloc.free(argsPtr);
    }
    calloc.free(opPtr);

    return result > 32;
  }
}

base class _TokenElevation extends Struct {
  @Uint32()
  external int tokenIsElevated;
}
