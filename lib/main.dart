import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'تاریخ و زمان فارسی',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  MyHomePageState createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  Jalali selectedDate = Jalali.now();
  final Dio _dio = Dio();
  String currentVersion = '';

  @override
  void initState() {
    super.initState();
    _checkForUpdate(); // بررسی به‌روزرسانی هنگام شروع اپلیکیشن
  }

  Future<void> _checkForUpdate() async {
    // دریافت نسخه فعلی اپلیکیشن
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      currentVersion =
          packageInfo.version; // مقداردهی currentVersion و به‌روزرسانی UI
    });
    // دریافت فایل version.json از GitHub
    final response = await _dio.get(
        'https://raw.githubusercontent.com/M-R-Abedini/empty_prj/main/version.json');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.data) as Map<String, dynamic>;
      final versionInfo = VersionInfo.fromJson(data);

      String newVersion = versionInfo.version;
      String downloadUrl = versionInfo.linuxUrl;

      // انتخاب لینک دانلود مناسب بر اساس پلتفرم
      if (Platform.isAndroid) {
        downloadUrl = data['android_url'];
      } else if (Platform.isWindows) {
        downloadUrl = data['windows_url'];
      } else if (Platform.isLinux) {
        downloadUrl =
            data['linux_deb_url']; // تغییر لینک دانلود به لینک فایل .deb
      }

      // مقایسه نسخه‌ها
      if (newVersion != currentVersion && downloadUrl.isNotEmpty) {
        // نسخه جدید موجود است
        _showUpdateDialog(downloadUrl);
      }
    }
  }

  void _showUpdateDialog(String downloadUrl) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('نسخه جدید موجود است'),
        content: const Text('آیا می‌خواهید نسخه جدید را دانلود کنید؟'),
        actions: [
          TextButton(
            child: const Text('خیر'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: const Text('بله'),
            onPressed: () {
              Navigator.of(context).pop();
              _downloadAndInstall(downloadUrl);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _downloadAndInstall(String url) async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String debPath = '${appDocDir.path}/new_version.deb';

    // دانلود فایل .deb
    await _dio.download(url, debPath);

    // نصب فایل .deb
    if (Platform.isLinux) {
      final result = await Process.run('sudo', ['dpkg', '-i', debPath]);

      // نمایش خروجی نصب در Console
      print(result.stdout);
      if (result.exitCode != 0) {
        print(result.stderr);
        throw 'Failed to install .deb package';
      }
    }

    // پاکسازی فایل‌های موقت
    await File(debPath).delete();
  }

  Future<void> _openFile(String filePath) async {
    final uri = Uri.file(filePath);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not open $filePath';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(' تقویم'),
      ),
      body: Center(
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () async {
                final Jalali? picked = await showPersianDatePicker(
                  context: context,
                  initialDate: Jalali.fromDateTime(
                      DateTime.fromMillisecondsSinceEpoch(1722942780132)),
                  firstDate: Jalali(1390),
                  lastDate: Jalali(1410),
                );
                if (picked != null) {
                  setState(() {
                    selectedDate = picked;
                    int millisecondsSinceEpoch =
                        selectedDate.toDateTime().millisecondsSinceEpoch;
                    print(millisecondsSinceEpoch);
                  });
                }
              },
              child: const Text(' تقویم شمسی'),
            ),

            SizedBox(
              height: 16,
            ),
            Text(
                'Current App Version: $currentVersion'), // نمایش نسخه فعلی اپلیکیشن
          ],
        ),
      ),
    );
  }
}

class VersionInfo {
  final String version;
  final String linuxUrl;
  final String windowsUrl;
  final String androidUrl;
  final String linuxDebUrl;

  VersionInfo({
    required this.linuxDebUrl,
    required this.version,
    required this.linuxUrl,
    required this.windowsUrl,
    required this.androidUrl,
  });

  factory VersionInfo.fromJson(Map<String, dynamic> json) {
    return VersionInfo(
      version: json['version'],
      linuxUrl: json['linux_url'],
      windowsUrl: json['windows_url'],
      androidUrl: json['android_url'],
      linuxDebUrl: json['linux_deb_url'],
    );
  }
}
