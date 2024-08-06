import 'package:flutter/material.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('انتخاب تاریخ و زمان فارسی'),
      ),
      body: Center(
        child: ElevatedButton(
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
          child: const Text('تاریخ '),
        ),
      ),
    );
  }
}
