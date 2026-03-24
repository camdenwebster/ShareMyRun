## SwiftUI & iOS Best Practices

**IMPORTANT**: Follow these guidelines to avoid deprecated APIs and common mistakes. Use modern SwiftUI patterns.

### View Modifiers (Always Use Modern APIs)
- ✅ `.foregroundStyle()` ❌ `.foregroundColor()` - Supports gradients and advanced styling
- ✅ `.clipShape(.rect(cornerRadius:))` ❌ `.cornerRadius()` - Supports uneven rounded rectangles
- ✅ `.onChange(of: value) { oldValue, newValue in }` or `.onChange(of: value) { }` ❌ Single-parameter variant is deprecated
- ✅ `.fontWeight()` use sparingly - Prefer `.bold()` for semantic weights, or Dynamic Type scaling

### Layout & Sizing (Avoid GeometryReader Overuse)
- ❌ `GeometryReader` - **Massively overused by LLMs**, often unnecessarily
- ❌ Fixed `.frame(width:height:)` sizes - Breaks adaptive layouts and accessibility
- ✅ `.visualEffect { content, geometry in }` - Modern alternative for geometry-aware effects
- ✅ `.containerRelativeFrame()` - Size views relative to their container
- ✅ Let SwiftUI handle layout - Use flexible frames, spacing, padding instead
- **Cardinal Sin**: `GeometryReader` + fixed frames = rigid, non-adaptive layouts

### Navigation & Interaction
- ✅ `NavigationStack` ❌ `NavigationView` - Modern navigation API
- ✅ `navigationDestination(for:)` ❌ Inline destination NavigationLink in lists
- ✅ `Tab` API ❌ `.tabItem()` - Type-safe selection, iOS 26 search tab support
- ✅ `Button("Label", systemImage: "icon") { }` ❌ `Label` inside Button or image-only buttons
- ✅ `Button` with proper labels ❌ `onTapGesture()` - Better for VoiceOver and eye tracking
  - Exception: Use `onTapGesture()` only when you need tap location or count

### State Management & Observation
- ✅ `@Observable` macro ❌ `ObservableObject` - Simpler, faster, better view invalidation
- ✅ Separate SwiftUI views ❌ Computed properties for view composition
  - **Critical**: With `@Observable`, computed properties don't benefit from intelligent view invalidation
  - Split complex views into separate structs for better performance