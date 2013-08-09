module FilesRebuilder

  module Model

    # Contains all selected matching pointers
    class MatchingSelection

      # Matching pointers
      #   map< pointer,                       pointer >
      #   map< ( SegmentPointer | FileInfo ), ( SegmentPointer | FileInfo ) >
      attr_reader :matching_pointers

      # Constructor
      def initialize
        @matching_pointers = {}
      end

    end

  end

end
