module FilesRebuilder

  module Model

    # Represents a pointer to a Segment
    class SegmentPointer

      # FileInfo containing the segment
      #   FileInfo
      attr_reader :file_info

      # Index of the segment
      #   Fixnum
      attr_reader :idx_segment

      # Constructor
      #
      # Parameters::
      # * *file_info* (_FileInfo_): The FileInfo
      # * *idx_segment* (_Fixnum_): The segment index in the FileInfo
      def initialize(file_info, idx_segment)
        @file_info = file_info
        @idx_segment = idx_segment
      end

      # == operator
      #
      # Parameters::
      # * *other* (_Object_): Other object
      def ==(other)
        return (
          other.is_a?(SegmentPointer) and
          (other.file_info == @file_info) and
          (other.idx_segment == @idx_segment)
        )
      end

    end

  end

end
