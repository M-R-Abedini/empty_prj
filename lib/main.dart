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
        // print(response.data);
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
      String currentExecutable = Platform.resolvedExecutable;
      String appName = currentExecutable.split('/').last;
      String logPath = '${appDocDir.path}/update_log.txt';

      String script = '''
#!/bin/bash
exec > $logPath 2>&1  # Redirect output to log file
set -x  # Enable command tracing

echo "Starting update process"
sleep 2
pkill -f "$appName"  # Kill the current running instance
echo "Current instance killed"

sudo dpkg -i "$debPath"
sudo dpkg --configure -a
sudo systemctl daemon-reload
sudo update-desktop-database
sudo gtk-update-icon-cache -f /usr/share/icons/hicolor
rm "$debPath"
echo "Update process completed"

# Get the current user
CURRENT_USER=\$(logname)

# Run the new version as the current user
su - \$CURRENT_USER -c "nohup $currentExecutable > /dev/null 2>&1 &"
echo "New version started"
''';

      await File(scriptPath).writeAsString(script);
      await Process.run('chmod', ['+x', scriptPath]);
    } catch (e) {
      print('خطا در ایجاد اسکریپت: $e');
    }
  }

  Future<void> _restartApp() async {
    if (Platform.isLinux) {
      try {
        Directory appDocDir = await getApplicationDocumentsDirectory();
        String scriptPath = '${appDocDir.path}/install_and_restart.sh';
        String logPath = '${appDocDir.path}/update_log.txt';

        // اجرای اسکریپت با pkexec و منتظر ماندن برای اتمام آن
        ProcessResult result = await Process.run('pkexec', [scriptPath]);

        if (result.exitCode != 0) {
          print('خطا در اجرای اسکریپت: ${result.stderr}');
          // خواندن و نمایش محتویات فایل لاگ
          String logContent = await File(logPath).readAsString();
          print('محتویات فایل لاگ:\n$logContent');
          return;
        }

        // خواندن و نمایش محتویات فایل لاگ
        String logContent = await File(logPath).readAsString();
        print('محتویات فایل لاگ:\n$logContent');

        // افزودن تأخیر قبل از بستن برنامه
        await Future.delayed(Duration(seconds: 2));

        // بستن برنامه فعلی
        exit(0);
      } catch (e) {
        print('خطا در راه‌اندازی مجدد برنامه: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          ' تقویم جلال',
          style: TextStyle(color: Colors.red),
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
              child: const Text('تقویم ایرانی'),
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
