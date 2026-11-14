import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/evora_colors.dart';
import '../../../core/utils/auth_guard.dart';
import '../../../core/utils/external_launcher.dart';
import '../../../services/environmental_service.dart';
import '../../../services/location_service.dart';
import '../../auth/services/auth_service.dart';
import '../../facilities/models/circular_facility_model.dart';
import '../../facilities/services/circular_directory_service.dart';
import '../../ledger/models/eco_ledger_model.dart';
import '../../ledger/services/eco_ledger_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _selectedLocalityName = 'Dehradun Central';
  double _activeLatitude = 30.3244;
  double _activeLongitude = 78.0416;
  bool _ecoActionCompleted = false;

  final Map<String, ({double lat, double lng})> _localities = const {
    'Dehradun Central': (lat: 30.3244, lng: 78.0416),
    'Rajpur Road / Jakhan': (lat: 30.3615, lng: 78.0712),
    'Dalanwala': (lat: 30.3280, lng: 78.0550),
    'Paltan Bazaar': (lat: 30.3228, lng: 78.0398),
    'ISBT / Majra': (lat: 30.2970, lng: 78.0080),
    'West Doon': (lat: 30.3685, lng: 77.8760),
  };

  static String _ecoActionKey(String uid) {
    final now = DateTime.now();
    return 'evora_eco_action_${uid}_${now.year}_${now.month}_${now.day}';
  }

  Future<void> _loadEcoActionStatus(String? uid) async {
    if (uid == null || uid.isEmpty) {
      if (mounted) setState(() => _ecoActionCompleted = false);
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDone = prefs.getBool(_ecoActionKey(uid)) ?? false;
      if (mounted) {
        setState(() => _ecoActionCompleted = isDone);
      }
    } catch (_) {
      if (mounted) setState(() => _ecoActionCompleted = false);
    }
  }

  Future<void> _saveEcoActionStatus(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_ecoActionKey(uid), true);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    final userLoc = user?.selectedLocality;
    if (userLoc != null && _localities.containsKey(userLoc)) {
      _selectedLocalityName = userLoc;
      _activeLatitude = _localities[userLoc]!.lat;
      _activeLongitude = _localities[userLoc]!.lng;
    }
    _loadEcoActionStatus(user?.uid);
  }

  bool _isRefreshingEnv = false;

  Future<void> _refreshEnvironmentalData({bool showFeedback = true}) async {
    if (_isRefreshingEnv) return;
    setState(() => _isRefreshingEnv = true);

    try {
      // 1. Clear in-memory cache for active coordinates so fresh telemetry is fetched
      ref.read(environmentalServiceProvider).clearCache(
        latitude: _activeLatitude,
        longitude: _activeLongitude,
      );

      // 2. Invalidate provider and await fresh network result
      ref.invalidate(environmentalDataProvider);
      await ref.read(
        environmentalDataProvider((lat: _activeLatitude, lng: _activeLongitude)).future,
      );

      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Updated real-time air quality & weather feed.'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not refresh sensors: $e'),
            backgroundColor: EvoraColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshingEnv = false);
      }
    }
  }

  Future<void> _useLiveGps() async {
    final loc = await LocationService.acquireLocation();
    if (!mounted) return;
    setState(() {
      _activeLatitude = loc.latitude;
      _activeLongitude = loc.longitude;
      _selectedLocalityName = loc.localityName;
    });

    ref.read(circularDirectoryProvider.notifier).updateLocation(loc);
    ref.read(environmentalServiceProvider).clearCache(
          latitude: loc.latitude,
          longitude: loc.longitude,
        );
    ref.invalidate(environmentalDataProvider);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Switched to Live GPS: ${loc.localityName}'),
        backgroundColor: EvoraColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showLocalityPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        final rawBottom = [
          media.padding.bottom,
          media.viewPadding.bottom,
          media.viewInsets.bottom,
        ].reduce((a, b) => a > b ? a : b);
        final bottomInset = rawBottom > 0 ? (rawBottom + 16.0) : 56.0;

        return Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset),
          decoration: const BoxDecoration(
            color: EvoraColors.surfaceContainerLowest,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: EvoraColors.outlineVariant,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Select Your Neighborhood',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 4),
              const Text(
                'Customizes local environmental air quality and nearby recycling hubs.',
                style: TextStyle(fontSize: 12.5, color: EvoraColors.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: EvoraColors.secondary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.my_location, color: EvoraColors.primary, size: 22),
                ),
                title: const Text('Use Live GPS Location', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Detect exact coordinates automatically'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(ctx);
                  _useLiveGps();
                },
              ),
              const Divider(height: 20),
              ..._localities.keys.map((name) {
                final isSelected = _selectedLocalityName == name;
                return ListTile(
                  leading: Icon(
                    Icons.location_city_outlined,
                    color: isSelected ? EvoraColors.primary : EvoraColors.onSurfaceVariant,
                  ),
                  title: Text(
                    name,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                      color: isSelected ? EvoraColors.primary : EvoraColors.onSurface,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: EvoraColors.primary)
                      : null,
                  onTap: () {
                    final coords = _localities[name]!;
                    setState(() {
                      _selectedLocalityName = name;
                      _activeLatitude = coords.lat;
                      _activeLongitude = coords.lng;
                    });
                    ref.read(circularDirectoryProvider.notifier).updateLocation(
                          EvoraLocation(
                            latitude: coords.lat,
                            longitude: coords.lng,
                            localityName: name,
                          ),
                        );
                    ref.read(environmentalServiceProvider).clearCache(
                          latitude: coords.lat,
                          longitude: coords.lng,
                        );
                    ref.invalidate(environmentalDataProvider);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _launchDirections(CircularFacility facility) async {
    final success = await ExternalLauncher.launchDirections(
      latitude: facility.latitude,
      longitude: facility.longitude,
      destinationName: facility.name,
    );
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open Google Maps navigation for ${facility.name}'),
          backgroundColor: EvoraColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (!next.isAuthenticated) {
        setState(() => _ecoActionCompleted = false);
      } else if (next.user?.uid != previous?.user?.uid) {
        _loadEcoActionStatus(next.user?.uid);
      }
    });

    final authState = ref.watch(authProvider);
    final user = authState.user;
    final textTheme = Theme.of(context).textTheme;

    // Environmental Telemetry Provider
    final envAsync = ref.watch(
      environmentalDataProvider((lat: _activeLatitude, lng: _activeLongitude)),
    );

    // Nearby facilities
    final directoryNotifier = ref.read(circularDirectoryProvider.notifier);
    final nearbyHubs = directoryNotifier.getClosestFacilities(limit: 3);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: EvoraColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.eco, color: EvoraColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'EVORA',
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.military_tech_outlined),
            tooltip: 'Eco Missions',
            onPressed: () => context.push('/missions'),
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Impact Profile',
            onPressed: () => context.push('/profile'),
          ),
          if (authState.isAuthenticated)
            IconButton(
              icon: const Icon(Icons.logout_outlined),
              tooltip: 'Sign Out',
              onPressed: () async {
                await ref.read(authProvider.notifier).signOut();
                if (mounted) {
                  setState(() => _ecoActionCompleted = false);
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Signed out. You are now browsing in guest mode.'),
                    ),
                  );
                }
              },
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                icon: const Icon(Icons.login, size: 18),
                label: const Text(
                  'Sign In',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                onPressed: () => context.push('/login?returnOnSuccess=true'),
              ),
            ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        maintainBottomViewPadding: true,
        child: RefreshIndicator(
          onRefresh: () => _refreshEnvironmentalData(showFeedback: false),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              24 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Warm Greeting & Neighborhood Selector Pill
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: EvoraColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: EvoraColors.outlineVariant.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => context.push('/profile'),
                      borderRadius: BorderRadius.circular(100),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: EvoraColors.primary,
                        child: Text(
                          (user?.displayName.isNotEmpty == true)
                              ? user!.displayName[0].toUpperCase()
                              : 'R',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Namaste, ${user?.displayName ?? "Resident"}',
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: _showLocalityPicker,
                            borderRadius: BorderRadius.circular(100),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: EvoraColors.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(color: EvoraColors.outlineVariant.withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.location_on, size: 14, color: EvoraColors.primary),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      _selectedLocalityName,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: EvoraColors.primary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.keyboard_arrow_down, size: 16, color: EvoraColors.primary),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Real-Time Environmental Health Card
              envAsync.when(
                data: (env) => _buildEnvironmentalCard(env),
                loading: () => Container(
                  height: 100,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: EvoraColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Reading Doon Valley environmental sensors...'),
                      ],
                    ),
                  ),
                ),
                error: (e, _) => _buildEnvironmentalUnavailableCard(),
              ),
              const SizedBox(height: 16),

              // 3. Today's Eco Action Card
              _buildTodayEcoActionCard(),
              const SizedBox(height: 24),

              // 4. Civic & Sustainability Services Grid (2x2 Clear Cards)
              const Text(
                'Essential Civic Services',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'Everything you need to report problems, discuss, and adopt sustainable choices.',
                style: TextStyle(fontSize: 12.5, color: EvoraColors.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.15,
                children: [
                  _buildServiceCard(
                    title: 'CivicFlow',
                    subtitle: 'File formal grievance',
                    description: 'Report potholes, waste & streetlights with AI triage.',
                    icon: Icons.assignment_outlined,
                    color: EvoraColors.primary,
                    onTap: () => context.push('/civic-flow'),
                  ),
                  _buildServiceCard(
                    title: 'CivicBook',
                    subtitle: 'Community feed',
                    description: 'View & upvote 3-5 km neighborhood observations.',
                    icon: Icons.dynamic_feed_outlined,
                    color: Colors.teal.shade700,
                    onTap: () => context.push('/civic-book'),
                  ),
                  _buildServiceCard(
                    title: 'EvoSwitch',
                    subtitle: 'Green calculator',
                    description: 'Calculate CO₂ & rupee savings on travel and home habits.',
                    icon: Icons.swap_calls_outlined,
                    color: Colors.orange.shade800,
                    onTap: () => context.push('/evoswitch'),
                  ),
                  _buildServiceCard(
                    title: 'Waste Directory',
                    subtitle: 'Recycling & hubs',
                    description: 'Find verified e-waste, composting & repair centers.',
                    icon: Icons.recycling_outlined,
                    color: const Color(0xFF0D9488),
                    onTap: () => context.push('/facilities'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 4b. Eco Action Missions Spotlight Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.teal.shade900,
                      const Color(0xFF004D34),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: EvoraColors.primary.withValues(alpha: 0.22),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.park_outlined, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Eco Missions & Campaigns',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Join Rispana riverbed cleanups, tree drives & earn verified EcoCoins.',
                            style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EvoraColors.secondary,
                        foregroundColor: EvoraColors.onSecondary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: () => context.push('/missions'),
                      child: const Text('Explore', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 5. Nearby Verified Circular Hubs Carousel
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Nearest Recycling & Hubs',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('View All', style: TextStyle(fontWeight: FontWeight.w700)),
                    onPressed: () => context.push('/facilities'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (nearbyHubs.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: EvoraColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text('Loading verified municipal facilities...'),
                  ),
                )
              else
                SizedBox(
                  height: 148,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: nearbyHubs.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 12),
                    itemBuilder: (ctx, index) {
                      final hub = nearbyHubs[index];
                      return Container(
                        width: 250,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: EvoraColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: EvoraColors.outlineVariant.withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: EvoraColors.primary.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(hub.category.icon, size: 14, color: EvoraColors.primary),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    hub.category.label,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: EvoraColors.primary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (hub.distanceFormatted.isNotEmpty)
                                  Text(
                                    hub.distanceFormatted,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.orange.shade800,
                                    ),
                                  ),
                              ],
                            ),
                            Text(
                              hub.name,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    hub.locality,
                                    style: const TextStyle(fontSize: 11, color: EvoraColors.onSurfaceVariant),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                InkWell(
                                  onTap: () => _launchDirections(hub),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: EvoraColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.directions, size: 12, color: EvoraColors.primary),
                                        SizedBox(width: 2),
                                        Text('Map', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: EvoraColors.primary)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 28),

              // 6. Clean Footer Links
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => context.push('/privacy-policy'),
                      child: const Text('Privacy Policy'),
                    ),
                    const Text('•', style: TextStyle(color: EvoraColors.outline)),
                    TextButton(
                      onPressed: () => context.push('/terms'),
                      child: const Text('Terms of Service'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildEnvironmentalCard(EnvironmentalData env) {
    if (env.isUnavailable) {
      return _buildEnvironmentalUnavailableCard();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EvoraColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: EvoraColors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: env.aqiColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: env.aqiColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'AQI ${env.aqi} • ${env.aqiCategory}',
                      style: TextStyle(
                        color: env.aqiColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(env.weatherIcon, size: 18, color: EvoraColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    '${env.temperatureCelsius.round()}°C',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: _isRefreshingEnv ? null : () => _refreshEnvironmentalData(showFeedback: true),
                    borderRadius: BorderRadius.circular(100),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: _isRefreshingEnv
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: EvoraColors.primary,
                              ),
                            )
                          : const Icon(Icons.refresh, size: 16, color: EvoraColors.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            env.healthAdvisory,
            style: const TextStyle(fontSize: 12.5, color: EvoraColors.onSurface, height: 1.3),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PM2.5: ${env.pm25.toStringAsFixed(1)} µg/m³  •  PM10: ${env.pm10.toStringAsFixed(1)} µg/m³',
                style: const TextStyle(fontSize: 11, color: EvoraColors.onSurfaceVariant),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: EvoraColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  env.isStale ? 'Cached feed' : 'Live sensors',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: EvoraColors.primary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEnvironmentalUnavailableCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EvoraColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: EvoraColors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: EvoraColors.outline, size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Environmental Telemetry Offline',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                SizedBox(height: 2),
                Text(
                  'Sensor feeds are temporarily unreachable.',
                  style: TextStyle(fontSize: 11.5, color: EvoraColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: _isRefreshingEnv
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Reload AQI Sensors',
            onPressed: _isRefreshingEnv ? null : () => _refreshEnvironmentalData(showFeedback: true),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayEcoActionCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [EvoraColors.primary, Color(0xFF004D34)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: EvoraColors.primary.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Text(
                  "TODAY'S ECO ACTION",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              if (_ecoActionCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: EvoraColors.secondary,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, size: 12, color: EvoraColors.onSecondary),
                      SizedBox(width: 4),
                      Text(
                        'Done',
                        style: TextStyle(
                          color: EvoraColors.onSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Segregate Kitchen Scraps & Plastic Today',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Keeping biodegradable organic waste separate from recyclables facilitates clean municipal composting in the Doon Valley.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _ecoActionCompleted ? Colors.white24 : EvoraColors.secondary,
              foregroundColor: _ecoActionCompleted ? Colors.white : EvoraColors.onSecondary,
            ),
            icon: Icon(_ecoActionCompleted ? Icons.check : Icons.thumb_up_alt_outlined, size: 16),
            label: Text(_ecoActionCompleted ? 'Completed for Today (+10 Eco Coins)' : 'Mark as Done Today (+10 Eco Coins)'),
            onPressed: _ecoActionCompleted
                ? null
                : () async {
                    final authed = await AuthGuard.requireLogin(
                      context,
                      ref,
                      actionDescription: 'Sign in to record your daily eco actions and earn Eco Coins.',
                    );
                    if (authed && mounted) {
                      final uid = ref.read(authProvider).user?.uid;
                      if (uid != null) {
                        await _saveEcoActionStatus(uid);
                        final now = DateTime.now();
                        try {
                          await ref.read(ecoLedgerProvider.notifier).appendTransaction(
                                userId: uid,
                                type: EcoLedgerTransactionType.creditDailyHabit,
                                amount: 10,
                                referenceId: 'daily_${now.year}_${now.month}_${now.day}',
                                title: 'Daily Eco Action Habit',
                                description: 'Segregated household organic and dry waste in Doon Valley',
                              );
                        } catch (_) {}
                      }
                      if (!mounted) return;
                      setState(() => _ecoActionCompleted = true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Awesome! +10 EcoCoins credited to your immutable ledger.',
                          ),
                          backgroundColor: EvoraColors.primary,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard({
    required String title,
    required String subtitle,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: EvoraColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: EvoraColors.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(fontSize: 10.5, color: EvoraColors.onSurfaceVariant, height: 1.2),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
