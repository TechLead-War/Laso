# Laso Android

Native Android port scaffold for the current Laso iOS app.

## What is implemented

- Jetpack Compose app shell under `android-app/`
- Three-tab navigation matching iOS: `Today`, `Live`, `Explore`
- Shared health domain vocabulary for categories and metrics
- Android-specific health abstraction via `AndroidHealthGateway`
- First-pass Compose screens styled to mirror the current iOS information architecture
- Gradle wrapper so the project can build with `./gradlew`
- Conditional Firebase plugin wiring and SDK dependencies
- Health Connect manifest setup, rationale activity, onboarding activity, and permission entry points
- Release-signing config path via `keystore.properties`

## What is still stubbed

- Real scoring, insight generation, and streaming pipelines
- Full Health Connect repository implementation that replaces `SampleHealthDataRepository`
- Firebase project credentials and runtime feature wiring to the existing backend flows
- Notifications, subscriptions, and wearable-specific integrations
- Android equivalents for Apple-only features such as HealthKit-specific metrics, Siri/App Intents, and Apple Watch flows

## Build notes

- This machine did not have Java installed, so the project was not compiled here even after adding the Gradle wrapper.
- Open `android-app/` in Android Studio with JDK 17 available, or use `./gradlew assembleDebug`.
- Put your Android Firebase config at `android-app/app/google-services.json`. The Gradle script only applies Firebase plugins if that file exists.
- Copy `android-app/keystore.properties.sample` to `android-app/keystore.properties` and point it at your release keystore if you want signed release builds.
- Health Connect requires Play Console declarations that match the permissions listed in the Android manifest.
