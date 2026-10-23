import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

/// Returns [results] in order, one per call, holding on the last entry once
/// exhausted. A `null` entry simulates the user cancelling the native picker.
class FakeImagePickerPlatform extends ImagePickerPlatform {
  FakeImagePickerPlatform(this.results);

  final List<XFile?> results;
  int _callCount = 0;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    final result = results[_callCount];
    if (_callCount < results.length - 1) _callCount++;
    return result;
  }
}
