module FilesRebuilder

  module Model

    class FileInfo

      CRC_BLOCK_SIZE = 4096

      attr_accessor :filled
      attr_accessor :date
      attr_accessor :size
      attr_accessor :crc_list
      attr_accessor :segments

      # Constructor
      def initialize
        @filled = false
      end

      # Compute the CRC of this File
      #
      # Result::
      # * _String_: The CRC
      def get_crc
        return Zlib.crc32(@crc_list.join(''), 0).to_s(16).upcase
      end

    end

  end

end
