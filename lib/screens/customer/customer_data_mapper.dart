class CustomerDataMapper {
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
    String fallback = 'Selected Branch',
  }) {
    return stringValue(
      data,
      const ['name', 'branchName', 'displayName', 'title'],
      fallback: fallback,
    );
  }

  static String branchAddress(
    Map<String, dynamic> data, {
    String fallback = 'Address unavailable',
  }) {
    return stringValue(
      data,
      const ['address', 'location', 'fullAddress', 'branchAddress'],
      fallback: fallback,
    );
  }

  static String branchImage(
    Map<String, dynamic> data, {
    required String seed,
  }) {
    final fromData = stringValue(
      data,
      const [
        'imageUrl',
        'coverImageUrl',
        'heroImageUrl',
        'photoUrl',
        'branchImageUrl',
      ],
    );
    if (fromData.isNotEmpty) return fromData;
    return _fallbackBranchImages[seed.hashCode.abs() % _fallbackBranchImages.length];
  }

  static String barberFullName(
    Map<String, dynamic> data, {
    String fallback = 'Barber',
  }) {
    return stringValue(
      data,
      const ['fullName', 'name', 'displayName'],
      fallback: fallback,
    );
  }

  static String barberImage(
    Map<String, dynamic> data, {
    int fallbackIndex = 0,
  }) {
    final fromData = stringValue(
      data,
      const ['imageUrl', 'photoUrl', 'avatarUrl', 'profileImageUrl'],
    );
    if (fromData.isNotEmpty) return fromData;
    return _fallbackBarberImages[fallbackIndex % _fallbackBarberImages.length];
  }

  static String userFullName(
    Map<String, dynamic> data, {
    String fallback = 'Customer',
  }) {
    return stringValue(
      data,
      const ['fullName', 'name', 'displayName'],
      fallback: fallback,
    );
  }

  static String userAvatar(
    Map<String, dynamic> data, {
    String fallback = '',
  }) {
    return stringValue(
      data,
      const ['photoUrl', 'avatarUrl', 'imageUrl', 'profileImageUrl'],
      fallback: fallback,
    );
  }
}

const List<String> _fallbackBranchImages = <String>[
  'https://lh3.googleusercontent.com/aida-public/AB6AXuB-M4ztj-yfON358Y_Wgm-t5FJN8S1ejuEztls7XEJiRxhCRxrCRzl9sPO0iuxKvwRxS7m_hbXHl3tCMtFGgwHSCmtwkUdis0aqYmfVATvfUleUNktwNoriQrwg-GQ5WUb2-6wDmgVsmih6zkLAuoZrgd2VuLhIQpIM3FsrWFsj24pZyqJ1ZJj5_-r2hjt2nL1D12eWMsVvTxfusQmZxjn9m9GZhjtk_aiQheKGUr32X2LFL5I-i_dPmCBZEnfB9QbB2ll5SU1d-ZFZ',
  'https://lh3.googleusercontent.com/aida-public/AB6AXuC93VqXz0K_jZB6XI5L17LIdxkxT9Q7ey-VpWAg-RUS97NlDikogUbdSSusodZtl7XBAwrdU4Tawa7LZX-pX55rjsvHXnDQk2ZWELilR02DEZDzHrUIs-d_jyM1zpWdjxOhTn-jHWoOwuq7M9h684GMFdXhi6tVxnSQKISmE3yEdizXioiYj9BWsGUUafd3lHnpQHvm9Z0XiEcInZnGyQVuyN2rJXGe0JJ9e49KBk_qyr-nmJUoxvW_1P5ljH4k4hddSXRcS-2UNnbB',
  'https://lh3.googleusercontent.com/aida-public/AB6AXuCPBHocVxQq9_KmkValmCCul5FopuvoIpCWyCd4kFCbcsvsKIqe8NVeP4GUNIDpJDYPdQE65XlMha-NL57N8CtryizAnAeZJLQZ3pzVTNg4Ocg1rc750DTKju6FL_zUHpzSITDm42MWbplH7yCy-4w8T2spP7Yxla5KhReI4RyzpW1Cv4En-4VPwEC5fTeuNGsfE5uLCo_bAmvkN_d8ZsAN5yycV7IvAzHNAgD6lO4nI188d6FdAKQqJrWoloekzUAP6vnxm6vstEyz',
];

const List<String> _fallbackBarberImages = <String>[
  'https://lh3.googleusercontent.com/aida-public/AB6AXuAt5G2lPsMgR-Z7u41NWnEOeUZlt07-OHD3JUCrc3_csw3e0Bd4q6DgzHA2qL3DHDToB6i19QIhlzDWBQ7N0u8_3GcNt2mhjafspJqel6ogUxTefbVu6zfyQzLGIMWfispKwbS2ZekKbbRa1xgZSymjryti5TlQki3OtKwJq2yWesHo9psb5A6sulTY8_pEua86GpgEk74dmxYo3m0ssUYsSXQacG9uvDdbZ-1-kDZ7JvClgd9kJxj-AqalpoMIAXVOZSbOU8AtwISz',
  'https://lh3.googleusercontent.com/aida-public/AB6AXuAkjLicRR6tmVHPOr_OyfYMa9AKfSEcyeb7b-rDc-MVjUfPLoeOOy5HX2hJkgAh1iuiXuTqgTdOan6Gy20Oa-N0tK60gXiLfRYS0WRP3ABjugOBwG58xFZn7EHJY4ocTjtNmKwlREFnEn2lL9Ma1XghMLE6-WuEh36f2e1_4yWsJnvIvOrIzHaj37IreT2nFsomUJpToUVNQYZh9EwqT0zW1NMQoex-H6vRJ_MUyeQKlXH4sdKcS4vLWjP3r-KxjyOmUBgkzn6P_bZX',
  'https://lh3.googleusercontent.com/aida-public/AB6AXuAFtA2mqeeyMzt90m4XnLjQRsw9mRWg-LcdFqTGiPIqQgE59qD6mvTxRH_D2ZA7OhesvnV8sT73ZqMOeXMQ9HRAp-MnfhpFGNo4es64VcEdvAqlYKCl_Xgn5NrJkqvl7FP9D6CTfJo_YwugUyz22K4tqSFn8Dfh5JD5F5vpYinFxRAg17QKhnVfB0W9-Bp8z_wByLYxtbmlE3_EPDeiHiaZNdS1W619ShelwHKPlXqF7eYl1GKuSKSlJrAZjBezailfNS9bUMp_HUgX',
  'https://lh3.googleusercontent.com/aida-public/AB6AXuCqPKuBXTzAi1rj16s9qvPRQNbKd9Yap1CSjAVvnOG1dTAZdLukFkRJdPRIWA-JkjTCrH762-zFFyhOoudbNOEDmVlaGt9PCvhsVRLXrNr1wmraLKb3cobS0B8NR89cUIL38aIk9zVIRg8Wk1l9T3comVzy_pCqV7-cpjX6mzkdkdbEziL11j4F4NUguJ5yQprdhgnEtK1m6YZdCCLftITNhrRrp-sST2adqExojU5E6peezgPTIObUq4b0QKkAFc2g3-4DVKUxbLx2',
  'https://lh3.googleusercontent.com/aida-public/AB6AXuA-TLgDn8an9f9BRptlRkzstm13ESMtYBop3Jv6BIzP4h3p9cHiLr4_LFMtJIiWwh4LM_dqEYtwz7L0zUj590KrgD57cDi12Xn5cnOWUx41IZXjydpVK39wYPKdeRJhvrQA6tvI-Fo0fv8I-6CIFbe3IMDJY1_1SD3FABCKvR2k8K9ThH3YhXCnghfZizXqa0fptAQJI4fedxixu-SmU7Jf93F0NEJYIX4IkeoCtpFTfDOLDAFbkJRD4H5s19eM9gNq_U4FGijwh7Jv',
];
