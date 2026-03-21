---
name: dev-ui
description: UI development approach — component architecture, state management, accessibility, and user experience patterns.
---

# UI Development

You apply these principles when building user interfaces, regardless of framework.

## Component Architecture

### Structure

- Components should do one thing well — if a component has multiple responsibilities, split it
- Separate presentation from logic: keep rendering pure and predictable, push side effects and data fetching to the edges
- Name components by what they are, not what they do: `UserProfile` not `RenderUserData`
- Prefer composition over configuration — small composable components beat large ones with many props/flags

### Props and data flow

- Data flows down, events flow up — parent passes data to children, children notify parent via callbacks or events
- Keep the prop surface small — a component that takes 15 props probably needs to be split
- Use sensible defaults for optional props — the component should be useful with minimal configuration
- Don't pass data through intermediate components that don't use it (prop drilling) — use context, state management, or composition instead

### Component hierarchy

```
Page / Route
  └── Layout (header, sidebar, content area)
       └── Feature Container (data fetching, state)
            └── Presentation Components (rendering, styling)
                 └── Shared UI Primitives (button, input, card)
```

- Pages own routing and data loading
- Containers handle state and side effects
- Presentation components are pure: same props = same output
- Primitives are the design system — reusable across features

## State Management

### Where state lives

- **Local component state**: UI state that only this component cares about (open/closed, hover, form field values before submit)
- **Shared state**: Data multiple components need (current user, theme, feature flags) — lift to nearest common ancestor or use a state store
- **Server state**: Data from APIs — use purpose-built tools (React Query, SWR, Apollo) that handle caching, revalidation, and loading states
- **URL state**: Filters, pagination, search terms — put in the URL so it's shareable and survives refresh

### Principles

- Derive what you can — don't store `fullName` if you have `firstName` and `lastName`
- Single source of truth — each piece of state lives in exactly one place
- Keep state as close to where it's used as possible — don't hoist prematurely
- Treat server data as a cache, not as state you own — it can change out from under you

## Forms

- Validate on blur (field level) and on submit (form level)
- Show errors inline next to the relevant field, not in a banner at the top
- Preserve user input on validation failure — never clear a form the user just filled in
- Disable submit button while submitting, show a loading indicator
- Handle the full lifecycle: idle, validating, submitting, success, error
- For complex forms, use a form library — don't hand-roll state tracking for 20 fields

## Loading and Error States

### Every async operation has three states

1. **Loading** — show a skeleton, spinner, or placeholder. Never show a blank screen.
2. **Success** — render the data
3. **Error** — show what went wrong and what the user can do about it

### Patterns

- Use skeleton screens instead of spinners where possible — they feel faster
- Show stale data while revalidating in the background (stale-while-revalidate)
- For errors: show a message, a retry button, and (if applicable) a way to report the issue
- Empty states are not errors — design for them: "No results found. Try adjusting your search."

## Accessibility

### Fundamentals

- Use semantic HTML elements: `<button>` not `<div onClick>`, `<nav>` not `<div class="nav">`
- All images need `alt` text — decorative images get `alt=""`
- All form inputs need associated `<label>` elements
- Ensure sufficient colour contrast (WCAG AA: 4.5:1 for normal text, 3:1 for large text)
- Don't rely on colour alone to convey meaning — add icons, text, or patterns

### Keyboard navigation

- All interactive elements must be reachable via Tab
- Custom widgets need appropriate ARIA roles, states, and keyboard handlers
- Focus management: when a modal opens, focus moves to it; when it closes, focus returns to the trigger
- Visible focus indicators — never remove the outline without providing an alternative

### Screen readers

- Use heading hierarchy: `h1` → `h2` → `h3`, don't skip levels
- Use `aria-live` regions for dynamic content updates (notifications, form errors)
- Hide decorative elements from screen readers with `aria-hidden="true"`
- Test with a screen reader — VoiceOver on macOS, NVDA on Windows

## Performance

### Rendering

- Don't render what's off-screen — use virtualisation for long lists
- Memoize expensive computations and components that receive the same props
- Debounce rapid user input (search-as-you-type, window resize)
- Avoid layout thrashing — batch DOM reads and writes

### Assets

- Lazy-load images and heavy components below the fold
- Optimise images: use modern formats (WebP, AVIF), serve appropriate sizes
- Code-split by route — don't ship the entire app in one bundle
- Set appropriate cache headers for static assets

## Responsive Design

- Design mobile-first, then enhance for larger screens
- Use relative units (rem, %, vh/vw) over fixed pixels for layout
- Test at real breakpoints, not just "desktop and mobile" — tablets and small laptops matter
- Touch targets need minimum 44x44px for comfortable tapping
- Consider content priority: what matters most on a small screen? Show that first.
