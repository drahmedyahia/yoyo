# Earth to Moon Learning Game

Flutter Android game:
- Arabic / English
- Local / offline
- 20 difficulty levels
- Earth-to-Moon space journey
- Stage 1 — 3D journey on NASA's Orion spacecraft (lib/rocket_journey.dart, lib/space3d.dart):
  - Real-time 3D (perspective camera, lit meshes, textured planets) drawn with Canvas.drawVertices.
  - Earth and Moon are 3D spheres textured with real NASA maps (Blue Marble, LRO Moon) at their
    real apparent size for the distance travelled; the sky is NASA's Deep Star Map of the Milky Way.
  - SLS launch with booster and core-stage separation, gravity turn, solar-array deployment,
    trans-lunar injection, rear camera watching Earth shrink, Earthrise over the Moon in lunar orbit.
  - Obstacles are space rocks and meteors (glowing shooting stars in the mesosphere) destroyed with a laser;
    a giant asteroid guards the Moon.
  - Real NASA photos (Artemis I, Apollo 8/17, ISS) appear with the facts along the way.
  - Sounds: real Artemis II launch roar recorded at the pad (NASA), real Apollo 11 "The Eagle has landed"
    audio, plus generated space ambience, engine, laser, explosion and countdown effects.
- Educational questions
- Monsters with increasing level size (quiz levels)

GitHub Actions builds the release APK automatically after pushing to main/master.

## Media credits

All photos, maps and recordings in `assets/` are from NASA (public domain):
NASA Image and Video Library (Artemis I launch NHQ202211160016 / NHQ202211160200, Orion art001e000673 /
art001e002129, ISS iss01-389-023 / iss029e034092, comet NEOWISE iss063e040067, Blue Marble as17-148-22727,
Earthrise as08-14-2383, Artemis II launch pad audio), NASA Earth Observatory (Blue Marble textures, cloud map),
NASA Scientific Visualization Studio (CGI Moon Kit LRO color map, Deep Star Maps 2020).
Other sound effects in `assets/audio/` were generated for this project.
