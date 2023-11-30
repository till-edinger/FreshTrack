import 'package:barcode_scan2/barcode_scan2.dart';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';

// differentsettings for the barcode scanner
class ScannerSettings extends StatefulWidget {

  final _aspectTolerance = 0.00;
  final _selectedCamera = -1;
  final _useAutoFocus = true;
  final _autoEnableFlash = false;

  double get aspectTolerance => _aspectTolerance;
  int get selectedCamera => _selectedCamera;
  bool get useAutoFocus => _useAutoFocus;
  bool get autoEnableFlash => _autoEnableFlash;

  static final _possibleFormats = BarcodeFormat.values.toList()
    ..removeWhere((e) => e == BarcodeFormat.unknown);

  List<BarcodeFormat> selectedFormats = [..._possibleFormats];

  @override
  _ScannerSettingsState createState() => _ScannerSettingsState();

}

class _ScannerSettingsState extends State<ScannerSettings> {

  var _aspectTolerance = 0.00;
  var _numberOfCameras = 0;
  var _selectedCamera = -1;
  var _useAutoFocus = true;
  var _autoEnableFlash = false;

  static final _possibleFormats = BarcodeFormat.values.toList()
    ..removeWhere((e) => e == BarcodeFormat.unknown);

  List<BarcodeFormat> selectedFormats = [..._possibleFormats];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Scanner Einstellungen'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pushNamed('/settings');
            },
          ),
          actions: const [], // Add your actions widgets here if needed
        ),
        body: ListView(
          shrinkWrap: true,
          children: <Widget>[
            const ListTile(
              title: Text('Camera selection'),
              dense: true,
              enabled: false,
            ),
            RadioListTile(
              onChanged: (v) => setState(() => _selectedCamera = -1),
              value: -1,
              title: const Text('Default camera'),
              groupValue: _selectedCamera,
            ),
            ...List.generate(
              _numberOfCameras,
                  (i) =>
                  RadioListTile(
                    onChanged: (v) => setState(() => _selectedCamera = i),
                    value: i,
                    title: Text('Camera ${i + 1}'),
                    groupValue: _selectedCamera,
                  ),
            ),
            if (Platform.isAndroid) ...[
              const ListTile(
                title: Text('Android specific options'),
                dense: true,
                enabled: false,
              ),
              ListTile(
                title: Text(
                  'Aspect tolerance (${_aspectTolerance.toStringAsFixed(2)})',
                ),
                subtitle: Slider(
                  min: -1,
                  value: _aspectTolerance,
                  onChanged: (value) {
                    setState(() {
                      _aspectTolerance = value;
                    });
                  },
                ),
              ),
              CheckboxListTile(
                title: const Text('Use autofocus'),
                value: _useAutoFocus,
                onChanged: (checked) {
                  setState(() {
                    _useAutoFocus = checked!;
                  });
                },
              ),
            ],
            const ListTile(
              title: Text('Other options'),
              dense: true,
              enabled: false,
            ),
            CheckboxListTile(
              title: const Text('Start with flash'),
              value: _autoEnableFlash,
              onChanged: (checked) {
                setState(() {
                  _autoEnableFlash = checked!;
                });
              },
            ),
            const ListTile(
              title: Text('Barcode formats'),
              dense: true,
              enabled: false,
            ),
            ListTile(
              trailing: Checkbox(
                tristate: true,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                value: selectedFormats.length == _possibleFormats.length
                    ? true
                    : selectedFormats.isEmpty
                    ? false
                    : null,
                onChanged: (checked) {
                  setState(() {
                    selectedFormats = [
                      if (checked ?? false) ..._possibleFormats,
                    ];
                  });
                },
              ),
              dense: true,
              enabled: false,
              title: const Text('Detect barcode formats'),
              subtitle: const Text(
                'If all are unselected, all possible '
                    'platform formats will be used',
              ),
            ),
            ..._possibleFormats.map(
                  (format) =>
                  CheckboxListTile(
                    value: selectedFormats.contains(format),
                    onChanged: (i) {
                      setState(
                            () =>
                        selectedFormats.contains(format)
                            ? selectedFormats.remove(format)
                            : selectedFormats.add(format),
                      );
                    },
                    title: Text(format.toString()),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}