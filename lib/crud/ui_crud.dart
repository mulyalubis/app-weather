import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../database/db_helper.dart';




class CityCrudContent extends StatefulWidget {
  final Function(String cityName) onCitySelected;
  final VoidCallback onCloseCrud;

  const CityCrudContent({
    super.key,
    required this.onCitySelected,
    required this.onCloseCrud,
  });

  @override
  State<CityCrudContent> createState() => _CityCrudContentState();
}

class _CityCrudContentState extends State<CityCrudContent> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<String> searchResults = [];
  List<String> favoriteCities = [];

  @override
  void initState() {
    super.initState();
    _loadSavedCities();
  }

  Future<void> _loadSavedCities() async {
    final cities = await DBHelper.getFavoriteCities();
    setState(() {
      favoriteCities = cities;
    });
  }

  Future<void> searchCity(String keyword) async {
    if (keyword.isEmpty) {
      setState(() => searchResults = []);
      return;
    }

    const apiKey = "625b91d1c6cb6bb7958662d3f2cdd80b";
    final url =
        "https://api.openweathermap.org/geo/1.0/direct?q=$keyword&limit=5&appid=$apiKey";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;

      setState(() {
        searchResults = data.map((e) {
          final name = e["name"];
          final country = e["country"];
          return "$name, $country";
        }).toList();
      });
    }
  }


  void _showEditDialog(int index) {
    final TextEditingController editCtrl =
        TextEditingController(text: favoriteCities[index]);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Nama Kota"),
          content: TextField(
            controller: editCtrl,
            decoration: const InputDecoration(
              hintText: "Nama kota baru",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  favoriteCities[index] = editCtrl.text;
                });
                Navigator.pop(context);
              },
              child: const Text("Simpan"),
            ),
          ],
        );
      },
    );
  }



  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent, // BIAR BACKGROUND ANIMASI KELIHATAN
      child: Column(
        children: [
          const SizedBox(height: 60),

          // 🔍 SEARCH
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (value) {
                searchCity(value);
              },
              decoration: InputDecoration(
                hintText: "Cari kota...",
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            height: MediaQuery.of(context).size.height * 0.45,
            child: ListView.builder(
              itemCount: searchResults.length,
              itemBuilder: (context, index) {
                final city = searchResults[index];

                return ListTile(
                  title: Text(city),
                  trailing: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () async {
                      if (!favoriteCities.contains(city)) {
                        await DBHelper.addFavoriteCity(city);
                        _loadSavedCities();
                      }
                    },
                  ),
                );
              },
            ),
          ),

          if (favoriteCities.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Kota Favorit",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),


            SizedBox(
              height: 300,
              child: ListView.builder(
                itemCount: favoriteCities.length,
                itemBuilder: (context, index) {
                  final city = favoriteCities[index];

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                    child: ListTile(
                      title: Text(city),

                      // klik nama kota → tampilkan cuaca
                      onTap: () {
                        widget.onCitySelected(city); // kirim kota
                        widget.onCloseCrud(); 
                      },

                      // hapus kota
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ✏️ EDIT
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () {
                              _showEditDialog(index);
                            },
                          ),

                          // 🗑 DELETE
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              await DBHelper.deleteFavoriteCity(city);
                              _loadSavedCities();
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

        ],
      ),
    );
  }
}
