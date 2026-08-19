import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mihox/common/common.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class Picker {
  Future<PlatformFile?> pickerFile({FileType fileType = FileType.any, List<String>? allowedExtensions}) async => 
      FilePicker.pickFile(
        type: fileType,
        allowedExtensions: allowedExtensions,
        initialDirectory: await appPath.downloadDirPath,
      );

  Future<String?> saveFile(String fileName, Uint8List bytes) async {
    final path = await FilePicker.saveFile(
      fileName: fileName,
      initialDirectory: await appPath.downloadDirPath,
      bytes: bytes,
    );
    if (!Platform.isAndroid && path != null) {
      final file = await File(path.toFilePath()).create(recursive: true);
      await file.writeAsBytes(bytes);
    }
    return path?.toFilePath();
  }

  Future<String?> pickerConfigQRCode() async {
    final xFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (xFile == null) {
      return null;
    }
    final controller = MobileScannerController();
    final capture = await controller.analyzeImage(xFile.path, formats: [
      BarcodeFormat.qrCode,
    ]);
    final result = capture?.barcodes.first.rawValue;
    if (result == null || !result.isUrl) {
      throw appLocalizations.pleaseUploadValidQrcode;
    }
    return result;
  }
}

final picker = Picker();
