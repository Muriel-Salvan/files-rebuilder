require 'filesrebuilder/Model/FileInfo'

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
      #   map< index_name, map< indexed_data, list< ( file_info | [ file_info, segment_index ] ) > > >
      #   map< Symbol,     map< Object,       list< ( FileInfo  | [ FileInfo,  Fixnum ] ) > > >
      attr_reader :indexes

      # Segments' metadata index.
      # Index segment metadata, by extensions
      #   map< list< extension >, map< metadata_name, map< metadata_value, list< ( file_info | [ file_info, segment_index ] ) > > > >
      #   map< list< Symbol >,    map< Symbol,        map< Object,         list< ( FileInfo  | [ FileInfo,  Fixnum ] ) > > > >
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
        @global_mutex.synchronize do
          # Fill simple indexes at file level
          file_extension = File.extname(absolute_file_name)
          indexed_data = {
            :crc => file_info.get_crc,
            :base_name => File.basename(absolute_file_name)[0..-1-file_extension.size],
            :size => file_info.size,
            :date => file_info.date,
          }
          indexed_data[:ext] = file_extension[1..-1] if (!file_extension.empty?)
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
              # Simple indexes
              {
                :crc => segment.get_crc,
                :size => segment.end_offset - segment.begin_offset,
              }.each do |index_name, data|
                @indexes[index_name][data] = [] if (!@indexes[index_name].has_key?(data))
                @indexes[index_name][data] << [ file_info, idx_segment ]
              end
              # CRC blocks
              segment.crc_list.each do |crc|
                @indexes[:block_crc][crc] = [] if (!@indexes[:block_crc].has_key?(crc))
                @indexes[:block_crc][crc] << [ file_info, idx_segment ]
              end
            end
          end
          # Index segment data
          file_info.segments.each_with_index do |segment, idx_segment|
            fileinfo_pointer = ((file_info.segments.size == 1) ? file_info : [ file_info, idx_segment ])
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

    end

  end

end
