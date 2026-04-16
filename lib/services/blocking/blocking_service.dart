abstract class BlockingService {
  Future<void> initialize();
  Future<bool> isBlockingSupported();
  Future<bool> requestElevatedPermissions();
  Future<bool> hasElevatedPermissions();
  Future<void> blockDomain(String domain);
  Future<void> unblockDomain(String domain);
  Future<bool> isDomainBlocked(String domain);
  Future<List<String>> getBlockedDomains();
  Future<void> applyBlocks(List<String> domains);
  Future<void> removeBlocks(List<String> domains);
  Future<void> forceCloseBrowsers();
  Future<void> dispose();
}

enum BlockingResult {
  success,
  permissionDenied,
  fileNotWritable,
  unknownError,
}

extension BlockingResultExtension on BlockingResult {
  bool get isSuccess => this == BlockingResult.success;
}
