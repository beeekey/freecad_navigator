class MetadataField {
  MetadataField({
    required this.key,
    this.builtinValue,
    this.sidecarValue,
  });

  final String key;
  final String? builtinValue;
  final String? sidecarValue;

  bool get hasSidecar => sidecarValue != null && sidecarValue!.trim().isNotEmpty;

  String get effectiveValue {
    if (hasSidecar) {
      return sidecarValue!.trim();
    }
    return builtinValue?.trim() ?? '';
  }

  MetadataField copyWith({
    String? builtinValue,
    String? sidecarValue,
  }) {
    return MetadataField(
      key: key,
      builtinValue: builtinValue ?? this.builtinValue,
      sidecarValue: sidecarValue ?? this.sidecarValue,
    );
  }
}
