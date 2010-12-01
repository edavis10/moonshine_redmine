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

    # Symlink Redmine file uploads to the shared directory
    #
    #  recipe :redmine_file_uploads
    #
    def redmine_file_uploads
      file("#{rails_root}/files/delete.me",
           :ensure => :absent)

      file("#{configuration[:deploy_to]}/shared/files",
           :ensure => :directory)

      file("#{rails_root}/files",
           :ensure => :link,
           :target => "#{configuration[:deploy_to]}/shared/files")
    end

    # Install the subversion client needed for repository reads
    #
    #   recipe :redmine_subversion_client
    #
    def redmine_subversion_client
      package :subversion, :ensure => :installed
      package "subversion-tools", :ensure => :installed
    end

    # Install the git client needed for repository reads
    #
    #   recipe :redmine_git_client
    #
    def redmine_git_client
      package "git-core", :ensure => :installed
    end

    # TODO: more recipes for other SCM tools

    # Schedules the cronjob for fetching the SCM changesets
    #
    # Configure the fetching time in moonshine.yml. All fields
    # default to * so make sure to set something (or it will run every minute)
    #
    #   :redmine:
    #     :fetch_changesets:
    #       :minute: '*/10'
    #       :hour:   '*'
    #       :month:  '*'
    #
    def redmine_fetch_changesets
      if configuration[:redmine] && configuration[:redmine][:fetch_changesets]
        minute = configuration[:redmine][:fetch_changesets][:minute]
        hour = configuration[:redmine][:fetch_changesets][:hour]
        month = configuration[:redmine][:fetch_changesets][:month]
      end
      minute ||= '*'
      hour   ||= '*'
      month  ||= '*'

      fetch_task = "/usr/bin/rake -f #{configuration[:deploy_to]}/current/Rakefile redmine:fetch_changesets RAILS_ENV=#{ENV['RAILS_ENV']}"
      cron 'redmine:fetch_changesets', :command => fetch_task, :user => configuration[:user], :minute => minute, :hour => hour, :month => month
    end

    # Schedules the cronjob for updating caching values in the redmine_rate plugin
    #
    # Configure the fetching time in moonshine.yml. All fields
    # default to * so make sure to set something (or it will run every minute)
    #
    #   :redmine:
    #     :redmine_rate:
    #       :update_cost_cache:
    #         :minute: '*/10'
    #         :hour:   '*'
    #         :month:  '*'
    #
    def redmine_rate_cache_update
      if configuration[:redmine] && configuration[:redmine][:redmine_rate] && configuration[:redmine][:redmine_rate][:update_cost_cache]
        cache_config = configuration[:redmine][:redmine_rate][:update_cost_cache]
        minute = cache_config[:minute]
        hour = cache_config[:hour]
        month = cache_config[:month]
      end
      minute ||= '*'
      hour   ||= '*'
      month  ||= '*'

      update_task = "/usr/bin/rake -f #{configuration[:deploy_to]}/current/Rakefile rate_plugin:cache:update_cost_cache RAILS_ENV=#{ENV['RAILS_ENV']}"
      cron 'redmine:rate_plugin:cache:update_cost_cache', :command => update_task, :user => configuration[:user], :minute => minute, :hour => hour, :month => month
    end

    # Schedules the cronjob for refreshing caching values in the redmine_rate plugin
    #
    # Configure the fetching time in moonshine.yml. All fields
    # default to * so make sure to set something (or it will run every minute)
    #
    #   :redmine:
    #     :redmine_rate:
    #       :refresh_cost_cache:
    #         :minute: '10'
    #         :hour:   '0'
    #         :month:  '*'
    #
    def redmine_rate_cache_refresh
      if configuration[:redmine] && configuration[:redmine][:redmine_rate] && configuration[:redmine][:redmine_rate][:refresh_cost_cache]
        cache_config = configuration[:redmine][:redmine_rate][:refresh_cost_cache]
        minute = cache_config[:minute]
        hour = cache_config[:hour]
        month = cache_config[:month]
      end
      minute ||= '*'
      hour   ||= '*'
      month  ||= '*'

      update_task = "/usr/bin/rake -f #{configuration[:deploy_to]}/current/Rakefile rate_plugin:cache:refresh_cost_cache RAILS_ENV=#{ENV['RAILS_ENV']}"
      cron 'redmine:rate_plugin:cache:refresh_cost_cache', :command => update_task, :user => configuration[:user], :minute => minute, :hour => hour, :month => month
    end


    # Schedules the cronjob for fetching email via IMAP
    #
    # Configure the fetching in moonshine.yml. All fields default to * so
    # make sure to set something (or it will run every minute).
    #
    #   :redmine:
    #     :receive_imap
    #       :host: 'imap.example.com'
    #       :username: 'redmine@example.com'
    #       :password: 'littlestreamsoftware'
    #       :minute: '10'
    #       :hour:   '0'
    #       :month:  '*'
    #
    def redmine_receive_imap
      if configuration[:redmine] && configuration[:redmine][:receive_imap]
        imap_config = configuration[:redmine][:receive_imap]

        host = imap_config[:host]
        username = imap_config[:username]
        password = imap_config[:password]
        minute = imap_config[:minute]
        hour = imap_config[:hour]
        month = imap_config[:month]
      end
      host ||= 'localhost'
      username ||= configuration[:user]
      password ||= ''
      minute ||= '*'
      hour   ||= '*'
      month  ||= '*'

      imap_task = "/usr/bin/rake -f #{configuration[:deploy_to]}/current/Rakefile redmine:email:receive_imap RAILS_ENV=#{ENV['RAILS_ENV']} host='#{host}' username='#{username}' password='#{password}'"
      cron 'redmine:receive_imap', :command => imap_task, :user => configuration[:user], :minute => minute, :hour => hour, :month => month
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
