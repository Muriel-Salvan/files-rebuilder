module FilesRebuilder

  module GUI

    class CompareGroup < GUIHandler

      # Codes used to identify the type of Array node in the tree view
      NODE_TYPE_DIR = 0
      NODE_TYPE_FILE = 1
      NODE_TYPE_SEGMENT = 2
      NODE_TYPE_CRC_MATCHING_FILE = 3
      NODE_TYPE_MATCHING_FILE = 4

      # The main tree view contains items that are organized this way:
      # +- [ NODE_TYPE_DIR, DirInfo, index ] - Directory being parsed
      #    +- [ NODE_TYPE_DIR, DirInfo, index ] - Sub-directory being parsed
      #    +- [ NODE_TYPE_FILE, FileInfo, MatchingInfo ] - File belonging to this directory
      #       +- [ NODE_TYPE_CRC_MATCHING_FILE, pointer ] - Matching file
      #       +- [ NODE_TYPE_MATCHING_FILE, pointer, selected, MatchingIndexSinglePointer ] - Matching file
      #       +- [ NODE_TYPE_SEGMENT, SegmentPointer, MatchingInfo ] - Segment belonging to this file
      #          +- [ NODE_TYPE_CRC_MATCHING_FILE, pointer ] - Matching file
      #          +- [ NODE_TYPE_MATCHING_FILE, pointer, selected, MatchingIndexSinglePointer ] - Matching file

      def on_treeview_row_expanded(widget, tree_iter, tree_path)
        # If the only child has no data, it means it is a fake child, and we have to create real children
        if (tree_iter.first_child[0] == false)
          fake_child = tree_iter.first_child
          # Create real children
          line_obj_info = tree_iter[0]
          case line_obj_info[0]
          when NODE_TYPE_DIR
            # Directory
            line_obj_info[1].sub_dirs.values.each do |child_dir_info|
              add_obj_info(widget.model, tree_iter, child_dir_info, line_obj_info[2])
            end
            line_obj_info[1].files.values.each do |child_file_info|
              add_obj_info(widget.model, tree_iter, child_file_info, line_obj_info[2])
            end
          end
          # Delete the fake child (do it after inserting others otherwise expansion will be cancelled)
          widget.model.remove(fake_child)
        end
      end

      def on_treeview_cursor_changed(widget)
        # Get the selected TreeIter
        selected_item = widget.selection.selected
        treestore = get_details_tree_view(widget.parent.parent.parent.parent).model
        treestore.clear
        if (selected_item != nil)
          line_obj_info = selected_item[0]
          case line_obj_info[0]
          when NODE_TYPE_DIR
            dir_info = line_obj_info[1]
            line = treestore.append(nil)
            line[0] = 'Number of files'
            line[1] = dir_info.files.size.to_s
            line = treestore.append(nil)
            line[0] = 'Number of sub-directories'
            line[1] = dir_info.sub_dirs.size.to_s
          when NODE_TYPE_FILE
            file_info = line_obj_info[1]
            if (file_info.filled)
              line = treestore.append(nil)
              line[0] = 'Already scanned?'
              line[1] = 'Yes'
              line = treestore.append(nil)
              line[0] = 'Date'
              line[1] = file_info.date.strftime('%Y-%m-%d %H:%M:%S')
              line = treestore.append(nil)
              line[0] = 'Size'
              line[1] = file_info.size.to_s
              line = treestore.append(nil)
              line[0] = 'CRC global'
              line[1] = file_info.get_crc
              line = treestore.append(nil)
              line[0] = 'CRC list'
              line[1] = file_info.crc_list.join(', ')
              segments_line = treestore.append(nil)
              segments_line[0] = "#{file_info.segments.size} segments"
              segments_line[1] = ''
              file_info.segments.each_with_index do |segment, idx_segment|
                segment_line = treestore.append(segments_line)
                segment_line[0] = "Segment ##{idx_segment}: [#{segment.begin_offset}-#{segment.end_offset}]"
                segment_line[1] = "#{segment.extensions.join(', ')}#{segment.missing_previous_data ? ' (Missing previous data)' : ''}#{segment.truncated ? ' (Truncated)' : ''} (CRC: #{segment.get_crc}) - #{segment.metadata.size} metadata - CRC List: [#{segment.crc_list.join(', ')}]"
                segment.metadata.each do |metadata_key, metadata_value|
                  line = treestore.append(segment_line)
                  line[0] = metadata_key.to_s
                  line[1] = metadata_value.to_s
                end
              end
            else
              line = treestore.append(nil)
              line[0] = 'Already scanned?'
              line[1] = 'No'
            end
          when NODE_TYPE_SEGMENT
            file_info = line_obj_info[1].file_info
            segment = file_info.segments[file_info = line_obj_info[1].idx_segment]
            line = treestore.append(nil)
            line[0] = 'Extensions'
            line[1] = segment.extensions.join(', ')
            line = treestore.append(nil)
            line[0] = 'Truncated?'
            line[1] = segment.truncated.inspect
            line = treestore.append(nil)
            line[0] = 'Missing previous data?'
            line[1] = segment.missing_previous_data.inspect
            line = treestore.append(nil)
            line[0] = 'Date'
            line[1] = file_info.date.strftime('%Y-%m-%d %H:%M:%S')
            line = treestore.append(nil)
            line[0] = 'Begin offset'
            line[1] = segment.begin_offset.to_s
            line = treestore.append(nil)
            line[0] = 'End offset'
            line[1] = segment.end_offset.to_s
            line = treestore.append(nil)
            line[0] = 'Size'
            line[1] = (segment.end_offset - segment.begin_offset).to_s
            line = treestore.append(nil)
            line[0] = 'CRC global'
            line[1] = segment.get_crc
            line = treestore.append(nil)
            line[0] = 'CRC list'
            line[1] = segment.crc_list.join(', ')
            metadata_line = treestore.append(nil)
            metadata_line[0] = "#{segment.metadata.size} metadata"
            segment.metadata.each do |metadata_key, metadata_value|
              line = treestore.append(metadata_line)
              line[0] = metadata_key.to_s
              line[1] = metadata_value.to_s
            end
          when NODE_TYPE_MATCHING_FILE
            matching_info = line_obj_info[3]
            line = treestore.append(nil)
            line[0] = 'Selected?'
            line[1] = line_obj_info[2].inspect
            line = treestore.append(nil)
            line[0] = 'Score'
            line[1] = matching_info.score.to_s
            indexes_line = treestore.append(nil)
            indexes_line[0] = "#{matching_info.indexes.size} indexes"
            matching_info.indexes.each do |index_name, lst_index_data|
              line = treestore.append(indexes_line)
              line[0] = index_name.to_s
              line[1] = lst_index_data.map { |index_data| index_data.inspect }.join(', ')
            end
            segments_metadata_line = treestore.append(nil)
            segments_metadata_line[0] = "#{matching_info.segments_metadata.size} segments"
            matching_info.segments_metadata.each do |segment_ext, segment_data|
              segment_metadata_line = treestore.append(segments_metadata_line)
              segment_metadata_line[0] = segment_ext.join(', ')
              segment_metadata_line[1] = "#{segment_data.size} metadata keys"
              segment_data.each do |metadata_key, lst_values|
                line = treestore.append(segment_metadata_line)
                line[0] = metadata_key.to_s
                line[1] = lst_values.map { |value| value.inspect }.join(', ')
              end
            end
          end
        end
      end

      # Set the directory to be displayed
      #
      # Parameters::
      # * *widget* (<em>Gtk::Widget</em>): The CompareGroup widget
      # * *lst_dirs* (<em>list< [ String, DirInfo ] ></em>): List of directories to display
      # * *index* (<em>Model::Index</em>): Index used to get matching files
      def set_dirs_to_compare(widget, lst_dirs, index)

        # Create the main TreeStore
        treestore = Gtk::TreeStore.new(Model::DirInfo)
        lst_dirs.each do |dir_name, dir_info|
          add_obj_info(treestore, nil, dir_info, index)
        end
        # Assign TreeStore to the view
        view = get_tree_view(widget)
        view.model = treestore
        # Set renderers
        # == Icon ==
        view_column_name = Gtk::TreeViewColumn.new
        view_column_name.title = 'Name'
        view_column_name.resizable = true
        cell_renderer_icon = Gtk::CellRendererPixbuf.new
        view_column_name.pack_start(cell_renderer_icon, false)
        view_column_name.set_cell_data_func(cell_renderer_icon) do |column, renderer, model, iter|
          line_obj_info = iter[0]
          case line_obj_info[0]
          when NODE_TYPE_DIR
            renderer.stock_id = Gtk::Stock::DIRECTORY
          when NODE_TYPE_FILE
            renderer.stock_id = Gtk::Stock::FILE
          when NODE_TYPE_SEGMENT
            renderer.stock_id = Gtk::Stock::INDEX
          when NODE_TYPE_CRC_MATCHING_FILE
            renderer.stock_id = Gtk::Stock::COPY
          when NODE_TYPE_MATCHING_FILE
            renderer.stock_id = (line_obj_info[2] ? Gtk::Stock::APPLY : Gtk::Stock::DISCARD)
          else
            raise "Unknown node type: #{line_obj_info[0]}"
          end
        end
        # == Name ==
        cell_renderer_name = Gtk::CellRendererText.new
        cell_renderer_name.foreground = 'grey'
        view_column_name.pack_start(cell_renderer_name, true)
        view.append_column(view_column_name)
        view_column_name.set_cell_data_func(cell_renderer_name) do |column, renderer, model, iter|
          line_obj_info = iter[0]
          case line_obj_info[0]
          when NODE_TYPE_DIR
            renderer.text = "#{line_obj_info[1].base_name}/"
            renderer.foreground_set = false
            renderer.weight = Pango::WEIGHT_BOLD
          when NODE_TYPE_FILE
            renderer.text = line_obj_info[1].base_name
            renderer.foreground_set = line_obj_info[2].matching_files.empty?
            renderer.weight = Pango::WEIGHT_NORMAL
          when NODE_TYPE_SEGMENT
            renderer.text = "Segment ##{line_obj_info[1].idx_segment}"
            renderer.foreground_set = line_obj_info[2].matching_files.empty?
            renderer.weight = Pango::WEIGHT_NORMAL
          when NODE_TYPE_CRC_MATCHING_FILE
            if (line_obj_info[1].is_a?(Model::FileInfo))
              renderer.text = line_obj_info[1].get_absolute_name
            else
              renderer.text = "#{line_obj_info[1].file_info.get_absolute_name} ##{line_obj_info[1].idx_segment}"
            end
            renderer.foreground_set = true
            renderer.weight = Pango::WEIGHT_NORMAL
          when NODE_TYPE_MATCHING_FILE
            if (line_obj_info[1].is_a?(Model::FileInfo))
              renderer.text = line_obj_info[1].get_absolute_name
            else
              renderer.text = "#{line_obj_info[1].file_info.get_absolute_name} ##{line_obj_info[1].idx_segment}"
            end
            renderer.foreground_set = false
            renderer.weight = line_obj_info[2] ? Pango::WEIGHT_BOLD : Pango::WEIGHT_NORMAL
          end
        end
        # == Count ==
        cell_renderer_count = Gtk::CellRendererText.new
        view_column_count = Gtk::TreeViewColumn.new('Date', cell_renderer_count)
        view.append_column(view_column_count)
        view_column_count.set_cell_data_func(cell_renderer_count) do |column, renderer, model, iter|
          line_obj_info = iter[0]
          case line_obj_info[0]
          when NODE_TYPE_DIR
            renderer.text = ''
          when NODE_TYPE_FILE
            renderer.text = "#{line_obj_info[2].matching_files.size} matching files, #{line_obj_info[2].crc_matching_files.size} exact matching files"
          when NODE_TYPE_SEGMENT
            renderer.text = "#{line_obj_info[2].matching_files.size} matching files, #{line_obj_info[2].crc_matching_files.size} exact matching files"
          when NODE_TYPE_CRC_MATCHING_FILE
            renderer.text = ''
          when NODE_TYPE_MATCHING_FILE
            matching_info = line_obj_info[3]
            nbr_metadata = 0
            matching_info.segments_metadata.values.each do |segment_data|
              segment_data.values.each do |lst_data|
                nbr_metadata += lst_data.size
              end
            end
            renderer.text = "Score: #{matching_info.score} - #{matching_info.indexes.map { |index_name, lst_data| (lst_data.size == 1) ? index_name.to_s : "#{index_name.to_s} (#{lst_data.size})" }.join(', ')} - #{nbr_metadata} metadata"
          end
        end

        # Create a TreeStore for the details pane
        details_tree_view = get_details_tree_view(widget)
        details_treestore = Gtk::TreeStore.new(String, String)
        details_tree_view.model = details_treestore
        # == Property ==
        cell_renderer_property = Gtk::CellRendererText.new
        view_column_property = Gtk::TreeViewColumn.new('Property', cell_renderer_property)
        details_tree_view.append_column(view_column_property)
        view_column_property.set_cell_data_func(cell_renderer_property) do |column, renderer, model, iter|
          renderer.text = iter[0]
        end
        # == Value ==
        cell_renderer_value = Gtk::CellRendererText.new
        view_column_value = Gtk::TreeViewColumn.new('Value', cell_renderer_value)
        details_tree_view.append_column(view_column_value)
        view_column_value.set_cell_data_func(cell_renderer_value) do |column, renderer, model, iter|
          renderer.text = iter[1]
        end

      end

      private

      # Get the tree view
      #
      # Parameters::
      # * *widget* (<em>Gtk::Widget</em>): The ShowDir widget
      def get_tree_view(widget)
        return widget.children[0].children[2].children[0].children[0]
      end

      # Get the details tree view
      #
      # Parameters::
      # * *widget* (<em>Gtk::Widget</em>): The ShowDir widget
      def get_details_tree_view(widget)
        return widget.children[0].children[2].children[1].children[0].children[0].children[0]
      end

      # Create items for a given object model in a treestore
      #
      # Parameters::
      # * *treestore* (<em>Gtk::TreeStore</em>): The TreeStore to complete
      # * *parent_elem* (<em>Gtk::TreeIter</em>): Element to create the DirInfo into
      # * *obj_info* (_Object_): The model object to add to the treestore. Can be DirInfo, FileInfo or SegmentPointer.
      # * *index* (_Index_): The index used to get matching files
      def add_obj_info(treestore, parent_elem, obj_info, index)
        new_elem = treestore.append(parent_elem)
        has_children = false
        case
        when (obj_info.class == Model::DirInfo)
          new_elem[0] = [ NODE_TYPE_DIR, obj_info, index ]
          has_children = ((!obj_info.sub_dirs.empty?) or (!obj_info.files.empty?))
        when ((obj_info.class == Model::FileInfo) or (obj_info.class == Model::SegmentPointer))
          # Get the MatchingInfo
          matching_info = @gui_controller.get_matching_info(obj_info, index)
          # Set the File element
          new_elem[0] = [ (obj_info.is_a?(Model::FileInfo) ? NODE_TYPE_FILE : NODE_TYPE_SEGMENT), obj_info, matching_info ]
          # Create all the CRC files elements
          matching_info.crc_matching_files.each do |pointer|
            treestore.append(new_elem)[0] = [ NODE_TYPE_CRC_MATCHING_FILE, pointer ]
          end
          # Create all the matching elements
          matching_info.matching_files.each do |pointer, matching_file_info|
            treestore.append(new_elem)[0] = [ NODE_TYPE_MATCHING_FILE, pointer, (matching_info.selected_pointer == pointer), matching_file_info ]
          end
          # Create sub-segments if need be
          if ((obj_info.is_a?(Model::FileInfo)) and
              (obj_info.segments.size > 1))
            obj_info.segments.size.times do |idx_segment|
              add_obj_info(treestore, new_elem, Model::SegmentPointer.new(obj_info, idx_segment), index)
            end
          end
        else
          raise "Unknown class for object to add to the tree: #{obj_info.class}"
        end
        # Create a fake child just for being able to expand it
        treestore.append(new_elem)[0] = false if has_children
      end

    end

  end

end