# AI Instructions for egc27

This file defines project-specific guidance for AI coding agents working in this repository.

## Core Principles
- Prefer standard Rails conventions over custom patterns.
- Keep changes small, readable, and easy to review.
- Preserve existing architecture and visual style unless explicitly asked to redesign.
- Never make destructive git changes unless explicitly requested.

## Stack and Architecture
- Rails 8.1 app with Hotwire (Turbo + Stimulus), importmap, and Tailwind.
- PostgreSQL database across environments.
- Authentication via Devise.
- Controllers inherit from `ApplicationController`.

## Implementation Best Practices
- Use strong params for all controller writes.
- Add model validations for required fields and data format constraints.
- Keep business rules in models/services, not in views.
- Prefer service objects for external API integrations.
- For date input/output, use European format expectations (day before month) where requested.
- For participant country storage, keep ISO 3166-1 alpha-2 code semantics.

## Frontend Best Practices
- Use Stimulus controllers for client-side behavior.
- Keep form behavior accessible and resilient (keyboard and mouse friendly).
- Avoid adding heavy dependencies when native browser APIs are sufficient.
- Keep class naming and UI patterns consistent with existing forms.

## Testing and Verification
- Add or update tests whenever behavior changes.
- Prioritize model and controller tests for business logic and params.
- Run focused tests for changed areas before broader test suites when possible.
- Always run `bin/rubocop --autocorrect` before committing any changes.

## Safety and Data Integrity
- Do not silently change persisted data semantics.
- If data format changes are required, include migration and model normalization.
- Validate external API payloads defensively.

## Preference Update Rule (Important)
When the user expresses a new coding/UI/process preference in chat:
1. Apply the preference to the current task immediately.
2. Update this file (`AGENTS.md`) in the same work session so future agent runs follow it.
3. Keep the preference phrasing concise and actionable.
4. If a new preference conflicts with an existing one, replace the old rule and note the new default.

## Current User Preferences Captured
- Keep participant date UX aligned with European day-before-month expectations.
- Use full strength labels: `kyu`, `dan`, `dan pro`.
- Show stronger playing strengths first.
- Country selector should support autocomplete with ISO alpha-2 semantics.
- Taiwan display name: `Chinese Taipei (Taiwan)`.
