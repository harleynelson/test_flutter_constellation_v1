class Constellation {
  final String name;
  final String description;
  final List<Star> stars;
  final List<List<String>> lines;

  Constellation({
    required this.name,
    required this.description,
    required this.stars,
    required this.lines,
  });

  factory Constellation.fromMap(Map<String, dynamic> map) {
    return Constellation(
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      stars: (map['stars'] as List<dynamic>)
          .map((starMap) => Star.fromMap(starMap as Map<String, dynamic>))
          .toList(),
      lines: (map['lines'] as List<dynamic>)
          .map((line) => (line as List<dynamic>)
              .map((id) => id as String)
              .toList())
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'stars': stars.map((star) => star.toMap()).toList(),
      'lines': lines,
    };
  }

  static List<Map<String, dynamic>> getSampleData() {
    return [
      {
        "name": "Ursa Major",
        "description": "The Great Bear, contains the Big Dipper asterism",
        "stars": [
          {"id": "alpha", "name": "Dubhe", "magnitude": 1.79, "x": 0.2, "y": 0.3},
          {"id": "beta", "name": "Merak", "magnitude": 2.37, "x": 0.25, "y": 0.35},
          {"id": "gamma", "name": "Phecda", "magnitude": 2.44, "x": 0.3, "y": 0.4},
          {"id": "delta", "name": "Megrez", "magnitude": 3.31, "x": 0.35, "y": 0.38},
          {"id": "epsilon", "name": "Alioth", "magnitude": 1.77, "x": 0.4, "y": 0.35},
          {"id": "zeta", "name": "Mizar", "magnitude": 2.27, "x": 0.45, "y": 0.32},
          {"id": "eta", "name": "Alkaid", "magnitude": 1.86, "x": 0.5, "y": 0.25}
        ],
        "lines": [
          ["alpha", "beta"],
          ["beta", "gamma"],
          ["gamma", "delta"],
          ["delta", "epsilon"],
          ["epsilon", "zeta"],
          ["zeta", "eta"]
        ]
      },
      {
        "name": "Cassiopeia",
        "description": "Named after the queen in Greek mythology, has a distinctive W shape",
        "stars": [
          {"id": "alpha", "name": "Schedar", "magnitude": 2.24, "x": 0.7, "y": 0.2},
          {"id": "beta", "name": "Caph", "magnitude": 2.28, "x": 0.8, "y": 0.15},
          {"id": "gamma", "name": "Navi", "magnitude": 2.47, "x": 0.65, "y": 0.25},
          {"id": "delta", "name": "Ruchbah", "magnitude": 2.68, "x": 0.75, "y": 0.25},
          {"id": "epsilon", "name": "Segin", "magnitude": 3.38, "x": 0.6, "y": 0.3}
        ],
        "lines": [
          ["alpha", "beta"],
          ["beta", "gamma"],
          ["gamma", "delta"],
          ["delta", "epsilon"]
        ]
      }
    ];
  }
}

class Star {
  final String id;
  final String name;
  final double magnitude;
  final double x;
  final double y;

  Star({
    required this.id,
    required this.name,
    required this.magnitude,
    required this.x,
    required this.y,
  });

  factory Star.fromMap(Map<String, dynamic> map) {
    return Star(
      id: map['id'] as String,
      name: map['name'] as String,
      magnitude: map['magnitude'] as double,
      x: map['x'] as double,
      y: map['y'] as double,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'magnitude': magnitude,
      'x': x,
      'y': y,
    };
  }
}