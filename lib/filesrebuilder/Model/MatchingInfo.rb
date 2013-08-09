require 'filesrebuilder/Model/MatchingIndexSinglePointer'

module FilesRebuilder

  module Model

    # Contains information about a file matched with others
    class MatchingInfo

      # Coefficients bound to the importance given to a matching index.
      # The higher the coefficient, the more probable 2 files having the same data for this index should be the same file
      COEFFS = {
        :base_name => 8,
        :size => 7,
        :date => 6,
        :ext => 2,
        :block_crc => 2,
        :segment_ext => 2
      }
      COEFF_SEGMENT_METADATA = 1

      # CRC Matching files
      #   list< ( file_info | segment_info ) >
      #   list< ( FileInfo  | SegmentInfo ) >
      attr_reader :crc_matching_files

      # Matching files with other indexes than CRC
      #   map< ( file_info | segment_info ), matching_info >
      #   map< ( FileInfo  | SegmentInfo ),  MatchingIndexSinglePointer >
      attr_reader :matching_files

      # Selected matching file
      #   FileInfo | SegmentInfo
      attr_accessor :selected_pointer

      # Constructor
      #
      # Parameters::
      # * *matching_index* (_MatchingIndex_): Matching index used to compute this MatchingInfo
      def initialize(matching_index)
        @matching_files = {}
        @crc_matching_files = {}
        @selected_pointer = nil
        # First find CRC matching files
        if (matching_index.indexes.has_key?(:crc))
          matching_index.indexes[:crc].each do |data, lst_pointers|
            @crc_matching_files.concat(lst_pointers)
          end
        end
        # Then all other indexes
        matching_index.indexes.each do |index_name, index_data|
          if (index_name != :crc)
            index_data.each do |data, lst_pointers|
              lst_pointers.each do |pointer|
                if (!@crc_matching_files.has_key?(pointer))
                  @matching_files[pointer] = MatchingIndexSinglePointer.new if (!@matching_files.has_key?(pointer))
                  @matching_files[pointer].score += COEFFS[index_name]
                  @matching_files[pointer].indexes[index_name] = [] if (!@matching_files[pointer].indexes.has_key?(index_name))
                  @matching_files[pointer].indexes[index_name] << data
                end
              end
            end
          end
        end
        matching_index.segments_metadata.each do |segment_ext, segment_ext_data|
          segment_ext_data.each do |metadata_key, metadata_data|
            metadata_data.each do |metadata_value, lst_pointers|
              lst_pointers.each do |pointer|
                if (!@crc_matching_files.has_key?(pointer))
                  @matching_files[pointer] = MatchingIndexSinglePointer.new if (!@matching_files.has_key?(pointer))
                  @matching_files[pointer].score += COEFF_SEGMENT_METADATA
                  @matching_files[pointer].segments_metadata[segment_ext] = {} if (!@matching_files[pointer].segments_metadata.has_key?(segment_ext))
                  @matching_files[pointer].segments_metadata[segment_ext][metadata_key] = [] if (!@matching_files[pointer].segments_metadata[segment_ext].has_key?(metadata_key))
                  @matching_files[pointer].segments_metadata[segment_ext][metadata_key] << metadata_value
                end
              end
            end
          end
        end
      end

    end

  end

end
