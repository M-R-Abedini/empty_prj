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
            child: const Text('الان نه'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: const Text('باشه'),
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
          await _createRestartScript(); // فراخوانی متد برای ایجاد اسکریپت راه‌اندازی مجدد
          await _restartApp();
        }
      } else {
        print('خطا: فایل دانلود شده یافت نشد.');
      }
    } catch (e) {
      print('خطا در دانلود یا نصب: $e');
    }
  }

  Future<void> _createInstallScript(String debPath) async {
    try {
      Directory appDocDir = await getApplicationDocumentsDirectory();
      String scriptPath = '${appDocDir.path}/install.sh';
      String logPath = '${appDocDir.path}/install_log.txt';

      String script = '''
#!/bin/bash
LOG_PATH="$logPath"
DEB_PATH="$debPath"

exec > \$LOG_PATH 2>&1  # Redirect output to log file
set -x  # Enable command tracing

echo "Starting installation process"
sleep 1

xhost +SI:localuser:root

sudo dpkg -i "\$DEB_PATH"
sudo dpkg --configure -a
sudo systemctl daemon-reload
sudo update-desktop-database
sudo gtk-update-icon-cache -f /usr/share/icons/hicolor

echo "Installation process completed"

rm "\$DEB_PATH"
''';

      await File(scriptPath).writeAsString(script);
      await Process.run('chmod', ['+x', scriptPath]);

      if (await File(scriptPath).exists()) {
        print('اسکریپت نصب با موفقیت ایجاد شد: $scriptPath');
      } else {
        print('خطا در ایجاد اسکریپت نصب: $scriptPath');
      }
    } catch (e) {
      print('خطا در ایجاد اسکریپت نصب: $e');
    }
  }

  Future<void> _createRestartScript() async {
    try {
      Directory appDocDir = await getApplicationDocumentsDirectory();
      String scriptPath = '${appDocDir.path}/restart.sh';
      String currentExecutable = Platform.resolvedExecutable;
      String appName = currentExecutable.split('/').last;
      String logPath = '${appDocDir.path}/restart_log.txt';

      // گرفتن مقدار متغیر DISPLAY
      String? display = Platform.environment['DISPLAY'];

      String script = '''
#!/bin/bash
APP_NAME="$appName"
LOG_PATH="$logPath"
DISPLAY="$display"

exec > \$LOG_PATH 2>&1  # Redirect output to log file
set -x  # Enable command tracing

echo "Starting restart process"
sleep 1

# کشتن فرآیند قبلی
pkill -f "\$APP_NAME"
echo "Current instance killed"

# تنظیم DISPLAY و اجرای برنامه
export DISPLAY=\$DISPLAY
"$currentExecutable" &

echo "New version started"
''';

      await File(scriptPath).writeAsString(script);
      await Process.run('chmod', ['+x', scriptPath]);

      if (await File(scriptPath).exists()) {
        print('اسکریپت راه‌اندازی مجدد با موفقیت ایجاد شد: $scriptPath');
      } else {
        print('خطا در ایجاد اسکریپت راه‌اندازی مجدد: $scriptPath');
      }
    } catch (e) {
      print('خطا در ایجاد اسکریپت راه‌اندازی مجدد: $e');
    }
  }

  Future<void> _restartApp() async {
    if (Platform.isLinux) {
      try {
        Directory appDocDir = await getApplicationDocumentsDirectory();
        String installScriptPath = '${appDocDir.path}/install.sh';
        String restartScriptPath = '${appDocDir.path}/restart.sh';
        String installLogPath = '${appDocDir.path}/install_log.txt';
        String restartLogPath = '${appDocDir.path}/restart_log.txt';

        // اجرای اسکریپت نصب با pkexec
        ProcessResult installResult =
            await Process.run('pkexec', [installScriptPath]);
        if (installResult.exitCode != 0) {
          print('خطا در اجرای اسکریپت نصب: ${installResult.stderr}');
          String installLogContent = await File(installLogPath).readAsString();
          print('محتویات فایل لاگ نصب:\n$installLogContent');
          return;
        }

        // اجرای اسکریپت راه‌اندازی مجدد بدون pkexec
        ProcessResult restartResult =
            await Process.run('bash', [restartScriptPath]);
        if (restartResult.exitCode != 0) {
          print(
              'خطا در اجرای اسکریپت راه‌اندازی مجدد: ${restartResult.stderr}');
          String restartLogContent = await File(restartLogPath).readAsString();
          print('محتویات فایل لاگ راه‌اندازی مجدد:\n$restartLogContent');
          return;
        }

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

  VersionInfo({
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
    );
  }
}
