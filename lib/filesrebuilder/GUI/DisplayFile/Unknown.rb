module FilesRebuilder

  module GUI

    module DisplayFile

      class Unknown < GUIHandler

      	# Initialize the widget based on a pointer content
      	#
      	# Parameters::
      	# * *widget* (<em>Gtk::Widget</em>): The widget to initialize
      	# * *pointer* (_FileInfo_ or _SegmentPointer_): The pointer
      	# * *data* (_IOBlockReader_): The data to read content from
      	# * *begin_offset* (_Fixnum_): Beginning of the content in the data
      	# * *end_offset* (_Fixnum_): Ending of the content in the data
				def init_with_data(widget, pointer, data, begin_offset, end_offset)
          # Nothing to do
				end

      end

    end

  end

end
