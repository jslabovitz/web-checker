#encoding: utf-8

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'web-checker'

Gem::Specification.new do |s|
  s.name          = 'web-checker'
  s.version       = WebChecker::Version
  s.summary       = 'Check static websites for consistency.'
  s.author        = 'John Labovitz'
  s.email         = 'johnl@johnlabovitz.com'
  s.description   = %q{
    WebChecker checks static websites for consistency.
  }
  s.homepage      = 'http://github.com/jslabovitz/web-checker'
  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_path  = 'lib'

  s.add_dependency 'addressable'
  s.add_dependency 'nokogiri'
  s.add_dependency 'path'
  s.add_dependency 'tidy_ffi'

  s.add_development_dependency 'bundler'
  s.add_development_dependency 'rake'
end