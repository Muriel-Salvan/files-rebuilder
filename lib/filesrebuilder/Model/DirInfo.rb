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

      # Get various counters out of a directory entry
      #
      # Parameters::
      # * *matching_selection* (_MatchingSelection_): The matching selection
      # Result::
      # * <em>map<Symbol,Fixnum></em>: The counters:
      #   * *:nbr_files*: Number of files
      #   * *:nbr_unmatched_files*: Number of unmatched files
      #   * *:nbr_segments*: Number of segments
      #   * *:nbr_unmatched_segments*: Number of unmatched segments
      def count(matching_selection)
        result = {
          :nbr_files => @files.size,
          :nbr_unmatched_files => 0,
          :nbr_segments => 0,
          :nbr_unmatched_segments => 0
        }
        @files.each do |file_base_name, file_info|
          result[:nbr_unmatched_files] += 1 if !matching_selection.matching_pointers.has_key?(file_info)
          file_info.segments.size.times do |idx_segment|
            result[:nbr_unmatched_segments] += 1 if !matching_selection.matching_pointers.has_key?(Model::SegmentPointer.new(file_info, idx_segment))
            result[:nbr_segments] += 1
          end
        end
        @sub_dirs.each do |dir_base_name, sub_dir_info|
          result.merge!(sub_dir_info.count(matching_selection)) { |counter_name, old_counter, new_counter| old_counter + new_counter }
        end
        return result
      end

    end

  end

end
