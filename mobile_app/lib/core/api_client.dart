import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'
    show VoidCallback, debugPrint, kDebugMode;
import 'constants.dart';
import 'storage.dart';

class ApiClient {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConstants.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
  ));

  static bool _initialized = false;

  /// Called when a 401 is received — AuthNotifier sets this to force logout.
  static VoidCallback? onSessionExpired;

  static bool _handlingExpiry = false;

  static Dio get instance {
    if (!_initialized) {
      _init();
      _initialized = true;
    }
    return _dio;
  }

  /// Debug-only logging. Bodies, tokens and headers are deliberately not
  /// logged: in a release build these land in logcat, where any app holding
  /// READ_LOGS can read a user's bearer token straight out of them.
  static void _log(String Function() message) {
    if (kDebugMode) debugPrint('[api] ${message()}');
  }

  static void _init() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await StorageService.getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        _log(() => '--> ${options.method} ${options.uri} '
            '(${token != null ? 'authenticated' : 'anonymous'})');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        _log(() => '<-- ${response.statusCode} '
            '${response.requestOptions.method} ${response.requestOptions.uri}');
        return handler.next(response);
      },
      onError: (DioException err, handler) async {
        _log(() => '!!! ${err.response?.statusCode ?? err.type.name} '
            '${err.requestOptions.method} ${err.requestOptions.uri}');

        // On 401: try refresh token first, then clear session
        if (err.response?.statusCode == 401 && !_handlingExpiry) {
          final path = err.requestOptions.path;
          // Skip token refresh for auth endpoints (invalid OTP, bad credentials, etc.)
          final isAuthEndpoint = path.contains('/auth/');
          if (!isAuthEndpoint) {
            _handlingExpiry = true;
            // Try to refresh the token
            final refreshed = await _tryRefreshToken();
            if (refreshed) {
              // Retry the original request with the new token
              try {
                final token = await StorageService.getAccessToken();
                final opts = err.requestOptions;
                opts.headers['Authorization'] = 'Bearer $token';
                final retryResponse = await _dio.fetch(opts);
                _handlingExpiry = false;
                return handler.resolve(retryResponse);
              } catch (_) {
                // Retry failed — fall through to session expired
              }
            }
            await StorageService.clearAll();
            onSessionExpired?.call();
            await Future.delayed(const Duration(milliseconds: 100));
            _handlingExpiry = false;
          }
        }
        return handler.next(err);
      },
    ));
  }

  /// Attempt to refresh the access token using the stored refresh token.
  static Future<bool> _tryRefreshToken() async {
    try {
      final refreshToken = await StorageService.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) return false;
      final res = await Dio(BaseOptions(
        baseUrl: AppConstants.baseUrl,
        headers: {'Content-Type': 'application/json'},
      )).post('/auth/refresh-token', data: {'refresh_token': refreshToken});
      final data = res.data as Map<String, dynamic>;
      final inner = data['data'] as Map<String, dynamic>?;
      if (inner != null && inner['access_token'] != null) {
        await StorageService.saveTokens(
          accessToken: inner['access_token'],
          refreshToken: inner['refresh_token'] ?? refreshToken,
        );
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ── Auth ──────────────────────────────────────────────────────────────────
  // POST /auth/send-otp  { mobile }
  static Future<Map<String, dynamic>> sendOtp(String mobile) =>
      _post('/auth/send-otp', {'mobile': mobile});

  // POST /auth/verify-otp  { mobile, otp }
  // Returns: { success, message, data: { new_user, mobile } } or
  //          { success, message, data: { access_token, refresh_token, user } }
  static Future<Map<String, dynamic>> verifyOtp(String mobile, String otp,
          {String? deviceToken}) =>
      _post('/auth/verify-otp', {'mobile': mobile, 'otp': otp});

  // POST /auth/complete-registration  { name, mobile, email? }
  // Returns: { success, data: { access_token, refresh_token, user } }
  static Future<Map<String, dynamic>> completeRegistration(
          String name, String mobile,
          {String? email}) =>
      _post('/auth/complete-registration', {
        'name': name,
        'mobile': mobile,
        if (email != null && email.isNotEmpty) 'email': email,
      });

  // POST /auth/logout
  static Future<void> logout(String refreshToken) =>
      _post('/auth/logout', {'refresh_token': refreshToken});

  // POST /auth/refresh-token
  static Future<Map<String, dynamic>> refreshToken(String token) =>
      _post('/auth/refresh-token', {'refresh_token': token});

  // ── Sports (Categories) ──────────────────────────────────────────────────
  // GET /sports
  static Future<Map<String, dynamic>> getSports() async {
    final res = await instance.get('/sports');
    final raw = res.data as Map<String, dynamic>;
    return {'data': raw['data'] ?? []};
  }

  // ── Grounds ─────────────────────────────────────────────────────────────
  // GET /grounds  (public, filters: sport_id, lat, lng, radius_km, page, limit)
  static Future<Map<String, dynamic>> getGrounds({
    int? sportId,
    String? city,
    String? search,
    double? latitude,
    double? longitude,
    double? radiusKm,
    bool? hasRoof,
    int page = 1,
    int limit = 20,
  }) async {
    final res = await instance.get('/grounds', queryParameters: {
      if (sportId != null) 'sport_id': sportId,
      // `city` used to be accepted here and then silently dropped. The API
      // matches city inside its `search`, so route it there rather than
      // pretending a parameter exists.
      if (search != null && search.trim().isNotEmpty)
        'search': search.trim()
      else if (city != null && city.trim().isNotEmpty)
        'search': city.trim(),
      // Sends the pair only when both halves are real, so the API is never
      // asked to sort by half a coordinate.
      if (latitude != null && longitude != null) ...{
        'lat': latitude,
        'lng': longitude,
        if (radiusKm != null) 'radius_km': radiusKm,
      },
      if (hasRoof != null) 'has_roof': hasRoof,
      'page': page,
      'limit': limit,
    });
    final raw = res.data as Map<String, dynamic>;
    return {'data': raw['data'] ?? []};
  }

  // GET /grounds (popular — same endpoint, sorted by rating/bookings)
  static Future<Map<String, dynamic>> getPopularGrounds({int page = 1}) async {
    final res = await instance
        .get('/grounds', queryParameters: {'page': page, 'limit': 10});
    final raw = res.data as Map<String, dynamic>;
    return {'data': raw['data'] ?? []};
  }

  // GET /grounds?lat=&lng=&radius_km=
  static Future<Map<String, dynamic>> getNearbyGrounds({
    double? latitude,
    double? longitude,
  }) async {
    final res = await instance.get('/grounds', queryParameters: {
      if (latitude != null) 'lat': latitude,
      if (longitude != null) 'lng': longitude,
      'radius_km': 50,
    });
    final raw = res.data as Map<String, dynamic>;
    return {'data': raw['data'] ?? []};
  }

  // GET /grounds/:id
  static Future<Map<String, dynamic>> getGround(int id) async {
    final res = await instance.get('/grounds/$id');
    final raw = res.data as Map<String, dynamic>;
    return {'data': raw['data'] ?? raw};
  }

  // GET /grounds?sport_id=:id
  static Future<Map<String, dynamic>> getGroundsByCategory(
      int categoryId) async {
    final res = await instance
        .get('/grounds', queryParameters: {'sport_id': categoryId});
    final raw = res.data as Map<String, dynamic>;
    return {'data': raw['data'] ?? []};
  }

  // GET /grounds/:id/sports
  static Future<Map<String, dynamic>> getGroundSports(int groundId) async {
    final res = await instance.get('/grounds/$groundId/sports');
    final raw = res.data as Map<String, dynamic>;
    return {'data': raw['data'] ?? []};
  }

  // ── Amenities ────────────────────────────────────────────────────────────
  // GET /amenities
  static Future<Map<String, dynamic>> getAmenities() async {
    final res = await instance.get('/amenities');
    final raw = res.data as Map<String, dynamic>;
    return {'data': raw['data'] ?? []};
  }

  // ── Slots ─────────────────────────────────────────────────────────────────
  // GET /ground-sports/:groundSportId/slots?date=YYYY-MM-DD
  static Future<Map<String, dynamic>> getSlots(
      int groundSportId, String date) async {
    final res = await instance.get(
      '/ground-sports/$groundSportId/slots',
      queryParameters: {'date': date},
    );
    final raw = res.data as Map<String, dynamic>;
    return {'data': raw['data'] ?? []};
  }

  // ── Bookings ──────────────────────────────────────────────────────────────
  // GET /bookings (role-based: user sees own, owner sees their grounds')
  static Future<Map<String, dynamic>> getBookings() async {
    final res = await instance.get('/bookings');
    final raw = res.data as Map<String, dynamic>;
    return {'data': raw['data'] ?? []};
  }

  // GET /bookings (upcoming: filter client-side by status != completed/cancelled)
  static Future<Map<String, dynamic>> getUpcomingBookings() async {
    final res = await instance.get('/bookings');
    final raw = res.data as Map<String, dynamic>;
    final all = raw['data'] as List<dynamic>? ?? [];
    final upcoming = all.where((b) {
      final status = (b['status'] ?? '').toString().toLowerCase();
      return status == 'pending' || status == 'confirmed';
    }).toList();
    return {'data': upcoming};
  }

  // GET /bookings (completed: filter client-side)
  static Future<Map<String, dynamic>> getCompletedBookings() async {
    final res = await instance.get('/bookings');
    final raw = res.data as Map<String, dynamic>;
    final all = raw['data'] as List<dynamic>? ?? [];
    final completed = all.where((b) {
      final status = (b['status'] ?? '').toString().toLowerCase();
      return status == 'completed' || status == 'cancelled';
    }).toList();
    return {'data': completed};
  }

  // GET /bookings/:id
  static Future<Map<String, dynamic>> getBooking(int id) async {
    final res = await instance.get('/bookings/$id');
    final raw = res.data as Map<String, dynamic>;
    return {'data': raw['data'] ?? raw};
  }

  // POST /bookings
  // Body: { ground_sport_id, slot_date, slot_ids, is_game, payment_method }
  static Future<Map<String, dynamic>> createBooking({
    required int groundSportId,
    required String slotDate,
    required List<int> slotIds,
    String paymentMethod = 'pay_at_ground',
    bool isGame = false,
  }) =>
      _post('/bookings', {
        'ground_sport_id': groundSportId,
        'slot_date': slotDate,
        'slot_ids': slotIds,
        'payment_method': paymentMethod,
        'is_game': isGame,
      });

  // POST /payments/razorpay/create-order  { booking_id }
  static Future<Map<String, dynamic>> createRazorpayOrder(int bookingId) =>
      _post('/payments/razorpay/create-order', {'booking_id': bookingId});

  // POST /payments/razorpay/verify
  static Future<Map<String, dynamic>> verifyRazorpayPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) =>
      _post('/payments/razorpay/verify', {
        'razorpay_order_id': orderId,
        'razorpay_payment_id': paymentId,
        'razorpay_signature': signature,
      });

  // PATCH /bookings/:id/cancel  { cancellation_reason }
  static Future<Map<String, dynamic>> cancelBooking(
      int id, String reason) async {
    final res = await instance.patch('/bookings/$id/cancel', data: {
      'cancellation_reason': reason,
    });
    return res.data as Map<String, dynamic>;
  }

  // Cancel reasons — not available in playsher-api, return common defaults
  static Future<Map<String, dynamic>> getCancelReasons() async => {
        'data': [
          {'id': 1, 'reason': 'Change of plans'},
          {'id': 2, 'reason': 'Found a better option'},
          {'id': 3, 'reason': 'Weather conditions'},
          {'id': 4, 'reason': 'Personal emergency'},
          {'id': 5, 'reason': 'Other'},
        ]
      };

  // ── Coupons ────────────────────────────────────────────────────────────────
  // Not available in playsher-api — stubs
  static Future<Map<String, dynamic>> getAvailableCoupons() async =>
      {'data': []};

  static Future<Map<String, dynamic>> applyCoupon(
          int bookingId, int couponId) async =>
      {'success': false, 'message': 'Coupons not available yet'};

  // ── Reviews ───────────────────────────────────────────────────────────────
  // GET /reviews?ground_id=:groundId
  static Future<Map<String, dynamic>> getReviews({int? groundId}) async {
    if (groundId == null) return {'data': []};
    final res = await instance.get('/reviews', queryParameters: {
      'ground_id': groundId,
      'review_type': 'ground',
    });
    final raw = res.data as Map<String, dynamic>;
    return {'data': raw['data'] ?? []};
  }

  // GET /reviews/eligibility?ground_id=
  // Whether this customer may review the ground, and why not if they may not.
  static Future<Map<String, dynamic>> getReviewEligibility(int groundId) async {
    final res = await instance.get(
      '/reviews/eligibility',
      queryParameters: {'ground_id': groundId},
    );
    final raw = res.data as Map<String, dynamic>;
    return {'data': raw['data'] ?? {}};
  }

  // POST /reviews
  // bookingId is no longer sent: the API resolves the qualifying booking from
  // the ground itself, because trusting a client-supplied id is what allowed
  // the eligibility check to be skipped.
  static Future<Map<String, dynamic>> createReview({
    required int groundId,
    required int rating,
    required String comment,
  }) =>
      _post('/reviews', {
        'review_type': 'ground',
        'ground_id': groundId,
        'rating': rating,
        'comment': comment,
      });

  // ── Games ─────────────────────────────────────────────────────────────────
  // GET /games
  static Future<Map<String, dynamic>> getGames({int page = 1}) async {
    final res = await instance.get('/games', queryParameters: {'page': page});
    final raw = res.data as Map<String, dynamic>;
    return {'data': raw['data'] ?? [], 'pagination': raw['pagination'] ?? {}};
  }

  // GET /games/:id
  static Future<Map<String, dynamic>> getGame(int id) async {
    final res = await instance.get('/games/$id');
    final raw = res.data as Map<String, dynamic>;
    return {'data': raw['data'] ?? {}};
  }

  // POST /games
  static Future<Map<String, dynamic>> createGame(Map<String, dynamic> data) =>
      _post('/games', data);

  // POST /games/:id/join
  static Future<Map<String, dynamic>> joinGame(int id) =>
      _post('/games/$id/join', {});

  // DELETE /games/:id/leave
  static Future<Map<String, dynamic>> leaveGame(int id) async {
    final res = await instance.delete('/games/$id/leave');
    return res.data as Map<String, dynamic>;
  }

  // ── Location ──────────────────────────────────────────────────────────────
  // PATCH /auth/update-location  { latitude, longitude }
  static Future<void> updateLocation(double lat, double lng) async {
    await instance.patch('/auth/update-location', data: {
      'latitude': lat,
      'longitude': lng,
    });
  }

  // ── Favorites ─────────────────────────────────────────────────────────────
  // POST /favorites  { ground_id }
  static Future<void> addFavorite(int groundId) async {
    await instance.post('/favorites', data: {'ground_id': groundId});
  }

  // DELETE /favorites/:groundId
  static Future<void> removeFavorite(int groundId) async {
    await instance.delete('/favorites/$groundId');
  }

  // GET /favorites
  static Future<Map<String, dynamic>> getFavorites() async {
    final res = await instance.get('/favorites');
    final raw = res.data as Map<String, dynamic>;
    return {'data': raw['data'] ?? []};
  }

  // ── Profile ─────────────────────────────────────────────────────────────
  // GET /profile
  static Future<Map<String, dynamic>> getProfile() async {
    final res = await instance.get('/profile');
    final raw = res.data as Map<String, dynamic>;
    return raw;
  }

  // PUT /profile
  static Future<Map<String, dynamic>> updateProfile(
      Map<String, dynamic> data) async {
    final res = await instance.put('/profile', data: data);
    return res.data as Map<String, dynamic>;
  }

  // Profile completion check — derive from profile data
  static Future<Map<String, dynamic>> isProfileCompleted() async {
    try {
      final res = await instance.get('/profile');
      final raw = res.data as Map<String, dynamic>;
      final user = raw['data'] as Map<String, dynamic>?;
      final isComplete = user != null &&
          user['name'] != null &&
          user['name'] != 'User' &&
          user['mobile'] != null;
      return {'is_completed': isComplete, 'user': user};
    } catch (_) {
      return {'is_completed': false};
    }
  }

  // ── Bank Details ────────────────────────────────────────────────────────
  // POST /add-bank-details
  static Future<Map<String, dynamic>> addBankDetails(
          Map<String, dynamic> data) =>
      _post('/add-bank-details', data);

  // GET /bank-details
  static Future<Map<String, dynamic>> getBankDetails() async {
    final res = await instance.get('/bank-details');
    return res.data as Map<String, dynamic>;
  }

  // ── Coaches ─────────────────────────────────────────────────────────────
  // GET /coaches
  static Future<Map<String, dynamic>> getCoaches({
    int page = 1,
    String? sportName,
    int? sportId,
    String? city,
    String? search,
    int? groundId,
  }) async {
    final res = await instance.get('/coaches', queryParameters: {
      'page': page,
      if (sportName != null) 'sport_name': sportName,
      if (sportId != null) 'sport_id': sportId,
      if (city != null) 'city': city,
      if (search != null && search.isNotEmpty) 'search': search,
      if (groundId != null) 'ground_id': groundId,
    });
    final raw = res.data as Map<String, dynamic>;
    return {'data': raw['data'] ?? []};
  }

  // GET /coaches/:id
  static Future<Map<String, dynamic>> getCoach(int id) async {
    final res = await instance.get('/coaches/$id');
    final raw = res.data as Map<String, dynamic>;
    return {'data': raw['data'] ?? {}};
  }

  // GET /coaches/:id/slots?date=YYYY-MM-DD
  // Only blocks the coach is actually free for — the server drops booked,
  // blocked and already-passed ones.
  static Future<Map<String, dynamic>> getCoachSlots(int id, String date) async {
    final res = await instance
        .get('/coaches/$id/slots', queryParameters: {'date': date});
    final raw = res.data as Map<String, dynamic>;
    return {'data': raw['data'] ?? []};
  }

  // GET /coaches/:id/grounds — the venues whose owners approved this coach
  static Future<Map<String, dynamic>> getCoachGrounds(int id) async {
    final res = await instance.get('/coaches/$id/grounds');
    final raw = res.data as Map<String, dynamic>;
    return {'data': raw['data'] ?? []};
  }

  // ── Coaching sessions ───────────────────────────────────────────────────
  // POST /coach-bookings. The amount is computed by the server from the
  // coach's price — never send one.
  static Future<Map<String, dynamic>> createCoachBooking({
    required int coachId,
    required String sessionDate,
    required List<int> slotIds,
    int? groundId,
    String? customerNote,
  }) =>
      _post('/coach-bookings', {
        'coach_id': coachId,
        'session_date': sessionDate,
        'slot_ids': slotIds,
        if (groundId != null) 'ground_id': groundId,
        if (customerNote != null && customerNote.isNotEmpty)
          'customer_note': customerNote,
      });

  // GET /coach-bookings
  static Future<Map<String, dynamic>> getCoachBookings({String? status}) async {
    final res = await instance.get('/coach-bookings', queryParameters: {
      if (status != null) 'status': status,
    });
    final raw = res.data as Map<String, dynamic>;
    return {'data': raw['data'] ?? []};
  }

  // GET /coach-bookings/:id
  static Future<Map<String, dynamic>> getCoachBooking(int id) async {
    final res = await instance.get('/coach-bookings/$id');
    final raw = res.data as Map<String, dynamic>;
    return {'data': raw['data'] ?? {}};
  }

  // PATCH /coach-bookings/:id/cancel
  static Future<Map<String, dynamic>> cancelCoachBooking(int id,
      {String? reason}) async {
    final res = await instance.patch('/coach-bookings/$id/cancel', data: {
      if (reason != null && reason.isNotEmpty) 'cancellation_reason': reason,
    });
    return res.data as Map<String, dynamic>;
  }

  // ── Notifications ──────────────────────────────────────────────────────
  // GET /notifications
  static Future<Map<String, dynamic>> getNotifications() async {
    final res = await instance.get('/notifications');
    final raw = res.data as Map<String, dynamic>;
    return {'data': raw['data'] ?? []};
  }

  // GET /notifications/unread-count
  static Future<int> getUnreadNotificationCount() async {
    final res = await instance.get('/notifications/unread-count');
    final raw = res.data as Map<String, dynamic>;
    final data = raw['data'] as Map<String, dynamic>?;
    return data?['unread'] as int? ?? 0;
  }

  static Future<Map<String, dynamic>> markNotificationRead(int id) async {
    final res = await instance.patch('/notifications/$id/read');
    return res.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> markAllNotificationsRead() async {
    final res = await instance.patch('/notifications/read-all');
    return res.data as Map<String, dynamic>;
  }

  // ── Rewards ────────────────────────────────────────────────────────────
  // Not available in playsher-api — stubs
  static Future<Map<String, dynamic>> getAvailableCash(int points) async => {
        'data': {'cash': 0}
      };

  static Future<Map<String, dynamic>> getWithdrawHistory() async =>
      {'data': []};

  // ── Payments ────────────────────────────────────────────────────────────
  // POST /payments  { booking_id, payment_method, ... }
  static Future<Map<String, dynamic>> createPayment(
          Map<String, dynamic> data) =>
      _post('/payments', data);

  // GET /payments/:id
  static Future<Map<String, dynamic>> getPaymentDetails(int id) async {
    final res = await instance.get('/payments/$id');
    return res.data as Map<String, dynamic>;
  }

  // ── Dashboard ────────────────────────────────────────────────────────────
  // Not a separate endpoint — aggregate from other calls
  static Future<Map<String, dynamic>> getDashboard() async => {'data': {}};

  // ── Misc ──────────────────────────────────────────────────────────────────
  // Not available in playsher-api — stubs
  static Future<Map<String, dynamic>> getAvailableCities() async =>
      {'data': []};

  static Future<Map<String, dynamic>> getPriceFilters() async => {'data': []};

  // ── App version ───────────────────────────────────────────────────────────
  // GET /app-version?platform=&version=
  // Public — no token needed. Deliberately so: the check has to work before
  // login, and a build old enough to be blocked must be told even though its
  // stored token is already being rejected.
  static Future<Map<String, dynamic>> checkAppVersion({
    required String platform,
    required String version,
  }) async {
    final res = await instance.get(
      '/app-version',
      queryParameters: {'platform': platform, 'version': version},
    );
    final raw = res.data as Map<String, dynamic>;
    return {'data': raw['data'] ?? {}};
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> data) async {
    final res = await instance.post(path, data: data);
    return res.data as Map<String, dynamic>;
  }
}
