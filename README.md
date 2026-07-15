# flutter_ai_chat

<a href="https://buymeacoffee.com/codewithsora" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/default-orange.png" alt="Buy Me A Coffee" height="41" width="174"></a>

Flutter와 Firebase를 함께 배우는 예제 프로젝트입니다.

## 소개

이 프로젝트는 채팅 앱의 기본 구조와 Firebase 연결 과정을 함께 보여주기 위한 학습용 예제입니다.

Firebase 설정 파일은 실제 실행에 필요하지만, 강의에서는 직접 생성 과정을 보여주기 위해 `.example` 파일만 참고용으로 두었습니다.

## 준비 사항

- Flutter SDK
- Firebase 계정
- Android Studio 또는 VS Code
- iOS/macOS 빌드가 필요하면 Xcode

## Firebase 설정 방법

1. Firebase Console에서 새 프로젝트를 생성합니다.
2. Android, iOS, macOS 앱을 각각 등록합니다.
3. 프로젝트에 맞는 설정 파일을 생성합니다.
4. 아래 파일들을 실제 파일명으로 복사한 뒤 내용을 채웁니다.

### 참고 파일

- `firebase.json.example`
- `lib/firebase_options.dart.example`
- `android/app/google-services.json.example`
- `ios/Runner/GoogleService-Info.plist.example`
- `macos/Runner/GoogleService-Info.plist.example`

## Firestore Rules 배포

`firestore.rules` 파일을 수정한 뒤에는 Firebase CLI로 아래처럼 배포합니다.

```bash
firebase login
firebase use <your-firebase-project-id>
firebase deploy --only firestore:rules
```

프로젝트를 직접 지정해서 배포할 수도 있습니다.

```bash
firebase deploy --only firestore:rules --project <your-firebase-project-id>
```

## 실행 방법

```bash
flutter pub get
flutter run
```

## 링크

- YouTube 강의 : https://youtu.be/ZPanY02a6F8
- 깃헙 코드 : https://github.com/ExplainingDeveloper/ai-chat

## 참고

이 저장소는 강의용이라서, Firebase 설정은 직접 따라 하면서 완성하는 것을 목표로 합니다.
