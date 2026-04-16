import 'dart:io';

import 'blocking_service.dart';

class WindowsBlockingService implements BlockingService {
  static const String _hostsPath = r'C:\Windows\System32\drivers\etc\hosts';
  static const String _markerStart = '# FocusOS Block Start';
  static const String _markerEnd = '# FocusOS Block End';

  bool _hasPermissions = false;
  bool _initialized = false;
  final Set<String> _managedDomains = {};

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _hasPermissions = await _checkWritePermissions();
    _initialized = true;
  }

  @override
  Future<bool> isBlockingSupported() async {
    return Platform.isWindows;
  }

  Future<bool> _checkWritePermissions() async {
    try {
      final file = File(_hostsPath);
      if (!await file.exists()) return false;
      await file.readAsString();
      await file.writeAsString(await file.readAsString(), mode: FileMode.append);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> requestElevatedPermissions() async {
    try {
      final result = await Process.run(
        'net',
        ['session'],
        runInShell: true,
      );
      _hasPermissions = result.exitCode == 0;
      return _hasPermissions;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> hasElevatedPermissions() async {
    if (!_initialized) await initialize();
    return _hasPermissions;
  }

  @override
  Future<void> blockDomain(String domain) async {
    if (!_hasPermissions) {
      throw BlockingException('No write permissions to hosts file');
    }

    final hostsContent = await _readHostsFile();
    final blockedDomains = _extractManagedDomains(hostsContent);

    if (!blockedDomains.contains(domain.toLowerCase())) {
      blockedDomains.add(domain.toLowerCase());
      await _writeHostsFile(hostsContent, blockedDomains);
      _managedDomains.add(domain.toLowerCase());
    }
  }

  @override
  Future<void> unblockDomain(String domain) async {
    if (!_hasPermissions) {
      throw BlockingException('No write permissions to hosts file');
    }

    final hostsContent = await _readHostsFile();
    final blockedDomains = _extractManagedDomains(hostsContent);

    blockedDomains.remove(domain.toLowerCase());
    await _writeHostsFile(hostsContent, blockedDomains);
    _managedDomains.remove(domain.toLowerCase());
  }

  @override
  Future<bool> isDomainBlocked(String domain) async {
    final hostsContent = await _readHostsFile();
    final blockedDomains = _extractManagedDomains(hostsContent);
    return blockedDomains.contains(domain.toLowerCase());
  }

  @override
  Future<List<String>> getBlockedDomains() async {
    try {
      final hostsContent = await _readHostsFile();
      return _extractManagedDomains(hostsContent).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> applyBlocks(List<String> domains) async {
    if (!_hasPermissions) {
      throw BlockingException('No write permissions to hosts file');
    }

    final hostsContent = await _readHostsFile();
    final blockedDomains = _extractManagedDomains(hostsContent);

    for (final domain in domains) {
      blockedDomains.add(domain.toLowerCase());
      _managedDomains.add(domain.toLowerCase());
    }

    await _writeHostsFile(hostsContent, blockedDomains);
  }

  @override
  Future<void> removeBlocks(List<String> domains) async {
    if (!_hasPermissions) {
      throw BlockingException('No write permissions to hosts file');
    }

    final hostsContent = await _readHostsFile();
    final blockedDomains = _extractManagedDomains(hostsContent);

    for (final domain in domains) {
      blockedDomains.remove(domain.toLowerCase());
      _managedDomains.remove(domain.toLowerCase());
    }

    await _writeHostsFile(hostsContent, blockedDomains);
  }

  @override
  Future<void> forceCloseBrowsers() async {
    final browsers = [
      'chrome.exe',
      'firefox.exe',
      'msedge.exe',
      'brave.exe',
      'opera.exe',
    ];

    for (final browser in browsers) {
      try {
        await Process.run(
          'taskkill',
          ['/F', '/IM', browser],
          runInShell: true,
        );
      } catch (e) {
        // Browser not running or access denied
      }
    }
  }

  @override
  Future<void> dispose() async {
    _managedDomains.clear();
    _initialized = false;
  }

  Future<String> _readHostsFile() async {
    try {
      final file = File(_hostsPath);
      if (!await file.exists()) {
        return '';
      }
      return await file.readAsString();
    } catch (e) {
      throw BlockingException('Cannot read hosts file: $e');
    }
  }

  Set<String> _extractManagedDomains(String content) {
    final domains = <String>{};
    bool inManagedSection = false;
    final lines = content.split('\n');

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed == _markerStart) {
        inManagedSection = true;
        continue;
      }
      if (trimmed == _markerEnd) {
        inManagedSection = false;
        continue;
      }
      if (inManagedSection && trimmed.isNotEmpty && !trimmed.startsWith('#')) {
        final parts = trimmed.split(RegExp(r'\s+'));
        if (parts.length >= 2) {
          final ip = parts[0];
          if (ip == '127.0.0.1') {
            domains.add(parts[1].toLowerCase());
          }
        }
      }
    }

    return domains;
  }

  Future<void> _writeHostsFile(String existingContent, Set<String> domains) async {
    try {
      final buffer = StringBuffer();

      final lines = existingContent.split('\n');
      final cleanLines = <String>[];
      bool inManagedSection = false;

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed == _markerStart) {
          inManagedSection = true;
          continue;
        }
        if (trimmed == _markerEnd) {
          inManagedSection = false;
          continue;
        }
        if (!inManagedSection) {
          cleanLines.add(line);
        }
      }

      for (final line in cleanLines) {
        buffer.writeln(line);
      }

      if (domains.isNotEmpty) {
        buffer.writeln();
        buffer.writeln(_markerStart);
        for (final domain in domains) {
          buffer.writeln('127.0.0.1 $domain');
          buffer.writeln('127.0.0.1 www.$domain');
        }
        buffer.writeln(_markerEnd);
      }

      final file = File(_hostsPath);
      await file.writeAsString(buffer.toString());
    } catch (e) {
      throw BlockingException('Cannot write to hosts file: $e');
    }
  }

  Future<void> clearAllManagedBlocks() async {
    await _writeHostsFile('', {});
    _managedDomains.clear();
  }
}

class BlockingException implements Exception {
  final String message;
  BlockingException(this.message);

  @override
  String toString() => 'BlockingException: $message';
}
