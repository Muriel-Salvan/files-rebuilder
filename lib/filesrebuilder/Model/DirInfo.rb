require 'filesrebuilder/Model/FileInfo'

module FilesRebuilder

  module Model

    # Contains information from the scan of a directory
    class DirInfo

      # Directory base name
      #   String
      attr_reader :base_name

      # Parent directory
      #   DirInfo
      attr_reader :parent_dir

      # Data scan of each sub-directory
      #   map< dir_base_name, dir_info >
      #   map< String, DirInfo >
      attr_reader :sub_dirs

      # Data scan of each file
      #   map< file_base_name, file_info >
      #   map< String, FileInfo >
      attr_reader :files

      # Constructor
      #
      # Parameters::
      # * *base_name* (_String_): Directory base name
      # * *parent_dir* (_DirInfo_): Parent DirInfo, or nil if none [default = nil]
      def initialize(base_name, parent_dir = nil)
        @base_name = base_name
        @parent_dir = parent_dir
        @sub_dirs = {}
        @files = {}
      end

      # Get the absolute dir name
      #
      # Result::
      # * _String_: The absolute dir name
      def get_absolute_name
        return (parent_dir.base_name == nil) ? base_name : "#{parent_dir.get_absolute_name}/#{base_name}"
      end

    end

  end

end
