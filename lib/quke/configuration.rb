require 'yaml'

module Quke #:nodoc:

  # Manages all configuration for Quke.
  class Configuration

    # Access where the config file was loaded from for this instance of
    # Quke::Configuration.
    attr_reader :file_location

    # Access the loaded config data object directly.
    attr_reader :data

    # Instance of +Quke::BrowserstackConfiguration+ which manages reading and
    # returning the config for setting up Quke to use browserstack.
    attr_reader :browserstack

    class << self
      # Class level setter for the location of the config file.
      #
      # There will only be one for each execution of Quke and it does not
      # support reading from another during execution. Hence we write this to
      # the class level and all instances of Quke::Configuration then inherit
      # this value.
      attr_writer :file_location
    end

    # Returns the expected root location of where Quke expects to find the
    # the config file.
    def self.file_location
      @file_location ||= "#{Dir.pwd}/#{file_name}"
    end

    # Return the file name for the config file, either as set by the user in
    # an environment variable called `QCONFIG` or the default of +.config.yml+.
    def self.file_name
      ENV['QUKE_CONFIG'] || '.config.yml'
    end

    # When an instance is initialized it will automatically populate itself by
    # calling a private method +load_data()+.
    def initialize
      @data = load_data
      @browserstack = ::Quke::BrowserstackConfiguration.new(self)
    end

    # Returns the value set for +features_folder+.
    #
    # This will be passed to Cucumber by Quke when it executes the tests. It
    # tells Cucumber where the main features folder which contains the tests is
    # located. If not set in the +.config.yml+ file it defaults to 'features'.
    def features_folder
      @data['features_folder']
    end

    # Returns the value set for +app_host+.
    #
    # Normally Capybara expects to be testing an in-process Rack application,
    # but Quke is designed to talk to a remote host. Users of Quke can set
    # what this will be by setting +app_host+ in their +.config.yml+ file.
    # Capybara will then combine this with links you provide.
    #
    #     visit('/Main_Page')
    #     visit('/')
    #
    # This saves you from having to repeat the full url each time.
    def app_host
      @data['app_host']
    end

    # Returns the value set for +driver+.
    #
    # Tells Quke which browser to use for testing. Choices are firefox,
    # chrome browserstack and phantomjs, with the default being phantomjs.
    def driver
      @data['driver']
    end

    # Return the value set for +pause+.
    #
    # Add a pause (in seconds) between steps so you can visually track how the
    # browser is responding. Only useful if using a non-headless browser. The
    # default is 0.
    def pause
      @data['pause']
    end

    # Return the value set for +stop_on_error+.
    #
    # Specify whether Quke should stop all tests once an error occurs. Useful in
    # Continuous Integration (CI) environments where a quick Yes/No is
    # preferable to a detailed response.
    def stop_on_error
      # This use of Yaml.load to convert a string to a boolean comes from
      # http://stackoverflow.com/a/21804027/6117745
      YAML.load(@data['stop_on_error'])
    end

    # Return the value for +max_wait_time+
    #
    # +max_wait_time+ is the time Capybara will spend waiting for an element
    # to appear. It's default is normally 2 seconds but you may want to increase
    # this is you are having to deal with a site that is not performant or prone
    # to delays.
    #
    # If the value is not set in config file, it will default to whatever is the
    # current Capybara value for default_max_wait_time.
    def max_wait_time
      @data['max_wait_time']
    end

    # Return the value set for +user_agent+.
    #
    # Useful if you want the underlying driver to spoof what kind of browser the
    # request is coming from. For example you may want to pretend to be a mobile
    # browser so you can check what you get back versus the desktop version. Or
    # you want to pretend to be another kind of browser, because the one you
    # have is not supported by the site.
    def user_agent
      @data['user_agent']
    end

    # Return the value set for +javascript_errors+.
    #
    # Currently only supported when using the phantomjs driver (ignored by the
    # others). In phantomjs if a site has a javascript error we can configure it
    # to throw an error which will cause the test to fail. Quke by default sets
    # this to true, however you can override it by setting this flag to false.
    # For example you may be dealing with a legacy site and JavaScript errors
    # are out of your scope. You still want to test other aspects of the site
    # but not let these errors prevent you from using phantomjs.
    def javascript_errors
      @data['javascript_errors']
    end

    # Return the hash of +proxy+ server settings
    #
    # If your environment requires you to go via a proxy server you can
    # configure Quke to use it by setting the +host+ and +port+ in your config
    # file.
    def proxy
      @data['proxy']
    end

    # Return true if the +proxy: host+ value has been set in the +.config.yml+
    # file, else false.
    #
    # It is mainly used when determining whether to apply proxy server settings
    # to the different drivers when registering them with Capybara.
    def use_proxy?
      proxy['host'] != ''
    end

    # Return the hash of +custom+ server settings
    #
    # This returns a hash of all the key/values in the custom section of your
    # +.config.yml+ file. You can then access it in your steps/page objects with
    #
    #     Quke::Quke.config.custom["default_org_name"] # = "Testy Ltd"
    #     Quke::Quke.config.custom["accounts"]["account2"]["username"] # = "john.doe@example.gov.uk"
    #     Quke::Quke.config.custom["urls"]["front_office"] # = "http://myservice.service.gov.uk"
    #
    # As long as what you add is valid YAML (check with a tool like
    # http://www.yamllint.com/) Quke will be able to pick it up and make it
    # available in your tests.
    def custom
      @data['custom']
    end

    private

    def load_data
      data = default_data!(load_yml_data)
      data['proxy'] = proxy_data(data['proxy'])
      data
    end

    # rubocop:disable Metrics/AbcSize
    # rubocop:disable Metrics/CyclomaticComplexity
    # rubocop:disable Metrics/PerceivedComplexity
    def default_data!(data)
      data.merge(
        'features_folder' =>   (data['features'] || 'features').downcase.strip,
        'app_host' =>          (data['app_host'] || '').downcase.strip,
        'driver' =>            (data['driver'] || 'phantomjs').downcase.strip,
        'pause' =>             (data['pause'] || '0').to_s.downcase.strip.to_i,
        'stop_on_error' =>     (data['stop_on_error'] || 'false').to_s.downcase.strip,
        'max_wait_time' =>     (data['max_wait_time'] || Capybara.default_max_wait_time).to_s.downcase.strip.to_i,
        'user_agent' =>        (data['user_agent'] || '').strip,
        # Because we want to default to 'true', but allow users to override it
        # with 'false' it causes us to mess with the logic. Essentially if the
        # user does enter false (either as a string or as a boolean) the result
        # will be 'true', so we flip it back to 'false' with !.
        # Else the condition fails and we get 'false', which when flipped gives
        # us 'true', which is what we want the default value to be
        # rubocop:disable Style/InverseMethods
        'javascript_errors' => !(data['javascript_errors'].to_s.downcase.strip == 'false'),
        # rubocop:enable Style/InverseMethods
        'custom' =>            (data['custom'] || nil)
      )
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/CyclomaticComplexity
    # rubocop:enable Metrics/PerceivedComplexity

    def proxy_data(data)
      data = {} if data.nil?
      data.merge(
        'host' => (data['host'] || '').downcase.strip,
        'port' => (data['port'] || '0').to_s.downcase.strip.to_i,
        'no_proxy' => (data['no_proxy'] || '').downcase.strip
      )
    end

    def load_yml_data
      if File.exist? self.class.file_location
        # YAML.load_file returns false if the file exists but is empty. So
        # added the || {} to ensure we always return a hash from this method
        YAML.load_file(self.class.file_location) || {}
      else
        {}
      end
    end

  end

end
