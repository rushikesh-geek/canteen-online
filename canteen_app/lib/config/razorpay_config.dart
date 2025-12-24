/// Razorpay Configuration
/// Store API keys securely - never commit to public repositories
class RazorpayConfig {
  // ⚠️ PRODUCTION WARNING: Move to environment variables or Firebase Remote Config
  // For local development and testing only
  
  /// Razorpay Test Key ID
  /// Get from: https://dashboard.razorpay.com/app/keys
  static const String keyId = "rzp_test_ulDUM27OfZySEx";
  
  /// Company/Business name shown in payment UI
  static const String companyName = "Canteen Queue System";
  
  /// Company logo URL (optional)
  static const String? companyLogoUrl = null;
  
  /// Theme color for Razorpay checkout (hex format)
  static const String themeColor = "#FF9800"; // Orange to match app theme
  
  /// Currency code
  static const String currency = "INR";
  
  /// Payment description
  static const String paymentDescription = "Canteen Order Payment";
}
