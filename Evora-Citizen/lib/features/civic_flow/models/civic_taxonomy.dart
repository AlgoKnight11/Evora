/// Official EVORA Municipal Civic Taxonomy & Multi-Department Routing Catalog.
///
/// Serves as the single source of truth shared between the CivicFlow Grievance
/// Wizard, CivicBook Observation Feed, and the Gemini 3.8 Flash Vision Classifier.
class CivicTaxonomy {
  static const Map<String, List<String>> categories = {
    'Solid Waste': [
      'Garbage Dump Overflow',
      'Uncollected Door-to-Door Waste',
      'Hazardous / Medical Waste Dumping',
      'Dead Animal Removal',
      'Plastic Waste in Stream/Canal',
    ],
    'Roads & Footpaths': [
      'Dangerous Pothole',
      'Damaged Pedestrian Footpath',
      'Missing Manhole Cover',
      'Road Cave-in / Landslide Debris',
      'Illegal Road Encroachment',
    ],
    'Drainage & Waterlogging': [
      'Blocked Stormwater Drain',
      'Monsoon Waterlogging',
      'Sewage Overflow on Street',
      'Broken Drain Slab',
    ],
    'Street Lighting': [
      'Streetlight Completely Off',
      'Flickering Light Pole',
      'Exposed Electrical Wiring',
      'Damaged Electric Pole',
    ],
    'Water Supply': [
      'Main Pipeline Leakage / Wastage',
      'Contaminated / Turbid Tap Water',
      'No Municipal Water Supply',
      'Low Pressure Supply',
    ],
    'Public Sanitation': [
      'Unsanitary Public Toilet',
      'Open Urination Hotspot',
      'Stagnant Dirty Water Puddle',
    ],
  };

  /// Official municipal operational departments available for single or
  /// multi-department co-assignment.
  static const List<String> allDepartments = [
    'Nagar Nigam (Sanitation & SWM)',
    'PWD / Road Engineering Wing',
    'Stormwater & Drainage Wing',
    'Electricity / Streetlight Wing',
    'Uttarakhand Jal Sansthan (Water)',
    'Public Health & Sanitation Cell',
    'Horticulture & Parks Wing',
    'Disaster & Encroachment Cell',
  ];

  static const Map<String, String> defaultDepartmentByCategory = {
    'Solid Waste': 'Nagar Nigam (Sanitation & SWM)',
    'Roads & Footpaths': 'PWD / Road Engineering Wing',
    'Drainage & Waterlogging': 'Stormwater & Drainage Wing',
    'Street Lighting': 'Electricity / Streetlight Wing',
    'Water Supply': 'Uttarakhand Jal Sansthan (Water)',
    'Public Sanitation': 'Public Health & Sanitation Cell',
  };

  static const Map<String, String> civicBookKeyByCategory = {
    'Solid Waste': 'waste',
    'Roads & Footpaths': 'roads',
    'Drainage & Waterlogging': 'water',
    'Water Supply': 'water',
    'Street Lighting': 'lights',
    'Public Sanitation': 'waste',
  };

  /// Strict enum normalizer ensuring AI predictions always map cleanly to an
  /// authoritative CivicFlow category.
  static String normalizeCategory(String? raw) {
    if (raw == null || raw.trim().isEmpty) return categories.keys.first;
    final clean = raw.trim().toLowerCase();

    for (final cat in categories.keys) {
      if (cat.toLowerCase() == clean) return cat;
    }

    if (clean.contains('waste') || clean.contains('garbage') || clean.contains('trash') || clean.contains('plastic') || clean.contains('litter')) {
      return 'Solid Waste';
    }
    if (clean.contains('road') || clean.contains('pothole') || clean.contains('footpath') || clean.contains('manhole') || clean.contains('encroach') || clean.contains('debris')) {
      return 'Roads & Footpaths';
    }
    if (clean.contains('drain') || clean.contains('waterlog') || clean.contains('sewage') || clean.contains('flood')) {
      return 'Drainage & Waterlogging';
    }
    if (clean.contains('light') || clean.contains('lamp') || clean.contains('pole') || clean.contains('wire') || clean.contains('electric')) {
      return 'Street Lighting';
    }
    if (clean.contains('water') || clean.contains('pipe') || clean.contains('tap') || clean.contains('leak')) {
      return 'Water Supply';
    }
    if (clean.contains('sanitation') || clean.contains('toilet') || clean.contains('stagnant') || clean.contains('puddle') || clean.contains('hygiene')) {
      return 'Public Sanitation';
    }

    return categories.keys.first;
  }

  /// Strict subcategory normalizer scoped to the resolved [category].
  static String normalizeSubcategory(String category, String? rawSub) {
    final validSubs = categories[category] ?? categories.values.first;
    if (rawSub == null || rawSub.trim().isEmpty) return validSubs.first;
    final clean = rawSub.trim().toLowerCase();

    for (final sub in validSubs) {
      if (sub.toLowerCase() == clean) return sub;
    }

    for (final sub in validSubs) {
      final subTokens = sub.toLowerCase().split(RegExp(r'[\s/]+'));
      final matches = subTokens.where((t) => t.length > 3 && clean.contains(t)).length;
      if (matches >= 1) return sub;
    }

    return validSubs.first;
  }

  /// Maps arbitrary department phrasing back to an official municipal department.
  static String normalizeDepartment(String? rawDept, {String? fallbackCategory}) {
    if (rawDept != null && rawDept.trim().isNotEmpty) {
      final clean = rawDept.trim().toLowerCase();
      for (final dept in allDepartments) {
        if (dept.toLowerCase() == clean) return dept;
      }
      if (clean.contains('nagar nigam') || clean.contains('solid waste') || clean.contains('swm') || clean.contains('garbage')) {
        return 'Nagar Nigam (Sanitation & SWM)';
      }
      if (clean.contains('pwd') || clean.contains('road') || clean.contains('engineering') || clean.contains('pothole')) {
        return 'PWD / Road Engineering Wing';
      }
      if (clean.contains('drain') || clean.contains('stormwater') || clean.contains('sewer') || clean.contains('sewage')) {
        return 'Stormwater & Drainage Wing';
      }
      if (clean.contains('electric') || clean.contains('upcl') || clean.contains('light') || clean.contains('power')) {
        return 'Electricity / Streetlight Wing';
      }
      if (clean.contains('jal') || clean.contains('water supply') || clean.contains('pipeline')) {
        return 'Uttarakhand Jal Sansthan (Water)';
      }
      if (clean.contains('health') || clean.contains('sanitation') || clean.contains('toilet')) {
        return 'Public Health & Sanitation Cell';
      }
      if (clean.contains('horticulture') || clean.contains('tree') || clean.contains('park') || clean.contains('greenery')) {
        return 'Horticulture & Parks Wing';
      }
      if (clean.contains('disaster') || clean.contains('encroach') || clean.contains('landslide')) {
        return 'Disaster & Encroachment Cell';
      }
    }

    return defaultDepartmentByCategory[fallbackCategory] ?? allDepartments.first;
  }

  /// Resolves a CivicFlow category to its closest CivicBook category chip key.
  static String toCivicBookKey(String civicFlowCategory) {
    return civicBookKeyByCategory[normalizeCategory(civicFlowCategory)] ?? 'general';
  }

  /// Maps a CivicBook category key ('waste', 'roads', 'water', 'lights', etc.) to a CivicFlow category.
  static String fromCivicBookKey(String key) {
    switch (key.trim().toLowerCase()) {
      case 'waste':
        return 'Solid Waste';
      case 'roads':
        return 'Roads & Footpaths';
      case 'water':
        return 'Water Supply';
      case 'lights':
        return 'Street Lighting';
      default:
        return 'Public Sanitation';
    }
  }
}
