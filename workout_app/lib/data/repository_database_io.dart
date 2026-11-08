import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

Future<Database> openWorkoutDatabase() async {
  final directory = await getApplicationSupportDirectory();
  await Directory(directory.path).create(recursive: true);
  return databaseFactoryIo.openDatabase(
    path.join(directory.path, 'liftlog.sembast'),
  );
}
