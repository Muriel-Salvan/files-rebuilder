RubyPackager::ReleaseInfo.new.
  author(
    :name => 'Muriel Salvan',
    :email => 'muriel@x-aeon.com',
    :web_page_url => 'http://murielsalvan.users.sourceforge.net'
  ).
  project(
    :name => 'Files Hunter',
    :web_page_url => 'http://files-rebuilder.sourceforge.net',
    :summary => 'Find and rebuild corrupted files and directories.',
    :description => 'Application that scans files and directories for specified folders, indexes their content, and retrieves lost or corrupted fragments. Ideally used to retrieved corrupted or lost files/folders after a disk crash recovery.',
    :image_url => 'http://files-rebuilder.sourceforge.net/wiki/images/c/c9/Logo.png',
    :favicon_url => 'http://files-rebuilder.sourceforge.net/wiki/images/2/26/Favicon.png',
    :browse_source_url => 'https://github.com/Muriel-Salvan/files-rebuilder',
    :dev_status => 'Alpha'
  ).
  add_core_files( [
    '{lib,bin}/**/*'
  ] ).
  # add_test_files( [
  #   'test/**/*'
  # ] ).
  add_additional_files( [
    'README',
    'README.md',
    'LICENSE',
    'AUTHORS',
    'Credits',
    'ChangeLog',
    'Rakefile'
  ] ).
  gem(
    :gem_name => 'files-rebuilder',
    :gem_platform_class_name => 'Gem::Platform::RUBY',
    :require_paths => [ 'lib' ],
    :has_rdoc => true,
    #:test_file => 'test/run.rb',
    :gem_dependencies => [
      [ 'rUtilAnts', '>= 1.0' ],
      [ 'ioblockreader' ],
      [ 'fileshunter' ],
      [ 'gtk2' ],
      [ 'ruby-serial' ]
    ]
  ).
  source_forge(
    :login => 'murielsalvan',
    :project_unix_name => 'files-rebuilder',
    :ask_for_key_passphrase => true
  ).
  ruby_forge(
    :project_unix_name => 'files-rebuilder'
  )
