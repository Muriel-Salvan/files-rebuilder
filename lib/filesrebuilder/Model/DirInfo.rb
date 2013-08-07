require 'filesrebuilder/Model/FileInfo'

module FilesRebuilder

  module Model

    # Contains information from the scan of a directory
    class DirInfo

      # Directory base name
      #   String
      attr_accessor :base_name

      # Data scan of each sub-directory
      #   map< dir_base_name, dir_info >
      #   map< String, DirInfo >
      attr_reader :sub_dirs

      # Data scan of each file
      #   map< file_base_name, file_info >
      #   map< String, FileInfo >
      attr_reader :files

      # Constructor
      def initialize
        @sub_dirs = {}
        @files = {}
      end

    end

  end

end
