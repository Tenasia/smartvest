import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:convert';
import 'package:smartvest/core/services/mqtt_service.dart';
import 'package:smartvest/config/app_routes.dart';
import 'package:google_fonts/google_fonts.dart';

// --- DESIGN SYSTEM (Using the established system for consistency) ---
class AppColors {
  static const Color background = Color(0xFFF7F8FC);
  static const Color cardBackground = Colors.white;
  static const Color primaryText = Color(0xFF333333);
  static const Color secondaryText = Color(0xFF8A94A6);
  static const Color profileColor = Color(0xFF5667FD);
  static const Color heartRateColor = Color(0xFFF25C54);
}

class AppTextStyles {
  static final TextStyle heading = GoogleFonts.poppins(
      fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryText);
  static final TextStyle cardTitle = GoogleFonts.poppins(
      fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primaryText);
  static final TextStyle secondaryInfo = GoogleFonts.poppins(
      fontSize: 14, fontWeight: FontWeight.normal, color: AppColors.secondaryText);
  static final TextStyle buttonText = GoogleFonts.poppins(
      fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white);
}
// --- END OF DESIGN SYSTEM ---

class SearchingDeviceScreen extends StatefulWidget {
  const SearchingDeviceScreen({super.key});
  @override
  State<SearchingDeviceScreen> createState() => _SearchingDeviceScreenState();
}

class _SearchingDeviceScreenState extends State<SearchingDeviceScreen> {
  // --- STATE & LOGIC (Functionality is preserved, no changes here) ---
  bool _isScanning = false;
  bool _noDeviceFound = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _user = FirebaseAuth.instance.currentUser;
  bool _hasInitializedDeviceFields = false;
  bool _isBindingDevice = false;
  List<ScanResult> _scanResults = [];
  BluetoothDevice? _connectingDevice;
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  StreamSubscription<bool>? _isScanningSubscription;
  final Guid _esp32ServiceUuid = Guid("d751e04f-3ee7-4d5a-b40d-c9f92ea9c56c");
  final Guid _esp32IdentifierCharacteristicUuid = Guid("02d0732d-304a-4195-b687-5b1525a05ca9");
  final Guid _esp32PairCommandCharacteristicUuid = Guid("6f5f12ed-2ea6-4a3b-9191-4d7e4ade9d5a");
  final MqttService _mqttService = MqttService();

  @override
  void initState() {
    super.initState();
    _initializeDeviceConnectionFields();
    _initBluetooth();
  }

  @override
  void dispose() {
    _scanResultsSubscription?.cancel();
    _adapterStateSubscription?.cancel();
    _isScanningSubscription?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<void> _initBluetooth() async {
    if (await FlutterBluePlus.isSupported == false) {
      return;
    }
    _startListeningToAdapterState();
  }

  void _startListeningToAdapterState() {
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      if (mounted) {
        setState(() {}); // Re-build to reflect adapter state change
        if (state == BluetoothAdapterState.on) {
          _startScan();
        }
      }
    });
  }

  Future<void> _startScan() async {
    if (FlutterBluePlus.isScanningNow) {
      return;
    }
    setState(() {
      _isScanning = true;
      _noDeviceFound = false;
      _scanResults = [];
      _connectingDevice = null;
    });

    try {
      _scanResultsSubscription = FlutterBluePlus.scanResults.listen(
            (results) {
          if (mounted) {
            final processedResults = results.where((r) => r.device.platformName.isNotEmpty).toList();
            final uniqueResults = <BluetoothDevice, ScanResult>{};
            for (var r in processedResults) {
              uniqueResults[r.device] = r;
            }
            setState(() {
              _scanResults = uniqueResults.values.toList();
            });
          }
        },
      );

      _isScanningSubscription = FlutterBluePlus.isScanning.listen((scanning) {
        if (mounted) {
          setState(() {
            _isScanning = scanning;
          });
          if (!scanning && _scanResults.isEmpty) {
            setState(() {
              _noDeviceFound = true;
            });
          }
        }
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        withServices: [_esp32ServiceUuid],
      );

    } catch (e) {
      if (mounted) setState(() { _isScanning = false; _noDeviceFound = true; });
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    if (_connectingDevice != null || _isBindingDevice) return;
    setState(() {
      _connectingDevice = device;
      _isBindingDevice = true;
    });
    await FlutterBluePlus.stopScan();
    try {
      await device.connect(timeout: const Duration(seconds: 20));
      List<BluetoothService> services = await device.discoverServices();
      String? esp32IdFromCharacteristic;
      bool identifierFound = false;
      for (BluetoothService service in services) {
        if (service.uuid == _esp32ServiceUuid) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid == _esp32IdentifierCharacteristicUuid) {
              List<int> value = await characteristic.read();
              esp32IdFromCharacteristic = String.fromCharCodes(value).trim();
              identifierFound = true;
              break;
            }
          }
        }
        if (identifierFound) break;
      }
      if (identifierFound && esp32IdFromCharacteristic != null && esp32IdFromCharacteristic.isNotEmpty) {
        final esp32BindingRef = _firestore.collection('esp32_bindings').doc(esp32IdFromCharacteristic);
        DocumentSnapshot esp32BindingDoc = await esp32BindingRef.get();
        if (esp32BindingDoc.exists) {
          Map<String, dynamic> bindingData = esp32BindingDoc.data() as Map<String, dynamic>;
          if (bindingData['boundToUserUid'] == _user!.uid && bindingData['isActivelyBound'] == true) {
            await _updateUserDeviceStatus(esp32IdFromCharacteristic, device.remoteId.toString(), true, true);
            await _mqttService.connectAndSubscribe(esp32IdFromCharacteristic);
            if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
          } else if (bindingData['isActivelyBound'] == true) {
            await device.disconnect();
          } else {
            await _performNewBinding(device, esp32IdFromCharacteristic, device.remoteId.toString());
          }
        } else {
          await _performNewBinding(device, esp32IdFromCharacteristic, device.remoteId.toString());
        }
      } else {
        await device.disconnect();
      }
    } catch (e) {
      await device.disconnect();
    } finally {
      if (mounted) setState(() { _connectingDevice = null; _isBindingDevice = false; });
    }
  }

  Future<void> _performNewBinding(BluetoothDevice device, String esp32Id, String macAddress) async {
    setState(() => _isBindingDevice = true);
    try {
      bool esp32Paired = await _sendPairCommandToEsp32(device, esp32Id);
      if (esp32Paired) {
        await _firestore.collection('users').doc(_user!.uid).update({
          'esp32Identifier': esp32Id, 'esp32MacAddress': macAddress, 'isDeviceBound': true,
          'hasDeviceConnected': true, 'previouslyHasDeviceConnected': true,
        });
        await _mqttService.connectAndSubscribe(esp32Id);
        await _firestore.collection('esp32_bindings').doc(esp32Id).set({
          'boundToUserUid': _user!.uid, 'macAddress': macAddress,
          'firstBoundAt': FieldValue.serverTimestamp(), 'isActivelyBound': true,
        });
        if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
      } else {
        await device.disconnect();
      }
    } catch (e) {
      await device.disconnect();
    } finally {
      if (mounted) setState(() { _isBindingDevice = false; _connectingDevice = null; });
    }
  }

  Future<bool> _sendPairCommandToEsp32(BluetoothDevice device, String esp32Id) async {
    try {
      List<BluetoothService> services = await device.discoverServices();
      for (BluetoothService service in services) {
        if (service.uuid == _esp32ServiceUuid) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid == _esp32PairCommandCharacteristicUuid) {
              if (characteristic.properties.write || characteristic.properties.writeWithoutResponse) {
                String command = "PAIR:${_user!.uid}";
                await characteristic.write(utf8.encode(command), withoutResponse: !characteristic.properties.write);
                return true;
              }
            }
          }
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _updateUserDeviceStatus(String esp32Id, String macAddress, bool isConnected, bool isBound) async {
    if (_user != null) {
      await _firestore.collection('users').doc(_user!.uid).update({
        'hasDeviceConnected': isConnected,
        'previouslyHasDeviceConnected': isBound ? true : FieldValue.delete(),
      });
    }
  }

  Future<void> _initializeDeviceConnectionFields() async {
    if (_user != null && !_hasInitializedDeviceFields) {
      await _firestore.collection('users').doc(_user!.uid).set({
        'hasDeviceConnected': false,
      }, SetOptions(merge: true));
      if (mounted) setState(() => _hasInitializedDeviceFields = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Connect Device', style: AppTextStyles.heading),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primaryText),
        centerTitle: false,
        actions: [
          if (_isScanning)
            IconButton(icon: const Icon(Icons.stop_circle_outlined), onPressed: FlutterBluePlus.stopScan, tooltip: "Stop Scan")
          else
            IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _startScan, tooltip: "Rescan"),
        ],
      ),
      body: Center(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      return _buildBluetoothOffUI();
    }
    if (_isScanning && _scanResults.isEmpty) {
      return _buildSearchingUI();
    }
    if (!_isScanning && _scanResults.isEmpty) {
      return _buildNoDeviceFoundUI();
    }
    return _buildDeviceList();
  }

  Widget _buildBluetoothOffUI() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bluetooth_disabled_rounded, size: 60, color: AppColors.secondaryText.withOpacity(0.5)),
          const SizedBox(height: 24),
          Text("Bluetooth is Off", style: AppTextStyles.heading.copyWith(fontSize: 22)),
          const SizedBox(height: 8),
          Text("Please turn on Bluetooth to connect your Smart Vest.", style: AppTextStyles.secondaryInfo, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async => await FlutterBluePlus.turnOn(),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.profileColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
            child: Text("Turn On Bluetooth", style: AppTextStyles.buttonText),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchingUI() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.profileColor, strokeWidth: 3),
          const SizedBox(height: 32),
          Text('Searching for Smart Vest...', style: AppTextStyles.heading.copyWith(fontSize: 22)),
          const SizedBox(height: 8),
          Text('Keep your device nearby and powered on.', style: AppTextStyles.secondaryInfo, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildNoDeviceFoundUI() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 60, color: AppColors.secondaryText.withOpacity(0.5)),
          const SizedBox(height: 24),
          Text('No Device Found', style: AppTextStyles.heading.copyWith(fontSize: 22)),
          const SizedBox(height: 8),
          Text('Make sure your Smart Vest is on and nearby, then try again.', style: AppTextStyles.secondaryInfo, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _startScan,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.profileColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
            child: Text('Try Again', style: AppTextStyles.buttonText),
          ),
          TextButton(
            onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.dashboard),
            child: Text('Skip for Now', style: AppTextStyles.secondaryInfo.copyWith(color: AppColors.profileColor)),
          )
        ],
      ),
    );
  }

  Widget _buildDeviceList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _scanResults.length,
      itemBuilder: (context, index) {
        final result = _scanResults[index];
        final deviceName = result.device.platformName.isNotEmpty ? result.device.platformName : 'Unknown Device';
        final isConnectingThisDevice = _connectingDevice == result.device;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            leading: const CircleAvatar(backgroundColor: AppColors.background, child: Icon(Icons.bluetooth_rounded, color: AppColors.profileColor)),
            title: Text(deviceName, style: AppTextStyles.cardTitle),
            subtitle: Text(result.device.remoteId.toString(), style: AppTextStyles.secondaryInfo),
            trailing: ElevatedButton(
              onPressed: (isConnectingThisDevice || _isBindingDevice) ? null : () => _connectToDevice(result.device),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.profileColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.secondaryText.withOpacity(0.5),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: isConnectingThisDevice
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Bind', style: AppTextStyles.buttonText.copyWith(fontSize: 12)),
            ),
          ),
        );
      },
    );
  }
}