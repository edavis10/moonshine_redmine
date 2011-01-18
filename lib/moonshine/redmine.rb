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
      file("#{configuration[:deploy_to]}/shared/files",
           :ensure => :directory)

      file("#{rails_root}/files",
           :force => true,
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

    # Sets up the Advanced SVN Management with Redmine (reposman.rb)
    #
    #  recipe :redmine_repository_management
    def redmine_repository_management
      redmine_option = if configuration[:ssl]
                         "https://"
                       else
                         "http://"
                       end
      redmine_option += configuration[:domain]

      file(svn_dir,
           :ensure => :directory,
           :group => 'www-data',
           :owner => 'root',
           :mode => '750')
      
      reposman_command = "/usr/bin/ruby #{configuration[:deploy_to]}/current/extra/svn/reposman.rb --redmine #{redmine_option} --svn-dir #{svn_dir} --owner www-data --url #{svn_url}"

      cron 'redmine:repository_management', :command => reposman_command, :user => 'root', :minute => '*/15'

    end

    # Sets up the Advanced SVN Access Control with Redmine (Redmine.pm)
    #
    #   recipe :redmine_repository_access_control
    def redmine_repository_access_control
      package "libapache2-svn", :ensure => :installed
      package "libapache-dbi-perl", :ensure => :installed
      package "libapache2-mod-perl2", :ensure => :installed
      package "libdbd-mysql-perl", :ensure => :installed
      package "libdigest-sha1-perl", :ensure => :installed
      package "libauthen-simple-ldap-perl", :ensure => :installed

      exec("a2enmod dav")
      exec("a2enmod dav_svn")
      exec("a2enmod dav_fs")
      exec("a2enmod perl")

      file("/usr/lib/perl5/Apache/Redmine.pm",
           :ensure => :link,
           :target => "#{rails_root}/extra/svn/Redmine.pm")

      recipe :redmine_svn_host
    end

    # Sets up the Advanced SVN Integration with Redmine
    #
    #  recipe :redmine_advanced_svn_integration
    def redmine_advanced_svn_integration
      recipe :redmine_repository_management
      recipe :redmine_repository_access_control
    end


    # SVN helpers
    #

    # Creates an Apache2 vhost for SVN, with optional SSL suport
    def redmine_svn_host
      file("/srv/#{svn_host}",
           :ensure => :directory,
           :owner => configuration[:user])


      file "/etc/apache2/sites-available/#{svn_host}",
      :ensure => :present,
      :content => template(File.join(File.dirname(__FILE__), 'templates', 'svn.vhost.erb')),
      :notify => service("apache2"),
      :require => file("/srv/#{svn_host}")

      a2ensite svn_host
    end

    # Generates the url to use for the svn vhost
    def svn_url
      if svn_ssl?
        "https://#{svn_host}/#{svn_path}"
      else
        "http://#{svn_host}/#{svn_path}"
      end
    end

    # Is the svn vhost using ssl?
    def svn_ssl?
      if configuration[:redmine] && configuration[:redmine][:repository_management] && configuration[:redmine][:repository_management][:svn_ssl]
        true
      else
        false
      end
    end

    # Generates the hostname for the svn vhost
    # Defaults to the main domain
    def svn_host
      host = configuration[:redmine][:repository_management][:svn_host] if configuration[:redmine] && configuration[:redmine][:repository_management]
      host ||= configuration[:domain]
    end

    # Generates the url path to the svn repositories
    # Defaults to /svn/
    def svn_path
      path = configuration[:redmine][:repository_management][:svn_path] if configuration[:redmine] && configuration[:redmine][:repository_management]
      path ||= '/svn/'
    end

    # Generates the dedicated ip address to use for the svn vhost
    # Defaults to the ipaddress found by Facter
    def svn_ip_address
      ip = configuration[:redmine][:repository_management][:svn_ip_address] if configuration[:redmine] && configuration[:redmine][:repository_management]
      ip ||= Facter.to_hash['ipaddress']
    end

    # Generates the filesystem path to the svn repositories
    # Defaults to /var/svn
    def svn_dir
      svn_dir = configuration[:redmine][:repository_management][:svn_directory] if configuration[:redmine] && configuration[:redmine][:repository_management]
      svn_dir ||= '/var/svn'
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
