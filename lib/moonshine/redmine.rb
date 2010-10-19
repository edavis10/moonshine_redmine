module Moonshine
  module Redmine

    # Define options for this plugin in your moonshine.yml
    #
    #   :redmine_email_yml:
    #     :production:
    #       :delivery_method: :async_sendmail
    #
    # Then include the plugin and call the recipe(s) you need:
    #
    #  recipe :redmine_email_yml
    #
    def redmine_email_yml(options = {})
      file("#{rails_root}/config/email.yml",
           :ensure => :present,
           :content => moonshine_stringify_keys(configuration[:redmine_email_yml]).to_yaml,
           :before => exec('rake tasks'))
    end

    # Then include the plugin and call the recipe(s) you need:
    #
    #  recipe :redmine_plugin_migrations
    #
    def redmine_plugin_migrations(options = {})
      rake 'db:migrate_plugins'
    end
    
    # Helper, since Rails' version isn't loading in time
    def moonshine_stringify_keys(h)
      h.inject({}) do |options, (key, value)|
        options[key.to_s] = value
        options
      end
    end

  end
end
