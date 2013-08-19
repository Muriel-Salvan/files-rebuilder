require 'filesrebuilder/Model/DirInfo'
require 'filesrebuilder/Model/Index'
require 'filesrebuilder/Model/MatchingSelection'

module FilesRebuilder

  module Model

    # Complete data model.
    # this data model is thread safe.
    class Data

      dont_rubyserial :global_mutex

      attr_reader :src_indexes
      attr_reader :dst_indexes
      attr_reader :src_selection
      attr_reader :dst_selection
      attr_reader :options

      # Constructor
      def initialize
        # Flat directories info
        @dirs_info = DirInfo.new(nil)
        # Indexes
        @src_indexes = Index.new
        @dst_indexes = Index.new
        # Selection
        @src_selection = MatchingSelection.new
        @dst_selection = MatchingSelection.new
        # Options
        # Set defaults here
        @options = {
          :score_min => 0
        }
        # Mutex protecting any access to the data (@dirs_info)
        @global_mutex = Mutex.new
      end

      # Callback called when RubySerial loads this object.
      # Called after instance variables have been replaced.
      def rubyserial_onload
        @global_mutex = Mutex.new
      end

      # Get the directory info of a given directory
      #
      # Parameters::
      # * *dir_name* (_String_): The directory to look for
      # Result::
      # * _DirInfo_: The corresponding directory info, or nil if none
      def dir_info(dir_name)
        dir_info = nil

        @global_mutex.synchronize do
          dir_info = dir_info_unprotected(dir_name)
        end

        return dir_info
      end

      # Get or create a dir info of a given directory
      #
      # Parameters::
      # * *dir_name* (_String_): The directory to look for
      # Result::
      # * _DirInfo_: The resulting DirInfo
      def get_or_create_dir_info(dir_name)
        dir_info = nil

        @global_mutex.synchronize do
          dir_info = get_or_create_dir_info_unprotected(dir_name)
        end

        return dir_info
      end

      # Store a subdir info when we already have access to the DirInfo
      #
      # Parameters::
      # * *dir_info* (_DirInfo_): The directory info to complete
      # * *dir_base_name* (_String_): The directory base name to add
      # Result::
      # * _DirInfo_: The resulting DirInfo
      def get_or_create_subdir_info(dir_info, dir_base_name)
        subdir_info = nil

        @global_mutex.synchronize do
          subdir_info = dir_info.sub_dirs[dir_base_name]
          if (subdir_info == nil)
            subdir_info = DirInfo.new(dir_base_name, dir_info)
            dir_info.sub_dirs[dir_base_name] = subdir_info
          end
        end

        return subdir_info
      end

      # Store a file info when we already have access to the DirInfo
      #
      # Parameters::
      # * *dir_info* (_DirInfo_): The directory info to complete
      # * *file_base_name* (_String_): The file base name to add
      # Result::
      # * _FileInfo_: The resulting FileInfo
      def get_or_create_file_info(dir_info, file_base_name)
        file_info = nil

        @global_mutex.synchronize do
          file_info = dir_info.files[file_base_name]
          if (file_info == nil)
            file_info = FileInfo.new(file_base_name, dir_info)
            dir_info.files[file_base_name] = file_info
          end
        end

        return file_info
      end

      # Remove every FileInfo that is not part of the given list.
      #
      # Parameters::
      # * *dir_info* (_DirInfo_): The directory info to complete
      # * *lst_file_base_names* (<em>list<String></em>): The file base names to keep
      def keep_file_infos(dir_info, lst_file_base_names)
        @global_mutex.synchronize do
          if (lst_file_base_names.empty?)
            dir_info.files.clear
          else
            dir_info.files.delete_if { |file_base_name, file_info| (!lst_file_base_names.include?(file_base_name)) }
          end
        end
      end

      # Get a list of file info belonging to a given directory
      #
      # Parameters::
      # * *dir_name* (_String_): Directory name to search in
      # Result::
      # * <em>list< FileInfo ></em>: The list of all FileInfo for this directory
      def get_file_info_from_dir(dir_name)
        lst_fileinfo = []

        @global_mutex.synchronize do
          lst_fileinfo.concat(get_file_info_from_dir_unprotected(dir_info_unprotected(dir_name)))
        end

        return lst_fileinfo
      end

      private

      FILE_SEPARATOR_REGEXP = Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact)

      # Get the directory info of a given directory.
      # This method is not protected by the mutex.
      #
      # Parameters::
      # * *dir_name* (_String_): The directory to look for
      # Result::
      # * _DirInfo_: The corresponding directory info, or nil if none
      def dir_info_unprotected(dir_name)
        dir_info = @dirs_info

        dir_name.split(FILE_SEPARATOR_REGEXP).each do |dir_base_name|
          dir_info = dir_info.sub_dirs[dir_base_name]
          break if (dir_info == nil)
        end

        return dir_info
      end

      # Create a directory info for a given directory if it does not exist already.
      # This method is not protected by the mutex.
      #
      # Parameters::
      # * *dir_name* (_String_): The directory to look for
      # Result::
      # * _DirInfo_: The corresponding directory info (can be the existing or a new one)
      def get_or_create_dir_info_unprotected(dir_name)
        dir_info = @dirs_info

        dir_name.split(FILE_SEPARATOR_REGEXP).each do |dir_base_name|
          dir_info.sub_dirs[dir_base_name] = Model::DirInfo.new(dir_base_name, dir_info) if (dir_info.sub_dirs[dir_base_name] == nil)
          dir_info = dir_info.sub_dirs[dir_base_name]
        end

        return dir_info
      end

      # Get a list of file info belonging to a given directory
      #
      # Parameters::
      # * *dir_info* (_DirInfo_): Directory info to search in
      # Result::
      # * <em>list< FileInfo ></em>: The list of all FileInfo for this directory
      def get_file_info_from_dir_unprotected(dir_info)
        lst_fileinfo = dir_info.files.values

        dir_info.sub_dirs.values.each do |subdir_info|
          lst_fileinfo.concat(get_file_info_from_dir_unprotected(subdir_info))
        end

        return lst_fileinfo
      end

    end

  end

end
