#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'sketchup.rb'
begin
  require 'TT_Lib2/core.rb'
rescue LoadError => e
  module TT
    if @lib2_update.nil?
      url = 'http://www.thomthom.net/software/sketchup/tt_lib2/errors/not-installed'
      options = {
        :dialog_title => 'TT_Lib² Not Installed',
        :scrollable => false, :resizable => false, :left => 200, :top => 200
      }
      w = UI::WebDialog.new( options )
      w.set_size( 500, 300 )
      w.set_url( "#{url}?plugin=#{File.basename( __FILE__ )}" )
      w.show
      @lib2_update = w
    end
  end
end


#-------------------------------------------------------------------------------

if defined?( TT::Lib ) && TT::Lib.compatible?( '2.8.3', 'Layer Tools' )

module TT::Plugins::LayerTools


  ### MENU & TOOLBARS ### ------------------------------------------------------

  unless file_loaded?( __FILE__ )
    m = TT.menu('Tools')
    m.add_item('Hide Layer by Pick') { self.activate_hide_layer }
  end


  ### MAIN SCRIPT ### ----------------------------------------------------------

  def self.activate_hide_layer
    Sketchup.active_model.tools.push_tool( LayerTool.new )
  end


  class LayerTool

    def activate
      @cursor = ORIGIN
      @picked = nil
      @transformation = nil

      update_ui()
    end

    def resume(view)
      update_ui()
    end

    def update_ui
      Sketchup.status_text = 'Click an entity to hide its layer. Press Ctrl to hide from all Scenes.'
    end

    def deactivate(view)
      view.invalidate
    end

    def onMouseMove(flags, x, y, view)
      @cursor = [x, y, 0]

      ph = view.pick_helper
      ph.do_pick(x,y)
      if ph.picked_edge
        @picked = ph.picked_edge
      elsif ph.picked_face
        @picked = ph.picked_face
      else
        @picked = nil
      end

      if @picked
       (0...ph.count).each { |i|
          if ph.path_at(i).include?(@picked)
            @transformation = ph.transformation_at(i)
            break
          end
        }
      end

      update_tooltip()
      view.invalidate
    end

    def onLButtonUp(flags, x, y, view)
      if @picked
        layer = @picked.layer
        if flags & COPY_MODIFIER_MASK == COPY_MODIFIER_MASK
          view.model.start_operation('Hide Layer from all Scenes')
          view.model.pages.each { |page|
            unless page.layers.include?( layer )
              page.set_visibility( layer, false )
            end
          }
          layer.visible = false
          view.model.commit_operation
        else
          layer.visible = false
        end
        @picked = nil
      end
      update_tooltip()
    end

    def update_tooltip
      if @picked
        @tooltip = "#{@picked.class}\n#{@picked.layer.name}"
      else
        @tooltip = ''
      end
      Sketchup.status_text = @tooltip
    end

    def draw(view)
      if @picked
        view.line_stipple = ''
        view.line_width = 1

        origin = @cursor.offset([25,0,0])

        lines = @tooltip.split("\n")
        lines_length = lines.map { |str| str.length }
        max_length = lines_length.max

        height = (12 * lines.length) + (3 * (lines.length-1)) + 6
        width = ( 7 * max_length ) + 4

        pt1 = origin.offset( [-3,0,0] )
        pt2 = pt1.offset( X_AXIS, width )
        pt3 = pt2.offset( Y_AXIS, height )
        pt4 = pt1.offset( Y_AXIS, height )
        rect = [ pt1, pt2, pt3, pt4 ]

        view.drawing_color = [220,220,220]
        view.draw2d( GL_QUADS, rect )
        view.drawing_color = [64,64,64]
        rect.map! { |pt| Geom::Point3d.new( pt.x + 0.5, pt.y + 0.5, 0 ) }
        view.draw2d( GL_LINE_LOOP, rect )

        view.draw_text( origin, @tooltip )


        t = @transformation
        view.line_width = 5
        view.drawing_color = [255, 128, 0]
        if @picked.is_a?(Sketchup::Edge)
          view.draw(GL_LINES, @picked.vertices.map{|v|v.position.transform(t)})
        elsif @picked.is_a?(Sketchup::Face)
          view.draw(GL_LINE_LOOP, @picked.outer_loop.vertices.map{|v|v.position.transform(t)})
        end
      end
    end

  end # class LayerTool


  ### DEBUG ### ----------------------------------------------------------------

  # @note Debug method to reload the plugin.
  #
  # @example
  #   TT::Plugins::Template.reload
  #
  # @param [Boolean] tt_lib Reloads TT_Lib2 if +true+.
  #
  # @return [Integer] Number of files reloaded.
  # @since 1.0.0
  def self.reload( tt_lib = false )
    original_verbose = $VERBOSE
    $VERBOSE = nil
    TT::Lib.reload if tt_lib
    # Core file (this)
    load __FILE__
    # Supporting files
    if defined?( PATH ) && File.exist?( PATH )
      x = Dir.glob( File.join(PATH, '*.{rb,rbs}') ).each { |file|
        load file
      }
      x.length + 1
    else
      1
    end
  ensure
    $VERBOSE = original_verbose
  end

end # module

end # if TT_Lib

#-------------------------------------------------------------------------------

file_loaded( __FILE__ )

#-------------------------------------------------------------------------------