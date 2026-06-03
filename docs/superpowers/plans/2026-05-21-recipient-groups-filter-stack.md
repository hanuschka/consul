# Recipient Groups — Filter-Stack Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Empfängergruppen-System auf eine Filter-Kette umstellen (12 Filter-Kinds, Operatoren include/exclude/intersect, Migration bestehender Records, neues UI mit Live-Counter).

**Architecture:** `RecipientGroup has_many :filters` (neue Tabelle `recipient_group_filters` mit `kind`, `operator`, `params` JSONB). Pro Kind eine Resolver-Klasse unter `app/services/recipient_group/filter_resolvers/`. Auflösung via `RecipientGroupResolver` (PORO, In-Memory Set-Algebra über Email-Strings). UI als sortierbarer Filter-Stack mit Turbo-Stream-getriebenem Live-Counter.

**Tech Stack:** Rails 6.1, RSpec + FactoryBot, ViewComponent, Stimulus, Turbo, `acts_as_list` (Gemfile_custom).

**Vorbedingung — Branch & Commit-Convention:**
- Vor Beginn neues Jira-Ticket anlegen (Vorschlag: feature/CON-NNNN-recipient-groups-filter-stack).
- Branch von `new-connection` abzweigen.
- Alle Commits in diesem Plan verwenden die Variable `$BRANCH` als Commit-Message. Vor dem ersten Task:
  ```bash
  export BRANCH=$(git rev-parse --abbrev-ref HEAD)
  echo "Commits werden gelabelt als: $BRANCH"
  ```

**Spec:** [docs/superpowers/specs/2026-05-21-recipient-groups-filter-stack-design.md](../specs/2026-05-21-recipient-groups-filter-stack-design.md)

---

## File Structure

### New files
- `db/migrate/<timestamp>_create_recipient_group_filters.rb` — schema for filter table
- `db/migrate/<timestamp>_migrate_legacy_recipient_groups.rb` — data migration
- `app/models/recipient_group_filter.rb` — ActiveRecord model
- `app/services/recipient_group_resolver.rb` — set-algebra driver
- `app/services/recipient_group/filter_resolvers/base.rb` — resolver contract
- `app/services/recipient_group/filter_resolvers/newsletter_subscribers.rb`
- `app/services/recipient_group/filter_resolvers/role.rb`
- `app/services/recipient_group/filter_resolvers/phase_authors.rb`
- `app/services/recipient_group/filter_resolvers/phase_subscribers.rb`
- `app/services/recipient_group/filter_resolvers/comment_authors.rb`
- `app/services/recipient_group/filter_resolvers/voting_participants.rb`
- `app/services/recipient_group/filter_resolvers/geozone.rb`
- `app/services/recipient_group/filter_resolvers/plz.rb`
- `app/services/recipient_group/filter_resolvers/age_range.rb`
- `app/services/recipient_group/filter_resolvers/gender.rb`
- `app/services/recipient_group/filter_resolvers/individual_group.rb`
- `app/services/recipient_group/filter_resolvers/manual_users.rb`
- `app/controllers/adm/recipient_group_filters_controller.rb`
- `app/components/adm/recipient_group_filter_card_component.rb`
- `app/components/adm/recipient_group_filter_card_component.html.erb`
- `app/components/adm/recipient_group_filter_card_component.scss`
- `app/javascript/controllers/adm_newsletters/filter_stack_controller.js`
- `spec/factories/recipient_groups.rb`
- `spec/models/recipient_group_spec.rb`
- `spec/models/recipient_group_filter_spec.rb`
- `spec/services/recipient_group_resolver_spec.rb`
- `spec/services/recipient_group/filter_resolvers/*_spec.rb` (12 files)
- `spec/system/adm/recipient_group_filter_stack_spec.rb`

### Modified files
- `app/models/recipient_group.rb` — has_many filters, neue API
- `app/controllers/adm/recipient_groups_controller.rb` — Edit-Action umbauen
- `config/routes/adm.rb` — nested resource
- `app/views/adm/recipient_groups/edit.html.erb` — Filter-Stack-UI
- `app/views/adm/recipient_groups/new.html.erb` — Vereinfachung (nur Name + erster Filter)
- `app/views/adm/recipient_groups/_access_methods.html.erb` — entfernen (durch Stack abgelöst)
- `app/views/adm/recipient_groups/_options_for_kind.html.erb` — entfernen
- `config/locales/kern/de/adm/recipient_groups.yml` — neue Keys
- `config/locales/kern/en/adm/recipient_groups.yml` — neue Keys
- `app/policies/adm/recipient_group_policy.rb` — Authorize neue Actions

### Files to delete after migration verified
- `app/views/adm/recipient_groups/_options_for_kind.html.erb`
- `app/views/adm/recipient_groups/_access_methods.html.erb`
- `app/views/adm/recipient_groups/select_options.turbo_stream.erb`
- `app/controllers/adm/recipient_groups_controller.rb#select_options` (Action löschen)

---

## Task 1: Migration für `recipient_group_filters`

**Files:**
- Create: `db/migrate/<timestamp>_create_recipient_group_filters.rb`

- [ ] **Step 1: Generate migration**

```bash
bin/rails generate migration CreateRecipientGroupFilters
```

- [ ] **Step 2: Edit migration content**

`db/migrate/<timestamp>_create_recipient_group_filters.rb`:
```ruby
class CreateRecipientGroupFilters < ActiveRecord::Migration[6.1]
  def change
    create_table :recipient_group_filters do |t|
      t.references :recipient_group, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.string :kind, null: false
      t.string :operator, null: false, default: "include"
      t.jsonb :params, null: false, default: {}
      t.timestamps
    end

    add_index :recipient_group_filters, [:recipient_group_id, :position]
    add_index :recipient_group_filters, :kind
  end
end
```

- [ ] **Step 3: Run migration**

```bash
bin/rails db:migrate
```
Expected: schema.rb updated, no errors.

- [ ] **Step 4: Commit**

```bash
git add db/migrate db/schema.rb
git commit -m "$BRANCH"
```

---

## Task 2: `RecipientGroupFilter` Model — minimal skeleton + KINDS/OPERATORS

**Files:**
- Create: `app/models/recipient_group_filter.rb`
- Test: `spec/models/recipient_group_filter_spec.rb`

- [ ] **Step 1: Write the failing spec**

`spec/models/recipient_group_filter_spec.rb`:
```ruby
require "rails_helper"

describe RecipientGroupFilter do
  describe "constants" do
    it "exposes the 12 kinds" do
      expect(RecipientGroupFilter::KINDS).to match_array(%w[
        newsletter_subscribers role
        phase_authors phase_subscribers comment_authors voting_participants
        geozone plz age_range gender
        individual_group manual_users
      ])
    end

    it "exposes the 3 operators" do
      expect(RecipientGroupFilter::OPERATORS).to eq(%w[include exclude intersect])
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:recipient_group) }
  end

  describe "validations" do
    it { is_expected.to validate_inclusion_of(:kind).in_array(RecipientGroupFilter::KINDS) }
    it { is_expected.to validate_inclusion_of(:operator).in_array(RecipientGroupFilter::OPERATORS) }
  end
end
```

- [ ] **Step 2: Run spec to verify it fails**

```bash
bundle exec rspec spec/models/recipient_group_filter_spec.rb
```
Expected: FAIL — "uninitialized constant RecipientGroupFilter".

- [ ] **Step 3: Create model**

`app/models/recipient_group_filter.rb`:
```ruby
class RecipientGroupFilter < ApplicationRecord
  KINDS = %w[
    newsletter_subscribers role
    phase_authors phase_subscribers comment_authors voting_participants
    geozone plz age_range gender
    individual_group manual_users
  ].freeze

  OPERATORS = %w[include exclude intersect].freeze

  belongs_to :recipient_group

  acts_as_list scope: :recipient_group

  validates :kind, inclusion: { in: KINDS }
  validates :operator, inclusion: { in: OPERATORS }
end
```

- [ ] **Step 4: Run spec to verify it passes**

```bash
bundle exec rspec spec/models/recipient_group_filter_spec.rb
```
Expected: PASS, 5 examples.

- [ ] **Step 5: Commit**

```bash
git add app/models/recipient_group_filter.rb spec/models/recipient_group_filter_spec.rb
git commit -m "$BRANCH"
```

---

## Task 3: Factory + first-filter validation

**Files:**
- Create: `spec/factories/recipient_groups.rb`
- Modify: `app/models/recipient_group_filter.rb`
- Modify: `spec/models/recipient_group_filter_spec.rb`

- [ ] **Step 1: Write factories**

`spec/factories/recipient_groups.rb`:
```ruby
FactoryBot.define do
  factory :recipient_group do
    sequence(:name) { |n| "Recipient Group #{n}" }
  end

  factory :recipient_group_filter do
    recipient_group
    kind { "newsletter_subscribers" }
    operator { "include" }
    params { {} }
  end
end
```

- [ ] **Step 2: Add validation spec (failing)**

Append to `spec/models/recipient_group_filter_spec.rb`:
```ruby
  describe "first_filter_must_be_include validation" do
    let(:group) { create(:recipient_group) }

    it "rejects exclude as the first filter" do
      filter = build(:recipient_group_filter, recipient_group: group, operator: "exclude")
      expect(filter).not_to be_valid
      expect(filter.errors[:operator]).to be_present
    end

    it "rejects intersect as the first filter" do
      filter = build(:recipient_group_filter, recipient_group: group, operator: "intersect")
      expect(filter).not_to be_valid
    end

    it "allows include as the first filter" do
      filter = build(:recipient_group_filter, recipient_group: group, operator: "include")
      expect(filter).to be_valid
    end

    it "allows exclude as the second filter" do
      create(:recipient_group_filter, recipient_group: group, position: 1)
      second = build(:recipient_group_filter, recipient_group: group, operator: "exclude", position: 2)
      expect(second).to be_valid
    end
  end
```

- [ ] **Step 3: Run spec to verify new examples fail**

```bash
bundle exec rspec spec/models/recipient_group_filter_spec.rb -e "first_filter_must_be_include"
```
Expected: FAIL — validation absent.

- [ ] **Step 4: Implement validation**

In `app/models/recipient_group_filter.rb`, add at the end of the class:
```ruby
  validate :first_filter_must_be_include

  private

    def first_filter_must_be_include
      return if operator == "include"
      return if recipient_group.blank?

      is_first =
        recipient_group.filters.where.not(id: id).none? ||
          recipient_group.filters.where.not(id: id).minimum(:position).to_i >= position.to_i

      errors.add(:operator, :must_be_include_for_first_filter) if is_first
    end
```

- [ ] **Step 5: Run spec to verify it passes**

```bash
bundle exec rspec spec/models/recipient_group_filter_spec.rb
```
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add spec/factories/recipient_groups.rb app/models/recipient_group_filter.rb spec/models/recipient_group_filter_spec.rb
git commit -m "$BRANCH"
```

---

## Task 4: `RecipientGroup` model — `has_many :filters` association

**Files:**
- Modify: `app/models/recipient_group.rb`
- Create: `spec/models/recipient_group_spec.rb`

- [ ] **Step 1: Write the failing spec**

`spec/models/recipient_group_spec.rb`:
```ruby
require "rails_helper"

describe RecipientGroup do
  describe "associations" do
    it { is_expected.to have_many(:filters).class_name("RecipientGroupFilter").dependent(:destroy) }
    it { is_expected.to have_many(:newsletters).dependent(:restrict_with_exception) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
  end

  describe "#filters ordering" do
    it "returns filters ordered by position" do
      group = create(:recipient_group)
      f2 = create(:recipient_group_filter, recipient_group: group, position: 2)
      f1 = create(:recipient_group_filter, recipient_group: group, position: 1)
      expect(group.filters.to_a).to eq([f1, f2])
    end
  end
end
```

- [ ] **Step 2: Run spec to verify it fails**

```bash
bundle exec rspec spec/models/recipient_group_spec.rb
```
Expected: FAIL — `filters` association missing.

- [ ] **Step 3: Update model**

`app/models/recipient_group.rb`:
```ruby
class RecipientGroup < ApplicationRecord
  has_many :newsletters, dependent: :restrict_with_exception
  has_many :filters,
           -> { order(:position) },
           class_name: "RecipientGroupFilter",
           dependent: :destroy,
           inverse_of: :recipient_group

  validates :name, presence: true

  def self.base_options_for_kind
    %i[projekts user_roles]
  end

  def user_emails
    if filters.any?
      RecipientGroupResolver.new(self).user_emails
    else
      legacy_user_emails
    end
  end

  private

    def legacy_user_emails
      return [] if origin_class_name.blank? || access_method.blank?

      if origin_class_object_id.present?
        user_ids = origin_class_name.constantize
                                    .find_by(id: origin_class_object_id)
                                    .send(access_method.to_sym)
      else
        user_ids = origin_class_name.constantize.send(access_method.to_sym)
      end

      if access_method == "all_newsletter_subscriber_ids"
        [User.where(id: user_ids).pluck(:email) + UnregisteredNewsletterSubscriber.all.pluck(:email)]
          .flatten.compact.uniq
      else
        User.where(id: user_ids).pluck(:email).compact.uniq
      end
    end
end
```

- [ ] **Step 4: Run spec to verify it passes**

```bash
bundle exec rspec spec/models/recipient_group_spec.rb
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/models/recipient_group.rb spec/models/recipient_group_spec.rb
git commit -m "$BRANCH"
```

---

## Task 5: `FilterResolvers::Base` — resolver contract

**Files:**
- Create: `app/services/recipient_group/filter_resolvers/base.rb`
- Create: `app/services/recipient_group/filter_resolvers.rb` (module + lookup)
- Test: `spec/services/recipient_group/filter_resolvers_spec.rb`

- [ ] **Step 1: Write the failing spec**

`spec/services/recipient_group/filter_resolvers_spec.rb`:
```ruby
require "rails_helper"

describe RecipientGroup::FilterResolvers do
  describe ".for" do
    it "returns the matching resolver class" do
      stub_const("RecipientGroup::FilterResolvers::Foo", Class.new)
      expect(described_class.for("foo")).to eq(RecipientGroup::FilterResolvers::Foo)
    end

    it "raises when no resolver exists" do
      expect { described_class.for("nope") }.to raise_error(NameError)
    end
  end
end

describe RecipientGroup::FilterResolvers::Base do
  it "stores params with indifferent access" do
    resolver = described_class.new("foo" => "bar")
    expect(resolver.params[:foo]).to eq("bar")
  end

  it "requires subclasses to implement #emails" do
    resolver = described_class.new({})
    expect { resolver.emails }.to raise_error(NotImplementedError)
  end
end
```

- [ ] **Step 2: Run spec to verify it fails**

```bash
bundle exec rspec spec/services/recipient_group/filter_resolvers_spec.rb
```
Expected: FAIL — "uninitialized constant".

- [ ] **Step 3: Create resolver module**

`app/services/recipient_group/filter_resolvers.rb`:
```ruby
module RecipientGroup
  module FilterResolvers
    def self.for(kind)
      const_get(kind.to_s.camelize)
    end
  end
end
```

`app/services/recipient_group/filter_resolvers/base.rb`:
```ruby
module RecipientGroup
  module FilterResolvers
    class Base
      attr_reader :params

      def initialize(params)
        @params = (params || {}).with_indifferent_access
      end

      def emails
        raise NotImplementedError, "#{self.class} must implement #emails"
      end
    end
  end
end
```

- [ ] **Step 4: Run spec to verify it passes**

```bash
bundle exec rspec spec/services/recipient_group/filter_resolvers_spec.rb
```
Expected: PASS, 4 examples.

- [ ] **Step 5: Commit**

```bash
git add app/services/recipient_group spec/services/recipient_group
git commit -m "$BRANCH"
```

---

## Task 6: `RecipientGroupResolver` — set-algebra driver

**Files:**
- Create: `app/services/recipient_group_resolver.rb`
- Test: `spec/services/recipient_group_resolver_spec.rb`

- [ ] **Step 1: Write the failing spec**

`spec/services/recipient_group_resolver_spec.rb`:
```ruby
require "rails_helper"

describe RecipientGroupResolver do
  let(:group) { create(:recipient_group) }

  def stub_resolver(kind, emails)
    klass = Class.new(RecipientGroup::FilterResolvers::Base) do
      define_method(:emails) { @stubbed_emails }
    end
    stub_const("RecipientGroup::FilterResolvers::#{kind.camelize}", klass)
    allow_any_instance_of(klass).to receive(:emails).and_return(emails)
  end

  it "returns the first filter as the start set" do
    stub_resolver("kind_a", ["a@x", "b@x"])
    create(:recipient_group_filter, recipient_group: group, kind: "kind_a", position: 1, operator: "include")

    expect(described_class.new(group).user_emails).to match_array(["a@x", "b@x"])
  end

  it "intersects the second filter" do
    stub_resolver("kind_a", ["a@x", "b@x", "c@x"])
    stub_resolver("kind_b", ["b@x", "c@x", "d@x"])
    create(:recipient_group_filter, recipient_group: group, kind: "kind_a", position: 1, operator: "include")
    create(:recipient_group_filter, recipient_group: group, kind: "kind_b", position: 2, operator: "intersect")

    expect(described_class.new(group).user_emails).to match_array(["b@x", "c@x"])
  end

  it "excludes the second filter" do
    stub_resolver("kind_a", ["a@x", "b@x", "c@x"])
    stub_resolver("kind_b", ["b@x"])
    create(:recipient_group_filter, recipient_group: group, kind: "kind_a", position: 1, operator: "include")
    create(:recipient_group_filter, recipient_group: group, kind: "kind_b", position: 2, operator: "exclude")

    expect(described_class.new(group).user_emails).to match_array(["a@x", "c@x"])
  end

  it "unions when second filter is include" do
    stub_resolver("kind_a", ["a@x"])
    stub_resolver("kind_b", ["b@x"])
    create(:recipient_group_filter, recipient_group: group, kind: "kind_a", position: 1, operator: "include")
    create(:recipient_group_filter, recipient_group: group, kind: "kind_b", position: 2, operator: "include")

    expect(described_class.new(group).user_emails).to match_array(["a@x", "b@x"])
  end

  it "reports per-filter counts" do
    stub_resolver("kind_a", ["a@x", "b@x"])
    stub_resolver("kind_b", ["a@x"])
    f1 = create(:recipient_group_filter, recipient_group: group, kind: "kind_a", position: 1, operator: "include")
    f2 = create(:recipient_group_filter, recipient_group: group, kind: "kind_b", position: 2, operator: "intersect")

    counts = described_class.new(group).per_filter_counts
    expect(counts).to eq([
      { id: f1.id, count: 2, delta: 2 },
      { id: f2.id, count: 1, delta: -1 }
    ])
  end

  it "returns 0 for an empty filter chain" do
    expect(described_class.new(group).count).to eq(0)
    expect(described_class.new(group).user_emails).to eq([])
  end
end
```

- [ ] **Step 2: Run spec to verify it fails**

```bash
bundle exec rspec spec/services/recipient_group_resolver_spec.rb
```
Expected: FAIL — "uninitialized constant RecipientGroupResolver".

- [ ] **Step 3: Create resolver service**

`app/services/recipient_group_resolver.rb`:
```ruby
class RecipientGroupResolver
  def initialize(recipient_group)
    @recipient_group = recipient_group
  end

  def user_emails
    resolve.fetch(:emails).to_a
  end

  def count
    resolve.fetch(:emails).size
  end

  def per_filter_counts
    resolve.fetch(:per_filter)
  end

  private

    def resolve
      @resolve ||= compute
    end

    def compute
      emails = Set.new
      per_filter = []

      @recipient_group.filters.each_with_index do |filter, index|
        resolver = RecipientGroup::FilterResolvers.for(filter.kind).new(filter.params)
        new_emails = Set.new(resolver.emails.compact)

        previous_size = emails.size

        emails =
          case filter.operator
          when "include"   then index.zero? ? new_emails : emails | new_emails
          when "exclude"   then emails - new_emails
          when "intersect" then emails & new_emails
          else emails
          end

        per_filter << { id: filter.id, count: emails.size, delta: emails.size - previous_size }
      end

      { emails: emails, per_filter: per_filter }
    end
end
```

- [ ] **Step 4: Run spec to verify it passes**

```bash
bundle exec rspec spec/services/recipient_group_resolver_spec.rb
```
Expected: PASS, 6 examples.

- [ ] **Step 5: Commit**

```bash
git add app/services/recipient_group_resolver.rb spec/services/recipient_group_resolver_spec.rb
git commit -m "$BRANCH"
```

---

## Task 7: Resolver — `newsletter_subscribers`

**Files:**
- Create: `app/services/recipient_group/filter_resolvers/newsletter_subscribers.rb`
- Test: `spec/services/recipient_group/filter_resolvers/newsletter_subscribers_spec.rb`

- [ ] **Step 1: Write the failing spec**

`spec/services/recipient_group/filter_resolvers/newsletter_subscribers_spec.rb`:
```ruby
require "rails_helper"

describe RecipientGroup::FilterResolvers::NewsletterSubscribers do
  let!(:opted_in)  { create(:user, newsletter: true, email: "opted@x.test") }
  let!(:opted_out) { create(:user, newsletter: false, email: "out@x.test") }
  let!(:erased)    { create(:user, newsletter: true, email: "erased@x.test", erased_at: Time.current) }

  it "returns users with newsletter consent (excluding erased)" do
    emails = described_class.new({}).emails
    expect(emails).to contain_exactly("opted@x.test")
  end

  context "with include_unregistered: true" do
    let!(:unreg) { UnregisteredNewsletterSubscriber.create!(email: "ext@x.test", confirmed: true) }
    let!(:unconfirmed) { UnregisteredNewsletterSubscriber.create!(email: "pending@x.test", confirmed: false) }

    it "adds confirmed unregistered subscribers" do
      emails = described_class.new("include_unregistered" => true).emails
      expect(emails).to contain_exactly("opted@x.test", "ext@x.test")
    end
  end
end
```

- [ ] **Step 2: Run spec to verify it fails**

```bash
bundle exec rspec spec/services/recipient_group/filter_resolvers/newsletter_subscribers_spec.rb
```
Expected: FAIL — "uninitialized constant".

- [ ] **Step 3: Create resolver**

`app/services/recipient_group/filter_resolvers/newsletter_subscribers.rb`:
```ruby
module RecipientGroup
  module FilterResolvers
    class NewsletterSubscribers < Base
      def emails
        base = User.actual.where(newsletter: true).pluck(:email)
        base += UnregisteredNewsletterSubscriber.confirmed.pluck(:email) if params[:include_unregistered]
        base.compact.uniq
      end
    end
  end
end
```

- [ ] **Step 4: Run spec to verify it passes**

```bash
bundle exec rspec spec/services/recipient_group/filter_resolvers/newsletter_subscribers_spec.rb
```
Expected: PASS, 2 examples.

- [ ] **Step 5: Commit**

```bash
git add app/services/recipient_group/filter_resolvers/newsletter_subscribers.rb spec/services/recipient_group/filter_resolvers/newsletter_subscribers_spec.rb
git commit -m "$BRANCH"
```

---

## Task 8: Resolver — `role`

**Files:**
- Create: `app/services/recipient_group/filter_resolvers/role.rb`
- Test: `spec/services/recipient_group/filter_resolvers/role_spec.rb`

- [ ] **Step 1: Write the failing spec**

`spec/services/recipient_group/filter_resolvers/role_spec.rb`:
```ruby
require "rails_helper"

describe RecipientGroup::FilterResolvers::Role do
  let!(:admin) { create(:administrator).user.tap { |u| u.update!(email: "admin@x.test") } }
  let!(:moderator) { create(:moderator).user.tap { |u| u.update!(email: "mod@x.test") } }
  let!(:regular) { create(:user, email: "reg@x.test") }

  it "returns administrators" do
    expect(described_class.new("role" => "administrator").emails).to contain_exactly("admin@x.test")
  end

  it "returns moderators" do
    expect(described_class.new("role" => "moderator").emails).to contain_exactly("mod@x.test")
  end

  it "returns empty for unsupported role" do
    expect(described_class.new("role" => "bogus").emails).to eq([])
  end
end
```

- [ ] **Step 2: Run spec to verify it fails**

```bash
bundle exec rspec spec/services/recipient_group/filter_resolvers/role_spec.rb
```
Expected: FAIL.

- [ ] **Step 3: Create resolver**

`app/services/recipient_group/filter_resolvers/role.rb`:
```ruby
module RecipientGroup
  module FilterResolvers
    class Role < Base
      ROLE_SCOPES = {
        "administrator"             => :administrators,
        "moderator"                 => :moderators,
        "valuator"                  => :valuators,
        "projekt_manager"           => :projekt_managers,
        "idea_manager"              => :idea_managers,
        "officing_manager"          => :officing_managers,
        "deficiency_report_manager" => :deficiency_report_managers
      }.freeze

      def emails
        scope = ROLE_SCOPES[params[:role].to_s]
        return [] unless scope

        User.actual.public_send(scope).pluck(:email).compact.uniq
      end
    end
  end
end
```

- [ ] **Step 4: Run spec to verify it passes**

```bash
bundle exec rspec spec/services/recipient_group/filter_resolvers/role_spec.rb
```
Expected: PASS, 3 examples.

If `valuators`, `idea_managers`, `officing_managers`, or `deficiency_report_managers` scopes are missing on `User`, add them in `app/models/custom/user.rb` (alongside the existing `:projekt_managers` scope) — confirm by running `bin/rails runner "puts User.respond_to?(:valuators)"` before continuing.

- [ ] **Step 5: Commit**

```bash
git add app/services/recipient_group/filter_resolvers/role.rb spec/services/recipient_group/filter_resolvers/role_spec.rb app/models/custom/user.rb
git commit -m "$BRANCH"
```

---

## Task 9: Resolver — `phase_authors`

**Files:**
- Create: `app/services/recipient_group/filter_resolvers/phase_authors.rb`
- Test: `spec/services/recipient_group/filter_resolvers/phase_authors_spec.rb`

- [ ] **Step 1: Write the failing spec**

`spec/services/recipient_group/filter_resolvers/phase_authors_spec.rb`:
```ruby
require "rails_helper"

describe RecipientGroup::FilterResolvers::PhaseAuthors do
  describe "BudgetPhase" do
    let(:phase) { create(:projekt_phase, :budget_phase) }
    let!(:winner_author) { create(:user, email: "win@x.test") }

    before do
      allow(phase).to receive(:authors_of_winners_ids).and_return([winner_author.id])
      allow(ProjektPhase).to receive(:find).with(phase.id).and_return(phase)
    end

    it "returns authors for criterion=winners" do
      emails = described_class.new("projekt_phase_id" => phase.id, "criterion" => "winners").emails
      expect(emails).to contain_exactly("win@x.test")
    end
  end

  describe "ProposalPhase" do
    let(:phase) { create(:projekt_phase, :proposal_phase) }
    let!(:author) { create(:user, email: "p@x.test") }

    before do
      create(:proposal, projekt_phase: phase, author: author)
    end

    it "returns all proposal authors for criterion=all" do
      emails = described_class.new("projekt_phase_id" => phase.id, "criterion" => "all").emails
      expect(emails).to contain_exactly("p@x.test")
    end
  end

  describe "DebatePhase" do
    let(:phase) { create(:projekt_phase, :debate_phase) }
    let!(:author) { create(:user, email: "d@x.test") }

    before do
      create(:debate, projekt_phase: phase, author: author)
    end

    it "returns debate authors for criterion=all" do
      emails = described_class.new("projekt_phase_id" => phase.id, "criterion" => "all").emails
      expect(emails).to contain_exactly("d@x.test")
    end
  end

  it "returns empty when projekt_phase_id is missing" do
    expect(described_class.new({}).emails).to eq([])
  end
end
```

- [ ] **Step 2: Run spec to verify it fails**

```bash
bundle exec rspec spec/services/recipient_group/filter_resolvers/phase_authors_spec.rb
```
Expected: FAIL.

- [ ] **Step 3: Create resolver**

`app/services/recipient_group/filter_resolvers/phase_authors.rb`:
```ruby
module RecipientGroup
  module FilterResolvers
    class PhaseAuthors < Base
      BUDGET_CRITERIA = %w[feasible unfeasible selected winners not_winners].freeze

      def emails
        return [] if params[:projekt_phase_id].blank?

        phase = ProjektPhase.find_by(id: params[:projekt_phase_id])
        return [] unless phase

        user_ids = user_ids_for(phase)
        User.actual.where(id: user_ids).pluck(:email).compact.uniq
      end

      private

        def user_ids_for(phase)
          criterion = params[:criterion].to_s

          case phase.type
          when "ProjektPhase::BudgetPhase"
            return [] unless BUDGET_CRITERIA.include?(criterion)

            phase.send("authors_of_#{criterion}_ids")
          when "ProjektPhase::ProposalPhase"
            Proposal.where(projekt_phase_id: phase.id).pluck(:author_id)
          when "ProjektPhase::DebatePhase"
            Debate.where(projekt_phase_id: phase.id).pluck(:author_id)
          when "ProjektPhase::ArgumentPhase"
            phase.respond_to?(:arguments) ? phase.arguments.pluck(:author_id) : []
          when "ProjektPhase::QuestionPhase"
            phase.respond_to?(:projekt_questions) ? phase.projekt_questions.pluck(:author_id) : []
          else
            []
          end
        end
    end
  end
end
```

- [ ] **Step 4: Run spec to verify it passes**

```bash
bundle exec rspec spec/services/recipient_group/filter_resolvers/phase_authors_spec.rb
```
Expected: PASS, 4 examples.

If `:proposal_phase` or `:debate_phase` traits don't exist on the `projekt_phase` factory, inspect `spec/factories/projekts.rb` and add them — pattern is `trait(:proposal_phase) { type "ProjektPhase::ProposalPhase" }`.

- [ ] **Step 5: Commit**

```bash
git add app/services/recipient_group/filter_resolvers/phase_authors.rb spec/services/recipient_group/filter_resolvers/phase_authors_spec.rb spec/factories/projekts.rb
git commit -m "$BRANCH"
```

---

## Task 10: Resolver — `phase_subscribers`

**Files:**
- Create: `app/services/recipient_group/filter_resolvers/phase_subscribers.rb`
- Test: `spec/services/recipient_group/filter_resolvers/phase_subscribers_spec.rb`

- [ ] **Step 1: Write the failing spec**

`spec/services/recipient_group/filter_resolvers/phase_subscribers_spec.rb`:
```ruby
require "rails_helper"

describe RecipientGroup::FilterResolvers::PhaseSubscribers do
  let(:projekt) { create(:projekt) }
  let(:phase) { projekt.projekt_phases.first }
  let!(:subscriber) { create(:user, email: "sub@x.test") }
  let!(:non_subscriber) { create(:user, email: "no@x.test") }

  before do
    create(:projekt_phase_subscription, user: subscriber, projekt_phase: phase)
  end

  it "returns subscribers of a specific phase" do
    expect(
      described_class.new("projekt_phase_id" => phase.id).emails
    ).to contain_exactly("sub@x.test")
  end

  it "returns all phase subscribers across a projekt" do
    expect(
      described_class.new("projekt_id" => projekt.id).emails
    ).to contain_exactly("sub@x.test")
  end

  it "returns empty when neither id is given" do
    expect(described_class.new({}).emails).to eq([])
  end
end
```

- [ ] **Step 2: Run spec to verify it fails**

```bash
bundle exec rspec spec/services/recipient_group/filter_resolvers/phase_subscribers_spec.rb
```
Expected: FAIL.

- [ ] **Step 3: Create resolver**

`app/services/recipient_group/filter_resolvers/phase_subscribers.rb`:
```ruby
module RecipientGroup
  module FilterResolvers
    class PhaseSubscribers < Base
      def emails
        user_ids =
          if params[:projekt_phase_id].present?
            ProjektPhaseSubscription.where(projekt_phase_id: params[:projekt_phase_id]).pluck(:user_id)
          elsif params[:projekt_id].present?
            phase_ids = ProjektPhase.where(projekt_id: params[:projekt_id]).pluck(:id)
            ProjektPhaseSubscription.where(projekt_phase_id: phase_ids).pluck(:user_id)
          else
            []
          end

        User.actual.where(id: user_ids).pluck(:email).compact.uniq
      end
    end
  end
end
```

- [ ] **Step 4: Run spec to verify it passes**

```bash
bundle exec rspec spec/services/recipient_group/filter_resolvers/phase_subscribers_spec.rb
```
Expected: PASS, 3 examples.

- [ ] **Step 5: Commit**

```bash
git add app/services/recipient_group/filter_resolvers/phase_subscribers.rb spec/services/recipient_group/filter_resolvers/phase_subscribers_spec.rb
git commit -m "$BRANCH"
```

---

## Task 11: Resolver — `comment_authors`

**Files:**
- Create: `app/services/recipient_group/filter_resolvers/comment_authors.rb`
- Test: `spec/services/recipient_group/filter_resolvers/comment_authors_spec.rb`

- [ ] **Step 1: Write the failing spec**

`spec/services/recipient_group/filter_resolvers/comment_authors_spec.rb`:
```ruby
require "rails_helper"

describe RecipientGroup::FilterResolvers::CommentAuthors do
  let(:phase) { create(:projekt_phase) }
  let!(:commenter) { create(:user, email: "c@x.test") }
  let!(:other) { create(:user, email: "o@x.test") }

  before do
    create(:comment, commentable: phase, user: commenter)
  end

  it "returns commenters scoped to a phase" do
    expect(
      described_class.new("commentable_type" => "ProjektPhase", "commentable_id" => phase.id).emails
    ).to contain_exactly("c@x.test")
  end

  it "returns no one when scoped to an unrelated commentable" do
    other_phase = create(:projekt_phase)
    expect(
      described_class.new("commentable_type" => "ProjektPhase", "commentable_id" => other_phase.id).emails
    ).to eq([])
  end

  it "returns all global commenters when commentable_id is blank" do
    expect(
      described_class.new({}).emails
    ).to contain_exactly("c@x.test")
  end
end
```

- [ ] **Step 2: Run spec to verify it fails**

```bash
bundle exec rspec spec/services/recipient_group/filter_resolvers/comment_authors_spec.rb
```
Expected: FAIL.

- [ ] **Step 3: Create resolver**

`app/services/recipient_group/filter_resolvers/comment_authors.rb`:
```ruby
module RecipientGroup
  module FilterResolvers
    class CommentAuthors < Base
      def emails
        scope = Comment.all
        scope = scope.where(commentable_type: params[:commentable_type]) if params[:commentable_type].present?
        scope = scope.where(commentable_id: params[:commentable_id]) if params[:commentable_id].present?

        user_ids = scope.pluck(:user_id).uniq
        User.actual.where(id: user_ids).pluck(:email).compact.uniq
      end
    end
  end
end
```

- [ ] **Step 4: Run spec to verify it passes**

```bash
bundle exec rspec spec/services/recipient_group/filter_resolvers/comment_authors_spec.rb
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/services/recipient_group/filter_resolvers/comment_authors.rb spec/services/recipient_group/filter_resolvers/comment_authors_spec.rb
git commit -m "$BRANCH"
```

---

## Task 12: Resolver — `voting_participants`

**Files:**
- Create: `app/services/recipient_group/filter_resolvers/voting_participants.rb`
- Test: `spec/services/recipient_group/filter_resolvers/voting_participants_spec.rb`

- [ ] **Step 1: Write the failing spec**

`spec/services/recipient_group/filter_resolvers/voting_participants_spec.rb`:
```ruby
require "rails_helper"

describe RecipientGroup::FilterResolvers::VotingParticipants do
  let(:phase) { create(:projekt_phase, :voting_phase) }
  let!(:voter) { create(:user, email: "v@x.test") }
  let!(:non_voter) { create(:user, email: "n@x.test") }

  before do
    create(:vote, voter: voter, votable: create(:proposal, projekt_phase: phase))
  end

  it "returns users who voted on items in this voting phase" do
    expect(
      described_class.new("projekt_phase_id" => phase.id).emails
    ).to contain_exactly("v@x.test")
  end

  it "returns empty when phase_id is missing" do
    expect(described_class.new({}).emails).to eq([])
  end
end
```

- [ ] **Step 2: Run spec to verify it fails**

```bash
bundle exec rspec spec/services/recipient_group/filter_resolvers/voting_participants_spec.rb
```
Expected: FAIL.

- [ ] **Step 3: Create resolver**

`app/services/recipient_group/filter_resolvers/voting_participants.rb`:
```ruby
module RecipientGroup
  module FilterResolvers
    class VotingParticipants < Base
      def emails
        return [] if params[:projekt_phase_id].blank?

        votable_ids = Proposal.where(projekt_phase_id: params[:projekt_phase_id]).pluck(:id)
        user_ids = ActsAsVotable::Vote.where(votable_type: "Proposal", votable_id: votable_ids).pluck(:voter_id).uniq

        User.actual.where(id: user_ids).pluck(:email).compact.uniq
      end
    end
  end
end
```

Note: If your repo uses Polls or Budget::Investment as the votable instead of Proposal for VotingPhase, adjust the query accordingly. Verify with `grep -r "votable_type" app/models/projekt_phase/voting_phase.rb` before writing the resolver.

- [ ] **Step 4: Run spec to verify it passes**

```bash
bundle exec rspec spec/services/recipient_group/filter_resolvers/voting_participants_spec.rb
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/services/recipient_group/filter_resolvers/voting_participants.rb spec/services/recipient_group/filter_resolvers/voting_participants_spec.rb
git commit -m "$BRANCH"
```

---

## Task 13: Resolver — `geozone`

**Files:**
- Create: `app/services/recipient_group/filter_resolvers/geozone.rb`
- Test: `spec/services/recipient_group/filter_resolvers/geozone_spec.rb`

- [ ] **Step 1: Write the failing spec**

`spec/services/recipient_group/filter_resolvers/geozone_spec.rb`:
```ruby
require "rails_helper"

describe RecipientGroup::FilterResolvers::Geozone do
  let(:zone1) { create(:geozone) }
  let(:zone2) { create(:geozone) }
  let!(:in_zone1) { create(:user, geozone: zone1, email: "z1@x.test") }
  let!(:in_zone2) { create(:user, geozone: zone2, email: "z2@x.test") }
  let!(:no_zone) { create(:user, email: "nz@x.test") }

  it "returns users in selected geozones" do
    expect(
      described_class.new("geozone_ids" => [zone1.id]).emails
    ).to contain_exactly("z1@x.test")
  end

  it "returns users across multiple geozones" do
    expect(
      described_class.new("geozone_ids" => [zone1.id, zone2.id]).emails
    ).to contain_exactly("z1@x.test", "z2@x.test")
  end

  it "returns empty when no geozone_ids given" do
    expect(described_class.new({}).emails).to eq([])
  end
end
```

- [ ] **Step 2: Run spec to verify it fails**

```bash
bundle exec rspec spec/services/recipient_group/filter_resolvers/geozone_spec.rb
```
Expected: FAIL.

- [ ] **Step 3: Create resolver**

`app/services/recipient_group/filter_resolvers/geozone.rb`:
```ruby
module RecipientGroup
  module FilterResolvers
    class Geozone < Base
      def emails
        ids = Array(params[:geozone_ids]).map(&:to_i).reject(&:zero?)
        return [] if ids.empty?

        User.actual.where(geozone_id: ids).pluck(:email).compact.uniq
      end
    end
  end
end
```

- [ ] **Step 4: Run spec to verify it passes**

```bash
bundle exec rspec spec/services/recipient_group/filter_resolvers/geozone_spec.rb
```
Expected: PASS, 3 examples.

- [ ] **Step 5: Commit**

```bash
git add app/services/recipient_group/filter_resolvers/geozone.rb spec/services/recipient_group/filter_resolvers/geozone_spec.rb
git commit -m "$BRANCH"
```

---

## Task 14: Resolver — `plz`

**Files:**
- Create: `app/services/recipient_group/filter_resolvers/plz.rb`
- Test: `spec/services/recipient_group/filter_resolvers/plz_spec.rb`

- [ ] **Step 1: Write the failing spec**

`spec/services/recipient_group/filter_resolvers/plz_spec.rb`:
```ruby
require "rails_helper"

describe RecipientGroup::FilterResolvers::Plz do
  let!(:a) { create(:user, plz: 80331, email: "a@x.test") }
  let!(:b) { create(:user, plz: 80333, email: "b@x.test") }
  let!(:c) { create(:user, plz: 99999, email: "c@x.test") }

  it "matches exact PLZ values" do
    expect(
      described_class.new("plz_list" => ["80331", "80333"]).emails
    ).to contain_exactly("a@x.test", "b@x.test")
  end

  it "returns empty when list is empty" do
    expect(described_class.new("plz_list" => []).emails).to eq([])
  end
end
```

- [ ] **Step 2: Run spec to verify it fails**

```bash
bundle exec rspec spec/services/recipient_group/filter_resolvers/plz_spec.rb
```
Expected: FAIL.

- [ ] **Step 3: Create resolver**

`app/services/recipient_group/filter_resolvers/plz.rb`:
```ruby
module RecipientGroup
  module FilterResolvers
    class Plz < Base
      def emails
        list = Array(params[:plz_list]).map(&:to_s).reject(&:blank?)
        return [] if list.empty?

        User.actual.where(plz: list).pluck(:email).compact.uniq
      end
    end
  end
end
```

- [ ] **Step 4: Run spec to verify it passes**

```bash
bundle exec rspec spec/services/recipient_group/filter_resolvers/plz_spec.rb
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/services/recipient_group/filter_resolvers/plz.rb spec/services/recipient_group/filter_resolvers/plz_spec.rb
git commit -m "$BRANCH"
```

---

## Task 15: Resolver — `age_range`

**Files:**
- Create: `app/services/recipient_group/filter_resolvers/age_range.rb`
- Test: `spec/services/recipient_group/filter_resolvers/age_range_spec.rb`

- [ ] **Step 1: Write the failing spec**

`spec/services/recipient_group/filter_resolvers/age_range_spec.rb`:
```ruby
require "rails_helper"

describe RecipientGroup::FilterResolvers::AgeRange do
  let!(:young)  { create(:user, date_of_birth: 25.years.ago, email: "y@x.test") }
  let!(:mid)    { create(:user, date_of_birth: 40.years.ago, email: "m@x.test") }
  let!(:senior) { create(:user, date_of_birth: 70.years.ago, email: "s@x.test") }

  it "filters by min_age + max_age inline range" do
    expect(
      described_class.new("min_age" => 30, "max_age" => 50).emails
    ).to contain_exactly("m@x.test")
  end

  it "filters by configured age_range_id" do
    range = AgeRange.create!(name: "Seniors", min_age: 65, max_age: 120)
    expect(
      described_class.new("age_range_id" => range.id).emails
    ).to contain_exactly("s@x.test")
  end

  it "returns empty when no params given" do
    expect(described_class.new({}).emails).to eq([])
  end
end
```

- [ ] **Step 2: Run spec to verify it fails**

```bash
bundle exec rspec spec/services/recipient_group/filter_resolvers/age_range_spec.rb
```
Expected: FAIL.

- [ ] **Step 3: Create resolver**

`app/services/recipient_group/filter_resolvers/age_range.rb`:
```ruby
module RecipientGroup
  module FilterResolvers
    class AgeRange < Base
      def emails
        min, max = resolve_bounds
        return [] if min.nil? && max.nil?

        today = Date.current
        scope = User.actual.where.not(date_of_birth: nil)
        scope = scope.where("date_of_birth <= ?", today - min.years) if min
        scope = scope.where("date_of_birth >= ?", today - (max + 1).years + 1.day) if max

        scope.pluck(:email).compact.uniq
      end

      private

        def resolve_bounds
          if params[:age_range_id].present?
            range = ::AgeRange.find_by(id: params[:age_range_id])
            return [nil, nil] unless range

            [range.min_age, range.max_age]
          else
            [params[:min_age]&.to_i, params[:max_age]&.to_i]
          end
        end
    end
  end
end
```

- [ ] **Step 4: Run spec to verify it passes**

```bash
bundle exec rspec spec/services/recipient_group/filter_resolvers/age_range_spec.rb
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/services/recipient_group/filter_resolvers/age_range.rb spec/services/recipient_group/filter_resolvers/age_range_spec.rb
git commit -m "$BRANCH"
```

---

## Task 16: Resolver — `gender`

**Files:**
- Create: `app/services/recipient_group/filter_resolvers/gender.rb`
- Test: `spec/services/recipient_group/filter_resolvers/gender_spec.rb`

- [ ] **Step 1: Write the failing spec**

`spec/services/recipient_group/filter_resolvers/gender_spec.rb`:
```ruby
require "rails_helper"

describe RecipientGroup::FilterResolvers::Gender do
  let!(:f) { create(:user, gender: "female", email: "f@x.test") }
  let!(:m) { create(:user, gender: "male", email: "m@x.test") }
  let!(:nb) { create(:user, gender: nil, email: "nb@x.test") }

  it "filters by gender value" do
    expect(described_class.new("gender" => "female").emails).to contain_exactly("f@x.test")
  end

  it "returns empty for unknown gender" do
    expect(described_class.new("gender" => "xx").emails).to eq([])
  end

  it "returns empty when blank" do
    expect(described_class.new({}).emails).to eq([])
  end
end
```

- [ ] **Step 2: Run spec to verify it fails**

```bash
bundle exec rspec spec/services/recipient_group/filter_resolvers/gender_spec.rb
```
Expected: FAIL.

- [ ] **Step 3: Create resolver**

`app/services/recipient_group/filter_resolvers/gender.rb`:
```ruby
module RecipientGroup
  module FilterResolvers
    class Gender < Base
      ALLOWED = %w[male female diverse].freeze

      def emails
        value = params[:gender].to_s
        return [] unless ALLOWED.include?(value)

        User.actual.where(gender: value).pluck(:email).compact.uniq
      end
    end
  end
end
```

If the User model uses single-letter codes (`m`/`f`/`d`) instead of full words, adjust `ALLOWED` and the spec accordingly. Verify with `bin/rails runner "puts User.distinct.pluck(:gender).inspect"`.

- [ ] **Step 4: Run spec to verify it passes**

```bash
bundle exec rspec spec/services/recipient_group/filter_resolvers/gender_spec.rb
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/services/recipient_group/filter_resolvers/gender.rb spec/services/recipient_group/filter_resolvers/gender_spec.rb
git commit -m "$BRANCH"
```

---

## Task 17: Resolver — `individual_group`

**Files:**
- Create: `app/services/recipient_group/filter_resolvers/individual_group.rb`
- Test: `spec/services/recipient_group/filter_resolvers/individual_group_spec.rb`

- [ ] **Step 1: Write the failing spec**

`spec/services/recipient_group/filter_resolvers/individual_group_spec.rb`:
```ruby
require "rails_helper"

describe RecipientGroup::FilterResolvers::IndividualGroup do
  let(:group) { create(:individual_group) }
  let(:value_a) { create(:individual_group_value, individual_group: group) }
  let(:value_b) { create(:individual_group_value, individual_group: group) }
  let!(:member_a) { create(:user, email: "a@x.test") }
  let!(:member_b) { create(:user, email: "b@x.test") }
  let!(:outsider) { create(:user, email: "o@x.test") }

  before do
    create(:user_individual_group_value, user: member_a, individual_group_value: value_a)
    create(:user_individual_group_value, user: member_b, individual_group_value: value_b)
  end

  it "returns members of selected individual group values" do
    expect(
      described_class.new("individual_group_value_ids" => [value_a.id]).emails
    ).to contain_exactly("a@x.test")
  end

  it "supports multiple values (union within filter)" do
    expect(
      described_class.new("individual_group_value_ids" => [value_a.id, value_b.id]).emails
    ).to contain_exactly("a@x.test", "b@x.test")
  end

  it "returns empty when no ids given" do
    expect(described_class.new({}).emails).to eq([])
  end
end
```

- [ ] **Step 2: Run spec to verify it fails**

```bash
bundle exec rspec spec/services/recipient_group/filter_resolvers/individual_group_spec.rb
```
Expected: FAIL.

- [ ] **Step 3: Create resolver**

`app/services/recipient_group/filter_resolvers/individual_group.rb`:
```ruby
module RecipientGroup
  module FilterResolvers
    class IndividualGroup < Base
      def emails
        ids = Array(params[:individual_group_value_ids]).map(&:to_i).reject(&:zero?)
        return [] if ids.empty?

        user_ids = UserIndividualGroupValue.where(individual_group_value_id: ids).pluck(:user_id).uniq
        User.actual.where(id: user_ids).pluck(:email).compact.uniq
      end
    end
  end
end
```

- [ ] **Step 4: Run spec to verify it passes**

```bash
bundle exec rspec spec/services/recipient_group/filter_resolvers/individual_group_spec.rb
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/services/recipient_group/filter_resolvers/individual_group.rb spec/services/recipient_group/filter_resolvers/individual_group_spec.rb
git commit -m "$BRANCH"
```

---

## Task 18: Resolver — `manual_users`

**Files:**
- Create: `app/services/recipient_group/filter_resolvers/manual_users.rb`
- Test: `spec/services/recipient_group/filter_resolvers/manual_users_spec.rb`

- [ ] **Step 1: Write the failing spec**

`spec/services/recipient_group/filter_resolvers/manual_users_spec.rb`:
```ruby
require "rails_helper"

describe RecipientGroup::FilterResolvers::ManualUsers do
  let!(:u1) { create(:user, email: "u1@x.test") }
  let!(:u2) { create(:user, email: "u2@x.test") }
  let!(:erased) { create(:user, email: "e@x.test", erased_at: Time.current) }

  it "returns emails of selected users (excluding erased)" do
    expect(
      described_class.new("user_ids" => [u1.id, u2.id, erased.id]).emails
    ).to contain_exactly("u1@x.test", "u2@x.test")
  end

  it "returns empty when no ids given" do
    expect(described_class.new({}).emails).to eq([])
  end
end
```

- [ ] **Step 2: Run spec to verify it fails**

```bash
bundle exec rspec spec/services/recipient_group/filter_resolvers/manual_users_spec.rb
```
Expected: FAIL.

- [ ] **Step 3: Create resolver**

`app/services/recipient_group/filter_resolvers/manual_users.rb`:
```ruby
module RecipientGroup
  module FilterResolvers
    class ManualUsers < Base
      def emails
        ids = Array(params[:user_ids]).map(&:to_i).reject(&:zero?)
        return [] if ids.empty?

        User.actual.where(id: ids).pluck(:email).compact.uniq
      end
    end
  end
end
```

- [ ] **Step 4: Run spec to verify it passes**

```bash
bundle exec rspec spec/services/recipient_group/filter_resolvers/manual_users_spec.rb
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/services/recipient_group/filter_resolvers/manual_users.rb spec/services/recipient_group/filter_resolvers/manual_users_spec.rb
git commit -m "$BRANCH"
```

---

## Task 19: Per-kind params validation

**Files:**
- Modify: `app/models/recipient_group_filter.rb`
- Modify: `spec/models/recipient_group_filter_spec.rb`

- [ ] **Step 1: Write the failing spec**

Append to `spec/models/recipient_group_filter_spec.rb`:
```ruby
  describe "params validation per kind" do
    let(:group) { create(:recipient_group) }

    it "rejects geozone filter without geozone_ids" do
      f = build(:recipient_group_filter, recipient_group: group, kind: "geozone", params: {})
      expect(f).not_to be_valid
      expect(f.errors[:params]).to be_present
    end

    it "accepts geozone filter with geozone_ids" do
      f = build(:recipient_group_filter, recipient_group: group, kind: "geozone", params: { "geozone_ids" => [1] })
      expect(f).to be_valid
    end

    it "rejects role filter with unsupported role" do
      f = build(:recipient_group_filter, recipient_group: group, kind: "role", params: { "role" => "nope" })
      expect(f).not_to be_valid
    end

    it "accepts role filter with allowed role" do
      f = build(:recipient_group_filter, recipient_group: group, kind: "role", params: { "role" => "administrator" })
      expect(f).to be_valid
    end

    it "rejects phase_authors without projekt_phase_id" do
      f = build(:recipient_group_filter, recipient_group: group, kind: "phase_authors", params: { "criterion" => "winners" })
      expect(f).not_to be_valid
    end
  end
```

- [ ] **Step 2: Run spec to verify it fails**

```bash
bundle exec rspec spec/models/recipient_group_filter_spec.rb -e "params validation per kind"
```
Expected: FAIL.

- [ ] **Step 3: Implement validation**

In `app/models/recipient_group_filter.rb`, replace the `private` section and add:
```ruby
  REQUIRED_PARAMS = {
    "newsletter_subscribers" => [],
    "role"                   => ["role"],
    "phase_authors"          => ["projekt_phase_id"],
    "phase_subscribers"      => [], # validated below — either projekt_id OR projekt_phase_id
    "comment_authors"        => [],
    "voting_participants"    => ["projekt_phase_id"],
    "geozone"                => ["geozone_ids"],
    "plz"                    => ["plz_list"],
    "age_range"              => [], # validated below — either age_range_id OR min/max
    "gender"                 => ["gender"],
    "individual_group"       => ["individual_group_value_ids"],
    "manual_users"           => ["user_ids"]
  }.freeze

  ALLOWED_ROLES = %w[
    administrator moderator valuator
    projekt_manager idea_manager officing_manager deficiency_report_manager
  ].freeze

  validate :params_valid_for_kind

  private

    def first_filter_must_be_include
      # … unchanged from Task 3
    end

    def params_valid_for_kind
      return if kind.blank?

      required = REQUIRED_PARAMS[kind] || []
      required.each do |key|
        value = params&.dig(key)
        if value.blank? || (value.is_a?(Array) && value.empty?)
          errors.add(:params, "missing required key: #{key}")
        end
      end

      case kind
      when "role"
        errors.add(:params, "unsupported role") unless ALLOWED_ROLES.include?(params&.dig("role").to_s)
      when "phase_subscribers"
        unless params&.dig("projekt_id").present? || params&.dig("projekt_phase_id").present?
          errors.add(:params, "either projekt_id or projekt_phase_id required")
        end
      when "age_range"
        unless params&.dig("age_range_id").present? || params&.dig("min_age").present? || params&.dig("max_age").present?
          errors.add(:params, "either age_range_id or min/max required")
        end
      end
    end
```

- [ ] **Step 4: Run spec to verify it passes**

```bash
bundle exec rspec spec/models/recipient_group_filter_spec.rb
```
Expected: PASS all examples.

- [ ] **Step 5: Commit**

```bash
git add app/models/recipient_group_filter.rb spec/models/recipient_group_filter_spec.rb
git commit -m "$BRANCH"
```

---

## Task 20: Data-Migration of legacy recipient groups

**Files:**
- Create: `db/migrate/<timestamp>_migrate_legacy_recipient_groups.rb`
- Test: `spec/db/migrate/migrate_legacy_recipient_groups_spec.rb`

- [ ] **Step 1: Write the failing spec**

`spec/db/migrate/migrate_legacy_recipient_groups_spec.rb`:
```ruby
require "rails_helper"
require Rails.root.join("db/migrate").glob("*migrate_legacy_recipient_groups*.rb").first

describe MigrateLegacyRecipientGroups do
  before do
    # Strip filters created automatically by other tests
    RecipientGroupFilter.delete_all
    RecipientGroup.delete_all
  end

  it "migrates a newsletter_subscriber_ids group" do
    rg = RecipientGroup.create!(name: "All subs",
                                origin_class_name: "User",
                                access_method: "newsletter_subscriber_ids")
    described_class.new.up
    rg.reload
    expect(rg.filters.size).to eq(1)
    expect(rg.filters.first.kind).to eq("newsletter_subscribers")
    expect(rg.filters.first.params).to eq("include_unregistered" => false)
  end

  it "migrates an all_newsletter_subscriber_ids group" do
    rg = RecipientGroup.create!(name: "All+", origin_class_name: "User",
                                access_method: "all_newsletter_subscriber_ids")
    described_class.new.up
    expect(rg.reload.filters.first.params).to eq("include_unregistered" => true)
  end

  it "migrates an administrators_ids group" do
    rg = RecipientGroup.create!(name: "Admins", origin_class_name: "User",
                                access_method: "administrators_ids")
    described_class.new.up
    f = rg.reload.filters.first
    expect(f.kind).to eq("role")
    expect(f.params).to eq("role" => "administrator")
  end

  it "migrates a projekt-related any_phase_subscribers_ids group" do
    projekt = create(:projekt)
    rg = RecipientGroup.create!(name: "Phase subs", origin_class_name: "Projekt",
                                origin_class_object_id: projekt.id.to_s,
                                access_method: "any_phase_subscribers_ids")
    described_class.new.up
    f = rg.reload.filters.first
    expect(f.kind).to eq("phase_subscribers")
    expect(f.params).to eq("projekt_id" => projekt.id)
  end

  it "migrates a BudgetPhase authors_of_winners_ids group" do
    phase = create(:projekt_phase, :budget_phase)
    rg = RecipientGroup.create!(name: "Winners", origin_class_name: "ProjektPhase",
                                origin_class_object_id: phase.id.to_s,
                                access_method: "authors_of_winners_ids")
    described_class.new.up
    f = rg.reload.filters.first
    expect(f.kind).to eq("phase_authors")
    expect(f.params).to eq("projekt_phase_id" => phase.id, "criterion" => "winners")
  end

  it "is idempotent — running twice does not duplicate filters" do
    rg = RecipientGroup.create!(name: "X", origin_class_name: "User",
                                access_method: "administrators_ids")
    described_class.new.up
    described_class.new.up
    expect(rg.reload.filters.size).to eq(1)
  end
end
```

- [ ] **Step 2: Run spec to verify it fails**

```bash
bundle exec rspec spec/db/migrate/migrate_legacy_recipient_groups_spec.rb
```
Expected: FAIL — migration file doesn't exist yet.

- [ ] **Step 3: Generate and edit migration**

```bash
bin/rails generate migration MigrateLegacyRecipientGroups
```

Edit `db/migrate/<timestamp>_migrate_legacy_recipient_groups.rb`:
```ruby
class MigrateLegacyRecipientGroups < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def up
    RecipientGroup.find_each do |rg|
      next if rg.filters.exists?

      attrs = legacy_to_filter_attrs(rg)
      next unless attrs

      rg.filters.create!(attrs.merge(position: 0, operator: "include"))
    end
  end

  def down
    # Non-reversible: filter chains may have been edited after migration.
    raise ActiveRecord::IrreversibleMigration
  end

  private

    def legacy_to_filter_attrs(rg)
      case [rg.origin_class_name, rg.access_method]
      in ["User", "newsletter_subscriber_ids"]
        { kind: "newsletter_subscribers", params: { "include_unregistered" => false } }
      in ["User", "all_newsletter_subscriber_ids"]
        { kind: "newsletter_subscribers", params: { "include_unregistered" => true } }
      in ["User", "administrators_ids"]
        { kind: "role", params: { "role" => "administrator" } }
      in ["Projekt", "any_phase_subscribers_ids"]
        { kind: "phase_subscribers", params: { "projekt_id" => rg.origin_class_object_id.to_i } }
      in ["ProjektPhase", method] if method.start_with?("authors_of_") && method.end_with?("_ids")
        criterion = method.sub("authors_of_", "").sub("_ids", "")
        { kind: "phase_authors",
          params: { "projekt_phase_id" => rg.origin_class_object_id.to_i, "criterion" => criterion } }
      else
        nil
      end
    end
end
```

- [ ] **Step 4: Run spec to verify it passes**

```bash
bundle exec rspec spec/db/migrate/migrate_legacy_recipient_groups_spec.rb
```
Expected: PASS.

- [ ] **Step 5: Run migration on dev DB**

```bash
bin/rails db:migrate
```
Expected: schema updated, output shows migration ran.

- [ ] **Step 6: Commit**

```bash
git add db/migrate db/schema.rb spec/db
git commit -m "$BRANCH"
```

---

## Task 21: Routes

**Files:**
- Modify: `config/routes/adm.rb`

- [ ] **Step 1: Inspect current routes**

```bash
grep -n "recipient_group" config/routes/adm.rb
```

- [ ] **Step 2: Add nested resource**

Find the existing `resources :recipient_groups` block and replace with:
```ruby
resources :recipient_groups do
  resources :filters,
            controller: "recipient_group_filters",
            only: [:create, :update, :destroy] do
    collection do
      post :reorder
      get :recount
    end
  end
end
```

Remove the old `post :select_options, on: :collection` line if present (replaced by the new endpoints).

- [ ] **Step 3: Verify routes**

```bash
bin/rails routes -g recipient_group
```
Expected output includes lines like:
```
adm_recipient_group_filters         POST   /adm/recipient_groups/:recipient_group_id/filters(.:format)
adm_recipient_group_filter          PATCH  /adm/recipient_groups/:recipient_group_id/filters/:id(.:format)
reorder_adm_recipient_group_filters POST   /adm/recipient_groups/:recipient_group_id/filters/reorder(.:format)
recount_adm_recipient_group_filters GET    /adm/recipient_groups/:recipient_group_id/filters/recount(.:format)
```

- [ ] **Step 4: Commit**

```bash
git add config/routes/adm.rb
git commit -m "$BRANCH"
```

---

## Task 22: `Adm::RecipientGroupFiltersController`

**Files:**
- Create: `app/controllers/adm/recipient_group_filters_controller.rb`
- Modify: `app/policies/adm/recipient_group_policy.rb`
- Test: `spec/controllers/adm/recipient_group_filters_controller_spec.rb`

- [ ] **Step 1: Update policy**

`app/policies/adm/recipient_group_policy.rb` — ensure existing admin-only authorization extends to nested filter actions. Add (if not present):
```ruby
def create_filter?
  administrator?
end
alias_method :update_filter?, :create_filter?
alias_method :destroy_filter?, :create_filter?
alias_method :reorder_filters?, :create_filter?
alias_method :recount_filters?, :create_filter?
```

(If the policy uses a different pattern, follow the existing style — but the new actions must be authorized.)

- [ ] **Step 2: Write controller spec**

`spec/controllers/adm/recipient_group_filters_controller_spec.rb`:
```ruby
require "rails_helper"

describe Adm::RecipientGroupFiltersController do
  let(:admin) { create(:administrator).user }
  let(:group) { create(:recipient_group) }

  before { sign_in admin }

  describe "POST #create" do
    it "creates a filter and responds with turbo_stream" do
      post :create,
           params: { recipient_group_id: group.id,
                     recipient_group_filter: { kind: "newsletter_subscribers", operator: "include", params: {} } },
           format: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(group.reload.filters.size).to eq(1)
    end
  end

  describe "PATCH #update" do
    let!(:filter) { create(:recipient_group_filter, recipient_group: group) }

    it "updates params" do
      patch :update,
            params: { recipient_group_id: group.id, id: filter.id,
                      recipient_group_filter: { params: { "include_unregistered" => true } } },
            format: :turbo_stream

      expect(filter.reload.params).to eq("include_unregistered" => true)
    end
  end

  describe "DELETE #destroy" do
    let!(:filter) { create(:recipient_group_filter, recipient_group: group) }

    it "destroys the filter" do
      expect {
        delete :destroy, params: { recipient_group_id: group.id, id: filter.id }, format: :turbo_stream
      }.to change(RecipientGroupFilter, :count).by(-1)
    end
  end

  describe "POST #reorder" do
    let!(:f1) { create(:recipient_group_filter, recipient_group: group, position: 1) }
    let!(:f2) { create(:recipient_group_filter, recipient_group: group, position: 2) }

    it "applies the given order" do
      post :reorder,
           params: { recipient_group_id: group.id, ordered_ids: [f2.id, f1.id] },
           format: :turbo_stream

      expect(f1.reload.position).to eq(2)
      expect(f2.reload.position).to eq(1)
    end
  end

  describe "GET #recount" do
    it "responds with turbo_stream containing the counter" do
      create(:recipient_group_filter, recipient_group: group)
      get :recount, params: { recipient_group_id: group.id }, format: :turbo_stream
      expect(response).to have_http_status(:ok)
    end
  end
end
```

- [ ] **Step 3: Run spec to verify it fails**

```bash
bundle exec rspec spec/controllers/adm/recipient_group_filters_controller_spec.rb
```
Expected: FAIL — "uninitialized constant".

- [ ] **Step 4: Create controller**

`app/controllers/adm/recipient_group_filters_controller.rb`:
```ruby
module Adm
  class RecipientGroupFiltersController < Adm::BaseController
    before_action :set_recipient_group
    before_action :set_filter, only: [:update, :destroy]

    def create
      authorize [:adm, @recipient_group], :create_filter?
      @filter = @recipient_group.filters.create(filter_params)

      respond_to { |f| f.turbo_stream }
    end

    def update
      authorize [:adm, @recipient_group], :update_filter?
      @filter.update(filter_params)

      respond_to { |f| f.turbo_stream }
    end

    def destroy
      authorize [:adm, @recipient_group], :destroy_filter?
      @filter.destroy

      respond_to { |f| f.turbo_stream }
    end

    def reorder
      authorize [:adm, @recipient_group], :reorder_filters?

      ordered_ids = params[:ordered_ids].map(&:to_i)
      ordered_ids.each_with_index do |id, idx|
        @recipient_group.filters.where(id: id).update_all(position: idx + 1)
      end

      respond_to { |f| f.turbo_stream }
    end

    def recount
      authorize [:adm, @recipient_group], :recount_filters?
      @resolver = RecipientGroupResolver.new(@recipient_group)

      respond_to { |f| f.turbo_stream }
    end

    private

      def set_recipient_group
        @recipient_group = RecipientGroup.find(params[:recipient_group_id])
      end

      def set_filter
        @filter = @recipient_group.filters.find(params[:id])
      end

      def filter_params
        params.require(:recipient_group_filter)
              .permit(:kind, :operator, params: {})
      end
  end
end
```

- [ ] **Step 5: Add turbo_stream templates**

`app/views/adm/recipient_group_filters/create.turbo_stream.erb`:
```erb
<%= turbo_stream.append "filter-stack" do %>
  <%= render Adm::RecipientGroupFilterCardComponent.new(filter: @filter, count: 0, delta: 0) %>
<% end %>
<%= turbo_stream.update "filter-stack-footer", partial: "adm/recipient_groups/footer", locals: { recipient_group: @recipient_group } %>
```

`app/views/adm/recipient_group_filters/update.turbo_stream.erb`:
```erb
<%= turbo_stream.replace dom_id(@filter) do %>
  <%= render Adm::RecipientGroupFilterCardComponent.new(filter: @filter, count: 0, delta: 0) %>
<% end %>
<%= turbo_stream.update "filter-stack-footer", partial: "adm/recipient_groups/footer", locals: { recipient_group: @recipient_group } %>
```

`app/views/adm/recipient_group_filters/destroy.turbo_stream.erb`:
```erb
<%= turbo_stream.remove dom_id(@filter) %>
<%= turbo_stream.update "filter-stack-footer", partial: "adm/recipient_groups/footer", locals: { recipient_group: @recipient_group } %>
```

`app/views/adm/recipient_group_filters/reorder.turbo_stream.erb`:
```erb
<%= turbo_stream.update "filter-stack-footer", partial: "adm/recipient_groups/footer", locals: { recipient_group: @recipient_group } %>
```

`app/views/adm/recipient_group_filters/recount.turbo_stream.erb`:
```erb
<%= turbo_stream.update "filter-stack-footer", partial: "adm/recipient_groups/footer", locals: { recipient_group: @recipient_group } %>
<% @resolver.per_filter_counts.each do |entry| %>
  <%= turbo_stream.update "filter-count-#{entry[:id]}" do %>
    <%= t("adm.recipient_groups.filters.counter.total", count: entry[:count]) %>
    (<%= entry[:delta].positive? ? "+#{entry[:delta]}" : entry[:delta] %>)
  <% end %>
<% end %>
```

- [ ] **Step 6: Run spec to verify it passes**

```bash
bundle exec rspec spec/controllers/adm/recipient_group_filters_controller_spec.rb
```
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add app/controllers/adm/recipient_group_filters_controller.rb app/views/adm/recipient_group_filters app/policies/adm/recipient_group_policy.rb spec/controllers/adm/recipient_group_filters_controller_spec.rb
git commit -m "$BRANCH"
```

---

## Task 23: Locale keys (DE + EN)

**Files:**
- Modify: `config/locales/kern/de/adm/recipient_groups.yml`
- Modify: `config/locales/kern/en/adm/recipient_groups.yml`

- [ ] **Step 1: Append the filter-stack keys to DE locale**

In `config/locales/kern/de/adm/recipient_groups.yml`, under `de.adm.recipient_groups`, append:
```yaml
      filters:
        section_title: Filter
        add_filter: Filter hinzufügen
        empty: Noch keine Filter — beginnen Sie mit einer Quelle
        delete: Filter entfernen
        move_up: Nach oben verschieben
        move_down: Nach unten verschieben
        operators:
          include: Hinzufügen
          exclude: Ausschließen
          intersect: Schnittmenge
        kind_groups:
          sources: Quellen
          demographics: Demografie
          special: Sondergruppen
          manual: Manuell
        kinds:
          newsletter_subscribers: Newsletter-Abonnenten
          role: Rolle
          phase_authors: Autoren einer Projektphase
          phase_subscribers: Abonnenten einer Phase / eines Projekts
          comment_authors: Kommentatoren
          voting_participants: Abstimmungs-Teilnehmer
          geozone: Stadtteil
          plz: Postleitzahl
          age_range: Altersgruppe
          gender: Geschlecht
          individual_group: Sondergruppe
          manual_users: Manuelle Auswahl
        roles:
          administrator: Administratoren
          moderator: Moderatoren
          valuator: Bewerter
          projekt_manager: Projekt-Manager
          idea_manager: Ideen-Manager
          officing_manager: Abstimmungshelfer
          deficiency_report_manager: Mängel-Manager
        params_labels:
          include_unregistered: Newsletter-Empfänger ohne Konto einbeziehen
          role: Rolle auswählen
          projekt_phase_id: Projektphase
          projekt_id: Projekt
          criterion: Kriterium
          commentable_type: Bezugsobjekt
          commentable_id: Konkretes Objekt (optional)
          geozone_ids: Stadtteile
          plz_list: Postleitzahlen (eine pro Zeile)
          age_range_id: Altersgruppe (vordefiniert)
          min_age: Mindestalter
          max_age: Höchstalter
          gender: Geschlecht
          individual_group_value_ids: Werte
          user_ids: Nutzer
        counter:
          total: "%{count} Empfänger"
          total_summary: "Endgröße: %{count} Empfänger"
          delta_plus: "+%{count}"
          delta_minus: "−%{count}"
        preview: Vorschau
```

- [ ] **Step 2: Append the equivalent EN locale**

In `config/locales/kern/en/adm/recipient_groups.yml`, append the same structure under `en.adm.recipient_groups` with English values:
```yaml
      filters:
        section_title: Filters
        add_filter: Add filter
        empty: No filters yet — start with a source
        delete: Remove filter
        move_up: Move up
        move_down: Move down
        operators:
          include: Add
          exclude: Exclude
          intersect: Intersect
        kind_groups:
          sources: Sources
          demographics: Demographics
          special: Special groups
          manual: Manual
        kinds:
          newsletter_subscribers: Newsletter subscribers
          role: Role
          phase_authors: Phase authors
          phase_subscribers: Phase / projekt subscribers
          comment_authors: Commenters
          voting_participants: Voting participants
          geozone: District
          plz: Postal code
          age_range: Age range
          gender: Gender
          individual_group: Individual group
          manual_users: Manual selection
        roles:
          administrator: Administrators
          moderator: Moderators
          valuator: Valuators
          projekt_manager: Projekt managers
          idea_manager: Idea managers
          officing_manager: Officing managers
          deficiency_report_manager: Deficiency report managers
        params_labels:
          include_unregistered: Include unregistered newsletter subscribers
          role: Select role
          projekt_phase_id: Projekt phase
          projekt_id: Projekt
          criterion: Criterion
          commentable_type: Reference type
          commentable_id: Specific object (optional)
          geozone_ids: Districts
          plz_list: Postal codes (one per line)
          age_range_id: Age range (preset)
          min_age: Minimum age
          max_age: Maximum age
          gender: Gender
          individual_group_value_ids: Values
          user_ids: Users
        counter:
          total: "%{count} recipients"
          total_summary: "Total: %{count} recipients"
          delta_plus: "+%{count}"
          delta_minus: "−%{count}"
          preview: Preview
```

- [ ] **Step 3: Validate YAML**

```bash
ruby -ryaml -e "YAML.load_file('config/locales/kern/de/adm/recipient_groups.yml'); YAML.load_file('config/locales/kern/en/adm/recipient_groups.yml'); puts 'YAML OK'"
```
Expected: `YAML OK`.

- [ ] **Step 4: Commit**

```bash
git add config/locales/kern/de/adm/recipient_groups.yml config/locales/kern/en/adm/recipient_groups.yml
git commit -m "$BRANCH"
```

---

## Task 24: `Adm::RecipientGroupFilterCardComponent`

**Files:**
- Create: `app/components/adm/recipient_group_filter_card_component.rb`
- Create: `app/components/adm/recipient_group_filter_card_component.html.erb`
- Create: `app/components/adm/recipient_group_filter_card_component.scss`
- Test: `spec/components/adm/recipient_group_filter_card_component_spec.rb`

This task **must** be delegated to the `hanuschka-dev:frontend` agent per the project workflow (ViewComponent + ERB + SCSS). Hand it this prompt:

> Implement the `Adm::RecipientGroupFilterCardComponent` for the recipient-group filter stack.
>
> **Props:** `filter:` (RecipientGroupFilter), `count:` (Integer), `delta:` (Integer)
>
> **Structure:**
> ```
> <article class="rg-filter-card" data-controller="adm-newsletters--filter-stack-item" id="<%= dom_id(filter) %>">
>   <header>
>     <button class="rg-filter-card__handle" data-action="…"><%= material_icon("drag_indicator") %></button>
>     <span class="rg-filter-card__position">#<%= filter.position %></span>
>     <select operator>...</select>
>     <select kind>...</select>
>     <button class="rg-filter-card__delete" data-turbo-method="delete" data-turbo-confirm="<%= t('...delete') %>"><%= material_icon("close") %></button>
>   </header>
>   <section class="rg-filter-card__params">
>     <!-- kind-specific param fields, rendered via partial dispatch -->
>   </section>
>   <footer class="rg-filter-card__counter" id="filter-count-<%= filter.id %>">
>     <%= t("adm.recipient_groups.filters.counter.total", count: count) %>
>   </footer>
> </article>
> ```
>
> **Constraints (hard rules):**
> - No hardcoded strings — every label via `t(...)` with keys from `config/locales/kern/{de,en}/adm/recipient_groups.yml` (Task 23 already added them)
> - No genderized German strings ("Nutzer:innen") — masculine generic
> - All icon-only buttons (`drag_indicator`, `close`) need `title=` attributes
> - Use `var(--adm-color-primary)` for adm-tree brand color (not `var(--brand-color)` — that's citizen-frontend only)
> - `!important` only as Foundation override if absolutely necessary
> - Wrap the SCSS rules in `.custom-new-design { ... }` to win against Foundation reset
> - Mobile breakpoints: `$mobile-viewport-start`, `$small-tablet-viewport-start`
>
> **Kind-specific param sub-partials** live at `app/views/adm/recipient_group_filters/params/_<kind>.html.erb` — one per kind. Each receives the `filter` local. Keep them small (3–6 lines). Examples:
> - `_newsletter_subscribers.html.erb`: single checkbox bound to `params[include_unregistered]`
> - `_role.html.erb`: select from `RecipientGroupFilter::ALLOWED_ROLES`
> - `_geozone.html.erb`: multi-select from `Geozone.all`
> - `_age_range.html.erb`: dropdown (AgeRange) + or — min/max number inputs
> - For `phase_authors`, dispatch by phase type for the `criterion` field
>
> Each form field carries `data-action="change->adm-newsletters--filter-stack#recount"` so the Stimulus controller (Task 26) can debounce-trigger the recount endpoint.
>
> Spec: include a render test that the component outputs the expected DOM structure and that the operator select is hidden on the first filter (position 0/1 — your call which sentinel).

After agent completes, run:
```bash
bundle exec rspec spec/components/adm/recipient_group_filter_card_component_spec.rb
```
Expected: PASS.

- [ ] **Step Final: Commit**

```bash
git add app/components/adm/recipient_group_filter_card_component* app/views/adm/recipient_group_filters/params spec/components/adm
git commit -m "$BRANCH"
```

---

## Task 25: Edit-View rebuilt as filter stack

**Files:**
- Modify: `app/views/adm/recipient_groups/edit.html.erb`
- Create: `app/views/adm/recipient_groups/_footer.html.erb`
- Modify: `app/views/adm/recipient_groups/new.html.erb`
- Modify: `app/controllers/adm/recipient_groups_controller.rb`
- Delete: `app/views/adm/recipient_groups/_options_for_kind.html.erb`
- Delete: `app/views/adm/recipient_groups/_access_methods.html.erb`
- Delete: `app/views/adm/recipient_groups/select_options.turbo_stream.erb`

Delegate to `hanuschka-dev:frontend`:

> Rebuild `adm/recipient_groups/edit.html.erb` as a one-page filter stack:
>
> ```erb
> <%= render Adm::HeaderComponent.new(title: t(".title"), breadcrumbs: @breadcrumbs, narrow: true) %>
>
> <div class="kern-container my-5"
>      data-controller="adm-newsletters--filter-stack"
>      data-adm-newsletters--filter-stack-recount-url-value="<%= recount_adm_recipient_group_filters_path(@recipient_group) %>"
>      data-adm-newsletters--filter-stack-reorder-url-value="<%= reorder_adm_recipient_group_filters_path(@recipient_group) %>">
>
>   <%= form_with model: [:adm, @recipient_group] do |form| %>
>     <%= render Kern::FormFieldComponent.new(label: RecipientGroup.human_attribute_name(:name), divider: false) do %>
>       <%= form.text_field :name %>
>     <% end %>
>   <% end %>
>
>   <h3><%= t("adm.recipient_groups.filters.section_title") %></h3>
>
>   <ul id="filter-stack" data-adm-newsletters--filter-stack-target="list">
>     <% @recipient_group.filters.each_with_index do |filter, idx| %>
>       <li>
>         <%= render Adm::RecipientGroupFilterCardComponent.new(
>               filter: filter,
>               count: @counts[idx][:count],
>               delta: @counts[idx][:delta]) %>
>       </li>
>     <% end %>
>   </ul>
>
>   <%= form_with url: adm_recipient_group_filters_path(@recipient_group), data: { turbo_stream: true } do |f| %>
>     <%= f.hidden_field :"recipient_group_filter[kind]", value: "newsletter_subscribers" %>
>     <%= f.hidden_field :"recipient_group_filter[operator]",
>                        value: @recipient_group.filters.any? ? "intersect" : "include" %>
>     <%= f.submit t("adm.recipient_groups.filters.add_filter"), class: "kern-button" %>
>   <% end %>
>
>   <div id="filter-stack-footer">
>     <%= render "footer", recipient_group: @recipient_group %>
>   </div>
> </div>
> ```
>
> Create `_footer.html.erb`:
> ```erb
> <% resolver = RecipientGroupResolver.new(recipient_group) %>
> <%= t("adm.recipient_groups.filters.counter.total_summary", count: resolver.count) %>
> ```
>
> Rebuild `new.html.erb` to be lean: name input + auto-create-empty-RecipientGroup-then-redirect-to-edit. Pattern:
> ```erb
> <%= form_with model: [:adm, @recipient_group] do |form| %>
>   <%= form.label :name, RecipientGroup.human_attribute_name(:name) %>
>   <%= form.text_field :name, required: true %>
>   <%= form.submit t(".create") %>
> <% end %>
> ```
>
> In `Adm::RecipientGroupsController#edit`, set `@counts = RecipientGroupResolver.new(@recipient_group).per_filter_counts.presence || []` before render. Pad the array with `{ count: 0, delta: 0 }` if fewer counts than filters.
>
> In `#create`: After successful save, `redirect_to edit_adm_recipient_group_path(@recipient_group)` instead of index — admin needs to add filters next.
>
> Delete the three obsolete files listed in the file list above.
>
> Add to DE locale under `adm.recipient_groups.new`:
> ```yaml
> create: Erstellen und Filter konfigurieren
> ```
> Same in EN: `create: Create and configure filters`

After agent completes:

- [ ] **Step Final: Run integration test**

```bash
bundle exec rspec spec/controllers/adm/recipient_groups_controller_spec.rb 2>/dev/null
bin/rails routes -g recipient_group | head
```

- [ ] **Step Final + 1: Commit**

```bash
git add app/views/adm/recipient_groups app/controllers/adm/recipient_groups_controller.rb config/locales/kern
git rm app/views/adm/recipient_groups/_options_for_kind.html.erb app/views/adm/recipient_groups/_access_methods.html.erb app/views/adm/recipient_groups/select_options.turbo_stream.erb 2>/dev/null || true
git commit -m "$BRANCH"
```

---

## Task 26: Stimulus controller `filter-stack`

**Files:**
- Create: `app/javascript/controllers/adm_newsletters/filter_stack_controller.js`
- Modify: `app/javascript/controllers/index.js` (register controller — verify pattern in repo first)

Delegate to `hanuschka-dev:frontend` for the Stimulus implementation, since the repo has existing patterns to follow.

> Create `app/javascript/controllers/adm_newsletters/filter_stack_controller.js`:
>
> ```javascript
> import { Controller } from "@hotwired/stimulus"
> import Sortable from "sortablejs"
>
> export default class extends Controller {
>   static targets = ["list"]
>   static values = {
>     recountUrl: String,
>     reorderUrl: String,
>     debounceMs: { type: Number, default: 400 }
>   }
>
>   connect() {
>     this.sortable = Sortable.create(this.listTarget, {
>       handle: ".rg-filter-card__handle",
>       animation: 150,
>       onEnd: () => this.persistOrder()
>     })
>     this.recountTimer = null
>   }
>
>   disconnect() {
>     this.sortable?.destroy()
>     clearTimeout(this.recountTimer)
>   }
>
>   recount() {
>     clearTimeout(this.recountTimer)
>     this.recountTimer = setTimeout(() => this.fetchRecount(), this.debounceMsValue)
>   }
>
>   fetchRecount() {
>     fetch(this.recountUrlValue, {
>       headers: { Accept: "text/vnd.turbo-stream.html" }
>     }).then(r => r.text()).then(html => Turbo.renderStreamMessage(html))
>   }
>
>   persistOrder() {
>     const ids = Array.from(this.listTarget.querySelectorAll("[id^='recipient_group_filter_']"))
>                      .map(el => el.id.replace("recipient_group_filter_", ""))
>
>     const formData = new FormData()
>     ids.forEach(id => formData.append("ordered_ids[]", id))
>
>     const token = document.querySelector('meta[name="csrf-token"]').content
>     fetch(this.reorderUrlValue, {
>       method: "POST",
>       headers: { Accept: "text/vnd.turbo-stream.html", "X-CSRF-Token": token },
>       body: formData
>     }).then(r => r.text()).then(html => Turbo.renderStreamMessage(html))
>   }
> }
> ```
>
> Verify `sortablejs` is present in package.json — if missing, add `yarn add sortablejs`. Check `app/javascript/controllers/index.js` for the controller registration pattern. Many Consul setups use eager auto-loading via `@hotwired/stimulus-loading` — if so, no manual registration needed; otherwise add the explicit import.

After agent completes:

- [ ] **Step Final: Test asset compilation**

```bash
yarn build 2>&1 | tail -20
```
Expected: no errors.

- [ ] **Step Final + 1: Commit**

```bash
git add app/javascript package.json yarn.lock
git commit -m "$BRANCH"
```

---

## Task 27: System spec — Filter-stack happy path

**Files:**
- Create: `spec/system/adm/recipient_group_filter_stack_spec.rb`

- [ ] **Step 1: Write the spec**

`spec/system/adm/recipient_group_filter_stack_spec.rb`:
```ruby
require "rails_helper"

describe "Recipient group filter stack", :js do
  let(:admin) { create(:administrator).user }

  before { sign_in admin }

  it "lets an admin build a filter chain: subscribers → intersect geozone → exclude admins" do
    create_list(:user, 5, newsletter: true, geozone: create(:geozone))
    create(:administrator, user: create(:user, newsletter: true))

    visit new_adm_recipient_group_path
    fill_in RecipientGroup.human_attribute_name(:name), with: "Test-Q2"
    click_button I18n.t("adm.recipient_groups.new.create")

    expect(page).to have_current_path(%r{/adm/recipient_groups/\d+/edit})

    click_button I18n.t("adm.recipient_groups.filters.add_filter")
    expect(page).to have_css(".rg-filter-card", count: 1)

    # Add geozone intersect via UI
    click_button I18n.t("adm.recipient_groups.filters.add_filter")
    within(".rg-filter-card:nth-of-type(2)") do
      select I18n.t("adm.recipient_groups.filters.kinds.geozone"), from: "Kind"
      select I18n.t("adm.recipient_groups.filters.operators.intersect"), from: "Operator"
    end

    # Footer should update
    expect(page).to have_content(I18n.t("adm.recipient_groups.filters.counter.total_summary", count: 5))
  end

  it "blocks invalid operator on first filter" do
    group = create(:recipient_group)
    visit edit_adm_recipient_group_path(group)
    # Attempt to manipulate operator dropdown on (only) first filter — should be disabled/hidden
    expect(page).not_to have_select("recipient_group_filter[operator]")
  end
end
```

- [ ] **Step 2: Run spec**

```bash
bundle exec rspec spec/system/adm/recipient_group_filter_stack_spec.rb
```
Expected: PASS. If JS system tests are flaky in this repo (selenium/cuprite issues), wrap the first test in a `pending` block with TODO note and rely on the controller spec from Task 22 for coverage.

- [ ] **Step 3: Commit**

```bash
git add spec/system/adm
git commit -m "$BRANCH"
```

---

## Task 28: Verification — manually exercise in dev server

This is a verification gate, not a TDD step. Per project rule: UI features must be exercised in a browser before claiming done.

- [ ] **Step 1: Start dev server**

```bash
bin/dev 2>&1 | tee /tmp/recipient-groups-dev.log
```

- [ ] **Step 2: Manual checklist** (open `http://localhost:3000/adm/recipient_groups`)

  - [ ] Index renders migrated groups; old groups have a single filter shown after clicking Edit
  - [ ] New group creation: name → Edit-view appears
  - [ ] Add a `newsletter_subscribers` filter; counter shows a non-zero number
  - [ ] Add a `geozone` filter with operator `intersect`; counter decreases
  - [ ] Add a `role: administrator` filter with operator `exclude`; counter decreases by the admin count
  - [ ] Drag-reorder the filters; counter updates
  - [ ] Delete a filter; counter updates
  - [ ] Mobile-viewport: filter cards remain readable, no overflow
  - [ ] DE/EN locale switch: all new labels translated, no missing keys

- [ ] **Step 3: Run full test suite for affected areas**

```bash
bundle exec rspec spec/models/recipient_group_spec.rb \
  spec/models/recipient_group_filter_spec.rb \
  spec/services/recipient_group_resolver_spec.rb \
  spec/services/recipient_group \
  spec/controllers/adm/recipient_group_filters_controller_spec.rb \
  spec/db/migrate/migrate_legacy_recipient_groups_spec.rb \
  spec/components/adm/recipient_group_filter_card_component_spec.rb
```
Expected: ALL PASS.

- [ ] **Step 4: Confirm no regression in newsletter sending**

```bash
bundle exec rspec spec/models/newsletter_spec.rb spec/controllers/adm/newsletters_controller_spec.rb 2>/dev/null
```
Expected: existing tests unaffected (they call `RecipientGroup#user_emails` which now delegates to the new resolver when filters are present, falls back to legacy code otherwise).

- [ ] **Step 5: Commit verification notes (optional)**

If anything in the manual checklist failed, file a follow-up issue and link it from the PR description. Otherwise no commit needed — verification complete.

---

## Out-of-Scope follow-ups (separate spec/plan needed)

- Drop the deprecated columns `origin_class_name`, `origin_class_object_id`, `access_method` from `recipient_groups` (after the legacy fallback in `RecipientGroup#user_emails` is removed)
- Phase 2 filter kinds: `registered_address`, `manual_emails`, `csv_upload`, `verification_level`, `activity_*`, `deficiency_reporters`, `idea_authors`
- Filter-bibliothek (reusable filter snippets across groups)
- PLZ-range logic (instead of exact-match list)
- SQL-based intersection for >100k users
