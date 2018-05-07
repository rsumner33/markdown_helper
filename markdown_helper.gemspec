
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'markdown_helper/version'

Gem::Specification.new do |spec|
  spec.name          = 'markdown_helper'
  spec.version       = MarkdownHelper::VERSION
  spec.authors       = ['burdettelamar']
  spec.email         = ['BurdetteLamar@Yahoo.com']

  spec.summary       = 'Class to help with GitHub markdown.'
  spec.description   = 'Class to help with GitHub markdown.  So far:  file inclusion.'
  spec.homepage      = 'https://rubygems.org/gems/markdown_helper'
  spec.license       = 'MIT'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  # if spec.respond_to?(:metadata)
  #   spec.metadata['allowed_push_host'] = 'https://rubygems.org/'
  #   spec.metadata['allowed_push_host'] = "http://rubygems.org"
  # else
  #   raise 'RubyGems 2.0 or newer is required to protect against ' \
  #     'public gem pushes.'
  # end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.14'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'diff-lcs', '~> 1.3'
end
