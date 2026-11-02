import 'api_client.dart';

/// One server-issued CAPTCHA challenge. The answer stays on the server; the
/// app receives only the question and a single-use id.
class CaptchaChallenge {
  final String id;
  final String question;

  const CaptchaChallenge({required this.id, required this.question});

  static CaptchaChallenge fromJson(Object? value) {
    if (value is! Map) {
      throw ApiException(
          0, 'The CAPTCHA service returned an invalid response.');
    }

    final id = value['id'];
    final question = value['question'];

    if (id is! String || question is! String) {
      throw ApiException(
          0, 'The CAPTCHA service returned an invalid response.');
    }

    return CaptchaChallenge(id: id, question: question);
  }
}

class RecaptchaConfig {
  final bool enabled;
  final String siteKey;

  const RecaptchaConfig({required this.enabled, required this.siteKey});

  static RecaptchaConfig fromJson(Object? value) {
    if (value is! Map) {
      return const RecaptchaConfig(enabled: false, siteKey: '');
    }

    final siteKey = value['siteKey'];
    return RecaptchaConfig(
      enabled:
          value['enabled'] == true && siteKey is String && siteKey.isNotEmpty,
      siteKey: siteKey is String ? siteKey : '',
    );
  }
}

class LoginChallenge {
  final String challengeId;
  final String maskedEmail;
  final int expiresIn;
  final int resendIn;

  const LoginChallenge({
    required this.challengeId,
    required this.maskedEmail,
    required this.expiresIn,
    required this.resendIn,
  });

  static LoginChallenge fromJson(Object? value) {
    if (value is! Map) {
      throw ApiException(0, 'The server returned an invalid log-in response.');
    }
    final id = value['challengeId'];
    if (id is! String || id.isEmpty) {
      throw ApiException(0, 'The server returned an invalid log-in response.');
    }
    final masked = value['maskedEmail'];
    return LoginChallenge(
      challengeId: id,
      maskedEmail:
          masked is String && masked.isNotEmpty ? masked : 'your email',
      expiresIn: (value['expiresIn'] as num?)?.toInt() ?? 300,
      resendIn: (value['resendIn'] as num?)?.toInt() ?? 60,
    );
  }
}

/// Username + password authentication with a 6-digit email code as the
/// second factor. The session is created only after the code is accepted.
class AuthService {
  final ApiClient api;

  AuthService(this.api);

  Future<RecaptchaConfig> fetchRecaptchaConfig() async {
    final result = await api.request(
      'GET',
      '/api/auth/recaptcha',
      auth: false,
    );

    return RecaptchaConfig.fromJson(result);
  }

  Future<CaptchaChallenge> fetchCaptcha() async {
    final result = await api.request(
      'GET',
      '/api/auth/captcha',
      auth: false,
    );

    return CaptchaChallenge.fromJson(result);
  }

  Future<LoginChallenge> signIn({
    required String username,
    required String password,
    String? captchaId,
    String? captchaAnswer,
    String? recaptchaToken,
  }) async {
    final result = await api.request(
      'POST',
      '/api/auth/login',
      auth: false,
      body: {
        'username': username.trim(),
        'password': password,
        if (captchaId != null) 'captchaId': captchaId,
        if (captchaAnswer != null) 'captchaAnswer': captchaAnswer,
        if (recaptchaToken != null) 'recaptchaToken': recaptchaToken,
      },
    );

    return LoginChallenge.fromJson(result);
  }

  Future<Map<String, dynamic>> verifyLoginOtp({
    required String challengeId,
    required String code,
    bool rememberMe = false,
  }) async {
    final result = await api.request(
      'POST',
      '/api/auth/login/verify-otp',
      auth: false,
      body: {
        'challengeId': challengeId,
        'code': code.trim(),
        'rememberMe': rememberMe,
      },
    );

    return _storeSession(result);
  }

  Future<LoginChallenge> resendLoginOtp(String challengeId) async {
    final result = await api.request(
      'POST',
      '/api/auth/login/resend-otp',
      auth: false,
      body: {'challengeId': challengeId},
    );

    return LoginChallenge.fromJson(result);
  }

  Future<bool> usernameAvailable(String username) async {
    final result = await api.request(
      'GET',
      '/api/auth/username-available?username=${Uri.encodeQueryComponent(username.trim())}',
      auth: false,
    );

    return result is Map && result['available'] == true;
  }

  Future<Map<String, dynamic>> signUp({
    required String displayName,
    required String email,
    required String username,
    required String password,
    required bool privacyConsent,
    String? captchaId,
    String? captchaAnswer,
    String? recaptchaToken,
    bool rememberMe = false,
  }) async {
    final result = await api.request(
      'POST',
      '/api/auth/register',
      auth: false,
      body: {
        'displayName': displayName.trim(),
        'email': email.trim(),
        'username': username.trim(),
        'password': password,
        'privacyConsent': privacyConsent,
        if (captchaId != null) 'captchaId': captchaId,
        if (captchaAnswer != null) 'captchaAnswer': captchaAnswer,
        if (recaptchaToken != null) 'recaptchaToken': recaptchaToken,
        'rememberMe': rememberMe,
      },
    );

    return _storeSession(result);
  }

  Future<LoginChallenge> registerAccount(Map<String, dynamic> payload) async {
    final result = await api.request(
      'POST',
      '/api/auth/register',
      auth: false,
      body: payload,
    );
    return LoginChallenge.fromJson(result);
  }

  Future<Map<String, dynamic>> verifyRegistrationOtp({
    required String challengeId,
    required String code,
    bool rememberMe = false,
  }) async {
    final result = await api.request(
      'POST',
      '/api/auth/register/verify-otp',
      auth: false,
      body: {
        'challengeId': challengeId,
        'code': code.trim(),
        'rememberMe': rememberMe,
      },
    );
    return _storeSession(result);
  }

  Future<LoginChallenge> resendRegistrationOtp(String challengeId) async {
    final result = await api.request(
      'POST',
      '/api/auth/register/resend-otp',
      auth: false,
      body: {'challengeId': challengeId},
    );
    return LoginChallenge.fromJson(result);
  }

  Future<List<Map<String, String>>> forgotQuestions(
    String username, {
    String? captchaId,
    String? captchaAnswer,
    String? recaptchaToken,
  }) async {
    final result = await api.request(
      'POST',
      '/api/auth/forgot-password',
      auth: false,
      body: {
        'username': username.trim(),
        if (captchaId != null) 'captchaId': captchaId,
        if (captchaAnswer != null) 'captchaAnswer': captchaAnswer,
        if (recaptchaToken != null) 'recaptchaToken': recaptchaToken,
      },
    );
    if (result is! Map || result['questions'] is! List) {
      throw ApiException(0, 'The server returned an invalid response.');
    }
    return (result['questions'] as List)
        .whereType<Map>()
        .map((item) => {
              'key': '${item['key']}',
              'text': '${item['text']}',
            })
        .toList();
  }

  Future<LoginChallenge> forgotAnswer({
    required String username,
    required String question,
    required String answer,
    required String reanswer,
  }) async {
    final result = await api.request(
      'POST',
      '/api/auth/forgot-password/answer',
      auth: false,
      body: {
        'username': username.trim(),
        'question': question,
        'answer': answer.trim(),
        'reanswer': reanswer.trim(),
      },
    );
    return LoginChallenge.fromJson(result);
  }

  Future<String> verifyResetOtp({
    required String challengeId,
    required String code,
  }) async {
    final result = await api.request(
      'POST',
      '/api/auth/forgot-password/verify-otp',
      auth: false,
      body: {'challengeId': challengeId, 'code': code.trim()},
    );
    if (result is! Map || result['resetToken'] is! String) {
      throw ApiException(0, 'The server returned an invalid response.');
    }
    return result['resetToken'] as String;
  }

  Future<LoginChallenge> resendResetOtp(String challengeId) async {
    final result = await api.request(
      'POST',
      '/api/auth/forgot-password/resend-otp',
      auth: false,
      body: {'challengeId': challengeId},
    );
    return LoginChallenge.fromJson(result);
  }

  Future<void> requestPasswordReset(String email) async {
    await api.request(
      'POST',
      '/api/auth/forgot-password',
      auth: false,
      body: {'email': email.trim()},
    );
  }

  Future<void> resetPassword({
    required String code,
    required String password,
  }) async {
    await api.request(
      'POST',
      '/api/auth/reset-password',
      auth: false,
      body: {'token': code.trim(), 'password': password},
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await api.request(
      'POST',
      '/api/auth/password',
      body: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
  }

  Future<void> signOut() async {
    try {
      if (api.token != null && api.token!.isNotEmpty) {
        api.suppressUnauthorized = true;
        await api.request(
          'POST',
          '/api/auth/logout-all',
          auth: true,
          body: const <String, dynamic>{},
        );
      }
    } catch (_) {
      // Local sign-out must still work offline.
    } finally {
      api.suppressUnauthorized = false;
      api.token = null;
    }
  }

  Map<String, dynamic> _storeSession(dynamic result) {
    if (result is! Map ||
        result['accessToken'] is! String ||
        (result['accessToken'] as String).isEmpty) {
      throw ApiException(
        0,
        'The server returned an incomplete sign-in response. Please try again.',
      );
    }

    api.token = result['accessToken'] as String;
    return Map<String, dynamic>.from(result);
  }
}
