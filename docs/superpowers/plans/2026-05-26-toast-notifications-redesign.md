# Toast/Flash Notifications Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the dated Foundation-callout flash messages with modern, accessible, mobile-safe toasts that auto-dismiss (success/notice/info) or persist (warning/alert/error), and fix the horizontal-overflow bug on mobile.

**Architecture:** Server keeps rendering flash messages, but the custom partial emits a single `.toast-stack` wrapper with per-toast icon + inline text. A new global `_toasts.scss` (imported by `application.scss`, so it loads in every context that shows flash — public, admin, management, devise) holds the component styling. `flash_messages.js` is rewritten for auto-dismiss, pause-on-hover, manual/`Esc` close, and screen-reader announcement without stealing focus. Entrance/exit use only `transform`/`opacity` (no off-screen slide), eliminating the mobile widening.

**Tech Stack:** Ruby on Rails (ERB partials), Sass (Foundation 6), jQuery (jquery-ujs + Turbolinks), Font Awesome 4 icons, RSpec + Capybara (headless Chrome) system specs.

**Spec:** `docs/superpowers/specs/2026-05-26-toast-notifications-redesign-design.md`

---

## Architecture deviation from spec (intentional)

The spec proposed putting styles in `custom_new_design/_toasts.scss`. That file only loads on the public site (`custom_new_design.scss` is linked only in custom layouts), which would leave the new markup **unstyled in admin/management/devise**. Therefore:

- Component styling goes in a **new top-level** `app/assets/stylesheets/_toasts.scss`, imported by `application.scss` (loaded in all contexts).
- Only the **public header offset** (position `top`) stays in `custom_new_design/_base.scss`, scoped under `.custom-new-design`.

The spec's intent (consolidated styling, no regression) is preserved.

## File structure

| File | Action | Responsibility |
|---|---|---|
| `spec/system/flash_messages_spec.rb` | Create | System spec: toast markup contract + close behaviour |
| `app/views/custom/layouts/_flash.html.erb` | Rewrite | `.toast-stack` markup, per-type icon, inline text, SR live regions |
| `app/assets/javascripts/custom/flash_messages.js` | Rewrite | Announce, auto-dismiss, pause, close, `Esc`; no focus steal |
| `app/assets/stylesheets/_toasts.scss` | Create | Toast component look + animation (global) |
| `app/assets/stylesheets/application.scss` | Modify (after `@import "layout"`) | `@import "toasts";` |
| `app/assets/stylesheets/layout.scss` | Modify (`:1166-1199`) | Remove `.callout-slide`, `@keyframes slide`, `.notice-container` |
| `app/assets/stylesheets/custom_new_design/_base.scss` | Modify (`:49-90`) | Rename `.notice-container` → `.toast-stack`, mobile insets 12px |
| `app/assets/stylesheets/custom/shared_v2.scss` | Modify (`:5-11`) | Remove dead `.notice-text` rule |

## Preserved contract (do NOT break)

Active spec `spec/system/users_auth_spec.rb:107` does `within("#notice") { click_button "Close" }` and asserts visible flash text. The redesign MUST keep:
- per-toast `id="<flash_key>"` (e.g. `#notice`, `#alert`),
- a `<button>` with accessible name from `t("application.close")` ("Close"),
- the message text rendered **visibly** (now inline, so it no longer depends on JS).

---

## Task 1: Failing system spec for the new toast contract

**Files:**
- Create: `spec/system/flash_messages_spec.rb`

- [ ] **Step 1: Write the failing spec**

```ruby
require "rails_helper"

describe "Flash messages (toasts)" do
  scenario "success flash renders an auto-dismissing toast with icon and inline text" do
    user = create(:user)

    visit "/"
    click_link "Sign in"
    fill_in "Email or username", with: user.email
    fill_in "Password", with: user.password
    click_button "Enter"

    expect(page).to have_css("#notice.toast.toast--success[data-autodismiss='true']")

    within("#notice") do
      expect(page).to have_content("signed in successfully")
      expect(page).to have_css(".toast__icon .fa-check-circle")
    end
  end

  scenario "the close button removes the toast" do
    user = create(:user)

    visit "/"
    click_link "Sign in"
    fill_in "Email or username", with: user.email
    fill_in "Password", with: user.password
    click_button "Enter"

    expect(page).to have_css("#notice.toast")
    within("#notice") { click_button "Close" }
    expect(page).not_to have_css("#notice.toast")
  end

  scenario "error flash renders a persistent alert toast" do
    visit "/"
    click_link "Sign in"
    fill_in "Email or username", with: "nobody@example.com"
    fill_in "Password", with: "wrongpassword123"
    click_button "Enter"

    expect(page).to have_css("#alert.toast.toast--alert[data-autodismiss='false']")
    within("#alert") do
      expect(page).to have_css(".toast__icon .fa-exclamation-circle")
    end
  end
end
```

- [ ] **Step 2: Run the spec, expect failure**

Run: `bin/rspec spec/system/flash_messages_spec.rb`
Expected: FAIL — current markup has no `.toast`/`.toast-stack`/`.toast__icon`; selectors not found.

- [ ] **Step 3: Commit the failing spec**

```bash
git add spec/system/flash_messages_spec.rb
git commit -m "test: add system spec for redesigned flash toasts"
```

---

## Task 2: Rewrite the flash partial markup

**Files:**
- Modify: `app/views/custom/layouts/_flash.html.erb` (full rewrite)

- [ ] **Step 1: Replace the partial contents**

```erb
<% flash.delete("timedout") %>
<%
  toast_types = {
    "success" => { group: "success", icon: "fa-check-circle",         autodismiss: true,  live: "polite" },
    "notice"  => { group: "success", icon: "fa-check-circle",         autodismiss: true,  live: "polite" },
    "info"    => { group: "info",    icon: "fa-info-circle",          autodismiss: true,  live: "polite" },
    "warning" => { group: "warning", icon: "fa-exclamation-triangle", autodismiss: false, live: "assertive" },
    "alert"   => { group: "alert",   icon: "fa-exclamation-circle",   autodismiss: false, live: "assertive" },
    "error"   => { group: "alert",   icon: "fa-exclamation-circle",   autodismiss: false, live: "assertive" }
  }
  active_flashes = flash.select { |key, _| toast_types.key?(key.to_s) }
%>
<% if active_flashes.any? %>
  <div class="toast-stack js-toast-stack">
    <div class="show-for-sr js-flash-live-region" aria-live="polite" aria-atomic="true"></div>
    <div class="show-for-sr js-flash-alert-region" role="alert" aria-atomic="true"></div>

    <% active_flashes.each do |flash_key, flash_message| %>
      <% type = toast_types[flash_key.to_s] %>
      <div
        id="<%= flash_key %>"
        class="toast toast--<%= type[:group] %> js-flash-message"
        data-flash-type="<%= flash_key %>"
        data-autodismiss="<%= type[:autodismiss] %>"
        data-live="<%= type[:live] %>"
      >
        <span class="toast__icon" aria-hidden="true">
          <i class="fa <%= type[:icon] %>"></i>
        </span>
        <div class="toast__text"><%= sanitize(flash_message) %></div>
        <button
          class="toast__close js-toast-close"
          type="button"
          aria-label="<%= t("application.close") %>"
        >
          <span aria-hidden="true">&times;</span>
        </button>
      </div>
    <% end %>
  </div>
<% end %>
```

- [ ] **Step 2: Run the spec**

Run: `bin/rspec spec/system/flash_messages_spec.rb`
Expected: scenarios 1 and 3 PASS (markup/icon/data attrs present, text inline). Scenario 2 (close removes toast) still FAILS — close is handled by JS (next task).

- [ ] **Step 3: Commit**

```bash
git add app/views/custom/layouts/_flash.html.erb
git commit -m "feat: render flash messages as toast-stack markup with type icons"
```

---

## Task 3: Rewrite the flash JavaScript

**Files:**
- Modify: `app/assets/javascripts/custom/flash_messages.js` (full rewrite)

- [ ] **Step 1: Replace the file contents**

```javascript
(function() {
  "use strict";

  App.FlashMessages = {
    ANNOUNCE_DELAY: 100,
    AUTO_DISMISS_MS: 5000,
    EXIT_MS: 200,

    initialize: function() {
      var $toasts = $(".js-flash-message");
      if (!$toasts.length) return;

      this.announce($toasts);
      this.bindToasts($toasts);
    },

    // Mirror toast text into a visually-hidden live region so screen readers
    // announce it without the toast stealing focus.
    announce: function($toasts) {
      setTimeout(function() {
        var $polite = $(".js-flash-live-region");
        var $assertive = $(".js-flash-alert-region");

        $toasts.each(function() {
          var $toast = $(this);
          var text = $.trim($toast.find(".toast__text").text());
          var $region = $toast.data("live") === "assertive" ? $assertive : $polite;
          $region.append($("<div></div>").text(text));
        });
      }, App.FlashMessages.ANNOUNCE_DELAY);
    },

    bindToasts: function($toasts) {
      var self = this;

      $toasts.each(function() {
        var $toast = $(this);

        $toast.on("click", ".js-toast-close", function() {
          self.dismiss($toast);
        });

        $toast.on("keydown", function(event) {
          if (event.key === "Escape" || event.keyCode === 27) {
            self.dismiss($toast);
          }
        });

        if ($toast.data("autodismiss") === true) {
          self.scheduleDismiss($toast);
          $toast.on("mouseenter focusin", function() {
            self.cancelDismiss($toast);
          });
          $toast.on("mouseleave focusout", function() {
            self.scheduleDismiss($toast);
          });
        }
      });
    },

    scheduleDismiss: function($toast) {
      var self = this;
      this.cancelDismiss($toast);
      var timer = setTimeout(function() {
        self.dismiss($toast);
      }, this.AUTO_DISMISS_MS);
      $toast.data("dismissTimer", timer);
    },

    cancelDismiss: function($toast) {
      var timer = $toast.data("dismissTimer");
      if (timer) {
        clearTimeout(timer);
        $toast.removeData("dismissTimer");
      }
    },

    dismiss: function($toast) {
      this.cancelDismiss($toast);
      if ($toast.hasClass("toast--leaving")) return;

      $toast.addClass("toast--leaving");
      setTimeout(function() {
        $toast.remove();
      }, this.EXIT_MS);
    }
  };
}).call(this);
```

- [ ] **Step 2: Run the spec**

Run: `bin/rspec spec/system/flash_messages_spec.rb`
Expected: all three scenarios PASS (close button now removes the toast).

- [ ] **Step 3: Commit**

```bash
git add app/assets/javascripts/custom/flash_messages.js
git commit -m "feat: auto-dismiss, pause-on-hover and accessible announce for flash toasts"
```

---

## Task 4: Create the toast component stylesheet

**Files:**
- Create: `app/assets/stylesheets/_toasts.scss`
- Modify: `app/assets/stylesheets/application.scss` (add import after `@import "layout";`)
- Modify: `app/assets/stylesheets/layout.scss` (remove `:1166-1199`)

- [ ] **Step 1: Create `_toasts.scss`**

```scss
// Toast / flash notifications
// ---------------------------
// Loaded globally via application.scss (public, admin, management, devise).
// Public header offset lives in custom_new_design/_base.scss.

.toast-stack {
  position: fixed;
  top: 1rem;
  right: 1rem;
  z-index: 1000;
  display: flex;
  flex-direction: column;
  gap: 12px;
  width: 380px;
  max-width: calc(100% - 2rem);
  pointer-events: none; // clicks pass through gaps; toasts re-enable below

  @media (max-width: 39.9375em) { // < 640px
    top: calc(0.75rem + env(safe-area-inset-top, 0px));
    left: 12px;
    right: 12px;
    width: auto;
    max-width: none;
  }
}

.toast {
  pointer-events: auto;
  display: flex;
  align-items: flex-start;
  gap: 12px;
  padding: 14px 16px;
  background: #ffffff;
  border-radius: 8px;
  border-left: 4px solid #64748b;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.12);
  color: #0f172a;
  font-family: "Source Sans 3", "Asap", sans-serif;
  font-size: 16px;
  line-height: 1.45;
  animation: toast-in 220ms ease-out both;

  &.toast--leaving {
    animation: toast-out 150ms ease-in both;
  }
}

.toast__icon {
  flex: 0 0 auto;
  font-size: 20px;
  line-height: 1.45;
  color: #64748b;

  .fa { display: block; }
}

.toast__text {
  flex: 1 1 auto;
  min-width: 0;
  overflow-wrap: anywhere;

  a {
    color: inherit;
    font-weight: 600;
    text-decoration: underline;
  }
}

.toast__close {
  flex: 0 0 auto;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 44px;
  height: 44px;
  margin: -10px -8px -10px 0; // 44px hit area without inflating the row height
  padding: 0;
  border: 0;
  background: transparent;
  color: #64748b;
  font-size: 28px;
  line-height: 1;
  cursor: pointer;

  &:hover { color: #0f172a; }

  &:focus-visible {
    outline: 2px solid #0369a1;
    outline-offset: 2px;
    border-radius: 6px;
  }
}

.toast--success {
  border-left-color: #16a34a;
  .toast__icon { color: #16a34a; }
}

.toast--info {
  border-left-color: #0369a1;
  .toast__icon { color: #0369a1; }
}

.toast--warning {
  border-left-color: #b45309;
  .toast__icon { color: #b45309; }
}

.toast--alert {
  border-left-color: #dc2626;
  .toast__icon { color: #dc2626; }
}

@keyframes toast-in {
  from { opacity: 0; transform: translateY(-12px); }
  to   { opacity: 1; transform: translateY(0); }
}

@keyframes toast-out {
  from { opacity: 1; transform: translateY(0); }
  to   { opacity: 0; transform: translateY(-8px); }
}

@keyframes toast-fade-in {
  from { opacity: 0; }
  to   { opacity: 1; }
}

@keyframes toast-fade-out {
  from { opacity: 1; }
  to   { opacity: 0; }
}

@media (prefers-reduced-motion: reduce) {
  .toast            { animation: toast-fade-in 120ms ease both; }
  .toast.toast--leaving { animation: toast-fade-out 120ms ease both; }
}
```

- [ ] **Step 2: Import it in `application.scss`**

Find the line `@import "layout";` and add the toasts import directly below it:

```scss
@import "layout";
@import "toasts";
@import "participation";
```

- [ ] **Step 3: Remove the obsolete rules from `layout.scss`**

Delete this block (currently around `layout.scss:1166-1199`) — the `.callout-slide`, `@keyframes slide`, and `.notice-container` rules:

```scss
.callout-slide {
  animation-duration: 1s;
  animation-fill-mode: both;
  animation-name: slide;
}

@keyframes slide {
  from {
    transform: translate3d(100%, 0, 0);
    visibility: visible;
  }

  to {
    transform: translate3d(0, 0, 0);
  }
}

.notice-container {
  min-width: $line-height * 12;
  right: 24px;
  top: 24px;

  @include breakpoint(medium) {
    position: absolute;
  }

  .notice {
    height: $line-height * 4;

    .notice-text {
      width: 95%;
    }
  }
}
```

Leave the `.callout { ... }` colour rules that follow (still used by other components). Keep the `// 07. Callout` comment header.

- [ ] **Step 4: Verify the spec still passes and assets compile**

Run: `bin/rspec spec/system/flash_messages_spec.rb`
Expected: all three scenarios PASS (system spec precompiles assets; a Sass error would fail the run).

- [ ] **Step 5: Commit**

```bash
git add app/assets/stylesheets/_toasts.scss app/assets/stylesheets/application.scss app/assets/stylesheets/layout.scss
git commit -m "feat: add modern toast component styles and remove old callout-slide rules"
```

---

## Task 5: Public positioning override + remove dead rule

**Files:**
- Modify: `app/assets/stylesheets/custom_new_design/_base.scss` (`:49-90`)
- Modify: `app/assets/stylesheets/custom/shared_v2.scss` (`:5-11`)

- [ ] **Step 1: Rename `.notice-container` → `.toast-stack` in `_base.scss`**

Replace the `.notice-container` rule (and its admin-topbar/fixed-tabs variants) so the public header offset applies to the new stack. The `.custom-fixed-tabs--content` rules in the same block stay unchanged.

Replace this:

```scss
  .notice-container {
    z-index: 100;
    top: 110px;
    right: 20px;
    position: absolute;

    @media(max-width: $mobile-viewport-start) {
      right: 10px;
      left: 10px;
    }
  }

  &:has(.projekt-page--admin-topbar)  {
    .notice-container {
      top: 110px + $admin-topbar-height;
    }
```

with this:

```scss
  .toast-stack {
    top: 110px;
    right: 20px;

    @media(max-width: $mobile-viewport-start) {
      right: 12px;
      left: 12px;
    }
  }

  &:has(.projekt-page--admin-topbar)  {
    .toast-stack {
      top: 110px + $admin-topbar-height;
    }
```

Then, further down in the same block, replace the remaining two `.notice-container` references:

```scss
    @media (max-width: $small-tablet-viewport-start) {
      .notice-container {
        top: 110px + $admin-topbar-height + 8px;
      }
```
→
```scss
    @media (max-width: $small-tablet-viewport-start) {
      .toast-stack {
        top: 110px + $admin-topbar-height + 8px;
      }
```

and:

```scss
  .wrapper.has-custom-fixed-tabs .notice-container {
    @media screen and (max-width: $small-tablet-viewport-start) {
      top: 170px;
    }
  }
```
→
```scss
  .wrapper.has-custom-fixed-tabs .toast-stack {
    @media screen and (max-width: $small-tablet-viewport-start) {
      top: 170px;
    }
  }
```

(Do not touch the `.custom-fixed-tabs--content` lines.)

- [ ] **Step 2: Remove the dead `.notice-text` rule in `shared_v2.scss`**

Delete this block (around `shared_v2.scss:5-11`):

```scss
.notice-text {
  margin-right: 30px;

  &:focus-visible {
    outline: none;
  }
}
```

Keep the `.fa-location-dot` rule above it and the `.callout` / `.notice-container .notice` rules below for now (verified separately in Task 6).

- [ ] **Step 3: Run the spec**

Run: `bin/rspec spec/system/flash_messages_spec.rb`
Expected: all three scenarios PASS.

- [ ] **Step 4: Commit**

```bash
git add app/assets/stylesheets/custom_new_design/_base.scss app/assets/stylesheets/custom/shared_v2.scss
git commit -m "refactor: position toast-stack via new class and drop dead notice-text rule"
```

---

## Task 6: Regression + manual verification

**Files:** none (verification only)

- [ ] **Step 1: Run the existing flash regression spec**

Run: `bin/rspec spec/system/users_auth_spec.rb spec/system/sessions_spec.rb spec/system/flash_messages_spec.rb`
Expected: PASS — `within("#notice") { click_button "Close" }` and all `have_content` flash assertions still hold.

- [ ] **Step 2: Manual responsive check (public site)**

Start the server with `./bin/dev`. Trigger a flash (log in). At browser widths **375px** and **640px**:
- No horizontal scrollbar / page does not widen.
- Toast docks to the top, spans the width minus 12px margins.
- Entrance fades/slides down (no slide-in from the right edge).

- [ ] **Step 3: Manual accessibility check**

- Keyboard: `Tab` reaches the `×` button (visible focus ring); `Enter`/`Space` closes; `Esc` while focused inside the toast closes it.
- Toggle OS "reduce motion": entrance/exit is a plain fade, no transform.
- Screen reader (or inspect): success message lands in the polite region, an alert/error in the `role="alert"` region; focus is NOT moved to the toast on load.
- Each type shows its icon AND colour (meaning never by colour alone).

- [ ] **Step 4: Cross-context check (no regression)**

Confirm a flash renders correctly (visible text, working close button, styled card) in:
- Admin (e.g. save a setting), Management, and Devise (e.g. failed login) pages.
Because `_toasts.scss` is global and the text is now inline, these must not show blank or unstyled toasts.

- [ ] **Step 5: Confirm `.callout` is unaffected**

Run: `grep -rn "notice-container\|callout-slide\|js-flash" app/assets app/views | grep -v "custom/layouts/_flash"`
Expected: no remaining references to `notice-container`/`callout-slide` in active code (other than intentional). `.callout` colour rules in `layout.scss` remain for other components.

- [ ] **Step 6: Final commit (if any cleanup was needed)**

```bash
git add -A
git commit -m "chore: finalize toast notification redesign"
```

---

## Self-review notes

- **Spec coverage:** look/colours/icons (Task 2+4), auto-dismiss vs persist (Task 2 data attr + Task 3 timer), stacking (`.toast-stack` flex column, Task 4), mobile no-overflow (translateY animation + insets, Task 4/5), a11y live regions + no focus steal + keyboard + reduced-motion (Task 3+4, verified Task 6), robustness/inline text (Task 2), cleanup (Task 4/5), cross-context (Task 6) — all mapped.
- **Type consistency:** partial emits `data-autodismiss` / `data-live` / `.toast__text` / `.js-toast-close` / `.js-flash-message`; JS reads exactly those. CSS targets `.toast`, `.toast--success|info|warning|alert`, `.toast__icon|text|close`, `.toast--leaving` — all produced by the partial.
- **No placeholders:** every code step contains full content.
