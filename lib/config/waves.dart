/// One phase of a run: what spawns, how often, and from when.
///
/// The table is read top-to-bottom; the last entry whose [from] has passed is
/// the live wave. Retuning difficulty on stream is editing numbers here.
class WaveSpec {
  const WaveSpec({
    required this.from,
    required this.interval,
    required this.weights,
    required this.label,
  });

  /// Run time in seconds at which this wave takes over.
  final double from;

  /// Seconds between spawn events during this wave.
  final double interval;

  /// Agent id to relative odds. An id absent here cannot spawn yet.
  final Map<String, int> weights;

  /// Shown in the HUD when the wave starts.
  final String label;
}

/// The escalation table. Roughly: scrapers, then swarms, then armour, then
/// everything at once.
const waveTable = <WaveSpec>[
  WaveSpec(
    from: 0,
    interval: 0.85,
    weights: {'scraper': 10},
    label: 'UNAUTHENTICATED CRAWL',
  ),
  WaveSpec(
    from: 25,
    interval: 0.75,
    weights: {'scraper': 10, 'swarmlet': 5},
    label: 'FORK BOMB DETECTED',
  ),
  WaveSpec(
    from: 55,
    interval: 0.7,
    weights: {'scraper': 8, 'swarmlet': 6, 'crawler': 3},
    label: 'DEEP CRAWLERS INBOUND',
  ),
  WaveSpec(
    from: 90,
    interval: 0.62,
    weights: {'scraper': 7, 'swarmlet': 6, 'crawler': 4, 'injector': 4},
    label: 'PROMPT INJECTION CAMPAIGN',
  ),
  WaveSpec(
    from: 140,
    interval: 0.52,
    weights: {'scraper': 5, 'swarmlet': 7, 'crawler': 6, 'injector': 5},
    label: 'COORDINATED BREACH',
  ),
  WaveSpec(
    from: 200,
    interval: 0.42,
    weights: {'scraper': 4, 'swarmlet': 8, 'crawler': 7, 'injector': 6},
    label: 'CONTROL PLANE OVERRUN',
  ),
];

/// The wave in force at [elapsed] seconds.
WaveSpec waveAt(double elapsed) {
  var current = waveTable.first;
  for (final wave in waveTable) {
    if (elapsed >= wave.from) current = wave;
  }
  return current;
}
