import 'dart:async';
import 'dart:collection';
import 'dart:developer';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_hls_parser/flutter_hls_parser.dart';

typedef Dfn = Future Function();

class DownloadQueue {
  static Queue<Dfn> queue = Queue();
  static final _controller = StreamController()..sink.add(queue);

  static void add(Dfn value) {
    queue.add(value);
    // execute();
    _controller.sink.add(queue);
  }

  static Stream load() {
    return _controller.stream;
  }

  static Future<void> execute(Queue q) async {
    for (Dfn dfn in q) {
      await dfn();
    }
    queue.clear();
  }
}

Future<String> findFileLocation(String url) async {
  final hash = url.hashCode.toString();
  final filePath = getFilePath(url);
  final appDocDir = await getApplicationDocumentsDirectory();
  final file = File(p.join(appDocDir.path, hash, filePath));
  return file.absolute.path;
}

String normalizeUrl(String url) {
  final uri = Uri.parse(url);
  final dir = p.join(
    uri.host,
    uri.pathSegments.sublist(0, uri.pathSegments.length - 1).join('/'),
  );

  return dir;
}

String stripFilePath(String url) {
  final uri = Uri.parse(url);
  final dir = p.join(
    uri.host,
    uri.pathSegments.sublist(0, uri.pathSegments.length - 1).join('/'),
  );
  return '${uri.scheme}://$dir';
}

String getFilePath(String url) {
  final uri = Uri.parse(url);

  return uri.pathSegments.last;
}

List<String> pathSegments(String url) {
  final segments = url.split('/');
  return segments.sublist(0, segments.length - 1);
}

Future<File> downloadFile(String url, String filepath, String filename,
    Map<String, String> headers) async {
  log("Sending request to client...");
  final client = http.Client();
  final req = await client.get(Uri.parse(url), headers: headers);
  final bytes = req.bodyBytes;
  log("Response from client: $bytes");
  final file = File('$filepath/$filename');

  for (final f in pathSegments(filename)) {
    final d = Directory(p.join(filepath, f));
    if (!await d.exists()) {
      await d.create();
    }
  }

  if (!await file.exists()) {
    await file.create();
  }

  await file.writeAsBytes(bytes);
  return file;
}

Future<List<Segment>> getHlsMediaFiles(Uri uri, List<String> lines) async {
  HlsPlaylist? playList;

  try {
    playList = await HlsPlaylistParser.create().parse(uri, lines);
  } on ParserException catch (e) {
    log('HLS Parsing Error: $e');
  }

  if (playList is HlsMediaPlaylist) {
    log('MEDIA Playlist');
    return playList.segments;
  } else {
    return [];
  }
}

Future<Map> loadFileMetadata(String url, headers) async {
  log("Loading meta data started...");
  final uri = Uri.parse(url);
  log("Uri parsed: $uri");
  final client = http.Client();
  log("Connected http client: $client");
  final req = await client.get(Uri.parse(url), headers: headers);
  log("Request...");
  final lines = req.body;
  log("Request body getted: $lines");
  HlsPlaylist? playList;
  log("Started HlsPlaylistParser...");
  try {
    playList = await HlsPlaylistParser.create().parseString(uri, lines);
    log("Successfully HlsPlaylistParser. Length: ${playList.tags.length}");
  } catch (error) {
    log("HlsPlaylistParser Error:P $error");
  }

  log("Started checking HlsMediaPlaylist");
  if (playList is HlsMediaPlaylist) {
    log("created playlist is HlsMediaPlaylist");
    return {'default': url};
  } else if (playList is HlsMasterPlaylist) {
    log("created playlist is HlsMasterPlaylist");
    final result = {};
    for (final p in playList.variants) {
      result['${p.format.height} x ${p.format.width}'] = p.url.toString();
    }
    log("Result: $result");
    return result;
  } else {
    throw 'Unable to recognize HLS playlist type';
  }
}

Future<String> load(
    String url, Function(double) progress, Map<String, String> headers) async {
  log("load() function started...");
  final filename = getFilePath(url);
  log("File path getted: $filename");
  final appDocDir = await getApplicationDocumentsDirectory();
  log("Application directory getted");
  final downloadDir = Directory(p.join(
    appDocDir.path,
    url.hashCode.toString(),
  ));
  log("File joined in Application directory");
  if (!await downloadDir.exists()) {
    log("Directory not found. Creating directory...");
    await downloadDir.create();
    log("Directory created.");
  }
  final filepath = p.join(downloadDir.path, filename);
  var file = File(filepath);
  if (!await file.exists()) {
    log("downloadFile() started...");
    file = await downloadFile(url, downloadDir.path, filename, headers);
    log("downloadFile() completed.");
  }
  final lines = await file.readAsLines();
  log("Lines length: ${lines.length}");
  final mediaSegments = await getHlsMediaFiles(Uri.parse(file.path), lines);
  log("Lines length: ${mediaSegments.length}");
  final total = mediaSegments.length;
  var currentProgress = 0.0;
  log("Absolute file making started...");
  for (final entry in mediaSegments.asMap().entries) {
    final index = entry.key;
    final seg = entry.value;
    final urlToDownload = p.join(
      pathSegments(url).join('/'),
      seg.url,
    );
    var ff = File(p.join(downloadDir.path, seg.url));
    if (!await ff.exists()) {
      await downloadFile(urlToDownload, downloadDir.path, seg.url!, headers);
    }
    if (index != total - 1) {
      currentProgress += double.parse(((1 / total) * 100).toStringAsFixed(2));
      log("Progress: $currentProgress%");
      await progress(currentProgress);
    } else {
      currentProgress = 100.0;
      await progress(currentProgress);
    }
  }
  log("Absolute file making completed");
  log("All processing completed. Result: ${file.absolute.path}");
  return file.absolute.path;
}

////data/user/0/com.example.untitled2/app_flutter/673474223/stream.m3u8