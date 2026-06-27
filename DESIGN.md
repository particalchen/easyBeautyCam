---
name: EasyBeautyCam
colors:
  surface: '#fdf8f6'
  surface-dim: '#ddd9d7'
  surface-bright: '#fdf8f6'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f7f3f1'
  surface-container: '#f2edeb'
  surface-container-high: '#ece7e5'
  surface-container-highest: '#e6e1e0'
  on-surface: '#1c1b1a'
  on-surface-variant: '#56423f'
  inverse-surface: '#32302f'
  inverse-on-surface: '#f5f0ee'
  outline: '#89726e'
  outline-variant: '#dcc0bc'
  surface-tint: '#9f4035'
  primary: '#9f4035'
  on-primary: '#ffffff'
  primary-container: '#ff8a7a'
  on-primary-container: '#762219'
  inverse-primary: '#ffb4a9'
  secondary: '#884f41'
  on-secondary: '#ffffff'
  secondary-container: '#ffb4a2'
  on-secondary-container: '#7a4336'
  tertiary: '#5f5e5e'
  on-tertiary: '#ffffff'
  tertiary-container: '#adabab'
  on-tertiary-container: '#403f3f'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#ffdad5'
  primary-fixed-dim: '#ffb4a9'
  on-primary-fixed: '#410000'
  on-primary-fixed-variant: '#7f2920'
  secondary-fixed: '#ffdad2'
  secondary-fixed-dim: '#ffb4a2'
  on-secondary-fixed: '#360e05'
  on-secondary-fixed-variant: '#6c382b'
  tertiary-fixed: '#e5e2e1'
  tertiary-fixed-dim: '#c8c6c5'
  on-tertiary-fixed: '#1c1b1b'
  on-tertiary-fixed-variant: '#474746'
  background: '#fdf8f6'
  on-background: '#1c1b1a'
  surface-variant: '#e6e1e0'
  text-primary: '#2D2D2D'
  text-secondary: '#999999'
  pose-line: rgba(255, 255, 255, 0.55)
  pose-glow: rgba(255, 255, 255, 0.20)
  overlay-bg: rgba(255, 250, 248, 0.95)
  border-light: '#EEEEEE'
typography:
  headline-lg:
    fontFamily: SF Pro Display
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
  headline-md:
    fontFamily: SF Pro Display
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: SF Pro Text
    fontSize: 17px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: SF Pro Text
    fontSize: 15px
    fontWeight: '400'
    lineHeight: 20px
  button-text:
    fontFamily: SF Pro Text
    fontSize: 17px
    fontWeight: '500'
    lineHeight: 24px
  numeric-label:
    fontFamily: SF Pro Rounded
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 18px
    letterSpacing: 0.02em
  headline-lg-mobile:
    fontFamily: SF Pro Display
    fontSize: 22px
    fontWeight: '700'
    lineHeight: 28px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  margin-main: 20px
  gutter-grid: 12px
  thumb-hotzone: 44px
  shutter-size: 70px
  pose-thumbnail: 80px
---

## Brand & Style

The design system is built around the "EasyBeauty" narrative: a warm, encouraging, and approachable companion that transforms the anxiety of photography into a seamless, guided experience. The target audience includes casual photographers and partners who value simplicity and confidence-building tools.

The design style is **Corporate / Modern** with a strong **Tactile** influence. It prioritizes high-quality white space and soft, organic shapes to create a friendly atmosphere, while maintaining the functional precision required for a camera utility. The interface is optimized for **thumb-driven, one-handed interaction**, ensuring that all critical touch targets are within the natural arc of the lower third of the screen.

## Colors

The palette is centered on **Coral Pink**, a warm and inviting hue that differentiates the product from technical, "pro-black" camera apps. 

- **Primary & Secondary:** Used for the main action button (shutter) and active states. The gradient from `#FFB4A2` to `#FF8A7A` provides a subtle depth that makes buttons feel physically pressable.
- **Neutral:** The background uses a "Warm White" (`#FFFAF8`) to reduce eye strain and maintain the friendly brand personality compared to clinical pure white.
- **Tertiary:** Used exclusively for the camera viewfinder area to provide maximum contrast for the real-time image and pose overlays.
- **Pose Lines:** Defined as semi-transparent white with a soft outer glow to ensure visibility across diverse backgrounds (e.g., bright beaches or dark interiors) without obscuring the subject's face.

## Typography

This design system utilizes the SF Pro family to ensure a native feel on iOS while providing high legibility across all platforms. 

- **SF Pro Display** is reserved for high-level headings and titles to provide a modern, structural feel.
- **SF Pro Text** is used for all functional UI elements, body copy, and primary button labels, prioritized for its optical legibility at standard sizes.
- **SF Pro Rounded** is used for numeric values, zoom levels (1x, 2x), and counters to reinforce the "friendly and soft" brand narrative.

On mobile devices, headlines scale down slightly to preserve screen real estate for the viewfinder. Line heights are generous to prevent visual clutter in a fast-paced shooting environment.

## Layout & Spacing

The layout follows a **Fixed Grid** model within the interaction zones, but allows the camera viewfinder to occupy the maximum available space.

- **Interaction Zone:** The bottom 40% of the screen is the "Primary Action Area," containing the pose thumbnails, shutter button, and filter controls. This area is designed for one-handed operation.
- **Safe Margins:** A standard 20px side margin is maintained for all UI overlays. 
- **Thumb Ergonomics:** Interactive elements like zoom toggles and filter chips are spaced with a minimum 44px hit target (hotzone) to accommodate thumb movement.
- **Breakpoints:** On tablets, the interaction zone may shift to a side-bar format to accommodate larger viewports, but for mobile, it remains a bottom-aligned stack.

## Elevation & Depth

This design system uses **Tonal Layers** combined with **Glassmorphism** to create a sense of hierarchy without feeling heavy.

- **Floating Panels:** The filter and beauty adjustment panels use a semi-transparent Warm White (`overlay-bg`) with a high-intensity backdrop blur. This allows the user to still feel connected to the camera preview while making adjustments.
- **Depth Layers:**
    1. **Layer 0 (Base):** The Viewfinder (Dark Tertiary).
    2. **Layer 1 (Guidance):** Pose Lines (Translucent Overlay).
    3. **Layer 2 (Interaction):** Control buttons and thumbnails (Opaque or Glass-morphic).
- **Shadows:** Avoid heavy black shadows. Instead, use soft, low-opacity "Ambient Shadows" that take on the tint of the coral pink primary color to maintain the warm aesthetic.

## Shapes

The shape language is consistently **Rounded**. 

- **Pose Thumbnails:** Use a `rounded-lg` (16px/1rem) corner radius to feel like a modern gallery card.
- **Primary Shutter:** A perfect circle to emphasize its role as the central action.
- **Selection Indicators:** Use pill shapes or rounded rectangles to clearly highlight the active pose or filter.
- **Pose Outlines:** These follow a "Marker Style," featuring organic, slightly imperfect paths that mimic a hand-drawn guide, making the posing process feel less rigid and more artistic.

## Components

### Shutter Button
A circular, 70pt button featuring a primary gradient (`#FFB4A2` to `#FF8A7A`). It should have a subtle haptic response on press and a slight scale-down animation to feel tactile.

### Pose Thumbnails
Rounded cards with a light grey border (`#EEEEEE`). When selected, the card scales by 1.05x and gains a 2pt coral pink border.

### Filter & Beauty Sliders
- **Sliders:** Vertical or horizontal tracks using a soft coral line. The handle is a larger, tactile circle.
- **Filter Chips:** Circular or rounded square previews of the filter effect, arranged in a horizontal scrollable list.

### Marker Pose Outlines
These are the core guidance elements.
- **Stroke:** 3-4pt width.
- **Style:** Semi-transparent white (`rgba(255,255,255,0.55)`).
- **Effect:** A 1px soft outer glow (`rgba(255,255,255,0.20)`) to ensure separation from the camera background.
- **Interaction:** These remain static in size regardless of camera zoom to maintain the framing guide.

### Zoom Toggles (1x / 2x / 3x)
Grouped text buttons using SF Pro Rounded. The active state is indicated by a soft, warm-white pill background or a coral text color change.