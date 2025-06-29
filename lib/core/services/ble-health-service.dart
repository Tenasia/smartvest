// lib/core/services/ble_health_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:smartvest/core/services/mqtt_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BleHealthService {
  static final BleHealthService _instance = BleHealthService._internal();
  factory BleHealthService() => _instance;
  BleHealthService._internal();

  StreamSubscription<List<int>>? _healthDataSubscription;
  BluetoothDevice? _connectedDevice;
  String? _deviceId;
  final MqttService _mqttService = MqttService();

  // Statistics
  int _dataPacketsReceived = 0;
  int _mqttPublishCount = 0;
  int _mqttErrors = 0;
  String _lastReceivedData = "None";
  String _lastError = "None";

  // Status stream
  final StreamController<Map<String, dynamic>> _statusController =
  StreamController<Map<String, dynamic>>.broadcast();

  // Keep alive timer to maintain connection
  Timer? _keepAliveTimer;
  Timer? _statsTimer;

  Stream<Map<String, dynamic>> get statusStream => _statusController.stream;
  bool get isConnected => _connectedDevice != null && _healthDataSubscription != null;

  Map<String, dynamic> get stats => {
    'dataPacketsReceived': _dataPacketsReceived,
    'mqttPublishCount': _mqttPublishCount,
    'mqttErrors': _mqttErrors,
    'lastReceivedData': _lastReceivedData,
    'lastError': _lastError,
    'isConnected': isConnected,
  };

  Future<bool> startHealthDataMonitoring(
      BluetoothDevice device,
      String deviceId,
      BluetoothCharacteristic healthDataCharacteristic
      ) async {
    try {
      // Stop any existing monitoring
      await stopHealthDataMonitoring();

      _connectedDevice = device;
      _deviceId = deviceId;

      if (!healthDataCharacteristic.properties.notify) {
        debugPrint('BLE_HEALTH_SERVICE:: Health data characteristic does not support notifications.');
        _updateStatus('error', 'Health characteristic doesn\'t support notifications');
        return false;
      }

      // Store device info for persistence
      await _storeDeviceInfo(device.remoteId.toString(), deviceId);

      await healthDataCharacteristic.setNotifyValue(true);
      debugPrint('BLE_HEALTH_SERVICE:: Subscribed to health data notifications.');
      _updateStatus('connected', 'Subscribed to health data notifications');

      _healthDataSubscription = healthDataCharacteristic.onValueReceived.listen(
              (value) async {
            await _handleHealthData(value);
          },
          onError: (e) {
            debugPrint('BLE_HEALTH_SERVICE:: Error receiving health data notifications: $e');
            _lastError = "Notification: $e";
            _updateStatus('error', 'Error receiving notifications: $e');
            _attemptReconnection();
          },
          onDone: () {
            debugPrint('BLE_HEALTH_SERVICE:: Health data subscription done.');
            _updateStatus('disconnected', 'Health data subscription ended');
            _healthDataSubscription?.cancel();
            _healthDataSubscription = null;
            _attemptReconnection();
          }
      );

      // Start keep-alive and stats timers
      _startKeepAliveTimer();
      _startStatsTimer();

      return true;
    } catch (e) {
      debugPrint('BLE_HEALTH_SERVICE:: Failed to start health data monitoring: $e');
      _lastError = "Start monitoring: $e";
      _updateStatus('error', 'Failed to start monitoring: $e');
      return false;
    }
  }

  void _startKeepAliveTimer() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkConnectionHealth();
    });
  }

  void _startStatsTimer() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _updateStatus('stats_update', 'Regular stats update');
    });
  }

  Future<void> _checkConnectionHealth() async {
    if (_connectedDevice != null) {
      try {
        final connectionState = await _connectedDevice!.connectionState.first;
        if (connectionState != BluetoothConnectionState.connected) {
          debugPrint('BLE_HEALTH_SERVICE:: Device disconnected, attempting reconnection...');
          _attemptReconnection();
        } else {
          debugPrint('BLE_HEALTH_SERVICE:: Connection health check passed');
        }
      } catch (e) {
        debugPrint('BLE_HEALTH_SERVICE:: Error checking connection health: $e');
        _attemptReconnection();
      }
    }
  }

  Future<void> _attemptReconnection() async {
    if (_connectedDevice == null || _deviceId == null) return;

    debugPrint('BLE_HEALTH_SERVICE:: Attempting to reconnect...');
    _updateStatus('reconnecting', 'Attempting to reconnect to device');

    try {
      // Try to reconnect
      await _connectedDevice!.connect(timeout: const Duration(seconds: 10));

      // Rediscover services and restart monitoring
      final services = await _connectedDevice!.discoverServices();
      for (final service in services) {
        if (service.uuid == Guid("12345678-1234-1234-1234-123456789abc")) {
          for (final char in service.characteristics) {
            if (char.uuid == Guid("87654321-4321-4321-4321-cba987654321")) {
              await startHealthDataMonitoring(_connectedDevice!, _deviceId!, char);
              return;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('BLE_HEALTH_SERVICE:: Reconnection failed: $e');
      _updateStatus('error', 'Reconnection failed: $e');

      // Try again in 10 seconds
      Timer(const Duration(seconds: 10), () {
        _attemptReconnection();
      });
    }
  }

  Future<void> _storeDeviceInfo(String deviceAddress, String deviceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ble_device_address', deviceAddress);
      await prefs.setString('ble_device_id', deviceId);
      await prefs.setString('ble_connection_timestamp', DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('BLE_HEALTH_SERVICE:: Error storing device info: $e');
    }
  }

  Future<void> _handleHealthData(List<int> value) async {
    _dataPacketsReceived++;

    // Log raw bytes for debugging
    debugPrint('BLE_HEALTH_SERVICE:: Raw BLE bytes received (${value.length} bytes): $value');

    // Convert to string
    String payload;
    try {
      payload = String.fromCharCodes(value).trim();
      debugPrint('BLE_HEALTH_SERVICE:: Converted BLE payload: "$payload"');

      _lastReceivedData = payload.length > 50 ? "${payload.substring(0, 50)}..." : payload;
      _updateStatus('data_received', 'Received packet #$_dataPacketsReceived');

      // Store latest data
      await _storeLatestHealthData(payload);

    } catch (e) {
      debugPrint('BLE_HEALTH_SERVICE:: Error converting bytes to string: $e');
      _lastError = "String conversion: $e";
      _updateStatus('error', 'String conversion error');
      return;
    }

    // Validate JSON
    try {
      final jsonData = jsonDecode(payload);
      debugPrint('BLE_HEALTH_SERVICE:: Payload is valid JSON with keys: ${jsonData.keys.join(', ')}');
    } catch (e) {
      debugPrint('BLE_HEALTH_SERVICE:: Payload is NOT valid JSON. Error: $e');
      debugPrint('BLE_HEALTH_SERVICE:: Raw payload: "$payload"');
      _lastError = "Invalid JSON: $e";
      _updateStatus('error', 'Invalid JSON received');
      return;
    }

    // Publish to MQTT
    if (_deviceId != null) {
      try {
        await _mqttService.connectAndPublish(_deviceId!, payload);
        _mqttPublishCount++;
        debugPrint('BLE_HEALTH_SERVICE:: Successfully published to MQTT (#$_mqttPublishCount)');
        _updateStatus('mqtt_published', 'Published packet #$_mqttPublishCount to MQTT');
      } catch (e) {
        _mqttErrors++;
        _lastError = "MQTT: $e";
        debugPrint('BLE_HEALTH_SERVICE:: Error publishing to MQTT: $e');
        _updateStatus('error', 'MQTT publish error: $e');
      }
    }
  }

  Future<void> _storeLatestHealthData(String payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('latest_health_data', payload);
      await prefs.setString('latest_health_data_timestamp', DateTime.now().toIso8601String());
      await prefs.setInt('total_packets_received', _dataPacketsReceived);
      await prefs.setInt('total_mqtt_published', _mqttPublishCount);
    } catch (e) {
      debugPrint('BLE_HEALTH_SERVICE:: Error storing health data: $e');
    }
  }

  void _updateStatus(String status, String message) {
    _statusController.add({
      'status': status,
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
      'stats': stats,
    });
  }

  /// Get stored device info (useful when app restarts)
  Future<Map<String, String?>> getStoredDeviceInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'deviceAddress': prefs.getString('ble_device_address'),
        'deviceId': prefs.getString('ble_device_id'),
        'connectionTimestamp': prefs.getString('ble_connection_timestamp'),
        'latestHealthData': prefs.getString('latest_health_data'),
        'latestTimestamp': prefs.getString('latest_health_data_timestamp'),
      };
    } catch (e) {
      debugPrint('BLE_HEALTH_SERVICE:: Error getting stored device info: $e');
      return {};
    }
  }

  /// Get stored statistics
  Future<Map<String, int>> getStoredStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'totalPacketsReceived': prefs.getInt('total_packets_received') ?? 0,
        'totalMqttPublished': prefs.getInt('total_mqtt_published') ?? 0,
      };
    } catch (e) {
      debugPrint('BLE_HEALTH_SERVICE:: Error getting stored stats: $e');
      return {};
    }
  }

  /// Resume monitoring from stored data (useful on app restart)
  Future<bool> resumeMonitoringFromStorage() async {
    try {
      final storedData = await getStoredDeviceInfo();
      final deviceAddress = storedData['deviceAddress'];
      final deviceId = storedData['deviceId'];

      if (deviceAddress != null && deviceId != null) {
        debugPrint('BLE_HEALTH_SERVICE:: Attempting to resume monitoring for device: $deviceId');

        // Load stored stats
        final storedStats = await getStoredStats();
        _dataPacketsReceived = storedStats['totalPacketsReceived'] ?? 0;
        _mqttPublishCount = storedStats['totalMqttPublished'] ?? 0;

        // Try to reconnect to the stored device
        final connectedDevices = FlutterBluePlus.connectedDevices;
        for (final device in connectedDevices) {
          if (device.remoteId.toString() == deviceAddress) {
            debugPrint('BLE_HEALTH_SERVICE:: Found previously connected device, attempting to resume monitoring');

            // Try to find the health data characteristic
            final services = await device.discoverServices();
            for (final service in services) {
              if (service.uuid == Guid("12345678-1234-1234-1234-123456789abc")) {
                for (final char in service.characteristics) {
                  if (char.uuid == Guid("87654321-4321-4321-4321-cba987654321")) {
                    return await startHealthDataMonitoring(device, deviceId, char);
                  }
                }
              }
            }
          }
        }

        // If not found in connected devices, try to scan and reconnect
        _updateStatus('scanning', 'Scanning for previously connected device');
        return false; // Let the main app handle reconnection
      }

      return false;
    } catch (e) {
      debugPrint('BLE_HEALTH_SERVICE:: Error resuming monitoring from storage: $e');
      return false;
    }
  }

  Future<void> stopHealthDataMonitoring() async {
    _keepAliveTimer?.cancel();
    _statsTimer?.cancel();

    if (_healthDataSubscription != null) {
      await _healthDataSubscription!.cancel();
      _healthDataSubscription = null;
      debugPrint('BLE_HEALTH_SERVICE:: Stopped health data monitoring');
      _updateStatus('disconnected', 'Health data monitoring stopped');
    }

    if (_connectedDevice != null) {
      try {
        await _connectedDevice!.disconnect();
      } catch (e) {
        debugPrint('BLE_HEALTH_SERVICE:: Error disconnecting device: $e');
      }
      _connectedDevice = null;
    }

    _deviceId = null;
  }

  /// Clear all stored data
  Future<void> clearStoredData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('ble_device_address');
      await prefs.remove('ble_device_id');
      await prefs.remove('ble_connection_timestamp');
      await prefs.remove('latest_health_data');
      await prefs.remove('latest_health_data_timestamp');
      await prefs.remove('total_packets_received');
      await prefs.remove('total_mqtt_published');
    } catch (e) {
      debugPrint('BLE_HEALTH_SERVICE:: Error clearing stored data: $e');
    }
  }

  void dispose() {
    stopHealthDataMonitoring();
    _statusController.close();
  }
}
