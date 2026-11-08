import 'package:sembast/sembast.dart';

import 'models.dart';
import 'repository_database_stub.dart'
    if (dart.library.io) 'repository_database_io.dart'
    if (dart.library.js_interop) 'repository_database_web.dart'
    as platform;

abstract class WorkoutRepository {
  Future<AppData> load();
  Future<void> save(AppData data);
  Future<void> close();
}

class LocalWorkoutRepository implements WorkoutRepository {
  LocalWorkoutRepository(this._database);

  final Database _database;
  static final _snapshot = stringMapStoreFactory
      .store('app_data')
      .record('snapshot');

  static Future<LocalWorkoutRepository> open() async =>
      LocalWorkoutRepository(await platform.openWorkoutDatabase());

  @override
  Future<AppData> load() async {
    final json = await _snapshot.get(_database);
    return json == null ? AppData() : AppData.fromJson(json);
  }

  @override
  Future<void> save(AppData data) async {
    final json = data.toJson();
    await _database.transaction((transaction) async {
      // Validate inside the same transaction as the write. Even a caller that
      // skipped load cannot replace a newer schema or an unreadable snapshot.
      final existing = await _snapshot.get(transaction);
      if (existing != null) AppData.fromJson(existing);
      await _snapshot.put(transaction, json);
    });
  }

  @override
  Future<void> close() => _database.close();
}
