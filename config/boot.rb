$stdout.sync = true

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "logger" # Rails 6.1 needs it; concurrent-ruby 1.3.5+ stopped loading it
