# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'smartware/version'

Gem::Specification.new do |gem|
  gem.name          = "smartware"
  gem.version       = Smartware::VERSION
  gem.authors       = ["Evgeni Sudarchikov", "Boris Staal"]
  gem.email         = ["e.sudarchikov@roundlake.ru", "boris@roundlake.ru"]
  gem.description   = %q{Smartware is the Smartkiosk hardware control daemon}
  gem.summary       = gem.description
  gem.homepage      = "https://github.com/roundlake/smartware"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency 'smartkiosk-common', '>= 0.0.2'
  gem.add_dependency 'serialport'
  gem.add_dependency 'cmux', '>= 0.0.2'
  gem.add_dependency 'trollop'
  gem.add_dependency 'activesupport'
  gem.add_dependency 'redcarpet'
  gem.add_dependency 'digest-crc'
end
