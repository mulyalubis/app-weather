import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'crud/ui_crud.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env.local");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather Yav',
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

double asDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}

class _HomePageState extends State<HomePage> {
  double _backgroundHeight = 0; // awalnya belum muncul
  double _backgroundHeightDay = 0;
  double _backgroundHeightDayAll = 0;
  double _radiusBottomLeft = 0;
  double _radiusBottomRight = 0;
  double _logoOpacity = 0; // logo masih tersembunyi
  bool _showPermissionUI = false;
  bool _showWheatherUI = false;

  String visibilityKm = "";
  String windKmh = "";
  String windDir = "";
  double windDeg = 0;

  Map<String, dynamic>? weatherData;

  List<dynamic> sevenDays = [];
  String cityName = "Lokasi tidak diketahui";

  String? shortDate;
  List<String> dayDate = [];
  double? lat;
  double? lon;

  bool _showCrudUI = false;

  Future<Position?> requestLocationFully() async {
    // 1. Cek GPS hidup atau tidak
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      serviceEnabled = await Geolocator.openLocationSettings();
      if (!serviceEnabled) {
        print("GPS tetap mati.");
        return null;
      }
    }

    // 2. Cek permission
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print("Permission ditolak.");
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print("Permission ditolak permanen.");
      return null;
    }

    // 3. Ambil lokasi akurat
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.bestForNavigation,
    );
  }

  Future<Map<String, dynamic>?> getWeather(double lat, double lon) async {
    final apiKey = dotenv.env["API_KEY_WEATHER_MAP"]; // ganti

    final url =
        "https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$apiKey&units=metric";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      print("Gagal mengambil data cuaca hari ini");
      return null;
    }
  }

  Future<List<dynamic>?> get7DaysWeatherVC(double lat, double lon) async {
    final apiKey = dotenv.env["API_KEY_VISUAL_CROSSING"]; // ganti

    final url =
        "https://weather.visualcrossing.com/VisualCrossingWebServices/rest/services/timeline/$lat,$lon?unitGroup=metric&key=$apiKey&include=days&elements=datetime,temp,humidity,windspeed,winddir,visibility,conditions,icon";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // print("=== DATA 7 HARI DARI VISUAL CROSSING ===");
      // print(data["days"]);

      return data["days"];
    } else {
      print("Gagal mengambil data 7 hari dari Visual Crossing");
      print(response.body);
      return null;
    }
  }

  Future<String> getCityName(double lat, double lon) async {
    final url =
        "https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json";

    final response = await http.get(
      Uri.parse(url),
      headers: {"User-Agent": "FlutterWeatherApp/1.0"},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      return data["address"]["city"] ??
          data["address"]["town"] ??
          data["address"]["village"] ??
          data["address"]["county"] ??
          "Lokasi tidak ditemukan";
    }

    return "Lokasi tidak ditemukan";
  }

  Future<void> _loadWeatherFromCity(String city) async {
    // ambil koordinat dari nama kota (OpenWeather Geocoding)
    final apiKey = dotenv.env["API_KEY_WEATHER_MAP"]; // ganti

    final geoUrl =
        "https://api.openweathermap.org/geo/1.0/direct?q=$city&limit=1&appid=$apiKey";

    final geoRes = await http.get(Uri.parse(geoUrl));

    if (geoRes.statusCode != 200) return;

    final geoData = jsonDecode(geoRes.body) as List;
    if (geoData.isEmpty) return;

    final newLat = asDouble(geoData[0]["lat"]);
    final newLon = asDouble(geoData[0]["lon"]);

    // simpan state lokasi baru
    lat = newLat;
    lon = newLon;
    cityName = city;

    // ambil cuaca
    final weather = await getWeather(newLat, newLon);
    final days = await get7DaysWeatherVC(newLat, newLon);

    setState(() {
      weatherData = weather;
      sevenDays = days?.take(7).toList() ?? [];
      shortDate = getShortDate();
      dayDate = getNext7Days();

      if (weather != null) {
        visibilityKm = (asDouble(weather["visibility"]) / 1000).toStringAsFixed(
          1,
        );
        windKmh = (asDouble(weather["wind"]["speed"]) * 3.6).toStringAsFixed(1);
        windDeg = asDouble(weather["wind"]["deg"]);
        windDir = windDirection(windDeg);
      }
    });
  }

  // animasi kelima
  void _animateCloseCrud() {
    setState(() {
      _showCrudUI = false;
    });

    Future.delayed(const Duration(milliseconds: 1000), () {
      setState(() {
        _backgroundHeight = 0;
      });
    });

    Future.delayed(const Duration(milliseconds: 2500), () {
      setState(() {
        _backgroundHeight = MediaQuery.of(context).size.height * 0.6;
      });
    });

    Future.delayed(const Duration(milliseconds: 4100), () {
      setState(() {
        _backgroundHeightDay = MediaQuery.of(context).size.height * 0.06;
      });
    });

    Future.delayed(const Duration(milliseconds: 6000), () {
      setState(() {
        _backgroundHeightDayAll = MediaQuery.of(context).size.height * 0.32;
      });
    });

    Future.delayed(const Duration(milliseconds: 8000), () {
      setState(() {
        _showWheatherUI = true;
      });
    });
  }

  String getShortDate() {
    final now = DateTime.now();

    const hari = [
      "Senin",
      "Selasa",
      "Rabu",
      "Kamis",
      "Jumat",
      "Sabtu",
      "Minggu",
    ];

    const bulan = [
      "Januari",
      "Februari",
      "Maret",
      "April",
      "Mei",
      "Juni",
      "Juli",
      "Agustus",
      "September",
      "Oktober",
      "November",
      "Desember",
    ];

    final namaHari = hari[now.weekday - 1];
    final namaBulan = bulan[now.month - 1];

    return "$namaHari, ${now.day} $namaBulan";
  }

  List<String> getNext7Days() {
    final today = DateTime.now();

    const hari = [
      "Senin",
      "Selasa",
      "Rabu",
      "Kamis",
      "Jumat",
      "Sabtu",
      "Minggu",
    ];

    List<String> result = [];

    for (int i = 1; i <= 7; i++) {
      final nextDate = today.add(Duration(days: i));
      final indexHari = nextDate.weekday - 1;
      result.add(hari[indexHari]);
    }

    return result;
  }

  /// Mengubah derajat (0..360) menjadi kode arah (N, NE, E, SE, S, SW, W, NW)
  String windDirection(double deg) {
    // jika deg null atau tidak valid, kembalikan tanda '-'
    if (deg.isNaN) return "-";

    final d = deg % 360; // pastikan 0..359.999
    if (d >= 338 || d <= 22) return "N";
    if (d <= 67) return "NE";
    if (d <= 112) return "E";
    if (d <= 157) return "SE";
    if (d <= 202) return "S";
    if (d <= 247) return "SW";
    if (d <= 292) return "W";
    return "NW";
  }

  final Map<String, String> weatherTranslate = {
    // ===== VISUAL CROSSING =====
    "Clear": "Cerah",
    "Partially cloudy": "Berawan sebagian",
    "Partly cloudy": "Berawan sebagian",
    "Cloudy": "Berawan",
    "Overcast": "Mendung",
    "Rain": "Hujan",
    "Rain, Partially cloudy": "Hujan, berawan sebagian",
    "Rain, Overcast": "Hujan, mendung",
    "Snow": "Salju",
    "Fog": "Kabut",
    "Thunderstorm": "Badai petir",
    "Drizzle": "Gerimis",
    "Windy": "Berangin",
    "Hail": "Hujan es",

    // ===== OPENWEATHER MAIN =====
    "Mist": "Kabut tipis",
    "Smoke": "Asap",
    "Haze": "Kabut",
    "Dust": "Debu",
    "Sand": "Berpasir",
    "Ash": "Abu vulkanik",
    "Squall": "Angin kencang tiba-tiba",
    "Tornado": "Tornado",
    "Clouds": "Berawan",

    // ===== OPENWEATHER DESCRIPTION =====
    "clear sky": "Langit cerah",
    "few clouds": "Sedikit berawan",
    "scattered clouds": "Awan tersebar",
    "broken clouds": "Awan terpecah",
    "overcast clouds": "Mendung",

    "light rain": "Hujan ringan",
    "moderate rain": "Hujan sedang",
    "heavy intensity rain": "Hujan deras",
    "very heavy rain": "Hujan sangat deras",
    "extreme rain": "Hujan ekstrem",

    "freezing rain": "Hujan membeku",
    "light intensity shower rain": "Hujan gerimis ringan",
    "shower rain": "Hujan deras singkat",
    "heavy intensity shower rain": "Hujan deras singkat intens",

    "light snow": "Salju ringan",
    "snow": "Salju",
    "heavy snow": "Salju lebat",
    "sleet": "Hujan es",
    "light shower sleet": "Hujan es ringan",
    "shower sleet": "Hujan es singkat",
    "light rain and snow": "Hujan dan salju ringan",
    "rain and snow": "Hujan dan salju",
    "light shower snow": "Salju ringan singkat",
    "shower snow": "Salju singkat",
    "heavy shower snow": "Salju lebat singkat",

    "mist": "Kabut tipis",
    "smoke": "Asap",
    "haze": "Kabut",
    "sand/dust whirls": "Putaran pasir/debu",
    "fog": "Kabut",
    "sand": "Pasir",
    "dust": "Debu",
    "volcanic ash": "Abu vulkanik",
    "squalls": "Angin kencang",
    "tornado": "Tornado",
  };

  String translateCondition(String? eng) {
    if (eng == null) return "-";
    return weatherTranslate[eng] ?? eng;
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // animasi pertama

      Future.delayed(const Duration(milliseconds: 1000), () {
        setState(() {
          _backgroundHeight =
              MediaQuery.of(context).size.height *
              0.65; // background turun dari atas
          _radiusBottomLeft = 70;
          _radiusBottomRight = 70;
        });
      });

      Future.delayed(const Duration(milliseconds: 2000), () {
        setState(() {
          _logoOpacity = 1; // logo fade in
        });
      });

      // Logo fade-out setelah selesai muncul
      Future.delayed(const Duration(milliseconds: 4500), () {
        setState(() {
          _logoOpacity = 0; // logo hilang kembali
        });
      });

      // Tarik layar ke atas setelah logo menghilang
      Future.delayed(const Duration(milliseconds: 6500), () {
        setState(() {
          _backgroundHeight = 0; // angka besar biar layar keangkat total
          _radiusBottomLeft = 0;
          _radiusBottomRight = 0;
        });
      });

      Future.delayed(const Duration(milliseconds: 8500), () {
        setState(() {
          _backgroundHeight =
              MediaQuery.of(context).size.height *
              0.2; // 0.2 background turun dari atas ke bawah
          _radiusBottomLeft = 70;
          _radiusBottomRight = 70;
        });
      });

      // Tampilkan UI izin lokasi setelah semua animasi
      Future.delayed(const Duration(milliseconds: 10000), () {
        setState(() {
          _showPermissionUI = true;
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        alignment: AlignmentDirectional.center,
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 1500),
              curve: Curves.linear,
              width: screenWidth * 0.7,
              height: _backgroundHeightDay,
              margin: EdgeInsets.only(top: screenHeight * 0.6),
              decoration: const BoxDecoration(
                color: Color(0xaaFFD54F),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ), // warna putih yang naik
              ),
            ),
          ),

          // Background yang naik ke atas
          Align(
            alignment: Alignment.topCenter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 1500),
              curve: Curves.easeOutCubic,
              width: double.infinity,
              height: _backgroundHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(_radiusBottomLeft),
                  bottomRight: Radius.circular(_radiusBottomRight),
                ),
                color: Color(0xFFCFD8DC), // warna putih yang naik
              ),
            ),
          ),

          // Logo muncul fade-in di tengah
          AnimatedOpacity(
            opacity: _logoOpacity,
            duration: const Duration(seconds: 2),
            curve: Curves.easeIn,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/logo-2.jpg',
                width: 150,
                height: 150,
                fit: BoxFit.cover,
              ),
            ),
          ),

          if (_showPermissionUI) ...[
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Padding(padding: EdgeInsets.all(screenHeight * 0.03)),

                Text(
                  'Izinkan App Mengakses Lokasi Perangkat?',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Tombol YA
                Row(
                  spacing: 20,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        // Minta izin dan ambil lokasi
                        Position? pos = await requestLocationFully();

                        // Debug print
                        // print("HASIL POSISI: $pos");
                        // print("STATUS PERMISSION: ${await Geolocator.checkPermission()}");
                        // print("GPS AKTIF? ${await Geolocator.isLocationServiceEnabled()}");

                        if (pos != null) {
                          setState(() {
                            lat = asDouble(pos.latitude);
                            lon = asDouble(pos.longitude);

                            shortDate = getShortDate();
                            dayDate = getNext7Days();
                          });

                          // Ambil nama kota dari Nominatim
                          final city = await getCityName(
                            pos.latitude,
                            pos.longitude,
                          );
                          setState(() {
                            cityName = city;
                          });
                          // print("NAMA KOTA (Nominatim): $cityName");

                          final data = await getWeather(
                            pos.latitude,
                            pos.longitude,
                          );

                          final days = await get7DaysWeatherVC(
                            pos.latitude,
                            pos.longitude,
                          );

                          if (days != null) {
                            setState(() {
                              sevenDays = days
                                  .take(7)
                                  .toList(); // ambil 7 hari saja
                            });
                          }

                          if (data != null) {
                            setState(() {
                              weatherData = data;
                              // print(data);

                              visibilityKm =
                                  (asDouble(data["visibility"]) / 1000)
                                      .toStringAsFixed(1);

                              // wind speed m/s → km/h
                              windKmh = (asDouble(data["wind"]["speed"]) * 3.6)
                                  .toStringAsFixed(1);

                              // wind direction degrees
                              windDeg = asDouble(data["wind"]["deg"]);
                              windDir = windDirection(windDeg);
                            });
                          }
                        }

                        // animasi ketiga

                        Future.delayed(const Duration(milliseconds: 100), () {
                          setState(() {
                            _showPermissionUI = false;
                          });
                        });

                        Future.delayed(const Duration(milliseconds: 1000), () {
                          setState(() {
                            _backgroundHeight = 0;
                          });
                        });

                        Future.delayed(const Duration(milliseconds: 2500), () {
                          setState(() {
                            _backgroundHeight = screenHeight * 0.6;
                          });
                        });

                        Future.delayed(const Duration(milliseconds: 4000), () {
                          setState(() {
                            _backgroundHeightDay = screenHeight * 0.06;
                          });
                        });

                        Future.delayed(const Duration(milliseconds: 6000), () {
                          setState(() {
                            _backgroundHeightDayAll = screenHeight * 0.32;
                          });
                        });

                        Future.delayed(const Duration(milliseconds: 7500), () {
                          setState(() {
                            _showWheatherUI = true;
                          });
                        });
                      },
                      child: const Text(
                        "Ya",
                        style: TextStyle(color: Colors.black),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Tombol TIDAK
                    ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (BuildContext context) {
                            Future.delayed(
                              const Duration(milliseconds: 1500),
                              () {
                                if (context.mounted) {
                                  Navigator.of(context).pop(true);
                                }
                              },
                            );

                            return Dialog(
                              constraints: BoxConstraints(
                                maxWidth: 200,
                                maxHeight: 80,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Fitur Tidak Dapat Digunakan Tanpa Lokasi',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      child: const Text(
                        "Tidak",
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],

          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 1500),
              curve: Curves.decelerate,
              width: double.infinity,
              height: _backgroundHeightDayAll,
              decoration: BoxDecoration(
                color: Color(0xFFCFD8DC), // warna putih yang naik
              ),
            ),
          ),

          if (_showWheatherUI) ...[
            Column(
              children: [
                Padding(padding: EdgeInsets.all(screenHeight * 0.03)),

                Text(
                  shortDate ?? "Tanggal belum didapat",
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                ),

                Padding(padding: EdgeInsets.all(screenHeight * 0.01)),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 5,
                  children: [
                    Icon(Icons.location_pin, size: 35, color: Colors.black),
                    Text(cityName, style: TextStyle(fontSize: 19)),
                  ],
                ),

                if (weatherData != null) ...[
                  Image.network(
                    "https://openweathermap.org/img/wn/${weatherData!["weather"][0]["icon"]}@4x.png",
                    width: 200,
                    height: 200,
                  ),

                  // suhu
                  Text(
                    "${asDouble(weatherData!["main"]["temp"]).toStringAsFixed(1)}°",
                    style: TextStyle(fontSize: 35, fontWeight: FontWeight.bold),
                  ),

                  Text(
                    translateCondition(
                      weatherData!["weather"][0]["description"],
                    ),
                    style: TextStyle(fontSize: 21),
                    textAlign: TextAlign.center,
                  ),

                  Padding(padding: EdgeInsets.all(screenHeight * 0.01)),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 40,
                    children: [
                      Column(
                        children: [
                          Text("Jarak Pandang"),
                          Icon(Icons.visibility, size: 28),
                          Text("$visibilityKm km"),
                        ],
                      ),

                      Column(
                        children: [
                          Text("Angin"),
                          Icon(Icons.air, size: 28),
                          Text("$windKmh km/jam ($windDir)"),
                        ],
                      ),
                    ],
                  ),
                ],

                Padding(padding: EdgeInsets.all(screenHeight * 0.0115)),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 25,
                  children: [
                    Text(
                      '7 hari',
                      style: TextStyle(fontSize: 20, color: Colors.white),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        // animasi keempat

                        Future.delayed(const Duration(milliseconds: 100), () {
                          setState(() {
                            _showWheatherUI = false;
                          });
                        });

                        Future.delayed(const Duration(milliseconds: 1000), () {
                          setState(() {
                            _backgroundHeightDayAll = 0;
                          });
                        });

                        Future.delayed(const Duration(milliseconds: 2500), () {
                          setState(() {
                            _backgroundHeightDay = 0;
                          });
                        });

                        Future.delayed(const Duration(milliseconds: 4200), () {
                          setState(() {
                            _backgroundHeight = 0;
                          });
                        });

                        Future.delayed(const Duration(milliseconds: 6000), () {
                          setState(() {
                            _backgroundHeight = screenHeight * 1;
                          });
                        });

                        Future.delayed(const Duration(milliseconds: 7500), () {
                          setState(() {
                            _showCrudUI = true;
                          });
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                      ),
                      child: Text(
                        'Kelola Kota Favorit',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),

                Padding(padding: EdgeInsets.all(screenHeight * 0.002)),

                Container(
                  margin: EdgeInsets.only(
                    top: screenHeight * .02,
                    left: 10,
                    right: 10,
                  ),
                  width: screenWidth,
                  height: screenHeight * .31,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(5),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: .65,
                        ),
                    itemCount: dayDate.length,
                    itemBuilder: (context, index) {
                      return Container(
                        alignment: Alignment.topCenter,
                        decoration: BoxDecoration(
                          color: const Color(0xff4FC3F7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            Text(dayDate[index]),

                            Image.network(
                              "https://raw.githubusercontent.com/visualcrossing/WeatherIcons/main/PNG/4th%20Set%20-%20Color/${sevenDays[index]["icon"]}.png",
                              width: 50,
                              height: 50,
                              errorBuilder: (c, o, s) =>
                                  const Icon(Icons.cloud),
                            ),

                            Text(
                              "${asDouble(sevenDays[index]["temp"]).toStringAsFixed(1)}°C",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            Text(
                              translateCondition(
                                sevenDays[index]["conditions"] ?? "",
                              ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],

          if (_showCrudUI) ...[
            Positioned.fill(
              child: CityCrudContent(
                onCitySelected: (city) async {
                  await _loadWeatherFromCity(city);
                },
                onCloseCrud: () {
                  _animateCloseCrud();
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
