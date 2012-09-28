ROOT_PATH = File.expand_path(Dir.pwd)
ENV_PATH  = File.expand_path('config/environment',  ROOT_PATH)
BOOT_PATH = File.expand_path('config/boot',  ROOT_PATH)

require 'zeus'

module Zeus::Rails23
  class Plan < Zeus::Plan
    def boot
      require BOOT_PATH
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

    def test_environment
      $rails_rake_task = 'yup' # lie to skip eager loading
      load_env('test')
      $rails_rake_task = nil
      load_bundler_env :test
      _monkeypatch_rake

      $LOAD_PATH.unshift ".", "./lib", "./test", "./spec"
    end

  protected
    def load_env(env)
      ENV['RAILS_ENV'] = env
      require ENV_PATH
      ::Rails.instance_eval do
        @_env = ::ActiveSupport::StringInquirer.new(env)
      end
    end

    def load_bundler_env(env)
      env = env.to_sym
      @bundler ||= {}
      @bundler[:default] ||= !!::Bundler.require(:default)
      @bundler[env] ||= !!::Bundler.require(env)
    end
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
end

Zeus.plan = Zeus::Rails23::Plan.new