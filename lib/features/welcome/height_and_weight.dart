import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class HeightAndWeightScreen extends StatefulWidget {
  const HeightAndWeightScreen({super.key});

  @override
  State<HeightAndWeightScreen> createState() => _HeightAndWeightScreenState();
}

class _HeightAndWeightScreenState extends State<HeightAndWeightScreen> {
  bool _useMetric = true;
  int _selectedHeightCm = 175;
  double _selectedWeightKg = 65.0;

  final List<int> _heightCmOptions = List.generate(250 - 50 + 1, (i) => 50 + i);
  final List<int> _weightKgOptions = List.generate(200 - 30 + 1, (i) => 30 + i);
  final List<int> _heightInchOptions = List.generate(100 - 20 + 1, (i) => 20 + i);
  final List<int> _weightLbsOptions = List.generate(400 - 60 + 1, (i) => 60 + i);

  static const double cmToInch = 0.393701;
  static const double kgToLbs = 2.20462;

  FixedExtentScrollController? _heightPickerController;
  FixedExtentScrollController? _weightPickerController;

  int get _selectedHeightInch => (_selectedHeightCm * cmToInch).round();
  double get _selectedWeightLbs => _selectedWeightKg * kgToLbs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePickerControllers();
    });
  }

  void _initializePickerControllers() {
    _heightPickerController = FixedExtentScrollController(
      initialItem: _useMetric
          ? _heightCmOptions.indexOf(_selectedHeightCm)
          : _heightInchOptions.indexOf(_selectedHeightInch),
    );
    _weightPickerController = FixedExtentScrollController(
      initialItem: _useMetric
          ? _weightKgOptions.indexOf(_selectedWeightKg.round())
          : _weightLbsOptions.indexOf(_selectedWeightLbs.round()),
    );
    // Force a rebuild to use the initialized controllers
    setState(() {});
  }

  void _handleHeightChanged(int value) {
    setState(() {
      _selectedHeightCm = value;
    });
  }

  void _handleWeightChanged(double value) {
    setState(() {
      _selectedWeightKg = value;
    });
  }

  @override
  void dispose() {
    _heightPickerController?.dispose();
    _weightPickerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Height & Weight'),
        automaticallyImplyLeading: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Height & Weight',
              style: TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8.0),
            const Text(
              'Help us personalize your experience by entering your height and weight. This will improve posture tracking and stress monitoring for better insights!',
              style: TextStyle(fontSize: 16.0),
            ),
            const SizedBox(height: 20.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    setState(() {
                      _useMetric = true;
                      // Re-initialize controllers when unit changes
                      _initializePickerControllers();
                    });
                  },
                  child: Text(
                    'cm',
                    style: TextStyle(
                      color: _useMetric ? Colors.blue : Colors.grey,
                      fontWeight: _useMetric ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                const Text('/', style: TextStyle(color: Colors.grey)),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    setState(() {
                      _useMetric = false;
                      // Re-initialize controllers when unit changes
                      _initializePickerControllers();
                    });
                  },
                  child: Text(
                    'inch',
                    style: TextStyle(
                      color: !_useMetric ? Colors.blue : Colors.grey,
                      fontWeight: !_useMetric ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                const SizedBox(width: 20.0),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    setState(() {
                      _useMetric = true;
                      // Re-initialize controllers when unit changes
                      _initializePickerControllers();
                    });
                  },
                  child: Text(
                    'kg',
                    style: TextStyle(
                      color: _useMetric ? Colors.blue : Colors.grey,
                      fontWeight: _useMetric ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                const Text('/', style: TextStyle(color: Colors.grey)),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    setState(() {
                      _useMetric = false;
                      // Re-initialize controllers when unit changes
                      _initializePickerControllers();
                    });
                  },
                  child: Text(
                    'lbs',
                    style: TextStyle(
                      color: !_useMetric ? Colors.blue : Colors.grey,
                      fontWeight: !_useMetric ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20.0),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        _useMetric ? 'Height (cm)' : 'Height (inch)',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      SizedBox(
                        height: 150.0,
                        width: MediaQuery.of(context).size.width / 2 - 30, // Example width
                        child: CupertinoPicker(
                          itemExtent: 32.0,
                          scrollController: _heightPickerController,
                          onSelectedItemChanged: (int index) {
                            setState(() {
                              _selectedHeightCm = _useMetric
                                  ? _heightCmOptions[index]
                                  : (_heightInchOptions[index] / cmToInch).round();
                            });
                          },
                          children: _useMetric
                              ? _heightCmOptions.map((height) => Center(child: Text('$height'))).toList()
                              : _heightInchOptions.map((height) => Center(child: Text('$height'))).toList(),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        _useMetric ? 'Weight (kg)' : 'Weight (lbs)',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      SizedBox(
                        height: 150.0,
                        width: MediaQuery.of(context).size.width / 2 - 30, // Example width
                        child: CupertinoPicker(
                          itemExtent: 32.0,
                          scrollController: _weightPickerController,
                          onSelectedItemChanged: (int index) {
                            setState(() {
                              _selectedWeightKg = _useMetric
                                  ? _weightKgOptions[index].toDouble()
                                  : _weightLbsOptions[index] / kgToLbs;
                            });
                          },
                          children: _useMetric
                              ? _weightKgOptions.map((weight) => Center(child: Text('$weight'))).toList()
                              : _weightLbsOptions.map((weight) => Center(child: Text('${weight.round()}'))).toList(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20.0),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  print('Selected Height (cm): $_selectedHeightCm');
                  print('Selected Weight (kg): $_selectedWeightKg');
                  print('Selected Height (inch): $_selectedHeightInch');
                  print('Selected Weight (lbs): ${_selectedWeightLbs.toStringAsFixed(1)}');
                  Navigator.pushReplacementNamed(context, '/searchAndConnect');
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 15.0),
                  child: Text(
                    'Continue',
                    style: TextStyle(fontSize: 18.0),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}