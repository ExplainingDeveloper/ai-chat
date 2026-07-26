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
    await _ensureInitialized();

    // Trigger the authentication flow
    final GoogleSignInAccount googleUser = await GoogleSignIn.instance
        .authenticate();

    // Obtain the auth details from the request
    final GoogleSignInAuthentication googleAuth = googleUser.authentication;

    // Create a new credential
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    // Once signed in, return the UserCredential
    return await FirebaseAuth.instance.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    await _ensureInitialized();
    await GoogleSignIn.instance.signOut();
    await FirebaseAuth.instance.signOut();
  }
}
