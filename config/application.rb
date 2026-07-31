require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Cmbpayroll
  class Application < Rails::Application
    # Initialize configuration defaults. Walked forward deliberately from the
    # originally generated 5.1, one setting at a time, via the
    # new_framework_defaults_*.rb initializers (see upgrade notes) -- now
    # that every 5.2/6.0/6.1 setting has been individually reviewed and
    # enabled, load_defaults 6.1 here is redundant with them, not a new
    # behavior change.
    config.load_defaults 6.1

    # load_defaults 6.1 above already implies zeitwerk; kept explicit for
    # visibility since adopting it was a deliberate decision (see upgrade
    # notes), made once `zeitwerk:check` passed clean.
    config.autoloader = :zeitwerk

    # Load modules from lib
    config.autoload_paths << Rails.root.join('lib')
    config.eager_load_paths << Rails.root.join('lib')

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
