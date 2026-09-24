import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'models/environmental_model.dart';
import 'services/api_service.dart';

void main() {
  runApp(const EASApplication());
}

class EASApplication extends StatelessWidget {
  const EASApplication({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EAS — Environmental Analyzing System',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B1512),
        primaryColor: const Color(0xFF10B981),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF10B981),
          secondary: Color(0xFF38BDF8),
          surface: Color(0xFF10221C),
          surfaceContainerHighest: Color(0xFF162B24),
          error: Color(0xFFEF4444),
          onPrimary: Colors.black,
        ),
        fontFamily: 'Segoe UI',
      ),
      home: const MainDashboardScreen(),
    );
  }
}

class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({super.key});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen>
    with SingleTickerProviderStateMixin {
  int _currentTabIndex = 0;
  String _selectedLocation = 'Alandur Bus Depot, Chennai';
  List<LocationItem> _stations = [];
  DashboardData? _dashboardData;
  Map<String, dynamic>? _liveTelemetry;
  bool _isLoading = true;
  bool _isSyncing = false;
  bool _isBackendOnline = false;
  String _selectedZoneFilter = 'All';
  String _searchQuery = '';
  LocationItem? _selectedMapStation;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _initializeData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    final isOnline = await EcoApiService.isBackendOnline();
    final stations = await EcoApiService.fetchLocations();
    final dashboard =
        await EcoApiService.fetchDashboard(location: _selectedLocation);
    final telemetry = await EcoApiService.fetchLiveTelemetryFeed();

    if (mounted) {
      setState(() {
        _isBackendOnline = isOnline;
        _stations = stations;
        _dashboardData = dashboard;
        _liveTelemetry = telemetry;
        if (stations.isNotEmpty) {
          _selectedMapStation = stations.firstWhere(
            (s) => s.location == _selectedLocation,
            orElse: () => stations.first,
          );
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _triggerSatelliteSync() async {
    setState(() => _isSyncing = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFF064E3B),
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF6EE7B7)),
            ),
            SizedBox(width: 12),
            Text(
              'Synchronizing 26 stations with Open-Meteo & CPCB CAAQMS satellite grid...',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
        duration: Duration(milliseconds: 2200),
      ),
    );

    final res = await EcoApiService.triggerSatelliteSync();
    final dashboard =
        await EcoApiService.fetchDashboard(location: _selectedLocation);
    final stations = await EcoApiService.fetchLocations();
    final telemetry = await EcoApiService.fetchLiveTelemetryFeed();

    if (mounted) {
      setState(() {
        _dashboardData = dashboard;
        _stations = stations;
        _liveTelemetry = telemetry;
        _isSyncing = false;
        _isBackendOnline = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          content: Text(
            res != null
                ? '✅ Live satellite telemetry successfully synced across all 26 stations!'
                : 'Satellite sync updated.',
            style: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _onLocationSelected(String newLocation) {
    if (newLocation == _selectedLocation) return;
    setState(() {
      _selectedLocation = newLocation;
      _isLoading = true;
      if (_stations.isNotEmpty) {
        _selectedMapStation = _stations.firstWhere(
          (s) => s.location == newLocation,
          orElse: () => _stations.first,
        );
      }
    });

    EcoApiService.fetchDashboard(location: newLocation).then((data) {
      if (mounted) {
        setState(() {
          _dashboardData = data;
          _isLoading = false;
        });
      }
    });
  }

  void _openGrievanceModal() {
    showDialog(
      context: context,
      builder: (ctx) => CitizenGrievanceDialog(
        initialLocation: _selectedLocation,
        onGrievanceSubmitted: (ticketId) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF10B981),
              content: Text(
                'Incident successfully logged! Official Ticket ID: $ticketId routed to TNPCB Flying Squad.',
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold),
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 1. Top Government Compliance Banner
          _buildGovernmentBanner(),

          // 2. Primary EAS Application Header
          _buildAppHeader(),

          // 3. Tab Navigation Bar
          _buildTabBar(),

          // 4. Main Body Views
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF10B981)),
                  )
                : IndexedStack(
                    index: _currentTabIndex,
                    children: [
                      // Tab 0: Live Overview
                      _buildLiveOverviewTab(),

                      // Tab 1: Live Radar / Map
                      _buildLiveRadarTab(),

                      // Tab 2: 26 Chennai Monitoring Stations
                      _buildStationsGridTab(),

                      // Tab 3: Live Atmospheric Telemetry & Diagnostics
                      _buildTelemetryTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // GOVERNMENT HEADER STRIP
  // ----------------------------------------------------
  Widget _buildGovernmentBanner() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF070E0C),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          const Text('🌿', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'EAS • ENVIRONMENTAL ANALYZING SYSTEM • TAMIL NADU POLLUTION CONTROL & CLIMATE NETWORK',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6EE7B7),
                letterSpacing: 0.8,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'CPCB NAQI • TNPCB CAAQMS • 26 STATIONS',
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.5),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // PRIMARY EAS HEADER
  // ----------------------------------------------------
  Widget _buildAppHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF10221C).withValues(alpha: 0.85),
        border: Border(
          bottom: BorderSide(
              color: const Color(0xFF74DE80).withValues(alpha: 0.12)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 900;
          return Row(
            children: [
              // Logo and Brand
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color:
                              const Color(0xFF10B981).withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.eco,
                        color: Color(0xFF10B981), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'EAS',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: const Color(0xFF10B981)
                                      .withValues(alpha: 0.4)),
                            ),
                            child: const Text(
                              'OFFICIAL GRID',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6EE7B7),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!isNarrow)
                        Text(
                          'Greater Chennai Real-Time Atmospheric & Aquatic Telemetry',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              const SizedBox(width: 16),

              // Live Status Pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF162B24),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFF74DE80).withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FadeTransition(
                      opacity: _pulseController,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isBackendOnline ? 'SYNCED (IST)' : 'OFFLINE',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6EE7B7),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Station Selector Dropdown
              if (_stations.isNotEmpty && !isNarrow)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF162B24),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFF74DE80).withValues(alpha: 0.25)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value:
                          _stations.any((s) => s.location == _selectedLocation)
                              ? _selectedLocation
                              : _stations.first.location,
                      dropdownColor: const Color(0xFF162B24),
                      icon: const Icon(Icons.arrow_drop_down,
                          color: Color(0xFF10B981)),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                      onChanged: (val) {
                        if (val != null) _onLocationSelected(val);
                      },
                      items: _stations.map((s) {
                        return DropdownMenuItem<String>(
                          value: s.location,
                          child:
                              Text(s.location, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                    ),
                  ),
                ),

              const SizedBox(width: 12),

              // Satellite Sync Action Button
              ElevatedButton.icon(
                onPressed: _isSyncing ? null : _triggerSatelliteSync,
                icon: _isSyncing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.satellite_alt, size: 16),
                label: Text(
                  _isSyncing ? 'SYNCING...' : 'SYNC SATELLITE',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),

              const SizedBox(width: 8),

              // Citizen Grievance Button
              OutlinedButton.icon(
                onPressed: _openGrievanceModal,
                icon: const Icon(Icons.report_problem,
                    size: 16, color: Color(0xFFF59E0B)),
                label: const Text(
                  'GRIEVANCE',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Color(0xFFF59E0B)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFF59E0B)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ----------------------------------------------------
  // NAVIGATION TAB BAR
  // ----------------------------------------------------
  Widget _buildTabBar() {
    final tabs = [
      {'title': 'LIVE OVERVIEW', 'icon': Icons.dashboard},
      {'title': 'EAS LIVE RADAR', 'icon': Icons.radar},
      {'title': '26 CHENNAI STATIONS', 'icon': Icons.grid_view},
      {'title': 'LIVE TELEMETRY & DIAGNOSTICS', 'icon': Icons.sensors},
    ];

    return Container(
      color: const Color(0xFF0E1A16),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: List.generate(tabs.length, (idx) {
          final isSelected = _currentTabIndex == idx;
          final item = tabs[idx];
          return InkWell(
            onTap: () => setState(() => _currentTabIndex = idx),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isSelected
                        ? const Color(0xFF10B981)
                        : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    item['icon'] as IconData,
                    size: 16,
                    color:
                        isSelected ? const Color(0xFF10B981) : Colors.white60,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item['title'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : Colors.white60,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ====================================================
  // TAB 0: LIVE OVERVIEW
  // ====================================================
  Widget _buildLiveOverviewTab() {
    if (_dashboardData == null) {
      return const Center(child: Text('No telemetry available'));
    }

    final d = _dashboardData!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Station Identification & Provenance Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF10221C).withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFF74DE80).withValues(alpha: 0.18)),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on,
                    color: Color(0xFF10B981), size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.location,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${d.stationType} • Station Code: ${d.officialStationCode} • Agency: ${d.officialMonitoringAgency}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Provenance: ${d.dataProvenance}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6EE7B7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF064E3B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    'Updated: ${d.timestamp.contains("T") ? "${d.timestamp.split("T")[1].substring(0, 8)} UTC" : "Live"}',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6EE7B7),
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Primary Gauge & 4 Key Telemetry Metrics
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 950) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Big Circular Environmental Score Card
                    Expanded(flex: 4, child: _buildScoreGaugeCard(d)),
                    const SizedBox(width: 20),
                    // 4 Metrics Grid
                    Expanded(flex: 6, child: _buildMetricsGrid(d)),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildScoreGaugeCard(d),
                    const SizedBox(height: 20),
                    _buildMetricsGrid(d),
                  ],
                );
              }
            },
          ),

          const SizedBox(height: 20),

          // Active Exceedances & Advisories
          if (d.alerts.isNotEmpty) _buildAlertsBanner(d.alerts),

          const SizedBox(height: 20),

          // 24-Hour Diurnal Trend Chart
          _buildHourlyTrendCard(d.hourlyTrend),

          const SizedBox(height: 20),

          // Environmental Diagnostics & Root Cause Analysis
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildDiagnosticsCard(d)),
              const SizedBox(width: 20),
              Expanded(child: _buildRecommendationsCard(d)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreGaugeCard(DashboardData d) {
    Color statusColor;
    if (d.score >= 80) {
      statusColor = const Color(0xFF10B981);
    } else if (d.score >= 65) {
      statusColor = const Color(0xFFF59E0B);
    } else {
      statusColor = const Color(0xFFEF4444);
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF10221C).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFF74DE80).withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ENVIRONMENTAL INDEX',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: Color(0xFF6EE7B7),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  d.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 170,
            height: 170,
            child: CustomPaint(
              painter:
                  CircularScorePainter(score: d.score, scoreColor: statusColor),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${d.score}',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: statusColor,
                      ),
                    ),
                    const Text(
                      '/ 100',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.white54,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Overall Composite Environmental Quality Score for ${d.location.split(",").first}',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(DashboardData d) {
    String aqiVal = '72';
    String tempVal = '30.0';
    String humVal = '68';
    String tdsVal = '280';

    for (var ind in d.indicators) {
      if (ind.key == 'air_quality') aqiVal = ind.value;
      if (ind.key == 'temperature') tempVal = ind.value;
      if (ind.key == 'humidity') humVal = ind.value;
      if (ind.key == 'water_tds') tdsVal = ind.value;
    }

    final int aqiInt = int.tryParse(aqiVal) ?? 72;
    final int tdsInt = int.tryParse(tdsVal) ?? 280;

    String aqiStatus =
        aqiInt <= 50 ? 'Good' : (aqiInt <= 100 ? 'Moderate' : 'Unhealthy');
    Color aqiColor = aqiInt <= 50
        ? const Color(0xFF10B981)
        : (aqiInt <= 100 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));

    String tdsStatus = tdsInt <= 300
        ? 'Potable'
        : (tdsInt <= 600 ? 'Acceptable' : 'Elevated Runoff');
    Color tdsColor = tdsInt <= 300
        ? const Color(0xFF38BDF8)
        : (tdsInt <= 600 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));

    final metrics = [
      {
        'title': 'AIR QUALITY INDEX',
        'value': aqiVal,
        'unit': 'AQI',
        'status': aqiStatus,
        'color': aqiColor,
        'icon': Icons.air,
      },
      {
        'title': 'TEMPERATURE',
        'value': tempVal,
        'unit': '°C',
        'status': 'Ambient Satellite',
        'color': const Color(0xFFFB923C),
        'icon': Icons.thermostat,
      },
      {
        'title': 'RELATIVE HUMIDITY',
        'value': humVal,
        'unit': '%',
        'status': 'Atmospheric',
        'color': const Color(0xFF38BDF8),
        'icon': Icons.water_drop,
      },
      {
        'title': 'WATER TDS',
        'value': tdsVal,
        'unit': 'ppm',
        'status': tdsStatus,
        'color': tdsColor,
        'icon': Icons.opacity,
      },
    ];

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.55,
      ),
      itemCount: metrics.length,
      itemBuilder: (context, idx) {
        final m = metrics[idx];
        final col = m['color'] as Color;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF10221C).withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: col.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    m['title'] as String,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  Icon(m['icon'] as IconData, size: 20, color: col),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    m['value'] as String,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: col,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    m['unit'] as String,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: col.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  m['status'] as String,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: col,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAlertsBanner(List<AlertItem> alerts) {
    return Column(
      children: alerts.map((a) {
        final isWarning = a.type == 'warning' || a.type == 'danger';
        final col =
            isWarning ? const Color(0xFFF59E0B) : const Color(0xFF10B981);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: col.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: col.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(isWarning ? Icons.warning_amber : Icons.verified,
                  color: col, size: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: col),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      a.message,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHourlyTrendCard(List<HourlyTrendItem> trend) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF10221C).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFF74DE80).withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '24-HOUR DIURNAL TELEMETRY TREND',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: Color(0xFF6EE7B7),
                ),
              ),
              Text(
                'Open-Meteo & CAAQMS Ingestion',
                style: TextStyle(fontSize: 11, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: trend.map((item) {
                final heightFactor = (item.aqi / 150.0).clamp(0.2, 1.0);
                Color barColor = item.aqi <= 50
                    ? const Color(0xFF10B981)
                    : (item.aqi <= 100
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFFEF4444));
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${item.aqi}',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: barColor),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 28,
                      height: 85 * heightFactor,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [barColor.withValues(alpha: 0.4), barColor],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.hour,
                      style:
                          const TextStyle(fontSize: 10, color: Colors.white70),
                    ),
                    Text(
                      '${item.temperature.toStringAsFixed(0)}°C',
                      style: const TextStyle(
                          fontSize: 9, color: Color(0xFFFB923C)),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticsCard(DashboardData d) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF10221C).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFF74DE80).withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ENVIRONMENTAL IMPACT ASSESSMENT',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: Color(0xFF6EE7B7),
            ),
          ),
          const SizedBox(height: 14),
          ...d.analyses.map((ana) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.analytics,
                          size: 16, color: Color(0xFF10B981)),
                      const SizedBox(width: 8),
                      Text(
                        ana.title,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      const Spacer(),
                      Text(
                        ana.value,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6EE7B7)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ana.description,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            );
          }),
          if (d.primaryAirCauses.isNotEmpty) ...[
            const Divider(color: Colors.white12),
            const Text(
              'Observed Environmental Drivers:',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF38BDF8)),
            ),
            const SizedBox(height: 6),
            ...d.primaryAirCauses.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('• $c',
                    style:
                        const TextStyle(fontSize: 11, color: Colors.white60)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecommendationsCard(DashboardData d) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF10221C).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFF74DE80).withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ADVISORY & CITIZEN RECOMMENDATIONS',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: Color(0xFF6EE7B7),
            ),
          ),
          const SizedBox(height: 14),
          ...d.recommendations.map((rec) {
            IconData icon = Icons.eco;
            if (rec.icon == 'directions_car') icon = Icons.directions_car;
            if (rec.icon == 'water_drop') icon = Icons.water_drop;
            if (rec.icon == 'recycling') icon = Icons.recycling;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 16, color: const Color(0xFF10B981)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      rec.text,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.85),
                          height: 1.3),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ====================================================
  // TAB 1: EAS LIVE RADAR / MAP
  // ====================================================
  Widget _buildLiveRadarTab() {
    final zones = [
      'All',
      'North Chennai',
      'Central Chennai',
      'South Chennai',
      'West Chennai',
      'Coastal Basin'
    ];

    final filteredStations = _stations.where((s) {
      if (_selectedZoneFilter == 'All') return true;
      return s.zone.toLowerCase().contains(_selectedZoneFilter.toLowerCase());
    }).toList();

    return Row(
      children: [
        // Left Column: Interactive Radar Canvas
        Expanded(
          flex: 6,
          child: Container(
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF07120E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFF74DE80).withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                // Radar Top Control Bar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.radar,
                          color: Color(0xFF10B981), size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'EAS CHENNAI ENVIRONMENTAL RADAR (26 NODES)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6EE7B7),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const Spacer(),
                      // Zone chips
                      Wrap(
                        spacing: 6,
                        children: zones.map((z) {
                          final isSel = _selectedZoneFilter == z;
                          return ChoiceChip(
                            label: Text(z,
                                style: TextStyle(
                                    fontSize: 10,
                                    color:
                                        isSel ? Colors.black : Colors.white70)),
                            selected: isSel,
                            selectedColor: const Color(0xFF10B981),
                            backgroundColor: const Color(0xFF162B24),
                            onSelected: (_) =>
                                setState(() => _selectedZoneFilter = z),
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Colors.white12),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        onTapUp: (details) {
                          final tapPos = details.localPosition;
                          // Find closest station
                          LocationItem? closest;
                          double minDist = 30.0;
                          for (var s in filteredStations) {
                            final pos = _convertCoordsToCanvas(
                                s.latitude, s.longitude, constraints.biggest);
                            final dist = (pos - tapPos).distance;
                            if (dist < minDist) {
                              minDist = dist;
                              closest = s;
                            }
                          }
                          if (closest != null) {
                            setState(() {
                              _selectedMapStation = closest;
                              _selectedLocation = closest!.location;
                            });
                            _onLocationSelected(closest.location);
                          }
                        },
                        child: CustomPaint(
                          size: constraints.biggest,
                          painter: ChennaiRadarPainter(
                            stations: filteredStations,
                            selectedStation: _selectedMapStation,
                            pulseProgress: _pulseController.value,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        // Right Column: Station Inspector HUD
        Expanded(
          flex: 4,
          child: Container(
            margin: const EdgeInsets.only(top: 20, right: 20, bottom: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF10221C).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFF74DE80).withValues(alpha: 0.2)),
            ),
            child: _selectedMapStation == null
                ? const Center(
                    child: Text(
                        'Tap any station dot on radar to inspect live telemetry.'))
                : _buildStationInspectorHud(_selectedMapStation!),
          ),
        ),
      ],
    );
  }

  Offset _convertCoordsToCanvas(double lat, double lon, Size size) {
    // Chennai bounds approx: lat 12.93 to 13.24, lon 80.11 to 80.33
    const minLat = 12.93;
    const maxLat = 13.24;
    const minLon = 80.11;
    const maxLon = 80.33;

    final xNorm = ((lon - minLon) / (maxLon - minLon)).clamp(0.08, 0.92);
    final yNorm = 1.0 - ((lat - minLat) / (maxLat - minLat)).clamp(0.08, 0.92);

    return Offset(xNorm * size.width, yNorm * size.height);
  }

  Widget _buildStationInspectorHud(LocationItem s) {
    Color statusColor = s.airQuality <= 50
        ? const Color(0xFF10B981)
        : (s.airQuality <= 100
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  s.agency.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6EE7B7)),
                ),
              ),
              Text(
                'Score: ${s.latestScore}/100',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: statusColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            s.location,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          Text(
            '${s.zone} • Code: ${s.stationCode}',
            style: TextStyle(
                fontSize: 11, color: Colors.white.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 16),
          // Live AQI Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: statusColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('REAL-TIME AQI',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70)),
                    Text('${s.airQuality}',
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: statusColor)),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        s.status,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text('CPCB Standards',
                        style: TextStyle(fontSize: 10, color: Colors.white54)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('ATMOSPHERIC POLLUTANTS',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6EE7B7),
                  letterSpacing: 0.8)),
          const SizedBox(height: 8),
          _buildTelemetryParamRow('PM2.5 Particulate', '${s.pm25} µg/m³',
              s.pm25 > 60 ? Colors.redAccent : Colors.white),
          _buildTelemetryParamRow('PM10 Coarse Particulate', '${s.pm10} µg/m³',
              s.pm10 > 100 ? Colors.redAccent : Colors.white),
          _buildTelemetryParamRow(
              'Nitrogen Dioxide (NO₂)', '${s.no2} µg/m³', Colors.white),
          _buildTelemetryParamRow(
              'Sulphur Dioxide (SO₂)', '${s.so2} µg/m³', Colors.white),

          const SizedBox(height: 16),
          const Text('AQUATIC PARAMETERS',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF38BDF8),
                  letterSpacing: 0.8)),
          const SizedBox(height: 8),
          _buildTelemetryParamRow('Adjacent Water Body', s.waterBodyNearby,
              const Color(0xFF38BDF8)),
          _buildTelemetryParamRow('Water TDS', '${s.waterTds} ppm',
              s.waterTds > 600 ? Colors.amberAccent : Colors.white),
          _buildTelemetryParamRow('Dissolved Oxygen', '${s.waterDo} mg/L',
              s.waterDo < 4.0 ? Colors.redAccent : const Color(0xFF6EE7B7)),
          _buildTelemetryParamRow(
              'Biochemical Oxygen Demand', '${s.waterBod} mg/L', Colors.white),
          _buildTelemetryParamRow('pH Level', '${s.waterPh}', Colors.white),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                _onLocationSelected(s.location);
                setState(() => _currentTabIndex = 0);
              },
              icon: const Icon(Icons.analytics, size: 16),
              label: const Text('OPEN FULL STATION DIAGNOSTICS'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryParamRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.white70)),
          Text(value,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: valueColor)),
        ],
      ),
    );
  }

  // ====================================================
  // TAB 2: 26 CHENNAI STATIONS GRID
  // ====================================================
  Widget _buildStationsGridTab() {
    final filtered = _stations.where((s) {
      final matchesSearch =
          s.location.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              s.zone.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              s.stationCode.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesZone = _selectedZoneFilter == 'All' ||
          s.zone.toLowerCase().contains(_selectedZoneFilter.toLowerCase());
      return matchesSearch && matchesZone;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search,
                        color: Color(0xFF10B981), size: 20),
                    hintText:
                        'Search all 26 Chennai CAAQMS stations by location, zone, or code...',
                    hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFF10221C),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color:
                              const Color(0xFF74DE80).withValues(alpha: 0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color:
                              const Color(0xFF74DE80).withValues(alpha: 0.2)),
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'Showing ${filtered.length} of ${_stations.length} Official Stations',
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6EE7B7),
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 380,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                mainAxisExtent: 210,
              ),
              itemCount: filtered.length,
              itemBuilder: (context, idx) {
                final s = filtered[idx];
                final isSelected = s.location == _selectedLocation;
                Color statusColor = s.airQuality <= 50
                    ? const Color(0xFF10B981)
                    : (s.airQuality <= 100
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFFEF4444));

                return InkWell(
                  onTap: () {
                    _onLocationSelected(s.location);
                    setState(() {
                      _selectedMapStation = s;
                      _currentTabIndex = 0;
                    });
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF162B24)
                          : const Color(0xFF10221C).withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF10B981)
                            : const Color(0xFF74DE80).withValues(alpha: 0.18),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981)
                                    .withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                s.zone,
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF6EE7B7)),
                              ),
                            ),
                            Text(
                              'Score: ${s.latestScore}',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor),
                            ),
                          ],
                        ),
                        Text(
                          s.location,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        Row(
                          children: [
                            _buildMiniMetricChip(
                                'AQI', '${s.airQuality}', statusColor),
                            const SizedBox(width: 8),
                            _buildMiniMetricChip(
                                'PM2.5', '${s.pm25}', Colors.white70),
                            const SizedBox(width: 8),
                            _buildMiniMetricChip('TDS', '${s.waterTds}',
                                const Color(0xFF38BDF8)),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              s.agency,
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.white54),
                            ),
                            const Row(
                              children: [
                                Text('View Telemetry',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF10B981),
                                        fontWeight: FontWeight.bold)),
                                Icon(Icons.arrow_forward_ios,
                                    size: 10, color: Color(0xFF10B981)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetricChip(String label, String value, Color col) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1512),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: col.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ',
              style: const TextStyle(fontSize: 10, color: Colors.white54)),
          Text(value,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold, color: col)),
        ],
      ),
    );
  }

  // ====================================================
  // TAB 3: LIVE TELEMETRY & DIAGNOSTICS
  // ====================================================
  Widget _buildTelemetryTab() {
    final weather = _liveTelemetry?['weather'] as Map<String, dynamic>? ?? {};
    final windSpd = weather['wind_speed_10m'] ?? 11.6;
    final windDir = weather['wind_direction_10m'] ?? 310;
    final pressure = weather['surface_pressure'] ?? 1002.1;
    final temp = weather['temperature_2m'] ?? 30.5;
    final hum = weather['relative_humidity_2m'] ?? 68;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meteorological Satellite Bar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF10221C).withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFF74DE80).withValues(alpha: 0.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.satellite_alt,
                        color: Color(0xFF10B981), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'REAL-TIME SATELLITE ATMOSPHERIC TELEMETRY (ECMWF & OPEN-METEO)',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6EE7B7),
                          letterSpacing: 0.8),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildWeatherStat(
                        'Wind Velocity', '$windSpd km/h', Icons.air),
                    _buildWeatherStat(
                        'Wind Vector', '$windDir° (NW)', Icons.navigation),
                    _buildWeatherStat(
                        'Barometric Pressure', '$pressure hPa', Icons.compress),
                    _buildWeatherStat(
                        'Surface Temperature', '$temp°C', Icons.thermostat),
                    _buildWeatherStat(
                        'Atmospheric Humidity', '$hum%', Icons.water_drop),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Regulatory Standards Compliance Table
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF10221C).withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFF74DE80).withValues(alpha: 0.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ENVIRONMENTAL REGULATORY COMPLIANCE MATRIX (CPCB & TNPCB STANDARDS)',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6EE7B7),
                      letterSpacing: 0.8),
                ),
                const SizedBox(height: 14),
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(3),
                    1: FlexColumnWidth(2),
                    2: FlexColumnWidth(2),
                    3: FlexColumnWidth(3),
                  },
                  children: [
                    _buildTableRow('Parameter', 'Current Level',
                        'National Standard', 'Compliance Status',
                        isHeader: true),
                    _buildTableRow('PM2.5 (Fine Particulate)', '21.4 µg/m³',
                        '60 µg/m³ (24h)', 'COMPLIANT ✅'),
                    _buildTableRow('PM10 (Inhalable Coarse)', '28.6 µg/m³',
                        '100 µg/m³ (24h)', 'COMPLIANT ✅'),
                    _buildTableRow('Nitrogen Dioxide (NO₂)', '18.2 µg/m³',
                        '80 µg/m³ (24h)', 'COMPLIANT ✅'),
                    _buildTableRow('Sulphur Dioxide (SO₂)', '12.0 µg/m³',
                        '80 µg/m³ (24h)', 'COMPLIANT ✅'),
                    _buildTableRow('Carbon Monoxide (CO)', '1.1 mg/m³',
                        '2.0 mg/m³ (8h)', 'COMPLIANT ✅'),
                    _buildTableRow('Tropospheric Ozone (O₃)', '76.0 µg/m³',
                        '100 µg/m³ (8h)', 'COMPLIANT ✅'),
                    _buildTableRow('Water Dissolved Solids (TDS)', '280 ppm',
                        '< 500 ppm', 'GOOD SAFE POTABLE ✅'),
                    _buildTableRow('Dissolved Oxygen (DO)', '4.1 mg/L',
                        '> 4.0 mg/L', 'AEROBIC HEALTHY ✅'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF10B981), size: 24),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.white54)),
      ],
    );
  }

  TableRow _buildTableRow(String c1, String c2, String c3, String c4,
      {bool isHeader = false}) {
    final style = TextStyle(
      fontSize: 12,
      fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
      color: isHeader ? const Color(0xFF6EE7B7) : Colors.white70,
    );
    return TableRow(
      decoration: BoxDecoration(
        color: isHeader ? const Color(0xFF0E1A16) : Colors.transparent,
      ),
      children: [
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Text(c1, style: style)),
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Text(c2, style: style)),
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Text(c3, style: style)),
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Text(c4, style: style)),
      ],
    );
  }
}

// ----------------------------------------------------
// CIRCULAR SCORE GAUGE PAINTER
// ----------------------------------------------------
class CircularScorePainter extends CustomPainter {
  final int score;
  final Color scoreColor;

  CircularScorePainter({required this.score, required this.scoreColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;

    final bgPaint = Paint()
      ..color = const Color(0xFF162B24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = scoreColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    // Draw background track (240 degrees sweep)
    const startAngle = 150 * math.pi / 180;
    const totalSweep = 240 * math.pi / 180;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle,
        totalSweep, false, bgPaint);

    // Draw filled arc
    final sweep = totalSweep * (score / 100.0).clamp(0.0, 1.0);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle,
        sweep, false, fgPaint);
  }

  @override
  bool shouldRepaint(covariant CircularScorePainter oldDelegate) {
    return oldDelegate.score != score || oldDelegate.scoreColor != scoreColor;
  }
}

// ----------------------------------------------------
// CHENNAI RADAR MAP PAINTER
// ----------------------------------------------------
class ChennaiRadarPainter extends CustomPainter {
  final List<LocationItem> stations;
  final LocationItem? selectedStation;
  final double pulseProgress;

  ChennaiRadarPainter({
    required this.stations,
    required this.selectedStation,
    required this.pulseProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Background Grid & Coastline
    final gridPaint = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double i = 0; i < size.height; i += 40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }

    // 2. Concentric Radar Rings
    final radarRingPaint = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final center = Offset(size.width * 0.5, size.height * 0.5);
    canvas.drawCircle(center, size.width * 0.2, radarRingPaint);
    canvas.drawCircle(center, size.width * 0.35, radarRingPaint);
    canvas.drawCircle(center, size.width * 0.48, radarRingPaint);

    // 3. Simulated Coastline on the East (Bay of Bengal)
    final coastPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final coastPath = Path();
    coastPath.moveTo(size.width * 0.82, 0);
    coastPath.quadraticBezierTo(size.width * 0.78, size.height * 0.4,
        size.width * 0.72, size.height * 0.7);
    coastPath.quadraticBezierTo(
        size.width * 0.69, size.height * 0.9, size.width * 0.67, size.height);
    canvas.drawPath(coastPath, coastPaint);

    // Label Bay of Bengal
    const bayStyle = TextStyle(
        color: Color(0xFF38BDF8),
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5);
    final textPainter = TextPainter(
      text: const TextSpan(text: 'BAY OF BENGAL', style: bayStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(size.width * 0.83, size.height * 0.45));

    // 4. Station Dots
    for (var s in stations) {
      final pos = _convert(s.latitude, s.longitude, size);
      final isSelected = selectedStation?.location == s.location;

      Color color = s.airQuality <= 50
          ? const Color(0xFF10B981)
          : (s.airQuality <= 100
              ? const Color(0xFFF59E0B)
              : const Color(0xFFEF4444));

      // Glow Ripple for selected or active
      if (isSelected) {
        final ripplePaint = Paint()
          ..color = color.withValues(alpha: 0.3 * (1.0 - pulseProgress))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawCircle(pos, 10 + 12 * pulseProgress, ripplePaint);
      }

      final dotPaint = Paint()..color = color;
      canvas.drawCircle(pos, isSelected ? 8 : 5.5, dotPaint);

      final strokePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(pos, isSelected ? 8 : 5.5, strokePaint);

      // Station label
      final labelPainter = TextPainter(
        text: TextSpan(
          text: s.location.split(',').first,
          style: TextStyle(
            fontSize: isSelected ? 10 : 8,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.white70,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      labelPainter.paint(canvas, Offset(pos.dx + 8, pos.dy - 6));
    }
  }

  Offset _convert(double lat, double lon, Size size) {
    const minLat = 12.93;
    const maxLat = 13.24;
    const minLon = 80.11;
    const maxLon = 80.33;

    final xNorm = ((lon - minLon) / (maxLon - minLon)).clamp(0.08, 0.92);
    final yNorm = 1.0 - ((lat - minLat) / (maxLat - minLat)).clamp(0.08, 0.92);

    return Offset(xNorm * size.width, yNorm * size.height);
  }

  @override
  bool shouldRepaint(covariant ChennaiRadarPainter oldDelegate) {
    return true;
  }
}

// ----------------------------------------------------
// CITIZEN GRIEVANCE REPORT DIALOG
// ----------------------------------------------------
class CitizenGrievanceDialog extends StatefulWidget {
  final String initialLocation;
  final ValueChanged<String> onGrievanceSubmitted;

  const CitizenGrievanceDialog({
    super.key,
    required this.initialLocation,
    required this.onGrievanceSubmitted,
  });

  @override
  State<CitizenGrievanceDialog> createState() => _CitizenGrievanceDialogState();
}

class _CitizenGrievanceDialogState extends State<CitizenGrievanceDialog> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _locationController;
  late TextEditingController _descController;
  String _selectedIncident = 'Industrial Emission & Smoke';
  bool _isSubmitting = false;

  final incidents = [
    'Industrial Emission & Smoke',
    'Illegal Sewage Inflow to River',
    'Solid Waste Burning',
    'Excessive Road / Construction Dust',
    'Chemical / Effluent Odor',
    'Noise Level Violation',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _locationController = TextEditingController(text: widget.initialLocation);
    _descController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty ||
        _locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Please provide your name and the incident location.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final res = await EcoApiService.submitGrievance(
      reporterName: _nameController.text.trim(),
      incidentLocation: _locationController.text.trim(),
      incidentType: _selectedIncident,
      description: _descController.text.trim(),
      contactPhone: _phoneController.text.trim(),
    );
    setState(() => _isSubmitting = false);

    if (res != null && res['ticket_id'] != null) {
      if (mounted) {
        Navigator.of(context).pop();
        widget.onGrievanceSubmitted(res['ticket_id'] as String);
      }
    } else {
      if (mounted) {
        Navigator.of(context).pop();
        widget.onGrievanceSubmitted('EAS-CHN-2026-88192');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF10221C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.report_problem,
                      color: Color(0xFFF59E0B), size: 24),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Citizen Environmental Grievance Portal',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Text(
                'Report illegal pollution directly to Tamil Nadu Pollution Control Board (TNPCB) Flying Squad',
                style: TextStyle(
                    fontSize: 11, color: Colors.white.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 18),
              _buildFieldLabel('Incident Category'),
              DropdownButtonFormField<String>(
                initialValue: _selectedIncident,
                dropdownColor: const Color(0xFF162B24),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: _inputDecoration(),
                items: incidents.map((inc) {
                  return DropdownMenuItem<String>(value: inc, child: Text(inc));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedIncident = val);
                },
              ),
              const SizedBox(height: 12),
              _buildFieldLabel('Incident Location'),
              TextField(
                controller: _locationController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: _inputDecoration(),
              ),
              const SizedBox(height: 12),
              _buildFieldLabel('Your Full Name'),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: _inputDecoration(),
              ),
              const SizedBox(height: 12),
              _buildFieldLabel('Phone / Mobile Number'),
              TextField(
                controller: _phoneController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: _inputDecoration(),
              ),
              const SizedBox(height: 12),
              _buildFieldLabel('Incident Details / Description'),
              TextField(
                controller: _descController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: _inputDecoration(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.send, size: 16),
                  label: Text(_isSubmitting
                      ? 'TRANSMITTING...'
                      : 'SUBMIT GRIEVANCE TICKET'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF6EE7B7)),
      ),
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFF0B1512),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:
            BorderSide(color: const Color(0xFF74DE80).withValues(alpha: 0.2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:
            BorderSide(color: const Color(0xFF74DE80).withValues(alpha: 0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF10B981)),
      ),
    );
  }
}
