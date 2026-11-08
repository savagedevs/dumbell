import 'package:sembast_web/sembast_web.dart';

Future<Database> openWorkoutDatabase() =>
    databaseFactoryWeb.openDatabase('liftlog');
