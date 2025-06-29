// lib/core/services/esp32_time_sync_helper.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Esp32TimeSyncHelper {
  static Future<bool> syncTimeAndUserData(
      BluetoothDevice device,
      String esp32ServiceUuid,
      String pairCommandCharacteristicUuid,
      ) async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint('ESP32_SYNC:: No user logged in');
        return false;
      }

      List<BluetoothService> services = await device.discoverServices();
      BluetoothCharacteristic? pairCharacteristic;

      // Find the pair command characteristic
      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase() == esp32ServiceUuid.toLowerCase()) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() == pairCommandCharacteristicUuid.toLowerCase()) {
              pairCharacteristic = characteristic;
              break;
            }
          }
        }
        if (pairCharacteristic != null) break;
      }

      if (pairCharacteristic == null) {
        debugPrint('ESP32_SYNC:: Pair characteristic not found');
        return false;
      }

      // Send multiple commands to ESP32
      final commands = await _generateSyncCommands(currentUser.uid);

      for (String command in commands) {
        try {
          await pairCharacteristic.write(
              utf8.encode(command),
              withoutResponse: !pairCharacteristic.properties.write
          );
          debugPrint('ESP32_SYNC:: Sent command: $command');

          // Small delay between commands
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          debugPrint('ESP32_SYNC:: Error sending command "$command": $e');
        }
      }

      return true;
    } catch (e) {
      debugPrint('ESP32_SYNC:: Error in syncTimeAndUserData: $e');
      return false;
    }
  }

  static Future<List<String>> _generateSyncCommands(String userId) async {
    final now = DateTime.now();
    final epochTime = now.millisecondsSinceEpoch ~/ 1000;
    final timezoneOffset = now.timeZoneOffset.inHours;
    final humanTime = now.toIso8601String();

    return [
      'PAIR:$userId',
      'TIME:$epochTime',
      'TIMEZONE:$timezoneOffset',
      'USER_ID:$userId',
      'HUMAN_TIME:$humanTime',
      'SYNC_COMPLETE:true',
    ];
  }

  static Map<String, dynamic> validateAndEnhanceHealthData(
      Map<String, dynamic> data,
      String userId,
      ) {
    final now = DateTime.now();
    final epochTime = now.millisecondsSinceEpoch ~/ 1000;

    // Ensure user_id is set
    data['user_id'] = userId;

    // Fix time-related fields if they're invalid
    if (data['time_valid'] != true ||
        data['human_time'] == null ||
        data['human_time'] == 'TIME_NOT_SET') {
      data['human_time'] = now.toIso8601String();
      data['time_valid'] = true;
      data['server_corrected_time'] = true;
    }

    // Ensure epoch_time is valid
    if (data['epoch_time'] == null || data['epoch_time'] == 0) {
      data['epoch_time'] = epochTime;
      data['server_corrected_epoch'] = true;
    }

    // Add server metadata
    data['server_received_at'] = now.toIso8601String();
    data['server_epoch_received'] = epochTime;

    return data;
  }
}
