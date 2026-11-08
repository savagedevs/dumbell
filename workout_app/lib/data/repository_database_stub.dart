import 'package:sembast/sembast.dart';

Future<Database> openWorkoutDatabase() => Future.error(
  UnsupportedError('This platform has no local workout storage.'),
);
