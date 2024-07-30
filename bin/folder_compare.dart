import 'dart:io';

import 'package:args/args.dart';

import 'compare_folders.dart';
import 'multi_output_pipe.dart';

const String version = '0.0.1';

ArgParser buildParser() {
  return ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Print this usage information.',
    )
    ..addFlag(
      'version',
      negatable: false,
      help: 'Print the tool version.',
    )
    ..addOption(
      'folderA',
      abbr: 'a',
      help: 'The first folder to compare.',
      valueHelp: '/path/to/folderA',
    )
    ..addOption(
      'folderB',
      abbr: 'b',
      help: 'The second folder to compare.',
      valueHelp: '/path/to/folderB',
    );
}

void printUsage(ArgParser argParser) {
  print('Usage: dart file_compare.dart <flags> [arguments]');
  print(argParser.usage);
}

void main(List<String> arguments) async {
  final ArgParser argParser = buildParser();

  try {
    final ArgResults results = argParser.parse(arguments);

    // Process the parsed arguments.
    if (results.wasParsed('help')) {
      printUsage(argParser);
      return;
    }

    if (results.wasParsed('version')) {
      print('file_compare version: $version');
      return;
    }

    // Check if the required arguments are provided.
    late final String folderA;
    late final String folderB;

    if (results.wasParsed('folderA')) {
      folderA = results['folderA'] as String;
    } else {
      throw FormatException('Missing required argument: folderA');
    }

    if (results.wasParsed('folderB')) {
      folderB = results['folderB'] as String;
    } else {
      throw FormatException('Missing required argument: folderB');
    }

    // Check if the provided folders exist.
    final Directory dirA = Directory(folderA);
    final Directory dirB = Directory(folderB);

    if (!dirA.existsSync()) {
      throw FormatException('Folder not found: $folderA');
    }

    if (!dirB.existsSync()) {
      throw FormatException('Folder not found: $folderB');
    }

    // Start the comparison.
    final MultiOutputPipe multiOutputPipe = MultiOutputPipe();
    final ReportStatus reportStatus = ReportStatus(5, multiOutputPipe);

    final bool result = await compareFolders(dirA, dirB, reportStatus);

    if (result) {
      print('\n\nFolders are equal! 🎉');
    } else {
      print('\n\nFolders are different!');
    }
  } on FormatException catch (e) {
    // Print usage information if an invalid argument was provided.
    print(e.message);
    print('');
    printUsage(argParser);
  } catch (e, s) {
    // Print the error and stack trace.
    print('An error occurred: $e');
    print(s);
  }
}
