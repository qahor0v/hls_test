import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:untitled2/helpers.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HLS Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isDownloading = false;
  Map qualities = {};
  final downloadStream = DownloadQueue.load();
  String? quality;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () async {
                final url = quality;
                DownloadQueue.add(() async {
                  await load(url!, (progress) async {}, headers);
                });
              },
              child: const Text("Download Video"),
            ),
            MaterialButton(
              padding: const EdgeInsets.symmetric(
                vertical: NavigationToolbar.kMiddleSpacing / 1.5,
              ),
              elevation: 0,
              onPressed: () async {
                try {
                  final q = await loadFileMetadata(url, headers);
                  setState(() {
                    qualities = q;
                    quality = q.entries.first.value;
                  });
                  log("All Quality");
                  q.forEach((key, value) {
                    log("Quality: $key");
                  });
                } catch (e) {
                  log(e.toString());
                }
              },
              child: const Text('Load Metadata'),
            ),
            qualities.isEmpty
                ? const SizedBox.shrink()
                : StreamBuilder(
                    stream: downloadStream,
                    builder: (context, snapshot) {
                      log('stream');
                      log(snapshot.data.toString());

                      if (snapshot.hasData) {
                        DownloadQueue.execute(snapshot.data);
                      }
                      return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text("${snapshot.data}"));
                    },
                  ),
          ],
        ),
      ),
    );
  }
}

const headers = {
  "Authorization": "Token 752051277f418110e41e798b9e27aac47d07b1be",
  "profile-auth": "249446",
};
const url = "https://api.splay.uz/en/api/v2/content/film-hls/2008/stream.m3u8";
