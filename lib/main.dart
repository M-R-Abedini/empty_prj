import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
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
    _checkForUpdate();
  }

  int _versionToNumber(String version) {
    return int.parse(version.replaceAll('.', ''));
  }

  Future<void> _checkForUpdate() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        currentVersion = packageInfo.version;
      });

      final response = await _dio.get(
          'https://raw.githubusercontent.com/M-R-Abedini/empty_prj/main/version.json');

      if (response.statusCode == 200) {
        print(response.data);
        final data = jsonDecode(response.data) as Map<String, dynamic>;
        final versionInfo = VersionInfo.fromJson(data);

        String newVersion = versionInfo.version;
        String downloadUrl = versionInfo.linuxUrl;

        if (Platform.isAndroid) {
          downloadUrl = data['android_url'];
        } else if (Platform.isWindows) {
          downloadUrl = data['windows_url'];
        } else if (Platform.isLinux) {
          downloadUrl = data['linux_deb_url'];
        }

        int currentVersionNumber = _versionToNumber(currentVersion);
        int newVersionNumber = _versionToNumber(newVersion);

        if (newVersionNumber > currentVersionNumber && downloadUrl.isNotEmpty) {
          _showUpdateDialog(downloadUrl);
        }
      } else {
        print('خطا در دریافت اطلاعات نسخه: وضعیت ${response.statusCode}');
      }
    } catch (e) {
      print('خطا در بررسی نسخه: $e');
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
    try {
      Directory appDocDir = await getApplicationDocumentsDirectory();
      String debPath = '${appDocDir.path}/new_version.deb';

      // دانلود فایل
      await _dio.download(url, debPath, onReceiveProgress: (received, total) {
        if (total != -1) {
          print(
              'دانلود: ${(received / total * 100).toStringAsFixed(0)}% تکمیل شده');
        }
      });

      // بررسی وجود فایل دانلود شده
      File downloadedFile = File(debPath);
      if (await downloadedFile.exists()) {
        if (Platform.isLinux) {
          await _createInstallScript(debPath);
          await _restartApp();
        }
      } else {
        print('خطا: فایل دانلود شده یافت نشد.');
      }
    } catch (e) {
      // مدیریت خطا در دانلود و نصب
      print('خطا در دانلود یا نصب: $e');
    }
  }

  Future<void> _createInstallScript(String debPath) async {
    try {
      Directory appDocDir = await getApplicationDocumentsDirectory();
      String scriptPath = '${appDocDir.path}/install_and_restart.sh';

      String script = '''
#!/bin/bash
sleep 2  # اضافه کردن یک تأخیر کوچک
pkexec bash -c "dpkg -i '$debPath' && dpkg --configure -a && systemctl daemon-reload"
rm "$debPath"
/usr/bin/empty_prj &
''';

      await File(scriptPath).writeAsString(script);
      await Process.run('chmod', ['+x', scriptPath]);
    } catch (e) {
      // مدیریت خطا در ایجاد اسکریپت
      print('خطا در ایجاد اسکریپت: $e');
    }
  }

  Future<void> _restartApp() async {
    if (Platform.isLinux) {
      try {
        Directory appDocDir = await getApplicationDocumentsDirectory();
        String scriptPath = '${appDocDir.path}/install_and_restart.sh';

        // اجرای اسکریپت در پس‌زمینه
        await Process.start('bash', [scriptPath]);

        // افزودن یک تأخیر کوچک قبل از بستن برنامه
        await Future.delayed(const Duration(seconds: 2));

        // بستن برنامه فعلی
        exit(0);
      } catch (e) {
        // مدیریت خطا در راه‌اندازی مجدد
        print('خطا در راه‌اندازی مجدد برنامه: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          ' تقویم',
          style: TextStyle(color: Colors.green),
        ),
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
              child: const Text('تقویم شمسی'),
            ),
            Text('Current App Version: $currentVersion'),
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
