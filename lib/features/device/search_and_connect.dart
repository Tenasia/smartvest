import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:convert';
import 'package:smartvest/core/services/ble-health-service.dart';
import 'package:smartvest/config/app_routes.dart';
import 'package:google_fonts/google_fonts.dart';

// --- DESIGN SYSTEM ---
class AppColors {
  static const Color background = Color(0xFFF7F8FC);
  static const Color cardBackground = Colors.white;
  static const Color primaryText = Color(0xFF333333);
  static const Color secondaryText = Color(0xFF8A94A6);
  static const Color profileColor = Color(0xFF5667FD);
  static const Color heartRateColor = Color(0xFFF25C54);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color errorColor = Color(0xFFF44336);
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

class SearchingDeviceScreen extends StatefulWidget {
  const SearchingDeviceScreen({super.key});
  @override
  State<SearchingDeviceScreen> createState() => _SearchingDeviceScreenState();
}

class _SearchingDeviceScreenState extends State<SearchingDeviceScreen> {
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
  StreamSubscription<Map<String, dynamic>>? _healthServiceStatusSubscription;

  final Guid _esp32ServiceUuid = Guid("d751e04f-3ee7-4d5a-b40d-c9f92ea9c56c");
  final Guid _esp32IdentifierCharacteristicUuid = Guid("02d0732d-304a-4195-b687-5b1525a05ca9");
  final Guid _esp32PairCommandCharacteristicUuid = Guid("6f5f12ed-2ea6-4a3b-9191-4d7e4ade9d5a");
  final Guid _esp32HealthDataCharacteristicUuid = Guid("87654321-4321-4321-4321-cba987654321");

  final BleHealthService _bleHealthService = BleHealthService();

  // Enhanced debug variables
  String _debugInfo = "Initializing...";
  Map<String, dynamic> _healthServiceStats = {};
  List<String> _recentMessages = [];
  bool _isDataFlowing = false;

  @override
  void initState() {
    super.initState();
    _initializeDeviceConnectionFields();
    _initBluetooth();
    _listenToHealthServiceStatus();
    _checkForStoredConnection();
  }

  @override
  void dispose() {
    _scanResultsSubscription?.cancel();
    _adapterStateSubscription?.cancel();
    _isScanningSubscription?.cancel();
    _healthServiceStatusSubscription?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  void _listenToHealthServiceStatus() {
    _healthServiceStatusSubscription = _bleHealthService.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _healthServiceStats = status['stats'] ?? {};
          _isDataFlowing = _healthServiceStats['isConnected'] == true;
          _addRecentMessage(status['message'] ?? 'Status update');
        });
      }
    });
  }

  Future<void> _checkForStoredConnection() async {
    final storedData = await _bleHealthService.getStoredDeviceInfo();
    if (storedData['deviceId'] != null) {
      _addRecentMessage("Found stored device: ${storedData['deviceId']}");
      setState(() => _debugInfo = "Found stored device, attempting to resume...");

      bool resumed = await _bleHealthService.resumeMonitoringFromStorage();
      if (resumed) {
        _addRecentMessage("Successfully resumed monitoring");
        setState(() => _debugInfo = "Monitoring resumed from storage");
      } else {
        _addRecentMessage("Could not resume, device may need reconnection");
        setState(() => _debugInfo = "Stored device not available, scan for devices");
      }
    }
  }

  void _addRecentMessage(String message) {
    if (mounted) {
      setState(() {
        _recentMessages.insert(0, "${DateTime.now().toString().substring(11, 19)}: $message");
        if (_recentMessages.length > 5) {
          _recentMessages.removeLast();
        }
      });
    }
  }

  Future<void> _initBluetooth() async {
    if (await FlutterBluePlus.isSupported == false) {
      setState(() => _debugInfo = "Bluetooth not supported");
      return;
    }
    _startListeningToAdapterState();
  }

  void _startListeningToAdapterState() {
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      if (mounted) {
        setState(() {
          _debugInfo = "Bluetooth state: $state";
        });
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
      _debugInfo = "Scanning for devices...";
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
              _debugInfo = "Found ${_scanResults.length} devices";
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
              _debugInfo = "No devices found";
            });
          }
        }
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        withServices: [_esp32ServiceUuid],
      );

    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _noDeviceFound = true;
          _debugInfo = "Scan error: $e";
        });
      }
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    if (_connectingDevice != null || _isBindingDevice) return;

    setState(() {
      _connectingDevice = device;
      _isBindingDevice = true;
      _debugInfo = "Connecting to ${device.platformName}...";
    });

    _addRecentMessage("Connecting to ${device.platformName}");
    await FlutterBluePlus.stopScan();

    try {
      await device.connect(timeout: const Duration(seconds: 20));
      setState(() => _debugInfo = "Connected! Discovering services...");
      _addRecentMessage("Connected successfully");

      List<BluetoothService> services = await device.discoverServices();
      setState(() => _debugInfo = "Found ${services.length} services");
      _addRecentMessage("Found ${services.length} services");

      String? esp32IdFromCharacteristic;
      BluetoothCharacteristic? healthDataCharacteristic;

      bool identifierFound = false;

      for (BluetoothService service in services) {
        if (service.uuid == _esp32ServiceUuid) {
          setState(() => _debugInfo = "Found main service, reading identifier...");
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid == _esp32IdentifierCharacteristicUuid) {
              List<int> value = await characteristic.read();
              esp32IdFromCharacteristic = String.fromCharCodes(value).trim();
              identifierFound = true;
              setState(() => _debugInfo = "Device ID: $esp32IdFromCharacteristic");
              _addRecentMessage("Device ID: $esp32IdFromCharacteristic");
            }
          }
        }

        // Look for health service
        if (service.uuid == Guid("12345678-1234-1234-1234-123456789abc")) {
          setState(() => _debugInfo = "Found health service...");
          _addRecentMessage("Found health service");
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid == _esp32HealthDataCharacteristicUuid) {
              healthDataCharacteristic = characteristic;
              setState(() => _debugInfo = "Found health data characteristic");
              _addRecentMessage("Found health data characteristic");
            }
          }
        }

        if (identifierFound && healthDataCharacteristic != null) break;
      }

      if (identifierFound && esp32IdFromCharacteristic != null && esp32IdFromCharacteristic.isNotEmpty && healthDataCharacteristic != null) {
        setState(() => _debugInfo = "Checking device binding...");

        final esp32BindingRef = _firestore.collection('esp32_bindings').doc(esp32IdFromCharacteristic);
        DocumentSnapshot esp32BindingDoc = await esp32BindingRef.get();

        if (esp32BindingDoc.exists) {
          Map<String, dynamic> bindingData = esp32BindingDoc.data() as Map<String, dynamic>;
          if (bindingData['boundToUserUid'] == _user!.uid && bindingData['isActivelyBound'] == true) {
            await _updateUserDeviceStatus(esp32IdFromCharacteristic, device.remoteId.toString(), true, true);
            setState(() => _debugInfo = "Device already bound, starting data monitoring...");
            _addRecentMessage("Device bound, starting monitoring");

            // Start health data monitoring with the persistent service
            bool success = await _bleHealthService.startHealthDataMonitoring(
                device,
                esp32IdFromCharacteristic,
                healthDataCharacteristic
            );

            if (success) {
              _addRecentMessage("Health monitoring started successfully");
              // Navigate to dashboard after a short delay to ensure monitoring is established
              await Future.delayed(const Duration(seconds: 2));
              if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
            } else {
              setState(() => _debugInfo = "Failed to start health monitoring");
              await device.disconnect();
            }
          } else if (bindingData['isActivelyBound'] == true) {
            setState(() => _debugInfo = "Device bound to another user");
            _addRecentMessage("Device bound to another user");
            await device.disconnect();
          } else {
            await _performNewBinding(device, esp32IdFromCharacteristic, device.remoteId.toString(), healthDataCharacteristic);
          }
        } else {
          await _performNewBinding(device, esp32IdFromCharacteristic, device.remoteId.toString(), healthDataCharacteristic);
        }
      } else {
        setState(() => _debugInfo = "Could not find required characteristics");
        _addRecentMessage("Missing required characteristics");
        await device.disconnect();
      }
    } catch (e) {
      setState(() => _debugInfo = "Connection error: $e");
      _addRecentMessage("Connection error: $e");
      await device.disconnect();
    } finally {
      if (mounted) {
        setState(() {
          _connectingDevice = null;
          _isBindingDevice = false;
        });
      }
    }
  }

  Future<void> _performNewBinding(BluetoothDevice device, String esp32Id, String macAddress, BluetoothCharacteristic healthDataCharacteristic) async {
    setState(() {
      _isBindingDevice = true;
      _debugInfo = "Performing new device binding...";
    });
    _addRecentMessage("Starting new binding");

    try {
      bool esp32Paired = await _sendPairCommandToEsp32(device, esp32Id);
      if (esp32Paired) {
        setState(() => _debugInfo = "Pairing successful, updating database...");
        _addRecentMessage("Pairing successful");

        await _firestore.collection('users').doc(_user!.uid).update({
          'esp32Identifier': esp32Id,
          'esp32MacAddress': macAddress,
          'isDeviceBound': true,
          'hasDeviceConnected': true,
          'previouslyHasDeviceConnected': true,
        });

        await _firestore.collection('esp32_bindings').doc(esp32Id).set({
          'boundToUserUid': _user!.uid,
          'macAddress': macAddress,
          'firstBoundAt': FieldValue.serverTimestamp(),
          'isActivelyBound': true,
        });

        setState(() => _debugInfo = "Starting health data monitoring...");
        _addRecentMessage("Starting health monitoring");

        // Start health data monitoring with the persistent service
        bool success = await _bleHealthService.startHealthDataMonitoring(
            device,
            esp32Id,
            healthDataCharacteristic
        );

        if (success) {
          _addRecentMessage("Health monitoring started successfully");
          // Navigate to dashboard after a short delay
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
        } else {
          setState(() => _debugInfo = "Failed to start health monitoring");
          await device.disconnect();
        }
      } else {
        setState(() => _debugInfo = "Pairing failed");
        _addRecentMessage("Pairing failed");
        await device.disconnect();
      }
    } catch (e) {
      setState(() => _debugInfo = "Binding error: $e");
      _addRecentMessage("Binding error: $e");
      await device.disconnect();
    } finally {
      if (mounted) {
        setState(() {
          _isBindingDevice = false;
          _connectingDevice = null;
        });
      }
    }
  }

  Future<bool> _sendPairCommandToEsp32(BluetoothDevice device, String esp32Id) async {
    try {
      setState(() => _debugInfo = "Sending pair command...");
      _addRecentMessage("Sending pair command");

      List<BluetoothService> services = await device.discoverServices();
      for (BluetoothService service in services) {
        if (service.uuid == _esp32ServiceUuid) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid == _esp32PairCommandCharacteristicUuid) {
              if (characteristic.properties.write || characteristic.properties.writeWithoutResponse) {
                String command = "PAIR:${_user!.uid}";
                await characteristic.write(utf8.encode(command), withoutResponse: !characteristic.properties.write);
                _addRecentMessage("Sent pair command");

                // Send current time for synchronization
                final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
                String timeCommand = "TIME:$currentTime";
                await characteristic.write(utf8.encode(timeCommand), withoutResponse: !characteristic.properties.write);
                debugPrint('BLE_DEBUG:: Sent time sync: $timeCommand');
                _addRecentMessage("Sent time sync");

                // Send user ID for data association
                String userIdCommand = "USER_ID:${_user!.uid}";
                await characteristic.write(utf8.encode(userIdCommand), withoutResponse: !characteristic.properties.write);
                debugPrint('BLE_DEBUG:: Sent user ID: $userIdCommand');
                _addRecentMessage("Sent user ID");

                // Send timezone offset for proper human time calculation
                final timezoneOffset = DateTime.now().timeZoneOffset.inHours;
                String timezoneCommand = "TIMEZONE:$timezoneOffset";
                await characteristic.write(utf8.encode(timezoneCommand), withoutResponse: !characteristic.properties.write);
                debugPrint('BLE_DEBUG:: Sent timezone: $timezoneCommand');
                _addRecentMessage("Sent timezone");

                return true;
              }
            }
          }
        }
      }
      return false;
    } catch (e) {
      _addRecentMessage("Pair command error: $e");
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
            IconButton(
                icon: const Icon(Icons.stop_circle_outlined),
                onPressed: FlutterBluePlus.stopScan,
                tooltip: "Stop Scan"
            )
          else
            IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _startScan,
                tooltip: "Rescan"
            ),
        ],
      ),
      body: Column(
        children: [
          // Enhanced debug info panel
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.secondaryText.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _isDataFlowing ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: _isDataFlowing ? AppColors.successColor : AppColors.secondaryText,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Debug Info',
                      style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _debugInfo,
                  style: AppTextStyles.secondaryInfo.copyWith(fontSize: 12),
                ),
                if (_healthServiceStats.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BLE: ${_healthServiceStats['dataPacketsReceived'] ?? 0} received',
                              style: AppTextStyles.secondaryInfo.copyWith(
                                fontSize: 11,
                                color: AppColors.profileColor,
                              ),
                            ),
                            Text(
                              'MQTT: ${_healthServiceStats['mqttPublishCount'] ?? 0} sent, ${_healthServiceStats['mqttErrors'] ?? 0} errors',
                              style: AppTextStyles.secondaryInfo.copyWith(
                                fontSize: 11,
                                color: (_healthServiceStats['mqttErrors'] ?? 0) > 0 ? AppColors.errorColor : AppColors.successColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                if (_healthServiceStats['lastReceivedData'] != null && _healthServiceStats['lastReceivedData'] != "None") ...[
                  const SizedBox(height: 8),
                  Text(
                    'Last data: ${_healthServiceStats['lastReceivedData']}',
                    style: AppTextStyles.secondaryInfo.copyWith(
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Recent messages panel
          if (_recentMessages.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.secondaryText.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Activity',
                    style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  ...(_recentMessages.take(3).map((msg) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      msg,
                      style: AppTextStyles.secondaryInfo.copyWith(fontSize: 10),
                    ),
                  ))),
                ],
              ),
            ),

          const SizedBox(height: 16),
          Expanded(
            child: Center(child: _buildBody()),
          ),
        ],
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
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.profileColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
            ),
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
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.profileColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
            ),
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
            leading: const CircleAvatar(
                backgroundColor: AppColors.background,
                child: Icon(Icons.bluetooth_rounded, color: AppColors.profileColor)
            ),
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
                  ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
              )
                  : Text('Bind', style: AppTextStyles.buttonText.copyWith(fontSize: 12)),
            ),
          ),
        );
      },
    );
  }
}
