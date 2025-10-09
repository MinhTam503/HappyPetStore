import 'package:flutter/material.dart';

class LocalizationHelper {
  static String getLocalizedText(BuildContext context, String key,
      {String? fallback}) {
    switch (key) {
      // Auth messages with Vietnamese fallbacks
      case 'verifyEmail':
        return fallback ?? 'Xác nhận Email';
      case 'verifyAccount':
        return fallback ?? 'Xác minh tài khoản';
      case 'pleaseCheckEmail':
        return fallback ?? 'Vui lòng kiểm tra email';
      case 'iHaveVerified':
        return fallback ?? 'Tôi đã xác nhận';
      case 'resendVerificationEmail':
        return fallback ?? 'Gửi lại email xác nhận';
      case 'emailAlreadyUsed':
        return fallback ?? 'Email đã được sử dụng';
      case 'verificationEmailSent':
        return fallback ??
            'Email xác nhận đã được gửi! Vui lòng kiểm tra email';
      case 'registrationSuccess':
        return fallback ?? 'Đăng ký thành công! Vui lòng đăng nhập';
      case 'emailNotVerified':
        return fallback ?? 'Email chưa được xác nhận. Tài khoản đã bị hủy';
      case 'fillAllFields':
        return fallback ?? 'Vui lòng điền đầy đủ thông tin';
      case 'passwordMinLength':
        return fallback ?? 'Mật khẩu phải có ít nhất 6 ký tự';
      case 'passwordMismatch':
        return fallback ?? 'Mật khẩu xác nhận không khớp';
      case 'invalidEmailOrPhone':
        return fallback ?? 'Vui lòng nhập email hoặc số điện thoại hợp lệ';
      case 'registrationError':
        return fallback ?? 'Đăng ký thất bại';
      case 'phoneRegistrationError':
        return fallback ?? 'Đăng ký bằng số điện thoại thất bại';
      case 'unknownError':
        return fallback ?? 'Lỗi không xác định';
      case 'incompleteInformation':
        return fallback ?? 'Chưa điền đầy đủ thông tin';
      case 'accountNotExists':
        return fallback ?? 'Tài khoản không tồn tại';
      case 'incorrectInformation':
        return fallback ?? 'Thông tin không chính xác';
      case 'otpError':
        return fallback ?? 'Lỗi gửi OTP';
      case 'verificationFailed':
        return fallback ?? 'Xác thực thất bại';
      case 'verifyPhoneNumber':
        return fallback ?? 'Xác thực số điện thoại';
      case 'enterOtp':
        return fallback ?? 'Nhập mã OTP';
      case 'noItemsInCart':
        return fallback ?? 'Không có sản phẩm nào trong giỏ hàng';
      case 'storeInfo':
        return fallback ?? 'Thông tin cửa hàng';
      case 'notificationTitle':
        return fallback ?? 'Thông báo';
      case 'favorites':
        return fallback ?? 'Yêu thích';
      case 'noFavoriteYet':
        return fallback ?? 'Chưa có sản phẩm yêu thích nào';
      case 'unknownState':
        return fallback ?? 'Trạng thái không xác định';
      case 'removeFromFavorites':
        return fallback ?? 'Xóa khỏi yêu thích';
      case 'myCart':
        return fallback ?? 'Giỏ hàng của tôi';
      case 'processing':
        return fallback ?? 'Đang xử lý';
      case 'loginProcessing':
        return fallback ?? 'Lỗi xử lý đăng nhập';

      // Registration form labels
      case 'fullNameHint':
        return fallback ?? 'Họ và tên';
      case 'accountHint':
        return fallback ?? 'Tài khoản (Email hoặc SĐT)';
      case 'passwordHint':
        return fallback ?? 'Mật khẩu';
      case 'confirmPasswordHint':
        return fallback ?? 'Xác nhận mật khẩu';
      case 'registerButton':
        return fallback ?? 'ĐĂNG KÝ';
      case 'alreadyHaveAccount':
        return fallback ?? 'Bạn đã có tài khoản? ';
      case 'loginNow':
        return fallback ?? 'Đăng nhập ngay';
      case 'orRegisterWith':
        return fallback ?? 'Hoặc đăng ký bằng';

      // Login specific
      case 'loginButton':
        return fallback ?? 'ĐĂNG NHẬP';
      case 'orLoginWith':
        return fallback ?? 'Hoặc đăng nhập bằng';
      case 'pleaseLoginToContinue':
        return fallback ?? 'Vui lòng đăng nhập để tiếp tục';
      case 'forgotPassword':
        return fallback ?? 'Quên mật khẩu?';
      case 'dontHaveAccount':
        return fallback ?? 'Chưa có tài khoản? ';
      case 'registerNow':
        return fallback ?? 'Đăng ký ngay';

      // Favorite screen
      case 'addFavoritePetsMessage':
        return fallback ?? 'Hãy thêm vài thú cưng vào danh sách yêu thích nhé!';
      case 'errorOccurred':
        return fallback ?? 'Đã có lỗi xảy ra';

      // Home page
      case 'defaultUserName':
        return fallback ?? 'Người dùng';
      case 'you':
        return fallback ?? 'Bạn';
      case 'hello':
        return fallback ?? 'Xin chào';
      case 'welcomeToHappyPets':
        return fallback ?? 'Chào bạn đến với Happy Pets Shop!';
      case 'findPerfectCompanion':
        return fallback ??
            'Hãy tìm người bạn đồng hành hoàn hảo cho gia đình bạn';
      case 'searchPetsPlaceholder':
        return fallback ?? 'Tìm kiếm thú cưng';

      // Forgot password
      case 'enterEmailOrPhone':
        return fallback ?? 'Vui lòng nhập email hoặc số điện thoại!';
      case 'checkingEmail':
        return fallback ?? 'Đang kiểm tra email...';
      case 'emailNotExist':
        return fallback ?? 'Email không tồn tại trong hệ thống!';
      case 'resetEmailSent':
        return fallback ?? 'Email đặt lại mật khẩu đã được gửi!';
      case 'checkEmailInstructions':
        return fallback ??
            'Vui lòng kiểm tra email và làm theo hướng dẫn để đặt lại mật khẩu.';
      case 'sendEmailFailed':
        return fallback ?? 'Gửi email thất bại';

      // Form labels
      case 'emailOrPhoneHint':
        return fallback ?? 'Email hoặc Số điện thoại';
      case 'sendRequestButton':
        return fallback ?? 'GỬI YÊU CẦU';

      // OTP verification
      case 'sendingOtp':
        return fallback ?? 'Đang gửi mã OTP...';
      case 'otpSendFailed':
        return fallback ?? 'Gửi OTP thất bại';
      case 'otpSent':
        return fallback ?? 'Mã OTP đã được gửi!';
      case 'enter6Digits':
        return fallback ?? 'Vui lòng nhập đủ 6 số!';
      case 'verifying':
        return fallback ?? 'Đang xác thực...';
      case 'verificationErrorRetry':
        return fallback ?? 'Lỗi xác thực. Vui lòng thử lại!';
      case 'incorrectOtp':
        return fallback ?? 'Mã OTP không chính xác!';
      case 'invalidSession':
        return fallback ?? 'Phiên xác thực không hợp lệ!';

      // Login required messages
      case 'loginRequired':
        return fallback ?? 'Bạn cần đăng nhập trước.';
      case 'accountExistsPleaseLogin':
        return fallback ?? 'Tài khoản đã tồn tại! Vui lòng đăng nhập.';

      // Cart and order messages
      case 'pleaseEnterShippingInfo':
        return fallback ?? 'Vui lòng nhập đầy đủ thông tin giao hàng';
      case 'pleaseAddShippingInfo':
        return fallback ??
            'Vui lòng thêm thông tin giao hàng trước khi đặt hàng';
      case 'pleaseUpdatePhoneNumber':
        return fallback ??
            'Vui lòng cập nhật số điện thoại trong hồ sơ cá nhân trước khi đặt hàng!';
      case 'paymentAmountTooLarge':
        return fallback ??
            'Số tiền quá lớn cho thanh toán Stripe. Vui lòng chọn thanh toán khi nhận hàng.';
      case 'cannotCreatePayment':
        return fallback ??
            'Không thể tạo giao dịch thanh toán. Vui lòng thử lại.';

      // OTP verification error messages
      case 'sessionExpired':
        return fallback ?? 'Phiên xác thực đã hết hạn!';
      case 'authError':
        return fallback ?? 'Lỗi xác thực';
      case 'unknownErrorOccurred':
        return fallback ?? 'Lỗi không xác định';
      case 'missingRegistrationInfo':
        return fallback ?? 'Thiếu thông tin đăng ký!';
      case 'loginFailed':
        return fallback ?? 'Đăng nhập thất bại';
      case 'verificationError':
        return fallback ?? 'Lỗi xác thực';

      // OTP page titles
      case 'verificationRegistrationTitle':
        return fallback ?? 'Xác thực đăng ký';
      case 'forgotPasswordVerificationTitle':
        return fallback ?? 'Xác thực quên mật khẩu';
      case 'loginVerificationTitle':
        return fallback ?? 'Xác thực đăng nhập';
      case 'verifyPhoneNumberTitle':
        return fallback ?? 'Xác thực số điện thoại';
      case 'loginWithOtpTitle':
        return fallback ?? 'Đăng nhập với OTP';

      // OTP UI messages
      case 'otpSentTo':
        return fallback ?? 'Mã xác thực đã được gửi đến';
      case 'verifyButton':
        return fallback ?? 'XÁC THỰC';
      case 'didNotReceiveCode':
        return fallback ?? 'Không nhận được mã? ';
      case 'resendButton':
        return fallback ?? 'Gửi lại';
      case 'resendButtonTimer':
        return fallback ?? 'Gửi lại';

      // Registration messages
      case 'creatingAccount':
        return fallback ?? 'Đang tạo tài khoản...';
      case 'weakPassword':
        return fallback ?? 'Mật khẩu quá yếu!';
      case 'emailInvalid':
        return fallback ?? 'Email không hợp lệ!';
      case 'phoneAlreadyUsed':
        return fallback ?? 'Số điện thoại đã được sử dụng!';
      case 'registeringWithGoogle':
        return fallback ?? 'Đang đăng ký với Google...';
      case 'googleRegistrationSuccess':
        return fallback ?? 'Đăng ký thành công với Google!';
      case 'googleRegistrationFailed':
        return fallback ?? 'Đăng ký Google thất bại';
      case 'googleConfigError':
        return fallback ??
            'Lỗi cấu hình Google Sign-In. Vui lòng sử dụng email thường hoặc thử trên thiết bị thật!';
      case 'googleEmulatorError':
        return fallback ??
            'Google Sign-In không khả dụng trên emulator. Vui lòng sử dụng email thường!';
      case 'networkError':
        return fallback ?? 'Lỗi kết nối mạng. Vui lòng thử lại!';
      case 'googleRegistrationFailedGeneric':
        return fallback ??
            'Đăng ký Google thất bại. Vui lòng thử lại với email thường!';
      case 'registeringWithFacebook':
        return fallback ?? 'Đang đăng ký với Facebook...';
      case 'facebookRegistrationSuccess':
        return fallback ?? 'Đăng ký thành công với Facebook!';
      case 'facebookRegistrationFailed':
        return fallback ?? 'Đăng ký Facebook thất bại';
      case 'facebookConfigError':
        return fallback ??
            'Facebook đăng ký chưa được cấu hình đầy đủ. Vui lòng sử dụng Google hoặc Email!';
      case 'facebookWebViewError':
        return fallback ??
            'Lỗi WebView Facebook. Vui lòng thử lại hoặc sử dụng Email!';
      case 'changePassword':
        return fallback ?? 'Đổi mật khẩu';
      case 'profile':
        return fallback ?? 'Trang cá nhân';
        
      // History settings messages
      case 'searchHistoryDisabledMessage':
        return fallback ?? 'Lịch sử tìm kiếm đã tắt. Tới trang cài đặt để mở';
      case 'viewedPetsHistoryDisabledMessage':
        return fallback ?? 'Lịch sử xem thú cưng đã tắt. Tới trang cài đặt để mở';
      case 'goToSettings':
        return fallback ?? 'Tới cài đặt';
        
      // Admin interface
      case 'admin_panel':
        return fallback ?? 'Bảng điều khiển quản trị';
      case 'something_went_wrong':
        return fallback ?? 'Đã xảy ra lỗi';
      case 'retry':
        return fallback ?? 'Thử lại';

      default:
        return fallback ?? key;
    }
  }
}
