# Play Store checklist

Prepared 14 November 2026. This is a submission checklist, not a claim of Play
approval. Public policy/deletion resources and live service tests remain gates.

## Build and signing

- [ ] Confirm permanent package ID `com.charlie22dev.lingoblob` before first upload.
- [ ] Increment `1.0.0+1`'s build number for each subsequent Play upload.
- [ ] Securely back up the ignored keystore and `android/key.properties` outside Git.
- [ ] Enroll in Play App Signing. The upload key signs uploads; the distributed
  application uses the separate app-signing key managed through Play.
- [ ] Run `flutter analyze`, `flutter test`, build the release AAB, and run
  `python tool/verify_android_bundle.py`.
- [ ] Upload `build/app/outputs/bundle/release/app-release.aab` to internal testing.
- [ ] Validate generated APK ZIP alignment and 16 KB page-size operation with
  Play/bundletool and a compatible device. The local verifier checks ELF load
  alignment, not Play-generated APK ZIP layout.
- [ ] Recheck target SDK rules at upload. Current rules require API 36+ for
  ordinary new Android apps/updates from August 31, 2026; this project targets 37.
  [Google's target API policy](https://support.google.com/googleplay/android-developer/answer/11926878)

## Store listing draft

**Title:** LingoBlob: Learn Languages

**Short description:** Learn six languages with short lessons, flashcards and speaking practice.

**Full description:**

Learn Japanese, Spanish, French, German, Italian or Brazilian Portuguese one
small step at a time with LingoBlob and Pip.

Practice common beginner words and phrases through short lessons. Choose an
answer, match pairs, fill a gap, translate a phrase, listen and try speaking.
Get clear feedback and revisit mistakes while you learn.

Build a study habit with daily XP goals, streaks and reminders you control.
Review vocabulary with spaced repetition, hear pronunciations and save useful
words from conversation practice.

Practice introductions, ordering food, directions and shopping with an AI tutor.
Reveal translations when you need them and expand gentle corrections. AI replies
can make mistakes.

Your progress stays on your device and syncs to your account when online. Cached
accounts can continue lessons and reviews offline; new AI replies need internet.
Speaking availability depends on your device and installed services.

Designed for English-speaking beginners, with light/dark themes and a daily goal
that fits your routine. Switch courses in Settings and keep your progress.

Only advertise cloud/AI features once their production services are configured
and tested. Do not claim offline AI or guaranteed fluency.

## Visual assets

- [ ] Export an opaque 512x512 store icon from `assets/branding/app_icon.png`.
- [ ] Create a feature graphic using current Play specifications (commonly
  1024x500); launcher/splash artwork does not replace it.
- [ ] Review at least two phone screenshots on real devices. Current generated
  1080x1920 captures are in `docs/screenshots/`, using isolated test data.
- [ ] Capture Learn, an exercise, populated Review, Profile and optional live
  Chat. Current empty Review/Chat captures demonstrate their empty states.
- [ ] Use accurate UI with no private account details or unsupported claims.

## Privacy and account deletion

- [ ] Replace placeholders in `PRIVACY_POLICY_DRAFT.md`, verify deployment
  settings, publish a stable HTTPS policy and link it from Play Console and the app.
- [ ] Provide an in-app account-deletion request path and a public web deletion
  resource. **Reset progress and Log out do not delete an account.** A production
  deletion endpoint/page is not implemented here, so this is a publication blocker.
  [Google's deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111)
- [ ] Test removal of the Supabase auth identity and associated cloud data,
  session revocation and local-cache cleanup. Specify retention exceptions.

## Data safety inventory

Review SDKs and deployed settings before submitting answers; this inventory is
not an automatically completed declaration.

| Data | Implementation | Review for the form |
| --- | --- | --- |
| Email, user ID, optional name | Supabase Auth/profile | Personal info; account functionality and deletion |
| XP, streaks, lesson/word progress, daily activity | Local SQLite and owned cloud rows | App activity; functionality/personalization |
| Learner conversation text | Local last 20 messages; context through Supabase to Groq | User-generated content, processing and retention |
| Suggested vocabulary | Saved locally and synchronized | Learning activity/content |
| Optional voice input | Platform speech provider; transcript received, no app recordings stored | Verify provider off-device processing before answering audio questions |
| Pronunciation downloads | Audio host requests/local cache | Network metadata and provider practices |
| Infrastructure logs | Supabase/Groq deployment settings | Verify IP/device metadata, retention and access |
| Ads/analytics | No ads or analytics SDK configured in this codebase | Reassess when integrations change |

Assess the service-provider exceptions when deciding Google's definition of
sharing. Offline SQLite does not mean no data is collected.
[Google's Data safety guidance](https://support.google.com/googleplay/android-developer/answer/10787469)

## Runtime and reviewer access

- [ ] Deploy all migrations and `chat`; put `GROQ_API_KEY` only in server secrets.
- [ ] Verify signup, confirmation, OAuth, recovery, expiry, offline study, reconnect
  sync and two-account isolation using release builds.
- [ ] Confirm the existing Supabase deep-link redirect allowlist.
- [ ] Supply a dedicated reviewer account in Play Console's App access section;
  never commit its password.
- [ ] Test denied/revoked microphone and notification access, unavailable voices,
  keyboard resizing, Android Back, interruptions and reduced motion.
- [ ] Check TalkBack order, 48 dp targets, contrast, dark mode and 200% text on
  physical devices. Review Play pre-launch reports and low-end device performance.
- [ ] Complete content rating, target audience, ads, support contacts and any
  applicable AI-content questions. No child-specific consent flow exists here.
- [ ] Review Chat against the AI-generated-content policy and implement in-app
  reporting/flagging of offensive tutor responses before public AI release.
  The current Chat UI has no reporting workflow; moderation alone does not
  provide that user action. [Google's AI-content policy](https://support.google.com/googleplay/android-developer/answer/13985936)
- [ ] For applicable new personal accounts, complete closed testing with 12
  continuously opted-in testers for 14 days, then apply for production access.
  [Google's testing requirements](https://support.google.com/googleplay/android-developer/answer/14151465)

Build setup follows [Flutter's Android release guide](https://docs.flutter.dev/deployment/android).
