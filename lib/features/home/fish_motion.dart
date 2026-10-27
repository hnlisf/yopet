import 'dart:math' as math;
import 'package:flutter/painting.dart';

/// Continuous steering in aquarium pixels, shared by normal and reactive swims.
class FishMotion {
  FishMotion(this.position, {this.velocity = Offset.zero});
  Offset position;
  Offset velocity;

  void step(
    double dt, {
    required Offset target,
    required Size tank,
    required Iterable<Offset> neighbours,
    double speed = 24,
    double personalSpace = 90,
    double steering = .9,
  }) {
    dt = dt.clamp(0, .05);
    final delta = target - position;
    var desired = delta.distance < 1
        ? Offset.zero
        : delta / delta.distance * speed * (delta.distance / 70).clamp(.25, 1);
    for (final other in neighbours) {
      var away = position - other;
      final distance = away.distance;
      if (distance >= personalSpace) continue;
      if (distance < .001) away = const Offset(1, -.5);
      desired +=
          away / away.distance * speed * 1.8 * (1 - distance / personalSpace);
    }
    // Soft walls steer before contact, rather than bouncing off a clamp.
    const margin = 58.0;
    desired += Offset(
      position.dx < margin
          ? speed
          : position.dx > tank.width - margin
          ? -speed
          : 0,
      position.dy < margin
          ? speed
          : position.dy > tank.height - margin
          ? -speed
          : 0,
    );
    if (desired.distance > speed) desired = desired / desired.distance * speed;
    // Bend through a gentle arc instead of braking into a straight reversal.
    // The acceleration cap below keeps this steering continuous.
    if (velocity.distance > speed * .25 &&
        velocity.dx * desired.dx < 0 &&
        velocity.dx.abs() > velocity.dy.abs()) {
      final bend = velocity.dy.abs() > 1
          ? velocity.dy.sign
          : (position.dy > tank.height / 2 ? -1.0 : 1.0);
      desired = Offset(desired.dx * .65, desired.dy + bend * speed * .40);
      if (desired.distance > speed) {
        desired = desired / desired.distance * speed;
      }
    }
    var change = desired - velocity;
    final maxChange = speed * steering.clamp(.3, 1.5) * dt;
    if (change.distance > maxChange) {
      change = change / change.distance * maxChange;
    }
    velocity += change;
    position += velocity * dt;
    position = Offset(
      position.dx.clamp(0, math.max(0, tank.width)),
      position.dy.clamp(0, math.max(0, tank.height)),
    );
  }
}
