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
					if pointer.is_a?(Model::FileInfo)
						set_file_name(widget, pointer.get_absolute_name)
					else
						set_file_name(widget, "#{pointer.file_info.get_absolute_name} ##{pointer.idx_segment} (#{pointer.file_info.segments[pointer.idx_segment].extensions.join(', ')})")
					end
				end

				# Set the file name of our widget
				#
				# Parameters::
      	# * *widget* (<em>Gtk::Widget</em>): The widget
				# * *file_name* (_String_): The file name
				def set_file_name(widget, file_name)
					widget.children[1].label = file_name
				end

      end

    end

  end

end
