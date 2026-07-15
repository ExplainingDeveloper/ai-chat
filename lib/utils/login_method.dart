import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginMethod {
  static bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }
    await GoogleSignIn.instance.initialize();
    _initialized = true;
  }

  Future<UserCredential> signInWithGoogle() async {
    final credential = await _getGoogleCredential();

    // Once signed in, return the UserCredential
    return await FirebaseAuth.instance.signInWithCredential(credential);
  }

  /// 민감한 작업(예: 다중 인증 등록) 직전에 최근 로그인 상태를 갱신한다.
  /// Firebase는 이런 작업에 "recent login"을 요구하며, 오래 전에 로그인한
  /// 세션으로는 requires-recent-login 오류가 발생한다.
  Future<UserCredential> reauthenticateWithGoogle(User user) async {
    final credential = await _getGoogleCredential();
    return await user.reauthenticateWithCredential(credential);
  }

  Future<void> signOut() async {
    await _ensureInitialized();
    await GoogleSignIn.instance.signOut();
    await FirebaseAuth.instance.signOut();
  }

  Future<AuthCredential> _getGoogleCredential() async {
    await _ensureInitialized();

    // Trigger the authentication flow
    final GoogleSignInAccount googleUser = await GoogleSignIn.instance
        .authenticate();

    // Obtain the auth details from the request
    final GoogleSignInAuthentication googleAuth = googleUser.authentication;

    // Create a new credential
    return GoogleAuthProvider.credential(idToken: googleAuth.idToken);
  }

  /// 전화번호를 이용한 다중 인증(MFA) 등록의 1단계.
  /// 인증번호(SMS)를 발송하고, 완료/실패/코드발송 시점을 콜백으로 알려준다.
  Future<void> startPhoneMultiFactorEnrollment({
    required User user,
    required String phoneNumber,
    required PhoneCodeSent onCodeSent,
    required PhoneVerificationFailed onVerificationFailed,
    PhoneCodeAutoRetrievalTimeout? onCodeAutoRetrievalTimeout,
  }) async {
    final MultiFactorSession session = await user.multiFactor.getSession();

    await FirebaseAuth.instance.verifyPhoneNumber(
      multiFactorSession: session,
      phoneNumber: phoneNumber,
      verificationCompleted: (_) {},
      verificationFailed: onVerificationFailed,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: onCodeAutoRetrievalTimeout ?? (_) {},
    );
  }

  /// 전화번호 다중 인증(MFA) 등록의 2단계.
  /// 사용자가 입력한 SMS 코드로 자격 증명을 만들어 계정에 등록한다.
  Future<void> confirmPhoneMultiFactorEnrollment({
    required User user,
    required String verificationId,
    required String smsCode,
    String? displayName,
  }) async {
    final PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    await user.multiFactor.enroll(
      PhoneMultiFactorGenerator.getAssertion(credential),
      displayName: displayName,
    );
  }

  /// 다중 인증이 등록된 계정으로 로그인할 때 2차 인증(SMS)의 1단계.
  /// [resolver]는 1차 로그인(signInWithGoogle 등)에서 던져진
  /// FirebaseAuthMultiFactorException.resolver를 그대로 넘겨받는다.
  Future<void> verifyPhoneSecondFactor({
    required MultiFactorResolver resolver,
    required PhoneMultiFactorInfo hint,
    required PhoneCodeSent onCodeSent,
    required PhoneVerificationFailed onVerificationFailed,
    PhoneCodeAutoRetrievalTimeout? onCodeAutoRetrievalTimeout,
  }) async {
    await FirebaseAuth.instance.verifyPhoneNumber(
      multiFactorSession: resolver.session,
      multiFactorInfo: hint,
      verificationCompleted: (_) {},
      verificationFailed: onVerificationFailed,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: onCodeAutoRetrievalTimeout ?? (_) {},
    );
  }

  /// 다중 인증 로그인의 2단계.
  /// 사용자가 입력한 SMS 코드로 2차 인증을 완료하고 로그인을 마무리한다.
  Future<UserCredential> confirmSecondFactorSignIn({
    required MultiFactorResolver resolver,
    required String verificationId,
    required String smsCode,
  }) async {
    final PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    return await resolver.resolveSignIn(
      PhoneMultiFactorGenerator.getAssertion(credential),
    );
  }

  /// 계정에 등록된 2차 인증 수단 목록을 가져온다.
  Future<List<MultiFactorInfo>> getEnrolledFactors(User user) {
    return user.multiFactor.getEnrolledFactors();
  }

  /// 등록된 2차 인증 수단 하나를 계정에서 해제한다.
  /// unenroll도 민감한 작업이라, 호출 전에 재인증이 필요할 수 있다.
  Future<void> unenrollFactor(User user, MultiFactorInfo factor) {
    return user.multiFactor.unenroll(multiFactorInfo: factor);
  }
}
