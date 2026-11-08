import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'csv_backup_codec.dart';

abstract interface class DataTransferFileService {
  Future<Uri?> save({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  });
  Future<Uint8List?> pickBackup();
}

class NativeDataTransferFileService implements DataTransferFileService {
  @override
  Future<Uri?> save({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) =>
      // file_picker 13 writes these bytes through Android's document provider
      // (ACTION_CREATE_DOCUMENT). Its content URI is not a dart:io file path.
      FilePicker.saveFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: mimeType,
        dialogTitle: 'Save your Dumbbell CSV',
      );

  @override
  Future<Uint8List?> pickBackup() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Choose a Dumbbell Backup CSV',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (file == null) return null;
    final length = file.lengthSync();
    if (length != null && length > CsvBackupCodec.maxBytes) {
      throw const FormatException(
        'Choose a Dumbbell backup smaller than 8 MiB.',
      );
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in file.readAsByteStream()) {
      if (bytes.length + chunk.length > CsvBackupCodec.maxBytes) {
        throw const FormatException(
          'Choose a Dumbbell backup smaller than 8 MiB.',
        );
      }
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }
}
