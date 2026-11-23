/// Triggers a browser download of in-memory bytes.
///
/// Uses `package:web` on web builds; other platforms get a stub that throws,
/// which keeps this library importable from VM-based tests.
library;

export 'file_download_stub.dart'
    if (dart.library.js_interop) 'file_download_web.dart';
