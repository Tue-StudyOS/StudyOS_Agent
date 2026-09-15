# StudyOS Agent — Product Walkthrough

This guide accompanies the course Product Artifact submission. It describes the
implemented interface and an intended user scenario; the example questions are
not a transcript of a recorded test. Actual results depend on the student's
account, available university data, device capabilities, and configured model.

## A student preparing for the day

The student wants to find their next lecture, check upcoming coursework, and
choose somewhere to eat without navigating several university portals.

### 1. Connect the student workspace

The opening screen is titled **StudyOS**, with the subtitle **Connect your
student workspace**. The student enters their university ID or email and
password, selects **Continue**, and completes onboarding. The app uses a
student profile to personalise the experience.

University integrations run from the device rather than through a shared
StudyOS aggregation backend. A university login is needed for personal portal
data; public information such as Mensa menus has separate public sources.

### 2. See what is relevant now

**Home** presents a greeting, the next lecture when timetable data is available,
and a **For you** feed. It also provides access to Profile, Assistant setup,
Notes, Tübingen Talks, and University Mail.

This is the entry point for discovering information without first knowing the
name of a university service or the exact question to ask.

### 3. Inspect the study plan

The bottom navigation offers **Home**, **Plan**, and **Assistant**. In **Plan**,
the student can inspect timetable information and academic registration status,
refresh data, and access supported calendar/report actions.

This is an overview of information retrieved from university sources, not a
promise that the assistant can enrol a student in a course or submit coursework.
Missing data or a failed refresh should be checked against the source portal.

### 4. Ask a question and inspect the result

The student opens **Assistant** and asks, for example:

> What deadlines do I have in the next seven days?

The assistant can use the ILIAS/Moodle deadline tools to retrieve relevant data
and answer in the conversation. Supported results can appear as inline UI cards;
the exact presentation depends on the model's response. Calling a tool does not
automatically guarantee that a card will be shown.

A second example is:

> What vegan Mensa options are available today?

The assistant can query public Mensa information rather than relying on a
student to locate and navigate a separate menu page. Timetable, study planner,
and campus information are further examples of tool-backed capabilities.

The central design decision is to expose many capabilities through a compact
conversation instead of giving every tool its own top-level page. Dedicated
views remain available where they make recurring information easier to inspect.

### 5. Maintain personal context and choose the model

The student can revisit conversations and edit the local memory document through
**Notes**. **Settings → Assistant setup** controls the model configuration.

- **On device:** local model execution requires a compatible device and available
  model. Android and iOS use different native integrations.
- **Custom/cloud:** the student configures a provider and API key. Relevant
  conversation context and tool results are sent to that provider. Portal
  credentials and raw portal sessions are not intended to enter model prompts.

Local inference avoids sending prompts to a cloud model, but retrieving current
university information still requires network access to the university services.

## Current boundaries

The repository contains a Flutter implementation, native Android/iOS runners,
and web/desktop targets. These are not interchangeable deployment experiences:
native actions and local inference depend on the platform. Web builds also run
under browser networking restrictions, so they should not be assumed to support
every direct university integration available on mobile.

The main remaining product questions concern setup complexity, reliability
across student accounts and devices, and wider distribution. Local models add
setup requirements; cloud models introduce provider dependencies and a different
data-sharing choice. Portal parsing needs maintenance when external sites change.

The team simplified the first prototype after feedback that a combined interface
was still too complex. More user testing is needed to assess how well the revised
workflow works for students outside the project group. An assistant plugin is a
possible future direction, not the product submitted in this repository.

## Implementation references

These links let a reviewer connect the described workflow to the source without
having to install the application.

| Part of the experience | Source |
| --- | --- |
| Login | [Login screen](../flutter_app/lib/src/login_page.dart) |
| Navigation | [App routes](../flutter_app/lib/src/app_router.dart) |
| Home overview | [Home view](../flutter_app/lib/src/views/home_view.dart) |
| Study plan | [Schedule view](../flutter_app/lib/src/views/schedule_view.dart) |
| Assistant capabilities | [Tool catalog](../flutter_app/lib/src/studyos_tool_catalog.dart) |
| Inline cards | [Assistant UI payload handling](../flutter_app/lib/src/generated_ui_message.dart) |
| Tasks and deadlines | [University capabilities](../flutter_app/lib/src/private_study_capabilities.dart) |
| Model configuration | [Settings](../flutter_app/lib/src/views/settings_view.dart) |

For installation routes and build requirements, return to the
[repository README](../README.md).
