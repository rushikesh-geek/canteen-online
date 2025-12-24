import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:canteen_app/config/razorpay_config.dart';

/// Service for handling Razorpay payment integration
/// 
/// PLATFORM SUPPORT:
/// - Android: Full support with Razorpay UI
/// - iOS: Full support (not tested in this project)
/// - Web: NOT SUPPORTED - displays platform error
/// 
/// SECURITY:
/// - Never expose Razorpay secret key
/// - Validate amounts server-side in production
/// - Use webhook verification for production
class RazorpayService {
  late Razorpay _razorpay;
  bool _isInitialized = false;
  
  // Callbacks for payment events
  Function(String paymentId)? _onSuccess;
  Function(String error)? _onFailure;

  /// Initialize Razorpay instance
  /// Must be called before starting payment
  /// 
  /// Throws exception on Web platform
  void initialize({
    required Function(String paymentId) onSuccess,
    required Function(String error) onFailure,
  }) {
    // Platform check - Razorpay doesn't work on Web
    if (kIsWeb) {
      throw UnsupportedError(
        'Razorpay is not supported on Web platform. Please use the Android app for payments.',
      );
    }

    // Additional safety check for non-Android platforms
    if (!kIsWeb && !Platform.isAndroid) {
      throw UnsupportedError(
        'Razorpay is only supported on Android in this app configuration.',
      );
    }

    _onSuccess = onSuccess;
    _onFailure = onFailure;

    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    _isInitialized = true;
  }

  /// Start payment flow
  /// 
  /// Parameters:
  /// - [amountInRupees]: Payment amount in INR (will be converted to paise)
  /// - [orderId]: Firestore order document ID
  /// - [userEmail]: User's email for prefill
  /// - [userPhone]: User's phone number for prefill
  /// 
  /// Throws:
  /// - [StateError] if not initialized
  /// - [UnsupportedError] if called on Web
  void startPayment({
    required double amountInRupees,
    required String orderId,
    required String userEmail,
    required String userPhone,
  }) {
    if (!_isInitialized) {
      throw StateError('RazorpayService not initialized. Call initialize() first.');
    }

    if (kIsWeb) {
      throw UnsupportedError('Payment not available on Web. Use Android app.');
    }

    // Convert rupees to paise (Razorpay requires amount in smallest currency unit)
    final int amountInPaise = (amountInRupees * 100).round();

    // ⚠️ CRITICAL: options Map must contain ONLY JSON-serializable values
    // NO functions, NO closures, NO callbacks, NO objects
    final options = <String, dynamic>{
      'key': RazorpayConfig.keyId,
      'amount': amountInPaise, // Amount in paise (int)
      'currency': RazorpayConfig.currency,
      'name': RazorpayConfig.companyName,
      'description': '${RazorpayConfig.paymentDescription} - Order #${orderId.substring(orderId.length - 6).toUpperCase()}',
      'prefill': <String, String>{
        'email': userEmail,
        'contact': userPhone.isEmpty ? '0000000000' : userPhone,
      },
      'notes': <String, String>{
        'order_id': orderId,
        'platform': 'android',
      },
      'theme': <String, String>{
        'color': RazorpayConfig.themeColor,
      },
    };

    // Add logo if configured
    if (RazorpayConfig.companyLogoUrl != null && RazorpayConfig.companyLogoUrl!.isNotEmpty) {
      options['image'] = RazorpayConfig.companyLogoUrl!;
    }

    // Debug: Log options to verify JSON-serializable
    print('═══════════════════════════════════════════════════════');
    print('🔧 RAZORPAY OPTIONS (must be JSON-serializable):');
    print('═══════════════════════════════════════════════════════');
    print('Amount: ${options['amount']} paise (₹$amountInRupees)');
    print('Currency: ${options['currency']}');
    print('Email: ${options['prefill']?['email']}');
    print('Contact: ${options['prefill']?['contact']}');
    print('Order ID (notes): ${options['notes']?['order_id']}');
    print('═══════════════════════════════════════════════════════');

    try {
      print('🚀 Calling Razorpay.open()...');
      _razorpay.open(options);
      print('✅ Razorpay.open() called successfully');
    } catch (e, stackTrace) {
      print('❌ CRITICAL ERROR: Razorpay.open() failed!');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      _onFailure?.call('Failed to open payment: ${e.toString()}');
    }
  }

  /// Handle successful payment
  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    // Extract payment details
    final paymentId = response.paymentId;
    final orderId = response.orderId;
    final signature = response.signature;
    
    // Log complete payment details
    print('═══════════════════════════════════════════════════════');
    print('✅ RAZORPAY PAYMENT SUCCESS');
    print('═══════════════════════════════════════════════════════');
    print('Payment ID: $paymentId');
    print('Order ID: $orderId');
    print('Signature: $signature');
    print('═══════════════════════════════════════════════════════');
    
    if (paymentId != null) {
      _onSuccess?.call(paymentId);
    } else {
      print('❌ ERROR: Payment succeeded but no payment ID received!');
      _onFailure?.call('Payment succeeded but no payment ID received');
    }
  }

  /// Handle payment errors
  void _handlePaymentError(PaymentFailureResponse response) {
    final errorCode = response.code;
    final errorMessage = response.message ?? 'Unknown payment error';
    
    // Log complete error details
    print('═══════════════════════════════════════════════════════');
    print('❌ RAZORPAY PAYMENT ERROR');
    print('═══════════════════════════════════════════════════════');
    print('Error Code: $errorCode');
    print('Error Message: $errorMessage');
    print('═══════════════════════════════════════════════════════');
    
    // Format user-friendly error message
    String friendlyMessage;
    switch (errorCode) {
      case Razorpay.PAYMENT_CANCELLED:
        friendlyMessage = 'Payment cancelled';
        break;
      case Razorpay.NETWORK_ERROR:
        friendlyMessage = 'Network error. Please check your internet connection';
        break;
      case Razorpay.INVALID_OPTIONS:
        friendlyMessage = 'Payment configuration error. Please contact support';
        break;
      case Razorpay.TLS_ERROR:
        friendlyMessage = 'Security error. Please update your device';
        break;
      default:
        friendlyMessage = 'Payment failed: $errorMessage';
    }
    
    _onFailure?.call(friendlyMessage);
  }

  /// Handle external wallet selection
  void _handleExternalWallet(ExternalWalletResponse response) {
    final walletName = response.walletName ?? 'external wallet';
    _onFailure?.call('Payment via $walletName is not supported. Please use card/UPI/netbanking.');
  }

  /// Dispose Razorpay instance
  /// Must be called in widget's dispose() method
  void dispose() {
    if (_isInitialized) {
      _razorpay.clear();
      _isInitialized = false;
    }
  }

  /// Check if platform supports Razorpay
  static bool isPlatformSupported() {
    return !kIsWeb && Platform.isAndroid;
  }
}
