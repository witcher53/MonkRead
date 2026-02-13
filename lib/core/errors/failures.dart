/// Sealed class representing failures in the application.
sealed class Failure {
  final String message;
  const Failure(this.message);

  @override
  String toString() => message;
}

/// Failed to obtain required storage permission.
class PermissionFailure extends Failure {
  const PermissionFailure([
    super.message = 'Storage permission was denied. '
        'Please grant permission in Settings to open PDF files.',
  ]);
}

/// An error occurred while picking a file.
class FilePickerFailure extends Failure {
  const FilePickerFailure([
    super.message = 'Could not open the file picker. '
        'Please try again.',
  ]);
}

/// The selected PDF could not be loaded or rendered.
class PdfLoadFailure extends Failure {
  const PdfLoadFailure([
    super.message = 'Failed to load the PDF file. '
        'The file may be corrupted or unsupported.',
  ]);
}
