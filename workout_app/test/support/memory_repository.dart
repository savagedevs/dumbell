import 'package:workout_app/data/models.dart';
import 'package:workout_app/data/workout_repository.dart';

class MemoryRepository implements WorkoutRepository {
  AppData value = AppData();
  bool failWrites = false;
  int writes = 0;
  @override
  Future<AppData> load() async => value;
  @override
  Future<void> save(AppData data) async {
    await Future<void>.delayed(Duration.zero);
    if (failWrites) throw StateError('Disk full');
    value = AppData.fromJson(data.toJson());
    writes++;
  }

  @override
  Future<void> close() async {}
}
