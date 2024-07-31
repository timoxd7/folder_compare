import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'limited_queue.dart';

const int chunkSize = 1024 * 1024;
const int queueLength = 100; // -> 100 MB

class CancelToken {
  bool _canceled = false;

  void cancel() {
    _canceled = true;
  }

  bool get isCanceled => _canceled;
}

/// Compares two [Uint8List]s by comparing 8 bytes at a time.
bool memEquals(final Uint8List bytes1, final Uint8List bytes2) {
  if (identical(bytes1, bytes2)) {
    return true;
  }

  if (bytes1.lengthInBytes != bytes2.lengthInBytes) {
    return false;
  }

  // Treat the original byte lists as lists of 8-byte words.
  final int numWords = bytes1.lengthInBytes ~/ 8;
  final Uint64List words1 = bytes1.buffer.asUint64List(0, numWords);
  final Uint64List words2 = bytes2.buffer.asUint64List(0, numWords);

  for (int i = 0; i < words1.length; ++i) {
    if (words1[i] != words2[i]) {
      return false;
    }
  }

  // Compare any remaining bytes.
  for (int i = words1.lengthInBytes; i < bytes1.lengthInBytes; i += 1) {
    if (bytes1[i] != bytes2[i]) {
      return false;
    }
  }

  return true;
}

/// Read a file in chunks and add them to the queue.
Future _readFile(
    final LimitedQueue<Uint8List> queue,
    final RandomAccessFile file,
    final int fileLength,
    final CancelToken cancelToken) async {
  try {
    while (true) {
      final Uint8List chunk = await file.read(chunkSize);

      // Break condition -> cancel token is set
      // Break condition -> empty means file end is reached
      // -> add empty chunk to queue to signal end of stream
      if (chunk.isEmpty || cancelToken.isCanceled) {
        await queue.add(chunk);
        return;
      }

      await queue.add(chunk);
    }
  } catch (e) {
    print(e);
    await queue.add(Uint8List(0));
  }
}

/// Compare two files by comparing them chunk by chunk.
Future<bool> compareFiles(final File a, final File b) async {
  try {
    // Open both files for reading.
    final Future<RandomAccessFile> fileAFuture = a.open();
    final Future<RandomAccessFile> fileBFuture = b.open();

    final RandomAccessFile fileA = await fileAFuture;
    final RandomAccessFile fileB = await fileBFuture;

    // Get the length of both files.
    final Future<int> lengthAFuture = fileA.length();
    final Future<int> lengthBFuture = fileB.length();

    final int lengthA = await lengthAFuture;
    final int lengthB = await lengthBFuture;

    // If the files are not the same length, they are not equal.
    if (lengthA != lengthB) {
      await Future.wait([fileA.close(), fileB.close()]);
      return false;
    }

    // Create a queue to hold the chunks of the files.
    final LimitedQueue<Uint8List> queueA = LimitedQueue<Uint8List>(queueLength);
    final LimitedQueue<Uint8List> queueB = LimitedQueue<Uint8List>(queueLength);

    // Start async reading of both files
    final CancelToken cancelTokenA = CancelToken();
    final CancelToken cancelTokenB = CancelToken();

    final Future aFuture = _readFile(queueA, fileA, lengthA, cancelTokenA);
    final Future bFuture = _readFile(queueB, fileB, lengthB, cancelTokenB);

    Future<void> closeFiles() {
      cancelTokenA.cancel();
      cancelTokenB.cancel();

      final Future aDoneFuture = aFuture.then((_) => fileA.close());
      final Future bDoneFuture = bFuture.then((_) => fileB.close());

      return Future.wait([aDoneFuture, bDoneFuture]);
    }

    // Wait for both files to be read
    while (true) {
      // Pop elements
      final Future<Uint8List> chunkAFuture = queueA.pop();
      final Future<Uint8List> chunkBFuture = queueB.pop();

      final Uint8List chunkA = await chunkAFuture;
      final Uint8List chunkB = await chunkBFuture;

      // Check if one is done
      if (chunkA.isEmpty && chunkB.isEmpty) {
        // -> Both files are done
        await closeFiles();
        return true;
      }

      if (chunkA.isEmpty || chunkB.isEmpty) {
        // Cancel reading of both files -> Different (why?)
        print("Different file sizes even though lengths are equal (Why?)");
        await closeFiles();
        return false;
      }

      if (!memEquals(chunkA, chunkB)) {
        // Cancel reading of both files
        await closeFiles();
        return false;
      }
    }
  } catch (e) {
    print(e);
    return false;
  }
}

/// Compare two files in a new Isolate.
Future<bool> compareFilesMultithread(File a, File b) {
  // Start new Isolate to compare files
  return Isolate.run(() => compareFiles(a, b));
}
