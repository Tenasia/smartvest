import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:convert'; // For utf8.encode
import 'package:smartvest/core/services/mqtt_service.dart';
// TODO: Import a permission handler package if you haven't already
// import 'package:permission_handler/permission_handler.dart';

class SearchingDeviceScreen extends StatefulWidget {
  const SearchingDeviceScreen({super.key});

  @override
  State<SearchingDeviceScreen> createState() => _SearchingDeviceScreenState();
}

class _SearchingDeviceScreenState extends State<SearchingDeviceScreen> {
  bool _isActuallySearchingBluetooth = false;
  bool _noDeviceFoundByBluetooth = false;
  Timer? _initialDelayTimer;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _user = FirebaseAuth.instance.currentUser;
  bool _hasInitializedDeviceFields = false;
  bool _isBindingDevice = false; // To show loading state during binding

  List<ScanResult> _scanResults = [];
  BluetoothDevice? _connectingDevice;
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;

  // Define your ESP32's unique Service UUID here
  // Generate a new one from a site like https://www.uuidgenerator.net/
  final Guid _esp32ServiceUuid = Guid("d751e04f-3ee7-4d5a-b40d-c9f92ea9c56c"); // <-- IMPORTANT: REPLACE THIS
  final Guid _esp32IdentifierCharacteristicUuid = Guid("02d0732d-304a-4195-b687-5b1525a05ca9");
  final Guid _esp32PairCommandCharacteristicUuid = Guid("6f5f12ed-2ea6-4a3b-9191-4d7e4ade9d5a");
  final MqttService _mqttService = MqttService();


  @override
  void initState() {
    super.initState();
    _initializeDeviceConnectionFields();
    _initBluetooth();

    setState(() {
      _isActuallySearchingBluetooth = true;
      _noDeviceFoundByBluetooth = false;
    });
  }

  Future<void> _initBluetooth() async {
    if (await FlutterBluePlus.isSupported == false) {
      print("Bluetooth not supported by this device");
      if (mounted) {
        setState(() {
          _isActuallySearchingBluetooth = false;
          _noDeviceFoundByBluetooth = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bluetooth is not supported on this device.')),
        );
      }
      return;
    }

    // TODO: Implement runtime permission requests robustly
    // (See previous examples using permission_handler)
    _startListeningToAdapterState();
  }

  void _startListeningToAdapterState() {
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
      print("Adapter State: $state");
      if (mounted) {
        if (state == BluetoothAdapterState.on) {
          _startScan();
        } else {
          setState(() {
            _isActuallySearchingBluetooth = false;
            _noDeviceFoundByBluetooth = true;
            _scanResults = [];
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bluetooth is off. Please turn it on.')),
          );
        }
      }
    });
    if (FlutterBluePlus.adapterStateNow == BluetoothAdapterState.off) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bluetooth is off. Please turn it on.')),
        );
        setState(() {
          _isActuallySearchingBluetooth = false;
          _noDeviceFoundByBluetooth = true;
        });
      }
    }
  }

  Future<void> _startScan() async {
    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }
    setState(() {
      _isActuallySearchingBluetooth = true;
      _noDeviceFoundByBluetooth = false;
      _scanResults = [];
      _connectingDevice = null;
    });

    try {
      _scanResultsSubscription = FlutterBluePlus.scanResults.listen(
            (results) {
          if (mounted) {
            // When using withServices, FlutterBluePlus does the primary filtering.
            // You might still want to filter out unnamed devices if any slip through.
            final processedResults = results
                .where((r) => r.device.platformName.isNotEmpty)
                .toList();

            final uniqueResults = <BluetoothDevice, ScanResult>{};
            for (var r in processedResults) {
              uniqueResults[r.device] = r;
            }
            setState(() {
              _scanResults = uniqueResults.values.toList();
            });
          }
        },
        onError: (e) {
          print("Scan Error: $e");
          if (mounted) {
            setState(() {
              _isActuallySearchingBluetooth = false;
              _noDeviceFoundByBluetooth = true;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Bluetooth scan error: $e')),
            );
          }
        },
      );

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        withServices: [_esp32ServiceUuid], // Filter by your defined Service UUID
      );

      StreamSubscription? _isScanningSubscription;
      _isScanningSubscription = FlutterBluePlus.isScanning.listen((scanning) {
        if (mounted) {
          setState(() {
            _isActuallySearchingBluetooth = scanning;
          });
          if (!scanning && _scanResults.isEmpty) {
            setState(() {
              _noDeviceFoundByBluetooth = true;
            });
          }
          if(!scanning) {
            _isScanningSubscription?.cancel();
          }
        }
      });

    } catch (e) {
      print("Error starting scan: $e");
      if (mounted) {
        setState(() {
          _isActuallySearchingBluetooth = false;
          _noDeviceFoundByBluetooth = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting scan: $e')),
        );
      }
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    if (_connectingDevice != null || _isBindingDevice) return;

    setState(() {
      _connectingDevice = device;
      _isBindingDevice = true; // Indicate process start
    });
    await FlutterBluePlus.stopScan(); // Stop scanning before connecting

    StreamSubscription<BluetoothConnectionState>? connectionStateSubscription;

    try {
      connectionStateSubscription = device.connectionState.listen((BluetoothConnectionState state) async {
        print("Device ${device.remoteId}: Connection State $state");
        if (mounted) {
          if (state == BluetoothConnectionState.connected) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Connected to ${device.platformName}! Reading identifier...')),
            );
            try {
              List<BluetoothService> services = await device.discoverServices();
              String? esp32IdFromCharacteristic;
              bool identifierFound = false;

              for (BluetoothService service in services) {
                if (service.uuid == _esp32ServiceUuid) {
                  for (BluetoothCharacteristic characteristic in service.characteristics) {
                    if (characteristic.uuid == _esp32IdentifierCharacteristicUuid) {
                      List<int> value = await characteristic.read();
                      esp32IdFromCharacteristic = String.fromCharCodes(value).trim(); // Trim whitespace
                      identifierFound = true;
                      print("ESP32 Identifier from Characteristic: '$esp32IdFromCharacteristic' / MAC: ${device.remoteId}");
                      break; // Found identifier
                    }
                  }
                }
                if (identifierFound) break;
              }

              if (identifierFound && esp32IdFromCharacteristic != null && esp32IdFromCharacteristic.isNotEmpty) {
                final String deviceMacAddress = device.remoteId.toString();
                final esp32BindingRef = _firestore.collection('esp32_bindings').doc(esp32IdFromCharacteristic);
                DocumentSnapshot esp32BindingDoc = await esp32BindingRef.get();

                if (esp32BindingDoc.exists) {
                  Map<String, dynamic> bindingData = esp32BindingDoc.data() as Map<String, dynamic>;
                  if (bindingData['boundToUserUid'] == _user!.uid && bindingData['isActivelyBound'] == true) {
                    print("Device $esp32IdFromCharacteristic already bound to current user ${_user!.uid}. Connecting...");
                    await _updateUserDeviceStatus(esp32IdFromCharacteristic, deviceMacAddress, true, true);
                    // *** ADDED: Connect to MQTT on reconnect ***
                    await _mqttService.connectAndSubscribe(esp32IdFromCharacteristic);
                    if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
                  } else if (bindingData['isActivelyBound'] == true) {
                    print("Device $esp32IdFromCharacteristic is bound to another user: ${bindingData['boundToUserUid']}");
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${device.platformName} is already paired with another account.')),
                    );
                    await device.disconnect();
                  } else { // Exists but not actively bound (e.g. after an unbind flow)
                    print("Device $esp32IdFromCharacteristic was previously bound but is now available. Attempting to bind.");
                    await _performNewBinding(device, esp32IdFromCharacteristic, deviceMacAddress);
                  }
                } else {
                  // Device is not in bindings collection, available for new binding
                  print("Device $esp32IdFromCharacteristic is new. Attempting to bind to user ${_user!.uid}");
                  await _performNewBinding(device, esp32IdFromCharacteristic, deviceMacAddress);
                }
              } else {
                print("ESP32 specific identifier characteristic not found or value is null/empty.");
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not read a valid identifier from ${device.platformName}.')),
                );
                await device.disconnect();
              }
            } catch (e) {
              print("Service discovery or characteristic read/binding error: $e");
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error processing device details: $e')),
              );
              await device.disconnect();
            } finally {
              if (mounted) setState(() { _connectingDevice = null; _isBindingDevice = false; });
            }

          } else if (state == BluetoothConnectionState.disconnected) {
            // Only show if not during an active binding attempt that might intentionally disconnect
            if(!_isBindingDevice || _connectingDevice == device) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${device.platformName} disconnected.')),
              );
            }
            if (mounted) {
              setState(() {
                if (_connectingDevice == device) {
                  _connectingDevice = null;
                  _isBindingDevice = false;
                }
              });
            }
            connectionStateSubscription?.cancel(); // Clean up listener
          }
        }
      });

      await device.connect(timeout: const Duration(seconds: 20)); // Increased timeout

    } catch (e) {
      print("Connection error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect: ${e.toString().split('.').last}')),
        );
        setState(() { _connectingDevice = null; _isBindingDevice = false; });
        // Optionally restart scan if connection fails early
        // _startScan();
      }
      connectionStateSubscription?.cancel();
    }
  }

  Future<void> _performNewBinding(BluetoothDevice device, String esp32Id, String macAddress) async {
    setState(() { _isBindingDevice = true; });
    try {
      // Command ESP32 to enter paired state
      bool esp32Paired = await _sendPairCommandToEsp32(device, esp32Id);
      if (esp32Paired) {
        // Update Firestore: user's document and global bindings
        await _firestore.collection('users').doc(_user!.uid).update({
          'esp32Identifier': esp32Id,
          'esp32MacAddress': macAddress,
          'isDeviceBound': true,
          'hasDeviceConnected': true,
          'previouslyHasDeviceConnected': true,
        });

        await _mqttService.connectAndSubscribe(esp32Id);

        await _firestore.collection('esp32_bindings').doc(esp32Id).set({
          'boundToUserUid': _user!.uid,
          'macAddress': macAddress,
          'firstBoundAt': FieldValue.serverTimestamp(),
          'isActivelyBound': true,
        });
        print("Device $esp32Id successfully bound to user ${_user!.uid}");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${device.platformName} successfully paired!')),
          );
          Navigator.pushReplacementNamed(context, '/dashboard');
        }
      } else {
        print("ESP32 did not confirm pairing or command failed for $esp32Id.");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not complete pairing with ${device.platformName}.')),
        );
        await device.disconnect();
      }
    } catch (e) {
      print("Error during new binding process for $esp32Id: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during pairing: $e')),
      );
      await device.disconnect();
    } finally {
      if(mounted) setState(() { _isBindingDevice = false; _connectingDevice = null; });
    }
  }

  Future<bool> _sendPairCommandToEsp32(BluetoothDevice device, String esp32Id) async {
    // This tells the ESP32 it's being paired. ESP32 needs to handle this.
    try {
      List<BluetoothService> services = await device.discoverServices(); // Re-discover or use cached
      for (BluetoothService service in services) {
        if (service.uuid == _esp32ServiceUuid) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid == _esp32PairCommandCharacteristicUuid) {
              if (characteristic.properties.write || characteristic.properties.writeWithoutResponse) {
                // Payload could be just a "1", or "PAIR:{user.uid}"
                // ESP32 must save its state to NVS upon receiving this.
                String command = "PAIR:${_user!.uid}"; // Example command
                await characteristic.write(utf8.encode(command), withoutResponse: !characteristic.properties.write);
                print("Pair command '$command' sent to ESP32 $esp32Id.");
                // For robust pairing, ESP32 should acknowledge.
                // For now, assume success if write doesn't throw.
                return true;
              }
            }
          }
        }
      }
      print("Pair command characteristic not found for ESP32 $esp32Id.");
      return false;
    } catch (e) {
      print("Error sending pair command to ESP32 $esp32Id: $e");
      return false;
    }
  }

  // Helper to update user's device connection status (session mainly)
  Future<void> _updateUserDeviceStatus(String esp32Id, String macAddress, bool isConnected, bool isBound) async {
    if (_user != null) {
      try {
        await _firestore.collection('users').doc(_user!.uid).update({
          'hasDeviceConnected': isConnected,
          'previouslyHasDeviceConnected': isBound ? true : FieldValue.delete(), // Keep true if bound, else remove or set based on logic
          // These should already be set if isBound is true from _performNewBinding
          // 'esp32Identifier': isBound ? esp32Id : FieldValue.delete(),
          // 'esp32MacAddress': isBound ? macAddress : FieldValue.delete(),
          // 'isDeviceBound': isBound ? true : FieldValue.delete(),
        });
        print("User device session status updated for UID: ${_user!.uid}, Connected: $isConnected");
      } catch (e) {
        print("Error updating user device session status: $e");
      }
    }
  }

  Future<void> _initializeDeviceConnectionFields() async {
    if (_user != null && !_hasInitializedDeviceFields) {
      try {
        // Only reset session-specific flags. Permanent binding info is preserved.
        await _firestore.collection('users').doc(_user!.uid).set({
          'hasDeviceConnected': false, // Reset for the current search/connect attempt session
        }, SetOptions(merge: true)); // Merge to not overwrite other fields like isDeviceBound

        setState(() { _hasInitializedDeviceFields = true; });
        print("Reset session device connection fields for UID: ${_user!.uid}");
      } catch (e) {
        print("Error resetting session device connection fields: $e");
      }
    }
  }

  @override
  void dispose() {
    _initialDelayTimer?.cancel();
    _scanResultsSubscription?.cancel();
    _adapterStateSubscription?.cancel();
    if (FlutterBluePlus.isScanningNow) {
      FlutterBluePlus.stopScan();
    }
    // If a device is connecting or binding, attempt to disconnect.
    // Check if _connectingDevice is not null before calling disconnect.
    if (_connectingDevice != null) {
      _connectingDevice!.disconnect().catchError((e) {
        print("Error on dispose disconnect: $e");
      });
    }
    super.dispose();
  }

  Widget _buildDeviceList() {
    // ...(UI logic remains largely the same as previous full example)
    // Ensure this part correctly reflects the scanning/found states
    if (_scanResults.isEmpty && _isActuallySearchingBluetooth && FlutterBluePlus.isScanningNow) {
      return _buildSearchingUI();
    }
    if (_scanResults.isEmpty && !_isActuallySearchingBluetooth && _noDeviceFoundByBluetooth) {
      return _buildNoDeviceFoundUI();
    }
    if (_scanResults.isEmpty && !_isActuallySearchingBluetooth && !_noDeviceFoundByBluetooth && FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bluetooth_disabled, size: 60, color: Colors.grey),
              const SizedBox(height: 20),
              const Text("Bluetooth is off.", style: TextStyle(fontSize: 18, color: Colors.black54)),
              const Text("Please turn on Bluetooth to scan for devices.", style: TextStyle(fontSize: 16, color: Colors.black54), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _initBluetooth, child: const Text("Retry Initialization"))
            ],
          )
      );
    }
    if (_scanResults.isEmpty && _isActuallySearchingBluetooth && !FlutterBluePlus.isScanningNow && !_noDeviceFoundByBluetooth) {
      // Scan might have timed out without explicitly setting noDeviceFound
      return _buildNoDeviceFoundUI();
    }


    return ListView.builder(
      itemCount: _scanResults.length,
      itemBuilder: (context, index) {
        final result = _scanResults[index];
        final deviceName = result.device.platformName.isNotEmpty
            ? result.device.platformName
            : 'Unknown Device';
        final deviceId = result.device.remoteId.toString();
        bool isConnectingThisDevice = _connectingDevice == result.device;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ListTile(
            leading: const Icon(Icons.bluetooth_searching, color: Colors.blue),
            title: Text(deviceName),
            subtitle: Text(deviceId),
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isConnectingThisDevice ? Colors.orangeAccent : Colors.blue,
              ),
              onPressed: (isConnectingThisDevice || (_connectingDevice != null && _connectingDevice != result.device))
                  ? null // Disable if connecting this or another device is already being connected/bound
                  : () => _connectToDevice(result.device),
              child: Text(isConnectingThisDevice ? 'BINDING...' : 'CONNECT & BIND'),
            ),
            onTap: (isConnectingThisDevice || (_connectingDevice != null && _connectingDevice != result.device))
                ? null
                : () => _connectToDevice(result.device),
          ),
        );
      },
    );
  }

  Widget _buildSearchingUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const Text('Searching for SmartVest...', //
            style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold, color: Colors.blue,), textAlign: TextAlign.center),
        const SizedBox(height: 10.0),
        const Text('Keep the device close to your phone and ensure it is powered on.', //
            style: TextStyle(fontSize: 16.0, color: Colors.black54), textAlign: TextAlign.center),
        const SizedBox(height: 30.0),
        const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.blue)), //
        const SizedBox(height: 30.0),
        OutlinedButton(
          onPressed: () {
            FlutterBluePlus.stopScan();
            if(mounted) Navigator.pop(context);
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 15.0, horizontal: 30),
            child: Text('Cancel', style: TextStyle(fontSize: 18.0, color: Colors.blue)), //
          ),
        ),
      ],
    );
  }

  Widget _buildNoDeviceFoundUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const Icon(Icons.bluetooth_disabled, color: Colors.redAccent, size: 60),
        const SizedBox(height: 20.0),
        const Text('No SmartVest Device Nearby', //
            style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold, color: Colors.redAccent), textAlign: TextAlign.center),
        const SizedBox(height: 10.0),
        const Text('Ensure your SmartVest is on, nearby, and Bluetooth is enabled. Then, try again.', //
            style: TextStyle(fontSize: 16.0, color: Colors.black54), textAlign: TextAlign.center),
        const SizedBox(height: 30.0),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _startScan,
            child: const Padding(padding: EdgeInsets.symmetric(vertical: 15.0),
                child: Text('Try Again', style: TextStyle(fontSize: 18.0))), //
          ),
        ),
        const SizedBox(height: 10.0),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/dashboard'), //
            child: const Padding(padding: EdgeInsets.symmetric(vertical: 15.0),
                child: Text('Skip for Now', style: TextStyle(fontSize: 18.0, color: Colors.blueGrey))),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: const Text('Connect SmartVest'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          if (FlutterBluePlus.isScanningNow)
            IconButton(icon: const Icon(Icons.stop_circle_outlined), onPressed: (){ FlutterBluePlus.stopScan(); }, tooltip: "Stop Scan")
          else if (!FlutterBluePlus.isScanningNow && _isActuallySearchingBluetooth) // Show refresh if not scanning but was trying
            IconButton(icon: const Icon(Icons.refresh), onPressed: _startScan, tooltip: "Rescan"),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Builder(
            builder: (context) {
              if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
                return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.bluetooth_disabled, size: 60, color: Colors.grey),
                        const SizedBox(height: 20),
                        const Text("Bluetooth is Off", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const Text("Please turn on Bluetooth to connect your SmartVest.", style: TextStyle(fontSize: 16, color: Colors.black54), textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        ElevatedButton(onPressed: () async {
                          // Attempt to turn on Bluetooth (Android only)
                          await FlutterBluePlus.turnOn();
                          // Re-check state or rely on adapterState listener
                          if(FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on && mounted){
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enable Bluetooth in your device settings.')),
                            );
                          }
                          // _initBluetooth(); // Could also re-trigger init
                        }, child: const Text("Turn On Bluetooth"))
                      ],
                    )
                );
              }
              if (_isActuallySearchingBluetooth && FlutterBluePlus.isScanningNow && _scanResults.isEmpty) {
                return _buildSearchingUI();
              } else if (_noDeviceFoundByBluetooth && _scanResults.isEmpty) {
                return _buildNoDeviceFoundUI();
              } else if (_scanResults.isNotEmpty) {
                return _buildDeviceList();
              }
              // Fallback for initial state before scan starts or if BT is off
              return _buildSearchingUI(); // Or a more specific "Initializing" UI
            },
          ),
        ),
      ),
    );
  }
}