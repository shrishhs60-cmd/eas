import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/environmental_model.dart';

class EcoApiService {
  // 127.0.0.1 for Windows Desktop & Web; 10.0.2.2 for Android Emulator
  static String baseUrl = 'http://127.0.0.1:8000';

  static void setBaseUrl(String url) {
    baseUrl = url;
  }

  /// Fetches complete dashboard data for a given location.
  static Future<DashboardData> fetchDashboard({String location = 'Alandur Bus Depot, Chennai'}) async {
    final uri = Uri.parse('$baseUrl/api/dashboard?location=${Uri.encodeComponent(location)}');

    try {
      final response = await http.get(uri).timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return DashboardData.fromJson(data);
      } else {
        if (kDebugMode) {
          print('Backend returned status: ${response.statusCode}');
        }
        return DashboardData.fallback(location: location);
      }
    } catch (e) {
      if (kDebugMode) {
        print('EcoApiService fetchDashboard error: $e');
      }
      return DashboardData.fallback(location: location);
    }
  }

  /// Fetches all 26 registered Greater Chennai CAAQMS & NWMP stations.
  static Future<List<LocationItem>> fetchLocations() async {
    final uri = Uri.parse('$baseUrl/api/locations');

    try {
      final response = await http.get(uri).timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((item) => LocationItem.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        print('EcoApiService fetchLocations error: $e');
      }
    }

    return [];
  }

  /// Triggers full satellite telemetry synchronization across all 26 stations
  static Future<Map<String, dynamic>?> triggerSatelliteSync() async {
    final uri = Uri.parse('$baseUrl/api/realtime/sync');
    try {
      final response = await http.post(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      }
    } catch (e) {
      if (kDebugMode) {
        print('EcoApiService triggerSatelliteSync error: $e');
      }
    }
    return null;
  }

  /// Fetches live atmospheric telemetry status (Open-Meteo satellite feed)
  static Future<Map<String, dynamic>?> fetchLiveStatus() async {
    final uri = Uri.parse('$baseUrl/api/realtime/live-status');
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      }
    } catch (e) {
      if (kDebugMode) {
        print('EcoApiService fetchLiveStatus error: $e');
      }
    }
    return null;
  }

  /// Fetches the live telemetry feed for all stations including wind & exceedances
  static Future<Map<String, dynamic>?> fetchLiveTelemetryFeed() async {
    final uri = Uri.parse('$baseUrl/api/telemetry/live-feed');
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      }
    } catch (e) {
      if (kDebugMode) {
        print('EcoApiService fetchLiveTelemetryFeed error: $e');
      }
    }
    return null;
  }

  /// Submits a citizen pollution grievance to the backend
  static Future<Map<String, dynamic>?> submitGrievance({
    required String reporterName,
    required String incidentLocation,
    required String incidentType,
    String? description,
    String? contactPhone,
  }) async {
    final uri = Uri.parse('$baseUrl/api/grievances');
    try {
      final payload = {
        'reporter_name': reporterName,
        'incident_location': incidentLocation,
        'incident_type': incidentType,
        'description': description ?? '',
        'contact_phone': contactPhone ?? '',
      };
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      }
    } catch (e) {
      if (kDebugMode) {
        print('EcoApiService submitGrievance error: $e');
      }
    }
    return null;
  }

  /// Checks if backend server is online
  static Future<bool> isBackendOnline() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/realtime/live-status')).timeout(
        const Duration(seconds: 3),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
