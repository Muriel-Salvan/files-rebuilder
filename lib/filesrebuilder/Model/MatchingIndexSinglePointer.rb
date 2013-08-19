module FilesRebuilder

  module Model

    # Contains indexed information that matches a FileInfo with another single pointer (FileInfo or SegmentPointer).
    # This is used to store what information is shared between 2 different pointers.
    class MatchingIndexSinglePointer

      # Simple matching indexes
      # An indexed data references a list of pointers to FileInfo or given segment of FileInfo.
      #   map< index_name, list< indexed_data > >
      #   map< Symbol,     list< Object > >
      attr_reader :indexes

      # Segments' metadata index.
      # Index segment metadata, by extensions.
      #   map< list< extension >, map< metadata_name, list< metadata_value > > >
      #   map< list< Symbol >,    map< Symbol,        list< Object > > >
      attr_reader :segments_metadata

      # List of matching sequences of blocks' CRC
      #   map< first_block_offset, map< matching_block_offset, list< block_crc > > >
      #   map< Fixnum,             map< Fixnum,                list< String > > >
      attr_reader :block_crc_sequences

      # Score given to this match.
      # The higher the closer pointers are.
      #   Fixnum
      attr_accessor :score

      # Constructor
      def initialize
        @indexes = {}
        @segments_metadata = {}
        @block_crc_sequences = {}
        @score = 0
      end

    end

  end

end
