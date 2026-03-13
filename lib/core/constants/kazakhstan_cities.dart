class KazakhstanCity {
  final String name;
  final double latitude;
  final double longitude;

  const KazakhstanCity({
    required this.name,
    required this.latitude,
    required this.longitude,
  });
}

class KazakhstanCities {
  static const String defaultCity = 'Алматы';

  static const List<KazakhstanCity> values = <KazakhstanCity>[
    KazakhstanCity(name: 'Алматы', latitude: 43.238949, longitude: 76.889709),
    KazakhstanCity(name: 'Астана', latitude: 51.169392, longitude: 71.449074),
    KazakhstanCity(name: 'Шымкент', latitude: 42.3417, longitude: 69.5901),
    KazakhstanCity(name: 'Актобе', latitude: 50.2839, longitude: 57.1669),
    KazakhstanCity(name: 'Караганда', latitude: 49.8028, longitude: 73.0877),
    KazakhstanCity(name: 'Тараз', latitude: 42.9004, longitude: 71.3655),
    KazakhstanCity(name: 'Павлодар', latitude: 52.2871, longitude: 76.9733),
    KazakhstanCity(name: 'Усть-Каменогорск', latitude: 49.9483, longitude: 82.6275),
    KazakhstanCity(name: 'Семей', latitude: 50.4111, longitude: 80.2275),
    KazakhstanCity(name: 'Костанай', latitude: 53.2145, longitude: 63.6246),
    KazakhstanCity(name: 'Кызылорда', latitude: 44.8488, longitude: 65.4823),
    KazakhstanCity(name: 'Уральск', latitude: 51.2306, longitude: 51.3865),
    KazakhstanCity(name: 'Атырау', latitude: 47.0945, longitude: 51.9238),
    KazakhstanCity(name: 'Актау', latitude: 43.6532, longitude: 51.1975),
    KazakhstanCity(name: 'Петропавловск', latitude: 54.866, longitude: 69.143),
    KazakhstanCity(name: 'Туркестан', latitude: 43.2973, longitude: 68.2518),
    KazakhstanCity(name: 'Кокшетау', latitude: 53.2833, longitude: 69.4),
    KazakhstanCity(name: 'Талдыкорган', latitude: 45.0156, longitude: 78.3739),
    KazakhstanCity(name: 'Экибастуз', latitude: 51.7237, longitude: 75.3229),
    KazakhstanCity(name: 'Рудный', latitude: 52.9729, longitude: 63.1168),
  ];

  static List<String> get names =>
      values.map((KazakhstanCity city) => city.name).toList(growable: false);

  static bool contains(String cityName) {
    return values.any((KazakhstanCity city) => city.name == cityName);
  }

  static KazakhstanCity cityByName(String cityName) {
    return values.firstWhere(
      (KazakhstanCity city) => city.name == cityName,
      orElse: () => values.firstWhere(
        (KazakhstanCity city) => city.name == defaultCity,
      ),
    );
  }
}

