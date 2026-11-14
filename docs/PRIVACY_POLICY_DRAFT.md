# LingoBlob privacy policy draft

Owner review required before publication. Replace `[PUBLISHER_NAME]`,
`[SUPPORT_EMAIL]`, `[EFFECTIVE_DATE]`, `[PRIVACY_URL]` and
`[DELETION_REQUEST_URL]`. Confirm retention periods, regions and provider settings.

**Publisher:** [PUBLISHER_NAME]  
**Effective date:** [EFFECTIVE_DATE]  
**Contact:** [SUPPORT_EMAIL]

## Account and learning information

LingoBlob teaches beginner Japanese. Supabase receives your email and account
identifier for account management, and an optional display name. Google/Supabase
process Google sign-in when chosen. Supabase Auth manages passwords and sessions;
the app does not retain plaintext passwords. Its SDK caches session credentials.

Lessons, XP, streaks, goals, review schedules and activity history support learning
and synchronization. SQLite stores progress per account on the device; owned
cloud rows synchronize through Supabase. Preferences store appearance, sound and
reminder choices. Pronunciation files may be cached locally.

## Conversations and optional voice

Conversation practice sends the scenario and message context through Supabase to
Groq to produce replies, corrections, translations and vocabulary. The last 20
messages remain locally per account; history is not synchronized to progress
tables. Explicitly saved words and their review schedules are synchronized.
Avoid sensitive personal information in practice conversations.

Microphone access is optional and requested when recording is chosen. The app
uses device/browser speech recognition and receives recognized text. It does not
store recordings or send raw recordings to its chat function. The speech provider
may process audio remotely under its terms. Keyboard input and optional exercise
skipping remain available. TTS processing depends on the selected voice/provider.

Local reminders are optional. You can change their time, disable them or revoke
notification permission without losing access to lessons.

## Providers, storage and retention

Supabase supplies account, database and Edge services; Groq processes AI text.
Google or another platform provider may process chosen sign-in/speech requests.
Audio URLs contact their hosts. Infrastructure providers may keep security,
access or request metadata. Insert verified regions, vendor privacy links and
configured retention periods here before publication. Do not promise zero AI
retention without verifying the actual Groq account settings and agreements.

Specify cloud account/progress retention, log retention and deletion timelines.
Local history is bounded to 20 messages. Signing out does not erase the local
account database; uninstalling clears app-private data according to the platform.
Progress reset is distinct from account deletion.

## Deletion and choices

Request deletion at [DELETION_REQUEST_URL] or through the in-app request path.
**Those production paths must be implemented and tested before publishing this
paragraph.** Describe identity verification, deletion of cloud and local data,
session revocation and any lawful retention exceptions. Contact [SUPPORT_EMAIL]
for access, correction or deletion questions.

You may decline optional microphone/reminder access, change settings, study cached
material offline and stop submitting conversations. HTTPS protects service
requests; cloud ownership policies restrict rows to their authenticated owner.
The Groq and signing keys are not bundled with the app. Public Supabase client
configuration relies on server authorization and Row Level Security.

No advertising or analytics SDK is configured in this codebase; review that
statement whenever integrations change. Specify the intended age audience before
publication: this build has no parental-consent or child-specific account flow.
Publish updates and the effective date at [PRIVACY_URL] when practices change.
