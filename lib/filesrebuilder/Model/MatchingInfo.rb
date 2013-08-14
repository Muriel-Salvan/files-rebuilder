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
        :segment_ext => 8
      }
      COEFF_SEGMENT_METADATA = 2
      COEFF_BLOCK_CRC_SEQUENCE = 4

      # CRC Matching files
      #   list< ( file_info | segment_info ) >
      #   list< ( FileInfo  | SegmentInfo ) >
      attr_reader :crc_matching_files

      # Matching files with other indexes than CRC
      #   map< ( file_info | segment_info ), matching_info >
      #   map< ( FileInfo  | SegmentInfo ),  MatchingIndexSinglePointer >
      attr_reader :matching_files

      # Constructor
      #
      # Parameters::
      # * *matching_index* (_MatchingIndex_): Matching index used to compute this MatchingInfo
      # * *pointer* (_FileInfo_ or _SegmentPointer_): Pointer of the file for which we have matching index
      def initialize(matching_index, pointer)
        @matching_files = {}
        @crc_matching_files = {}
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
              lst_pointers.each do |matching_pointer|
                if (!@crc_matching_files.has_key?(matching_pointer))
                  @matching_files[matching_pointer] = MatchingIndexSinglePointer.new if (!@matching_files.has_key?(matching_pointer))
                  @matching_files[matching_pointer].score += COEFFS[index_name]
                  @matching_files[matching_pointer].indexes[index_name] = [] if (!@matching_files[matching_pointer].indexes.has_key?(index_name))
                  @matching_files[matching_pointer].indexes[index_name] << data
                end
              end
            end
          end
        end
        matching_index.segments_metadata.each do |segment_ext, segment_ext_data|
          segment_ext_data.each do |metadata_key, metadata_data|
            metadata_data.each do |metadata_value, lst_pointers|
              lst_pointers.each do |matching_pointer|
                if (!@crc_matching_files.has_key?(matching_pointer))
                  @matching_files[matching_pointer] = MatchingIndexSinglePointer.new if (!@matching_files.has_key?(matching_pointer))
                  @matching_files[matching_pointer].score += COEFF_SEGMENT_METADATA
                  @matching_files[matching_pointer].segments_metadata[segment_ext] = {} if (!@matching_files[matching_pointer].segments_metadata.has_key?(segment_ext))
                  @matching_files[matching_pointer].segments_metadata[segment_ext][metadata_key] = [] if (!@matching_files[matching_pointer].segments_metadata[segment_ext].has_key?(metadata_key))
                  @matching_files[matching_pointer].segments_metadata[segment_ext][metadata_key] << metadata_value
                end
              end
            end
          end
        end
        # Find matching blocks' CRC sequences
        lst_crc = (pointer.is_a?(FileInfo) ? pointer.crc_list : pointer.file_info.segments[pointer.idx_segment].crc_list)
        @matching_files.each do |matching_pointer, matching_info|
          if (matching_info.indexes.has_key?(:block_crc))
            lst_common_crc = matching_info.indexes[:block_crc]
            # Get the list of blocks' CRC from the file
            lst_matching_crc = (matching_pointer.is_a?(FileInfo) ? matching_pointer.crc_list : matching_pointer.file_info.segments[matching_pointer.idx_segment].crc_list)
            # Parse the original file and get to a matching CRC
            idx_crc = 0
            while (idx_crc < lst_crc.size)
              while ((idx_crc < lst_crc.size) and
                     (!lst_common_crc.include?(lst_crc[idx_crc])))
                idx_crc += 1
              end
              if (idx_crc < lst_crc.size)
                first_crc = lst_crc[idx_crc]
                # We are at the beginning of a sequence in the original file.
                smallest_sequence_size = lst_crc.size - idx_crc
                # Find all the occurences of this sequence in the matching file.
                lst_matching_crc.each_with_index do |matching_crc, idx_matching_crc|
                  if (matching_crc == first_crc)
                    # We are at the beginning of a sequence in the matching file
                    idx_sequence = 1
                    # Get the matching sequence
                    matching_sequence = [first_crc]
                    while ((idx_crc+idx_sequence < lst_crc.size) and
                           (idx_matching_crc+idx_sequence < lst_matching_crc.size) and
                           (lst_crc[idx_crc+idx_sequence] == lst_matching_crc[idx_matching_crc+idx_sequence]))
                      matching_sequence << lst_crc[idx_crc+idx_sequence]
                      idx_sequence += 1
                    end
                    if (matching_sequence.size > 1)
                      # There is a matching sequence
                      offset = idx_crc*FileInfo::CRC_BLOCK_SIZE
                      matching_info.block_crc_sequences[offset] = {} if (!matching_info.block_crc_sequences.has_key?(offset))
                      matching_info.block_crc_sequences[offset][idx_matching_crc*FileInfo::CRC_BLOCK_SIZE] = matching_sequence
                      smallest_sequence_size = matching_sequence.size if (matching_sequence.size < smallest_sequence_size)
                      # For each successful sequence, increase the score
                      matching_info.score += (COEFF_BLOCK_CRC_SEQUENCE * matching_sequence.size)
                    end
                  end
                end
                idx_crc += smallest_sequence_size
              end
            end
          end
        end
      end

      # Compute the maximal score matching a given pointer could get
      #
      # Parameters::
      # * *pointer* (_FileInfo_ or _SegmentPointer_): The pointer to compute the maximal score for
      # Result::
      # * _Fixnum_: The maximal score
      def self.compute_score_max(pointer)
        file_info = (pointer.is_a?(FileInfo) ? pointer : pointer.file_info)
        score_max = 0
        lst_index_names = [ :base_name, :size, :date ]
        lst_index_names << :ext if (!File.extname(file_info.base_name).empty?)
        lst_index_names.each do |index_name|
          score_max += COEFFS[index_name]
        end
        lst_crc = (pointer.is_a?(FileInfo) ? pointer.crc_list : pointer.file_info.segments[pointer.idx_segment].crc_list)
        score_max += (COEFF_BLOCK_CRC_SEQUENCE + COEFFS[:block_crc]) * lst_crc.size
        score_max += COEFFS[:segment_ext] * (pointer.is_a?(FileInfo) ? pointer.segments.size : 1)
        (pointer.is_a?(FileInfo) ? pointer.segments : [ pointer.file_info.segments[pointer.idx_segment] ]).each do |segment|
          score_max += COEFF_SEGMENT_METADATA * segment.metadata.size
        end

        return score_max
      end

    end

  end

end
