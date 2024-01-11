import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:maps_flutter/location_services.dart';
import 'package:url_launcher/url_launcher.dart';

class SourceDestination extends StatefulWidget {
  const SourceDestination({Key? key});

  @override
  State<SourceDestination> createState() => _SourceDestinationState();
}

class _SourceDestinationState extends State<SourceDestination> {
  Completer<GoogleMapController> _controller = Completer();
  TextEditingController _sourceController = TextEditingController();
  TextEditingController _destinationController = TextEditingController();
  List<String> sourcePlaces = [];
  List<String> destinationPlaces = [];
  GoogleMapController? _mapController;

  Set<Marker> _markers = Set<Marker>();
  Set<Polygon> _polygons = Set<Polygon>();
  Set<Polyline> _polylines = Set<Polyline>();
  List<LatLng> polygonLatLngs = <LatLng>[];

  int _polygonIdCounter = 1;
  int _polylineIdCounter = 1;
  static final CameraPosition _kGooglePlex =
      CameraPosition(target: LatLng(17.4065, 78.4772), zoom: 14.4746);

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _setMarker(LatLng(17.4065, 78.4772));
  }

  void _setMarker(LatLng point) {
    setState(() {
      _markers.add(
        Marker(
          markerId: MarkerId('marker'),
          position: point,
        ),
      );
    });
  }

  // Function to clear polylines
  void clearPolylines() {
    setState(() {
      _polylines.clear();
    });
  }

  void _setNewPolyline(List<PointLatLng> points) {
    // Clear existing polylines
    clearPolylines();

// Add the new polyline
    final String polylineIdVal = 'polyline_$_polylineIdCounter';
    _polylineIdCounter++;

    _polylines.add(
      Polyline(
        polylineId: PolylineId(polylineIdVal),
        width: 3,
        color: Colors.blue,
        points: points
            .map(
              (point) => LatLng(point.latitude, point.longitude),
            )
            .toList(),
      ),
    );
  }

  void fetchPlaces(String input, {bool isDestination = false}) async {
    final apiKey =
        'AIzaSyDBOOKUbB5AjZGROTna4SGgfnF4_BgDX5M'; // Replace with your API key
    final apiUrl =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&types=(cities)&key=$apiKey';
    final response = await http.get(Uri.parse(apiUrl));
    final responseData = json.decode(response.body);
    setState(() {
      if (responseData['predictions'] != null) {
        if (isDestination) {
          destinationPlaces = List<String>.from(responseData['predictions']
              .map((prediction) => prediction['description']));
        } else {
          sourcePlaces = List<String>.from(responseData['predictions']
              .map((prediction) => prediction['description']));
        }
      } else {
        if (isDestination) {
          destinationPlaces = [];
        } else {
          sourcePlaces = [];
        }
      }
    });
  }

  void _updateSourceField(String value) {
    fetchPlaces(value);
  }

  void _updateDestinationField(String value) {
    fetchPlaces(value, isDestination: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Source Destination'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _sourceController,
              decoration: InputDecoration(
                labelText: 'Source',
                suffixIcon: Icon(Icons.location_on),
              ),
              onChanged: (value) {
                _updateSourceField(value);
              },
            ),
            SizedBox(height: 15),
            _buildSourcePlacesList(),
            SizedBox(height: 2),
            TextField(
              controller: _destinationController,
              decoration: InputDecoration(
                labelText: 'Destination',
                suffixIcon: Icon(Icons.location_on),
              ),
              onChanged: (value) {
                _updateDestinationField(value);
              },
            ),
            SizedBox(height: 15),
            _buildDestinationPlacesList(),
            SizedBox(height: 2),
            IconButton(
              onPressed: () async {
                if (_sourceController.text.isEmpty ||
                    _destinationController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Please enter both source and destination to search directions.',
                      ),
                    ),
                  );
                  return;
                }

                if (_sourceController.text == _destinationController.text) {
                  // Display error message for identical source and destination
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('Source and destination cannot be the same.'),
                    ),
                  );
                  return;
                }
                var directions = await LocationService().getDirections(
                  _sourceController.text,
                  _destinationController.text,
                );
                _goToPlace(
                  directions['start_location']['lat'],
                  directions['start_location']['lng'],
                  directions['bounds_ne'],
                  directions['bounds_sw'],
                );
                _setNewPolyline(directions['polyline_decoded']);

                final double destinationLatitude =
                    directions['end_location']['lat'];
                final double destinationLongitude =
                    directions['end_location']['lng'];

                final LatLng destinationLatLng =
                    LatLng(destinationLatitude, destinationLongitude);

                final Marker destinationMarker = Marker(
                  markerId: MarkerId('destination'),
                  position: destinationLatLng,
                  icon: BitmapDescriptor.defaultMarker,
                );

                setState(() {
                  _markers.add(destinationMarker);
                });
              },
              icon: Icon(Icons.search),
            ),
            Expanded(
              child: GoogleMap(
                mapType: MapType.normal,
                markers: _markers,
                polygons: _polygons,
                polylines: _polylines,
                initialCameraPosition: _kGooglePlex,
                onMapCreated: (GoogleMapController controller) {
                  _controller.complete(controller);
                },
                onTap: (point) {
                  _updateToCurrentLocation();
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    _updateToCurrentLocation();
                  },
                  style: ElevatedButton.styleFrom(
                    primary: Color.fromARGB(255, 226, 123,
                        20), // Change the button's background color here
                  ),
                  child: Text('Current Location'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    String source = _sourceController.text;
                    String destination = _destinationController.text;

                    if (source.isNotEmpty && destination.isNotEmpty) {
                      await startNavigation(source, destination);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    primary: Color.fromARGB(255, 226, 123,
                        20), // Change the button's background color here
                  ),
                  child: Text('Start Navigation'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourcePlacesList() {
    return sourcePlaces.isEmpty
        ? SizedBox.shrink()
        : Expanded(
            child: ListView.builder(
              itemCount: sourcePlaces.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(sourcePlaces[index]),
                  onTap: () async {
                    setState(() {
                      _sourceController.text = sourcePlaces[index];
                      sourcePlaces.clear();
                    });
                    // Optionally, you can perform map-related operations here
                  },
                );
              },
            ),
          );
  }

  Widget _buildDestinationPlacesList() {
    return destinationPlaces.isEmpty
        ? SizedBox.shrink()
        : Expanded(
            child: ListView.builder(
              itemCount: destinationPlaces.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(destinationPlaces[index]),
                  onTap: () async {
                    setState(() {
                      _destinationController.text = destinationPlaces[index];
                      destinationPlaces.clear();
                    });
                    // Optionally, you can perform map-related operations here
                  },
                );
              },
            ),
          );
  }

  Future<void> startNavigation(String origin, String destination) async {
    if (origin.isEmpty || destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter both source and destination to start navigation.',
          ),
        ),
      );
      return;
    }

    var directions = await LocationService().getDirections(origin, destination);

    if (directions != null) {
      // Update the map to show the route between origin and destination
      _setNewPolyline(directions['polyline_decoded']);

      // Open Google Maps app with directions
      String url =
          "https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination";
      if (await canLaunch(url)) {
        await launch(url);
      } else {
        throw 'Could not launch $url';
      }
    }
  }

  Future<void> _goToPlace(
    // Map<String, dynamic> place,
    double lat,
    double lng,
    Map<String, dynamic> boundsNe,
    Map<String, dynamic> boundsSw,
  ) async {
    // final double lat = place['geometry']['location']['lat'];
    // final double lng = place['geometry']['location']['lng'];

    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(lat, lng), zoom: 12),
      ),
    );

    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(boundsSw['lat'], boundsSw['lng']),
            northeast: LatLng(boundsNe['lat'], boundsNe['lng']),
          ),
          25),
    );
    _setMarker(LatLng(lat, lng));
  }

  Future<void> _updateToCurrentLocation() async {
    try {
      LocationPermission locationPermission =
          await Geolocator.requestPermission();

      if (locationPermission == LocationPermission.always ||
          locationPermission == LocationPermission.whileInUse) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        _goToPlace(
          position.latitude,
          position.longitude,
          {'lat': position.latitude, 'lng': position.longitude},
          {'lat': position.latitude, 'lng': position.longitude},
        );

        _setMarker(LatLng(position.latitude, position.longitude));
      } else {
        print('Location permission denied');
      }
    } catch (e) {
      print('Error getting current location: $e');
    }
  }
}
