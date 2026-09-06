import 'sign_in_screen_v2.dart';

/// Compatibility name retained for the app entry point. The implementation is
/// V2, which preserves native biometric/browser-PIN security and adds routed
/// clinical-support identities/workflows.
class SignInScreen extends SignInScreenV2 {
  const SignInScreen({super.key, required super.onSignedIn});
}
