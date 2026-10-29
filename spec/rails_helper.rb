ENV["RAILS_ENV"] ||= "test"
if ENV["COVERALLS_REPO_TOKEN"]
  require "coveralls"
  Coveralls.wear!("rails")
end
require File.expand_path("../../config/environment", __FILE__)
abort("The Rails environment is running in production mode!") if Rails.env.production?

require "rspec/rails"
require "spec_helper"
require "capybara/rails"
require "capybara/rspec"
require "selenium/webdriver"
require "view_component/test_helpers"

module ViewComponent
  module TestHelpers
    def sign_in(user)
      allow(vc_test_controller).to receive(:current_user).and_return(user)
    end

    def within(...)
      raise "`within` doesn't work in component tests. Use `page.find` instead."
    end
  end
end

module ActiveJob
  module TestHelper
    # Rails 7.2 keeps the configured delayed_job adapter in tests that include
    # this helper; give them the test adapter like earlier Rails versions did.
    # Other specs keep running jobs inline through delayed_job.
    def queue_adapter_for_test
      ActiveJob::QueueAdapters::TestAdapter.new
    end
  end
end

RSpec.configure do |config|
  config.include ViewComponent::TestHelpers, type: :component
end

Rails.application.load_tasks if Rake::Task.tasks.empty?

include Warden::Test::Helpers
Warden.test_mode!

ActiveRecord::Migration.maintain_test_schema!

RSpec.configure do |config|
  config.infer_spec_type_from_file_location!
  config.after do
    Warden.test_reset!
  end
end

FactoryBot.use_parent_strategy = false

Capybara.register_driver :headless_chrome do |app|
  options = Selenium::WebDriver::Options.chrome
  options.add_argument("--headless=new")
  options.add_argument("--no-sandbox")
  options.add_argument("--disable-dev-shm-usage")
  options.add_argument("--window-size=1200,800")

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

Capybara.exact = true
Capybara.enable_aria_label = true
Capybara.disable_animation = true

OmniAuth.config.test_mode = true

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
