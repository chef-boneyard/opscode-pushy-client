# -*- encoding: utf-8 -*-
require File.expand_path('../lib/pushy-client/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Mark Anderson"]
  gem.email         = ["mark@opscode.com"]
  gem.description   = %q{Client for opscode chef push jobs server}
  gem.summary       = %q{Client for opscode chef push jobs server}
  gem.homepage      = "https://github.com/opscode/opscode-pushy-client"

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "opscode-pushy-client"
  gem.require_paths = ["lib"]
  gem.version       = '0.0.1'
end
