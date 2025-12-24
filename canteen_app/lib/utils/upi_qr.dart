/// UPI QR Code Generator
/// 
/// Generates UPI payment URIs for QR code display on Web platform
/// Follows UPI Deep Linking specification
/// 
/// Supported UPI Apps: Google Pay, PhonePe, Paytm, BHIM, etc.
class UpiQrGenerator {
  /// Generate UPI payment URI
  /// 
  /// Parameters:
  /// - [upiId]: Merchant UPI ID (e.g., "canteen@upi")
  /// - [name]: Merchant name to display
  /// - [amount]: Payment amount in rupees
  /// - [transactionNote]: Transaction reference/note
  /// 
  /// Returns: UPI deep link string for QR code generation
  /// 
  /// Format: upi://pay?pa=UPI_ID&pn=NAME&am=AMOUNT&cu=INR&tn=NOTE
  static String generateUpiUri({
    required String upiId,
    required String name,
    required double amount,
    required String transactionNote,
  }) {
    // Validate inputs
    if (upiId.isEmpty) {
      throw ArgumentError('UPI ID cannot be empty');
    }
    if (amount <= 0) {
      throw ArgumentError('Amount must be greater than 0');
    }

    // Encode parameters for URI
    final encodedName = Uri.encodeComponent(name);
    final encodedNote = Uri.encodeComponent(transactionNote);
    final formattedAmount = amount.toStringAsFixed(2);

    // Build UPI URI according to specification
    return "upi://pay"
        "?pa=$upiId" // Payee Address (UPI ID)
        "&pn=$encodedName" // Payee Name
        "&am=$formattedAmount" // Amount
        "&cu=INR" // Currency
        "&tn=$encodedNote"; // Transaction Note
  }

  /// Get merchant UPI configuration
  /// 
  /// ⚠️ PRODUCTION WARNING:
  /// In production, fetch from Firebase Remote Config or secure API
  /// DO NOT hardcode sensitive merchant details in client code
  /// 
  /// TODO: Replace with actual merchant UPI ID before going live
  static Map<String, String> getMerchantConfig() {
    return {
      'upiId': 'merchant@paytm', // TODO: Replace with actual merchant UPI ID (e.g., canteen@paytm)
      'name': 'College Canteen',
      'supportContact': 'support@collegecanteen.com', // TODO: Add actual support contact
    };
  }

  /// Validate UPI ID format
  /// 
  /// Basic validation - checks for presence of '@' symbol
  /// Real UPI IDs follow format: username@bankname
  static bool isValidUpiId(String upiId) {
    return upiId.contains('@') && upiId.split('@').length == 2;
  }
}
