import 'package:dart_ipify/dart_ipify.dart';
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Network Info App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Network Information'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String publicIp = 'Loading...';
  String localIp = 'Loading...';
  String ssid = 'Loading...';
  String bssid = 'Loading...';
  String connectionStatus = 'Loading...';
  bool isLoading = true;
  bool hasLocationPermission = false;
  bool hasNearbyWifiPermission = false;

  final NetworkInfo _networkInfo = NetworkInfo();
  final Connectivity _connectivity = Connectivity();
  Timer? _timer;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    // Skip permission checks on web
    if (kIsWeb) {
      setState(() {
        hasLocationPermission = false; // Not applicable for web
        hasNearbyWifiPermission = false; // Not applicable for web
      });
      await _loadNetworkInfo();
      _startRealtimeUpdates();
      _listenToConnectivityChanges();
      return;
    }

    bool locationGranted = false;
    bool nearbyWifiGranted = false;

    // Check location permission
    var locationStatus = await Permission.location.status;
    if (locationStatus.isDenied) {
      locationStatus = await Permission.location.request();
    }
    locationGranted = locationStatus.isGranted;

    // Check nearby wifi devices permission for Android 13+ (API 33+)
    // Only check this permission on mobile platforms
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        var nearbyWifiStatus = await Permission.nearbyWifiDevices.status;
        if (nearbyWifiStatus.isDenied) {
          nearbyWifiStatus = await Permission.nearbyWifiDevices.request();
        }
        nearbyWifiGranted = nearbyWifiStatus.isGranted;
      } catch (e) {
        // If permission is not available on this Android version, assume granted
        print('Nearby WiFi permission not available: $e');
        nearbyWifiGranted = true;
      }
    } else {
      nearbyWifiGranted = true; // Not needed for iOS
    }

    setState(() {
      hasLocationPermission = locationGranted;
      hasNearbyWifiPermission = nearbyWifiGranted;
    });

    // Load network info after permission check
    await _loadNetworkInfo();
    _startRealtimeUpdates();
    _listenToConnectivityChanges();
  }

  void _startRealtimeUpdates() {
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _loadNetworkInfo();
    });
  }

  void _listenToConnectivityChanges() {
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
      _loadNetworkInfo();
    });
  }

  Future<void> _loadNetworkInfo() async {
    try {
      // Get connectivity status
      final connectivityResult = await _connectivity.checkConnectivity();

      // Initialize variables
      String wifiName = 'Not available';
      String wifiBSSID = 'Not available';
      String wifiIP = 'Not available';

      // Check if we're on web platform
      if (kIsWeb) {
        // Web platform limitations
        wifiName = 'Not supported on web';
        wifiBSSID = 'Not supported on web';
        wifiIP = 'Not supported on web';
      } else {
        // Mobile/Desktop platforms
        // Check if we have the necessary permissions and are connected to WiFi
        if (connectivityResult == ConnectivityResult.wifi) {
          // Get WiFi IP (usually works without location permission)
          try {
            final ipValue = await _networkInfo.getWifiIP();
            wifiIP = ipValue ?? 'Not available';
          } catch (e) {
            print('Error getting WiFi IP: $e');
            wifiIP = 'Not available';
          }

          // Get WiFi SSID and BSSID (requires location permission)
          if (hasLocationPermission && hasNearbyWifiPermission) {
            try {
              final name = await _networkInfo.getWifiName();
              final bssidValue = await _networkInfo.getWifiBSSID();

              // Remove quotes from SSID if present
              wifiName = name?.replaceAll('"', '') ?? 'Not available';
              wifiBSSID = bssidValue ?? 'Not available';
            } catch (e) {
              print('Error getting WiFi info: $e');
              wifiName = 'Error: ${e.toString()}';
              wifiBSSID = 'Error: ${e.toString()}';
            }
          } else {
            wifiName = 'Permission required';
            wifiBSSID = 'Permission required';
          }
        } else {
          wifiName = 'Not connected to WiFi';
          wifiBSSID = 'Not connected to WiFi';
          wifiIP = 'Not connected to WiFi';
        }
      }

      // Get public IP
      String publicIpAddress = 'No connection';
      try {
        if (connectivityResult == ConnectivityResult.wifi ||
            connectivityResult == ConnectivityResult.mobile) {
          publicIpAddress = await Ipify.ipv4();
        }
      } catch (e) {
        print('Error getting public IP: $e');
        publicIpAddress = 'Failed to get public IP';
      }

      setState(() {
        publicIp = publicIpAddress;
        localIp = wifiIP;
        ssid = wifiName;
        bssid = wifiBSSID;
        connectionStatus = _getConnectionStatusText(connectivityResult);
        isLoading = false;
      });
    } catch (e) {
      print('Error loading network info: $e');
      setState(() {
        publicIp = 'Error: ${e.toString()}';
        localIp = 'Error';
        ssid = 'Error';
        bssid = 'Error';
        connectionStatus = 'Error getting status';
        isLoading = false;
      });
    }
  }

  String _getConnectionStatusText(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
        return 'WiFi Connected';
      case ConnectivityResult.mobile:
        return 'Mobile Data Connected';
      case ConnectivityResult.ethernet:
        return 'Ethernet Connected';
      case ConnectivityResult.bluetooth:
        return 'Bluetooth Connected';
      case ConnectivityResult.none:
        return 'No Connection';
      default:
        return 'Unknown Connection';
    }
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildPermissionCard() {
    // Don't show permission card on web
    if (kIsWeb) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        color: Colors.blue.shade50,
        child: ListTile(
          leading: Icon(Icons.info, color: Colors.blue.shade700),
          title: const Text(
            'Web Platform Limitations',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: const Text(
            'WiFi details (SSID, BSSID, Local IP) are not available on web browsers due to security restrictions. Only connection status and public IP are supported.',
            style: TextStyle(fontSize: 14),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      color: Colors.orange.shade50,
      child: ListTile(
        leading: Icon(Icons.warning, color: Colors.orange.shade700),
        title: const Text(
          'Permissions Required',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'To access WiFi SSID and BSSID information, please grant:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              '• Location permission: ${hasLocationPermission ? "✓ Granted" : "✗ Required"}',
              style: TextStyle(
                fontSize: 12,
                color: hasLocationPermission ? Colors.green : Colors.red,
              ),
            ),
            if (defaultTargetPlatform == TargetPlatform.android)
              Text(
                '• Nearby WiFi Devices permission: ${hasNearbyWifiPermission ? "✓ Granted" : "✗ Required"}',
                style: TextStyle(
                  fontSize: 12,
                  color: hasNearbyWifiPermission ? Colors.green : Colors.red,
                ),
              ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () async {
            await _requestPermissions();
          },
          child: const Text('Grant'),
        ),
      ),
    );
  }

  Future<void> _requestPermissions() async {
    // Skip permission request on web
    if (kIsWeb) {
      return;
    }

    // Request location permission
    if (!hasLocationPermission) {
      final locationResult = await Permission.location.request();
      setState(() {
        hasLocationPermission = locationResult.isGranted;
      });
    }

    // Request nearby wifi devices permission for Android 13+
    if (defaultTargetPlatform == TargetPlatform.android &&
        !hasNearbyWifiPermission) {
      try {
        final nearbyWifiResult = await Permission.nearbyWifiDevices.request();
        setState(() {
          hasNearbyWifiPermission = nearbyWifiResult.isGranted;
        });
      } catch (e) {
        print('Error requesting nearby WiFi permission: $e');
        // If permission is not available, assume granted
        setState(() {
          hasNearbyWifiPermission = true;
        });
      }
    }

    // If permissions are still not granted, show app settings
    if (!hasLocationPermission ||
        (defaultTargetPlatform == TargetPlatform.android &&
            !hasNearbyWifiPermission)) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Permissions Required'),
          content: const Text(
            'This app needs location and nearby WiFi devices permissions to access WiFi information. Please enable them in app settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    } else {
      // Reload network info if permissions are granted
      _loadNetworkInfo();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNetworkInfo,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadNetworkInfo,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // Show info card on web, permission card on mobile
                    if (kIsWeb ||
                        (!hasLocationPermission ||
                            (defaultTargetPlatform == TargetPlatform.android &&
                                !hasNearbyWifiPermission)))
                      _buildPermissionCard(),
                    _buildInfoCard('Connection Status', connectionStatus,
                        Icons.network_check),
                    _buildInfoCard('Public IP Address', publicIp, Icons.public),
                    _buildInfoCard('Local IP Address', localIp, Icons.computer),
                    _buildInfoCard('WiFi SSID', ssid, Icons.wifi),
                    _buildInfoCard('WiFi BSSID', bssid, Icons.router),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const Icon(Icons.autorenew, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Auto-refresh every 10 seconds',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
