# This file is a dummy gemspec that bundle asks for
# This project is packaged using RubyPackager: http://rubypackager.sourceforge.net

Gem::Specification.new do |s|
  s.name        = 'filesrebuilder'
  s.version     = '0.0.1'
  s.summary     = ''
  s.authors     = ''
  s.add_dependency('rUtilAnts', '>= 2.0')
  s.add_dependency('fileshunter', '>= 0.1.1')
  s.add_dependency('ioblockreader')
  s.add_dependency('gtk2')
  s.add_dependency('ruby-serial')
end
