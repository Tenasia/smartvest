// lib/core/services/mqtt_service.dart

import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  // Singleton pattern
  static final MqttService _instance = MqttService._internal();
  factory MqttService() => _instance;
  MqttService._internal();

  // IMPORTANT: Use your own broker or a private one for production.
  // For testing, you can use a public broker like 'broker.emqx.io'
  final String _broker = 'broker.emqx.io';
  final int _port = 1883;
  // Use a dynamic client identifier to avoid conflicts if multiple app instances connect
  final String _clientIdentifier = 'smartvest-flutter-app-${DateTime.now().millisecondsSinceEpoch}';

  MqttServerClient? _client;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Track current subscription to avoid unnecessary re-subscriptions
  String? _currentSubscriptionTopic;

  // Debug counters
  int _publishCount = 0;
  int _receiveCount = 0;
  int _saveCount = 0;

  // Connect to the MQTT broker and subscribe to the device's topic
  Future<void> connectAndSubscribe(String deviceId) async {
    final String topic = 'smartvest/data/$deviceId';

    if (_client != null && _client!.connectionStatus!.state == MqttConnectionState.connected) {
      debugPrint('MQTT_SERVICE:: Already connected.');
      if (_currentSubscriptionTopic != topic) {
        if (_currentSubscriptionTopic != null) {
          _client!.unsubscribe(_currentSubscriptionTopic!);
          debugPrint('MQTT_SERVICE:: Unsubscribed from previous topic: $_currentSubscriptionTopic');
        }
        debugPrint('MQTT_SERVICE:: Subscribing to new topic: $topic');
        _client!.subscribe(topic, MqttQos.atLeastOnce);
        _currentSubscriptionTopic = topic;
      }
      return;
    }

    _client = MqttServerClient(_broker, _clientIdentifier);
    _client!.port = _port;
    _client!.keepAlivePeriod = 60;
    _client!.logging(on: kDebugMode); // Enable logging in debug mode
    _client!.onConnected = _onConnected;
    _client!.onDisconnected = _onDisconnected;
    _client!.onSubscribed = _onSubscribed;
    _client!.onSubscribeFail = (topic) => debugPrint('MQTT_SERVICE:: Failed to subscribe to $topic');
    _client!.pongCallback = () => debugPrint('MQTT_SERVICE:: Pong received');

    _client!.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(_clientIdentifier)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    try {
      debugPrint('MQTT_SERVICE:: Connecting to broker $_broker:$_port...');
      await _client!.connect();
    } catch (e) {
      debugPrint('MQTT_SERVICE:: Connection exception: $e');
      _client!.disconnect();
      _client = null;
      return;
    }

    debugPrint('MQTT_SERVICE:: Subscribing to topic: $topic');
    _client!.subscribe(topic, MqttQos.atLeastOnce);
    _currentSubscriptionTopic = topic;

    // Listen for incoming messages
    _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      if (c != null && c.isNotEmpty) {
        final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
        final String payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        final String receivedTopic = c[0].topic;

        _receiveCount++;
        debugPrint('MQTT_SERVICE:: Received message #$_receiveCount: $payload from topic: $receivedTopic');
        _handleIncomingMessage(payload);
      }
    });
  }

  // New method to publish data to an MQTT topic
  Future<void> connectAndPublish(String deviceId, String payload) async {
    if (_client == null || _client!.connectionStatus!.state != MqttConnectionState.connected) {
      debugPrint('MQTT_SERVICE:: Not connected for publishing. Attempting to connect...');
      await connectAndSubscribe(deviceId);
      await Future.delayed(const Duration(milliseconds: 500));
      if (_client == null || _client!.connectionStatus!.state != MqttConnectionState.connected) {
        debugPrint('MQTT_SERVICE:: Failed to connect to broker for publishing.');
        throw Exception('Failed to connect to MQTT broker');
      }
    }

    final topic = 'smartvest/data/$deviceId';
    final MqttClientPayloadBuilder builder = MqttClientPayloadBuilder();
    builder.addString(payload);

    _publishCount++;
    debugPrint('MQTT_SERVICE:: Publishing message #$_publishCount to topic: $topic');
    debugPrint('MQTT_SERVICE:: Payload: $payload');

    try {
      _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      debugPrint('MQTT_SERVICE:: Successfully published message #$_publishCount');
    } catch (e) {
      debugPrint('MQTT_SERVICE:: Error publishing message: $e');
      throw e;
    }
  }

  void _onConnected() {
    debugPrint('MQTT_SERVICE:: ✅ Connected to broker $_broker:$_port');
  }

  void _onDisconnected() {
    debugPrint('MQTT_SERVICE:: ❌ Disconnected from broker.');
    _client = null;
    _currentSubscriptionTopic = null;
  }

  void _onSubscribed(String topic) {
    debugPrint('MQTT_SERVICE:: ✅ Subscribed to topic: $topic');
    _currentSubscriptionTopic = topic;
  }

  // Handle the data received from ESP32 (now via MQTT, published by this app)
  void _handleIncomingMessage(String payload) {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint('MQTT_SERVICE:: No user logged in. Ignoring message.');
      return;
    }

    try {
      // Decode the JSON payload from the ESP32
      Map<String, dynamic> data = jsonDecode(payload);
      debugPrint('MQTT_SERVICE:: Decoded JSON data: ${data.keys.join(', ')}');

      // Ensure user_id is set (override if empty or missing)
      data['user_id'] = currentUser.uid;

      // Add server-side timestamp and epoch time
      final int epochTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      data['server_timestamp'] = ServerValue.timestamp;
      data['server_epoch_time'] = epochTime;

      // If human_time is not set or invalid, set it from server
      if (data['human_time'] == null ||
          data['human_time'] == 'TIME_NOT_SET' ||
          data['time_valid'] == false) {
        data['human_time'] = DateTime.now().toIso8601String();
        data['time_valid'] = true;
        debugPrint('MQTT_SERVICE:: Set human_time from server: ${data['human_time']}');
      }

      // Ensure epoch_time is valid
      if (data['epoch_time'] == null || data['epoch_time'] == 0) {
        data['epoch_time'] = epochTime;
        debugPrint('MQTT_SERVICE:: Set epoch_time from server: $epochTime');
      }

      // Save to Firebase Realtime Database with enhanced structure
      final String dataKey = '${currentUser.uid}_$epochTime';
      _database.ref('healthMonitor/data/$dataKey').set(data).then((_) {
        _saveCount++;
        debugPrint('MQTT_SERVICE:: ✅ Data #$_saveCount successfully saved to Firebase RTDB with key: $dataKey');
      }).catchError((error) {
        debugPrint('MQTT_SERVICE:: ❌ Error saving to Firebase RTDB: $error');
      });

      // Also save to user-specific path for easier querying
      _database.ref('users/${currentUser.uid}/healthData/$epochTime').set(data).then((_) {
        debugPrint('MQTT_SERVICE:: ✅ Data also saved to user-specific path');
      }).catchError((error) {
        debugPrint('MQTT_SERVICE:: ❌ Error saving to user-specific path: $error');
      });

    } catch (e) {
      debugPrint('MQTT_SERVICE:: ❌ Could not decode JSON payload or save to Firebase: $e');
      debugPrint('MQTT_SERVICE:: Raw payload: $payload');
    }
  }

  // Get debug statistics
  Map<String, int> getDebugStats() {
    return {
      'published': _publishCount,
      'received': _receiveCount,
      'saved': _saveCount,
    };
  }

  // Disconnect from the MQTT broker
  void disconnect() {
    if (_client != null) {
      _client!.disconnect();
      _client = null;
      _currentSubscriptionTopic = null;
      debugPrint('MQTT_SERVICE:: Disconnect called.');
    }
  }
}
