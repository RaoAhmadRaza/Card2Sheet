/// Centralized schema and normalization for business card fields.
///
/// Fixed 7-field schema (internal keys):
/// - name
/// - designation
/// - company
/// - email
/// - phone
/// - address
/// - website
///
/// Export (display) headers for the 7 fields, in order:
/// - Name, Designation, Company, Email, Phone Number, Address, Website
///
/// Optional 8th column for notes:
/// - personal_thoughts (display: Personal Thoughts)

const List<String> kStrictKeys = [
  'name',
  'designation',
  'company',
  'email',
  'phone',
  'address',
  'website',
];

const List<String> kStrictHeaderLabels = [
  'Name',
  'Designation',
  'Company',
  'Email',
  'Phone Number',
  'Address',
  'Website',
];

const String kNotesKey = 'personal_thoughts';
const String kNotesHeaderLabel = 'Personal Thoughts';

/// Map display header labels to internal keys
String headerLabelToKey(String header) {
  final h = header.trim().toLowerCase();
  switch (h) {
    case 'name':
      return 'name';
    case 'designation':
    case 'title':
    case 'role':
    case 'position':
    case 'job title':
    case 'job_title':
      return 'designation';
    case 'company':
    case 'organisation':
    case 'organization':
    case 'org':
      return 'company';
    case 'email':
    case 'email address':
    case 'email_address':
    case 'mail':
      return 'email';
    case 'phone':
    case 'phone number':
    case 'phone_number':
    case 'mobile':
    case 'telephone':
    case 'cell':
      return 'phone';
    case 'address':
    case 'addr':
    case 'location':
      return 'address';
    case 'website':
    case 'url':
    case 'site':
      return 'website';
    case 'personal thoughts':
    case 'personal_thoughts':
    case 'notes':
      return kNotesKey;
    default:
      // try to normalize unknowns to snake_case key
      return h.replaceAll(RegExp(r"[^a-z0-9]+"), '_');
  }
}

/// Map internal keys to export/display header labels
String keyToHeaderLabel(String key) {
  final k = key.trim().toLowerCase();
  switch (k) {
    case 'name':
      return 'Name';
    case 'designation':
      return 'Designation';
    case 'company':
      return 'Company';
    case 'email':
      return 'Email';
    case 'phone':
      return 'Phone Number';
    case 'address':
      return 'Address';
    case 'website':
      return 'Website';
    case kNotesKey:
      return kNotesHeaderLabel;
    default:
      // best-effort prettify
      return k
          .split('_')
          .where((s) => s.isNotEmpty)
          .map((w) => w[0].toUpperCase() + w.substring(1))
          .join(' ');
  }
}

/// Normalize any incoming map (from AI or fallback) to the strict schema.
/// - Keys are normalized and synonyms are mapped.
/// - Only the 7 strict keys are guaranteed; extras are kept unless [keepExtras] is false.
/// - Missing strict fields are filled with 'NONE' (schema contract).
Map<String, String> normalizeToStrictSchema(
  Map<String, dynamic> input, {
  bool keepExtras = true,
}) {
  final out = <String, String>{};
  // First pass: collect any values mapped to normalized keys
  input.forEach((rawKey, rawVal) {
    final v = rawVal?.toString() ?? '';
    final normKey = headerLabelToKey(rawKey);
    // Preserve personal thoughts and extras optionally
    if (normKey == kNotesKey) {
      out[kNotesKey] = v;
    } else if (kStrictKeys.contains(normKey)) {
      out[normKey] = v;
    } else if (keepExtras) {
      out[normKey] = v;
    }
  });

  // Ensure all strict keys exist; fill missing with 'NONE'
  for (final key in kStrictKeys) {
    if (!out.containsKey(key) || (out[key]?.trim().isEmpty ?? true)) {
      out[key] = 'NONE';
    }
  }

  return out;
}

/// Build the default export header labels list (7 fixed + optional notes)
List<String> defaultExportHeaders({bool includeNotes = false}) {
  final headers = List<String>.from(kStrictHeaderLabels);
  if (includeNotes) headers.add(kNotesHeaderLabel);
  return headers;
}

/// Build a values list matching [headerLabels] order from a normalized map.
/// Any missing values are returned as 'NONE'.
List<String> valuesForHeaders(List<String> headerLabels, Map<String, String> normalized) {
  return headerLabels.map((label) {
    final key = headerLabelToKey(label);
    if (key == kNotesKey) return normalized[kNotesKey] ?? '';
    return normalized[key] ?? 'NONE';
  }).toList();
}
