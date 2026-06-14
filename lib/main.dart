import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;


class AppConfig {
  static const String baseUrl = String.fromEnvironment(
    "API_URL",
    defaultValue: "localhost:3000",
  );
  
  static String get httpUrl => baseUrl.startsWith("http") ? baseUrl : "http://" + baseUrl;
  static String get wsUrl => baseUrl.startsWith("http") 
      ? baseUrl.replaceFirst("http", "ws") 
      : "ws://" + baseUrl;
}

void main() {
  runApp(const FleetFlowApp());
}

class FleetFlowApp extends StatelessWidget {
  const FleetFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FleetFlow Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.purple,
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final Map<String, dynamic> _assets = {};
  WebSocketChannel? _channel;
  bool _isConnected = false;

  final List<LatLng> _geofencePoints = [
    const LatLng(37.785, -122.410),
    const LatLng(37.795, -122.410),
    const LatLng(37.795, -122.390),
    const LatLng(37.785, -122.390),
  ];

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
    _fetchInitialAssets();
  }

  void _connectWebSocket() {
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse(AppConfig.wsUrl),
      );
      _channel!.stream.listen((message) {
        final decoded = jsonDecode(message);
        if (decoded['type'] == 'TELEMETRY' || decoded['type'] == 'INIT') {
          setState(() {
            if (decoded['type'] == 'INIT') {
              for (var asset in decoded['data']) {
                _assets[asset['id']] = asset;
              }
            } else {
              final asset = decoded['data'];
              _assets[asset['id']] = asset;
            }
          });
        }
      }, onError: (err) {
        debugPrint('WS Error: ');
        setState(() => _isConnected = false);
        Future.delayed(const Duration(seconds: 5), _connectWebSocket);
      }, onDone: () {
        setState(() => _isConnected = false);
        Future.delayed(const Duration(seconds: 5), _connectWebSocket);
      });
      setState(() => _isConnected = true);
    } catch (e) {
      debugPrint('WS Connection error: ');
      Future.delayed(const Duration(seconds: 5), _connectWebSocket);
    }
  }

  Future<void> _fetchInitialAssets() async {
    try {
      final response = await http.get(Uri.parse(AppConfig.httpUrl + '/api/assets'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          for (var asset in data) {
            _assets[asset['id']] = asset;
          }
        });
      }
    } catch (e) {
      debugPrint('Fetch error: ');
    }
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assetList = _assets.values.toList();
    final breachCount = assetList.where((a) => a['status'] == 'BREACH').length;

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 300,
            color: Colors.grey[900],
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'FleetFlow Dashboard',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.purple[300]),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.circle, size: 12, color: _isConnected ? Colors.green : Colors.red),
                          const SizedBox(width: 8),
                          Text(_isConnected ? 'Connected' : 'Disconnected', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (breachCount > 0)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.warning, color: Colors.white),
                        const SizedBox(height: 4),
                        Text(
                          'GEOFENCE BREACH: ' + breachCount.toString() + ' ASSETS',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: ListView.separated(
                    itemCount: assetList.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final asset = assetList[index];
                      final isBreach = asset['status'] == 'BREACH';
                      return ListTile(
                        leading: Icon(
                          asset['id'].contains('Truck') ? Icons.local_shipping : Icons.airplanemode_active,
                          color: isBreach ? Colors.red : Colors.blue,
                        ),
                        title: Text(asset['id'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(asset['lat'].toStringAsFixed(4) + ', ' + asset['lng'].toStringAsFixed(4)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isBreach ? Colors.red[900] : Colors.green[900],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            asset['status'],
                            style: const TextStyle(fontSize: 10, color: Colors.white),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: const LatLng(37.790, -122.400),
                initialZoom: 14.5,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.fleet_flow',
                  tileProvider: NetworkTileProvider(headers: {'User-Agent': 'FleetFlow Dashboard'}),
                ),
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: _geofencePoints,
                      color: Colors.purple.withAlpha(50),
                      borderColor: Colors.purple,
                      borderStrokeWidth: 3,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: assetList.map((asset) {
                    final isBreach = asset['status'] == 'BREACH';
                    return Marker(
                      point: LatLng(asset['lat'], asset['lng']),
                      width: 40,
                      height: 40,
                      child: Icon(
                        asset['id'].contains('Truck') ? Icons.local_shipping : Icons.airplanemode_active,
                        color: isBreach ? Colors.red : Colors.blueAccent,
                        size: 24,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}