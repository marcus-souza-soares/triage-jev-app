require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# jevalyn 0.1.0 appends app/decisions to autoload_paths from an initializer that runs
# after Rails has frozen that array, which raises FrozenError on boot. Rails already
# autoloads every directory under app/, so the initializer is redundant: drop it.
# Remove this once jevalyn registers it with `before: :set_autoload_paths`.
Jevalyn::Railtie.initializers.reject! { |initializer| initializer.name == "jevalyn.autoload_paths" }

module TriageApp
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    config.time_zone = "Brasilia"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
