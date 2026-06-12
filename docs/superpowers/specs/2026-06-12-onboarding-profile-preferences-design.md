# Onboarding Profile And Preferences Design

## Goal

Make onboarding useful without feeling like setup work. The first run should
connect the university account, confirm the profile data StudyOS can fetch, and
collect only the preferences that immediately improve the app experience.

## Flow

1. Sign in
   - Ask for university ID or email and password.
   - Store credentials only with platform secure storage.
   - Fetch profile data before showing the next step.

2. Confirm profile
   - Show this as `Confirm profile`.
   - Pre-fill name, degree program, semester, and email when available.
   - Let the user edit incorrect or missing fields.
   - Do not ask for email manually when the university account can provide it.

3. Choose what StudyOS should help with
   - Use selectable chips, not text input.
   - Initial options: `Schedule`, `Deadlines`, `Mensa`, `Study planning`,
     `Campus info`, and `Notifications`.
   - Persist selected interests as profile preferences.

4. Mensa preferences
   - Show only when the user selected `Mensa`.
   - Use a segmented or chip control: `No preference`, `Vegetarian`, `Vegan`.
   - Store the preference locally and use it to filter or highlight food options.

5. Notification preferences
   - Ask for notification categories before requesting OS permission.
   - Initial categories: `Deadline reminders`, `Next lecture`, and
     `Mensa updates`.
   - Request native notification permission only after the user enables a
     category that needs it.

6. Finish
   - Land on Home with useful cards based on selected interests.
   - Chat should inherit compact profile and preference context at session start.

## Data To Avoid Up Front

- Do not ask for age.
- Do not ask for exact home address.
- Do not ask for precise location permission during onboarding.
- If location-aware campus features are added later, request location only from
  the relevant feature with a concrete explanation such as nearby Mensa results.

## Input Model

- Prefer chips or segmented controls for known choices.
- Prefer fetched values plus an edit action for university profile data.
- Use text input only for fields that cannot be fetched, such as a corrected
  display name or degree program.

## UX Rules

- Keep the default path under one minute.
- Make optional personalization skippable.
- Ask for sensitive permissions only when the user understands the benefit.
- Keep wording student-facing and avoid technical terms.
- Do not expose app credentials, tokens, bridge status, or model setup during
  onboarding.

## Implementation Notes

- Extend the profile model with interest, food, and notification preferences.
- Keep credentials separate from profile preferences.
- Profile and preference data should remain local unless a future feature has a
  clear reason to send it.
- Existing chat context injection should include only compact profile and
  preference data at session start.

## Acceptance Checks

- A new user can complete onboarding without typing anything that was already
  fetched from the university account.
- Mensa preference appears only after selecting Mensa as an interest.
- Notification categories are selectable without immediately triggering the OS
  permission dialog.
- No age, exact address, API token, model, or bridge status appears in
  onboarding.
- Home reflects selected interests after onboarding completes.
