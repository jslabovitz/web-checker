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

  s.add_dependency 'addressable', '~> 2.8'
  s.add_dependency 'http', '~> 5.0'
  s.add_dependency 'nokogiri', '~> 1.12'
  s.add_dependency 'path', '~> 2.0'

  s.add_development_dependency 'rake', '~> 13.0'
end