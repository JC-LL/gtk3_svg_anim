require 'gtk3'
require 'rsvg2'
require 'cairo'

class SVGAnimator
  def initialize(svg_file)
    @window = Gtk::Window.new("Animation SVG Ruby")
    @window.set_default_size(800, 600)
    @window.signal_connect('destroy') { Gtk.main_quit }

    @drawing_area = Gtk::DrawingArea.new
    @window.add(@drawing_area)

    @svg_handle = Rsvg::Handle.new_from_file(svg_file)
    @time = 0

    @drawing_area.signal_connect('draw') { |widget, cr| draw_svg(cr) }

    GLib::Timeout.add(16) do
      @time += 0.1
      @drawing_area.queue_draw
      true
    end
  end

  def draw_svg(cr)
    cr.set_source_rgb(0, 0, 0)
    cr.paint

    # Dessiner le SVG de base
    @svg_handle.render_cairo(cr)

    # Appliquer des transformations supplémentaires
    animate_elements(cr)
  end

  def animate_elements(cr)
    # Animation du cercle (mouvement sinusoïdal)
    cr.save
    cr.translate(100 + Math.sin(@time) * 100, 100 + Math.cos(@time) * 50)
    cr.set_source_rgb(1, 0, 0)
    cr.arc(0, 0, 40, 0, 2 * Math::PI)
    cr.fill
    cr.restore

    # Animation du rectangle (rotation)
    cr.save
    cr.translate(240, 190)  # Centre du rectangle
    cr.rotate(@time)
    cr.translate(-40, -40)  # Compensation
    cr.set_source_rgb(0, 1, 0)
    cr.rectangle(0, 0, 80, 80)
    cr.fill
    cr.restore
  end

  def run
    @window.show_all
    Gtk.main
  end
end

# Utilisation
animator = SVGAnimator.new('test_animation.svg')
animator.run
