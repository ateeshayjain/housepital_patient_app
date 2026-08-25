import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import 'logger.dart';

/// Picks photos with their embedded metadata removed.
///
/// WHY THIS EXISTS
/// Every photo this app uploads is taken at the patient's home: a wound
/// dressing for a nurse, a meter reading, an equipment fault, an ID document.
/// A phone camera stamps each of those with EXIF — GPS latitude/longitude to
/// a few metres, the capture timestamp, and the device serial. The app
/// uploaded that untouched, so a concern photo sent to support carried the
/// exact home coordinates of a bedbound patient, to a Firebase Storage bucket
/// readable by every authenticated account.
///
/// Nobody asked for that and no feature uses it. It is the highest-value data
/// the app moves and the only data it moves entirely by accident.
///
/// FAIL CLOSED
/// If the image cannot be decoded and re-encoded, [pickSanitizedImage] returns
/// null rather than handing back the original. A photo that fails to attach is
/// a visible, recoverable annoyance; a photo that silently attaches with a
/// home address inside it is neither.
abstract final class ImagePrivacy {
  /// Picks an image and returns a metadata-free copy, or null if the user
  /// cancelled OR the copy could not be made.
  ///
  /// [maxWidth], [maxHeight] and [imageQuality] are forwarded to the picker
  /// unchanged, so call sites keep their existing sizing behaviour. Do NOT
  /// treat those as the privacy control: image_picker only re-encodes (and so
  /// only incidentally drops EXIF) when a resize is actually required, which
  /// is why four of this app's call sites shipped the original bytes.
  static Future<XFile?> pickSanitizedImage(
    ImagePicker picker, {
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    final picked = await picker.pickImage(
      source: source,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );
    if (picked == null) return null;
    return stripMetadata(picked);
  }

  /// Re-encodes [original] without any metadata. Returns null on failure.
  static Future<XFile?> stripMetadata(XFile original) async {
    try {
      final bytes = await original.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        Log.warn('Could not decode picked image — refusing to upload it with '
            'its metadata intact', tag: 'ImagePrivacy');
        return null;
      }

      // Orientation must be BAKED before the tag is dropped, or every photo
      // taken in portrait comes out sideways: the pixels are landscape and the
      // EXIF Orientation tag is what rotates them for display.
      final baked = img.bakeOrientation(decoded);

      // bakeOrientation carries `exif` across, and encodeJpg writes whatever
      // is on the image back into the file — so clearing this is the actual
      // strip. Without it the re-encode faithfully reproduces the GPS tags.
      baked.exif = img.ExifData();

      final encoded = img.encodeJpg(baked, quality: 88);

      final dir = await Directory.systemTemp.createTemp('hpl_img_');
      final out = File('${dir.path}/${_safeName(original.name)}');
      await out.writeAsBytes(encoded, flush: true);

      return XFile(out.path, mimeType: 'image/jpeg', name: out.uri.pathSegments.last);
    } catch (e, st) {
      Log.error('Failed to strip image metadata — upload refused',
          error: e, stack: st, tag: 'ImagePrivacy');
      return null;
    }
  }

  /// The output is always JPEG, so the extension must say so — a `.png` name
  /// on JPEG bytes makes downstream viewers guess.
  static String _safeName(String name) {
    final base = name.split('/').last.split('\\').last;
    final dot = base.lastIndexOf('.');
    final stem = dot > 0 ? base.substring(0, dot) : base;
    return '${stem.isEmpty ? 'photo' : stem}.jpg';
  }
}
