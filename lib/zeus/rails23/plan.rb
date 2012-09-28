ROOT_PATH = File.expand_path(Dir.pwd)
ENV_PATH  = File.expand_path('config/environment',  ROOT_PATH)
BOOT_PATH = File.expand_path('config/boot',  ROOT_PATH)

require 'zeus'

module Zeus::Rails23
  class Plan < Zeus::Plan
    def boot
      require BOOT_PATH
    end

    def after_fork
      reconnect_activerecord
      restart_girl_friday
      reconnect_redis
    end

    def default_bundle;end

    def prerake
      require 'rake'
    end

    def rake
      Rake.application.run
    end

    def development_environment
      load_env('development')
      load_bundler_env :development

      @irb = begin
        require 'irb'
        ::IRB.instance_eval do
          @CONF[:LOAD_MODULES] ||= []
          @CONF[:LOAD_MODULES] << 'irb/completion'
          @CONF[:LOAD_MODULES] << '%( -r "#{RAILS_ROOT}/config/environment")'
          @CONF[:LOAD_MODULES] << 'console_app'
          @CONF[:LOAD_MODULES] << 'console_with_helpers'
        end

        IRB
      end
    end

    def server
      require 'commands/server'
    end

    def console
      @irb.start
    end

  protected
    def load_env(env)
      ENV['RAILS_ENV'] = env
      require ENV_PATH
      ::Rails.instance_eval{ @_env = ::ActiveSupport::StringInquirer.new(env) }
      load_bundler_env env
    end

    def load_bundler_env(env)
      @bundler ||= Hash.new{|hash, env| hash[env] = !!::Bundler.require(env) }
      @bundler[env.to_sym]
    end

    def _monkeypatch_rake
      require 'rake/testtask'
      Rake::TestTask.class_eval {

        # Create the tasks defined by this task lib.
        def define
          desc "Run tests" + (@name==:test ? "" : " for #{@name}")
          task @name do
            # ruby "#{ruby_opts_string} #{run_code} #{file_list_string} #{option_list}"
            rails_env = ENV['RAILS_ENV']
            rubyopt = ENV['RUBYOPT']
            ENV['RAILS_ENV'] = nil
            ENV['RUBYOPT'] = nil # bundler sets this to require bundler :|
            puts "zeus test #{file_list_string}"
            system "zeus test #{file_list_string}"
            ENV['RAILS_ENV'] = rails_env
            ENV['RUBYOPT'] = rubyopt
          end
          self
        end

        alias_method :_original_define, :define

        def self.inherited(klass)
          return unless klass.name == "TestTaskWithoutDescription"
          klass.class_eval {
            def self.method_added(sym)
              class_eval do
                if !@rails_hack_reversed
                  @rails_hack_reversed = true
                  alias_method :define, :_original_define
                  def desc(*)
                  end
                end
              end
            end
          }
        end
      }
    end

    def restart_girl_friday
      return unless defined?(GirlFriday::WorkQueue)
      # The Actor is run in a thread, and threads don't persist post-fork.
      # We just need to restart each one in the newly-forked process.
      ObjectSpace.each_object(GirlFriday::WorkQueue) do |obj|
        obj.send(:start)
      end
    end

    def reconnect_activerecord
      ActiveRecord::Base.clear_all_connections! rescue nil
      ActiveRecord::Base.establish_connection   rescue nil
    end

    def reconnect_redis
      return unless defined?(Redis::Client)
      ObjectSpace.each_object(Redis::Client) do |client|
        client.connect
      end
    end
  end
end

Zeus.plan = Zeus::Rails23::Plan.new