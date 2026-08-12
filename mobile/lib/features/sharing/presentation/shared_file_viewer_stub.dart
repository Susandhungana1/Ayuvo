/// The non-web implementation of [openSharedFile]: there is no DOM to open the
/// file in, so the caller is told so rather than silently doing nothing.
library;

String? openSharedFile(String base64, String fileName) =>
    'The original file can only be opened on the web version.';
