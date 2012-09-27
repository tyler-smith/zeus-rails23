$:.unshift File.join(__FILE__, '..', 'lib')
require "zeus-rails-2-3/version"

Gem::Specification.new do |s|
  s.name        = "zeus-rails-2-3"
  s.version     = ::Zeus::Rails23::VERSION
  s.authors     = ["Tyler Smith"]
  s.email       = 'tylersmith.me@gmail.com'
  s.homepage    = 'http://tylersmith.me'
  s.summary     = %q{Rails 2.3 support for Zeus}
  s.description = %q{Provides a Zeus plan for Rails 2.3 - partially working}

  s.files         = `git ls-files`.split("\n")
  s.require_paths = ["lib"]

  s.add_runtime_dependency 'zeus'
end