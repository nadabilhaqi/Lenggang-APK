import 'dart:math' as math;

import '../models/project.dart';

/// Pasangan penari yang jarak antarpusatnya di bawah ambang aman.
class Collision {
  const Collision(this.a, this.b, this.distance);

  final String a;
  final String b;

  /// Jarak antarpusat (meter).
  final double distance;

  bool involves(String id) => a == id || b == id;
}

class CollisionDetector {
  CollisionDetector._();

  static double distance(DancerState a, DancerState b) =>
      math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));

  /// Semua pasangan dengan jarak Euclidean < [threshold] meter, diurutkan
  /// dari yang paling dekat.
  static List<Collision> find(
    Map<String, DancerState> states,
    double threshold,
  ) {
    final ids = states.keys.toList();
    final out = <Collision>[];
    for (var i = 0; i < ids.length; i++) {
      for (var j = i + 1; j < ids.length; j++) {
        final d = distance(states[ids[i]]!, states[ids[j]]!);
        if (d < threshold) out.add(Collision(ids[i], ids[j], d));
      }
    }
    out.sort((x, y) => x.distance.compareTo(y.distance));
    return out;
  }

  static Set<String> involved(List<Collision> collisions) => {
    for (final c in collisions) ...[c.a, c.b],
  };
}

/// Penari yang berdiri di dalam area sebuah benda panggung.
class ObstacleHit {
  const ObstacleHit(this.dancerId, this.objectId);

  final String dancerId;
  final String objectId;
}

class ObstacleDetector {
  ObstacleDetector._();

  /// Setengah lebar badan penari (meter) yang ikut diperhitungkan.
  static const double bodyRadius = 0.25;

  static bool inside(DancerState s, StageObject o) =>
      s.x > o.left - bodyRadius &&
      s.x < o.right + bodyRadius &&
      s.y > o.front - bodyRadius &&
      s.y < o.back + bodyRadius;

  /// Semua penari yang masuk area benda panggung (properti tari diabaikan).
  static List<ObstacleHit> find(
    Map<String, DancerState> states,
    List<StageObject> objects,
  ) => [
    for (final o in objects)
      if (o.kind == StageObjectKind.obstacle)
        for (final e in states.entries)
          if (inside(e.value, o)) ObstacleHit(e.key, o.id),
  ];
}
