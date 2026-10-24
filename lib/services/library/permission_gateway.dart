import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

enum LibraryAccess { granted, denied, permanentlyDenied }

/// Audio-library access, abstracted so UI and controllers are testable.
abstract interface class PermissionGateway {
  Future<LibraryAccess> status();
  Future<LibraryAccess> request();
  Future<void> openSettings();
}

/// Android 13+ (API 33) uses READ_MEDIA_AUDIO; older releases use the legacy
/// storage read permission.
class AndroidPermissionGateway implements PermissionGateway {
  Future<Permission> _permission() async {
    final info = await DeviceInfoPlugin().androidInfo;
    return info.version.sdkInt >= 33 ? Permission.audio : Permission.storage;
  }

  LibraryAccess _map(PermissionStatus s) {
    if (s.isGranted) return LibraryAccess.granted;
    if (s.isPermanentlyDenied) return LibraryAccess.permanentlyDenied;
    return LibraryAccess.denied;
  }

  @override
  Future<LibraryAccess> status() async =>
      _map(await (await _permission()).status);

  @override
  Future<LibraryAccess> request() async =>
      _map(await (await _permission()).request());

  @override
  Future<void> openSettings() async {
    await openAppSettings();
  }
}
