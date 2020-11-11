lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'kitchen/driver/ovirt_version'

Gem::Specification.new do |spec|
  spec.name          = 'kitchen-ovirt'
  spec.version       = Kitchen::Driver::OVIRT_VERSION
  spec.authors       = ['Yusuke Fujimaki']
  spec.email         = ['usk.fujimaki@gmail.com']

  spec.summary       = 'kitchen driver for oVirt'
  spec.description   = 'kitchen driver for oVirt'
  spec.homepage      = 'https://github.com/uskf'
  spec.license       = 'Apache-2.0'

  spec.files         = Dir['LICENSE', 'README.md', 'lib/**/*']
  spec.require_paths = ['lib']

  spec.add_dependency 'ovirt-engine-sdk', '>= 4.3.0'
  spec.add_dependency 'test-kitchen'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
end
