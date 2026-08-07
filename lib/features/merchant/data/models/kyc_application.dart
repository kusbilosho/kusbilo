/// The data a merchant submits during onboarding. Kept as a plain model
/// (not scattered across form field variables) so it can be handed to a
/// real backend call later without any UI changes.
class KycApplication {
  final String shopName;
  final String ownerName;
  final String aadhaarNumber;
  final String? panNumber;
  final String address;
  final String village;
  final String district;
  final String state;
  final String pincode;
  final String bankAccountNumber;
  final String ifscCode;
  final double shopLat;
  final double shopLng;
  final String? description;
  final int? prepMinutes;

  const KycApplication({
    required this.shopName,
    required this.ownerName,
    required this.aadhaarNumber,
    this.panNumber,
    required this.address,
    required this.village,
    required this.district,
    required this.state,
    required this.pincode,
    required this.bankAccountNumber,
    required this.ifscCode,
    required this.shopLat,
    required this.shopLng,
    this.description,
    this.prepMinutes,
  });

  KycApplication copyWith({String? shopName, String? description, int? prepMinutes}) => KycApplication(
        shopName: shopName ?? this.shopName,
        ownerName: ownerName,
        aadhaarNumber: aadhaarNumber,
        panNumber: panNumber,
        address: address,
        village: village,
        district: district,
        state: state,
        pincode: pincode,
        bankAccountNumber: bankAccountNumber,
        ifscCode: ifscCode,
        shopLat: shopLat,
        shopLng: shopLng,
        description: description ?? this.description,
        prepMinutes: prepMinutes ?? this.prepMinutes,
      );
}
