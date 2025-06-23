import 'dart:async'; // Required for StreamSubscription
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:harkai/features/home/utils/incidences.dart';
import 'package:harkai/features/home/utils/markers.dart';
import 'package:harkai/features/home/widgets/header.dart';
import 'package:harkai/core/services/location_service.dart';
import 'package:harkai/features/home/screens/home.dart';
import 'package:harkai/l10n/app_localizations.dart';
import 'package:pay/pay.dart';
import '../widgets/incident_tile.dart';
import '../widgets/map_view.dart';
import 'package:harkai/features/home/utils/extensions.dart';

class IncidentScreen extends StatefulWidget {
  final MakerType incidentType;
  final User? currentUser;

  const IncidentScreen({
    super.key,
    required this.incidentType,
    required this.currentUser,
  });

  @override
  State<IncidentScreen> createState() => _IncidentScreenState();
}

class _IncidentScreenState extends State<IncidentScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final LocationService _locationService = LocationService();

  List<IncidenceData> _allFetchedIncidents = [];
  List<IncidenceData> _displayedIncidents = [];
  Position? _currentPosition;
  bool _isLoadingInitialData = true;
  String _error = '';

  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<List<IncidenceData>>? _incidentsStreamSubscription;

  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';

  late final Future<PaymentConfiguration> _googlePayConfigFuture;
  final TextEditingController _donationAmountController =
      TextEditingController();

  static const double _maxDistanceInMeters = 100000; // 100km

  AppLocalizations get localizations => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _googlePayConfigFuture =
        PaymentConfiguration.fromAsset('google_pay.json');
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchTerm = _searchController.text;
          _processIncidentsUpdate(_allFetchedIncidents);
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_incidentsStreamSubscription == null &&
        _positionStreamSubscription == null) {
      _initializeScreenData();
    }
  }

  Future<void> _initializeScreenData() async {
    await _fetchInitialUserLocation();
    _listenToIncidents();
    _startListeningToLocationUpdates();
  }

  Future<void> _fetchInitialUserLocation() async {
    if (!mounted) return;
    setState(() {
      _isLoadingInitialData = true;
      _error = '';
    });
    try {
      final locationResult = await _locationService.getInitialPosition();
      if (!mounted) return;
      if (locationResult.success && locationResult.data != null) {
        _currentPosition = locationResult.data;
      } else {
        _currentPosition = null;
        _error = locationResult.errorMessage ??
            localizations.mapCurrentUserLocationNotAvailable;
      }
    } catch (e) {
      if (!mounted) return;
      _currentPosition = null;
      _error = localizations.mapErrorFetchingLocation(e.toString());
    }
  }

  void _listenToIncidents() {
    if (!mounted) return;
    _incidentsStreamSubscription?.cancel();

    if (_currentPosition == null ||
        (_isLoadingInitialData && _allFetchedIncidents.isEmpty)) {
      setState(() {
        _isLoadingInitialData = true;
      });
    }

    _incidentsStreamSubscription = _firestoreService
        .getIncidencesStreamByType(widget.incidentType)
        .listen(
      (incidentsOfType) {
        if (!mounted) return;
        _allFetchedIncidents = incidentsOfType;
        _processIncidentsUpdate(_allFetchedIncidents);
        setState(() {
          _isLoadingInitialData = false;
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _error = localizations.incidentReportFailed("incidents");
          _allFetchedIncidents = [];
          _displayedIncidents = [];
          _isLoadingInitialData = false;
        });
      },
    );
  }

  void _startListeningToLocationUpdates() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = _locationService.getPositionStream().listen(
      (Position newPosition) {
        if (mounted) {
          final bool positionChangedSignificantly = _currentPosition == null ||
              Geolocator.distanceBetween(
                    _currentPosition!.latitude,
                    _currentPosition!.longitude,
                    newPosition.latitude,
                    newPosition.longitude,
                  ) >
                  50;

          _currentPosition = newPosition;
          if (positionChangedSignificantly) {
            _processIncidentsUpdate(List.from(_allFetchedIncidents));
          }
        }
      },
      onError: (error) {
        debugPrint("Error in IncidentScreen location stream: $error");
        if (mounted) {
          setState(() {
            _error = localizations.mapErrorFetchingLocation(error.toString());
          });
        }
      },
    );
  }

  void _processIncidentsUpdate(List<IncidenceData> allIncidents) {
    if (!mounted) return;

    List<IncidenceData> filteredIncidents = List.from(allIncidents);

    if (_currentPosition != null) {
      filteredIncidents.removeWhere((incident) {
        final distance = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          incident.latitude,
          incident.longitude,
        );
        incident.distance = distance;
        return distance > _maxDistanceInMeters;
      });
    } else {
      for (var incident in filteredIncidents) {
        incident.distance = null;
      }
    }

    if (_searchTerm.isNotEmpty) {
      filteredIncidents.removeWhere((incident) => !incident.description
          .toLowerCase()
          .contains(_searchTerm.toLowerCase()));
    }

    if (widget.incidentType == MakerType.pet) {
      final now = DateTime.now();
      final twentyFourHoursAgo = now.subtract(const Duration(days: 1));
      filteredIncidents.removeWhere((incident) {
        return incident.timestamp.toDate().isBefore(twentyFourHoursAgo);
      });
    } else if (widget.incidentType != MakerType.place) {
      final now = DateTime.now();
      final oneHourAgo = now.subtract(const Duration(hours: 1));
      filteredIncidents.removeWhere((incident) {
        return incident.timestamp.toDate().isBefore(oneHourAgo);
      });
    }

    if (_currentPosition != null) {
      filteredIncidents.sort((a, b) => (a.distance ?? double.maxFinite)
          .compareTo(b.distance ?? double.maxFinite));
    }

    bool listChanged = true;
    if (_displayedIncidents.length == filteredIncidents.length) {
      listChanged = false;
      for (int i = 0; i < _displayedIncidents.length; i++) {
        if (_displayedIncidents[i].id != filteredIncidents[i].id) {
          listChanged = true;
          break;
        }
      }
    }

    if (listChanged) {
      setState(() {
        _displayedIncidents = filteredIncidents;
      });
    }
  }

  void _navigateToIncidentMap(IncidenceData incident) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.05,
            vertical: screenHeight * 0.1,
          ),
          child: SizedBox(
            width: screenWidth * 0.9,
            height: screenHeight * 0.7,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(15.0),
                  child: IncidentMapViewContent(
                    incident: incident,
                    incidentTypeForExpiry: widget.incidentType,
                  ),
                ),
                Positioned(
                  top: 8.0,
                  left: 8.0,
                  child: Material(
                    color: Colors.black.withOpacity(0.6),
                    shape: const CircleBorder(),
                    elevation: 4.0,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20.0),
                      onTap: () => Navigator.of(dialogContext).pop(),
                      child: const Padding(
                        padding: EdgeInsets.all(6.0),
                        child: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getScreenTitleText() {
    final markerInfo = getMarkerInfo(widget.incidentType, localizations);
    return localizations.incidentScreenTitle(markerInfo?.title ??
        widget.incidentType.name.capitalizeAllWords());
  }

  void _showDonationModal() {
    final markerInfo = getMarkerInfo(widget.incidentType, localizations);
    final Color accentColor = markerInfo?.color ?? Colors.blueGrey;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF011935),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
            side: BorderSide(color: accentColor, width: 2),
          ),
          title: Text(
            localizations.donationDialogTitle,
            style: TextStyle(color: accentColor, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _donationAmountController,
            builder: (context, value, child) {
              final amount = value.text.trim().isEmpty ? "0.00" : value.text.trim();
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    localizations.donationDialogContent(amount),
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _donationAmountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: localizations.donationAmountHint,
                      hintStyle:
                          TextStyle(color: Colors.white.withOpacity(0.7)),
                      prefixIcon:
                          Icon(Icons.attach_money, color: accentColor),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30.0),
                        borderSide: BorderSide(color: accentColor.withOpacity(0.5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30.0),
                        borderSide: BorderSide(color: accentColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FutureBuilder<PaymentConfiguration>(
                    future: _googlePayConfigFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done) {
                        if (snapshot.hasData) {
                          return GooglePayButton(
                            paymentConfiguration: snapshot.data!,
                            paymentItems: [
                              PaymentItem(
                                label: localizations.donationLabel,
                                amount: amount,
                                status: PaymentItemStatus.final_price,
                              )
                            ],
                            onPaymentResult: (Map<String, dynamic> result) {
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        localizations.donationSuccessMessage)),
                              );
                              _donationAmountController.clear();
                            },
                            loadingIndicator: const Center(
                                child: CircularProgressIndicator()),
                            onError: (error) {
                              debugPrint("Google Pay Error: $error");
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        localizations.donationFailedMessage)),
                              );
                            },
                            type: GooglePayButtonType.donate,
                            theme: GooglePayButtonTheme.dark,
                            width: double.infinity,
                          );
                        } else {
                          return Text("Error loading payment configuration.",
                              style: TextStyle(color: Colors.red));
                        }
                      }
                      return const Center(child: CircularProgressIndicator());
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                localizations.incidentImageModalCloseButton,
                style: TextStyle(color: accentColor),
              ),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final markerInfo = getMarkerInfo(widget.incidentType, localizations);
    final Color incidentColor = markerInfo?.color ?? Colors.blueGrey;

    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      body: SafeArea(
        child: Column(
          children: [
            HomeHeaderWidget(
              currentUser: widget.currentUser,
              onLogoTap: () {
                Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const Home()),
                    (Route<dynamic> route) => false);
              },
              isLongPressEnabled: false,
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: Text(
                _getScreenTitleText(),
                style: const TextStyle(
                  color: Color(0xFF57D463),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: localizations.hintSearch,
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  prefixIcon:
                      Icon(Icons.search, color: Colors.white.withOpacity(0.7)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                    borderSide: const BorderSide(color: Color(0xFF57D463)),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
                  suffixIcon: _searchTerm.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear,
                              color: Colors.white.withOpacity(0.7)),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                ),
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 10.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(25),
                      spreadRadius: 0,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _buildBody(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.favorite, color: Colors.white),
                  label: Text(
                    localizations.donationButtonText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: incidentColor,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    elevation: 5.0,
                  ),
                  onPressed: _showDonationModal,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoadingInitialData && _displayedIncidents.isEmpty) {
      return Center(
          child:
              CircularProgressIndicator(color: Theme.of(context).primaryColor));
    }
    if (_error.isNotEmpty && _displayedIncidents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(_error,
              style: const TextStyle(color: Colors.red, fontSize: 16),
              textAlign: TextAlign.center),
        ),
      );
    }
    if (_displayedIncidents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _searchTerm.isNotEmpty
                ? localizations.searchNoResults + _searchTerm
                : localizations.incidentFeedNoIncidentsFound(
                    getMarkerInfo(widget.incidentType, localizations)?.title ??
                        widget.incidentType.name.capitalizeAllWords()),
            style: const TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _displayedIncidents.length,
      itemBuilder: (context, index) {
        final incident = _displayedIncidents[index];
        return IncidentTile(
          incident: incident,
          distance: incident.distance,
          onTap: () => _navigateToIncidentMap(incident),
          localizations: localizations,
        );
      },
    );
  }

  @override
  void dispose() {
    _donationAmountController.dispose();
    _searchController.removeListener(() {});
    _searchController.dispose();
    _positionStreamSubscription?.cancel();
    _incidentsStreamSubscription?.cancel();
    super.dispose();
  }
}