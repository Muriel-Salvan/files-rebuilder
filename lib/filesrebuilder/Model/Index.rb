require 'filesrebuilder/Model/MatchingIndex'
require 'filesrebuilder/Model/SegmentPointer'

module FilesRebuilder

  module Model

    # Contains indexed information from the scan of a directory
    class Index

      INDEXES_LIST = [
        :crc, # String: File CRC, Segment CRC
        :base_name, # String: File base name without extension
        :size, # Fixnum: File size, Segment size
        :date, # Time: File date
        :ext, # String: File extension
        :block_crc, # String: File block CRC, Segment block CRC
        :segment_ext # list< Symbol >: List of Segment extensions
      ]

      dont_rubyserial :global_mutex

      # Simple indexes, for each index name.
      # An indexed data references a list of pointers to FileInfo or given segment of FileInfo.
      #   map< index_name, map< indexed_data, list< ( file_info | segment_pointer ) > > >
      #   map< Symbol,     map< Object,       list< ( FileInfo  | SegmentPointer ) > > >
      attr_reader :indexes

      # Segments' metadata index.
      # Index segment metadata, by extensions
      #   map< list< extension >, map< metadata_name, map< metadata_value, list< ( file_info | segment_pointer ) > > > >
      #   map< list< Symbol >,    map< Symbol,        map< Object,         list< ( FileInfo  | SegmentPointer ) > > > >
      attr_reader :segments_metadata

      # Constructor
      def initialize
        @indexes = {}
        INDEXES_LIST.each do |index_name|
          @indexes[index_name] = {}
        end
        @segments_metadata = {}
        # Mutex protecting any access to the data (@dirs_info)
        @global_mutex = Mutex.new
      end

      # Callback called when RubySerial loads this object.
      # Called after instance variables have been replaced.
      def rubyserial_onload
        @global_mutex = Mutex.new
      end

      # Add data from a FileInfo to be indexed
      #
      # Parameters::
      # * *absolute_file_name* (_String_): Absolute file name
      # * *file_info* (_FileInfo_): File info to index
      def add(absolute_file_name, file_info)
        file_extension = File.extname(absolute_file_name)
        indexed_data = {
          :crc => file_info.get_crc,
          :base_name => file_info.base_name[0..-1-file_extension.size],
          :size => file_info.size,
          :date => file_info.date
        }
        indexed_data[:ext] = file_extension[1..-1] if (!file_extension.empty?)
        @global_mutex.synchronize do
          # Fill simple indexes at file level
          indexed_data.each do |index_name, data|
            @indexes[index_name][data] = [] if (!@indexes[index_name].has_key?(data))
            @indexes[index_name][data] << file_info
          end
          # Add block crc
          file_info.crc_list.each do |crc|
            @indexes[:block_crc][crc] = [] if (!@indexes[:block_crc].has_key?(crc))
            @indexes[:block_crc][crc] << file_info
          end
          # If there are several segments, index each one of them
          if (file_info.segments.size > 1)
            file_info.segments.each_with_index do |segment, idx_segment|
              segment_pointer = SegmentPointer.new(file_info, idx_segment)
              # Simple indexes
              {
                :crc => segment.get_crc,
                :size => segment.end_offset - segment.begin_offset,
              }.each do |index_name, data|
                @indexes[index_name][data] = [] if (!@indexes[index_name].has_key?(data))
                @indexes[index_name][data] << segment_pointer
              end
              # CRC blocks
              segment.crc_list.each do |crc|
                @indexes[:block_crc][crc] = [] if (!@indexes[:block_crc].has_key?(crc))
                @indexes[:block_crc][crc] << segment_pointer
              end
            end
          end
          # Index segment data
          file_info.segments.each_with_index do |segment, idx_segment|
            fileinfo_pointer = ((file_info.segments.size == 1) ? file_info : SegmentPointer.new(file_info, idx_segment))
            @indexes[:segment_ext][segment.extensions] = [] if (!@indexes[:segment_ext].has_key?(segment.extensions))
            @indexes[:segment_ext][segment.extensions] << fileinfo_pointer
            # Index metadata
            if (!segment.metadata.empty?)
              @segments_metadata[segment.extensions] = {} if (!@segments_metadata.has_key?(segment.extensions))
              segment.metadata.each do |metadata_key, metadata_value|
                @segments_metadata[segment.extensions][metadata_key] = {} if (!@segments_metadata[segment.extensions].has_key?(metadata_key))
                @segments_metadata[segment.extensions][metadata_key][metadata_value] = [] if (!@segments_metadata[segment.extensions][metadata_key].has_key?(metadata_value))
                @segments_metadata[segment.extensions][metadata_key][metadata_value] << fileinfo_pointer
              end
            end
          end
        end
      end

      # Delete a list of FileInfo from the indexed data
      #
      # Parameters::
      # * *lst_file_info* (<em>list< FileInfo ></em>): The list of FileInfo to be removed
      def remove(lst_file_info)
        @global_mutex.synchronize do
          # Gather the list of lists to update
          lst_lst_file_info = []
          INDEXES_LIST.each do |index_name|
            lst_lst_file_info.concat(@indexes[index_name].values)
          end
          @segments_metadata.values.each do |metadata_key_map|
            metadata_key_map.values do |metadata_value_map|
              lst_lst_file_info.concat(metadata_value_map.values)
            end
          end
          # Update them for real
          lst_lst_file_info.each do |lst_pointers|
            lst_pointers.delete_if do |pointer|
              if pointer.is_a?(FileInfo)
                next lst_file_info.include?(pointer)
              else
                next lst_file_info.include?(pointer.file_info)
              end
            end
          end
        end
      end

      # Get matching file info for a given file info (or a segment inside of it).
      # This is done by looking at indexes.
      #
      # Parameters::
      # * *file_info* (_FileInfo_): Corresponding FileInfo
      # * *segment_index* (_Fixnum_): Segment index in this file info. Set to nil to consider all segments. [default = nil]
      # Result::
      # * _MatchingIndex_: The index info, containing only matching files
      def get_matching_index(file_info, segment_index = nil)
        result = MatchingIndex.new

        segment_pointer = SegmentPointer.new(file_info, segment_index)
        file_extension = File.extname(file_info.base_name)
        # Create the list of indexes to be looked
        # map< index_name, list< data > >
        indexes_lookup_data = {
          :base_name => [ file_info.base_name[0..-1-file_extension.size] ],
          :date => [ file_info.date ]
        }
        if (file_info.segments.size == 1)
          indexes_lookup_data[:crc] = [ file_info.get_crc ]
          indexes_lookup_data[:size] = [ file_info.size ]
          indexes_lookup_data[:block_crc] = file_info.crc_list
          indexes_lookup_data[:segment_ext] = [ file_info.segments[0].extensions ]
        elsif (segment_index == nil)
          indexes_lookup_data[:crc] = [ file_info.get_crc ]
          indexes_lookup_data[:size] = [ file_info.size ]
          indexes_lookup_data[:block_crc] = file_info.crc_list
          indexes_lookup_data[:segment_ext] = file_info.segments.map { |segment| segment.extensions }
          file_info.segments.each do |segment|
            indexes_lookup_data[:crc] << segment.get_crc
            indexes_lookup_data[:size] << segment.end_offset - segment.begin_offset
            indexes_lookup_data[:block_crc].concat(segment.crc_list)
          end
        else
          indexes_lookup_data[:crc] = [ file_info.segments[segment_index].get_crc ]
          indexes_lookup_data[:size] = [ file_info.segments[segment_index].end_offset - file_info.segments[segment_index].begin_offset ]
          indexes_lookup_data[:block_crc] = file_info.segments[segment_index].crc_list
          indexes_lookup_data[:segment_ext] = [ file_info.segments[segment_index].extensions ]
        end
        indexes_lookup_data[:ext] = [ file_extension[1..-1] ] if (!file_extension.empty?)
        @global_mutex.synchronize do
          # Look into simple indexes
          indexes_lookup_data.each do |index_name, lst_data|
            lst_data.each do |data|
              if (@indexes[index_name].has_key?(data))
                lst_matching = @indexes[index_name][data].clone.delete_if do |pointer|
                  if (file_info.segments.size == 1)
                    next (pointer == file_info)
                  elsif (segment_index == nil)
                    if (pointer.is_a?(FileInfo))
                      next (pointer == file_info)
                    else
                      next (pointer.file_info == file_info)
                    end
                  else
                    next (pointer == segment_pointer)
                  end
                end
                if (!lst_matching.empty?)
                  result.indexes[index_name] = {} if (!result.indexes.has_key?(index_name))
                  result.indexes[index_name][data] = lst_matching
                end
              end
            end
          end
          # Lookup into selected segments only
          (((file_info.segments.size == 1) or (segment_index == nil)) ? file_info.segments : [ file_info.segments[segment_index] ]).each do |segment|
            segment.metadata.each do |metadata_key, metadata_value|
              if ((@segments_metadata.has_key?(segment.extensions)) and
                  (@segments_metadata[segment.extensions].has_key?(metadata_key)) and
                  (@segments_metadata[segment.extensions][metadata_key].has_key?(metadata_value)))
                lst_matching = @segments_metadata[segment.extensions][metadata_key][metadata_value].clone.delete_if do |pointer|
                  if (file_info.segments.size == 1)
                    next (pointer == file_info)
                  elsif (segment_index == nil)
                    if (pointer.is_a?(FileInfo))
                      next (pointer == file_info)
                    else
                      next (pointer.file_info == file_info)
                    end
                  else
                    next (pointer == segment_pointer)
                  end
                end
                if (!lst_matching.empty?)
                  result.segments_metadata[segment.extensions] = {} if (!result.segments_metadata.has_key?(segment.extensions))
                  result.segments_metadata[segment.extensions][metadata_key] = {} if (!result.segments_metadata[segment.extensions].has_key?(metadata_key))
                  result.segments_metadata[segment.extensions][metadata_key][metadata_value] = lst_matching
                end
              end
            end
          end
        end

        return result
      end

    end

  end

end
