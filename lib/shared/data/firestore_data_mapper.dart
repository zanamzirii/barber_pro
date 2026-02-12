class FirestoreDataMapper {
  static String stringValue(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = data[key];
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) return trimmed;
      }
    }
    return fallback;
  }

  static bool boolValue(
    Map<String, dynamic> data,
    List<String> keys, {
    bool fallback = false,
  }) {
    for (final key in keys) {
      final value = data[key];
      if (value is bool) return value;
    }
    return fallback;
  }

  static String branchName(
    Map<String, dynamic> data, {
    String fallback = 'Branch',
  }) {
    return stringValue(data, const [
      'name',
      'branchName',
      'displayName',
      'title',
    ], fallback: fallback);
  }

  static String branchAddress(
    Map<String, dynamic> data, {
    String fallback = 'Address unavailable',
  }) {
    return stringValue(data, const [
      'address',
      'location',
      'fullAddress',
      'branchAddress',
    ], fallback: fallback);
  }

  static String userFullName(
    Map<String, dynamic> data, {
    String fallback = 'User',
  }) {
    return stringValue(data, const [
      'fullName',
      'name',
      'displayName',
    ], fallback: fallback);
  }

  static String userAvatar(Map<String, dynamic> data, {String fallback = ''}) {
    return stringValue(data, const [
      'photoUrl',
      'avatarUrl',
      'imageUrl',
      'profileImageUrl',
    ], fallback: fallback);
  }

  static String barberFullName(
    Map<String, dynamic> data, {
    String fallback = 'Barber',
  }) {
    return stringValue(data, const [
      'barberFullName',
      'fullName',
      'barberName',
      'name',
      'displayName',
    ], fallback: fallback);
  }

  static String customerFullName(
    Map<String, dynamic> data, {
    String fallback = 'Customer',
  }) {
    return stringValue(data, const [
      'customerFullName',
      'fullName',
      'customerName',
      'name',
      'displayName',
    ], fallback: fallback);
  }

  static String serviceName(
    Map<String, dynamic> data, {
    String fallback = 'Service',
  }) {
    return stringValue(data, const [
      'serviceName',
      'name',
      'serviceTitle',
    ], fallback: fallback);
  }
}
