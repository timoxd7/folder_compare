import 'dart:io';

import 'compare_files.dart';
import 'multi_output_pipe.dart';

class ReportStatus {
  // Output
  final MultiOutputPipe multiOutputPipe;

  // Configuration
  final int reportEverySeconds;

  // State
  final Stopwatch stopwatch = Stopwatch()..start();
  int countFiles = 0;
  int countBytes = 0;

  ReportStatus(this.reportEverySeconds, this.multiOutputPipe);

  void addFile(int bytes) {
    countFiles++;
    countBytes += bytes;

    if (stopwatch.elapsed.inSeconds > reportEverySeconds) {
      final double filesPerSecond =
          countFiles / (stopwatch.elapsed.inMilliseconds / 1000);
      final double bytesPerSecond =
          countBytes / (stopwatch.elapsed.inMilliseconds / 1000);
      final double megabytesPerSecond = bytesPerSecond / (1024 * 1024);

      multiOutputPipe.printOne(
          "$reportEverySeconds: Files/s: ${filesPerSecond.toStringAsFixed(2)} - MB/s: ${megabytesPerSecond.toStringAsFixed(2)}");

      countFiles = 0;
      countBytes = 0;

      stopwatch.reset();
    }
  }
}

Future<bool> compareFolders(final Directory a, final Directory b,
    final ReportStatus reportStatus) async {
  // Prepare the next entries for comparison
  final Future<List<FileSystemEntity>> dirEntriesAFuture = a.list().toList();
  final Future<List<FileSystemEntity>> dirEntriesBFuture = b.list().toList();

  final List<FileSystemEntity> dirEntriesA = await dirEntriesAFuture;
  final List<FileSystemEntity> dirEntriesB = await dirEntriesBFuture;

  // Check count of entries
  if (dirEntriesA.length != dirEntriesB.length) {
    print('Directories have different number of files');
    print('${a.path}: ${dirEntriesA.length}');
    print('${b.path}: ${dirEntriesB.length}');
    return false;
  }

  // Sort both lists by name (as fs might not arrange them in the same order)
  dirEntriesA.sort((a, b) => a.path.compareTo(b.path));
  dirEntriesB.sort((a, b) => a.path.compareTo(b.path));

  for (int i = 0; i < dirEntriesA.length; ++i) {
    // Prepare the next entries for comparison
    final FileSystemEntity entityA = dirEntriesA[i];
    final FileSystemEntity entityB = dirEntriesB[i];

    // Check if the name is equal
    final String nameA = entityA.path.split(Platform.pathSeparator).last;
    final String nameB = entityB.path.split(Platform.pathSeparator).last;

    if (nameA.compareTo(nameB) != 0) {
      print('Different file/folder names');
      print('${entityA.path}: $nameA');
      print('${entityB.path}: $nameB');
      return false;
    }

    // Get stats
    final Future<FileStat> statAFuture = entityA.stat();
    final Future<FileStat> statBFuture = entityB.stat();

    final FileStat statsA = await statAFuture;
    final FileStat statsB = await statBFuture;

    // Compare types
    if (statsA.type != statsB.type) {
      print('Different file types');
      print('${entityA.path}: ${entityA.statSync().type}');
      print('${entityB.path}: ${entityB.statSync().type}');
      return false;
    }

    // Handle based on type
    switch (statsA.type) {
      case FileSystemEntityType.directory:
        // -> Recurse
        if (!await compareFolders(
            Directory(entityA.path), Directory(entityB.path), reportStatus)) {
          return false;
        }

        break;

      case FileSystemEntityType.file:
        // -> Compare files
        if (!await compareFiles(File(entityA.path), File(entityB.path))) {
          print('Files are different');
          print('${entityA.path}: ${entityA.statSync().size}');
          print('${entityB.path}: ${entityB.statSync().size}');
          return false;
        }

        reportStatus.addFile(statsA.size);
        break;

      default:
        reportStatus.multiOutputPipe.printRecurring(
            'Unsupported type: ${statsA.type} -> Will skip for comparison');
    }
  }

  return true;
}
