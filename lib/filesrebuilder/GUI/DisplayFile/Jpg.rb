module FilesRebuilder

  module GUI

    module DisplayFile

      module Jpg

        # Initialize the widget based on a pointer content
        #
        # Parameters::
        # * *pointer* (_FileInfo_ or _SegmentPointer_): The pointer
        # * *data* (_IOBlockReader_): The data to read content from
        # * *begin_offset* (_Fixnum_): Beginning of the content in the data
        # * *end_offset* (_Fixnum_): Ending of the content in the data
        def init_with_data(pointer, data, begin_offset, end_offset)
          pixbuf_loader = Gdk::PixbufLoader.open('image/jpeg', true) do |loader|
            data.each_block(begin_offset..end_offset-1) do |data_block|
              loader.write(data_block)
            end
          end
          set_image(self, pixbuf_loader.pixbuf)
        end

        # Set the image
        #
        # Parameters::
        # * *widget* (<em>Gtk::Widget</em>): The widget
        # * *pixbuf* (<em>Gtk::Pixbuf</em>): The pixel buffer
        def set_image(widget, pixbuf)
          widget.pixbuf = pixbuf
        end

      end

    end

  end

end
