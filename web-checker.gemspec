#encoding: utf-8

require_relative 'lib/web-checker/version'

Gem::Specification.new do |s|
  s.name          = 'web-checker'
  s.version       = WebChecker::VERSION
  s.summary       = 'Check static websites for consistency.'
  s.author        = 'John Labovitz'
  s.email         = 'johnl@johnlabovitz.com'
  s.description   = %q{
    WebChecker checks static websites for consistency.
  }
  s.license       = 'MIT'
  s.homepage      = 'http://github.com/jslabovitz/web-checker'
  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  s.require_path  = 'lib'

  s.add_dependency 'addressable', '~> 2'
  s.add_dependency 'http', '~> 4'
  s.add_dependency 'nokogiri', '~> 1'
  s.add_dependency 'nokogumbo', '~> 2'
  s.add_dependency 'path', '~> 2'

  s.add_development_dependency 'rake', '~> 12'
  s.add_development_dependency 'rubygems-tasks', '~> 0.2'
end