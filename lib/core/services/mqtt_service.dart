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
  final String _clientIdentifier = 'smartvest-flutter-app-${DateTime.now().millisecondsSinceEpoch}';

  MqttServerClient? _client;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Connect to the MQTT broker and subscribe to the device's topic
  Future<void> connectAndSubscribe(String deviceId) async {
    if (_client != null && _client!.connectionStatus!.state == MqttConnectionState.connected) {
      debugPrint('MQTT_SERVICE:: Already connected.');
      return;
    }

    _client = MqttServerClient(_broker, _clientIdentifier);
    _client!.port = _port;
    _client!.keepAlivePeriod = 60;
    _client!.logging(on: false); // Disable for production
    _client!.onConnected = _onConnected;
    _client!.onDisconnected = _onDisconnected;
    _client!.onSubscribed = _onSubscribed;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(_clientIdentifier)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    try {
      debugPrint('MQTT_SERVICE:: Connecting to broker...');
      await _client!.connect(null, connMessage as String);
    } catch (e) {
      debugPrint('MQTT_SERVICE:: Exception: $e');
      _client!.disconnect();
      _client = null;
      return;
    }

    // Subscribe to the topic for the specific device
    final topic = 'smartvest/data/$deviceId';
    debugPrint('MQTT_SERVICE:: Subscribing to topic: $topic');
    _client!.subscribe(topic, MqttQos.atLeastOnce);

    // Listen for incoming messages
    _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      if (c != null && c.isNotEmpty) {
        final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
        final String payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

        debugPrint('MQTT_SERVICE:: Received message: $payload from topic: ${c[0].topic}');
        _handleIncomingMessage(payload);
      }
    });
  }

  void _onConnected() {
    debugPrint('MQTT_SERVICE:: Connected to broker.');
  }

  void _onDisconnected() {
    debugPrint('MQTT_SERVICE:: Disconnected from broker.');
    _client = null;
  }

  void _onSubscribed(String topic) {
    debugPrint('MQTT_SERVICE:: Subscribed to topic: $topic');
  }

  // Handle the data received from ESP32
  void _handleIncomingMessage(String payload) {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint('MQTT_SERVICE:: No user logged in. Ignoring message.');
      return;
    }

    try {
      // Decode the JSON payload from the ESP32
      Map<String, dynamic> data = jsonDecode(payload);

      // Add user-specific and server-side data
      final int epochTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      data['userId'] = currentUser.uid;
      data['timestamp'] = ServerValue.timestamp; // Use Firebase server timestamp for accuracy
      data['epochTime'] = epochTime; // Also store a client-side epoch time for keys

      // Save to Firebase Realtime Database
      // The key is the epoch time in seconds as a string, matching your existing structure
      _database.ref('healthMonitor/data/$epochTime').set(data).then((_) {
        debugPrint('MQTT_SERVICE:: Data successfully saved to Firebase RTDB.');
      }).catchError((error) {
        debugPrint('MQTT_SERVICE:: Error saving to Firebase RTDB: $error');
      });

    } catch (e) {
      debugPrint('MQTT_SERVICE:: Could not decode JSON payload or save to Firebase: $e');
    }
  }

  // Disconnect from the MQTT broker
  void disconnect() {
    if (_client != null) {
      _client!.disconnect();
      _client = null;
      debugPrint('MQTT_SERVICE:: Disconnect called.');
    }
  }
}