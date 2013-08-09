module FilesHunter

  # Decorate segments to add data we want to add
  class Segment
    # The list of blocks' CRC
    #   list< String >
    attr_accessor :crc_list

    # Compute the CRC of this Segment
    #
    # Result::
    # * _String_: The CRC
    def get_crc
      return Zlib.crc32(@crc_list.join(''), 0).to_s(16).upcase
    end

  end

end

module FilesRebuilder

  module Model

    class FileInfo

      CRC_BLOCK_SIZE = 4096

      # File base name
      #   String
      attr_reader :base_name

      # Parent directory
      #   DirInfo
      attr_reader :parent_dir

      # Whether the info was filled or not
      #   Boolean
      attr_accessor :filled

      # Creation date of the file
      #   Time
      attr_accessor :date

      # Size of the file
      #   Fixnum
      attr_accessor :size

      # List of blocks' CRC
      #   list< String >
      attr_accessor :crc_list

      # List of segments
      #   list< FilesHunter::Segment >
      attr_accessor :segments

      # Constructor
      #
      # Parameters::
      # * *base_name* (_String_): File base name
      # * *parent_dir* (_DirInfo_): Parent DirInfo
      def initialize(base_name, parent_dir)
        @base_name = base_name
        @parent_dir = parent_dir
        @filled = false
      end

      # Compute the CRC of this File
      #
      # Result::
      # * _String_: The CRC
      def get_crc
        return Zlib.crc32(@crc_list.join(''), 0).to_s(16).upcase
      end

      # Get the absolute file name
      #
      # Result::
      # * _String_: The absolute file name
      def get_absolute_name
        return "#{parent_dir.get_absolute_name}/#{base_name}"
      end

    end

  end

end
