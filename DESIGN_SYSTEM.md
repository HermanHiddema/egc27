# EGC27 Design System

## Brand Colors

### Primary Colors
- **Brand Blue**: `#0f3a77` - Primary brand color, used for headers, buttons, and key elements
- **Brand Red**: `#8c1915` - Accent color for secondary actions and emphasis
- **Brand Yellow**: `#fbba00` - Highlights and call-to-action elements

### Color Palette
Each brand color has a full tonal palette (50-900) for flexibility in design:

#### Blue Palette (`brand-blue`)
```
50:  #f0f4f9    (Lightest)
100: #e1e9f3
200: #c3d3e7
300: #a5bcdb
400: #698bc2
500: #2d5aa9
600: #0f3a77    (Brand Blue - Primary)
700: #0d326a
800: #0a2a5d
900: #082250    (Darkest)
```

#### Red Palette (`brand-red`)
```
50:  #f9f3f1    (Lightest)
100: #f3e6e2
200: #e8ccc5
300: #dbb3a9
400: #c4857a
500: #ad574b
600: #8c1915    (Brand Red - Accent)
700: #7a1612
800: #68120f
900: #560f0c    (Darkest)
```

#### Yellow Palette (`brand-yellow`)
```
50:  #fffbf0    (Lightest)
100: #fff8e1
200: #ffefc2
300: #ffe6a3
400: #ffd965
500: #fbba00    (Brand Yellow - Highlight)
600: #e6a800
700: #cc9600
800: #b38400
900: #997000    (Darkest)
```

#### Neutral Palette (`neutral`)
```
50:  #f9fafb    (Lightest background)
100: #f3f4f6
200: #e5e7eb
300: #d1d5db
400: #9ca3af
500: #6b7280
600: #4b5563
700: #374151
800: #1f2937
900: #111827    (Darkest text)
```

## Typography

### Font Family
- **Display & Body**: Inter (sans-serif)

### Font Sizes & Weights
- **H1**: 48px-60px, weight 800 (Extra Bold), text-brand-blue-600
- **H2**: 36px-48px, weight 700 (Bold), text-brand-blue-600
- **H3**: 24px, weight 600 (Semibold), text-brand-blue-500
- **Body**: 16px, weight 400 (Regular), text-neutral-900
- **Small**: 14px, weight 500 (Medium)

## Components

### Buttons

#### Primary Button (`.btn-primary`)
- Background: `brand-blue-600`
- Text: White
- Hover: `brand-blue-700`
- Usage: Main CTAs, primary actions

#### Secondary Button (`.btn-secondary`)
- Background: `brand-yellow-500`
- Text: `neutral-900`
- Hover: `brand-yellow-600`
- Usage: Alternative actions, secondary CTAs

#### Accent Button (`.btn-accent`)
- Background: `brand-red-600`
- Text: White
- Hover: `brand-red-700`
- Usage: Danger actions, special emphasis

### Cards

#### Standard Card (`.card`)
- Background: White
- Shadow: Medium
- Border Radius: Large (xl)
- Hover: Slight shadow increase

#### Elevated Card (`.card-elevated`)
- Background: White
- Shadow: Larger (`shadow-brand`)
- Border Radius: Large (xl)
- Hover: Even larger shadow (`shadow-brand-lg`)
- Usage: Featured content, primary cards

## Spacing

- Base unit: 0.25rem (4px)
- Sections: `section-padding` = 64px-128px (responsive)
- Container: `container-wide` = max-width 80rem with padding

## Shadows

- `.shadow-brand`: Subtle brand shadow with blue tint
- `.shadow-brand-lg`: Larger, more prominent brand shadow

## Layout Patterns

### Hero Section
- Full-width gradient background (`gradient-hero`)
- White text on blue gradient
- Large typography (H1 in 60px+)
- CTA button below copy

### Feature Cards
- 3-column grid (responsive to 1-2 columns)
- Icon + heading + description
- Elevated cards with hover effects
- Icon in small rounded squares with gradient

### Section Padding
- Use `section-padding` class for consistent vertical spacing
- Use `container-wide` for consistent horizontal padding and max-width

## Usage Examples

### In ERB Templates

```erb
<!-- Hero Section -->
<section class="gradient-hero text-white">
  <div class="container-wide section-padding">
    <h1 class="text-white">Headline</h1>
    <button class="btn-secondary">Call to Action</button>
  </div>
</section>

<!-- Feature Cards -->
<div class="grid grid-cols-1 md:grid-cols-3 gap-8">
  <div class="card-elevated p-8">
    <h3 class="text-brand-blue-600">Feature Title</h3>
    <p>Description here</p>
  </div>
</div>
```

### Tailwind Color Classes
```
text-brand-blue-600       → Primary text
bg-brand-yellow-500       → Yellow background
border-brand-red-600      → Red border
hover:bg-brand-blue-700   → Hover state
gradient-to-br from-brand-blue-500 to-brand-red-600  → Gradient
```

## Accessibility

- Minimum contrast ratio: 4.5:1 for normal text, 3:1 for large text
- All interactive elements have focus states (`:focus-ring-2`)
- Color is never the only indicator of status
- Alt text for all meaningful images

## Dark Mode Considerations

Not currently implemented but extensible via Tailwind's `dark:` prefix when needed.

## Responsive Breakpoints (from Tailwind)

- `sm`: 640px
- `md`: 768px
- `lg`: 1024px
- `xl`: 1280px
- `2xl`: 1536px

Use prefixes like `md:text-4xl` for responsive typography.
