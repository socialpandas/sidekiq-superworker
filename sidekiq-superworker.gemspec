require File.expand_path('../lib/sidekiq/superworker/version', __FILE__)

Gem::Specification.new do |s|
  s.authors       = ['Tom Benner']
  s.email         = ['tombenner@gmail.com']
  s.description = s.summary = %q{Chain together Sidekiq workers in parallel and/or serial configurations}
  s.homepage      = 'https://github.com/socialpandas/sidekiq-superworker'

  s.files         = Dir['{lib}/**/*'] + ['MIT-LICENSE', 'Rakefile', 'README.md']
  s.name          = 'sidekiq-superworker'
  s.require_paths = ['lib']
  s.version       = Sidekiq::Superworker::VERSION
  s.license       = 'MIT'

  s.add_dependency 'sidekiq', '>= 2.1.0'
  s.add_dependency 'activesupport', '>= 3.2'
  s.add_dependency 'activemodel', '>= 3.2'

  s.add_development_dependency 'appraisal'
  s.add_development_dependency 'rspec', '~> 2.12'
  s.add_development_dependency 'rake'
end
