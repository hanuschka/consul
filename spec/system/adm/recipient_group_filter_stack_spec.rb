require "rails_helper"

# NOTE: This spec documents the intended browser-level behavior of the
# recipient group filter stack UI, but cannot be executed in the current
# dev environment due to multiple infrastructure gaps:
#
# 1. JS test (multi-step filter chain):
#    - Requires Chrome binary (not installed) and a working headless_chrome
#      Capybara driver. The Selenium WebDriver gem version installed is
#      incompatible with rails_helper.rb (Selenium::WebDriver::Remote::
#      Capabilities.chrome no longer exists in newer Selenium versions).
#
# 2. Static test (no-operator check):
#    - Blocked by the same Selenium API issue in the system spec before-hooks
#      (spec_helper.rb line 224: `visit root_path` triggers the broken driver).
#    - Additionally blocked by SassC asset compilation OOM ("Not enough space")
#      when SCSS bundles are compiled on demand.
#
# Controller-level coverage for the filter stack is provided by the Task 22
# request spec (spec/requests/adm/recipient_group_filters_spec.rb).
#
# TODO (T28) — to re-enable, fix:
#   a) Update rails_helper.rb Capybara driver registration for newer Selenium API
#      (use Selenium::WebDriver::Options.chrome instead of Capabilities.chrome)
#   b) Install a Chrome/Chromium binary in the dev environment
#   c) Pre-compile SCSS assets or raise sassc memory limits for test env

RSpec.describe "Recipient group filter stack" do
  # JS happy-path: build a 3-step filter chain and verify the count.
  #
  # Full scenario (to implement when infra works):
  #   - Create 5 newsletter users in a geozone + 1 admin user with newsletter
  #   - Visit new_adm_recipient_group_path, fill name, submit
  #   - On edit page: first filter (newsletter_subscribers/include) is auto-added
  #   - Click "Add filter" → second card → change to geozone/intersect
  #   - Counter shows "Total: 5 recipients"
  it "lets an admin build a filter chain: subscribers → intersect geozone → exclude admins", :js do
    skip "JS-system test — needs selenium/chromedriver infrastructure (see file header)"
  end

  # Static page check: a group with no filters must not render any operator <select>.
  # Rationale: when there are no filters, no filter form is rendered at all,
  # so no operator dropdown can be present for an "invalid" first-position operator.
  it "blocks invalid operator on first filter" do
    skip "Blocked by environment infrastructure issues — see file header for details"
  end
end
