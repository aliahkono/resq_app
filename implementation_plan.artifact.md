# Fix Nested Scaffold and Blank UI in HomeView

The goal is to resolve the blank UI issue in `HomeView` caused by nested `Scaffold` widgets and duplicated headers. We will move the common `Scaffold` and Header logic to the parent `HomeView` and simplify the child views.

## User Review Required

> [!IMPORTANT]
> This refactor will change how headers are managed. Instead of each sub-view (EligibleHome, IneligibleHome, etc.) defining its own header, the parent `HomeView` will manage a single shared header. This ensures layout consistency and fixes the blank screen issue shown in your screenshot.

## Proposed Changes

### [Component] Home Navigation & Dashboard Layout

#### [MODIFY] [home_view.dart](file:///C:/Users/acdiv/StudioProjects/ResQ/lib/views/home/home_view.dart)
- Update the `build` method to contain a single `Scaffold` and `SafeArea`.
- Implement a `_buildTopHeader` method that dynamically updates its title ("Dashboard", "Appointment", "Profile") and its `isEligible` state based on the current tab and result.
- Wrap `_buildBody()` in an `Expanded` widget.

#### [MODIFY] [ineligible_home_view.dart](file:///C:/Users/acdiv/StudioProjects/ResQ/lib/views/home/ineligible_home_view.dart)
- Remove `Scaffold`, `SafeArea`, and `_buildTopHeader`.
- Change `build` to return a `Column` or `SingleChildScrollView` directly.

#### [MODIFY] [eligible_home_view.dart](file:///C:/Users/acdiv/StudioProjects/ResQ/lib/views/home/eligible_home_view.dart)
- Remove `Scaffold`, `SafeArea`, and `_buildTopHeader`.
- Change `build` to return a `Column` or `SingleChildScrollView` directly.

#### [MODIFY] [ineligible_appoint_view.dart](file:///C:/Users/acdiv/StudioProjects/ResQ/lib/views/appointment/ineligible_appoint_view.dart)
- Remove `Scaffold`, `SafeArea`, and `_buildAppointmentHeader`.

## Verification Plan

### Automated Tests
- I will verify the code compiles without errors.

### Manual Verification
- The user should verify that the "Home" tab now displays correctly without the blank white space in the middle.
- Verify that switching tabs ("Appointment", "Profile") updates the header title and maintains the correct layout.
