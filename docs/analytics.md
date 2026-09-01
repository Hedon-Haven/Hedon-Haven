# Analytics

Hedon Haven uses [PostHog](https://posthog.com/) (EU servers only) to collect fully anonymous
analytics data: usage pings and bug reports.

Analytic options are presented during the initial onboarding and can be disabled at any time in
`Settings > Privacy`.

#### What is NOT included in any analytics:

- IP addresses: Collection is explicitly disabled in the PostHog configuration.
- Any unique hardware or software identifiers (IMEI, advertising ID, etc.)

## Usage pings

Usage pings let the developers see which platforms and app versions are in active use. The data also
provides an approximate user count.

#### Each usage ping contains:

- [App info](#app-info)
- A `distinct_id`: a one-way hash of a random string that was generated during the first
  installation ("local salt") combined with the current date. The hashed value cannot be reversed to
  reveal the original unique salt. Used to avoid multiple entries from the same user in the
  analytics per day.

#### This is what a real usage ping event looks like on the analytics side:

<details>
<summary>Click to view</summary>

```json
{
  "uuid": "01a05d09-8b49-77dd-8322-db12a7d38f0b",
  "event": "usage_ping",
  "properties": {
    "$process_person_profile": false,
    "appInfo": {
      "architecture": "x86_64",
      "buildSignature": "121D035BCAB3BDF2C039A90FF535C6E7265BAB575727C88A4ADAFE106F7ABB44",
      "installerStore": "com.android.shell",
      "operatingSystem": "android",
      "operatingSystemVersion": "sdk_gphone64_x86_64-userdebug 16 BE2A.250530.026.F3 13894323 dev-keys",
      "packageName": "com.hedon_haven.viewer.debug",
      "resolution_logical": "426x952",
      "resolution_raw": "1280x2856",
      "version": "0.6.7"
    }
  },
  "timestamp": "2026-09-01T14:55:01.705000+02:00",
  "team_id": 218565,
  "distinct_id": "bb0f0b67abf3709a577084a1b7556ef1f023b1240615171aec23b4f0c8298ea0",
  "elements_chain": "",
  "created_at": "2026-09-01T14:55:01.874000+02:00",
  "person_mode": "propertyless"
}
```

</details>

## Bug reports

Bug reports are automatically generated whenever an error occurs in the app or a plugin. If enabled,
these bug reports are also automatically submitted to PostHog.  
Third party plugin errors are never automatically submitted.

- [App info](#app-info)
- A `distinct_id`: completely random per report, with no relation to the device, the
  usage-ping ID, or any other report.
- A stack trace pointing to where the crash happened in the app's code
- The error message produced by the crash
- The screen the crash occurred on
- An optional user-written message

#### This is what a real bug report event looks like on the analytics side:

<details>
<summary>Click to view</summary>

```json
{
  "uuid": "01a04dee-76a4-78ac-ac00-0becf877e6b4",
  "event": "bug_report",
  "properties": {
    "bugReportData": {
      "appInfo": {
        "architecture": "x86_64",
        "buildSignature": "121D035BCAB3BDF2C039A90FF535C6E7265BAB575727C88A4ADAFE106F7ABB44",
        "installerStore": "com.android.shell",
        "operatingSystem": "android",
        "operatingSystemVersion": "sdk_gphone64_x86_64-userdebug 16 BE2A.250530.026.F3 13894323 dev-keys",
        "packageName": "com.hedon_haven.viewer.debug",
        "resolution_logical": "426x952",
        "resolution_raw": "1280x2856",
        "version": "0.6.7"
      },
      "bugReports": {
        "appReports": [
          {
            "codeTrace": "#0      State.setState (package:flutter/src/widgets/framework.dart:1221)\n#1      _HomeScreenState.initState.<anonymous closure>.<anonymous closure> (package:hedon_haven/ui/screens/home.dart:77)\n#2      _RootZone.run (dart:async/zone.dart:1028)\n#3      _FutureListener.handleWhenComplete (dart:async/future_impl.dart:272)\n#4      Future._propagateToListeners.handleWhenCompleteCallback (dart:async/future_impl.dart:909)\n#5      Future._propagateToListeners (dart:async/future_impl.dart:974)\n#6      Future._completeWithValue (dart:async/future_impl.dart:720)\n<asynchronous suspension>\n",
            "errorMessage": "Null check operator used on a null value",
            "isCustomException": null,
            "navigatorPath": "/home/bug-report-emergency"
          }
        ]
      },
      "submissionType": "userApproved",
      "userMessage": ""
    },
    "$process_user_profile": false
  },
  "timestamp": "2026-08-29T16:31:08.708000+02:00",
  "distinct_id": "a0c4cbb50c80"
}
```

</details>

## App info

Both usage pings and bug reports include the same set of basic app/device fields:

- Device architecture (e.g. "arm64")
- Operating system and its version
- App version
- Screen resolution
- Installer source (e.g. which app store installed the app)
- Build signature
