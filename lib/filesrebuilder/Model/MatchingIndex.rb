module FilesRebuilder

  module Model

    # Contains indexed information that matches a FileInfo
    class MatchingIndex

      # Simple matching indexes
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
        @segments_metadata = {}
      end

      # Are matching files lists empty?
      #
      # Result::
      # * _Boolean_: Are matching files lists empty?
      def empty?
        return (@indexes.empty? and @segments_metadata.empty?)
      end

    end

  end

end
