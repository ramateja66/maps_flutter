import 'dart:convert';

import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'dart:convert' as convert;

class LocationService {
  final String key = 'AIzaSyDBOOKUbB5AjZGROTna4SGgfnF4_BgDX5M';

  Future<String?> getPlaceId(String input) async {
    final String url =
        'https://maps.googleapis.com/maps/api/place/findplacefromtext/json?input=$input&inputtype=textquery&key=$key';

    var response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      var json = convert.jsonDecode(response.body);

      // Check if there are candidates in the response
      if (json['candidates'] != null && json['candidates'].isNotEmpty) {
        var placeId = json['candidates'][0]['place_id'] as String;
        return placeId;
      }
    }

    // Return null if there are no candidates or if there's an error
    return null;
  }

  Future<Map<String, dynamic>> getDirections(String origin, String destination,
      {http.Client? httpClient}) async {
    final String url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination&key=$key';

    var response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      var json = convert.jsonDecode(response.body);

      var results = {
        'bounds_ne': json['routes'][0]['bounds']['northeast'],
        'bounds_sw': json['routes'][0]['bounds']['southwest'],
        'start_location': json['routes'][0]['legs'][0]['start_location'],
        'end_location': json['routes'][0]['legs'][0]['end_location'],
        'polyline': json['routes'][0]['overview_polyline']['points'],
        'polyline_decoded': PolylinePoints()
            .decodePolyline(json['routes'][0]['overview_polyline']['points']),
      };

      print(results);
      return results;
    } else {
      // Return null or handle error as needed
      return {};
    }
  }
}
