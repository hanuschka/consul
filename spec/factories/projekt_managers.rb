FactoryBot.define do
  factory :projekt_manager do
    user
    manage_all_projekts { false }

    trait :manage_all do
      manage_all_projekts { true }
    end
  end

  # `permissions` is a free-form text array; any subset of
  # ProjektManagerAssignment::ACCEPTABLE_PERMISSIONS is valid and each grants a
  # different capability. It defaults to [] here, matching the column default —
  # pass the permissions the example is actually about, or use a trait.
  factory :projekt_manager_assignment do
    projekt
    projekt_manager
    permissions { [] }

    # Additive via after(:build) rather than by setting `permissions` directly,
    # so the traits compose: `create(:projekt_manager_assignment, :manage,
    # :review)` grants both. Attribute-setting traits would overwrite each
    # other and silently keep only the last one.
    ProjektManagerAssignment::ACCEPTABLE_PERMISSIONS.each do |permission|
      trait permission.to_sym do
        after(:build) { |assignment| assignment.permissions |= [permission] }
      end
    end

    trait :all_permissions do
      after(:build) do |assignment|
        assignment.permissions |= ProjektManagerAssignment::ACCEPTABLE_PERMISSIONS
      end
    end
  end
end
