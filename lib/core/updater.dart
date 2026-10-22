import 'package:flutter/foundation.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

/// Shorebird code push. Patches download in the background and apply on the next
/// cold start; this only checks and triggers the download, so it never blocks the UI.
///
/// Outside a `shorebird release` build (flutter run, plain flutter build) the updater
/// reports itself unavailable and every call here is a harmless no-op.
class UpdateService extends ChangeNotifier {
  final ShorebirdUpdater _updater = ShorebirdUpdater();

  bool get available => _updater.isAvailable;
  int? currentPatch;
  bool restartNeeded = false;
  bool checking = false;

  Future<void> checkAndDownload() async {
    if (!available || checking) return;
    checking = true;
    notifyListeners();
    try {
      currentPatch = (await _updater.readCurrentPatch())?.number;
      final status = await _updater.checkForUpdate();
      if (status == UpdateStatus.outdated) {
        await _updater.update();
        restartNeeded = true;
      } else if (status == UpdateStatus.restartRequired) {
        restartNeeded = true;
      }
    } on UpdateException catch (e) {
      debugPrint('Shorebird update failed: $e');
    } finally {
      checking = false;
      notifyListeners();
    }
  }
}
